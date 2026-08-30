#!/bin/bash

# ESLint security scanning hook
# Trigger: PostToolUse hook for Write/Edit operations
# Runs ESLint security rules on .ts/.tsx files in apps/platform/ and libs/platform/

set -e

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Skip if no file path
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Only check .ts and .tsx files
case "$FILE_PATH" in
  *.ts|*.tsx) ;;
  *) exit 0 ;;
esac

# Only check platform code
case "$FILE_PATH" in
  */apps/platform/*|*/libs/platform/*) ;;
  *) exit 0 ;;
esac

# Skip test files
case "$FILE_PATH" in
  *.spec.ts|*.test.ts|*.spec.tsx|*.test.tsx) exit 0 ;;
esac

# Check if eslint-plugin-security is loadable (--print-config verifies plugins resolve)
if ! npx eslint --no-eslintrc -c "$CLAUDE_PROJECT_DIR/.eslintrc.security.json" --print-config "$FILE_PATH" >/dev/null 2>&1; then
  echo '{"additionalContext": "⚠️ eslint-plugin-security not installed — run: npm install -D eslint-plugin-security eslint-plugin-no-secrets"}'
  exit 0
fi

# Run ESLint security rules
RESULTS=$(npx eslint --no-eslintrc -c "$CLAUDE_PROJECT_DIR/.eslintrc.security.json" --format compact "$FILE_PATH" 2>&1 || true)

if [[ -n "$RESULTS" ]] && echo "$RESULTS" | grep -q "Error\|Warning"; then
  # Count issues
  ERROR_COUNT=$(echo "$RESULTS" | grep -c "Error" || true)
  WARN_COUNT=$(echo "$RESULTS" | grep -c "Warning" || true)

  # Extract relevant lines (skip summary)
  ISSUES=$(echo "$RESULTS" | grep -E "Error|Warning" | head -5)

  echo "{\"additionalContext\": \"⚠️ Security scan found ${ERROR_COUNT} error(s), ${WARN_COUNT} warning(s) in $(basename $FILE_PATH):\n${ISSUES}\"}"
fi

exit 0
