#!/bin/bash

# Source-driven development enforcement hook
# PreToolUse hook for Write/Edit — blocks edits to framework files without doc breadcrumb
# Exit 0 = allow, Exit 2 = block

set -e

# Parse input from stdin
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Only process Write and Edit events
if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" ]]; then
  exit 0
fi

# Extract file path
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Skip if no file path
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Skip if file doesn't exist (new file creation)
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# Skip test files and non-code files
case "$FILE_PATH" in
  *.spec.ts|*.test.ts|*.spec.tsx|*.test.tsx|*.md|*.json|*.yaml|*.yml)
    exit 0
    ;;
esac

# Read file content (limit to 50KB for performance)
CONTENT=$(head -c 50000 "$FILE_PATH" 2>/dev/null || echo "")

# Framework detection: check imports and accumulate all detected frameworks
DETECTED_FRAMEWORKS=""

if echo "$CONTENT" | grep -q "@nestjs/"; then
  DETECTED_FRAMEWORKS="$DETECTED_FRAMEWORKS nestjs"
fi
if echo "$CONTENT" | grep -q "@mikro-orm/"; then
  DETECTED_FRAMEWORKS="$DETECTED_FRAMEWORKS mikroorm"
fi
if echo "$CONTENT" | grep -qE "from ['\"]fastify['\"]|require\(['\"]fastify['\"]"; then
  DETECTED_FRAMEWORKS="$DETECTED_FRAMEWORKS fastify"
fi
if echo "$CONTENT" | grep -qE "from ['\"]react['\"]|from ['\"]react/"; then
  DETECTED_FRAMEWORKS="$DETECTED_FRAMEWORKS react"
fi
if echo "$CONTENT" | grep -q "@mui/"; then
  DETECTED_FRAMEWORKS="$DETECTED_FRAMEWORKS mui"
fi
if echo "$CONTENT" | grep -q "@playwright/"; then
  DETECTED_FRAMEWORKS="$DETECTED_FRAMEWORKS playwright"
fi
if echo "$CONTENT" | grep -qE "terraform|resource \"|data \""; then
  DETECTED_FRAMEWORKS="$DETECTED_FRAMEWORKS terraform"
fi
if echo "$CONTENT" | grep -qE "helm|apiVersion:.*helm"; then
  DETECTED_FRAMEWORKS="$DETECTED_FRAMEWORKS helm"
fi
if echo "$CONTENT" | grep -qE "argocd|argoproj"; then
  DETECTED_FRAMEWORKS="$DETECTED_FRAMEWORKS argocd"
fi

# No framework detected — allow
if [[ -z "$DETECTED_FRAMEWORKS" ]]; then
  exit 0
fi

# Check breadcrumb for each detected framework
for fw in $DETECTED_FRAMEWORKS; do
  BREADCRUMB=".claude/.source-driven-dev/${fw}.fetched"
  if [[ ! -f "$BREADCRUMB" ]]; then
    echo "{\"error\": \"Source-driven development: You must fetch ${fw} documentation before editing this file. Use context7 or WebFetch to get current docs, then create breadcrumb: mkdir -p .claude/.source-driven-dev && touch .claude/.source-driven-dev/${fw}.fetched\"}"
    exit 2
  fi
done

# All breadcrumbs exist — allow
exit 0
