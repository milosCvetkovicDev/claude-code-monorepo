#!/bin/bash

# Git branch auto-sync hook for Claude Code sessions
# Runs at session start to keep branches in sync with main

set -e

cd "$CLAUDE_PROJECT_DIR" || exit 1

# Check if this is a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "Not a git repository, skipping sync"
  exit 0
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

if [ "$CURRENT_BRANCH" = "main" ]; then
  # On main: pull the latest changes (ff-only to avoid surprise merges)
  if git pull origin main --ff-only 2>/dev/null; then
    echo "Git: pulled main"
  else
    echo "Git: main has diverged from origin — skipping auto-sync (resolve manually)"
  fi
else
  # On a feature branch: merge latest main
  git fetch origin main
  if git merge origin/main --no-edit 2>/dev/null; then
    echo "Git: merged main → $CURRENT_BRANCH"
  else
    git merge --abort 2>/dev/null || true
    echo "Git: could not auto-merge main → $CURRENT_BRANCH — resolve manually"
  fi
fi

exit 0
