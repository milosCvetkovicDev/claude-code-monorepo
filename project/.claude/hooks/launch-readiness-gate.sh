#!/bin/bash

# Launch readiness gate hook
# PreToolUse hook for Bash — blocks deploy commands without readiness pass
# Exit 0 = allow, Exit 2 = block

set -e

# Check jq is available
if ! command -v jq &>/dev/null; then
  echo "Warning: jq not found, launch-readiness gate disabled" >&2
  exit 0
fi

# Parse input from stdin
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Skip if no command
if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# Check if command is a deploy command
IS_DEPLOY=false

case "$COMMAND" in
  *"gh workflow run Deploy"*|*"gh workflow run deploy"*)
    IS_DEPLOY=true
    ;;
  *"az containerapp"*update*|*"az containerapp"*create*)
    IS_DEPLOY=true
    ;;
  *"terraform apply"*)
    IS_DEPLOY=true
    ;;
  *"helm upgrade"*|*"helm install"*)
    IS_DEPLOY=true
    ;;
esac

# Not a deploy command — allow
if [[ "$IS_DEPLOY" = false ]]; then
  exit 0
fi

# Check for readiness breadcrumb
if [[ -f ".claude/.launch-readiness-passed" ]]; then
  exit 0
fi

# No readiness pass — block deploy
echo '{"error": "Launch readiness gate: Deploy blocked. Run launch-readiness checklist first, or use --force with a documented reason. See .claude/skills/launch-readiness/SKILL.md"}'
exit 2
