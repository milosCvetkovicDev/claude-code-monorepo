# CLAUDE.md — Finance-domain service (Bun + Elysia)

A Bun + Elysia service owning one finance bounded context: it consumes domain events from the
trading system, derives monetary records, and serves reports over a proxied API.

> **Scope note.** The business rules this service implements are the employer's, not transferable
> engineering knowledge, and are deliberately **not** reproduced in this export — endpoint
> inventories, domain rules and calculation policy are omitted. What remains is the engineering:
> the Bun/Elysia/Drizzle patterns, the multi-instance and CORS setup, the webhook contract shape,
> the migration discipline and the operational guardrails. See [SANITIZATION.md](../../../SANITIZATION.md).

## Quick Reference

```bash
# Development
nx run domain-api:serve              # Start with hot reload

# Build
nx run domain-api:build

# Test
nx run domain-api:test

# Lint & Typecheck
nx run domain-api:lint
nx run domain-api:typecheck

# Docker (IMPORTANT: use --platform linux/amd64 when building on Apple Silicon for Azure)
nx run domain-api:docker-build
docker buildx build --platform linux/amd64 -f apps/domain-api/Dockerfile -t <tag> .

# Database (Drizzle)
nx run domain-api:db:generate        # Generate migrations
nx run domain-api:db:migrate         # Run migrations
nx run domain-api:db:seed:dev        # Seed dev closed commission months (run after db:recreate)
```

## Architecture

```
src/
├── index.ts              # Entry point - bootstrap Elysia app
├── config/
│   └── env.ts            # Environment config (Zod validation)
├── routes/
│   ├── health.routes.ts  # /health, /health/live, /health/ready
│   ├── commission.routes.ts  # /api/v1/commissions
│   ├── report.routes.ts      # /api/v1/reports
│   ├── admin.routes.ts       # /api/v1/admin (commission month management)
│   └── internal.routes.ts    # /api/internal (webhooks)
├── plugins/
│   ├── error-handler.plugin.ts  # Domain error to HTTP mapping
│   ├── cors.plugin.ts           # CORS configuration
│   ├── rate-limit.plugin.ts     # Rate limiting
│   ├── security-headers.plugin.ts # Security headers
│   └── logger.plugin.ts         # JSON logging with correlation IDs
├── services/
│   ├── trader-lookup.service.ts    # Trader company lookup for authorization
│   ├── export.service.ts           # CSV export generation
│   └── pdf/                        # PDF report generation (pdfmake + SVG charts)
│       ├── index.ts                # Barrel export
│       ├── pdf-generator.ts        # pdfmake wrapper (generatePdfBuffer)
│       ├── pdf-theme.ts            # Styles, page layout, A4, Helvetica fonts
│       ├── pdf-helpers.ts          # Formatters: money(), percentage(), headerCell()
│       ├── chart-svg.ts            # Pure SVG generators (area, bar, donut charts)
│       ├── chart-colors.ts         # CHART_COLORS palette (matches frontend)
│       ├── trader-report-pdf.ts    # Trader PDF: summary + area + donut + deals
│       ├── company-report-pdf.ts   # Company PDF: summary + area + bar + traders
│       └── all-companies-report-pdf.ts  # All companies PDF: summary + bar + donut
├── middleware/
│   ├── auth.middleware.ts      # Internal API key authentication (legacy-api proxy)
│   ├── auth.types.ts           # User roles and types
│   └── webhook.middleware.ts   # Webhook secret validation
├── database/
│   ├── client.ts               # Drizzle database connection
│   ├── repositories.ts         # Repository initialization
│   └── index.ts                # Exports
└── drizzle/
    ├── schema.ts         # Database schema
    └── migrations/       # SQL migrations
```

## API surface (shape, not inventory)

Three tiers, which is the part worth copying:

| Tier         | Auth                    | Purpose                                                        |
| ------------ | ----------------------- | -------------------------------------------------------------- |
| `GET /health`, `/health/live`, `/health/ready` | none | Full status w/ dependency checks; liveness always-200; readiness checks the DB |
| `/api/v1/*`  | role-gated              | The domain read/write API, reached **only** through the monolith's proxy |
| `/api/internal/*` | shared-secret header | Webhook receivers — machine callers, never a user session       |

**Rules that generalise:** liveness must never check a dependency (a slow DB then restarts a
healthy pod); readiness must; and internal webhook routes authenticate by shared secret rather than
by user session, because the caller is another service. Role-gated list endpoints scope results to
the caller **server-side** — a client-side filter is not access control.

## Environment Variables

| Variable | Required | Default | Description |
| ------------------------------------------ | -------- | ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `PORT`                                     | No | 3200        | Server port |
| `ENVIRONMENT_NAME`                         | No | development | For logging |
| `DATABASE_URL`                             | Yes | -           | PostgreSQL connection |
| `INTERNAL_API_KEY`                         | Yes | -           | Proxy auth key (must match legacy-api)                                                                                                                                                                                              |
| `LEGACY_BACKEND_URL`                        | No | -           | For deal data |
| `WEBHOOK_SECRET`                           | No | -           | Internal endpoint auth |
| `COMMISSION_GP_POLICY_ENFORCEMENT_ENABLED` | No | `false`     | Feature flag gating the stricter write policy (and its `gp_drift_holds` queue writes) in the `deal-gp-updated` receiver. Read **per request** in `src/config/env.ts`, so the policy can be turned off without a redeploy; `false` retains the previous behaviour. |

> **Auth model (simplified 2026-02-12):** All requests arrive via legacy-api's proxy, which authenticates users via MSAL/Entra and forwards user context as `X-User-*` headers with `X-Internal-Api-Key`. The service validates the API key and trusts the headers. No direct user authentication (cookie/bearer/OAuth) is needed.

## Rules as data

Rate/scheme configuration lives in a **table**, loaded at startup and cached — not in code. Two
consequences worth writing down next to it: a config change requires a restart (see *Service
Restart Requirements*), and an entity with no matching row is a legitimate "not applicable" state
that must be modelled explicitly (the webhook returns `404`, which the caller reclassifies as
benign) rather than treated as an error.

Derived financial records are **immutable, enforced by a database trigger** (migration `0003`) —
application-layer immutability is one careless repository method away from being untrue. The single
sanctioned correction path is an explicit, audited webhook, not a relaxation of the trigger.

## Database Migrations

| Migration | Description |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `0000_initial_schema`                  | Commission tables: `commission_rules`, `commissions`                                                   |
| `0001_add_commission_adjustments`      | `commission_adjustments` table for post-lock credit notes |
| `0002_add_denormalized_names`          | Denormalized trader/company names on commission records |
| `0003_add_immutability_trigger`        | ADR-007: PostgreSQL trigger preventing UPDATE except `pending → paid`                                  |
| `0004_add_paid_at`                     | `paid_at` and `payment_reference` columns on commissions |
| `0005_add_constraints`                 | CHECK constraints on commissions (type, month, year, status)                                           |
| `0006_create_closed_commission_months` | `closed_commission_months` table with unique `(company_id, month, year)`                         |
| `0008_create_gp_drift_holds`           | `gp_drift_holds` observability/remediation queue with unique `(deal_id, reason)`                        |

**Migration 0003 (immutability trigger)**: Creates `prevent_commission_update()` function and `commission_immutability` BEFORE UPDATE trigger. Only allows status change from `pending` to `paid` (auto-sets `paid_at` and `updated_at`). All other UPDATEs raise an exception. Must be deployed before production go-live.

**Migration 0008 (`gp_drift_holds`)**: creates the hold-queue table (`id`, `deal_id`, `reason`, `company_id`, the two `NUMERIC(15,4)` amounts being compared, `period_month`, `period_year`, `detected_at`, `created_at`) with UNIQUE `(deal_id, reason)` as the idempotent de-dup key — the same input landing twice updates nothing and creates nothing.

The pattern worth copying: when a sync **cannot be applied safely**, write a de-duplicated hold row for human review instead of mutating. The queue is observability, never a financial mutation, and it is the only place the "we saw this and chose not to act" state exists. **Intentionally NOT in the Drizzle `_journal.json`**, so `drizzle-kit migrate` skips it — apply with `psql -f`.

### Migration Authoring Rules

**Statement breakpoint requirement for PL/pgSQL:**

Drizzle splits SQL files on `--> statement-breakpoint` markers. PL/pgSQL blocks (functions, triggers) contain semicolons that look like statement boundaries but are part of the `$$ ... $$` block. Every `$$ LANGUAGE plpgsql;` line **MUST** be followed by `--> statement-breakpoint` before the next SQL statement.

```sql
-- CORRECT
$$ LANGUAGE plpgsql;
--> statement-breakpoint
CREATE TRIGGER ...

-- WRONG (will merge with next statement and fail)
$$ LANGUAGE plpgsql;
CREATE TRIGGER ...
```

**Destructive SQL blocking (CI-enforced):**

The validation script also blocks destructive SQL in migrations: `DROP TABLE`, `DROP SCHEMA`, `TRUNCATE`, and `DELETE FROM` without `WHERE`. These are never intended for forward migrations. If intentional, use a separate manual script with explicit approval.

**Validation:**

```bash
bash scripts/validate-migrations.sh
```

**Psql fallback (when drizzle-kit fails):**

```bash
DATABASE_URL="postgresql://..." bash scripts/apply-migrations-psql.sh apps/domain-api/drizzle/migrations
DATABASE_URL="postgresql://..." bash scripts/apply-migrations-psql.sh apps/domain-api/drizzle/migrations --dry-run
```

**Production targeted migration (preferred for single migrations):**

The psql fallback script may show all migrations as "WOULD APPLY" if the journal table state doesn't match expectations. For applying a specific migration to production, use `psql -f` directly:

```bash
PGPASSWORD="..." psql -h <host> -U <user> -d <database> -f apps/domain-api/drizzle/migrations/<nnnn>_<name>.sql
```

Verify after: `psql -c "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename;"`

## Export Formats

Export formats (csv, pdf, xlsx) are defined once in `@acme/shared-constants` (`EXPORT_FORMATS` / `ExportFormat`). The TypeBox schema in `report.routes.ts` and the Elysia schema in `api-types` stay explicit for framework compatibility but include a comment referencing the shared constant as the source of truth.

## Infrastructure Protection

The service's Container App and Container App Environment are protected by Azure Management Locks (`CanNotDelete`) in development and production. Controlled by `enable_delete_lock` variable in `infra/modules/domain-api/`. Locks must be removed before intentional teardown. Ephemeral dev instances (dev-2, dev-3, etc.) are NOT locked.

## Related Libraries

| Library | Purpose |
| ----------------------------------- | ------------------------------- |
| `@acme/commission-domain`         | Domain entities & services |
| `@acme/commission-application`    | Use cases |
| `@acme/commission-infrastructure` | Drizzle repositories |
| `@acme/domain-api-types`      | Shared DTOs |
| `@acme/shared-constants`          | Export formats, company configs |

## Related Documentation

Each bounded context keeps four documents beside its code — an architecture note, a data model, an
API design, and the feature specification — and a CLAUDE.md like this one points at all four so an
agent picks them up without being told. For this context all four are business-domain documents
and stayed behind; what the export carries instead is the conventions they were written to, in
the architecture set under [`docs/architecture/`](../../../docs/architecture/README.md).

## Multi-Instance Development (CRITICAL)

### CORS Configuration for Multiple Instances

The domain-api CORS plugin (`src/plugins/cors.plugin.ts`) **MUST** include ALL development instance ports:

```typescript
const allowedOrigins =
  environmentName === 'production'
    ? ['https://commission.acme.example.com', 'https://app.acme.example.com']
    : [
        // Instance 1-5: legacy-web
        'http://localhost:4200',
        'http://localhost:4201',
        'http://localhost:4202',
        'http://localhost:4203',
        'http://localhost:4204',

        // Include 127.0.0.1 variants
      ];
```

**Port Allocation Formula**: `Port = BasePort + (Instance - 1)`

| App | Base Port | Instance 1 | Instance 2 | Instance 3 | Instance 4 | Instance 5 |
| -------------- | --------- | ---------- | ---------- | ---------- | ---------- | ---------- |
| legacy-web | 4200      | 4200       | 4201       | 4202       | 4203       | 4204       |
| domain-api | 3200      | 3200       | 3201       | 3202       | 3203       | 3204       |
| commission-db | 5444      | 5444       | 5445       | 5446       | 5447       | 5448       |

**Symptoms of CORS misconfiguration:**

- Browser console: `Access to fetch at 'http://localhost:3201/...' from origin 'http://localhost:4401' has been blocked by CORS policy`
- Network tab: Request fails with status (cancelled)
- No error in domain-api logs (request blocked before reaching server)

## Webhook Integration with Legacy-Backend

### Required Environment Variables

The service receives webhooks from the monolith when a source aggregate reaches a terminal state:

```bash
# In domain-api .env
WEBHOOK_SECRET=<shared-secret>  # Must match legacy-api
```

```bash
# In legacy-api .env
COMMISSION_API_WEBHOOK_URL=http://localhost:3201
COMMISSION_API_WEBHOOK_SECRET=<shared-secret>  # Must match domain-api
```

### Webhook Endpoint

`POST /api/internal/deal-locked`

**Payload shape** (the field-level contract is domain detail; the structure is what generalises): the
lock event carries the **aggregate id**, the owning company as id *plus* denormalised name, the
monetary total as a **decimal string**, an ISO timestamp, the acting user id, and the **participant
contribution shares** — one array per side of the transaction, each entry an id plus a denormalised
name plus a decimal-string quantity.

Two rules travel with that shape:

- **Money and quantities cross the boundary as strings, never JS numbers.** A float here rounds
  silently and the receiver's derived record is wrong with nothing in any log.
- **The event carries denormalised names**, so the receiver can render and report without calling
  back into the sender for display data. It stores what the sender believed at emit time, which is
  also what an audit of that moment should show.

**Response:**

```typescript
{
  success: true;
  commissionsCreated: number; // Count of commission records created
}
```

### Seeded configuration must match by id, not by name

Configuration rows that reference another table by **both** an id and a denormalised name will
drift: the seed writes the name correctly and the id from a different environment. The symptom is
a runtime "no active rule found for X" from the webhook, long after seeding looked successful.

Verify by joining config → referenced table on the name and comparing ids, then repair by setting
the id from the join. The durable fix is to not seed the id at all — resolve it at load time — but
the join-and-repair query is what you need when the rows already exist.

### Service Restart Requirements

The service caches configuration at startup. **Restart required after**:

1. ✅ Direct database updates to `commission_rules` table
2. ✅ Environment variable changes (`.env` file)
3. ✅ Commission rule seeding via domain-api startup

```bash
# Restart domain-api
nx run domain-api:serve
```

---

## Elysia Patterns & Best Practices

### HTTP Redirects

Elysia does NOT provide a `redirect()` function by default. Use explicit status and headers:

```typescript
// ✅ CORRECT
app.get('/login', ({ set }) => {
  set.status = 302;
  set.headers['location'] = '/destination';
  return; // MUST return to prevent handler from continuing
});

// ❌ WRONG - redirect() doesn't exist
app.get('/login', ({ redirect }) => {
  return redirect('/destination'); // Error: redirect is undefined
});
```

**Critical:** Always `return` after setting redirect headers to prevent the handler from continuing execution and potentially overwriting the response.

### Authorization Error Handling

Always set `set.status` before throwing authorization errors:

```typescript
// ✅ CORRECT - Returns 403 Forbidden
if (user.role !== 'Admin') {
  set.status = 403;
  throw new ForbiddenError('Admin access required');
}

// ❌ WRONG - May return 500 instead of 403
checkRoles(user, ['Admin']); // Helper function throws without setting status
```

**Pattern for all authorization checks:**

1. Check authorization condition
2. Set `set.status` (401 for authentication, 403 for authorization)
3. Throw typed error (`UnauthorizedError` or `ForbiddenError`)
4. Error handler will format JSON response automatically

### Error Handler Integration

The error handler automatically maps error names to HTTP status codes:

```typescript
const statusMap: Record<string, number> = {
  UnauthorizedError: 401,
  ForbiddenError: 403,
  CommissionAlreadyCalculatedError: 409,
  // ...
};
```

But **only if** `set.status` is set before throwing. Otherwise errors may return as 500.

---

## Observability & Alerting

### Startup Verification

On bootstrap, domain-api:

1. **Verifies required tables** (`commission_rules`, `commissions`, `commission_adjustments`) — fails fast in production, warns in dev
2. **Logs active commission rules count** — zero rules = all webhooks will fail with `NO_RULE`
3. **Caches table verification result** — readiness probes use the cached result (no per-request `pg_tables` query)

### Structured Logging

**legacy-api** (webhook sender) logs structured JSON:

```json
{
  "category": "COMMISSION_WEBHOOK",
  "commission_event_type": "WEBHOOK_SUCCESS",
  "dealId": "<aggregate-id>",
  "resolvedUrl": "https://host.azurecontainerapps.io/api/internal/deal-locked",
  "durationMs": 342
}
```

Event types: `WEBHOOK_SENDING`, `WEBHOOK_SUCCESS`, `WEBHOOK_HTTP_ERROR`, `WEBHOOK_NETWORK_ERROR`, `WEBHOOK_NOT_CONFIGURED`

Credit note webhooks: `CREDIT_WEBHOOK_SENDING`, `CREDIT_WEBHOOK_SUCCESS`, `CREDIT_WEBHOOK_HTTP_ERROR`, `CREDIT_WEBHOOK_RETRY`, `CREDIT_WEBHOOK_EXHAUSTED`

**legacy-api** (commission proxy) logs structured JSON:

```json
{
  "category": "COMMISSION_PROXY",
  "commission_event_type": "PROXY_UPSTREAM_5XX",
  "status": 502,
  "message": "Commission API returned 502",
  "timestamp": "2026-02-13T15:00:00.000Z"
}
```

Proxy event types: `PROXY_UPSTREAM_5XX`, `PROXY_TIMEOUT`, `PROXY_CONNECTION_FAILED`, `PROXY_UNEXPECTED_ERROR`

**domain-api** (webhook receiver) logs:

- `[DealLocked] Received` — with trader counts
- `[DealLocked] Created` — with `commissionsCreated` count
- `[DealLocked] Failed` — with `errorCode` (e.g., `NO_RULE`, `ALREADY_CALCULATED`)

### Health Checks

| Endpoint | Checks | Failure |
| ----------------- | ----------------------------------------------------- | ------------------- |
| `/health`         | DB connectivity + cached table verification | Returns `unhealthy` |
| `/health/ready`   | DB + tables (distinguishes `queryError` vs `missing`) | Returns 503         |
| `/health/live`    | Process running | Always 200          |
| `/health/startup` | Immediate | Always 200          |

### Azure Alert Rules (Terraform)

Alert rules in `infra/modules/app-insights/main.tf` + `infra/modules/domain-api/main.tf`:

| Alert | Module | Severity | Trigger |
| ---------------------------------------- | -------------- | -------- | ------------------------------------------------------------------------------ |
| `commission-webhook-failure`             | app-insights | P1       | `WEBHOOK_HTTP_ERROR` or `WEBHOOK_NETWORK_ERROR`                                |
| `commission-webhook-not-configured`      | app-insights | P1       | `WEBHOOK_NOT_CONFIGURED`                                                       |
| `commission-credit-webhook-exhausted`    | app-insights | P2       | `CREDIT_WEBHOOK_EXHAUSTED`                                                     |
| `commission-proxy-failure`               | app-insights | P2       | `PROXY_UPSTREAM_5XX`, `PROXY_TIMEOUT`, `PROXY_CONNECTION_FAILED`               |
| `domain-api-unhealthy`               | domain-api | P1       | `[ERROR]` or `severityLevel:3` in ContainerAppConsoleLogs |
| `commission-gp-mismatch-skipped-policy`  | app-insights | P2       | A sync deliberately skipped by write policy rather than applied                |
| `commission-gp-mass-revalue-detected`    | app-insights | P2       | Mass-revalue circuit-breaker tripped (`GP_MASS_REVALUE_DETECTED`)              |
| `commission-gp-mismatch-not-applicable`  | app-insights | P2       | Benign not-applicable outcome — no matching configuration for the entity       |

**Deliberate skips must be subtracted from the error-rate alert.** The pre-existing P1 mismatch query
counted every non-applied outcome as an error. Once the receiver gained deliberate-skip outcomes,
each skip paged **twice** — its own P2 rule *and* the P1 error rate it inflated. The skip counters
are now subtracted from the P1 query. Whenever a system grows a new "we chose not to act" outcome,
every error-rate alert written before it has to be re-derived in the same change.

**Disabled:** the silence alert (zero logs for 10 min) was removed. A no-data alert is only
meaningful on a service with continuous traffic; on a low-volume, event-driven service, quiet **is**
normal operation and the rule is pure noise.

Controlled by `enable_commission_alerts` variable + `commission_alert_email_addresses`.

---

## Troubleshooting

### No Commissions Created (`commissionsCreated: 0`)

**Diagnosis checklist:**

1. **Check webhook logs** (legacy-api):

   ```bash
   grep "Commission webhook" <backend-log-file>
   # Should show: "purchaseTraders: X, salesTraders: Y" (X, Y > 0)
   ```

2. **Confirm the event's required participants were actually populated on the source rows** — before
   blaming the receiver, check that the sender had the data at all. A `NULL` participant on the
   source side produces a zero-count receive with no error logged anywhere, which reads exactly like
   a receiver bug.

3. **Check commission rules** (database):

   ```sql
   -- Verify rule exists for company
   SELECT * FROM commission_rules WHERE company_id = <company-id>;
   ```

4. **Verify domain-api received webhook** (domain-api logs):
   ```bash
   # Should show POST /api/internal/deal-locked
   grep "deal-locked" <domain-api-log-file>
   ```

### Webhook Authentication Failure

**Symptom:** Legacy-backend logs show `Commission webhook failed` with 401/403

**Solution:**

1. Verify `WEBHOOK_SECRET` matches in both `.env` files
2. Check domain-api is running: `curl http://localhost:3201/health`
3. Restart both services to reload environment variables

### Company ID Mismatch

**Symptom:** Error `"No active commission rule found for company X"`

**Root cause:** Commission rules reference old company IDs after database reset

**Solution:** Restart domain-api — it always validates company IDs against the database on startup:

```bash
# Restart domain-api to re-validate IDs
nx run domain-api:serve
```

If companies don't exist yet (legacy-api hasn't seeded), domain-api logs a warning and continues in development. Rules get seeded on next restart after companies exist.

### Missing Participants (Data Seeding Issue)

**Symptom:** the webhook reports zero participants on both sides.

**Root cause:** seeded records without their participant assignments — the source rows are
incomplete, so the event is correctly built from nothing.

**Fix:** reseed (`npm run db:recreate`) rather than patching rows by hand. Hand-repairing seed data
leaves a local database that no seed profile reproduces, and the next person to hit this bug debugs
a state that exists only on your machine.

### Pre-Webhook Deals Missing Commissions

**Symptom:** Locked deals have no commission records; only deals locked after webhook deployment have commissions.

**Root cause:** The deal-locked webhook only fires on the lock transition. Deals locked before the webhook was deployed were never processed.

**Solution:** Run the backfill script:

```bash
npx tsx scripts/backfill-commissions.ts \
  --db-url "postgresql://..." \
  --domain-api-url "https://..." \
  --webhook-secret "..." \
  --dry-run  # Preview first
```

The script finds locked deals with no commission records, calculates GP and trader contributions via SQL, and sends payloads through the existing `POST /api/internal/deal-locked` endpoint. Idempotent — safe to re-run.

---

## Azure Deployment Issues (2026-02-04)

### Webhook Investigation Process

When a webhook reports `commissionsCreated: N` but data seems missing, follow this systematic approach:

**Step 1: Verify webhook was sent** (legacy-api logs):

```bash
# Check background task output or console logs
grep "Commission webhook" <log-output>
# Should show: "Sending deal-locked webhook" and "Commission webhook succeeded"
```

**Step 2: Verify webhook was received** (domain-api logs):

```bash
# Check console output
grep "deal-locked\|POST.*internal" <log-output>
# Should show: POST /api/internal/deal-locked
```

**Step 3: Query database directly** (bypass API authentication):

```bash
docker exec acme2-db-1 psql -U legacy -d legacy_dev_2 \
  -c "SELECT COUNT(*) FROM commissions WHERE deal_id = <deal-id>;"
```

**Common False Leads:**

- ❌ Assuming webhook failed because API query returns empty/errors
- ❌ Not checking for expired authentication tokens
- ❌ Querying wrong database in multi-instance setup
- ❌ Suspecting schema issues (tables are in `public` schema with `commission_` prefix)

**Why API queries might fail while data exists:**

1. **Expired Bearer token** - Authentication required for all commission endpoints
2. **Authorization filtering** - Users can only see commissions for their company/role
3. **Wrong database** - Multi-instance setups use different databases per instance
4. **API not restarted** - Changes to commission rules require restart to reload cache

**Database Schema Note:**

Commission tables are in the **public schema** with `commission_` prefix:

- `public.commission_rules`
- `public.commissions`
- `public.commission_adjustments`

Do NOT add `?schema=commission` to DATABASE_URL - this will cause "schema does not exist" errors.

---

### Drizzle-kit False Success (IMPORTANT)

**Problem**: `drizzle-kit migrate` can report "migrations applied successfully!" without actually creating tables when the database connection fails silently (e.g., firewall rule expired, network issue).

**Always verify** tables exist after running drizzle-kit:

```bash
# After drizzle-kit migrate, verify tables:
npx tsx -e "
const postgres = require('postgres');
const sql = postgres(process.env.DATABASE_URL);
sql\`SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename IN ('commission_rules','commissions')\`
  .then(r => { console.log(r.map(t => t.tablename).join(',')); return sql.end(); })
  .catch(e => { console.error(e.message); process.exit(1); });
"
```

**Root cause**: drizzle-kit doesn't properly propagate connection errors — it creates the journal table but doesn't error when SQL execution fails.

### Drizzle Error Wrapping

Drizzle wraps PostgreSQL errors. `error.message` shows "Failed query: \<SQL\>" but the actual PG error is in `error.cause.message`. Always unwrap:

```typescript
const cause = error instanceof Error && error.cause instanceof Error ? error.cause : null;
const errorMessage = cause
  ? `${cause.message} (${error.message})`
  : error instanceof Error
  ? error.message
  : String(error);
```

### Drizzle Migrations in Docker

**Problem**: Docker builds fail to copy migration files, or migrations aren't applied in Azure Container Apps.

**Symptoms**:

```
Error: Migrations folder not found at /app/drizzle/migrations
Error: ENOENT: no such file or directory, scandir '/app/drizzle/migrations'
```

**Root Cause**: Drizzle migrations are generated locally in `apps/domain-api/drizzle/migrations/` but must be copied into Docker image.

**Solution - Dockerfile**:

```dockerfile
# Copy Drizzle schema and migrations
COPY apps/domain-api/drizzle/ ./drizzle/

# Verify migrations were copied (useful for debugging)
RUN ls -la drizzle/migrations/ || echo "Warning: No migrations found"
```

**Migration Application**:

```typescript
// src/database/client.ts or index.ts
import { migrate } from 'drizzle-orm/postgres-js/migrator';

// Run migrations on startup (development only - use separate job in production)
if (process.env.ENVIRONMENT_NAME === 'development') {
  await migrate(db, { migrationsFolder: './drizzle/migrations' });
  console.log('Database migrations applied');
}
```

**Production Best Practice**: Run migrations as a separate Azure Container Job before deploying the API:

```bash
# Create migration job (one-time setup)
az containerapp job create \
  --name dev-acme-domain-api-migrations \
  --resource-group development-acme-rg \
  --environment dev-acme-container-env \
  --image "ghcr.io/org/domain-api:main" \
  --command "bun" "run" "db:migrate" \
  --trigger-type Manual

# Run migrations before deployment
az containerapp job start \
  --name dev-acme-domain-api-migrations \
  --resource-group development-acme-rg
```

---

### Azure Key Vault Integration

**Problem**: Container Apps can't access Key Vault secrets due to network/permission issues.

**Symptoms**:

```
Error: The user, group or application does not have secrets get permission
secrets.value: Invalid value: "***": the secret value for secret "database-url" is invalid
```

**Prerequisites**:

1. **Managed Identity** enabled on Container App
2. **Key Vault Access Policy** or **RBAC role** assigned
3. **Network Rules** allow `AzureServices` bypass

**Solution - Terraform Module**:

```hcl
# infra/modules/domain-api/main.tf
resource "azurerm_container_app" "app" {
  identity {
    type = "SystemAssigned"
  }

  secret {
    name                = "database-url"
    key_vault_secret_id = "${var.key_vault_id}secrets/${var.database_url_secret_name}"
  }

  template {
    container {
      env {
        name        = "DATABASE_URL"
        secret_name = "database-url"
      }
    }
  }
}

# Grant Key Vault access
resource "azurerm_key_vault_access_policy" "app" {
  key_vault_id = var.key_vault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_container_app.app.identity[0].principal_id

  secret_permissions = ["Get", "List"]
}
```

**Manual Setup** (when Terraform can't access managed identity):

```bash
# 1. Get Container App managed identity principal ID
PRINCIPAL_ID=$(az containerapp identity show \
  --name dev-acme-domain-api \
  --resource-group development-acme-rg \
  --query principalId -o tsv)

# 2. Assign Key Vault Secrets User role
az role assignment create \
  --assignee "$PRINCIPAL_ID" \
  --role "Key Vault Secrets User" \
  --scope "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault>"

# 3. Verify access
az containerapp logs show \
  --name dev-acme-domain-api \
  --resource-group development-acme-rg \
  --follow
```

**Creating Secrets in Key Vault**:

```bash
# Set secrets (must exist BEFORE Container App deployment)
az keyvault secret set \
  --vault-name development-acme-kv \
  --name commission-database-url \
  --value "postgresql://user:pass@host:5432/dbname?schema=commission"

az keyvault secret set \
  --vault-name development-acme-kv \
  --name legacy-api-api-key \
  --value "<LEGACY_API_KEY>"

az keyvault secret set \
  --vault-name development-acme-kv \
  --name commission-webhook-secret \
  --value "<WEBHOOK_SECRET>"
```

---

### CORS Configuration for Azure Static Web Apps

**Problem**: Frontend deployed to Azure Static Web Apps can't communicate with domain-api due to CORS errors.

**Symptoms**:

```
Access to fetch at 'https://dev-acme-domain-api.azurecontainerapps.io/api/v1/commissions'
from origin 'https://acme-legacy-web-dev3.azurestaticapps.net' has been blocked by CORS policy
```

**Solution**: Add Azure SWA hostname to CORS allowlist:

```typescript
// src/plugins/cors.plugin.ts
import { cors } from '@elysiajs/cors';
import { Elysia } from 'elysia';

const environmentName = process.env.ENVIRONMENT_NAME || 'development';

const allowedOrigins =
  environmentName === 'production'
    ? ['https://commission.acme-example.co.uk', 'https://app.acme-example.co.uk']
    : [
        // Azure Static Web Apps hostnames
        'https://acme-legacy-web-dev3.azurestaticapps.net', // Development SWA
        'https://acme-legacy-web-prod.azurestaticapps.net', // Another env

        // Localhost for local development
        'http://localhost:4200', // legacy-web
        // ... other instance ports
      ];

export const corsPlugin = (app: Elysia) =>
  app.use(
    cors({
      origin: (origin) => allowedOrigins.includes(origin),
      credentials: true,
    })
  );
```

**Finding Azure SWA Hostname**:

```bash
# Get default hostname from Terraform output
terraform output commission_frontend_url

# Or query Azure
az staticwebapp show \
  --name development-acme-legacy-web \
  --resource-group development-acme-rg \
  --query defaultHostname -o tsv
```

**Verification**:

```bash
# Test CORS from browser console
fetch('https://dev-acme-domain-api.azurecontainerapps.io/health', {
  method: 'GET',
  credentials: 'include',
})
  .then((r) => r.json())
  .then(console.log)
  .catch(console.error);
```

---

### Container App Health Checks

**Problem**: Container App shows "Unhealthy" or fails to start despite image being built correctly.

**Symptoms**:

```
Provisioning state: Failed
Replica status: Unhealthy (0/1 running)
```

**Root Causes**:

1. **Missing health endpoint** - App doesn't respond to `/health`
2. **Port mismatch** - Container listens on different port than configured
3. **Slow startup** - Health check times out before app is ready
4. **Environment variable missing** - App crashes on startup

**Solution - Add Health Endpoints**:

```typescript
// src/routes/health.routes.ts
import { Elysia } from 'elysia';

import { db } from '../database';

export const healthRoutes = (app: Elysia) =>
  app
    // Liveness probe - always returns 200 if process is running
    .get('/health/live', () => ({ status: 'ok' }))

    // Readiness probe - checks dependencies
    .get('/health/ready', async () => {
      try {
        await db.execute('SELECT 1'); // Test database connection
        return { status: 'ready', database: 'connected' };
      } catch (error) {
        throw new Error('Database connection failed');
      }
    })

    // Full health check
    .get('/health', async () => {
      const dbStatus = await db
        .execute('SELECT 1')
        .then(() => 'connected')
        .catch(() => 'disconnected');

      return {
        status: dbStatus === 'connected' ? 'healthy' : 'unhealthy',
        environment: process.env.ENVIRONMENT_NAME,
        timestamp: new Date().toISOString(),
        dependencies: {
          database: dbStatus,
        },
      };
    });
```

**Container App Configuration**:

```hcl
resource "azurerm_container_app" "app" {
  template {
    container {
      liveness_probe {
        path               = "/health/live"
        port               = 3200
        interval_seconds   = 10
        timeout            = 5
        failure_threshold  = 3
      }

      readiness_probe {
        path               = "/health/ready"
        port               = 3200
        interval_seconds   = 10
        timeout            = 5
        failure_threshold  = 3
        initial_delay_seconds = 5 # Wait for DB migrations
      }
    }
  }
}
```

**Debugging**:

```bash
# View Container App logs
az containerapp logs show \
  --name dev-acme-domain-api \
  --resource-group development-acme-rg \
  --follow

# Check revision status
az containerapp revision list \
  --name dev-acme-domain-api \
  --resource-group development-acme-rg \
  --query "[].{name:name,health:healthState,replicas:replicas}" -o table

# Test health endpoint directly
curl https://dev-acme-domain-api.azurecontainerapps.io/health
```
