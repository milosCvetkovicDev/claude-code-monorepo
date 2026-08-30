---
name: dev-troubleshoot
description: "Debug and verify local development environment for the Acme monorepo. Use when services are not starting, webhooks fail, environment variables seem wrong, database data is missing, or the full stack is not working. Do not use for starting services from scratch (use dev-servers) or checking environment status (use env-status)."
---

# Local Development Troubleshooting

Debug and verify the local development environment.

## Critical Rule: Default Ports Only

NEVER start a service on port+1 (e.g., 3001 when 3000 is busy). Always kill the old process and start on the SAME default port.

## Step 1: Assess the Situation

Ask the user: What specifically is not working?

Common categories:
- Service not starting or crashing
- Webhook integration failing
- Database connectivity or data issues
- Environment variable misconfiguration

## Step 2: Check Service Health

```bash
lsof -i :5432 -sTCP:LISTEN   # PostgreSQL
lsof -i :3000 -sTCP:LISTEN   # legacy-api
lsof -i :3200 -sTCP:LISTEN   # domain-api
lsof -i :4200 -sTCP:LISTEN   # legacy-web
lsof -i :4400 -sTCP:LISTEN   # domain-web

curl -s http://localhost:3000/api/v1/up   # Should return "legacy ok"
curl -s http://localhost:3200/health       # Should return health status
```

## Step 3: Check Environment Configuration

```bash
grep COMMISSION_API_WEBHOOK_URL apps/legacy-api/.env
```

Common mistake: Including the path in COMMISSION_API_WEBHOOK_URL.
- WRONG: `http://localhost:3200/api/internal/deal-locked`
- RIGHT: `http://localhost:3200`

## Step 4: Check Database

```bash
PGPASSWORD=postgres psql -h localhost -U legacy -d legacy_development -c "SELECT 1"
```

See `references/database-queries.md` for the verification queries that confirm a local flow's
preconditions are actually met before you debug the code.

## Step 5: Check Logs

Read background task logs using TaskOutput. Look for:
- Error messages and stack traces
- Webhook activity (`Commission webhook`)
- HTTP status codes (404, 500)

## Step 6: Apply Known Fixes

| Symptom | Cause | Fix |
|---------|-------|-----|
| Webhook 404 | URL includes path | Set COMMISSION_API_WEBHOOK_URL to base URL only |
| `Cannot read properties of undefined` | Unloaded TypeORM relation | Pass data as function parameters |
| Consumer reports 0 records created | The webhook payload was empty — the source relation was never populated | Seed the missing link, then re-trigger |
| Port EADDRINUSE | Orphaned process | Kill process on default port, restart |

## Step 7: Test End-to-End

See `references/webhook-test-flow.md` for the full webhook integration test procedure.

## Success Criteria

- All 5 services running and accessible
- Backend health check returns "legacy ok"
- Database connection working
- Webhook URL configured correctly (base URL only)
- Trigger the producing action → webhook succeeds → records created by the consumer > 0
  (both counts checked, not just the success line)

## Common Root Causes

Most issues trace to one of:
1. Missing environment variables
2. Services not running
3. Missing or incorrect database data
4. Unloaded TypeORM relations

Check these first before investigating deeper.
