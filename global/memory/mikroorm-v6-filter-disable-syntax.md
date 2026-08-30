---
name: MikroORM v6 filter-disable syntax — `filters: { tenant: false }`, not `disableFilters`
description: To disable a `@Filter({ default: true })` (e.g. the Platform `tenant` filter) for a single query in MikroORM v6, pass `{ filters: { tenant: false } }` in the find/findOne options. There is no `disableFilters: ['tenant']` array form — that's a stale v5/Sequelize-style API that silently fails to disable and the query then dies with `No arguments provided for filter 'tenant'`.
type: reference
originSessionId: 00000000-0000-0000-0000-000000000038
---
For a single MikroORM v6 query that needs to bypass the default tenant filter (declared on `TenantBaseEntity` with `@Filter({ name: 'tenant', cond: ..., default: true })`):

```typescript
// ✅ Correct (MikroORM v6)
await em.find(AuditEntry, { _userId: userId } as never, {
  filters: { tenant: false },
});

// ❌ Wrong — does NOT disable the filter
await em.find(AuditEntry, { _userId: userId } as never, {
  disableFilters: ['tenant'],
});
```

The wrong form looks like it works (no TypeScript error in some configs), but the filter still fires and the query throws `Error: No arguments provided for filter 'tenant'`.

**Other forms:**

```typescript
// Disable ALL named filters on a query
{ filters: false }

// Provide arguments (don't disable, just satisfy)
{ filters: { tenant: { tenantId: 'tenant-1' } } }

// Disable on the EntityManager init (per-test-harness)
MikroORM.init({
  ...,
  filters: { tenant: { default: false } },  // off by default; opt-in per query
})
```

**Where this matters in Platform:**
- `libs/platform/mikro-orm/src/lib/tenant-base-entity.ts` declares the `tenant` filter with `default: true`.
- `libs/platform/mikro-orm/src/lib/tenant-entity-manager.ts` wraps `em.find`/`em.findOne` to inject `filters: filterOptions` — same shape.
- Integration test harnesses (e.g., audit-service `audit-entry-no-user-email.spec.ts`) that exercise persistence + reads without tenant scoping should disable globally on `MikroORM.init` rather than per-query (less noise).

**Recurring spec-authoring trap:**
Any spec author coming from v5 or a Sequelize background will reach for `disableFilters: [...]`. The compile passes (the v6 type signature allows arbitrary extra options without erroring in many configs); only the runtime fails. If you see `No arguments provided for filter 'tenant'` from a test that "should be" disabling the filter, this is the cause.

**Reference:** [MikroORM v6 filters docs](https://mikro-orm.io/docs/filters).
