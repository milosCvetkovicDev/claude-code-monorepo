---
name: platform-trading-hardening
description: Enterprise-grade hardening of the Trading BC backend — event-integration integrity, concurrency safety, data governance, contract fidelity, and observability
status: backlog
created: 2026-07-02T11:25:29Z
---

# PRD: platform-trading-hardening

## Executive Summary

The Trading BC backend (trading-service + inventory-service) is functionally mature — the record lifecycles, the derived aggregate calculations, an irreversible lock with pessimistic locking, RBAC, tenant isolation, transactional outbox, Pact CDC, and BDD suites are all shipped. A gap analysis run against the as-built code rather than the docs found the residual distance between "works" and "enterprise-ready": the feedback loop from the context that owns the downstream state is not consumed, concurrent writers can jointly exceed a shared quota, event redelivery is not idempotent on the consuming side, there is no optimistic concurrency or request idempotency, deletes are physical, and several contract-defined commands and list filters are unimplemented. This epic closes those gaps against the standard a system of record is held to: effectively-once event processing, serialized invariants, lost-update prevention, safe retries, auditable retention, and operable observability.

_The artefacts below keep their structure and their engineering content, with neutral placeholders standing in for the original domain vocabulary. The placeholder lifecycle the scenarios are written against is defined once under Acceptance Criteria and used consistently from there on._

This PRD targets **verified residual gaps only**. It complements (and partially absorbs) the backlog milestone PRDs `platform-m3-trading-extended`, `platform-m3-inventory-service`, and `platform-m4-accounting`, which predate the as-built services.

## Problem Statement

**What:** five classes of enterprise-readiness gap. Each is stated as the failure mode rather than as a list of the endpoints that happened to exhibit it — the fix has to be the cross-cutting mechanism, not a sweep of call sites.

1. **Broken feedback loop** — where one context owns a state transition and another owns the record it lands on, a service that consumes no events at all cannot follow it. The producing side already published a contract-defined event; nothing subscribed, so the downstream status never advanced, commands that need to distinguish "advanced" from "not yet" could not, and the two contexts could not be reconciled.
2. **Concurrency unsafety** — an availability check implemented as an in-process sum, with no row or advisory lock on the rows it reads, lets two concurrent writers each see enough headroom and jointly exceed the limit. (It was carried as documented debt on the assumption a later saga would replace it; debt with a correctness consequence needs a date, not an assumption.) Separately, with no version column anywhere, concurrent PATCHes silently lose updates; and with no idempotency key on mutations, a client or gateway retry duplicates records.
3. **Unsafe redelivery** — an at-least-once broker plus consumers with no inbox ledger means a redelivery double-applies its effect. A reconciliation job catches it, but only after the fact.
4. **Data-governance gaps** — physical delete on some endpoints and no delete at all on others. Retention and auditability then depend on which controller a request happens to reach rather than on one rule the schema enforces everywhere.
5. **Contract infidelity** — the list endpoint offered pagination and sort only, with no server-side filtering, even though the shipped bracket-filter parser was already wired into another module; the derived status was absent from list payloads; and several contract-defined commands, plus the bounded batch operation and export, were unimplemented.

**Why now:** the frontend epic (#1439) is about to build the list and detail screens against this API — filters, the derived status in the list, and the missing commands are its direct unblockers. And every month of production-like usage without idempotent consumers and serialized invariant checks widens the window in which a corruption can occur and be unexplainable afterwards.

## User Stories

### US-1: Statuses follow the context that owns them

As a **platform operator**, I want a record's status to advance from the owning context's event rather than from a manual step, so that "advanced" and "not yet advanced" are distinguishable in this service and the two contexts can be reconciled instead of drifting.
**Pain today:** the terminal status never occurs; the other context's state is invisible here.

### US-2: A shared quota holds under concurrency

As an **API consumer**, when two writers claim against the same shared quota at the same moment, I want the platform to admit only what the quota permits, so the running total can never go negative and no caller is confirmed something the quota cannot cover.
**Pain today:** the availability check is race-prone; simultaneous requests can both pass.

### US-3: Operator trusts event redelivery

As a **platform operator**, I want every Trading/Inventory event consumer to be idempotent, so broker redeliveries (crash, nack, network) never double-apply an effect.
**Pain today:** no dedup ledger in inventory consumers; trading has no consumers at all.

### US-4: Concurrent editors don't silently overwrite each other

As an **Admin/API client**, when I submit an edit based on stale data, I want a clear conflict response instead of silently clobbering a colleague's change.
**Pain today:** last-write-wins on all PATCH endpoints.

### US-5: API clients can retry safely

As the **frontend (and any API client)**, I want to send an `Idempotency-Key` on state-changing mutations, so a timeout-and-retry never creates duplicate records or repeats a lock.
**Pain today:** retries duplicate records.

### US-6: Deletion is recoverable and auditable

As a **compliance reviewer**, I want deletions to be soft (row retained with `deletedAt`, excluded from every read, visible in the activity log), so history is never physically destroyed by a UI action.
**Pain today:** physical delete on some endpoints, no delete at all on others.

### US-7: Lists are filterable server-side

As **any user**, I want to filter the record list by status (including the derived status that is computed, not stored), owner, related entity, and created-date range, so a large book of records is workable without client-side hacks.
**Pain today:** API supports only pagination + sort.

### US-8: Bulk actions and export

As an **Admin**, I want to select multiple eligible records, act on them in one bounded request that reports per-item results, and export the filtered list as CSV.
**Pain today:** the action is one-at-a-time; no export.

### US-9: Every lifecycle transition is an explicit command

As an **API client**, I want each lifecycle transition exposed as its own command endpoint with its own permission and guard, rather than inferred from a general-purpose PATCH, so the allowed transitions are discoverable from the API surface and enforceable in one place.
**Pain today:** several transitions have no endpoint at all and return 404.

### US-10: Operator sees and is alerted on the integration pipeline

As a **platform operator**, I want metrics + alerts for outbox lag, consumer lag/redeliveries, parked messages, lock rate, and rejected writes, with `tenantId`/`recordId` on traces, so integration failures surface in minutes rather than at the next reconciliation pass.
**Pain today:** outbox/consumer health is invisible.

## Acceptance Criteria (Gherkin)

**Placeholder lifecycle used below.** A line item moves `DRAFT → CONFIRMED → READY → COMPLETED`. `DRAFT` is the only editable state, and the only one a line item may be deleted from; `READY` is the precondition the downstream context's event expects; `COMPLETED` is terminal and is reached *only* by consuming that event — no command endpoint sets it. A record's status is **derived** from its line items rather than stored: `OPEN` while any line is below `READY`, `LOCKABLE` once all of them are `READY`, `LOCKED` once the irreversible lock has been applied; a record may be deleted only while `OPEN`. Reverting a line moves it one step back, `READY → CONFIRMED`; a `COMPLETED` line cannot be reverted from this side.

```gherkin
Feature: Downstream status write-back (US-1, US-3)
  A line's terminal status follows the owning context's event, exactly once

  Scenario: An eligible line advances on the event
    Given line item "li-1" on record "rec-1" with status READY
    When accounting-service publishes "accounting.invoice.processed" for source entity "li-1"
    Then line item "li-1" has status COMPLETED
    And the parent record's status is re-derived from its line items
    And an activity entry for that event exists on record "rec-1"

  Scenario: Duplicate delivery is a no-op
    Given "li-1" already advanced to COMPLETED by event "evt-100"
    When event "evt-100" is delivered a second time
    Then "li-1" remains COMPLETED
    And no additional activity entry is recorded

  Scenario: An event for a line in the wrong state is parked, not applied
    Given a line item "li-2" with status CONFIRMED, one step short of READY
    When the same event arrives for "li-2"
    Then "li-2" remains CONFIRMED
    And the message is parked with reason "INVALID_STATE"
    And the parked-message metric increments
```

```gherkin
Feature: Concurrent claims cannot exceed a shared quota (US-2)

  Scenario: Two concurrent claims cannot jointly exceed the source quantity
    Given source line "src-1" with quantity 100 and 0 claimed
    When two create-allocation requests for 60 each against "src-1" execute concurrently
    Then exactly one request succeeds
    And the other fails with 409 "QUOTA_EXCEEDED"
    And the total non-cancelled claimed quantity for "src-1" is 60

  Scenario: A concurrent update and create respect the same guard
    Given "src-1" with quantity 100 and an existing allocation of 50
    When an update raising that allocation to 80 and a new allocation of 40 execute concurrently
    Then at most 100 is claimed once both have settled
```

```gherkin
Feature: Optimistic concurrency (US-4)

  Scenario: Stale update is rejected
    Given record "rec-1" at version 3
    And client A read "rec-1" at version 3
    When client B updates "rec-1" making it version 4
    And client A submits an update declaring version 3
    Then client A receives 409 with error code "STALE_WRITE" and the current version
    And client B's changes are intact

  Scenario: Version increments on every successful mutation
    Given record "rec-1" at version 4
    When it is confirmed successfully
    Then its version is 5
```

```gherkin
Feature: Idempotent mutations (US-5)

  Scenario: Retried create does not duplicate
    Given a create request with header "Idempotency-Key: abc-123"
    When the identical request is sent twice
    Then exactly one record exists
    And both responses return the same record id and status code

  Scenario: Same key with different payload is rejected
    Given "Idempotency-Key: abc-123" was used for payload P1
    When a request reuses "abc-123" with payload P2
    Then the response is 409 "IDEMPOTENCY_KEY_REUSE"
```

```gherkin
Feature: Soft delete (US-6)

  Scenario: A record in its initial state is soft-deleted
    Given an OPEN record with nothing referencing it
    When DELETE /api/v1/records/:id is called
    Then subsequent list and detail reads exclude it
    And the database row retains a deletedAt timestamp
    And an activity entry records the deletion

  Scenario: Delete blocked while live rows reference it
    Given an OPEN record whose line item is referenced by an active allocation
    When DELETE /api/v1/records/:id is called
    Then the response is 409 and the record is not deleted

  Scenario: Existing physical-delete endpoints become soft
    Given a line item in DRAFT status
    When its DELETE endpoint is called
    Then the row is retained with deletedAt and excluded from reads
```

```gherkin
Feature: List server-side filtering (US-7)

  Scenario: Filter by the derived status
    Given records "rec-a" (all lines READY), "rec-b" (one line DRAFT) and "rec-c" (already LOCKED)
    When GET /api/v1/records?filter[status]=LOCKABLE
    Then only "rec-a" is returned
    And its status field reads LOCKABLE, derived at query time rather than stored

  Scenario: Combined filters with date range
    When GET /api/v1/records?filter[ownerId]=usr-7&filter[createdAt][gte]=2026-06-01&filter[createdAt][lte]=2026-06-30
    Then only records created in June 2026 by owner usr-7 are returned

  Scenario: Unsafe filter fields are dropped (guard retained)
    When GET /api/v1/records?filter[__proto__][eq]=x
    Then the request succeeds with the filter ignored
    And Object.prototype is not polluted
```

```gherkin
Feature: Bounded batch action and CSV export (US-8)

  Scenario: Partial failure reports per-item results
    Given "rec-a" and "rec-b" are eligible and "rec-c" is not
    When an admin batch-locks ["rec-a", "rec-b", "rec-c"]
    Then "rec-a" and "rec-b" become LOCKED with their computed snapshot
    And the response reports "rec-c" as failed with "NOT_LOCKABLE"
    And exactly two lock events are published

  Scenario: Batch cap enforced
    When an admin submits a batch larger than the configured cap
    Then the response is 400 naming the cap and no record is locked

  Scenario: CSV export of the filtered set
    Given filter[status]=LOCKED matches 3 records
    When GET /api/v1/records/export?filter[status]=LOCKED
    Then a CSV with 3 data rows and the configured column set is returned
```

```gherkin
Feature: Integration-pipeline observability (US-10)

  Scenario: Outbox lag alert
    Given the oldest unrelayed outbox entry is older than the alert threshold
    Then the outbox-lag alert fires with service and tenant labels

  Scenario: Redelivery visibility
    When a consumer deduplicates a redelivered message
    Then a redelivery counter increments with consumer and event-type labels
```

## Requirements

### Functional Requirements

**Workstream A — Event-integration integrity (P0)**

- **FR-1** trading-service consumes `accounting.invoice.processed` (versioned routing keys, ADR-0036; `@acme/queue`): the handler validates the source entity is in the expected precondition state, applies the transition, re-derives the parent record's status, and records an activity entry — all in one transaction with the inbox write.
- **FR-2** Inbox (processed-event ledger) in trading-service keyed by event id: duplicate deliveries are no-ops; ledger insert is transactional with the state change.
- **FR-3** Events whose target is in the wrong state, or cannot be resolved, are parked (parked-message store or DLQ per platform convention) with a reason code and a metric — never silently dropped, never crash-looping.
- **FR-4** inventory-service `trading.#` consumers gain the same inbox/dedup guarantee: redelivery never double-applies an effect (audit existing handlers; retrofit ledger; keep reconciliation job as backstop).

**Workstream B — Concurrency safety (P0)**

- **FR-5** The availability check and the write it guards are serialized per source line (transaction-scoped `pg_advisory_xact_lock` on the source-line id hash, or `SELECT … FOR UPDATE` on the source rows — decided at arch-create; ADR-0022 updated either way). Concurrent create and update cannot jointly exceed the source quantity.
- **FR-6** Optimistic concurrency: MikroORM version column on every mutable aggregate; mutation DTOs carry the expected version; stale writes → 409 `STALE_WRITE` with the current version.
- **FR-7** `Idempotency-Key` support on state-changing mutations (the create endpoints, the lock, and the batch lock): key + tenant + endpoint → stored response replayed on retry; same key with different payload → 409 `IDEMPOTENCY_KEY_REUSE`; TTL per convention.

**Workstream C — Data governance (P1)**

- **FR-8** Soft delete across the trading schema: `deletedAt` + MikroORM global filter; existing physical `@Delete` endpoints converted; new deletes allowed only in the initial state and blocked while live rows reference the target; deleted rows excluded from **all** read paths — lists, details, derived calculations, and status derivation (per architecture §3, not per controller).
- **FR-9** Activity entries recorded for delete and cancel operations (audit completeness).

**Workstream D — Contract & spec fidelity (P1)**

- **FR-10** List server-side filtering via the bracket grammar (ADR-0061): `filter[status]` (including the derived status), `filter[ownerId]`, `filter[<related-entity>Id]`, `filter[createdAt][gte|lte]`; the derived status exposed in the list payload; prototype-pollution guard retained.
- **FR-11** The lifecycle transitions that have no endpoint today land as explicit command endpoints (`POST /api/v1/<resource>/:id/<command>`), each with its own permission and guard, plus an explicit create and a lightweight summary read.
- **FR-12** The child-entity fields missing against the contract (migration + DTO + ownership validation) — closes the confirmed design/backend gap.
- **FR-13** Bounded batch action (`POST /api/v1/records/lock-batch`, size capped by a configured maximum rather than a hard-coded one, per-item result array, partial-failure semantics, one activity entry + event per item that succeeded) and list CSV export honouring the active filters.

**Workstream E — Observability & ops (P1)**

- **FR-14** Metrics + alerts: outbox relay lag, consumer lag/redelivery count, parked-message count, lock rate, rejected-write count, write-back count; OTel span attributes `tenantId`/`recordId` on trading flows; Grafana dashboard panels + alert rules; monitoring runbook section.
- **FR-15** Tenant-config wiring audit: verify `TenantConfigProvider` really resolves from tenant-service (the as-built default provider appears to be a static stub); if stubbed, implement the real Redis-cached tenant-service lookup.

### Non-Functional Requirements

- **Tenancy fail-closed:** every new consumer, endpoint, and query enforces tenant scoping; event handlers derive tenant from the event payload and validate it against the entity row.
- **Effectively-once semantics:** at-least-once delivery + idempotent consumers (inbox) across trading and inventory; zero double-application under redelivery.
- **Precision:** all money/quantity arithmetic remains `Big`/`Decimal(19,4)`; API money fields remain 4-dp strings.
- **Performance:** list p95 < 500 ms with filters applied at the benchmark seed size; a full-cap batch lock completes < 10 s; consumer throughput sustains outbox drain without growing lag.
- **Security:** no bypass of `PermissionsGuard`; the batch action requires the same permission as the single-item one; export honours the caller's tenant + filters; the idempotency store is tenant-scoped.
- **Provider-neutral:** no cloud-specific dependencies; RabbitMQ/PG/Redis primitives only (Redis 6.0-compatible commands if Redis is used).
- **Backwards compatibility:** response envelopes unchanged (`{data, meta}`); new fields additive; version field additive on DTOs.

## Testing Requirements

- **Unit (Vitest):** status-transition guards including the new terminal state; inbox dedup logic; idempotency-key store; soft-delete filter behaviour; batch partial-failure aggregation; filter parsing for the new list fields.
- **Integration (Testcontainers, real PG + Rabbit where applicable):**
  - true concurrency tests — parallel transactions racing on one quota (FR-5) and stale writes (FR-6);
  - redelivery tests — dispatch the same event twice through the real consumer (FR-2/FR-4);
  - write-back E2E — publish `accounting.invoice.processed`, assert status + activity + re-derived parent status (FR-1);
  - soft-delete visibility across list, detail and derived calculations (FR-8).
- **Contract (Pact):** new message-pact with trading-service as consumer of accounting-service's `invoice.processed`; regenerate inventory pacts if payloads change.
- **BDD:** the Gherkin features above land as `.feature` files with step definitions (RED first via `/pm:tests-generate`).
- **Performance:** k6 (or equivalent) baseline for the list endpoint with filters at the benchmark seed size; pass/fail p95 < 500 ms.
- **Test data:** seed extension — one tenant seeded to the benchmark size for perf runs; fixtures for both sides of the new transition, for multi-currency records, and for a second tenant class.

## Success Criteria

1. Concurrency suite: 0 quota breaches across ≥100 repeated parallel-claim runs in CI.
2. Redelivery suite: 100% single-application under forced duplicate delivery for every consumer.
3. Write-back E2E green in CI; the transition observable in dev-platform against real events from the producing service.
4. `grep` gate: no remaining physical-delete paths in trading modules (`nativeDelete`/`em.remove` on aggregates outside the soft-delete flow = 0).
5. All Gherkin scenarios automated and green; epic RED tests all flipped GREEN.
6. List p95 < 500 ms with filters at the benchmark seed size (measured, recorded in the epic).
7. Grafana shows the six new metric families; each alert rule proven by synthetic trigger.
8. No new SonarQube critical/blocker issues; no regression in existing trading/inventory suites.

## Constraints & Assumptions

- **Constraints:** per-BC schemas, no cross-schema FKs (ADR-0013); transactional outbox with caller-EM pattern (ADR-0018/0037); versioned event routing keys (ADR-0036); bracket-filter grammar and API envelope (ADR-0061) are fixed contracts; MikroORM v6 idioms; Vitest + Testcontainers; ≤10 tasks at decompose; trunk-based delivery in thin vertical slices — each workstream independently mergeable and deployable.
- **Assumptions:** accounting-service event payloads in `libs/platform/event-contracts` are stable; RabbitMQ per-BC permissions allow trading-service to bind a queue to the accounting exchange (verify at arch-create; may need topology addition); the FE epic (#1439) consumes new filters/commands as they land — no FE work in this epic.
- **Architecture decisions deferred to `/pm:arch-create`:** (1) the serialization mechanism (advisory lock vs `FOR UPDATE` vs accelerating the ADR-0012 saga — reconciling ADR-0022); (2) optimistic-locking convention (version-in-DTO vs `If-Match`/ETag); (3) inbox/idempotency storage convention (per-service table shape, TTL, parked-message handling) — each producing an ADR.

## Out of Scope

- All FE screens and UX (epic #1439 owns them; this epic only unblocks).
- `platform.user.updated` consumer — deferred until a name cache exists (resolution is read-time per ADR-0064; nothing to invalidate today).
- Full ADR-0012 reservation saga implementation IF arch-create chooses serialize-now (the saga then remains a documented, de-risked follow-up).
- accounting-service internals (ADR-0063 event-carried line items unchanged) — this epic consumes its published event and nothing else.
- #1581 pg-bootstrap grant (platform-owned, tracked separately) and #1586 NetworkPolicy rollout (tracked separately; listed as dependency).
- Cursor pagination migration (ADR-0061 mentions it; offset pagination stays for now — revisit with FE infinite-scroll needs).

## Dependencies

- **accounting-service** events + `libs/platform/event-contracts` (exists, merged).
- **RabbitMQ topology:** trading-service queue + binding on the accounting exchange (may require `rabbitmq.com` topology resources + per-BC permission update — operator-applied).
- **Open PRs to land independently:** #1548, #1549; this epic does not duplicate them.
- **Tracked issues this epic references but does not absorb:** #1559 (gateway write RBAC), #1586 (NetworkPolicy crossNamespaceIngress), #1510 (tenant-resolution unification), #1581 (identity grant).
- **tenant-service** for the FR-15 config lookup.
- **Milestone PRDs reconciled:** `platform-m3-trading-extended`, `platform-m3-inventory-service`, `platform-m4-accounting` remain `backlog`; overlapping items are superseded by this PRD's FRs (note added at prd-parse).

## Production Verification

Environment: **dev-platform** (backend services via the gateway), then staging/production when the platform promotes.

1. **Health:** all trading/inventory pods Ready; consumer queues visible in RabbitMQ management with non-zero consumers; ArgoCD apps Synced/Healthy.
2. **Write-back smoke:** move a seeded line into the precondition state; publish a contract-shaped event for it; within 30 s the line reads the terminal status via its detail endpoint and the activity log shows the event.
3. **Concurrency smoke:** scripted double-claim (two parallel requests for 60 against a quota of 100) → exactly one 201 and one 409 `QUOTA_EXCEEDED`.
4. **Idempotency smoke:** double-POST a create with the same `Idempotency-Key` → one record, identical responses.
5. **Soft delete smoke:** delete a DRAFT line item → absent from list, `deletedAt` set in DB, activity entry present.
6. **Filters smoke:** `filter[status]=LOCKABLE` returns only records whose lines are all READY; export returns CSV.
7. **Observability:** the Grafana panel shows outbox lag ≈ 0 and a consumer-redeliveries counter; synthetically park a message → alert fires.
8. **Monitoring window:** 48 h watching consumer lag, parked-message count, DLQ depth (must stay 0), error rates.
9. **Rollback criteria:** parked-message or DLQ growth, a quota breach detected by the reconciliation job, consumer crash-loop, or p95 regression > 2× baseline → Argo rollback per `docs/platform/operations/rollback-runbook.md`; consumers can be disabled by removing the queue binding without redeploying.
10. **Sign-off:** the three new ADRs need a second reviewer before the epic closes; no UI change, so no frontend sign-off is in the path.
