#!/bin/bash

# Helm chart validation hook
# Trigger: PostToolUse hook for Write/Edit operations
# Checks Helm chart files for common issues

set -e

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Skip if no file path
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Only check yaml/yml files under charts/
case "$FILE_PATH" in
  */charts/*.yaml|*/charts/*.yml|*/helm/*.yaml|*/helm/*.yml) ;;
  *) exit 0 ;;
esac

# Skip if file doesn't exist
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

WARNINGS=""

# For values files: check for hardcoded image tags
if echo "$FILE_PATH" | grep -q "values"; then
  if grep -q "tag:.*[a-f0-9]\{7,40\}" "$FILE_PATH" 2>/dev/null; then
    : # SHA tag is fine
  elif grep -q "tag:.*latest" "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS}• Hardcoded 'latest' image tag — use SHA or semantic version\n"
  fi

  # Check for missing resource requests
  if ! grep -q "resources:" "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS}• Missing 'resources' section — all services must have CPU/memory requests and limits\n"
  fi

  # Check for missing probes
  if ! grep -q "livenessProbe:" "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS}• Missing 'livenessProbe' — required for K8s health checks\n"
  fi
  if ! grep -q "readinessProbe:" "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS}• Missing 'readinessProbe' — required for K8s health checks\n"
  fi
fi

# For any chart file: check for plaintext secrets
if grep -qE "password:|secret:|token:|apiKey:" "$FILE_PATH" 2>/dev/null; then
  if ! grep -qE "secretKeyRef|ExternalSecret|Values\." "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS}• Possible plaintext secret — use External Secrets Operator (ADR-0020)\n"
  fi
fi

# Run helm lint if available and this is under a chart directory
CHART_DIR=$(echo "$FILE_PATH" | grep -oP '.*/charts/[^/]+' || true)
if [[ -n "$CHART_DIR" ]] && [[ -f "$CHART_DIR/Chart.yaml" ]] && command -v helm >/dev/null 2>&1; then
  LINT_RESULT=$(helm lint "$CHART_DIR" 2>&1 || true)
  if echo "$LINT_RESULT" | grep -q "ERROR"; then
    LINT_ERRORS=$(echo "$LINT_RESULT" | grep "ERROR" | head -3)
    WARNINGS="${WARNINGS}• Helm lint errors: ${LINT_ERRORS}\n"
  fi
fi

if [[ -n "$WARNINGS" ]]; then
  echo "{\"additionalContext\": \"⚠️ Helm chart warnings in $(basename $FILE_PATH):\n${WARNINGS}\"}"
fi

exit 0
