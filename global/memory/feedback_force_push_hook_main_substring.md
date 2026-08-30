---
name: feedback_force_push_hook_main_substring
description: "block-dangerous-commands hook false-positives on force-push to feature branches whose NAME contains \"main\""
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000035
---

The PreToolUse hook `.claude/hooks/block-dangerous-commands.sh` blocks any Bash command matching the regex `git push.*--force.*main`. This is a **substring match on the whole command string**, so it false-positives whenever the *feature branch name* contains "main" — e.g. `git push --force-with-lease origin fix/ci-serialise-required-**main**-test-oom` is blocked even though it targets a feature branch, not `main`. (Compound commands make it worse: a `git rebase origin/main` earlier in the same `&&`/newline block also supplies the "main" token.)

**Why:** the guard exists to stop force-pushing to the real `main` branch; it can't distinguish "main" the branch from "main" inside a branch name.

**How to apply:** when a feature branch's name contains the substring "main" and you need to update it after a rebase, DON'T force-push. Instead bring it up to date without rewriting history:
- `gh pr update-branch <PR#>` — merges base into the PR branch server-side (adds a merge commit; harmless under squash-merge). No local force-push, no hook trip. **Preferred.**
- or `git merge origin/main` locally then a plain `git push origin <branch>` (fast-forward of remote, no `--force`).
- or name branches without the "main" substring up front.

Confirmed 2026-05-29 shipping PR #1004 (`fix/ci-serialise-required-main-test-oom`). Earlier force-pushes that session succeeded because their branch names (`fix/consumer-reconnect-robustness-976`, `fix/bootstrap-harness-pre-declare-exchanges-978`) had no "main" substring. Related: [[feedback_explicit_push_target]].
