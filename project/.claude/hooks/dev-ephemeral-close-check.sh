#!/bin/bash
# PreToolUse hook: Check for dev instances when closing GitHub issues
#
# When Claude runs `gh issue close`, this hook:
# 1. Extracts the issue number from the command
# 2. Checks if that issue has a deployed:dev-<alias> label
# 3. Warns Claude if a dev instance needs cleanup
#
# This ensures the auto-destroy workflow can clean up the environment.

set -e

# Only process Bash tool calls
TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

# Get the command being run
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"
COMMAND=$(echo "$TOOL_INPUT" | jq -r '.command // empty' 2>/dev/null || echo "")

# Check if this is a gh issue close command
if ! echo "$COMMAND" | grep -qE "gh\s+issue\s+close"; then
  exit 0
fi

# Extract issue number from command (handles various formats)
# gh issue close 55
# gh issue close #55
# gh issue close "55"
ISSUE_NUM=$(echo "$COMMAND" | grep -oE "gh\s+issue\s+close\s+[#]?['\"]?([0-9]+)" | grep -oE "[0-9]+$" || true)

if [ -z "$ISSUE_NUM" ]; then
  exit 0
fi

# Check if issue has a deployed:dev-<alias> label
LABELS=$(gh issue view "$ISSUE_NUM" --json labels --jq '.labels[].name' 2>/dev/null || echo "")
DEV_LABEL=$(echo "$LABELS" | grep -E "^deployed:dev-[a-z0-9]+$" || true)

if [ -n "$DEV_LABEL" ]; then
  INSTANCE=$(echo "$DEV_LABEL" | sed 's/deployed://')

  # Output reminder to Claude
  cat << EOF

=== DEV INSTANCE REMINDER ===
Issue #$ISSUE_NUM has label '$DEV_LABEL'

When this issue closes:
- The auto-destroy workflow will automatically destroy $INSTANCE
- Monthly savings: ~\$29/month

If the dev instance should NOT be destroyed:
- Remove the label first: gh issue edit $ISSUE_NUM --remove-label "$DEV_LABEL"

If you want to keep the instance for another issue:
- Move the label: gh issue edit <new-issue> --add-label "$DEV_LABEL"
================================

EOF
fi

exit 0
