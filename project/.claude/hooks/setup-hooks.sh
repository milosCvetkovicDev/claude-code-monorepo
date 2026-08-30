#!/bin/bash

# Setup hook - ensures all hooks are executable
# Runs on: claude --init or claude --maintenance
# This fixes permissions that may be lost on Windows or after clone

set -e

HOOKS_DIR="$CLAUDE_PROJECT_DIR/.claude/hooks"

if [[ -d "$HOOKS_DIR" ]]; then
  echo "Setting up Claude Code hooks..."

  # Make all hook scripts executable
  chmod +x "$HOOKS_DIR"/*.sh 2>/dev/null || true

  # Count hooks
  HOOK_COUNT=$(ls -1 "$HOOKS_DIR"/*.sh 2>/dev/null | wc -l | tr -d ' ')

  echo "Configured $HOOK_COUNT hooks:"
  echo ""
  echo "  SessionStart:"
  echo "    - git-sync.sh (pull/merge main)"
  echo "    - docker-health-check.sh (env status)"
  echo "    - load-github-context.sh (PRs/issues)"
  echo "    - show-tips.sh (random tips)"
  echo ""
  echo "  PreToolUse:"
  echo "    - block-dangerous-commands.sh (safety)"
  echo "    - enforce-nx-commands.sh (nx reminder)"
  echo "    - protect-sensitive-files.sh (block .env)"
  echo ""
  echo "  PostToolUse:"
  echo "    - auto-format.sh (prettier)"
  echo ""
  echo "  Notification:"
  echo "    - desktop-notification.sh (alerts)"
  echo ""
  echo "  Stop:"
  echo "    - quality-gate-tests.sh (run tests)"
  echo ""
  echo "  SessionEnd:"
  echo "    - cleanup-resources.sh (free memory)"
  echo ""
  echo "  Setup:"
  echo "    - setup-hooks.sh (this script)"
  echo "    - deep-cleanup.sh (full cleanup)"
  echo ""
  echo "Hooks are ready! Run '/hooks' to verify."
fi

exit 0
