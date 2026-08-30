---
name: Concurrent subagent git-add race produces misattributed commits
description: When two subagents commit in parallel (even on disjoint file trees), their `git add` operations interleave on the shared index, producing commits whose title belongs to one stream and content belongs to the other. Stream isolation by file path is not enough — git's index is global.
type: feedback
originSessionId: 00000000-0000-0000-0000-000000000038
---
Concurrent subagents that each `git add` + `git commit` in the same worktree race on the shared index, even when their file scopes are disjoint.

**Why:** during the 2026-05-12 cnpg-outbox POC (issue #698), I launched Stream A (audit-service work) and Stream B (event-bus work) as parallel background subagents in the same `$PROJECT_ROOT-cnpg-outbox` worktree. Each had non-overlapping HARD RULES about which files to touch. But they both ran `git add <my-files>` then `git commit -m "..."` in their own turns, and the operations interleaved:

- Stream B's commit `d79c4279` was titled "ADR-0031 amendment for POC C4" — but its actual diff contained Stream B's `event-bus/src/lib/outbox-entry.factory.ts` + `entity.ts` + `index.ts` changes (no ADR-0031 file at all).
- Stream B's commit `715fc9f8` was titled "remove OutboxRelay default advisory-lock fallback (POC C1-prep)" — but it picked up Stream A's untracked `docs/adr/0031-amendment-poc-c4-audit-entry-userema.md` because the file was sitting in the working tree when Stream B staged its own changes.
- One of Stream B's intermediate commits (`d0aef88d`) was dropped entirely by a `git reset HEAD~1` that one of the agents ran between the other's commits.

Net result: file content was preserved, but commit attribution was completely scrambled. Required a soft-reset + atomic replay to clean up, then a force-push to two new branches.

**How to apply:**

1. **Don't run two mutating subagents in the same worktree.** If you must dispatch parallel streams in one issue, give each stream its own worktree (`acme-worktree create <stream-suffix> <branch>`) — git's index isolation comes from the worktree, not from file scope.
2. **OR** serialize the commit step: let each agent stage and commit one at a time, with a coordinator gating the order. Run them in parallel on read/edit work, but funnel the `git add`+`git commit` through a single sequenced phase.
3. **HARD RULES additions for any parallel subagent that commits:** "Before `git add`, run `git status --short` and abort if any file outside your declared file scope shows as `??`, `M`, or staged. Do not `git reset` ever — only the lead does."
4. Plan for the cleanup: pre-stage a soft-reset target commit BEFORE launching parallel committers, so you can rewind cheaply when (not if) a race occurs.

**Symptoms to recognise:**
- Commit titles in `git log --oneline` don't match the files in `git show --stat` for the same SHA.
- A "missing" commit that the agent reported it made — gone to a `git reset --hard HEAD~1` from a concurrent agent.
- A file that should be staged is suddenly showing as part of the other stream's commit.

**Cross-references:**
- [feedback_subagent_briefs_need_hard_rules.md](feedback_subagent_briefs_need_hard_rules.md) — covers infra-touching agents pushing unauthorized changes; this is the git-index analogue.
- Project memory `worktree-best-practices.md` — one-branch-per-worktree, fresh from origin/main, delete after merge.
