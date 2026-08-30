---
name: gh-pr-merge-delete-branch-fails-when-main-is-in-another-worktree
description: "`gh pr merge --squash --delete-branch` errors with \"main is already used by worktree at <path>\" but the GitHub-side merge actually succeeds. Manual cleanup of remote + local branch is needed."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000058
---

**Rule**: When `gh pr merge --squash --delete-branch` fails with `failed to run git: fatal: 'main' is already used by worktree at <path>`, do NOT assume the merge didn't happen. Verify via `gh pr view <num> --json state,mergedAt,mergeCommit` — the GitHub-side merge typically completed; only the local-side cleanup failed.

**Why**: 2026-05-26 incident merging PR #912 from the `$PROJECT_ROOT-platform` worktree. The repo has multiple worktrees: `acme-platform` is on a feature branch, while `acme-platform-microservices-databases` has `main` checked out. `gh pr merge` tries to switch the local worktree to `main` to update it post-merge, which fails because `main` is checked out elsewhere. Without verification, this looks like the merge didn't happen.

**How to apply**:
- After `gh pr merge ... --delete-branch` fails, immediately run `gh pr view <num> --json state,mergedAt,mergeCommit` — if `state: MERGED` and `mergedAt` is non-null, the merge succeeded.
- Manual cleanup needed because `--delete-branch` only fires on success of the local-side step:
  1. `git push origin --delete <branch>` to remove the remote ref
  2. `git checkout --detach origin/main` (or any other branch) to free the local branch
  3. `git branch -D <branch>` to delete the local branch
- The current worktree ends up at detached HEAD on the squash commit — that's the natural state for a worktree that's not meant to track `main`.

**Detection cue**: error message contains `'main' is already used by worktree at` — that's the exact signature. Same pattern would apply for any branch checked out in another worktree.

**Workaround for next time**: If you anticipate this, pass `--auto` or skip `--delete-branch` and clean up manually. Or work in the worktree that doesn't have main checked out.

**Related**: [[worktree-best-practices]] (one-branch-per-worktree means main lives in one worktree; the other worktrees can't transition to main via gh's post-merge step).
