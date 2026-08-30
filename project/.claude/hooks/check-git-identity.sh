#!/bin/bash

# Check git identity is configured
# SessionStart hook - prevents commit failures later in session

set -e

cd "$CLAUDE_PROJECT_DIR" || exit 0

GIT_NAME=$(git config user.name 2>/dev/null || true)
GIT_EMAIL=$(git config user.email 2>/dev/null || true)

if [[ -z "$GIT_NAME" || -z "$GIT_EMAIL" ]]; then
  echo "=== Git Identity Warning ==="
  if [[ -z "$GIT_NAME" ]]; then
    echo "WARNING: git user.name is not set"
  fi
  if [[ -z "$GIT_EMAIL" ]]; then
    echo "WARNING: git user.email is not set"
  fi
  echo "Commits will fail until identity is configured."
  echo "  Fix: git config user.name \"Your Name\""
  echo "  Fix: git config user.email \"your@email.com\""
  echo "============================="
fi

exit 0
