---
name: acme-worktree-best-practices
description: Behavioural rules for git worktree discipline + acme-worktree script — one-branch-per-worktree, branch-from-origin/main, lifecycle, alignment, plus when to use acme-worktree vs Claude Code agent-isolation worktrees. The script ~/.local/bin/acme-worktree is canonical for procedures.
type: feedback
originSessionId: 00000000-0000-0000-0000-000000000050
---
## Worktree behavioural rules

### 1. One worktree per branch — main is sync-only

Git enforces one worktree per branch. The worktree holding `main` is treated as sync-only — never edit, never commit there. All real work happens on feature branches in dedicated worktrees.

**Why:** trunk-based + squash-merge means any direct main commit becomes orphaned the moment a PR merges. `--ignore-other-worktrees` races the index/refs. As of 2026-04-30, `acme-urgent` is the main holder.

**How to apply:** start new work via `acme-worktree create <name>`. Don't `git checkout main` inside a feature worktree; use `acme-worktree align <name>` to pick up latest main.

### 2. Branch new worktrees from `origin/main`, not local main

`acme-worktree create` (post-2026-04-30 patch) runs `git fetch origin main` then `git worktree add ... -b <name> origin/main`. Direct invocations of `git worktree add` should follow the same pattern.

**Why:** branching from stale local `main` — or worse, from whatever the primary worktree happens to be checked out to — silently produces drift that only surfaces hours later in CI.

**How to apply:** trust the script. Raw equivalent: `git fetch origin main && git worktree add ../path -b name origin/main`.

### 3. Delete worktrees after PR merge — except track branches

`acme-worktree remove <name>` kills the tmux session, removes the dir, deletes the matching local branch (if name-match), and auto-prunes `~/.claude/projects/-<project-root-slug>-<name>/`.

**Keep:**
- Main holder (permanent)
- Long-running track branches: `platform`, milestones (`m2-s1`, etc.) — until milestone done
- Active in-progress feature — until merged

**Why:** stale worktrees ≈ 5-10 GB each on this monorepo. Instance numbers cap at 10. Env files, ports, Docker projects accumulate.

**How to apply:** within hours of `gh pr merge`, run `acme-worktree remove <name>`. Periodically, `acme-worktree list` and audit.

### 4. Align long-running branches periodically

`acme-worktree align <name>` does fetch + interactive prompt: rebase (default for local-only branches, linear history) or merge (default for branches with remote tracking, avoids force-push). Refuses if dirty.

**Why:** long-running branches that don't pull main regularly diverge until merge becomes painful. Rebase rewrites history (force-push needed); merge preserves it.

**How to apply:** weekly or before resuming work after a pause. After rebase: `git push --force-with-lease`. After merge: `git push`.

## When to use `acme-worktree` vs Claude Code agent-isolation

These don't compete — they're for different lifecycles:

- **`acme-worktree create <name>`** — human-paced, long-lived dev worktrees with port allocation, env files, multi-instance dev setup. Use when starting feature work locally.
- **`Agent(isolation: "worktree", ...)`** — ephemeral, agent-initiated sandbox at `<repo>/.claude/worktrees/agent-*`, auto-cleaned if the agent makes no changes. Use when an agent needs an isolated try-and-revert environment.

Don't repurpose one for the other. Agent-isolation is wrong for dev work (no env/port setup); `acme-worktree` is wrong for one-off agent sandboxes (overkill, persists across sessions). Auto-prune in `acme-worktree remove` already absorbs orphaned agent-worktree project dirs at `~/.claude/projects/-<project-root-slug>--claude-worktrees-*`.

## Script reference

`~/.local/bin/acme-worktree help` is the canonical command list. Key behaviours:

- `create <name>` — interactive prompt for feat/fix/chore/none/other branch type
- `create <name> <existing-branch>` — attaches a worktree to an existing branch (PR review)
- `open` — interactive picker over all acme-* worktrees
- `align` — interactive rebase vs merge prompt
- `remove` — categorizes uncommitted state: safe (cache: `.remember/`, `node_modules/`, `dist/`, `coverage/`, `.next/`, `out/`, `*.log`, `*.tsbuildinfo`) discarded silently; valuable (anything else) requires typing 'yes'
- `remove` — auto-prunes the orphaned `~/.claude/projects/-<project-root-slug>-<name>/` dir

CLAUDE.md memory at `~/.claude/projects/-<project-root-slug>/memory/` is shared across all worktrees by hardcoded path — survives any worktree removal.
