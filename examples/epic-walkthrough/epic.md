---
name: platform-trading-hardening
status: backlog
created: 2026-07-02T11:30:51Z
progress: 0%
prd: .claude/prds/platform-trading-hardening.md
architecture: .claude/epics/platform-trading-hardening/architecture.md
github: https://github.com/initech-trading-platform/acme/issues/1623
updated: 2026-07-02T20:00:46Z
---

# Epic: platform-trading-hardening

## Overview

Close the verified gap between "functionally complete" and "enterprise-ready" in the Trading BC backend (trading-service + inventory-service). Five workstreams: (A) event-integration integrity — consume the inbound event, inbox/dedup on both sides, parked messages; (B) concurrency safety — serialized quota checks, optimistic locking, idempotency keys; (C) data governance — soft delete + audit; (D) contract fidelity — server-side list filters including the derived status, bounded batch action + export, the transitions that have no command endpoint; (E) observability — integration-pipeline metrics + alerts, tenant-config wiring audit. Backend-only; FE epic #1439 consumes the results.

The approach is maximally **reuse-driven**: every new capability extends an existing, shipped mechanism rather than introducing a new one.

## Architecture Decisions

**Fixed (reuse, no debate):**

- **Consumer machinery:** trading-service's new consumer mirrors inventory-service's existing `@acme/queue` consumer (`trading-event-consumer.ts` pattern) — same bootstrap, versioned routing keys (ADR-0036), same error semantics.
- **Inbox pattern:** one `processed_event` table per service (schema-local, ADR-0013), insert transactional with the state change via the caller-EM outbox convention (ADR-0018/0037 mirror image). Same table shape in trading and inventory.
- **Filters:** list filtering reuses the shipped `parse-list-filters` bracket parser (ADR-0061) — a wiring change, not new parsing code.
- **Audit:** delete/cancel/write-back entries reuse the existing activity recorder (ADR-0062).
- **Optimistic locking:** MikroORM native `@Property({ version: true })` on mutable aggregates; stale write surfaces MikroORM's `OptimisticLockError` mapped to 409 `STALE_WRITE`.
- **Soft delete:** MikroORM global filter (same mechanism as the tenant filter) on `deletedAt`; physical `@Delete` handlers switch to setting `deletedAt`.
- **CSV export:** streams the existing list query path with filters applied — no new read model.
- **Additive contracts only:** response envelope `{data, meta}` unchanged; `version`, the derived `status`, and the new fields are additive.

**Deferred to `/pm:arch-create` (one ADR each):**

1. **Quota serialization mechanism** — `pg_advisory_xact_lock(hash(sourceLineId))` vs `SELECT … FOR UPDATE` on the source rows vs accelerating the ADR-0012 saga (reconciles ADR-0022's "intentional debt" note).
2. **Optimistic-locking surface** — version-in-DTO vs `If-Match`/ETag header convention (platform-wide precedent).
3. **Idempotency/inbox conventions** — key scoping (tenant+endpoint+key), response-replay storage, TTL, parked-message store vs DLQ.

## Technical Approach

### Frontend Components

None. Backend-only epic; #1439 consumes new filters/commands/fields as they land.

### Backend Services

**trading-service:**

- New `integration/` consumer module: RabbitMQ subscription to the accounting exchange, an inbound-event handler that applies the state change, re-derives the parent status, writes the activity entry and inserts the inbox row **in one transaction**, plus a parked-message store for events whose target is in the wrong state.
- The availability-check call sites wrapped in the serialization primitive chosen at arch-create.
- `version` column on every mutable aggregate (+ DTO plumbing, 409 mapping).
- `IdempotencyInterceptor` on state-changing mutations (the creates, the lock, the batch lock) backed by a tenant-scoped store.
- `deletedAt` + global filter across trading entities; convert the physical-delete endpoints; add initial-state-only DELETE guarded by live references.
- List endpoint: wire `parseListFilters` (status including the derived one, owner id, related-entity id, createdAt range); expose the derived status in the list payload; add the missing command endpoints, an explicit create, a lightweight summary read, the bounded batch action (per-item results) and the CSV export.
- The child-entity contact fields (migration + DTO + ownership validation).

**inventory-service:**

- Inbox ledger + dedup wrap around every existing `trading.#` handler; redelivery metrics.

**Migrations (consolidated, one per service per concern):** trading — inbox + parked tables; version columns; `deletedAt` columns; the new child fields. inventory — inbox table.

### Infrastructure

- RabbitMQ topology: trading-service queue + binding on the accounting exchange (topology-operator resources; per-BC permission update — operator-applied, listed as dependency).
- Grafana: an integration-pipeline dashboard (outbox lag, consumer lag/redeliveries, parked count, lock rate, rejected writes, write-back count) + alert rules; runbook section in `docs/platform/operations/monitoring-runbook.md`.
- No new services, no new datastores (idempotency/inbox live in each service's PG schema; Redis 6.0-safe if cache is chosen at arch-create).

## Implementation Strategy

- **Phase 0 (ceremony):** arch-create → 3 ADRs; tests-generate → RED suites from the PRD's Gherkin features.
- **Phase 1 (P0 correctness):** write-back consumer + trading inbox; inventory idempotency; quota serialization. Each an independently mergeable slice behind green CI.
- **Phase 2 (P1 safety + governance):** optimistic locking + idempotency keys; soft delete + audit.
- **Phase 3 (P1 fidelity + ops):** list filters, batch and export; the missing command endpoints; observability + config audit.
- **Phase 4:** production verification (dev-platform smokes + 48 h soak) — gate for epic close.
- **Risk mitigation:** consumers are disable-able by removing the queue binding (no redeploy); the soft-delete filter ships default-on behind a targeted testcontainers suite before any endpoint is converted; version columns land as an additive migration before DTO enforcement; concurrency primitives are proven by dedicated testcontainers races before being wired into services.
- **Testing:** TDD throughout — RED features first (`/pm:tests-generate`), true-concurrency and double-delivery tests in testcontainers, a new message-pact (trading ⇐ accounting), a k6 list baseline at the benchmark seed size.

## Task Breakdown Preview

High-level task categories (≤10 tasks total; tests first, prod-verify last):

- [ ] **T1 — RED test suites:** BDD features + failing testcontainers/unit stubs for every PRD Gherkin feature (concurrency races, double delivery, write-back E2E, filters, batch action).
- [ ] **T2 — Inbound write-back (trading):** consumer bootstrap + inbox + parked store + the handler with its transition, re-derivation and activity entry (FR-1..3).
- [ ] **T3 — Inventory consumer idempotency:** inbox ledger + dedup wrap on all `trading.#` handlers + redelivery metrics (FR-4).
- [ ] **T4 — Quota-check serialization:** the arch-chosen primitive around the availability check on create and update (FR-5).
- [ ] **T5 — Safe mutations:** optimistic version columns + 409 STALE_WRITE; Idempotency-Key interceptor + store on state-changing mutations (FR-6/7).
- [ ] **T6 — Soft delete + audit:** `deletedAt` + global filter, convert the physical deletes, add initial-state-only deletes with a live-reference guard, activity entries (FR-8/9).
- [ ] **T7 — List contract fidelity:** bracket filters + the derived status in the list payload, bounded batch action (partial results), CSV export (FR-10/13).
- [ ] **T8 — Command-endpoint completeness:** the lifecycle transitions with no endpoint, the explicit create and summary read, the new child fields + ownership validation (FR-11/12).
- [ ] **T9 — Observability + config audit:** metrics, dashboard, alerts, runbook; verify/wire the real `TenantConfigProvider` (FR-14/15).
- [ ] **T10 — Production verification:** dev-platform smoke suite (write-back, double-claim race, idempotency replay, soft delete, filters, alert fire) + 48 h soak + sign-off.

## Dependencies

- **accounting-service** `invoice.processed` events + `libs/platform/event-contracts` (merged, stable).
- **RabbitMQ topology change** (trading queue on the accounting exchange) — operator-applied; prerequisite for T2 deploy, not for its tests (testcontainers).
- **arch-create ADRs** (3) — prerequisite for T4/T5 implementation choices.
- Open PRs landing independently: #1548, #1549. Referenced, not absorbed: #1559, #1586, #1510, #1581.
- **tenant-service** lookup for the config audit (T9).

## Success Criteria (Technical)

- 0 quota breaches across ≥100 repeated parallel-claim CI runs; 100% single-application under forced duplicate delivery.
- Write-back E2E green in CI and observed in dev-platform (transition applied ≤30 s after the event).
- No remaining physical-delete paths on trading aggregates (grep gate).
- List p95 < 500 ms with filters at the benchmark seed size; a full-cap batch action < 10 s.
- All RED suites flipped green; no regression in existing trading/inventory/Pact suites; no new Sonar critical/blockers.
- Six metric families live in Grafana; every alert rule proven by synthetic trigger.

## Estimated Effort

- **Timeline:** ~4–6 weeks single-engineer equivalent; Phases 2–3 tasks (T5–T9) parallelisable across worktrees after Phase 1 merges.
- **Critical path:** arch-create ADRs → T2 (consumer infra, unlocks T3 patterns) and T4 (serialization) → T10 soak.
- **Sizing:** T2, T5, T6, T7 are L (2–4 days each); T3, T4, T8, T9 are M (1–2 days); T1 M; T10 S+soak.

## Architecture

Full document: `.claude/epics/platform-trading-hardening/architecture.md` (decision matrix §2, implementation patterns §3, FR→file map §4.2, DDD design §6).

Key decisions (arch-create 2026-07-02, all Accepted):

- **ADR-0066** — quota-check serialization via `PESSIMISTIC_WRITE` on the source-line rows, deterministic order (amends ADR-0022; the ADR-0012 saga stays the M3+ target).
- **ADR-0067** — optimistic locking: MikroORM native version column, `version` required in mutation DTOs, mismatch → 409 `STALE_WRITE` (**platform-wide convention**).
- **ADR-0068** — inbox `processed_event` + `idempotency_key` + `parked_message` as per-service PG tables, inbox insert transactional with the state change; DLX = transport backstop; Redis stays cache-only (**platform-wide convention**).
- Master architecture updated with the 0067/0068 platform conventions; trading + inventory are the reference implementations. ADR-0065 skipped (reserved by an in-flight branch).

## Tasks Created

- [ ] #1624 - RED test suites for all hardening workstreams (parallel: true)
- [ ] #1625 - Inbound write-back consumer + inbox + parked messages (trading) (parallel: true)
- [ ] #1626 - Inventory consumer idempotency (inbox + redelivery metrics) (parallel: true)
- [ ] #1627 - Quota-check serialization via PESSIMISTIC_WRITE on the source rows (parallel: true)
- [ ] #1628 - Safe mutations — optimistic locking + Idempotency-Key (parallel: true)
- [ ] #1629 - Soft delete + delete/cancel audit across trading aggregates (parallel: true)
- [ ] #1630 - List contract fidelity — server-side filters, derived status in list, bounded batch, CSV export (parallel: true)
- [ ] #1631 - Command-endpoint completeness for the remaining lifecycle transitions (parallel: true)
- [ ] #1632 - Integration-pipeline observability + tenant-config wiring audit (parallel: true)
- [ ] #1633 - Production verification — dev-platform smoke suite + 48h soak (parallel: false)

Total tasks: 10
Parallel tasks: 9
Sequential tasks: 1
Estimated total effort: 156 hours (~4–6 weeks single-engineer; T5–T9 parallelisable across worktrees after Phase 1)
