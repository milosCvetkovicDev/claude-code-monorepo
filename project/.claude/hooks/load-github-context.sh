#!/bin/bash

# Load GitHub issues and PRs for context at session start
# SessionStart hook

set -e

cd "$CLAUDE_PROJECT_DIR" || exit 0

# Check if gh CLI is available
if ! command -v gh &> /dev/null; then
  exit 0
fi

# Check if we're in a git repo with GitHub remote
if ! git remote -v 2>/dev/null | grep -q "github"; then
  exit 0
fi

echo "Open Pull Requests:"
gh pr list --limit 3 --state open 2>/dev/null || echo "  (unable to fetch PRs)"

echo "Recent Issues:"
gh issue list --limit 3 --state open 2>/dev/null || echo "  (unable to fetch issues)"

# Get current PR if on a feature branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [[ "$CURRENT_BRANCH" != "main" && "$CURRENT_BRANCH" != "master" ]]; then
  echo "Current Branch: $CURRENT_BRANCH"
  PR_INFO=$(gh pr view "$CURRENT_BRANCH" --json number,title,state 2>/dev/null || true)
  if [[ -n "$PR_INFO" ]]; then
    echo "Associated PR: $(echo "$PR_INFO" | jq -r '"#\(.number) - \(.title) (\(.state))"')"
  fi
fi

# Surface the latest triage inbox (loop-engineering loop memory) so findings are not lost.
# Written by the `triage` skill; lives at .claude/triage/inbox.md (git-ignored).
INBOX=".claude/triage/inbox.md"
if [[ -f "$INBOX" ]]; then
  echo "Triage inbox (run /triage to refresh):"
  grep -m1 '^summary:' "$INBOX" 2>/dev/null | sed 's/^/  /' || true
  # Open items needing a human. Matches the "## ...(INBOX)" heading — keep in sync with
  # assets/inbox-template.md ("## ⛔ Needs you (INBOX)"); renaming that heading silently empties this.
  awk '/^## .*INBOX/{f=1;next} /^## /{f=0} f && /^### /{print "  - " substr($0,5)}' "$INBOX" 2>/dev/null | head -5 || true
fi

exit 0
