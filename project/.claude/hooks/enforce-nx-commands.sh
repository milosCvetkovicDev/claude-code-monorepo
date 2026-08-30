#!/bin/bash

# Enforce using Nx commands instead of direct tool invocation
# PreToolUse hook for Bash operations

set -e

# Parse input from stdin
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Skip if no command
if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# Check patterns that should use Nx instead
check_pattern() {
  local pattern="$1"
  local alternative="$2"
  if echo "$COMMAND" | grep -qE "$pattern"; then
    echo "{\"additionalContext\": \"NOTE: Consider using Nx commands instead of direct tool invocation. Instead of this command, use: $alternative. Nx provides caching, dependency tracking, and consistent configuration.\"}"
    exit 0
  fi
}

check_pattern "^jest "       "nx run <project>:test or nx test <project>"
check_pattern "^npx jest"    "nx run <project>:test or nx test <project>"
check_pattern "^tsc "        "nx run <project>:build or nx build <project>"
check_pattern "^npx tsc"     "nx run <project>:build or nx build <project>"
check_pattern "^eslint "     "nx run <project>:lint or nx lint <project>"
check_pattern "^npx eslint"  "nx run <project>:lint or nx lint <project>"
check_pattern "^prettier "   "nx format:write or nx format:check"
check_pattern "^npx prettier" "nx format:write or nx format:check"
check_pattern "^webpack "    "nx run <project>:build"
check_pattern "^vite "       "nx run <project>:serve or nx run <project>:build"

exit 0
