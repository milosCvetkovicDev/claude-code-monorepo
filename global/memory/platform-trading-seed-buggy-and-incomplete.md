---
name: platform-trading-seed-buggy-and-incomplete
description: trading-service reference-data seed was buggy (non-UUID default tenant crashes boot) AND incomplete (never seeded currencies/units); fixed
metadata:
  node_type: memory
  type: project
  originSessionId: 00000000-0000-0000-0000-000000000017
---

Turning on `SEED_ON_BOOTSTRAP=true` for trading-service on dev (PR #1706) **crash-looped the pod** (Argo Rollout `Degraded`, stable scaled to 0 → auth trading down). Two independent defects in `apps/platform/trading-service/src/seed/seed.service.ts`:

1. **Crash on non-UUID tenant.** `onApplicationBootstrap` seeded `process.env.SEED_TENANT_ID ?? 'default-tenant'`. Trading `tenant_id` columns are **uuid**, so the literal `default-tenant` → Postgres `invalid input syntax for type uuid` → **fatal boot crash**. (`SeedService.seedCountries` findOne.)
2. **Incomplete.** `run()` only seeded countries + VAT. `CURRENCY_SEEDS`/`UNIT_SEEDS` were referenced in a **log line only** — currency/unit tables were NEVER inserted. A seeder that only logs its data set silently seeds nothing — every downstream flow that resolves those lookups found an empty table. There is NO other currency/unit seeder anywhere.

**Fix (#1711, branch `fix/platform-trading-seed-reference-data`):** fail SAFE (seed only when `SEED_TENANT_ID` matches a UUID regex, else warn+skip — never fatal) + added idempotent `seedCurrencies()`+`seedUnits()` mirroring `seedCountries` (findOne by `_code`+`tenantId` → persist missing → flush). RED→GREEN, 601 unit green.

**DONE (2026-07-18, dev):** #1709 (revert) → #1711 (code fix, image `sha-a81c7e4`) → #1714 (deploy: trading tag `sha-a81c7e4` + `SEED_ON_BOOTSTRAP=true` + a UUID `SEED_TENANT_ID`) all MERGED. Seeded pod booted healthy, and the boot log now accounts for **every** reference table the seeder claims to fill — a scripted end-to-end smoke then proved the seeded rows were reachable through the API rather than trusting the log. Tenant uuid verified via `/api/v1/users/me`. Enable pattern for other tenants: same 3 env in `charts/bundles/trading-bundle/values.yaml`; keep flag OFF the old buggy image; prod overlays stay `NODE_ENV=production` → gate closed.

**Live-fire lessons:** the empty dev deals page is ALSO a **frontend placeholder** — `/trading/deals`→`<TradingPlaceholderPage>` (deal-list screen unbuilt); backend data won't render there. `kubectl argo rollouts abort` restored the stable pod fast; ArgoCD selfHeal reverts out-of-band `kubectl patch rollout` env, so seed enablement MUST go through git. See [[platform-trading-hardening-epic]], [[platform-fail-closed-tenant-filter-forked-em]] (seed forks EM + `setFilterParams('tenant',{tenantId})`).
