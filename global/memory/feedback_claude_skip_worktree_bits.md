---
name: claude-skip-worktree-bits-block-checkout
description: Diagnose "pathspec '.claude/...' did not match any file(s) known to git" — the underlying cause is that .claude/* files have skip-worktree index bits set, by design, in symlink-shared worktrees
type: feedback
originSessionId: 00000000-0000-0000-0000-000000000044
---

In a acme worktree where `.claude/` is a symlink to the primary's `.claude/`, every tracked file under `.claude/` has the **`S` (skip-worktree) bit** set in this worktree's index. The skip-worktree mechanism is what makes the symlink workaround work: git refuses to touch those paths in the working tree, so the symlink stays unmolested.

**Why:** Without skip-worktree, `git checkout`/`git restore` would try to materialize `.claude/*` files INTO the working tree, conflicting with the symlink. Setting skip-worktree on every `.claude/*` index entry tells git "the worktree's view of these files is canonical — don't sync from the index." This is the deliberate design that lets multiple worktrees share one physical `.claude/` via the primary's directory.

**How to apply / diagnose:**

Symptoms that point at this:

- `git checkout HEAD -- .claude/foo.md` → `error: pathspec '.claude/foo.md' did not match any file(s) known to git`
- `git restore --source=HEAD .claude/foo.md` → same error
- `git status` after editing `.claude/foo.md` shows nothing (the change is "invisible" because skip-worktree masks worktree-vs-index diffs)
- BUT `git ls-files .claude/foo.md` returns the path (file IS tracked) and `git ls-tree HEAD .claude` returns the tree hash

Diagnostic command:

```bash
git ls-files -v .claude/ | head    # Look for 'S' prefix (skip-worktree set)
git ls-files -v .claude/foo.md     # 'S .claude/foo.md' → confirmed
```

To commit changes to `.claude/*` files from a symlink-shared worktree, the documented path is to do it from a worktree where `.claude/` is the real directory (the primary `acme/` worktree, or a `◉ local` worktree). DO NOT bypass skip-worktree from a `⊘ shared` worktree by clearing the bits — you'll break the cross-worktree shared-state pattern and likely confuse the next `acme-worktree` operation.

**Workflow when stuck mid-session in a `⊘ shared` worktree:**

1. Save your edits via the symlink (the changes are live on disk in the primary's `.claude/`).
2. Commit them from the primary `acme/` worktree on the same branch:
   ```bash
   cd $PROJECT_ROOT
   git stash    # if dirty
   git checkout <epic-branch>
   git add .claude/...
   git commit -m "..."
   git checkout <previous-branch>
   git stash pop
   ```
3. Or use `acme-worktree remove + create --local` to flip the worktree to `◉ local` mode, then commit from there.

**Related:** [feedback_claude_symlink_blocks_git_reset.md](feedback_claude_symlink_blocks_git_reset.md) covers the other failure mode (git reset blowing up against the symlink) — same underlying mechanism, different surface symptom.

**Discovered:** 2026-05-10 while attempting `.claude/` epic-doc commits for issue #695 from `acme-cnpg-foundation` worktree. Symptom was `git checkout HEAD -- .claude` returning "pathspec did not match"; `git ls-files -v` revealed the `S` bits.

---

**Update 2026-06-08 (NON-symlink primary checkout — bits caused SILENT hook breakage):** In `acme-platform-microservices-databases` (a REAL `.claude/` dir, not a symlink), the entire `.claude/hooks/` directory was deleted on disk while all 34 files carried `S` bits. Result: Stop hooks failed with "No such file or directory", yet `git status` was **clean** — skip-worktree masked the deletion so git wouldn't restore it. Recovery: `git ls-files -z .claude/hooks/ | xargs -0 git update-index --no-skip-worktree` → `git checkout -- .claude/hooks/` → (optionally re-flag).

**DECISION (Milos, 2026-06-08): leave skip-worktree bits OFF on `.claude/hooks/` in this repo** so future deletions are git-visible/self-recoverable instead of silently breaking hooks. **Do NOT re-apply `--skip-worktree` to `.claude/hooks/` here** (and don't let `acme-worktree configure` quietly re-flag them without flagging it). This is the opposite of the symlink-shared-worktree case above, where the bits are load-bearing — the choice is context-specific: bits ON for symlink-shared worktrees, bits OFF for a real-dir primary checkout.

**RECURRED 2026-06-11 in `acme-platform-testing`** (a real `.claude/` dir whose original symlink→main got replaced; only `block-dangerous-commands.sh` of 34 hooks was materialized → ~23 referenced hooks 404'd on every tool call with "No such file or directory", `git status` clean because all 858 tracked `.claude/*` files carried `S` bits, and `.claude` was in the per-worktree `info/exclude`). First did the hooks-only recovery (`git ls-files -z .claude/hooks/ | xargs -0 git update-index --no-skip-worktree` → `git checkout -- .claude/hooks/`; empty status after clearing bits confirmed the tracked versions were byte-identical to main's — so a `cp -p` from `acme/.claude/hooks/` is a valid stopgap, but ALWAYS finish by clearing the bits so it stays self-recoverable).

**Then Milos said "turn it off … to be visible to git and you also" → extended bits-off to ALL of `.claude` in this worktree:** `git ls-files -z .claude/ | xargs -0 git update-index --no-skip-worktree` (858 files, 813 were absent/masked) → `git checkout -- .claude/` to MATERIALIZE the full tracked tree from HEAD. End-state: 0 S-bits, full `.claude` present + git-tracked + clean, future `.claude` edits now show in `git status` (the point — visibility for both git and Claude). `.claude` stayed in `info/exclude` so only truly-untracked scratch (the unique `.claude/epics/platform-dev-stabilization/`, settings.json) stays hidden; tracked framework files are fully visible. **Caveat after this:** a blanket `git add -A` can now sweep `.claude` edits into commits — scope adds explicitly. Reversible anytime via `acme-worktree configure` (re-symlinks + re-flags). Do NOT `rm -rf .claude` to re-symlink: `platform-dev-stabilization` epic dir exists ONLY here, not in main.
