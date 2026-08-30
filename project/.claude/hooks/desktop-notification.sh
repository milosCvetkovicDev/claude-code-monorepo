#!/bin/bash

# Send desktop notifications when Claude needs attention
# Notification hook

set -e

# Parse input from stdin
INPUT=$(cat)
NOTIFICATION_TYPE=$(echo "$INPUT" | jq -r '.notification_type // empty')
MESSAGE=$(echo "$INPUT" | jq -r '.message // "Claude Code needs your attention"')

# Only notify for permission prompts and idle prompts
case "$NOTIFICATION_TYPE" in
  permission_prompt|idle_prompt)
    ;;
  *)
    exit 0
    ;;
esac

# macOS notification
if [[ "$(uname)" == "Darwin" ]]; then
  osascript -e "display notification \"$MESSAGE\" with title \"Claude Code\" sound name \"Ping\"" 2>/dev/null || true
fi

# Linux notification (using notify-send if available)
if [[ "$(uname)" == "Linux" ]]; then
  if command -v notify-send &> /dev/null; then
    notify-send "Claude Code" "$MESSAGE" --urgency=normal 2>/dev/null || true
  fi
fi

exit 0
