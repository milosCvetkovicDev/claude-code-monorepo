# CLAUDE.md - Legacy Backend

Extends root `CLAUDE.md`. Express + TypeORM + PostgreSQL.

## Commands

```bash
npm run dev / build              # Dev server / build
npm test / test:unit / test:integration
npm run lint / format
docker compose up -d             # PostgreSQL + Azurite
npm run db:recreate              # Full DB reset + commission setup
npm run db:migrate               # Run pending migrations
npm run generate:migration src/migrations/Name
npx nx run legacy-api:db:seed:fake          # default profile
npx nx run legacy-api:db:seed:fake:trader   # same data, dev users seeded as Trader
npx nx run legacy-api:db:seed:fake:finance  # same data, dev users seeded as Finance
npx nx run legacy-api:db:seed:fake:md       # same data, dev users seeded as MD
npx nx run legacy-api:db:seed:fake:fast     # smaller dataset
npx nx run legacy-api:db:seed:fake:standard # larger dataset
```

Seed profiles are parameterised on two axes — dataset size and the role the dev user is given — so a
role-gated screen can be exercised locally without hand-editing rows. Adding a role means adding a
profile, not a manual `UPDATE`.

## Structure

`src/`: `api/` (ERP, Graph), `controllers/` (thin → services), `db/migrations/`, `helpers/`, `jobs/` (pg-boss), `middleware/`, `models/{db,request,response,error}/`, `repositories/`, `services/`, `templates/` (PDF)

## Code Patterns

- **Controllers**: Thin. `asyncHandler` wrapper, `req.getTradingCompanyOrThrow()`, Zod via `validateRequest`
- **Services**: `import * as FooService`, PascalCase files. `find*/get*`, `create*/update*/destroy*`, `parse*/build*/map*`
- **Repositories**: Factory taking `TradingCompany`, extend `RepositoryWithTradingCompany`
- **Entities**: `src/models/db/`, decorators, `BigNumericTransformer` for numeric, `DateTransformer` for dates
- **Request validation**: Zod in `src/models/request/`, export schema + typed request
- **Response builders**: `build*Response` in `src/models/response/`

### Money formulas: one implementation, every consumer (CRITICAL)

A monetary formula gets **exactly one** canonical implementation — here, `src/helpers/dealLineHelpers.ts` —
and every consumer calls it. The consumers that break this rule are never the ORM paths: it is the
hand-written SQL, the reports and the exports that re-derive the arithmetic and drift, because each
one was written against the formula as it stood that week. The term such a query forgets is almost
always the unit conversion: it is a join rather than an arithmetic operator, so it does not look
like part of the formula, and omitting it produces a number that is wrong by a factor rather than
by a rounding error.

**Regression test:** `test/repositories/UnifiedInvoicesRepository.spec.ts` asserts that every SQL
path includes the conversion join — a cheap structural check that catches the next query written
without it, which no amount-level assertion would.

**ADR:** `docs/adr/0009-invoice-net-amount-formula-single-source-of-truth.md`

### Relations reachable only through a child collection (IMPORTANT)

Not every association is a direct 1:1. Where one aggregate is reachable only *via* a child
collection, expose a throwing accessor (`getSaleOrThrow()`) plus a `has*` guard instead of letting
callers assume a direct relation, and load the intermediate relation explicitly (`lineItems.sale`).
An unloaded hop through a collection is the classic shape of a bug that passes in tests — where the
fixture happens to be fully hydrated — and returns `undefined` in production.

## Database

- Migrations imported in `config/DataSourceConfig.ts` — add new ones there
- **Never remove migrations** — create new ones to undo/modify
- **Schema changes in migrations**; one-off data fixes can be manual (documented)
- **Exact matching** in data migrations (`WHERE name = 'X'`, not `ILIKE`)
- Check table size before index migrations; >100K rows needs maintenance window; >1M use `CONCURRENTLY`
- Multi-tenancy: entities scoped to `TradingCompany`, repos filter automatically

## Testing

| Type | Command | Workers | DB                 | CI             |
| ----------- | ------------------------------------------- | --------- | ------------------ | -------------- |
| Unit | `npx nx run legacy-api:test:unit`        | 50% cores | Mock AppDataSource | Enabled |
| Integration | `npx nx run legacy-api:test:integration` | Serial | Real PostgreSQL    | Disabled (#80) |

- Unit: mock `AppDataSource` + `mockRepositoryUtils`. Setup: `setupUnit.ts`
- Integration: real DB via `setupDB.ts`, `supertest`. Run `docker compose up -d` first

## Commission Proxy (IMPORTANT)

`CommissionProxyController.ts` proxies requests to domain-api. It has **allowlists** for query parameters and export formats per endpoint. When domain-api adds new capabilities (e.g., new export format, new query parameter), the proxy allowlist MUST also be updated or the proxy will reject valid requests with 400.

**Proxy routes** (mounted at `/v1/commission`):

| Proxy Route | Forwards To | Query Allowlist |
| --------------------------------- | ------------------------------------ | ------------------------ |
| `GET /commissions`                | `/api/v1/commissions`                | `COMMISSIONS_QUERY_KEYS` |
| `GET /commissions/traders`        | `/api/v1/commissions/traders`        | `['companyId']`          |
| `GET /commissions/companies`      | `/api/v1/commissions/companies`      | _(none)_                 |
| `GET /commissions/deal/:dealId`   | `/api/v1/commissions/deal/:dealId`   | _(none)_                 |
| `PATCH /commissions/:id/pay`      | `/api/v1/commissions/detail/:id/pay` | _(body only)_            |
| `GET /reports/trader/:traderId`   | `/api/v1/reports/trader/:traderId`   | `REPORT_QUERY_KEYS`      |
| `GET /reports/company/:companyId` | `/api/v1/reports/company/:companyId` | `REPORT_QUERY_KEYS`      |
| `GET /reports/all-companies`      | `/api/v1/reports/all-companies`      | `REPORT_QUERY_KEYS`      |
| `GET /reports/export`             | `/api/v1/reports/export`             | `EXPORT_QUERY_KEYS`      |

**Local routes** (not proxied — handled directly by legacy-api):

| Local Route | Handler | Query Validation |
| ------------------------------------------- | --------------------------------- | ------------------------------ |
| `GET /reports/deal-profitability/companies` | `getDealProfitabilityCompanyList` | _(none)_                       |
| `GET /reports/deal-profitability`           | `getDealProfitability`            | `DealProfitabilityQuerySchema` |
| `GET /reports/deal-profitability/export`    | `exportDealProfitability`         | `DealProfitabilityQuerySchema` |

### Period assignment (CRITICAL)

**The rule that generalises:** two features that report on the same entity must share **one**
period-assignment implementation. These had diverged — one using the record's own timestamp, the
other a separately computed effective date — and produced different totals for the same month, which
is how the divergence was found. One canonical resolver, called by both.

Resolve the period **once**, when the record is finalised, into a stored column rather than deriving
it per query: the inputs move afterwards, so a derived value silently rewrites history. The
repository filters on that column and falls back to the record's own timestamp for rows predating it.

**Multi-month query:** filter with a half-open range (`>= :start AND < :endExclusive`). Do **not**
use `EXTRACT(YEAR/MONTH)` — it silently breaks for any range spanning more than one month.

### Freezing a derived monetary value (CRITICAL)

The derived monetary total is **stored on the record when the record is finalised**, and the response
builder serves that stored value — falling back to a live calculation only for historical rows where
the column is NULL.

**Why freeze — the durable lesson:** the live calculation resolved exchange rates against
`invoice?.date ?? now`. `now` moves, new rates land, and the figure drifts away from the value a
downstream system already committed to. Any derived monetary value that another context has already
consumed must be **stored at the moment of the decision**, not recomputed on read. The rate-loading
helper therefore takes an explicit `getFallbackDate` parameter, so each caller has to state which
date basis it means instead of inheriting `now` by accident.

### DealLockedEvent Interface

`DealLockedEvent` in `DealsService.ts` is the typed interface for the webhook payload sent to domain-api when a deal is locked. It is the single source of truth for the contract between Trading and Commission contexts. Both the live webhook and `scripts/backfill-commissions.ts` must produce payloads conforming to this interface. See ADR-0011 for the consistency model.

### Webhook Failure Alerting

`emitDealLockedWebhook()` is fire-and-forget (deal lock always succeeds). Failures are tracked via:

- Console structured logging: `category: 'COMMISSION_WEBHOOK'`
- Application Insights: `trackException` with `category: 'COMMISSION_WEBHOOK_FAILURE'`
- `trackWebhookFailure()` helper handles both HTTP errors and network errors

Reconciliation: `scripts/check-missing-commissions.sh` detects locked deals without commission records. Recovery: `scripts/backfill-commissions.ts` (idempotent — domain-api returns 409 for existing deals).

### Deal GP Sync Webhook

`emitDealGpUpdatedWebhook()` in `WebhookService.ts` fires after the stored gross profit is
recalculated, sending the aggregate id and the new total to `POST /api/internal/deal-gp-updated`.
Fire-and-forget — the originating write never fails because of a webhook error. Uses the same
`COMMISSION_WEBHOOK` telemetry category (100% sampling bypass, P1 alert on failure).

**Skip outcomes — the integration lesson:** a fire-and-forget receiver answers with a **versioned
response carrying a closed-set `outcome`**, so the sender can tell *applied* from *deliberately
skipped* from *not applicable*. HTTP status alone cannot make that distinction — a policy skip and a
failure both arrive as "not applied" — and a not-applicable answer is reclassified sender-side as a
Warning rather than an error, so a normal outcome does not page anyone.

### Manual GP Reconcile Endpoint (epic #929)

`POST /api/api/internal/reconcile-gp` (`InternalReconcileController`) triggers a GP reconcile sweep. The controller is mounted under the app's `/api` router, so the externally reachable path is `/api/api/internal/reconcile-gp`.

- **Auth**: a shared-secret request header checked against an env-provided key (no user session).
- **Default = audit/dry-run** (no writes). `?remediate=true` opts into writes (logs `MANUAL_REMEDIATE_REQUESTED`).
- **Rate limit**: 1 call / 60s.

**Route ordering matters**: literal routes (`/traders`, `/companies`) MUST be registered before parameterized routes (`/:dealId`, `/:id`) in Express.

**Source of truth for export formats**: `@acme/shared-constants` (`EXPORT_FORMATS` / `ExportFormat`). The proxy imports `EXPORT_FORMATS` from the shared library — no hardcoded list to maintain.

**Proxy error logging**: `CommissionProxyService` logs structured JSON with `category: "COMMISSION_PROXY"` and `commission_event_type` for alerting (P2 alert in app-insights module).

## Auth

Microsoft Graph tokens via MSAL (empty scopes). Backend validates `appid`+`tid`, calls Graph `/me` → gets Entra ID → looks up `user` table. User must exist in DB or 401.

## Env Vars

Access via `src/helpers/environmentVariableHelpers.ts`, never `process.env`. Key helpers: `isProductionEnvironment()`, `getRequiredEnvironmentVariableValue()`. Copy `.env.template` → `.env`.

ERP mock: Local+dev use `USE_ERP_MOCK=true`; production uses real API with `ENVIRONMENT_NAME=production`.

**Reconcile/remediation caps** (accessed via `environmentVariableHelpers`) — an automated write against
financial data is bounded, never open-ended:

- `REMEDIATION_MAX_DIFF_*` — a **paired absolute and relative stop-loss**. Drift over EITHER cap skips
  the automatic write and raises `GP_MISMATCH_OVER_THRESHOLD` for manual review. Absolute alone lets a
  large record drift proportionally; relative alone lets a small one drift absurdly — the pair is the point.
- `REMEDIATION_MAX_REVALUE_COUNT` — a batch circuit-breaker (`GP_MASS_REVALUE_DETECTED`): a sweep that
  would revalue more rows than a run plausibly should stops instead of mass-writing.
- `COMMISSION_API_INTERNAL_KEY` — shared secret for the manual reconcile endpoint (checked against a request header).

## ERP API

All calls through `erpApiGuard.ts` (retry, logging, env filtering). Direct `erpApi.ts` imports blocked by ESLint. Non-production filtered to demo company. Schema drift detection in production.

## Background Jobs (pg-boss)

`ProcessPurchaseInvoiceJob`, `ProcessSaleInvoiceJob`, `SyncErpCustomersJob`. Implement `Job<T>` interface.

## Pagination Helpers

`src/helpers/paginationHelpers.ts`: `createOrderByValidator<T>()`, `calculateHasNextPage()`, `createPaginatedResult<T>()`. Defense-in-depth: Zod validates at request layer, repository validates again before SQL.
