#!/bin/bash

# Auto-format files after Claude edits them
# PostToolUse hook for Write/Edit operations

set -e

# Parse input from stdin
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only process Write and Edit tools
if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" ]]; then
  exit 0
fi

# Skip if no file path
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Get file extension
EXT="${FILE_PATH##*.}"

# Only format supported file types
case "$EXT" in
  ts|tsx|js|jsx|json|md|css|scss|html)
    # Check if prettier is available
    if command -v npx &> /dev/null; then
      cd "$CLAUDE_PROJECT_DIR"
      npx prettier --write "$FILE_PATH" 2>/dev/null || true
    fi
    ;;
esac

exit 0
