---
name: claude-symlink-blocks-git-reset-in-worktree
description: git reset --hard fails inside a acme worktree when .claude is a symlink to the primary worktree's .claude — must rm the symlink first, then reset, then reconfigure. ALSO git checkout/merge of a non-skip-worktree .claude file silently REPLACES the symlink with a real dir → breaks ALL hooks.
type: feedback
originSessionId: 00000000-0000-0000-0000-000000000048
---

When a acme worktree was created in `⊘ shared` mode, its `.claude/` is a **symlink** to `$PROJECT_ROOT/.claude` (the primary worktree). Git tracks files under `.claude/` (e.g., `.claude/epics/<name>/epic.md`), so `git reset --hard origin/main` tries to update those tracked paths through the symlink — fails with `error: Entry '.claude/epics/<name>/epic.md' not uptodate. Cannot merge.` on any worktree where the primary's `.claude` differs from origin/main.

**Why:** During Phase 2 (2026-04-30 session), resetting `acme-infra` (epic/ci-cd-deploy-systematic-fix → origin/main) blew up with that exact error. The symlink target had files staged differently than what main expected. Removing the symlink unblocked the reset, and `acme-worktree configure infra` re-created a local (`◉ local`) `.claude/` from origin/main content. The cost: the worktree flipped from `⊘ shared` to `◉ local`.

**How to apply:** Before `git reset --hard origin/main` (or any operation that updates tracked files under `.claude/`) inside a worktree using shared `.claude`:

```bash
# 1. Confirm .claude is a symlink (not a real dir)
ls -la .claude
# lrwxr-xr-x ... .claude -> $PROJECT_ROOT/.claude

# 2. Remove the symlink
rm .claude

# 3. Reset
git reset --hard origin/main

# 4. Re-configure to restore the worktree's instance-specific env files
#    (script auto-detects whether to create symlink-shared or local .claude)
acme-worktree configure <suffix>   # NOT the alias — use the dir suffix
```

`acme-worktree configure dev-i` fails (`Worktree not found: acme-dev-i`); the script wants the dir suffix (`infra`), not the alias (`dev-i`). Same gotcha for `acme-worktree remove <name>` — pass `m2-s1`, not `acme-m2-s1`.

**Trade-off:** After the reset, the worktree's `.claude` is local (own copy). If you need shared mode again, you must re-create the symlink manually or `acme-worktree remove + create` to start clean.

---

## Variant (2026-06-29, #1443 merge): `git checkout`/merge through the symlink turns `.claude` into a real dir → ALL hooks break

`git checkout HEAD -- .claude/<file>` (and a `git merge` that updates a `.claude` file whose **skip-worktree bit was cleared**) cannot write _through_ the `.claude` symlink — git's symlink protection instead **removes the symlink and creates a real `.claude/` directory** containing just that one materialized file. Symptom: every PreToolUse/PostToolUse hook fails with `/bin/sh: …/.claude/hooks/<name>.sh: No such file or directory` (the hooks now resolve to a real dir that has no `hooks/`). The shared target `$PROJECT_ROOT/.claude` is untouched and intact.

**Root cause chain:** all ~866 tracked `.claude/**` files carry **skip-worktree** (because git can't traverse the symlink as a dir — without skip-worktree it reports them all "deleted"). If you clear skip-worktree on one (e.g. to let a merge update it), git then materializes it → clobbers the symlink.

**Fix (surgical, no blanket `rm -rf`):**

```bash
git update-index --skip-worktree .claude/<the-file>        # re-protect → git ignores worktree state
rm .claude/<the-file> && rmdir .claude/<dirs…> .claude       # remove the erroneous local real dir
ln -s $PROJECT_ROOT/.claude .claude           # restore the symlink
ls .claude/hooks/pre-commit-checks.sh                        # verify hooks resolve again
```

The merge still records the file's merged content in the index (skip-worktree masks the now-divergent symlinked working copy) — so the commit stays correct. **Lesson: never clear skip-worktree on a `.claude` file to "help" a merge** — resolve `.claude` conflicts in the index and leave skip-worktree set. Related: [[feedback_claude_skip_worktree_bits]], [[feedback_source_driven_dev_breadcrumb_cwd]] (the same merge wiped the shared `.source-driven-dev/` breadcrumb dir → restore with `mkdir -p .claude/.source-driven-dev && cp ~/.claude/.source-driven-dev/*.fetched .claude/.source-driven-dev/`).
