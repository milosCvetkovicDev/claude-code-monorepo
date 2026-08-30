---
name: feedback-one-pr-for-review-fixes
description: "For multi-finding review-fix campaigns (e.g. closing N issues from a multi-expert review), use ONE bundled PR — NOT N small PRs in parallel."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000047
---

**Rule**: When fixing multiple findings from a single review/audit (e.g. epic #631's "6 CRIT + 15 HIGH" closeout), bundle them into ONE PR. Do not stack many small PRs in parallel.

**Why**: 2026-05-20/21 the epic #631 closeout campaign opened 14 PRs (#847–#861) — one per finding plus a vitest fix. Concrete costs the user hit:
- Self-hosted runner (`development-acme-runner`, 2 runners) saturated; jobs queued serially for hours.
- VM scheduled-shutdown at 17:00 UTC killed in-flight jobs → zombie `in_progress` runs blocked the runners for the next ~18 hours until manually `gh run cancel`'d.
- Stale rebases all morning: every merge of one PR meant the other N–1 had to fetch/rebase/force-push.
- Each PR's CI failure had to be diagnosed in isolation; flaky `platform-trading-service:test` failures looked like real bugs until cross-correlated.
- Repeated tasks: 14× rebase, 14× CI wait, 14× admin-merge, 14× local branch cleanup.
- One real bug (#856 `lockedDeal.lock is not a function`) was indistinguishable from environment flakes until a clean local run isolated it.

User feedback verbatim (2026-05-21): "the idea to have multiple small PRs was bad, don't do it again, try to scope it in one PR".

**How to apply**:
- For multi-finding closeouts driven by a single tracking issue (#846-style), draft one PR that addresses all findings in logically grouped commits.
- Acceptable to split ONLY when changes touch genuinely independent bounded contexts AND review benefits outweigh CI cost (e.g. one infra-only PR + one code-only PR).
- Do NOT split because "each finding is a separate concern" — the review tracking issue already enumerates them, and the PR body can do so too.
- Single PR also makes the systemic-flake-vs-real-bug distinction easier: if all tests pass on one branch, you have one signal, not 14 noisy ones.

Related: [[feedback_cross_poc_red_scaffolds_break_prs]] (also bites you when PRs share base scaffolding).
