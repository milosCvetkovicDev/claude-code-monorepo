---
name: github-refresh
description: "Refresh GitHub context by fetching current PR status, issue details, branch state, and CI/CD results. Use when the user needs up-to-date information about PRs, issues, or branches. Do not use for creating PRs (use pr-create) or fixing CI failures (use cicd-troubleshoot)."
model: haiku
---

# Refresh GitHub Context

Reload GitHub PRs and issues for the current repository.

## What to Fetch

### 1. Open Pull Requests

```bash
gh pr list --limit 10 --state open
```

### 2. Recent Issues

```bash
gh issue list --limit 10 --state open
```

### 3. Current Branch PR (if on feature branch)

```bash
# Get current branch
BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Check if there's a PR for this branch
gh pr view "$BRANCH" --json number,title,state,url,reviews,checks
```

### 4. PR Review Status (for current branch)

```bash
gh pr checks
```

### 5. My Assigned Issues

```bash
gh issue list --assignee @me --state open
```

### 6. PRs Awaiting My Review

```bash
gh pr list --search "review-requested:@me"
```

## Additional Context

### PR Details (if working on a PR)

```bash
# Full PR info
gh pr view --json title,body,comments,reviews,files

# PR diff stats
gh pr diff --stat
```

### Issue Details (if working on an issue)

```bash
gh issue view <number>
```

## Output

Provide a summary:

```
=== GitHub Context ===

Open Pull Requests (5):
#70 - chore(deps): Bump npm-minor group    [OPEN]
#65 - feat(pagination): Add pagination     [OPEN]
...

Recent Issues (5):
#64 - Add staging deployment step          [enhancement, infrastructure]
#63 - Add pagination to FinalisedLinesPage [enhancement, priority:high]
...

Current Branch: feat/my-feature
Associated PR: #71 - My feature PR [OPEN]
  - Checks: 3/3 passing
  - Reviews: 1 approved, 1 pending

========================
```
