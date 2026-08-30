---
name: feedback_stacked_pr_retarget_no_force_push
description: Retarget a stacked PR to main after its base PR merges WITHOUT a force-push (the harness blocks force-push)
metadata:
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000009
---

When PR-B is stacked on PR-A's branch and PR-A squash-merges to main, retarget PR-B to `main` **without rewriting history** (the harness classifier blocks `git push --force-with-lease`, so a local rebase + force-push is a dead end):

1. `gh pr merge <A> --admin --squash` (do NOT `--delete-branch` yet — B still bases on A's branch; also the worktree quirk aborts remote-delete on local-delete error).
2. `gh pr edit <B> --base main`
3. `gh pr update-branch <B>` — merges `main` (now containing A's squash) INTO B's branch via a merge commit. Because A's content is now reachable from B's new merge-base, GitHub recomputes B's diff to **B-only** (the A lines collapse out). No force-push, no history rewrite.
4. Then `git push origin --delete <A-branch>` is safe.

**Why:** verified on #1323→#1324 (2026-06-17). After step 3, `gh pr diff <B> --name-only` showed exactly B's files — clean review diff. Stack the NEXT PR (PR-C) off the _updated_ B branch (`origin/<B-branch>`, which now contains main+A+B) and repeat at merge time.

How to apply: never reach for force-push to retarget a stack; use edit-base + update-branch. For node_modules in fresh per-PR worktrees, symlink the first worktree's `node_modules` only when `git diff --quiet <base> HEAD -- package-lock.json` (else `npm ci`). See [[worktree-best-practices]], [[feedback_gh_pr_merge_delete_branch_worktree_quirk]].
