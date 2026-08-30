---
name: platform-trading-hardening
created: 2026-07-02T11:46:30Z
updated: 2026-07-02T11:46:30Z
prd: .claude/prds/platform-trading-hardening.md
epic: .claude/epics/platform-trading-hardening/epic.md
architecture: .claude/epics/platform-trading-hardening/architecture.md
---

# Test Manifest: platform-trading-hardening

RED-phase test suite for all 9 PRD Gherkin features (+1 inventory companion).
Every file below is intentionally FAILING — either because it statically
imports a module that does not exist yet (module-resolution failure at file
load), or because it drives REAL, ALREADY-EXISTING code and asserts the
FUTURE desired behaviour, which does not match today's actual behaviour
(assertion failure or uncaught exception against real Postgres).

**Total: 28 files — 10 `.feature`, 2 step-definition files (88 step defs), 9
testcontainers specs, 5 unit stubs, 1 message-pact spec, this manifest.
60 individual test cases (25 BDD scenarios + 25 tc `it()` + 9 unit `it()` + 1
pact `it()`).**

## Gherkin `.feature` files

| File | Layer | Covers (FR / task)                                                      | Scenarios | RED reason |
| ------------------------------------------------------------------------------------ | --------------------- | ----------------------------------------------------------------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `apps/platform/trading-service/test/features/invoice-write-back.feature`                | Acceptance (Cucumber) | US-1, US-3 / FR-1..3 / task 002                                         | 3         | Step defs in `hardening.steps.ts` throw `PENDING: implemented by task 002` — trading-service has zero RabbitMQ consumers today |
| `apps/platform/trading-service/test/features/concurrent-oversell-prevention.feature`    | Acceptance (Cucumber) | US-2 / FR-5 / task 004                                                  | 2         | Steps throw `PENDING: implemented by task 004` — the availability check runs outside any row lock (ADR-0022 debt; ADR-0066 not yet wired)                                                    |
| `apps/platform/trading-service/test/features/optimistic-concurrency.feature`            | Acceptance (Cucumber) | US-4 / FR-6 / task 005                                                  | 2         | Steps throw `PENDING: implemented by task 005` — no mutable aggregate has a `version` column (ADR-0067 not yet wired)                                                                |
| `apps/platform/trading-service/test/features/idempotent-financial-mutations.feature`    | Acceptance (Cucumber) | US-5 / FR-7 / task 005                                                  | 2         | Steps throw `PENDING: implemented by task 005` — `IdempotencyInterceptor`/`IIdempotencyStore` do not exist (ADR-0068)                                                                |
| `apps/platform/trading-service/test/features/soft-delete.feature`                       | Acceptance (Cucumber) | US-6 / FR-8..9 / task 006                                               | 3         | Steps throw `PENDING: implemented by task 006` — no `deletedAt` column or global filter; the endpoints under test hard-delete, and several aggregates expose no delete at all |
| `apps/platform/trading-service/test/features/deal-list-filtering.feature`               | Acceptance (Cucumber) | US-7 / FR-10 / task 007                                                 | 3         | Steps throw `PENDING: implemented by task 007` — `parseListFilters` (already shipped, already unit-tested) is never called by `DealController`/`DealService`/`IDealRepository`       |
| `apps/platform/trading-service/test/features/batch-lock-csv-export.feature`             | Acceptance (Cucumber) | US-8 / FR-13 / task 007                                                 | 3         | Steps throw `PENDING: implemented by task 007` — no `lock-batch` endpoint, no `LockDealBatchUseCase`, no CSV export |
| `apps/platform/trading-service/test/features/lifecycle-completeness.feature`            | Acceptance (Cucumber) | US-9 / FR-11..12 / task 008                                             | 3         | Steps throw `PENDING: implemented by task 008` — the two new entity commands and the new contact fields are all absent |
| `apps/platform/trading-service/test/features/money-pipeline-observability.feature`      | Acceptance (Cucumber) | US-10 / FR-14 / task 009                                                | 2         | Steps throw `PENDING: implemented by task 009` — none of the six `acme_trading_*` metric families exist |
| `apps/platform/inventory-service/test/features/consumer-redelivery-idempotency.feature` | Acceptance (Cucumber) | US-3, FR-4 / task 003 (companion to invoice-write-back; inventory side) | 2         | Steps throw `PENDING: implemented by task 003` — `src/stock/inbox/*` does not exist; `SaleCreatedHandler` has only a per-line-item `eventId` check across 4 non-transactional writes |

## Step-definition stubs (additive)

| File | Layer | Covers | Step defs | RED reason |
| -------------------------------------------------------------------------------- | ------------------ | ----------------------------------------- | --------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `apps/platform/trading-service/test/features/step-definitions/hardening.steps.ts`   | Cucumber step defs | All 9 trading `.feature` files above | 78 (+1 reused: `Given('I am authenticated as a trader/admin in tenant {string}', ...)` from `trading.steps.ts`) | Every step calls a shared `pending(taskFile, detail)` helper that throws `PENDING: implemented by task NNN — <detail>` |
| `apps/platform/inventory-service/test/features/step-definitions/hardening.steps.ts` | Cucumber step defs | `consumer-redelivery-idempotency.feature` | 10                                                                                                              | Same `pending(detail)` pattern, all pointing at task 003                                                               |

Collision check performed: grepped every `Given`/`When`/`Then` pattern already
registered in `trading.steps.ts` (120 patterns), `deal-http-gap-fills.steps.ts`
(22 patterns), and `inventory.steps.ts` (80 patterns) before writing new
patterns — zero collisions. Parentheses in literal Gherkin text (e.g. a
bracketed state qualifier such as `(all lines settled)`) are escaped as `\(...\)` in the Cucumber
Expression to force literal matching rather than relying on
optional-text-group semantics.

## Testcontainers specs

| File | Layer | Covers (FR / task)   | Tests | RED reason (verified, not assumed)                                                                                                                                                                                                                                                                                                                                                                   |
| --------------------------------------------------------------------------------------- | --------------------------------------- | -------------------- | ----- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `apps/platform/trading-service/test/testcontainers/invoice-writeback.tc.spec.ts`           | Integration (real PG)                   | FR-1..3 / task 002   | 3     | Static import of `../../src/integration/invoice-processed.handler` (`InvoiceProcessedHandler`) fails module resolution — whole file fails at collection |
| `apps/platform/trading-service/test/testcontainers/stock-oversell-race.tc.spec.ts`         | Integration (real PG, TRUE concurrency) | FR-5 / task 004      | 2     | Drives TODAY'S real create-line-items sequence via two genuine `em.fork()` racers; asserts the 409 `errorCode` the epic introduces — that string exists nowhere in the codebase today (grep-verified), so the assertion fails deterministically regardless of which interleaving occurs |
| `apps/platform/trading-service/test/testcontainers/optimistic-locking.tc.spec.ts`          | Integration (real PG)                   | FR-6 / task 005      | 2     | No import gate — asserts a stale write is rejected 409 `STALE_WRITE`; today it silently succeeds (no version column) so `.rejects` fails because the promise resolves instead |
| `apps/platform/trading-service/test/testcontainers/idempotency-key.tc.spec.ts`             | Integration (real PG)                   | FR-7 / task 005      | 2     | Static import of `../../src/common/idempotency/mikro-orm-idempotency.store` (`MikroOrmIdempotencyStore`) fails module resolution |
| `apps/platform/trading-service/test/testcontainers/soft-delete-visibility.tc.spec.ts`      | Integration (real PG)                   | FR-8..9 / task 006   | 3     | No import gate — asserts `IPurchaseRepository` exposes `remove()` (it does not, verified by reading the port) and that a hard-deleted Haulage row survives with `deletedAt` set (it does not — `MikroOrmHaulageRepository.remove()` is a real, executed `em.remove()+flush()`)                                                                                                                       |
| `apps/platform/trading-service/test/testcontainers/deal-list-filters.tc.spec.ts`           | Integration (real PG)                   | FR-10 / task 007     | 3     | No import gate — calls the REAL `MikroOrmDealRepository.findAll` with a `filters` param (via `as any`, honestly signalling the current interface doesn't support it); its `where` clause is hardcoded `{}` (verified by reading the file) so filtered assertions fail against real unfiltered results |
| `apps/platform/trading-service/test/testcontainers/deal-batch-lock.tc.spec.ts`             | Integration (real PG)                   | FR-13 / task 007     | 3     | Static import of `../../src/modules/deal/lock-deal-batch.use-case` and `../../src/modules/deal/deal-export.service` fails module resolution |
| `apps/platform/trading-service/test/testcontainers/lifecycle-gap-fills.tc.spec.ts`         | Integration (real PG)                   | FR-11..12 / task 008 | 5     | No import gate — 5 direct capability checks against real, existing classes: the two new entity methods and the two new controller methods are `undefined` on their prototypes, and constructing a child with a reference that belongs to another owner does not throw (there is no ownership rule yet for it to violate). Asserting capability against the real class, rather than importing a module that does not exist, is what makes these fail for the right reason |
| `apps/platform/inventory-service/test/testcontainers/consumer-inbox-redelivery.tc.spec.ts` | Integration (real PG, TRUE concurrency) | FR-4 / task 003      | 2     | No import gate — drives the REAL `SaleCreatedHandler` with two genuine concurrent `.handle()` calls on the identical event via `Promise.allSettled`; asserts zero rejections, but the losing writer hits `stock_movement.event_id`'s UNIQUE constraint uncaught today |

**Verification status: UNEXECUTED.** Per hard rule 7, testcontainers suites
were NOT run (require Docker + ~2 min/container startup × 9 files — too slow
for this pass). Two specs (`deal-list-filters.tc.spec.ts`,
`soft-delete-visibility.tc.spec.ts` partially, `lifecycle-gap-fills.tc.spec.ts`,
`optimistic-locking.tc.spec.ts`) have NO not-yet-existing import, so — unlike
the others — they would pass TypeScript resolution and only fail at
assertion/runtime time if executed; this is by design (see "RED reason"
column) and was verified by re-reading the actual production source files
they exercise (`mikro-orm-deal.repository.ts`, `purchase-repository.port.ts`,
`mikro-orm-haulage.repository.ts`, `sale.entity.ts`, `credit-note.entity.ts`,
`deal.controller.ts`, `haulage.entity.ts`, `purchase.entity.ts`), not assumed.

## Unit stubs (colocated `__tests__`)

| File | Layer | Covers (FR / task) | Tests | RED reason |
| ------------------------------------------------------------------------------------------------------------------ | ------------- | ------------------ | ----- | ---------------------------------------------------------------------------------- |
| `apps/platform/trading-service/src/integration/infrastructure/__tests__/mikro-orm-processed-event.repository.spec.ts` | Unit (Vitest) | FR-2 / task 002    | 1     | Static import of `../mikro-orm-processed-event.repository` fails module resolution |
| `apps/platform/trading-service/src/common/idempotency/__tests__/mikro-orm-idempotency.store.spec.ts`                  | Unit (Vitest) | FR-7 / task 005    | 2     | Static import of `../mikro-orm-idempotency.store` fails module resolution |
| `apps/platform/trading-service/src/modules/deal/__tests__/lock-deal-batch.use-case.spec.ts`                           | Unit (Vitest) | FR-13 / task 007   | 2     | Static import of `../lock-deal-batch.use-case` fails module resolution |
| `apps/platform/trading-service/src/common/__tests__/soft-delete-filter.spec.ts`                                       | Unit (Vitest) | FR-8 / task 006    | 2     | Static import of `../soft-delete.filter` fails module resolution |
| `apps/platform/inventory-service/src/stock/inbox/__tests__/mikro-orm-processed-event.repository.spec.ts`              | Unit (Vitest) | FR-4 / task 003    | 2     | Static import of `../mikro-orm-processed-event.repository` fails module resolution |

These 5 files are ALSO under `src/**` (not `test/**`), so they ARE included by
`tsconfig.json`'s `"include": ["src/**/*.ts"]` and were exercised by the
`typecheck` verification run below (see Verification).

## Message-pact spec

| File | Layer | Covers (FR / task)                        | Tests | RED reason |
| ----------------------------------------------------------------------------------------- | ------------------ | ----------------------------------------- | ----- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `apps/platform/trading-service/test/pact/accounting-invoice-processed.consumer.pact.spec.ts` | Contract (Pact V4) | Testing Requirements §Contract / task 002 | 1     | Static import of `../../src/integration/invoice-processed.handler` (`InvoiceProcessedHandler`, a VALUE import — see note below) fails module resolution. Payload built ONLY from `InvoiceProcessedEventPayload` in `@acme/event-contracts` (confirmed present, stable — no invented fields) |

**Correctness note:** the RED-trigger import for the not-yet-existing handler
MUST be a value import (`import { X } from ...}`), never `import type { X }`.
A type-only import is elided entirely by the SWC transpiler Vitest/Cucumber
use in this repo, so it would silently NOT fail at runtime — this was caught
and fixed during generation (the pact spec initially had this bug; corrected
before finalising). All RED-trigger imports across every new file in this
manifest were re-checked and are value imports.

## Scenario coverage matrix (9 PRD features + 1 companion)

| PRD Feature | `.feature`                                          | tc spec(s)                                                                                                                                                          | Unit stub(s)                                             | Pact |
| ------------------------------------------------------- | --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------- | -------------------------------------------------- |
| Invoice write-back (US-1, US-3)                         | invoice-write-back.feature | invoice-writeback.tc.spec.ts | mikro-orm-processed-event.repository.spec.ts (trading)   | accounting-invoice-processed.consumer.pact.spec.ts |
| Concurrent oversell prevention (US-2)                   | concurrent-oversell-prevention.feature | stock-oversell-race.tc.spec.ts | —                                                        | —                                                  |
| Optimistic concurrency (US-4)                           | optimistic-concurrency.feature | optimistic-locking.tc.spec.ts | —                                                        | —                                                  |
| Idempotent financial mutations (US-5)                   | idempotent-financial-mutations.feature | idempotency-key.tc.spec.ts | mikro-orm-idempotency.store.spec.ts | —                                                  |
| Soft delete (US-6)                                      | soft-delete.feature | soft-delete-visibility.tc.spec.ts | soft-delete-filter.spec.ts | —                                                  |
| Deal-list server-side filtering (US-7)                  | deal-list-filtering.feature | deal-list-filters.tc.spec.ts | —                                                        | —                                                  |
| Batch lock and CSV export (US-8)                        | batch-lock-csv-export.feature | deal-batch-lock.tc.spec.ts | lock-deal-batch.use-case.spec.ts | —                                                  |
| Lifecycle completeness (US-9)                           | lifecycle-completeness.feature | lifecycle-gap-fills.tc.spec.ts | —                                                        | —                                                  |
| Money-pipeline observability (US-10)                    | money-pipeline-observability.feature | (covered by redelivery-metric assertions inside invoice-writeback / consumer-inbox-redelivery specs — no dedicated tc spec; metrics module is pure infra, task 009) | —                                                        | —                                                  |
| Inventory redelivery idempotency (US-3, FR-4 companion) | consumer-redelivery-idempotency.feature (inventory) | consumer-inbox-redelivery.tc.spec.ts (inventory)                                                                                                                    | mikro-orm-processed-event.repository.spec.ts (inventory) | —                                                  |

## Blockers / observations (none block generation; recorded for the record)

1. **No type-contract blocker.** The inbound event's payload type already
   exists in the shared `libs/platform/event-contracts` lib — hard rule 3's
   stop-condition did not trigger; the pact/consumer specs were written as
   instructed against that type, with no invented fields.
2. **PRD/event-contracts naming nuance (not a blocker).** The literal the PRD
   Gherkin uses for the payload's `sourceEntityType` is not among the values
   the contract's own comment enumerates. The field is typed as plain `string`
   (not a literal union), so this is not a compile-time conflict — used the
   PRD's literal verbatim per its status as acceptance-criteria source of
   truth. T2 must confirm the canonical value with the publishing service
   before finalising the handler's switch/match: a string-typed contract field
   turns a producer/consumer vocabulary mismatch into a runtime no-match that
   no type-checker will catch, and the implementing task is the last place it
   can still be cheap to fix.
3. **Prior-art, not a collision.** `stock-position-materialisation.feature`
   already has an (unrelated-epic, separately-scoped, also-`throw new
Error('Not implemented yet')`) redelivery scenario for
   `trading.purchase.receipted`. This epic's new inventory feature targets
   `trading.sale.created` specifically and is additive — no file was modified,
   no step pattern collides (verified by grep).
4. **`LockDealBatchUseCase`/`DealExportService` constructor shapes are
   illustrative.** `deal-batch-lock.tc.spec.ts` and its unit stub wire these
   not-yet-existing classes using casts (`as unknown as new (...)`) mirroring
   `LockDealUseCase`'s real dependency shape, since the epic explicitly
   describes batch-lock as wrapping the same per-deal mechanics. The RED
   trigger (import failure) does not depend on getting this exactly right —
   T7 owns the final signature.
5. **Existing suites left untouched.** No existing test file was modified —
   only two ADDITIVE step-definition files were created
   (`hardening.steps.ts` in each service), alongside wholly new spec/feature
   files. `git status` shows only new files (see Verification).

## Verification (hard rule 7 / 9 — exactly what was run, real output)

Ran ONLY fast static checks — no testcontainers, no Cucumber, no Pact
execution (all too slow / require Docker+RabbitMQ per hard rule 7):

```
npx nx run platform-trading-service:typecheck
npx nx run platform-inventory-service:typecheck
```

- **Note on scope:** both projects' `tsconfig.json` sets
  `"include": ["src/**/*.ts"]` and `"exclude": [..., "test"]`. This means
  `typecheck` compiles the 5 unit stubs under `src/**/__tests__/` (they DO
  fail to resolve their not-yet-existing imports, as intended) but does
  **NOT** compile anything under `test/` (the 10 `.feature` files' step defs,
  the 9 `.tc.spec.ts` files, or the pact spec) — Vitest/Cucumber transpile
  those with SWC (no type-checking), so `typecheck` cannot be used to prove
  their RED status; their RED reasons are argued from source-reading (see
  tables above) and were not executed in this pass.
- Real command output and pass/fail counts are reported in the final summary
  message of this session (not duplicated here to avoid drift if re-run).
