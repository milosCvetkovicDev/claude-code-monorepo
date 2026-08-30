# CLAUDE.md - Nx Cache Server (Bun + Elysia)

High-performance Nx remote cache server built on Bun runtime with Elysia framework.

## Quick Reference

```bash
# Development
bun run --watch apps/nx-cache-server-bun/src/index.ts

# Build
bun build apps/nx-cache-server-bun/src/index.ts --outdir dist/apps/nx-cache-server-bun --target bun --minify

# Test
bun test apps/nx-cache-server-bun/test

# Docker
docker build -f apps/nx-cache-server-bun/Dockerfile -t nx-cache-server-bun:latest .
docker run -p 3000:3000 --env-file apps/nx-cache-server-bun/.env nx-cache-server-bun:latest
```

## Architecture

```
src/
├── index.ts              # Entry point - bootstrap Elysia app
├── config/
│   └── env.ts            # Environment config (fail-fast validation)
├── domain/
│   ├── types.ts          # CacheStats, HealthStatus interfaces
│   ├── cache-hash.ts     # CacheHash value object (validated 16-64 hex)
│   └── errors.ts         # Domain errors (InvalidHashError, etc.)
├── services/
│   ├── auth.service.ts   # Dual-token auth with timing-safe comparison
│   ├── cache.service.ts  # LRU in-memory cache
│   ├── storage.service.ts # Azure Blob Storage adapter
│   └── health.service.ts # Health check aggregation
├── plugins/
│   ├── error-handler.plugin.ts # Domain error to HTTP mapping (with metrics)
│   ├── logger.plugin.ts  # JSON logging with correlation IDs (with metrics)
│   └── rate-limit.plugin.ts # Rate limiting (1000 req/min)
└── routes/
    ├── health.routes.ts  # /health, /health/live, /health/ready
    └── cache.routes.ts   # GET/PUT /v1/cache/:hash
```

## Key Design Decisions

### 1. No DI Container

Services are instantiated at startup and passed via constructor:

```typescript
const authService = new AuthService(config);
const cacheService = new CacheService(config);
app.use(createCacheRoutes(storageService, cacheService, authService));
```

### 2. Elysia Plugin Composition

Plugins chain using `.use()`:

```typescript
app
  .use(errorHandlerPlugin) // Error handling first
  .use(loggerPlugin) // Logging with correlation IDs
  .use(rateLimitPlugin) // Rate limiting
  .use(routes); // Routes last
```

### 3. Route-Specific Auth Guards

Auth guards are applied to route groups, not globally:

```typescript
.use(readAuthGuard)    // Applied to all subsequent routes in this group
.get('/:hash', ...)    // Requires read token
.use(writeAuthGuard)   // Switch to write guard
.put('/:hash', ...)    // Requires write token
```

## Security Features

| Feature | Implementation |
| ---------------------- | ------------------------------------------------ |
| Dual-token auth | Read token: GET only; Write token: GET + PUT     |
| Timing-safe comparison | `crypto.timingSafeEqual` with fixed-size buffers |
| Hash validation | 16-64 hex characters only |
| Immutable cache | 409 Conflict on duplicate PUT                    |
| Size limits | 100MB max artifact |
| Rate limiting | 1000 req/min per IP                              |

## API Endpoints

| Endpoint | Auth | Description |
| --------------------- | ----- | ----------------------------------------- |
| `GET /health`         | None | Full health status with cache stats |
| `GET /health/live`    | None | Liveness probe (always 200)               |
| `GET /health/ready`   | None | Readiness probe (checks storage)          |
| `GET /v1/cache/:hash` | Read | Download artifact (X-Cache: HIT/MISS)     |
| `PUT /v1/cache/:hash` | Write | Upload artifact (201 Created, 409 Exists) |

## Environment Variables

| Variable | Required | Default | Description |
| --------------------------------- | -------- | ----------- | -------------------------- |
| `PORT`                            | No | 3000        | Server port |
| `STORAGE_ACCOUNT_NAME`            | Yes | -           | Azure Storage account name |
| `CONTAINER_NAME`                  | Yes | -           | Blob container name |
| `AZURE_STORAGE_CONNECTION_STRING` | No\*     | -           | For local dev (Azurite)    |
| `CACHE_READ_TOKEN`                | Yes | -           | Read-only auth token |
| `CACHE_WRITE_TOKEN`               | Yes | -           | Read-write auth token |
| `CACHE_MAX_ENTRIES`               | No | 100         | Max LRU cache entries |
| `CACHE_MAX_ITEM_SIZE`             | No | 10MB        | Max size per cached item |
| `CACHE_MAX_TOTAL_SIZE`            | No | 500MB       | Max total cache size |
| `ENVIRONMENT_NAME`                | No | development | For logging |

\*Either `AZURE_STORAGE_CONNECTION_STRING` (local) or Managed Identity (Azure) required.

## Testing

```bash
# Run all tests
bun test apps/nx-cache-server-bun/test

# Run unit tests only
bun test apps/nx-cache-server-bun/test/unit

# Run integration tests only
bun test apps/nx-cache-server-bun/test/integration

# Run with coverage
bun test apps/nx-cache-server-bun/test --coverage
```

## Performance vs NestJS

| Metric | NestJS     | Bun + Elysia |
| ------------ | ---------- | ------------ |
| Files | ~30        | ~15          |
| Startup | ~500ms | ~50ms |
| Memory | ~80MB      | ~30MB        |
| Throughput | ~50K req/s | ~200K+ req/s |
| Docker image | ~200MB     | ~80MB        |
