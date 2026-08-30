---
name: platform-docker-compose-gotchas
description: Docker Compose gotchas for Platform local development — RabbitMQ, ports, Dockerfile patterns
type: reference
---

## RabbitMQ definitions.json
- MUST include `"vhosts": [{"name": "/"}]` or RabbitMQ 3 crashes with "Please create virtual host"
- Do NOT put user credentials in definitions (password must be base64-encoded hash, not plaintext)
- Use `RABBITMQ_DEFAULT_USER`/`RABBITMQ_DEFAULT_PASS` env vars for user creation instead

## Docker Internal vs Host Ports
- Inside Docker network: `db:5432`, `redis:6379`, `rabbitmq:5672`
- Host-mapped (offset for legacy conflict avoidance): `5433`, `6380`, `5673`
- Services in docker-compose MUST use internal ports (e.g., `DATABASE_URL=postgresql://...@db:5432/...`)

## Shared Dockerfile Template
- Single `apps/platform/Dockerfile` with build args: `SERVICE_NAME`, `SERVICE_DIR`, `PORT`
- All 4 services use same template — no duplication
- `npm cache clean --force` fails in Docker with ENOTEMPTY — use `|| true`

## Service Dependency Order
```
db, redis, rabbitmq → auth-service, tenant-service → user-service → gateway
```
- user-service depends on auth + tenant (inter-service HTTP)
- gateway depends on all 3 downstream services
- All use `depends_on: condition: service_healthy`

## NODE_ENV
- tenant-service and user-service have production stub guards — they CRASH if `NODE_ENV=production` with in-memory stubs wired
- Always set `NODE_ENV=development` in docker-compose for M1
