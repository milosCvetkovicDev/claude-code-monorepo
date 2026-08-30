# ERP Sync — Detailed Architecture Notes

## Approval → ERP Post Flow

```
HTTP POST /api/v1/invoices/approve
  └─ InvoicesService.approveInvoices()
       ├─ Promise.allSettled(invoiceAmendments.map(...))
       │    ├─ findInvoice()
       │    ├─ Guard: already in a terminal state → throw
       │    ├─ Clear errorMessage
       │    ├─ validateApprovedInvoice() — domain preconditions
       │    ├─ updateInvoiceStatus(APPROVED)
       │    └─ AppJobQueueAdapter.enqueue(ProcessPurchaseInvoiceJob, {...})
       └─ Collect errors → FailedToApproveInvoicesError
```

The shape is the transferable part: a batch endpoint validates and transitions each item, hands the slow third-party call to a job queue, and collects per-item failures instead of failing the whole batch. The validation step is a domain-specific precondition check — treat it as a black box whose only interesting property is that it runs *before* the status transition, so a record can never be queued for posting in a state the poster cannot handle.

## Job Processing Flow

```
ProcessPurchaseInvoiceJob.perform()
  ├─ fetchEntities() — loads invoice, checks status === APPROVED
  ├─ ErpInvoiceValidationService.validateBeforeErpPost() — warnings only
  ├─ try:
  │    ├─ InvoicesService.postInvoiceToErp()
  │    │    └─ ErpPostService.postErpPurchaseInvoice()
  │    │         ├─ buildErpPurchaseInvoiceRequestForPurchase()
  │    │         ├─ assertErpPostingEnabledOrSkip() ← PRODUCTION GUARD (PR #102)
  │    │         └─ postPurchaseInvoice() → erpPurchasesInvoicesApi
  │    ├─ updateInvoiceStatus(PROCESSED)
  │    └─ setInvoiceErrorMessage(null)
  └─ catch:
       ├─ setInvoiceErrorMessage(String(e))
       └─ throw e → pg-boss marks job as failed
```

## Key Files

| File | Purpose |
|------|---------|
| `src/services/InvoicesService.ts` | `approveInvoices()` — entry point; `postInvoiceToErp()` — dispatch by document type |
| `src/services/ErpPostService.ts` | The ERP post functions + production guard |
| `src/jobs/ProcessPurchaseInvoiceJob.ts` | Purchase invoice job handler |
| `src/jobs/ProcessSaleInvoiceJob.ts` | Sale invoice job handler |
| `src/jobs/lib/PgBossJobQueueAdapter.ts` | pg-boss wrapper, enqueue/worker |
| `src/api/erp/erpApiGuard.ts` | Guarded POST with retry/throttle |
| `src/api/erp/erpRetry.ts` | POST retries only on HTTP 429 |

## Where a Queued Third-Party Post Goes Silent

Handing a slow external call to a job queue buys throughput and costs you the error path: the HTTP caller has already been told "accepted", so every later failure has to announce itself, and each of these is a way it does not. They are worth knowing as a class, because a queue-behind-an-endpoint design grows all of them by default.

- **A feature flag that disables posting.** A flag that makes the poster a no-op is correct in dev and catastrophic in production, where it turns "posted" into "silently discarded". The guard is to make the disabled path *throw* when the environment is production, so the flag can only ever be a local convenience.
- **An enqueue that fails softly.** A queue client that returns `null` instead of throwing (throttled, duplicate singleton key, rejected payload) will be logged and stepped over unless the caller checks the return. The record is left in the transitional state with nothing recorded as failed. Assert on the returned job id and treat absence as an error.
- **`retryLimit: 0`.** Zero retries makes a single transient failure permanent, which is only defensible when the operation is not idempotent — and the answer to that is an idempotency key, not the removal of retries.
- **Narrow retry classification.** Retrying only on 429 and not on 5xx avoids duplicate documents at the cost of dropping recoverable failures; it is a deliberate trade only if something else re-drives them. Decide explicitly and write the reason next to the retry predicate.
- **Sampled failure telemetry.** Job-failure events are ordinary telemetry and are sampled like everything else, so the low-frequency failure is exactly the one that does not reach the dashboard. Exempt terminal-failure events from sampling, or verify against the queue tables rather than the telemetry (see [[appinsights-daily-cap-prod]]).

The common shape: each of these converts a failure into an absence, and an absence has no alert. Anything that leaves a record in a transitional state needs a stale-state query as its backstop — the one below.

## Recovering Stuck Jobs by Hand

When a record is stranded in a transitional state because its job never landed, the repair is to reset the row and re-enqueue the job directly into the queue's own table, in one transaction so a half-repair cannot happen. pg-boss job rows are plain rows; nothing but the state machine's own invariants stops you writing one:

```sql
-- Find the strandings first: transitioned but never posted.
SELECT number, status, "errorMessage", "updatedAt"
FROM   document
WHERE  status = 'Approved'
  AND  "updatedAt" < now() - interval '1 hour'
ORDER  BY "updatedAt";

-- Reset to the pre-post state and re-enqueue, atomically.
BEGIN;
UPDATE document SET status = 'Approved', "errorMessage" = NULL
WHERE  number IN (<numbers>) AND "ownerId" = <id> AND status = 'Processed';

INSERT INTO pgboss.job (id, name, data, state, retry_limit, created_on, expire_in)
VALUES (gen_random_uuid(), 'ProcessDocumentJob',
  '{"currentUserId": <uid>, "documentNumber": <num>, "ownerId": <oid>}',
  'created', 0, now(), interval '15 minutes');
COMMIT;
```

Three things make this safe rather than reckless. The `UPDATE` is guarded on the *current* status, so re-running it after a partial recovery is a no-op instead of a second post. `data` must match the job handler's expected payload exactly — pg-boss v10 rejects `undefined` values, and a payload the handler cannot destructure fails at pick-up, not at insert. And `expire_in` bounds how long a picked-up job may run before the queue reclaims it, so a wedged worker does not hold the row forever. Re-run the first query afterwards: the repair is proven by the strandings disappearing, not by the `INSERT` succeeding.

## Failure Modes Seen in Practice

- **pg-boss v10 rejects `undefined` in job data** — the enqueue never lands, so the record sits in the intermediate state forever with nothing logged as failed (see runbook).
- **Deployment slot swap races the worker** — jobs in flight across the swap are silently skipped rather than retried (see runbook).
