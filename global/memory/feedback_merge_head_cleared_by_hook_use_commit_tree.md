---
name: feedback_merge_head_cleared_by_hook_use_commit_tree
description: In acme checkouts a hook clears MERGE_HEAD mid-merge → git commit makes a single-parent fake-merge; build merges with commit-tree
metadata:
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000057
---

Observed twice in one session (2026-07-01) resolving `git merge origin/main` conflicts in `$PROJECT_ROOT-platform-commission`: **MERGE_HEAD was repeatedly cleared between tool calls** (reflog showed a stray `reset: moving to HEAD`). A later `git commit` then produced a **single-parent "fake merge"** — the commit message said "Merge …" but `%p` showed one parent and `git rev-list --count HEAD..origin/main` stayed non-zero (main NOT actually merged). Likely cause: a PostToolUse/format (prettier/lint-staged) hook running a git stash/reset while resolving across many Edit/Bash calls.

**Why:** conflict resolution spans many tool calls; if any hook touches git state, MERGE_HEAD vanishes and `git commit` silently drops the second parent. The result looks committed and clean but the merge never happened.

**How to apply:** For a real merge in this repo, do NOT rely on MERGE_HEAD surviving. Resolve + `git add` all conflicts, then build the 2-parent commit deterministically in ONE atomic Bash call:
`TREE=$(git write-tree); NEW=$(git commit-tree "$TREE" -p "$(git rev-parse HEAD)" -p "$(git rev-parse origin/main)" -F msg); git update-ref HEAD "$NEW"`.
commit-tree bypasses pre-commit hooks, so run `gitleaks detect --log-opts "origin/main..HEAD --no-merges"` manually afterward to keep the secret scan (NOT `--no-verify`; see [[feedback_merge_head_cleared_by_hook_use_commit_tree]] partner rule against --no-verify). ALWAYS verify: `git log -1 --pretty=%p` shows TWO parents and `git rev-list --count HEAD..origin/main` == 0. Tag the pre-existing HEAD first (`git tag wip-backup <sha>`) so a botched attempt is recoverable.
