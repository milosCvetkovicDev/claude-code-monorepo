---
name: implement-domain-event
description: 'Create a domain or integration event: event contract in @acme/event-contracts, aggregate method, outbox entry (for integration events), RabbitMQ publisher/consumer, dead letter handler, idempotency guard, and tests.'
model: sonnet
args: <event-name> [--type domain|integration] [--bc <bounded-context>]
disable-model-invocation: true
---

## Input

- `event-name`: Past-tense event name (e.g., `tenant-created`, `user-deactivated`, `deal-confirmed`)
- `--type`: `domain` (in-process only) or `integration` (outbox → RabbitMQ). Default: `integration`
- `--bc`: Bounded context name for exchange routing (e.g., `platform`, `identity`, `trading`)

## Workflow

### Step 1: Determine Event Type

Read master architecture at `.claude/milestones/platform/master-architecture.md`:

- **Domain events**: Stay in-process (NestJS EventEmitter). Same transaction. No outbox.
- **Integration events**: Outbox table → relay → RabbitMQ topic exchange. Guaranteed delivery.

### Step 2: Create Event Contract

File: `libs/platform/event-contracts/src/lib/{bc}/{event-name}.event.ts`

```typescript
import { IntegrationEvent } from '../integration-event.interface';

export interface {EventName}Payload {
  // TODO: Define payload fields
}

export const {EVENT_NAME}_EVENT_TYPE = '{bc}.{entity}.{past-tense}';
export const {EVENT_NAME}_VERSION = 1;
```

Register in barrel export: `libs/platform/event-contracts/src/index.ts`

### Step 3: Add Aggregate Method (if domain event)

In the entity that produces this event, add a method that calls `this.addDomainEvent()`.

### Step 4: Create Outbox Entry (if integration event)

In the application service, create an `OutboxEntry` in the same transaction as the business write:

```typescript
await this.outboxRepo.save(
  new OutboxEntry({
    eventType: '{bc}.{entity}.{past-tense}',
    routingKey: '{bc}.{entity}.{past-tense}',
    payload: {
      /* event-specific data */
    },
  })
);
await this.em.flush(); // Same transaction
```

### Step 5: Create Consumer (if integration event)

File: `apps/platform/{consumer-service}/src/modules/{module}/{event-name}.consumer.ts`

Must include idempotency guard:

1. Check `processed_events` table for `eventId`
2. If exists, ack and skip
3. Process event
4. Save to `processed_events`
5. Ack message

### Step 6: Configure Dead Letter (if integration event)

Queue: `{bc}.{entity}.{past-tense}` with DLX → `dlq.{bc}.{entity}.{past-tense}`

### Step 7: Update Event Catalog

Add entry to `docs/platform/context-mapping/event-catalog.md`:

| Event | Version | Payload | Producers | Consumers |
| ----- | ------- | ------- | --------- | --------- |

### Step 8: Write Tests

- Unit: Verify aggregate method produces event with correct payload
- Integration: Verify outbox entry created in same transaction
- Consumer: Verify idempotency (duplicate message → no duplicate processing)

## Conventions

- Event names: past tense (`tenant.created`, not `create.tenant`)
- Event envelope: eventId (UUID v7), eventType, aggregateId, version, payload, metadata.tenantId
- Routing key = eventType (dotted path)
- Exchange: `acme.{bc}` (topic)
- Queue naming: same as routing key for dedicated consumers
- DLQ: `dlq.{routing-key}`
- All integration events go through outbox — NEVER direct publish
- All consumers have idempotency guard
