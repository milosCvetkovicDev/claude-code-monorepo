# Deployment Gotchas

## Container App — Terraform `ignore_changes` Doesn't Apply on Creation

The domain-api Container App has `ignore_changes = [template, registry, secret]` to prevent Terraform from reverting CI-deployed images. **But this only applies to updates, not creation.**

When Terraform destroys+recreates the Container App Environment (e.g., tier change from Consumption to Workload Profiles), it creates a brand new Container App from scratch using `var.container_image` (`:production` tag). This overwrites whatever image CI last deployed.

**Fix:** Always run Terraform first, wait for completion, then run the app deploy workflow. Never run them concurrently.

## Container App Environment Tier Change Forces Replacement

Changing from Consumption-only to Workload Profiles (or vice versa) forces Azure to **destroy and recreate** the entire Container App Environment + all hosted Container Apps. The new environment gets a new `default_domain` (random subdomain), which changes all Container App FQDNs.

As of PR #117, the domain-api FQDN is resolved dynamically via `module.commission_api.container_app_url`, so FQDN changes are handled automatically in a single Terraform apply.

## INCIDENT 2026-03-03: Commission API 503 After Production Deploy

**Symptoms:** All commission requests returned `{"error": "Commission API is unavailable"}` (503).

**Root cause (two issues):**
1. `COMMISSION_API_URL` pointed to old Container Apps Environment FQDN (`victoriousstone-4f489c3c`) instead of new (`blacktree-e50fb0fd`). The environment was recreated but the app setting drifted from Terraform state.
2. `WEBSITE_VNET_ROUTE_ALL` was missing from the App Service, so DNS queries used Azure default DNS instead of VNet-linked private DNS zone. Even with the correct URL, the private FQDN couldn't resolve.

**Immediate fix:** Updated `COMMISSION_API_URL` and set `WEBSITE_VNET_ROUTE_ALL=1` via `az webapp config appsettings set`, then restarted.

**Permanent fixes (PR #121):**
- Added domain-api connectivity smoke test (Test 5) to staging smoke tests — blocks slot swap if domain-api returns 503 or times out
- Made `COMMISSION_API_URL` a sticky app setting in Terraform — prevents stale URLs surviving slot swaps
- Ran Terraform deploy to sync state (`vnet_route_all_enabled = true` was already in config)

**Prevention (defense in depth — PR #136):**
1. **Deploy-time FQDN sync** — `reusable-build-deploy-app.yml` resolves actual FQDN via `az containerapp show` and updates both slots before every backend deploy. This is the primary defense.
2. **Smoke test** (Test 5) — validates domain-api connectivity on staging before swap. Catches issues the sync step can't fix (e.g., VNet routing, DNS).
3. **Terraform** — `data.azurerm_container_app` resolves FQDN dynamically on every apply. Run after infra changes.
- `TF_VAR_commission_api_url` was removed (dead code — main.tf uses data source, not variable)

## Commission-API Schema Changes — Migration-First Deploy (2026-03-10)

Deploy workflow does NOT run commission DB (Drizzle) migrations. When deploying code that requires new tables/columns:

1. Add IP to KV firewall + PG firewall
2. Apply migration: `psql -f apps/domain-api/drizzle/migrations/<nnnn>.sql` (safer than `drizzle-kit migrate` for targeted changes; the psql fallback script may show all as "WOULD APPLY" due to journal mismatch)
3. Verify table exists: `psql -c "SELECT tablename FROM pg_tables WHERE schemaname='public'"`
4. Deploy domain-api
5. Deploy legacy-api
6. Clean up firewall rules

**Gotcha (multi-revision mode):** The deploy workflow updates the Container App template but does NOT route traffic to the new revision in multi-revision mode. The old revision keeps 100% traffic. To force the fix live:
```bash
az containerapp update --name prod-acme-domain-api --resource-group prod-acme-rg \
  --image ghcr.io/initech-trading-platform/domain-api:sha-<new-sha> \
  --revision-suffix <unique-suffix>
# Wait for healthy, then:
az containerapp ingress traffic set --name prod-acme-domain-api \
  --resource-group prod-acme-rg \
  --revision-weight <new-revision-name>=100
```
The deploy workflow (`reusable-build-deploy-app.yml`) needs updating to handle multi-revision traffic routing.

**Also:** If deploy fails and you re-deploy with same image tag, Azure won't create a new revision (duplicate suffix). Use `az containerapp update --revision-suffix <unique>` instead.

**Rollback:** `az containerapp ingress traffic set --revision-weight <old-healthy-rev>=100`

## `az containerapp update` — Registry Args Are Create-Only

`az containerapp update` does NOT accept `--registry-server`, `--registry-username`, `--registry-password`. These are only valid on `az containerapp create`.

Use `az containerapp registry set` as a separate command to update registry credentials:
```bash
az containerapp registry set --name <app> --resource-group <rg> \
  --server ghcr.io --username <user> --password <token>
```

Fixed in PR #115 — the composite action `container-app-deploy/action.yml` now uses this approach.

## Terraform `-target` Dependency Resolution

- `-target=module.X` includes **upstream** dependencies (resources module.X references)
- Does NOT include **downstream** dependents (resources that reference module.X)
- Example: targeting `module.commission_api` plans `module.network` subnet (upstream) but NOT `module.key_vault` (downstream, must be explicitly targeted)

## Production Terraform Deploy Targets

As of PR #117, production targets are:
```
module.network, module.key_vault, module.legacy_backend,
module.commission_api, azurerm_postgresql_flexible_server_database.commission,
module.postgres firewall rule
```
