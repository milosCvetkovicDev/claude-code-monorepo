---
name: feedback-explicit-push-target
description: "ALWAYS specify `origin <branch>` in `git push` inside bulk scripts. Never rely on the worktree's current-branch upstream tracking — multi-worktree loops will silently push the wrong branch."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000047
---

**Rule**: In any script or loop that does `git push` across multiple worktrees/branches, ALWAYS write `git push origin <branch>` (or `--force-with-lease origin <branch>`). Never write a bare `git push --force-with-lease`.

**Why**: 2026-05-21 a bulk-rebase script ran across 6 worktrees to refresh PR branches after a #850/#853/#858/#862/#863 merge. The acme-platform worktree at `$PROJECT_ROOT-platform` had `main` checked out (left over from earlier session work), not the PR's branch. The script:

```bash
cd "$wt"
git reset --hard "origin/$branch"   # branch=fix/high-3-wif-pod-label
git rebase origin/main
SKIP_HOOKS=1 git push --force-with-lease
```

`git reset --hard` moves the CURRENT BRANCH POINTER (main, in this worktree), not the named branch. So local `main` was reset to the PR's tip. The bare `git push --force-with-lease` then pushed the current branch (`main`) to its upstream (`origin/main`) — **force-pushing the PR's commits onto production main**.

Damage was contained because:
- The pushed content was legitimate PR work (#852 HIGH-3 + HIGH-8 fixes).
- `_deploy.yml` and `platform-pipeline.yml` correctly failed on the new SHA (no auto-deploy on main pushes).
- Recovery was: close #852, delete its branch, accept the (now slightly ugly) main history.

But it could have been catastrophic if the wrong worktree had been on `epic/cnpg-multitenancy`, `feat/platform-microservices-databases`, or any long-lived branch with destructive force-push consequences.

**How to apply**:
- In bulk scripts, ALWAYS pass explicit `origin <branch>`: `SKIP_HOOKS=1 git push --force-with-lease origin "$branch"`.
- Before `git reset --hard origin/<branch>`, ALWAYS check the current branch matches: `[ "$(git branch --show-current)" = "$branch" ] || { echo "wrong branch"; return 1; }`.
- Better: `git switch <branch>` (creates if needed, errors if dirty) before any history-rewriting operation.
- Even better: don't do bulk-rebase scripts; see [[feedback_one_pr_for_review_fixes]].
