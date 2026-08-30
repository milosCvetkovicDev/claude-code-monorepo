#!/bin/bash

# Hook: Auto-seed dev instance after successful deployment
# PostToolUse hook for Bash - detects when gh run view/watch shows
# a successful deploy-dev-ephemeral workflow and reminds Claude to
# run the local seeding script.
#
# Triggers on: gh run view/watch output containing deploy-dev-ephemeral + success

set -e

# Parse PostToolUse JSON from stdin
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Only process Bash tool calls
if [[ "$TOOL_NAME" != "Bash" ]]; then
  exit 0
fi

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
OUTPUT=$(echo "$INPUT" | jq -r '.tool_output // empty')

# Only process gh run view/watch commands
if [[ ! "$COMMAND" =~ gh\ run\ (view|watch) ]]; then
  exit 0
fi

# Check if the output indicates a completed deploy-dev-ephemeral workflow
# Look for the workflow name and success status in the output
if [[ "$OUTPUT" =~ deploy-dev-ephemeral ]] || [[ "$COMMAND" =~ deploy-dev-ephemeral ]]; then
  # Check for successful completion indicators
  if [[ "$OUTPUT" =~ "completed".*"success" ]] || [[ "$OUTPUT" =~ "success".*"completed" ]] || [[ "$OUTPUT" =~ "Deploy Instance".*"completed".*"success" ]]; then
    # Extract instance name (dev-2 through dev-5) from output or command
    INSTANCE=""
    if [[ "$OUTPUT" =~ instance=(dev-[2-5]) ]]; then
      INSTANCE="${BASH_REMATCH[1]}"
    elif [[ "$OUTPUT" =~ (dev-[2-5]) ]]; then
      INSTANCE="${BASH_REMATCH[1]}"
    elif [[ "$COMMAND" =~ (dev-[2-5]) ]]; then
      INSTANCE="${BASH_REMATCH[1]}"
    fi

    if [[ -n "$INSTANCE" ]]; then
      echo ""
      echo "Deploy to $INSTANCE succeeded! Run local database seeding now:"
      echo "  ./scripts/seed-dev-ephemeral.sh $INSTANCE"
      echo ""
    fi
  fi
fi

exit 0
