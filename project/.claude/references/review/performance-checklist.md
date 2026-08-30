# Performance Review Checklist

Acme-specific performance checklist. Use during code review for changes touching database queries, API endpoints, React components, or bundle configuration.

## Database Queries

- [ ] **No N+1 queries** — TypeORM: use `relations` option or `leftJoinAndSelect`; MikroORM: use `populate` option
- [ ] **Indexes on WHERE/JOIN columns** — New columns used in WHERE, JOIN, or ORDER BY have database indexes
- [ ] **Pagination on list endpoints** — No unbounded `SELECT *` queries; use `take`/`skip` or cursor pagination
- [ ] **Connection pool sized correctly** — Default pool size sufficient for concurrent requests; no pool exhaustion under load
- [ ] **Batch operations for bulk data** — Use `INSERT ... VALUES` batching, not individual inserts in a loop
- [ ] **No SELECT \* in production queries** — Select only needed columns for large tables
- [ ] **Query count reasonable** — Endpoint executes < 10 queries; investigate if more

### Measurement

```bash
# Check query count per request (TypeORM logging)
# Set logging: true in ormconfig and grep for "query:" in output
nx run legacy-api:serve  # then watch logs
```

## API Performance

- [ ] **Response size reasonable** — No endpoint returning > 1MB without pagination/streaming
- [ ] **No synchronous heavy computation** — CPU-intensive work offloaded to worker/queue (pg-boss)
- [ ] **Caching for expensive reads** — Frequently-read, rarely-changed data has caching strategy
- [ ] **Compression enabled** — gzip/brotli for API responses in production
- [ ] **No redundant API calls** — Frontend doesn't re-fetch data already in state

## React & Frontend

- [ ] **No unnecessary re-renders** — Components use `React.memo`, `useMemo`, `useCallback` where beneficial
- [ ] **Lists have stable keys** — `key` prop uses stable identifier, not array index
- [ ] **Large lists virtualized** — Lists > 100 items use `react-window` or similar
- [ ] **Images optimized** — Proper dimensions, lazy loading for off-screen images
- [ ] **No layout thrashing** — No DOM reads interleaved with writes in loops

## Bundle Size

- [ ] **Code splitting for routes** — Lazy-loaded routes with `React.lazy()` and `Suspense`
- [ ] **No large library imports** — Use named imports: `import { debounce } from 'lodash'`, not `import _ from 'lodash'`
- [ ] **Tree-shaking works** — ESM imports for tree-shakeable libraries
- [ ] **Bundle delta checked** — New dependency impact on bundle size reviewed

### Measurement

```bash
# Check bundle size
nx run legacy-web:build --stats-json
# Analyze with: npx webpack-bundle-analyzer dist/apps/legacy-web/stats.json
```

## Nx & Build Performance

- [ ] **Affected tests only** — CI runs `nx affected -t test`, not `nx run-many -t test --all`
- [ ] **Cache keys correct** — New build inputs added to `nx.json` `targetDefaults` if needed
- [ ] **No circular dependencies** — `nx graph` shows no cycles between libraries

## Financial Calculations

- [ ] **Big.js for all money math** — Never use native JS floating point for financial calculations
- [ ] **Precision preserved** — No `.toFixed()` or `Math.round()` on intermediate financial values
- [ ] **Batch commission calculations** — Period calculations run in batch, not per-row
