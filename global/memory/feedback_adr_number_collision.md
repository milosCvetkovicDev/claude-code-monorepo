---
name: adr-number-collision-on-parallel-prs
description: Two PRs drafted in parallel can both claim the same ADR-NNNN slot. The PR that lands second on main needs to renumber AND fix every reference. Caught only when merging origin/main back.
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000058
---

**Rule**: When merging `origin/main` back into a long-running branch that introduces a new `docs/adr/NNNN-*.md`, check whether main has gained a different ADR with the same number while your branch was open. If yes, renumber YOURS to the next-available slot BEFORE the merge commit, and update every reference.

**Why**: 2026-05-26 incident on PR #912. My PR drafted ADR-0042 (platform-dev-cluster-vendor-selection) on 2026-05-25. PR #926 drafted ADR-0042 (testcontainers-class-stays-on-ubuntu-latest) in parallel and landed on main first (2026-05-26 09:53). The collision surfaced only as a mechanical conflict in `docs/adr/README.md`, masking the substantive issue: two files with the same ADR number on disk after the merge would compile fine but be semantically wrong (ADR numbers must be unique).

**How to apply**:
- Before running `git merge origin/main` on any branch that adds a `docs/adr/NNNN-*.md` file, run `ls docs/adr/NNNN-*.md` on origin/main first. If a different file exists at the same slot, you have a collision.
- To resolve: `git mv docs/adr/NNNN-mine.md docs/adr/MMMM-mine.md` where MMMM is next-available. Update:
  - The file's own title (`# ADR-NNNN:` → `# ADR-MMMM:`); add a renumbering note explaining the history (date + reason + reference to the other ADR).
  - All references in your branch's docs (HTML, MD, other ADRs). `grep -rn "ADR-NNNN\|NNNN-mine"` is the fastest sweep.
  - `docs/adr/README.md` — add your new entry after theirs in the main table; remove your old entry from the conflict markers.
  - The categorical breakdown table further down in `docs/adr/README.md` (Platform Platform / CI/CD Platform / etc.) — add your new entry in the right category.
- Commit the rename as a single coherent commit BEFORE the merge commit, so the merge resolution is purely the `docs/adr/README.md` index reconcile.
- 18 spots needed updating in the migration-assessment HTML alone. Use `replace_all: true` on Edit.

**Detection cue**: if `gh pr view <num> --json mergeStateStatus,mergeable` returns `CONFLICTING/DIRTY` after main has moved on, run `git fetch && git merge-tree --name-only origin/main HEAD` to see the conflict files. If `docs/adr/README.md` appears in the list, check for an ADR-number collision before resolving.

**Related**: [[worktree-best-practices]] (delete after merge — but the ADR collision can survive even into a clean post-merge state if not caught during the merge).
