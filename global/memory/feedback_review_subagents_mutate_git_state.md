---
name: feedback_review_subagents_mutate_git_state
description: "Review-board subagents given Bash + repo access can `git checkout`/stash/reset the SHARED working tree, leaving the main session on the wrong branch. Re-check branch after any review workflow."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000011
---

When fanning out a code-review Workflow whose agents have **Bash + project access**, an agent can mutate **shared git state**. Observed 2026-05-31: during an expert review of PR #1012 (#867) and PR #928 (#869), a verifier ran `git checkout fix/als-chaos-coverage-wave2` to inspect #928's on-disk files, leaving the **main session's working tree on the wrong branch**. Subsequent `Edit`s failed with "File does not exist" because the #867 files only exist on the #867 branch (the commit itself was safe at the branch tip).

**Why:** the agents share one worktree with the main session; `checkout`/`stash`/`reset`/`add` from any agent are global side effects.

**How to apply:**
- Give review agents the **diff FILE** (`/tmp/*.diff`) as the source of truth and **explicitly forbid mutating git state** (no `checkout`/`stash`/`reset`/`add`/`commit`) in the prompt, OR use read-only agent types (`Explore`/`adversarial-reviewer`), OR run with `isolation: 'worktree'`.
- After ANY review/analysis workflow, run `git branch --show-current` before resuming edits; if it moved, `git checkout <my-branch>` (the tree is usually clean since agents only read). Related: [[feedback_subagent_briefs_need_hard_rules]], [[feedback_subagent_git_add_race]].

**RECURRED 2026-06-03 (CNPG waves I/E/H review), worse symptom + confirmed fix.** A panel of `review-tech-lead`/`review-enterprise-architect`/`review-test-architect` agents — prompt said "use `git diff`/`git show`, read-only" but did NOT forbid git outright — and one agent ran `git checkout` MID-RUN while the main session was committing Wave H. Result was a hard `fatal: cannot lock ref 'HEAD': is at <X> but expected <Y>` that **aborted the in-flight commit and discarded its staged tree** (worse than just "wrong branch"). Telling agents the source is a diff command is NOT enough — they improvise `checkout` to read files, and even `Explore`/`review-*` types have Bash. **The fix that worked:** pre-write each branch's `git diff origin/main...<branch>` to `/tmp/review-diff-<x>.txt` (for an all-additions slice the diff contains every new file's full body), and prompt: *"HARD CONSTRAINT: do NOT run ANY git command; read the change set from <file>; use Read/Grep/Glob read-only for context."* Re-ran the same 13-agent panel that way — zero git contention. Also: never do main-worktree git ops (commit/checkout) while a non-isolated review workflow is live; stop it (`TaskStop`) or use a separate worktree.
