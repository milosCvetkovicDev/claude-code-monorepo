---
allowed-tools: Bash, Read, Write
---

# Epic Merge

Merge completed epic from worktree back to main branch.

## Usage
```
/pm:epic-merge <epic_name>
```

## Quick Check

1. **Verify worktree exists:**
   ```bash
   git worktree list | grep "epic-$ARGUMENTS" || echo "❌ No worktree for epic: $ARGUMENTS"
   ```

2. **Check for active agents:**
   Read `.claude/epics/$ARGUMENTS/execution-status.md`
   If active agents exist: "⚠️ Active agents detected. Stop them first with: /pm:epic-stop $ARGUMENTS"

## Instructions

### 1. Pre-Merge Validation

Navigate to worktree and check status:
```bash
cd ../epic-$ARGUMENTS

# Check for uncommitted changes
if [[ $(git status --porcelain) ]]; then
  echo "⚠️ Uncommitted changes in worktree:"
  git status --short
  echo "Commit or stash changes before merging"
  exit 1
fi

# Check branch status
git fetch origin
git status -sb
```

### 2. Run Tests (Required)

**Tests MUST pass before merging.** Follow `/references/workflow/test-first-development.md`.

```bash
# Look for test commands based on project type
if [ -f package.json ]; then
  npm test || { echo "❌ Tests failed. Fix before merging."; exit 1; }
elif [ -f pom.xml ]; then
  mvn test || { echo "❌ Tests failed. Fix before merging."; exit 1; }
elif [ -f build.gradle ] || [ -f build.gradle.kts ]; then
  ./gradlew test || { echo "❌ Tests failed. Fix before merging."; exit 1; }
elif [ -f composer.json ]; then
  ./vendor/bin/phpunit || { echo "❌ Tests failed. Fix before merging."; exit 1; }
elif [ -f *.sln ] || [ -f *.csproj ]; then
  dotnet test || { echo "❌ Tests failed. Fix before merging."; exit 1; }
elif [ -f Cargo.toml ]; then
  cargo test || { echo "❌ Tests failed. Fix before merging."; exit 1; }
elif [ -f go.mod ]; then
  go test ./... || { echo "❌ Tests failed. Fix before merging."; exit 1; }
elif [ -f Gemfile ]; then
  bundle exec rspec || bundle exec rake test || { echo "❌ Tests failed. Fix before merging."; exit 1; }
elif [ -f pubspec.yaml ]; then
  flutter test || { echo "❌ Tests failed. Fix before merging."; exit 1; }
elif [ -f Package.swift ]; then
  swift test || { echo "❌ Tests failed. Fix before merging."; exit 1; }
elif [ -f CMakeLists.txt ]; then
  cd build && ctest || { echo "❌ Tests failed. Fix before merging."; exit 1; }
elif [ -f Makefile ]; then
  make test || { echo "❌ Tests failed. Fix before merging."; exit 1; }
fi

echo "✅ All tests passed"
```

### 2b. Production Verification Checklist

**Before merging, verify the epic's production readiness.**

Read the PRD's Production Verification section and the epic's production verification task:
```bash
# Find the PRD
epic_name=$ARGUMENTS
prd_file=".claude/prds/${epic_name}.md"

if [ -f "$prd_file" ]; then
  echo "📋 Production Verification Checklist (from PRD):"
  echo ""
  # Extract Production Verification section
  sed -n '/## Production Verification/,/^## /p' "$prd_file" | head -n -1
  echo ""
fi

# Find the last task (production verification task)
last_task=$(ls -1 .claude/epics/$ARGUMENTS/[0-9]*.md 2>/dev/null | sort | tail -1)
if [ -n "$last_task" ]; then
  task_name=$(grep '^name:' "$last_task" | cut -d: -f2 | sed 's/^ *//')
  if echo "$task_name" | grep -qi "production\|verification\|verify"; then
    echo "📋 Production Verification Task: $last_task"
    echo "   Status: $(grep '^status:' "$last_task" | cut -d: -f2 | sed 's/^ *//')"
    task_status=$(grep '^status:' "$last_task" | cut -d: -f2 | sed 's/^ *//')
    if [ "$task_status" != "closed" ] && [ "$task_status" != "completed" ]; then
      echo ""
      echo "⚠️ Production verification task is not complete."
      echo "   Complete it first with: /pm:prod-verify $ARGUMENTS"
      echo "   Or mark as done: /pm:issue-close {task_issue_number}"
    fi
  fi
fi
```

Confirm with user before proceeding:
```
Production verification status:
- [ ] Health checks pass
- [ ] Business smoke tests verified
- [ ] Monitoring reviewed (15 min window)
- [ ] Stakeholder sign-off (if required)

Continue with merge? (yes/no)
```

If user confirms, proceed. If production verification task is incomplete, warn but allow merge if user explicitly confirms.

### 2c. Code Review Check

Check if automated code review has been run:
```bash
review_file=".claude/epics/$ARGUMENTS/review-report.md"
if [ -f "$review_file" ]; then
  review_status=$(grep '^status:' "$review_file" | cut -d: -f2 | sed 's/^ *//')
  review_date=$(grep '^reviewed:' "$review_file" | cut -d: -f2- | sed 's/^ *//')
  echo "📋 Code Review Report: $review_status (reviewed: $review_date)"

  if [ "$review_status" = "needs-fixes" ]; then
    echo ""
    echo "⚠️ Code review has unresolved issues."
    echo "   Fix them first, then re-run: /pm:epic-review $ARGUMENTS"
    echo ""
    echo "Continue anyway? (yes/no)"
    # Wait for user confirmation before proceeding
  fi
else
  echo "⚠️ No code review report found."
  echo "   Recommended: Run /pm:epic-review $ARGUMENTS first"
  echo ""
  echo "Continue without code review? (yes/no)"
  # Wait for user confirmation before proceeding
fi
```

### 3. Update Epic Documentation

Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

Update `.claude/epics/$ARGUMENTS/epic.md`:
- Set status to "completed"
- Update completion date
- Add final summary

### 4. Create Pull Request

Instead of direct merge, create a PR for review and CI checks:

```bash
# Ensure latest changes are pushed
git push origin epic/$ARGUMENTS

# Check for existing PR
existing_pr=$(gh pr list --head "epic/$ARGUMENTS" --json number --jq '.[0].number' 2>/dev/null)

if [ -n "$existing_pr" ] && [ "$existing_pr" != "null" ]; then
  echo "Found existing PR #$existing_pr"
  pr_number=$existing_pr
else
  # Generate PR body from epic tasks and review report
  pr_body_file="/tmp/epic-pr-$ARGUMENTS.md"

  # Build feature list from tasks
  feature_list=""
  if [ -d ".claude/epics/$ARGUMENTS" ]; then
    for task_file in .claude/epics/$ARGUMENTS/[0-9]*.md; do
      [ -f "$task_file" ] || continue
      task_name=$(grep '^name:' "$task_file" | cut -d: -f2 | sed 's/^ *//')
      task_status=$(grep '^status:' "$task_file" | cut -d: -f2 | sed 's/^ *//')
      feature_list="$feature_list\n- [x] $task_name ($task_status)"
    done
  fi

  # Extract epic issue number for linking
  epic_github_line=$(grep 'github:' .claude/epics/$ARGUMENTS/epic.md 2>/dev/null || true)
  epic_issue=""
  if [ -n "$epic_github_line" ]; then
    epic_issue=$(echo "$epic_github_line" | grep -oE '[0-9]+' || true)
  fi

  # Include review report summary if available
  review_summary=""
  if [ -f ".claude/epics/$ARGUMENTS/review-report.md" ]; then
    review_summary=$(sed -n '/## Summary/,/## Critical/p' ".claude/epics/$ARGUMENTS/review-report.md" | head -5)
  fi

  cat > "$pr_body_file" << PREOF
## Epic: $ARGUMENTS

### Tasks Completed
$(echo -e "$feature_list")

### Code Review
${review_summary:-"No automated review report available."}

### Quality Checklist
- [x] Tests pass (required gate)
- [x] Code refactored (refactor phase completed)
- [x] Production verification documented
${epic_issue:+"
### Closes
Closes #$epic_issue"}

---
🤖 Generated by CCPM Pipeline
PREOF

  # Create the PR
  remote_url=$(git remote get-url origin 2>/dev/null || echo "")
  REPO=$(echo "$remote_url" | sed 's|.*github.com[:/]||' | sed 's|\.git$||')
  [ -z "$REPO" ] && REPO="user/repo"

  pr_number=$(gh pr create \
    --repo "$REPO" \
    --base main \
    --head "epic/$ARGUMENTS" \
    --title "Epic: $ARGUMENTS" \
    --body-file "$pr_body_file" \
    --json number --jq '.number' 2>/dev/null) || {
    echo "❌ Failed to create PR. Check: gh auth login"
    exit 1
  }

  echo "✅ Created PR #$pr_number"
  rm -f "$pr_body_file"
fi

### 5. Wait for CI Checks

```bash
echo "Waiting for CI checks on PR #$pr_number..."
gh pr checks $pr_number --watch --fail-level all 2>/dev/null || {
  echo ""
  echo "⚠️ CI checks have warnings or failures."
  echo "   Review at: gh pr view $pr_number --web"
  echo ""
  echo "Merge anyway? (yes/no)"
  # Wait for user confirmation
}
```

### 6. Merge the PR

```bash
echo "Merging PR #$pr_number..."
gh pr merge $pr_number --merge --delete-branch || {
  echo "❌ PR merge failed."
  echo "   Review at: gh pr view $pr_number --web"
  echo ""
  echo "Common causes:"
  echo "  - Branch protection rules require reviews"
  echo "  - CI checks haven't passed"
  echo "  - Merge conflicts with main"
  exit 1
}

echo "✅ PR #$pr_number merged successfully"
```

### 7. Post-Merge Cleanup

If merge succeeds:
```bash
# Pull latest main
git checkout main
git pull origin main

# Clean up worktree if it exists
if git worktree list | grep -q "epic-$ARGUMENTS"; then
  git worktree remove ../epic-$ARGUMENTS 2>/dev/null || true
  echo "✅ Worktree removed: ../epic-$ARGUMENTS"
fi

# Branch already deleted by --delete-branch in PR merge
# Clean up local tracking branch if still exists
git branch -d epic/$ARGUMENTS 2>/dev/null || true

# Archive epic locally
mkdir -p .claude/epics/archived/
mv .claude/epics/$ARGUMENTS .claude/epics/archived/
echo "✅ Epic archived: .claude/epics/archived/$ARGUMENTS"
```

### 8. Update GitHub Issues

Close related issues:
```bash
# Get issue numbers from epic
# Extract epic issue number
epic_github_line=$(grep 'github:' .claude/epics/archived/$ARGUMENTS/epic.md 2>/dev/null || true)
if [ -n "$epic_github_line" ]; then
  epic_issue=$(echo "$epic_github_line" | grep -oE '[0-9]+$' || true)
else
  epic_issue=""
fi

# Close epic issue
gh issue close $epic_issue -c "Epic completed and merged to main"

# Close task issues
for task_file in .claude/epics/archived/$ARGUMENTS/[0-9]*.md; do
  [ -f "$task_file" ] || continue
  # Extract task issue number
  task_github_line=$(grep 'github:' "$task_file" 2>/dev/null || true)
  if [ -n "$task_github_line" ]; then
    issue_num=$(echo "$task_github_line" | grep -oE '[0-9]+$' || true)
  else
    issue_num=""
  fi
  if [ ! -z "$issue_num" ]; then
    gh issue close $issue_num -c "Completed in epic merge"
  fi
done
```

### 9. Final Output

```
✅ Epic Merged Successfully: $ARGUMENTS

Summary:
  PR: #{pr_number} merged to main
  Branch: epic/$ARGUMENTS → main
  Commits merged: {count}
  Files changed: {count}
  Issues closed: {count}

Quality gates passed:
  ✓ Tests passed
  ✓ Code review completed
  ✓ CI checks passed
  ✓ PR merged

Cleanup completed:
  ✓ Worktree removed (if applicable)
  ✓ Branch deleted
  ✓ Epic archived
  ✓ GitHub issues closed

Next steps:
  - Verify in production: /pm:prod-verify $ARGUMENTS
  - Start new epic: /pm:prd-new {feature}
  - View completed work: git log --oneline -20
```

## Conflict Resolution Help

If conflicts need resolution:
```
The epic branch has conflicts with main.

This typically happens when:
- Main has changed since epic started
- Multiple epics modified same files
- Dependencies were updated

To resolve:
1. Open conflicted files
2. Look for <<<<<<< markers
3. Choose correct version or combine
4. Remove conflict markers
5. git add {resolved files}
6. git commit
7. git push

Or abort and try later:
  git merge --abort
```

## Important Notes

- Always check for uncommitted changes first
- Tests MUST pass before merging (required gate)
- Code review should be completed before merge (/pm:epic-review)
- Merge via PR for audit trail and CI integration
- Archive epic data instead of deleting
- Close GitHub issues to maintain sync
- Follow `/rules/github-operations.md` for repository protection