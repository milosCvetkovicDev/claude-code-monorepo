---
name: dev-servers
description: 'Start and manage all local development servers for the Acme monorepo (PostgreSQL, legacy-api, domain-api, legacy-web, domain-web). Use when the user wants to start services, get the local env running, or check service status. Do not use for debugging service failures (use dev-troubleshoot) or checking environment config (use env-status).'
---

# Local Development Servers

Start all required development services in the correct order and verify they are running.

## Critical Rule: Default Ports Only

NEVER start a service on port+1 (e.g., 3001 when 3000 is busy). Always kill the old process on the default port and start the new service on the SAME default port. Environment configs, frontends, and integrations all expect default ports.

## Services

| Service | Port | Command | Health Check |
| -------------------- | ----------------- | -------------------------------------- | --------------------------------------------------------------------------------------- |
| PostgreSQL + Azurite | 5432, 10000-10002 | `docker compose up -d`                 | `PGPASSWORD=postgres psql -h localhost -U legacy -d legacy_development -c "SELECT 1"` |
| legacy-api | 3000              | `npx nx run legacy-api:serve:dev`   | `curl -s http://localhost:3000/api/v1/up` → "legacy ok"                                  |
| domain-api | 3200              | `npx nx run domain-api:serve`      | `curl -s http://localhost:3200/health`                                                  |
| legacy-web | 4200              | `npx nx run legacy-web:serve`       | `curl -s http://localhost:4200`                                                         |
| domain-web | 4400              | `npx nx run domain-web:serve` | `curl -s http://localhost:4400`                                                         |

## Step 1: Pre-Flight Checks

1. Check for port conflicts:

   ```bash
   lsof -i :5432,3000,3200,4200,4400 -sTCP:LISTEN
   ```

   If ports are in use, ask user if they want to kill existing processes.

2. Verify environment files exist:

   ```bash
   test -f apps/legacy-api/.env && grep COMMISSION_API_WEBHOOK_URL apps/legacy-api/.env
   ```

3. Verify Docker daemon is running:
   ```bash
   docker ps >/dev/null 2>&1
   ```

## Step 2: Start Docker Services

```bash
docker compose up -d
```

Wait for PostgreSQL to accept connections (up to 30 seconds):

```bash
for i in {1..30}; do
  PGPASSWORD=postgres psql -h localhost -U legacy -d legacy_development -c "SELECT 1" 2>/dev/null && break
  sleep 1
done
```

## Step 3: Start Backend Services (background)

Start legacy-api first (run in background, track task ID):

```bash
npx nx run legacy-api:serve:dev
```

Wait for health check (up to 60 seconds):

```bash
for i in {1..60}; do
  curl -s http://localhost:3000/api/v1/up | grep -q "legacy ok" && break
  sleep 1
done
```

Then start domain-api (run in background, track task ID):

```bash
npx nx run domain-api:serve
```

Wait for health check (up to 30 seconds):

```bash
for i in {1..30}; do
  curl -s http://localhost:3200/health >/dev/null 2>&1 && break
  sleep 1
done
```

## Step 4: Start Frontend Services (background)

Start both frontends in parallel (run in background, track task IDs):

```bash
npx nx run legacy-web:serve
npx nx run domain-web:serve
```

Frontends take 10-20 seconds to build.

## Step 5: Verify All Services

```bash
lsof -i :5432,3000,3200,4200,4400 -sTCP:LISTEN
curl -s http://localhost:3000/api/v1/up
curl -s http://localhost:3200/health
curl -s http://localhost:4200 | head -10
curl -s http://localhost:4400 | head -10
```

Track all background task IDs and report them to the user.

## Stop All Services

```bash
pkill -f "nx run legacy-api"
pkill -f "nx run domain-api"
pkill -f "nx run legacy-web"
pkill -f "nx run domain-web"
docker compose down
```

## Troubleshooting

See `references/troubleshooting.md` for common issues (port conflicts, Docker not running, database migrations, environment variables).

## Startup Order

Database first → Backends next → Frontends last. Wait for each dependency to be fully ready before starting the next service.

---

## Platform Local Dev Stack

The Platform stack adds RabbitMQ and Redis to the Docker Compose services.

### Docker Compose (Platform)

File: `docker-compose.platform.yml`

| Service | Port | Health Check |
| ----------- | ---------------------------------- | --------------------------------------------------- |
| PostgreSQL  | 5432                               | `pg_isready`                                        |
| Redis | 6379                               | `redis-cli ping`                                    |
| RabbitMQ    | 5672 (AMQP), 15672 (Management UI) | `curl http://localhost:15672/api/healthchecks/node` |
| Pact Broker | 9292                               | `curl http://localhost:9292`                        |

### Start Platform Services

```bash
# Start infrastructure
docker compose -f docker-compose.platform.yml up -d

# Verify all healthy
docker compose -f docker-compose.platform.yml ps

# Check RabbitMQ management UI
open http://localhost:15672  # guest/guest

# Check Redis
redis-cli ping  # PONG
```

### Start NestJS Services (user runs these — never start in Claude shell)

```bash
# Gateway
nx serve gateway

# Auth service
nx serve auth-service

# Or with Tilt (Sprint 2+)
tilt up
```
