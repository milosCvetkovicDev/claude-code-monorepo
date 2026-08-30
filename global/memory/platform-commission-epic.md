---
name: platform-commission-epic
description: "platform-commission epic (#1534) state — Phase-1 RED landed,"
metadata:
  node_type: memory
  type: project
  originSessionId: 00000000-0000-0000-0000-000000000057
---

**Epic #1534** (`.claude/epics/platform-commission/`, branch `feat/platform-commission`), 10 tasks, status **in-progress ~15%** as of 2026-07-02. Goal: bring the existing commission service onto the new platform — FE on `@acme/ui` + backend wiring/authz + a parity cutover off the legacy stack. Does NOT rebuild the domain itself.

**Landed:** Phase-1 RED suite + event-contract shapes + ADRs (commit `7a0b6d4a`). Backend RED intact & red-by-design (stop-condition for tasks 002–006 holds).

**#1533 (finance-UI, `70f0b5ad`) overlap — materially changed 001/002/003/006/007/008.** #1533 shipped an overlapping-but-narrower slice: backend `GatewayIdentityGuard` (headers→`request.user`) + coarse `@Roles`/`RolesGuard` + `CommissionFeatureGuard` + report `resolveReportScope`; frontend `@acme/ui` surface — `api/commission.ts` (**singular**), pages Periods/Detail/Payouts, routes+nav+ThemeProvider, ~38 GREEN tests. It does NOT meet the epic ACs but pre-builds parts; the epic's own RED specs target different names (`src/modules/commission-platform/guards/**`, `api/commissions.ts` **plural**) so they stay RED.

**GREEN-phase reconciliations (net-new since decompose):** (1) event-contract **UNION → one wire shape** in `libs/platform/event-contracts/src/lib/commission-events.ts` before any producer is wired (task 006); (2) FE module naming `commission` (shipped) vs `commissions` (RED) — task 007; (3) **`extractTenantId` reads unpopulated `req.tenantId`** while the guard sets `req.user` → repoint (top blocker, task 002); (4) **ADR renumber**: two ADRs drafted on the branch had taken a number main meanwhile allocated to a different ADR, so both were renumbered at GREEN — an ADR id claimed on a long-lived branch is not reserved; (5) **outbox advisory-lock = 900008** (main #638 standard), NOT the epic's earlier 900012.

**Security gap (class):** where authorisation is opt-in per controller, a state-transition endpoint can ship with no guard at all and nothing fails — the gap is invisible until someone audits every controller rather than the diff. Found and closed under task 003; see [[platform-gateway-trust-unsigned-headers]].

**Longest pole:** task 004, the legacy-parity calculation (the rules it reimplements are business policy and are not part of this export) — not started; blocked on the upstream `trading.deal.locked` event, whose payload does not yet carry the per-line detail the calculation reads.

`readiness-report.md` is a pre-merge snapshot (stale ADR numbers, left as historical). Related: [[platform-finance-ui-epic]], _(removed — business-only)_, _(removed — business-only)_, [[platform-outbox-atomicity-pattern]], _(removed — business-only)_.
