---
name: Platform Job Queue Architecture Decision
description: Architecture Board decision 2026-03-25 — BullMQ removed, RabbitMQ unified for events + jobs, transactional outbox for atomic enqueue
type: project
---

Architecture Board reviewed 4 options for job queue system on 2026-03-25. Enterprise Architect + DevOps Architect evaluated independently.

**Why:** CTO spec references BullMQ 32 times, but Decision #5 (Redis cache-only) and board resolutions C8/H8 make BullMQ incompatible. Redis `allkeys-lru` eviction would silently delete BullMQ job payloads.

**How to apply:** All Sprint 2 services use RabbitMQ work queues for jobs. No BullMQ. See `@acme/queue` and `@acme/event-bus` library stubs for the design.

## Decision: Option A — RabbitMQ Unified

- **RabbitMQ** handles: domain events (topic exchange) + background jobs (work queues)
- **Transactional outbox** (Decision #7): jobs enqueued atomically with business writes via outbox table
- **Cron scheduling**: @nestjs/schedule + PG advisory lock (same pattern as outbox relay)
- **Retry**: RabbitMQ DLX + TTL re-queue. Failed queue (DLQ) per job type
- **Monitoring**: RabbitMQ Management UI + Prometheus metrics

## Why NOT the Alternatives

- **BullMQ (Option C)**: Contradicts Decision #5 (Redis cache-only). Board C8/H8 resolved by removing jobs from Redis. `allkeys-lru` silently evicts job data. DEAD.
- **graphile-worker (Option B)**: PgBouncer transaction pooling incompatible (needs session mode). No dashboard. Contradicts Decision #6 (RabbitMQ for work queues). Adds second job paradigm.
- **Temporal.io (Option D)**: 4-8 extra K8s pods. No official Testcontainer. Premature before first saga exists. Re-evaluate at M3 for invoice approval saga.

## Key Insight: Outbox Solves Transactional Safety

Enterprise Architect initially scored Option A 1/5 on transactional safety (RabbitMQ publish not atomic with PG commit). INCORRECT — Decision #7 outbox pattern IS the transactional bridge:
1. Business txn: `BEGIN` → business write + `INSERT INTO outbox` → `COMMIT` (atomic)
2. Outbox relay: poll → publish to RabbitMQ → mark published (async, retryable)
3. If RabbitMQ down: outbox row persists, retried when broker recovers

## Infrastructure Stack (M1)

- PostgreSQL: data + outbox table
- Redis: cache + sessions + token revocation ONLY
- RabbitMQ: events (topic) + jobs (work queues) + retry (DLX)

## Files Updated

- Task files: 207.md, 208.md, 209.md, 210.md, 211.md
- Architecture: `.claude/epics/platform-m1-platform-foundation/architecture.md`
- Library stubs: `libs/platform/queue/src/index.ts`, `libs/platform/event-bus/src/index.ts`

## Future: M3 Saga Evaluation

When invoice approval saga arrives (M3), evaluate Temporal.io as targeted extraction for complex workflow orchestration. Not before.
