#!/bin/bash

# NestJS anti-pattern detection hook
# Trigger: PostToolUse hook for Write/Edit operations
# Checks .ts files under apps/platform/ and libs/platform/ for anti-patterns

set -e

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Skip if no file path
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Only check .ts files
case "$FILE_PATH" in
  *.ts) ;;
  *) exit 0 ;;
esac

# Only check platform code
case "$FILE_PATH" in
  */apps/platform/*|*/libs/platform/*) ;;
  *) exit 0 ;;
esac

# Skip test files
case "$FILE_PATH" in
  *.spec.ts|*.test.ts) exit 0 ;;
esac

# Skip if file doesn't exist
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

VIOLATIONS=""

# Check for process.env usage
if grep -qn "process\.env" "$FILE_PATH" 2>/dev/null; then
  LINES=$(grep -n "process\.env" "$FILE_PATH" | head -3 | tr '\n' '; ')
  VIOLATIONS="${VIOLATIONS}• process.env usage (use @acme/config instead): ${LINES}\n"
fi

# Check for legacy scope imports
if grep -qn "from.*@acme/domain-types\|from.*@acme/shared-constants\|from.*apps/legacy-api\|from.*legacy-api" "$FILE_PATH" 2>/dev/null; then
  LINES=$(grep -n "from.*domain-types\|from.*shared-constants\|from.*legacy-api" "$FILE_PATH" | head -3 | tr '\n' '; ')
  VIOLATIONS="${VIOLATIONS}• ACL violation — importing from legacy scope: ${LINES}\n"
fi

# Check for Express/TypeORM imports
if grep -qn "from.*express\|from.*typeorm\|require.*express\|require.*typeorm" "$FILE_PATH" 2>/dev/null; then
  LINES=$(grep -n "from.*express\|from.*typeorm" "$FILE_PATH" | head -3 | tr '\n' '; ')
  VIOLATIONS="${VIOLATIONS}• Legacy framework import (use Fastify/MikroORM): ${LINES}\n"
fi

# Check for console.log usage
if grep -qn "console\.\(log\|error\|warn\|info\|debug\)" "$FILE_PATH" 2>/dev/null; then
  COUNT=$(grep -c "console\." "$FILE_PATH" 2>/dev/null || true)
  VIOLATIONS="${VIOLATIONS}• console.log usage (${COUNT} occurrences — use @acme/logger)\n"
fi

if [[ -n "$VIOLATIONS" ]]; then
  echo "{\"additionalContext\": \"⚠️ Platform pattern violations in $(basename $FILE_PATH):\n${VIOLATIONS}\"}"
fi

exit 0
