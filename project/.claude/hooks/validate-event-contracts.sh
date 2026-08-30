#!/bin/bash

# Event contract validation hook
# Trigger: PostToolUse hook for Write/Edit operations
# Checks event files for missing version, tenantId, past-tense naming

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

# Skip test files
case "$FILE_PATH" in
  *.spec.ts|*.test.ts) exit 0 ;;
esac

# Only check event-related files
IS_EVENT_FILE=false
case "$FILE_PATH" in
  */event-contracts/*|*/events/*) IS_EVENT_FILE=true ;;
esac

# Also check if file contains event definitions
if [[ "$IS_EVENT_FILE" = false ]] && [[ -f "$FILE_PATH" ]]; then
  if grep -q "DomainEvent\|IntegrationEvent\|implements.*Event" "$FILE_PATH" 2>/dev/null; then
    IS_EVENT_FILE=true
  fi
fi

if [[ "$IS_EVENT_FILE" = false ]]; then
  exit 0
fi

# Skip if file doesn't exist
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

WARNINGS=""

# Check for missing version field
if grep -q "class.*Event\|interface.*Event" "$FILE_PATH" 2>/dev/null; then
  if ! grep -q "version" "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS}• Missing 'version' field — all events must have a schema version\n"
  fi
fi

# Check for missing tenantId in metadata
if grep -q "metadata" "$FILE_PATH" 2>/dev/null; then
  if ! grep -q "tenantId" "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS}• Missing 'tenantId' in event metadata\n"
  fi
fi

# Check event class names are past tense (heuristic)
EVENT_NAMES=$(grep -oP "class \K\w+Event" "$FILE_PATH" 2>/dev/null || true)
for name in $EVENT_NAMES; do
  # Check if name ends in common past-tense suffixes
  if ! echo "$name" | grep -qiE "(Created|Updated|Deleted|Confirmed|Cancelled|Suspended|Deactivated|Assigned|Revoked|Completed|Enabled|Disabled|Changed|Logged|Expired|Failed|Published|Consumed)Event$"; then
    WARNINGS="${WARNINGS}• Event class '${name}' may not be past tense — events should describe what happened\n"
  fi
done

if [[ -n "$WARNINGS" ]]; then
  echo "{\"additionalContext\": \"⚠️ Event contract warnings in $(basename $FILE_PATH):\n${WARNINGS}See /rules/ddd-practices.md Practice 10 for event envelope standard.\"}"
fi

exit 0
