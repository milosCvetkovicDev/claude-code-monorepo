#!/bin/bash

# Protect sensitive files from being modified
# PreToolUse hook for Write/Edit operations

set -e

# Parse input from stdin
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Skip if no file path
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Get just the filename
FILENAME=$(basename "$FILE_PATH")

# List of protected file patterns
PROTECTED_FILES=(
  ".env"
  ".env.local"
  ".env.production"
  ".env.development"
  "credentials.json"
  "secrets.json"
  "*.pem"
  "*.key"
  "id_rsa"
  "id_ed25519"
  ".npmrc"
  ".netrc"
)

# Check if file matches any protected pattern
for pattern in "${PROTECTED_FILES[@]}"; do
  if [[ "$FILENAME" == $pattern ]]; then
    echo "BLOCKED: Cannot modify sensitive file: $FILE_PATH" >&2
    echo "This file may contain secrets or credentials." >&2
    echo "If you need to modify it, please do so manually." >&2
    exit 2
  fi
done

# Also check full path for specific patterns
SENSITIVE_PATHS=(
  "*/.ssh/*"
  "*/.aws/*"
  "*/.azure/*"
  "*/.gnupg/*"
  "*/secrets/*"
  "*/credentials/*"
)

for pattern in "${SENSITIVE_PATHS[@]}"; do
  if [[ "$FILE_PATH" == $pattern ]]; then
    echo "BLOCKED: Cannot modify file in sensitive directory: $FILE_PATH" >&2
    exit 2
  fi
done

exit 0
