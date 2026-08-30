---
name: feedback_audit_workflow_stale_worktree
description: 'When auditing MERGED code with a review workflow, sync the working tree to origin/main FIRST — stale checkouts produce false "not implemented" findings'
metadata:
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000009
---

When running a multi-agent review/verification workflow against code that is already MERGED, ensure the local working tree is current (`git merge --ff-only origin/main`, or have agents read via `git show origin/main:<path>`) BEFORE the audit.

**Why:** workflow review agents default to reading the CWD working tree via the Read/Grep tools. If that checkout is STALE (an ancestor of origin/main — e.g. local `main` left behind after PRs merged), agents audit the PRE-merge files and report the delivered work as "not implemented" — empty-stub libs, leftover placeholders, unguarded endpoints. Worse, same-tree adversarial verifiers read the SAME stale files and "CONFIRM isReal=true", so the false positives survive verification. In the Platform identity epic audit (2026-06-15), the `integration` unit raised 3 CRITICALs ("auth-client empty stub", "user-from-jwt placeholders", "/internal/\* unauthenticated") that were all artifacts of a tree at HEAD `1242aee3` (ancestor of origin/main `7973f812`); origin/main had the real implementations. Units that explicitly used `git show origin/main:` (e.g. the #1279 reviewer) got it right and even flagged the staleness.

**How to apply:** (1) at audit start, check `git merge-base --is-ancestor HEAD origin/main` — if true, FF the tree (or fetch + checkout the exact ref under review) before launching the workflow; (2) put "read the code via `git show origin/main:<path>`, the working tree may be stale" in the reviewer brief when auditing merged refs; (3) treat any "X is not implemented / is an empty stub / still has placeholders" finding on supposedly-merged work as a stale-checkout suspect — reconcile against origin/main before reporting. Related: [[feedback_review_subagents_mutate_git_state]], [[feedback_subagent_no_node_modules_skips_verification]].

**Recurrence 2026-06-20 (direct reads, not a workflow):** the PRIMARY worktree `$PROJECT_ROOT-platform-identity` is parked on the STALE branch `fix/platform-auth-1268-followups` (`660d0f9a`, a pre-#1269 ancestor of origin/main). I read `mfa-verify.use-case.ts` / `auth.controller` from it with my OWN Read/Grep (not a subagent) and concluded "MFA-complete issues no session — a bug vs BDD line 88", surfaced it to the user, and they made a decision on it — all WRONG: origin/main (#1269) fully mints the session + sets cookies on `/auth/mfa/verify`. Lesson: the trap isn't workflow-specific — ANY read from the primary worktree is stale-prone. For Platform source-of-truth, read from an origin/main-based worktree (the active fix worktrees under `/private/tmp/` or `$PROJECT_ROOT-*` are usually freshest) or `git show origin/main:<path>`; before claiming "not implemented / is a bug" on Platform code, confirm the worktree's HEAD is not an ancestor of origin/main (`git -C <wt> merge-base --is-ancestor HEAD origin/main`).
