---
name: feedback_nx_format_write_overreaches_scope
description: nx format:write (no args) reformats files outside your change scope — incl the symlinked .claude (pollutes the main repo) and pre-existing non-prettier files; always scope it with --files.
metadata:
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000030
---

Running `npx nx format:write` with NO args in a acme worktree reformats EVERY file it deems dirty/non-conformant — not just your edits. Observed 2026-06-29 in a fresh build worktree off `main`: it reformatted `charts/infrastructure/kube-prometheus-stack-values.yaml` (pre-existing comment-spacing that wasn't prettier-conformant) AND `.claude/skills/triage/assets/triage-loop.yml` — the latter via the `.claude` SYMLINK, writing prettier churn into the shared main worktree's `.claude` (`$PROJECT_ROOT/.claude`), polluting an unrelated repo's working tree.

**Why:** format:write's "changed files" detection picks up any dirty/non-prettier file in the tree (and follows the `.claude` symlink), not just your git diff.

**How to apply:** ALWAYS scope it — `npx nx format:write --files="path1,path2,..."` listing only the files you changed. If you already ran the broad form: `git status --short` to find the over-reach, confirm each stray diff is pure prettier whitespace (`git diff <file>`), then `git restore <stray files>` (incl any `.claude/...` ones — restore writes back through the symlink to the main repo and is safe when the only deviation from HEAD is the format churn). Keep only your in-scope files staged. See [[worktree-best-practices]], [[feedback_claude_symlink_blocks_git_reset]].
