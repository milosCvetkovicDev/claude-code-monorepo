#!/bin/bash
# UserPromptSubmit hook: Remind about dev slot availability when starting issue work
#
# Detects when user mentions:
# - "implement issue #X" / "work on issue #X" / "start issue #X"
# - "deploy to dev-X" / "deploy branch to dev"
# - References to specific issue numbers with implementation intent
#
# Provides reminders about:
# - Checking dev slot availability
# - Adding tracking labels after deployment

set -e

# Get the user's prompt
USER_PROMPT="${CLAUDE_USER_PROMPT:-}"

if [ -z "$USER_PROMPT" ]; then
  exit 0
fi

# Convert to lowercase for matching
PROMPT_LOWER=$(echo "$USER_PROMPT" | tr '[:upper:]' '[:lower:]')

# Patterns that indicate starting work on an issue
IMPLEMENT_PATTERNS="implement.*issue|work on.*issue|start.*issue|begin.*issue|tackle.*issue|fix.*issue.*#|working on.*#"
DEPLOY_PATTERNS="deploy.*dev-[a-z0-9]+|deploy.*to dev|deploy branch|deploy this"

# Check for implementation patterns with issue reference
if echo "$PROMPT_LOWER" | grep -qE "$IMPLEMENT_PATTERNS"; then
  # Extract issue number if present
  ISSUE_NUM=$(echo "$USER_PROMPT" | grep -oE "#[0-9]+" | head -1 | tr -d '#' || true)

  if [ -n "$ISSUE_NUM" ]; then
    # Check if issue already has a dev instance label
    LABELS=$(gh issue view "$ISSUE_NUM" --json labels --jq '.labels[].name' 2>/dev/null || echo "")
    DEV_LABEL=$(echo "$LABELS" | grep -E "^deployed:dev-[a-z0-9]+$" || true)

    if [ -n "$DEV_LABEL" ]; then
      INSTANCE=$(echo "$DEV_LABEL" | sed 's/deployed://')
      cat << EOF
Issue #$ISSUE_NUM already has '$DEV_LABEL' assigned.
This issue is associated with $INSTANCE.
Check if $INSTANCE is still deployed:
  ./scripts/azure-dev-ephemeral/status.sh
If continuing work, no action needed.
EOF
    else
      cat << EOF
Before deploying issue #$ISSUE_NUM to a dev environment:
1. Check available slots:
   ./scripts/azure-dev-ephemeral/check-availability.sh
2. After deploying, add tracking label:
   gh issue edit $ISSUE_NUM --add-label "deployed:dev-<alias>"
   (Find your alias: acme-worktree list)
This enables automatic cleanup when the issue closes.
EOF
    fi
  else
    # General reminder without specific issue
    cat << EOF
If this work requires a dev environment deployment:
1. Check available slots first:
   ./scripts/azure-dev-ephemeral/check-availability.sh
2. After deploying, add tracking label to the issue:
   gh issue edit <issue-number> --add-label "deployed:dev-<alias>"
   (Find your alias: acme-worktree list)
This enables automatic cleanup when the issue closes (~\$29/month savings).
EOF
  fi
  exit 0
fi

# Check for deployment patterns
if echo "$PROMPT_LOWER" | grep -qE "$DEPLOY_PATTERNS"; then
  # Check if they're mentioning a specific dev instance
  DEV_INSTANCE=$(echo "$USER_PROMPT" | grep -oE "dev-[a-z0-9]+" | head -1 || true)

  if [ -n "$DEV_INSTANCE" ]; then
    # Check if this instance is already deployed
    RG_NAME="${DEV_INSTANCE}-acme-rg"
    IS_DEPLOYED=$(az group show --name "$RG_NAME" 2>/dev/null && echo "yes" || echo "no")

    if [ "$IS_DEPLOYED" = "yes" ]; then
      # Check who owns it
      OWNER_ISSUE=$(gh issue list --label "deployed:$DEV_INSTANCE" --state open --json number,title --jq '.[0] | "#\(.number): \(.title)"' 2>/dev/null || echo "")

      if [ -n "$OWNER_ISSUE" ]; then
        cat << EOF
$DEV_INSTANCE is currently IN USE!
Associated with: $OWNER_ISSUE
Consider:
- Using a different slot (check-availability.sh)
- Coordinating with the issue owner
- Destroying first if the instance is orphaned
EOF
      else
        cat << EOF
$DEV_INSTANCE is deployed but has NO tracking label.
Check if it's orphaned:
  ./scripts/azure-dev-ephemeral/check-availability.sh
If orphaned, destroy first:
  ./scripts/azure-dev-ephemeral/destroy.sh $DEV_INSTANCE
EOF
      fi
    fi
  else
    # General deployment without specific instance
    cat << EOF
Before deploying:
1. Check which instances are available:
   ./scripts/azure-dev-ephemeral/check-availability.sh
2. After deploying, add tracking label:
   gh issue edit <issue-number> --add-label "deployed:dev-<alias>"
   (Find your alias: acme-worktree list)
EOF
  fi
fi

exit 0
