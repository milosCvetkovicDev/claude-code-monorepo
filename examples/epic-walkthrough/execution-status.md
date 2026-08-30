---
started: 2026-07-02T20:26:00Z
branch: epic/platform-trading-hardening
worktree: $PROJECT_ROOT-platform-trading-hardening
---

# Execution Status — platform-trading-hardening (#1623)

## Wave 0 — COMPLETE

- **#1624 RED baseline** — ✅ done. Deps installed; RED verified (`platform-trading-service:typecheck` fails only on 4 missing-impl modules, all deps green). Commits `12e56450` (ADRs), `02410251` (RED suite). Local only (not pushed — RED CI noise).
  - Gap carried: the high-volume perf seed script (AC4) → fold into #1630, which owns the list p95 baseline.

## Wave 1 pilot — #1625 VERIFIED GREEN (2026-07-03)

- **#1625 Inbound write-back consumer** — ✅ verified green by independent re-run (team-lead).
  - `invoice-writeback.tc` 3/3; `test:pact` 9/9; `test:unit` 517 pass; `test:bdd` loads (86 scenarios), invoice-write-back scenarios green (scenario-3 stops at `pending('009')` metric step — correct, task 009).
  - Commits (LOCAL ONLY, not pushed): `6c82628a` feat #1625, `0d1038e8` test #1625, `cf49ef83` **#1624 harness remediation**.
- **#1624 RED-baseline remediation (`cf49ef83`)** — pilot surfaced 3 systematic baseline defects (all real; team-lead initially mis-ruled the `$1` one, corrected via empirical run):
  1. `$1/$2/$3` → `?` — MikroORM raw `conn.execute` needs `?`, not PG `$1` (invoice-writeback / deal-list-filters / idempotency-key tc + trading.steps.ts).
  2. Escaped `\/` in cucumber `/api` step expressions — `/` = alternation operator → whole BDD suite aborted at load (hardening.steps.ts + pre-existing `deal-http-gap-fills.steps.ts` from merged #1471; **trading `test:bdd` was NOT gating CI**).
  3. Missing `.confirm()` in the seed — the line-item seed helper's default flag left the row in DRAFT while the step asserted CONFIRMED, so the scenario failed on its own fixture rather than on the missing behaviour.
     Baseline now fails for the RIGHT reasons. **RED verification lesson:** typecheck-only is insufficient — must RUN testcontainers.
- **No-regression proven:** full `test:integration` failed-set = ONLY other-task RED scaffolds (004/005/006/007/008) + pre-existing #1358 tenant-isolation tests. Tenant reds empirically confirmed pre-existing by running `reference-data.tc` at baseline `02410251` (identical 7 failures).

## Ready (unblocked by #1624 — baseline now CLEAN after cf49ef83)

- #1625 Inbound write-back consumer + inbox + parked messages (P0) — no conflicts
- #1626 Inventory consumer idempotency (P0) — no conflicts
- #1627 Quota-check serialization via PESSIMISTIC_WRITE (P0) — conflicts #1628
- #1629 Soft delete + delete/cancel audit — conflicts #1628, #1631
- #1630 List contract fidelity — filters, derived status, batch, CSV — conflicts #1631

## Blocked

- #1628 Safe mutations — optimistic locking + Idempotency-Key — conflicts #1627, #1629, #1631 (schedule solo)
- #1631 Command-endpoint completeness — conflicts #1628, #1629, #1630 (schedule solo)
- #1632 Integration-pipeline observability + tenant-config wiring audit — depends_on #1625, #1626
- #1633 Production verification — depends_on ALL

## Conflict-aware wave plan (graph-coloured; each task in its OWN worktree)

- **Wave 1 (parallel, mutually non-conflicting):** #1625, #1626, #1627, #1629, #1630
- **Wave 2:** #1628 (conflicts 3 of Wave 1)
- **Wave 3:** #1631 (conflicts #1628/#1629/#1630)
- **Wave 4:** #1632 (after #1625+#1626 GREEN & merged)
- **Final:** #1633 prod-verify + 48h soak

## Model note

Epic-start's "all agents in ONE shared branch" is unsafe here: 5 conflict edges + git-add
races. Using per-issue worktrees off epic/platform-trading-hardening, merged sequentially.

## Completed

- #1624 (RED baseline) — 2026-07-02; harness-remediated (`cf49ef83`) — 2026-07-03
- #1625 (Inbound write-back consumer) — pilot, VERIFIED GREEN 2026-07-03 (local; push/PR + GitHub issue-close held for user)
