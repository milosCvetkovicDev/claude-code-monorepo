# Docker Patterns — Acme

VERIFIED patterns from the acme repository. Use ONLY these patterns when writing Dockerfiles or docker-compose configs.

## Base Images (Verified)

```dockerfile
# Platform NestJS services — production
FROM node:22-slim AS deps          # Stage 1: install deps
FROM node:22 AS build              # Stage 2: build with Nx/SWC
FROM gcr.io/distroless/nodejs22-debian12:nonroot AS production  # Stage 3: runtime

# Bun services (domain-api, helix-agent, nx-cache-server)
FROM oven/bun:1.1.45-alpine AS deps
FROM oven/bun:1.1.45-alpine AS build
FROM oven/bun:1.1.45-alpine AS production
```

**NEVER use `node:22` for production stage** — always use distroless or slim.
**NEVER use `latest` tags** — always pin versions.

## Multi-Stage Build Pattern (Platform)

The Platform services use a SHARED Dockerfile at `apps/platform/Dockerfile` with build args:

```dockerfile
ARG SERVICE_DIR=gateway
ARG NX_PROJECT=platform-gateway

# Stage 1: deps — production deps only + node-prune
FROM node:22-slim AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts \
    && # ... prune node_modules bloat ... \
    && apt-get update && apt-get install -y --no-install-recommends dumb-init

# Stage 2: build — full install + Nx compilation
FROM node:22 AS build
ARG SERVICE_DIR
ARG NX_PROJECT
WORKDIR /app
COPY package.json package-lock.json nx.json tsconfig.base.json ./
COPY .eslintrc.base.json .eslintrc.security.json .prettierrc .prettierignore ./
COPY apps/platform/ apps/platform/
COPY libs/ libs/
RUN npm ci --ignore-scripts && npx nx run ${NX_PROJECT}:build

# Stage 3: production — distroless
FROM gcr.io/distroless/nodejs22-debian12:nonroot AS production
WORKDIR /app
COPY --from=deps /usr/bin/dumb-init /usr/bin/dumb-init
COPY --from=deps /app/node_modules ./node_modules
COPY --from=build /app/dist/apps/platform/${SERVICE_DIR} ./dist/apps/platform/${SERVICE_DIR}
# Path alias resolution: copy libs to node_modules/@acme/
COPY --from=build /app/dist/libs/platform/ ./node_modules/@acme/
```

### Key Details
- **dumb-init**: PID 1 signal handling (distroless has no init system)
- **Path aliases**: `@acme/*` resolved by copying `dist/libs/platform/` to `node_modules/@acme/`
- **node-prune**: Inline find/xargs to remove docs, tests, source maps from node_modules
- **Security**: distroless runs as uid 65534 (nonroot), readOnlyRootFilesystem in K8s

## Health Check Patterns

```dockerfile
# Platform (distroless — no wget/curl, use node --eval)
# Node binary in distroless is at /nodejs/bin/node
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=5 \
  CMD ["/nodejs/bin/node", "--eval", \
    "const h=require('http');h.get('http://localhost:'+(process.env.PORT||3000)+'/health/live',r=>{process.exit(r.statusCode===200?0:1)}).on('error',()=>process.exit(1))"]

# Bun services (alpine — wget available)
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget -qO- http://localhost:3000/health/live || exit 1
```

## Entrypoint Patterns

```dockerfile
# Platform: dumb-init + dynamic service entry
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
ARG SERVICE_DIR=gateway
ENV SERVICE_ENTRY="dist/apps/platform/${SERVICE_DIR}/src/main.js"
CMD ["/nodejs/bin/node", "--eval", \
  "const e = process.env.SERVICE_ENTRY; if (!e) { console.error('FATAL: SERVICE_ENTRY env var is not set'); process.exit(1); } require('./' + e)"]

# Bun: direct execution
ENTRYPOINT ["bun", "run", "dist/index.js"]
```

## Docker Build Command

```bash
# Platform service build (from repo root — Nx needs nx.json, libs/)
docker build -f apps/platform/Dockerfile \
  --build-arg SERVICE_DIR=gateway \
  --build-arg NX_PROJECT=platform-gateway \
  -t platform-gateway .

# Commission-api (uses package.docker.json)
docker build -f apps/domain-api/Dockerfile \
  -t domain-api .
```

## Docker Compose (Platform Infrastructure)

File: `docker-compose.platform.yml`

```yaml
services:
  postgres:
    image: postgres:16
    ports: ['5433:5432']  # Offset to avoid conflicts with legacy
    # Per-BC schema isolation (ADR-0013)

  redis:
    image: redis:7
    ports: ['6380:6379']  # Offset
    command: redis-server --requirepass ${REDIS_PASSWORD}

  rabbitmq:
    image: rabbitmq:3-management
    ports:
      - '5673:5672'   # AMQP (offset)
      - '15673:15672' # Management UI (offset)
```

**Port offsets**: Platform services use different ports than legacy to avoid conflicts.

## Image Tagging

```
# ACR images (Platform)
developmentacmeacr.azurecr.io/{service}:sha-{commit_sha_7}

# GHCR images (legacy)
ghcr.io/initech-trading-platform/acme/{app}:sha-{commit_sha_7}
```

**CRITICAL: NEVER commit image tags to the main branch.** ArgoCD Image Updater manages tag tracking.

## Security Checklist

- [ ] Non-root user (uid 65534 for distroless, uid 1001 for alpine)
- [ ] Multi-stage build (no build tools in production)
- [ ] No secrets in build args or ENV (use K8s secrets/ESO)
- [ ] `npm ci --omit=dev` for production deps (no devDependencies)
- [ ] Trivy scan in CI (optional skip for speed)
- [ ] `.dockerignore` excludes node_modules, .git, docs, tests

## Common Mistakes to Avoid

1. **NEVER use `npm install` in Dockerfile** — use `npm ci` (deterministic, respects lockfile)
2. **NEVER copy `node_modules` into the build** — always install fresh from lockfile
3. **NEVER use `node:22` (full) for production** — use distroless or slim
4. **NEVER hardcode ports** — use `process.env.PORT || 3000`
5. **NEVER use `EXPOSE` as security** — it's documentation only, not enforcement
6. **NEVER put secrets in build args** — they're visible in image history
7. **Build context must be repo root** for Platform (Nx needs nx.json, tsconfig.base.json, libs/)
8. **domain-api uses `package.docker.json`** — not the workspace package.json
