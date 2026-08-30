---
name: platform-trading-hardening
status: active
created: 2026-07-02T11:36:02Z
updated: 2026-07-02T11:36:02Z
prd: .claude/prds/platform-trading-hardening.md
epic: .claude/epics/platform-trading-hardening/epic.md
master: .claude/milestones/platform/master-architecture.md
---

# Architecture: platform-trading-hardening

## 1. Context Analysis

Backend-only hardening of the Trading BC (trading-service + inventory-service) across five workstreams: (A) event-integration integrity — consume `accounting.invoice.processed`, inbox/dedup in both services, parked messages (FR-1..4); (B) concurrency safety — serialized quota checks, optimistic locking, idempotency keys (FR-5..7); (C) data governance — soft delete + audit (FR-8..9); (D) contract fidelity — server-side list filters including the derived status, bounded batch action + export, the transitions with no command endpoint (FR-10..13); (E) observability + tenant-config wiring audit (FR-14..15).

**Inherited constraints (master architecture — not re-debated):** transactional outbox (ADR-0018/0037, caller-EM convention), RabbitMQ topic exchanges `acme.{bc}` with DLX+TTL retry, versioned event routing keys (ADR-0036), **Redis is cache-only**, MikroORM global-filter pattern for cross-cutting predicates (tenant filter precedent), `{data, meta}` / `{error:{code,message}}` envelopes with `{DOMAIN}_{ERROR}` codes, `@nestjs/swagger`, Vitest + Testcontainers + Cucumber BDD + Pact, per-BC schemas with no cross-schema FKs (ADR-0013), `@nestjs/schedule` + PG advisory lock for single-instance cron.

**NFR implications:** effectively-once event processing (at-least-once delivery + idempotent consumers); tenant fail-closed on every new surface; `Big`/4-dp strings for money; list p95 < 500 ms at the benchmark seed size; additive-only contract changes.

## 2. Decision Matrix

| Category | Decision | Rationale | ADR                  | Inherited?          |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | -------------------- | ------------------- |
| Data / concurrency | Availability check + write serialized via **`SELECT … FOR UPDATE` (MikroORM `PESSIMISTIC_WRITE`) on the source-line rows the check reads**, deterministic id order | Same primitive as the existing lock command; row-visible; blocks only competing writers; amends the ADR-0022 debt note | **ADR-0066**         | No (new)            |
| Data / concurrency | **Optimistic locking: MikroORM native `@Property({ version: true })`; `version` carried in mutation DTO body**; mismatch → 409 `STALE_WRITE` + `currentVersion`                                                           | Explicit, additive, no gateway/header plumbing; no client consumes these endpoints yet → no back-compat cost | **ADR-0067**         | No (new, platform)  |
| Data / integration | **Inbox `processed_event`, `idempotency_key`, `parked_message` as PG tables per service schema**; inbox insert transactional with state change; DLX remains transport backstop | Mirrors outbox symmetry; honours Redis-cache-only; queryable/replayable parking | **ADR-0068**         | No (new, platform)  |
| Data / governance | Soft delete: `deleted_at` column + MikroORM **global filter** (default-on), physical `@Delete` handlers converted to set `deleted_at`                                                                                     | Reuses the tenant-filter mechanism; zero opt-out reads | — (§3 pattern)       | Mechanism inherited |
| Auth & Security | No changes. The batch action reuses the single-item permission; export/filters run under caller tenant + `PermissionsGuard`                                                                                               | Already enterprise-grade post-#1443                                                                      | —                    | Yes |
| API & Communication | List filters reuse the **`parse-list-filters` bracket grammar**; envelope unchanged; new endpoints additive (batch action, export, the missing lifecycle commands, an explicit create, a summary read)                    | ADR-0061 are fixed contracts | ADR-0061             | Yes |
| API & Communication | trading-service **consumes** `accounting.invoice.processed` via a `@acme/queue` consumer mirroring inventory's `trading-event-consumer` pattern; payload/routing key from `libs/platform/event-contracts` (never invented) | First inbound integration event in trading; reuse proven consumer machinery | ADR-0036/0018 (inh.) | Pattern inherited |
| Frontend | N/A — backend-only epic | #1439 consumes results | —                    | —                   |
| Infrastructure | RabbitMQ topology addition: trading queue + binding on the accounting exchange (topology-operator resources, operator-applied); Grafana dashboard + alert rules on the OTel/Mimir stack; **no new services/datastores**       | ADR-0019 stack inherited; consumers disable-able by unbinding | —                    | Partially inherited |
| Domain events | Producer side unchanged (outbox). New consumer side follows **inbox** convention (ADR-0068)                                                                                                                               | Completes effectively-once end-to-end | ADR-0068             | Producer inherited |

## 3. Implementation Patterns

### 3.1 Naming Conventions

- **Tables (snake_case, schema-local):** `processed_event` (PK `consumer, event_id`), `idempotency_key` (UNIQUE `tenant_id, endpoint, key`), `parked_message`; columns `deleted_at`, `version`.
- **Error codes (`{DOMAIN}_{ERROR}`):** new `STALE_WRITE` (409) and `IDEMPOTENCY_KEY_REUSE` (409) join the existing conflict codes for "quota exceeded", "record locked" and "invalid status transition" (409) and "not eligible for this command" (422); parked reasons `INVALID_STATE`, `UNRESOLVABLE_ENTITY`.
- **Endpoints:** versioned under `/api/v1`, with each lifecycle transition as a POST sub-resource rather than an overloaded PATCH — `POST /api/v1/<resource>`, `GET /api/v1/<resource>/:id/summary`, `POST /api/v1/<resource>/lock-batch`, `GET /api/v1/<resource>/export`, `POST /api/v1/<resource>/:id/<command>`, `PATCH /api/v1/<resource>/:id` (initial state only), `DELETE /api/v1/<resource>/:id`.
- **Metrics (Prometheus, `{product}_{service}_{thing}_total|_seconds`):** `acme_trading_outbox_lag_seconds`, `acme_trading_consumer_redeliveries_total`, `acme_trading_parked_messages_total`, plus one counter per business event the pipeline moves, named the same way (inventory mirrors the consumer families with `acme_inventory_`).
- **Headers:** `Idempotency-Key` (request), echoed in `meta.idempotencyReplayed` on replay.

### 3.2 Structure Conventions

- trading-service: `src/integration/` module — `invoice-processed.consumer.ts` (bootstrap), `invoice-processed.handler.ts` (application), `infrastructure/mikro-orm-processed-event.repository.ts`, `infrastructure/mikro-orm-parked-message.repository.ts`; `src/common/idempotency/` — interceptor + store port + MikroORM adapter; soft-delete filter registered in `src/common/` beside the tenant filter.
- inventory-service: `src/stock/inbox/` — processed-event repo + dedup wrapper used by `trading-event-consumer.ts`.
- Locking reads live in repositories (e.g. `ISourceRepository.findLineItemsForUpdate(ids)`), never raw in services; transitions stay entity methods; orchestration stays in `*.service.ts` / use-cases (Practice #3).
- Migrations: one per concern per service — trading `Migration_005_inbox_parked`, `_006_version_columns`, `_007_soft_delete`, `_008_child_contacts`; inventory `Migration_003_inbox`.

### 3.3 Format Conventions

- Envelope `{ data, meta }` unchanged; errors `{ error: { code, message, details?, correlationId } }`.
- `version` (integer) additive on all mutable-entity response DTOs; **required** on mutation DTOs from day one (no client back-compat exists yet).
- Money/quantities remain 4-dp decimal strings; dates ISO 8601 UTC; the CSV export emits the contract's column set with the same string formats.
- Batch response: `{ data: { results: [{ id, status: 'LOCKED'|'FAILED', errorCode? }] } }` — partial success is a 200 with per-item results, never an all-or-nothing 4xx.

### 3.4 Anti-Patterns (NEVER DO)

1. **Never** apply an inbound event without the `processed_event` insert in the SAME transaction as the state change.
2. **Never** run the availability check outside a transaction that already holds `PESSIMISTIC_WRITE` on every row the check reads (acquired in sorted id order) — a check that is not covered by the lock guarding its write is decoration.
3. **Never** store inbox/idempotency/parked state in Redis (master: cache-only) or physically delete an aggregate (`em.nativeDelete`/`em.remove` on aggregates is banned outside migrations).
4. **Never** write the event-owned terminal status from anywhere but the inbound handler — a state whose truth lives in another context must have exactly one writer here.
5. **Never** invent event payloads/routing keys — import from `libs/platform/event-contracts`; never fork the EM in adapters (caller-EM convention).

## 4. Project Structure

### 4.1 Directory Tree (new files)

```
apps/platform/trading-service/src/
├── integration/
│   ├── integration.module.ts
│   ├── invoice-processed.consumer.ts
│   ├── invoice-processed.handler.ts
│   ├── domain/ports/{processed-event,parked-message}.repository.port.ts
│   └── infrastructure/mikro-orm-{processed-event,parked-message}.repository.ts
├── common/idempotency/{idempotency.interceptor.ts,idempotency-store.port.ts,mikro-orm-idempotency.store.ts}
├── common/soft-delete.filter.ts
├── migrations/Migration_005..008_*.ts
└── modules/<resource>/{lock-batch.use-case.ts,export.service.ts}
apps/platform/inventory-service/src/stock/inbox/… + migrations/Migration_003_inbox.ts
charts/… (topology: trading queue/binding — operator-applied)
```

### 4.2 Requirement-to-File Mapping

| FR / Task | Target | Layer |
| -------------- | ---------------------------------------------------------------------------------------- | ------------------------ |
| FR-1..3 / T2   | `integration/*` (consumer, handler, inbox, parked) + the entity transition method | app + infra + domain |
| FR-4 / T3      | `inventory: stock/inbox/*` + dedup wrap in `trading-event-consumer.ts`                   | infra |
| FR-5 / T4      | `ISourceRepository.findLineItemsForUpdate` + service txn wiring | infra + app (ADR-0066)   |
| FR-6..7 / T5   | version columns on every mutable aggregate + DTOs + `common/idempotency/*`               | domain + infra (0067/68) |
| FR-8..9 / T6   | `common/soft-delete.filter.ts` + entity `deleted_at` + controller conversions + activity | domain + app |
| FR-10,13 / T7  | list controller filters + `lock-batch.use-case.ts` + `export.service.ts`                 | app |
| FR-11..12 / T8 | the command controllers + child entity/DTO/migration | app + domain |
| FR-14..15 / T9 | metrics module, Grafana dashboard JSON, alert rules, `TenantConfigProvider` audit | infra + ops |

## 5. Cross-Cutting Concerns

- **Error handling:** all new failures throw `AppException` subtypes with §3.1 codes through the existing `GlobalExceptionFilter`; consumer failures classify → retry (transient, DLX), park (invalid state), never swallow.
- **Logging/tracing:** structured logs with `correlationId` propagated from event metadata; OTel spans carry `tenantId`/`recordId` attributes on all new paths.
- **Testing:** true-concurrency tc specs (two parallel `em.transactional` racing on one source row); double-dispatch redelivery specs; message-pact trading⇐accounting; k6 list baseline at the benchmark seed size; grep gate for physical deletes.
- **Monitoring:** alert thresholds — outbox lag > 60 s warn / > 300 s crit; `parked_messages_total` delta > 0 crit; DLQ depth > 0 crit; consumer redeliveries rate anomaly warn. Runbook section added to `docs/platform/operations/monitoring-runbook.md`.
- **Rollout:** additive migrations land before enforcing code; consumers ship with disable-by-unbinding as the rollback path; the soft-delete filter is proven by a tc suite before any endpoint conversion.

## 6. DDD Design

### 6.1 Context Map Relationships

| This BC | Related BC | Pattern | Direction | Notes |
| ------- | ---------- | --------------------------- | ---------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Trading | Accounting | Published Language (events) | **NEW: consume**       | `accounting.invoice.processed` closes a feedback loop that was previously one-way; Trading already produces events for Accounting (ADR-0063) |
| Trading | Inventory | Published Language (events) | produce (existing)     | Consumer side hardened with inbox (FR-4); reservation saga unchanged (ADR-0022/0066)                                     |
| Trading | Platform | Customer–Supplier | consume (REST, cached) | FR-15 audits that `TenantConfigProvider` really reads tenant-service                                                     |

### 6.2 Anti-Corruption Layers

None new — no legacy involvement in this epic.

### 6.3 Domain Event Contracts

| Event | Direction | Version | Payload Schema | Producer/Consumer |
| ------------------------------ | --------- | ------------------- | --------------------------------------------------------------- | ------------------------------------ |
| `accounting.invoice.processed` | consume | per event-contracts | `libs/platform/event-contracts` (source of truth — never invented) | accounting-service → trading-service |
| `trading.*` (existing)         | produce | unchanged | unchanged | trading-service → inventory et al.   |

### 6.4 Domain Logic Placement

The heuristic, not the rules themselves: an invariant that lives inside one aggregate belongs on the entity; one that spans aggregates belongs in a domain service with the locking in the repository/application layer; anything about transport or delivery belongs in infrastructure and must not leak into the domain.

| Rule | Location | Type | Rationale |
| ------------------------------------------------- | ---------------------------------------------- | ------------------- | ---------------------------------------------------------- |
| Precondition guard on the event-driven transition | entity transition methods | Entity method | single-aggregate invariant |
| "Sum of claims ≤ source quantity"                 | availability checker under source row locks | Domain service | cross-aggregate calculation; locking in repo/app layer (ADR-0066) |
| Park-vs-apply decision for inbound events | the inbound event handler | Application service | orchestration + inbox transaction |
| Idempotency replay | `IdempotencyInterceptor`                       | Infrastructure | transport concern, not domain |
| Soft-delete visibility | global filter + entity `softDelete()`          | Entity + filter | invariant enforced at read + write |

### 6.5 Repository Contracts (additions)

| Aggregate / Concern | Interface | Key Methods |
| ------------------- | --------------------------- | -------------------------------------------------------- |
| Source aggregate | `ISourceRepository`         | `findLineItemsForUpdate(ids: string[])` (sorted, locked) |
| Integration inbox | `IProcessedEventRepository` | `recordOnce(consumer, eventId): boolean`                 |
| Integration parking | `IParkedMessageRepository`  | `park(message, reason)`, `listUnresolved()`              |
| Idempotency | `IIdempotencyStore`         | `beginOrReplay(tenantId, endpoint, key, payloadHash)`    |
