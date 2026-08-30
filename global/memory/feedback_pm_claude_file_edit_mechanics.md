---
name: feedback_pm_claude_file_edit_mechanics
description: "How to safely edit + commit PM .claude files (epic.md/prd/task) in acme — real-vs-symlink worktree, fresh-worktree SKIP_HOOKS path, docs-only **/*.md admin-merge deadlock, frontmatter |-block YAML rule"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000008
---

Editing a git-tracked PM file under `.claude/` (epic.md, prd.md, task files) in the acme repo. **Why:** `.claude/` tracking + branch protection + frontmatter YAML each have a non-obvious footgun that cost a debugging detour 2026-06-03 (the "phantom 90% epic.md", a strict-YAML parse failure, and a BLOCKED merge). **How to apply:**

1. **`.claude/` is GIT-TRACKED in the acme repo, but only committable from a REAL worktree.** In the PRIMARY worktree `$PROJECT_ROOT` it's a real dir (`git ls-files -v .claude/.../epic.md` = `H`, normal — no skip-worktree). In session/agent worktrees it's a `.claude` SYMLINK → primary (`git status` shows `?? .claude`, untracked) → you CANNOT `git add`/commit `.claude` from a symlink worktree. See [[feedback_claude_skip_worktree_bits]] / [[feedback_claude_symlink_blocks_git_reset]].
2. **Cleanest edit path = a fresh throwaway worktree off origin/main:** `git worktree add <path> -b <branch> origin/main` (real tracked `.claude`, fresh index, no symlink/skip-worktree) → edit → `SKIP_HOOKS=1 git commit` (fresh worktree has no node_modules so husky/gitleaks can't run — SKIP_HOOKS is sanctioned; NEVER `--no-verify`) → push → PR → merge → `git worktree remove`. Do NOT edit/commit in the PRIMARY worktree: it's often BEHIND origin and shared with concurrent sessions (untracked `.agents/`/`.codex/`/`.opencode/`); an uncommitted edit there gets reverted on the next checkout/pull — that's the "phantom newer epic.md" trap (a value you saw that was never committed). To pick the change up in the primary afterward: `git -C <primary> pull --ff-only origin main` (verified clean ff, no conflict, epic.md updates in place).
3. **Docs-only required-check DEADLOCK: a `.claude/**.md` (or ANY `**/*.md`) PR is path-skipped by BOTH `ci.yml` AND `platform-pipeline.yml` (`paths-ignore: **/*.md`) → both required `ci-gate` AND `platform-ci-gate` sit "Expected" → mergeStateStatus=BLOCKED → `gh pr merge --squash --admin` required** (only `Validate Terraform` + informational gitleaks/Trivy run). Admin here bypasses only structurally-unrunnable gates, nothing substantive. See [[path-filtered-required-checks]].
4. **PM frontmatter is read by a LENIENT/regex reader, not strict YAML.** Existing `last_session:` / multi-line PLAIN scalars contain ` #nnn` (issue refs) which STRICT YAML parses as a COMMENT → the file fails `yaml.safe_load` (pre-existing; the lenient PM reader tolerates it). When you touch those lines, convert to a `|` literal block scalar (like `phase_status:` already is) so `#` stays literal + the frontmatter is strictly valid. Verify: extract between the `---` fences and `python3 -c 'import sys,yaml;yaml.safe_load(sys.stdin)'`.
5. **`/pm:epic-refresh` (the sanctioned PM tool) must run from the PRIMARY worktree** and recomputes progress % from the TASK-FILE decomposition only — it does NOT see later GitHub-only follow-up issues, so narrative progress for those must go in an epic-issue comment regardless.

Verified end-to-end refreshing epic `ci-arc-parallelisation` 2026-06-03 (PR #1109, `--admin` squash `69ba037a`). See [[ci-arc-phase-c-state]], [[feedback_always_use_pm_workflow]], [[worktree-best-practices]].
