# Dev Servers Troubleshooting

## Docker Not Running

**Symptom:** `Cannot connect to the Docker daemon`

**Fix:** Start Docker Desktop or `sudo systemctl start docker` (Linux).

## Port Already in Use

**Symptom:** `Error: listen EADDRINUSE: address already in use :::3000`

**Fix:** NEVER start on a different port. Kill the old process, then start on the default port.

```bash
lsof -i :<port> -sTCP:LISTEN
kill -9 <PID>
```

Or kill all Nx processes: `pkill -f "nx run"`

## Database Not Ready

**Symptom:** Backend fails with connection errors.

**Fix:**
```bash
docker ps | grep postgres
docker compose up -d
sleep 10
PGPASSWORD=postgres psql -h localhost -U legacy -d legacy_development -c "SELECT 1"
```

## Database Migration Needed

**Symptom:** Backend logs show migration errors.

**Fix:** `npm run db:migrate` or full reset: `npm run db:recreate`

## Environment Variables Missing

**Symptom:** Backend starts but webhook fails.

**Fix:** Verify `apps/legacy-api/.env` contains:

```
COMMISSION_API_WEBHOOK_URL=http://localhost:3200
COMMISSION_API_WEBHOOK_SECRET=<shared-secret>
```

CRITICAL: `COMMISSION_API_WEBHOOK_URL` must be base URL only (no `/api/internal/deal-locked` path).

## Frontend Compilation Errors

**Symptom:** Frontend fails to compile.

**Fix:**
```bash
rm -rf node_modules/.cache
npm run frontend:build
```

## Service Starts But Crashes

Common causes:
- TypeScript compilation errors
- Missing dependencies → run `npm install`
- Database migration needed → run `npm run db:migrate`
