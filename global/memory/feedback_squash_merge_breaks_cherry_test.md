---
name: squash-merge-breaks-git-cherry-orphan-test
description: git cherry returns "+" (not on main) for squash-merged branches because squash rewrites the patch ID — must cross-check via gh pr view --json mergedAt before declaring "real unmerged work"
type: feedback
originSessionId: 00000000-0000-0000-0000-000000000048
---
`git cherry origin/main <branch>` is unreliable for orphan-detection in this repo because **trunk-based dev uses squash-merge** (`CLAUDE.md`: "squash merge, branch naming: feat/, fix/, chore/"). After a squash-merge the branch's commit hashes don't equal the squash commit on main, and patch IDs differ, so `git cherry` reports every commit as `+` (not on main) even when the branch has been fully merged.

**Why:** During Phase 2 repo hygiene (2026-04-30 session), I cherry-tested `epic/commission-gp-reconciliation-hardening` against origin/main and saw all 11 commits as `+`. Almost concluded "real unmerged work — needs decision". Cross-checked with `gh pr list --state all --search "<branch-name>"` and found PR #571 had been MERGED on 2026-04-27 via squash commit `8f8d1874`. The branch was a dead duplicate, safe to delete. Same trap nearly fired on `epic/erp-token-resilience` (PR #456 squash-merged the base feature; the 5 follow-up commits ahead were the actual real work).

**How to apply:** When auditing a branch for orphan status:

```bash
# Step 1 — git cherry as a hint, NOT a verdict
git cherry origin/main <branch>

# Step 2 — ALWAYS cross-check the PR history
gh pr list --state all --search "head:<branch>" --limit 5 \
  --json number,state,title,mergedAt,headRefName

# Step 3 — if the PR is MERGED with a recent mergedAt, the branch is an orphan
# even if git cherry says otherwise.

# Step 4 — for branches with NO PR ever, fall back to subject-substring grep:
git log origin/main --oneline --grep="<distinctive subject phrase>"
```

The lesson: in a squash-merge repo, `git cherry` is a starting point, never the final answer. PR API is authoritative.
