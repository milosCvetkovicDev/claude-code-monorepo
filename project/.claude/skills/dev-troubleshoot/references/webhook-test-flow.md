# Webhook Integration Test Flow

Producer → webhook → consumer, exercised end to end against local services. The shape of the
test generalises: **trigger the producing action through the real UI, then assert the consumer's
success log _and_ the number of records it created.** A 200 from the consumer proves delivery,
not work — a consumer that received an empty payload also returns 200.

## Prerequisites

1. All services running on default ports (5432, 3000, 3200, 4200, 4400)
2. `COMMISSION_API_WEBHOOK_URL=http://localhost:3200` in `apps/legacy-api/.env` — base URL only,
   no path (see SKILL.md)

## Test Procedure

1. **Verify all services running:**

   ```bash
   lsof -i :3000,3200,4200,4400 -sTCP:LISTEN
   ```

2. **Check environment variables:**

   ```bash
   grep COMMISSION_API apps/legacy-api/.env
   ```

3. **Prepare a record that satisfies the trigger's preconditions.** The producing action only
   emits when the record is in the state the emitter checks, and the payload is built from
   relations that must actually be populated. Find a record in that state before you start, or
   seed one — most "the webhook never fired" reports are a record that never met the
   precondition, not a broken emitter. See `database-queries.md`.

4. **Trigger the action through the UI** — open the record at `http://localhost:4200/...` and
   perform the action. Trigger through the UI rather than curl: that path exercises the auth,
   serialisation, and emitter call site the real users hit.

5. **Verify the webhook in the producer's logs** — look, in order, for:
   - the handler entry for the action, with the record id
   - the emitter's "sending" line
   - a **non-zero count of items in the payload** (zero here means step 3 was not satisfied)
   - the consumer's success response
   - a **non-zero count of records created** by the consumer

   The two counts are the point. Checking only "succeeded" turns a silent no-op into a pass.

6. **Check the result in the consumer's UI** — `http://localhost:4400`.

## Expected Flow

```
User performs the action in the producer UI (localhost:4200)
  → legacy-api receives POST /api/v1/<resource>/:id/<action>
  → the service applies the state change
  → the emitter builds a payload from the record's populated relations
  → POST to domain-api: http://localhost:3200/api/internal/<event>
  → domain-api creates its own records from that payload
  → returns { created: N }
  → visible in domain-web (localhost:4400)
```

## Key Files

- `apps/legacy-api/src/services/DealsService.ts` — the state change and the webhook emitter
- `apps/domain-api/src/routes/internal.routes.ts` — the webhook endpoint
- `apps/domain-api/src/index.ts` — service startup and config
