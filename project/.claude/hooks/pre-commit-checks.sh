#!/bin/bash

# Pre-commit hook: runs typecheck and affected tests before git commit commands.
# Triggered as a PreToolUse hook on Bash — only acts when the command is a git commit.

set -e

cd "$CLAUDE_PROJECT_DIR" || exit 0

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only intercept git commit commands
if ! echo "$COMMAND" | grep -qE '\bgit\s+commit\b'; then
  exit 0
fi

# Check if npx is available
if ! command -v npx &> /dev/null; then
  exit 0
fi

echo "=== Pre-commit Checks ==="

echo "Running typecheck..."
if timeout 120 npx tsc --noEmit 2>&1; then
  echo "Typecheck passed!"
else
  echo '{"decision":"block","reason":"Typecheck failed — fix type errors before committing."}'
  exit 0
fi

echo ""
echo "Running affected tests..."
if timeout 180 npx nx affected --target=test --base=HEAD~1 2>&1; then
  echo "Tests passed!"
  echo "=========================="
  exit 0
else
  echo '{"decision":"block","reason":"Affected tests failed — fix failing tests before committing."}'
  exit 0
fi
