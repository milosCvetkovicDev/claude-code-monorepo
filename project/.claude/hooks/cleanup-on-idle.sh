#!/bin/bash

# Light cleanup when session is idle for a while
# Can be triggered periodically or on specific events

set -e

cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || exit 0

# 1. Stop Nx daemon if idle (it restarts automatically when needed)
if command -v npx &> /dev/null; then
  npx nx daemon --stop 2>/dev/null || true
fi

# 2. Trigger Node.js garbage collection hint by killing idle watchers
# This is aggressive - only use if memory is a concern

# 3. Clear terminal scrollback to free memory
# printf '\033[3J' 2>/dev/null || true

exit 0
