# Deploy to Azure Environment

Production-grade deployment runbook for Acme Azure Container Apps and App Services.
Covers development and prod-acme-legacy environments with FQDN verification, health checks, and rollback awareness.

## Arguments

- `$ARGUMENTS` — environment (`development` or `prod-acme-legacy`), optionally a specific app (`legacy-api`, `legacy-web`, `domain-api`)

If no arguments provided, ask the user which environment and app to deploy.

---

## Step 1: Verify Branch and Git State

```bash
git branch --show-current
git status --short
git log --oneline -3
```

**Rules:**

- Production deploys (`prod-acme-legacy`) MUST be from `main`. If not on `main`, STOP and confirm with user.
- Development deploys allow feature branches but warn the user.
- If there are uncommitted changes, warn — deployments should be from committed code.
- Check the latest commit matches what the user expects to deploy.

---

## Step 2: Run Tests

```bash
# Typecheck
npx nx affected -t typecheck --base=HEAD~1

# Run affected tests
npx nx affected -t test --base=HEAD~1
```

**Rules:**

- If typecheck fails, STOP. Do not deploy with type errors.
- If tests fail, STOP and report failures. Ask user whether to proceed (development only — never skip for production).

---

## Step 3: Check CI Status and Terraform

### CI Status

```bash
gh run list --branch main --workflow ci.yml --limit 3 --json status,conclusion,displayTitle,createdAt
```

If latest CI is not `success`, warn the user. Production deploys should not proceed with failing CI.

### Terraform Operations

```bash
# Check for in-progress Terraform workflow runs
gh run list --workflow "Terraform Deploy" --status in_progress --json databaseId,displayTitle,status
```

**CRITICAL:** If Terraform is currently running or was run recently against the same environment:

- STOP the deployment. Terraform can recreate Container App Environments, which:
  - Generates a new random FQDN subdomain (breaks `COMMISSION_API_URL`)
  - Reverts Container App images to the `:production` tag (loses latest deploy)
- Always run Terraform BEFORE app deploys, never concurrently.
- If Terraform just completed, proceed to Step 4 but pay extra attention to FQDN verification in Step 6.

### Check for Infrastructure Changes

```bash
git diff HEAD~5 --name-only | grep -q "^infra/" && echo "⚠️ Infrastructure changes detected — consider running Terraform first"
```

---

## Step 4: Trigger Deployment

### Determine Apps to Deploy

```bash
npx nx show projects --affected --base=HEAD~5 --type=app 2>/dev/null
```

Report which apps are affected. If user specified an app, deploy only that one.

### Trigger

```bash
# Development (auto-triggered on main merge, but can be manual)
gh workflow run deploy.yml --ref main -f environment=development -f app=<app>

# Production (MUST be manual — workflow_run triggers skip production)
gh workflow run deploy.yml --ref main -f environment=prod-acme-legacy -f app=<app>
```

**App names:** `legacy-api`, `legacy-web`, `domain-api`

### Monitor

```bash
# Get the run ID (wait a few seconds for it to appear)
gh run list --workflow deploy.yml --limit 1 --json databaseId,status,conclusion

# Watch progress
gh run view <run-id> --json status,conclusion,jobs
```

Poll every 30 seconds until complete. If it fails, fetch logs:

```bash
gh run view <run-id> --log-failed | tail -100
```

---

## Step 5: Verify FQDN Consistency (domain-api deploys)

**Skip this step if deploying only `legacy-web`.**

After deploy completes, verify the domain-api FQDN hasn't changed:

```bash
# Get current actual FQDN from Azure
az containerapp show \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --query "properties.configuration.ingress.fqdn" -o tsv
```

**Resource names by environment:**

| Environment | Container App Name | Resource Group |
| -------------------- | ----------------------------- | ----------------------- |
| `development`        | `dev-acme-domain-api`   | `development-acme-rg` |
| `prod-acme-legacy` | `prod-acme-domain-api` | `prod-acme-rg` |

**Then verify the App Service env vars match:**

```bash
# Check COMMISSION_API_URL on the legacy-api App Service
az webapp config appsettings list \
  --name <app-service-name> \
  --resource-group <resource-group> \
  --query "[?name=='COMMISSION_API_URL'].value" -o tsv

# Check COMMISSION_API_WEBHOOK_URL too — BOTH must match
az webapp config appsettings list \
  --name <app-service-name> \
  --resource-group <resource-group> \
  --query "[?name=='COMMISSION_API_WEBHOOK_URL'].value" -o tsv
```

**App Service names:**

| Environment | App Service Name |
| -------------------- | ------------------------------------------ |
| `development`        | `development-acme-legacy-api-web-app` |
| `prod-acme-legacy` | `prod-acme-legacy-api-web-app` |

**If FQDNs don't match:** The deploy workflow should have synced them, but if not:

```bash
az webapp config appsettings set \
  --name <app-service-name> \
  --resource-group <resource-group> \
  --settings COMMISSION_API_URL=https://<actual-fqdn> COMMISSION_API_WEBHOOK_URL=https://<actual-fqdn>
```

⚠️ For production, also update the staging slot:

```bash
az webapp config appsettings set \
  --name <app-service-name> \
  --resource-group <resource-group> \
  --slot staging \
  --settings COMMISSION_API_URL=https://<actual-fqdn> COMMISSION_API_WEBHOOK_URL=https://<actual-fqdn>
```

---

## Step 6: Health Checks

### legacy-api

```bash
# Development
curl -sf --max-time 30 "https://development-acme-legacy-api-web-app.azurewebsites.net/api/v1/up/ready"

# Production (via Front Door)
curl -sf --max-time 30 "https://api.acme-example.co.uk/api/v1/up/ready"
```

Expected response: `{"status":"ready"}` with database healthy.

### domain-api

Commission-api has no public FQDN (VNet-internal only). Verify via Azure CLI:

```bash
az containerapp revision list \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --query "[?properties.active].{name:name, running:properties.runningState, created:properties.createdTime}" -o table
```

Active revisions should show `Running` state.

### legacy-web

```bash
# Development
curl -sf --max-time 15 -o /dev/null -w "%{http_code}" "https://development-acme-legacy-web.azurestaticapps.net"

# Production
curl -sf --max-time 15 -o /dev/null -w "%{http_code}" "https://app.acme-example.co.uk"
```

Expected: HTTP 200.

---

## Step 7: Post-Deploy Report

Summarize to the user:

```
✅ Deploy complete: <app> → <environment>
  - Branch: <branch> (<commit-sha>)
  - CI: passed
  - Tests: passed
  - FQDN: verified (or N/A)
  - Health: <status>
  - Duration: ~<time>
```

If any step had warnings, list them.

---

## Rollback (if health checks fail)

### legacy-api (slot swap rollback)

```bash
# Instant rollback via slot swap back
gh workflow run rollback.yml -f environment=prod-acme-legacy -f app=legacy-api -f confirm=ROLLBACK

# Or manually:
az webapp deployment slot swap \
  --name prod-acme-legacy-api-web-app \
  --resource-group prod-acme-rg \
  --slot staging --target-slot production
```

### domain-api (traffic routing rollback)

```bash
# List revisions to find the previous healthy one
az containerapp revision list \
  --name prod-acme-domain-api \
  --resource-group prod-acme-rg \
  --query "[].{name:name, active:properties.active, traffic:properties.trafficWeight}" -o table

# Route 100% traffic to previous revision
az containerapp ingress traffic set \
  --name prod-acme-domain-api \
  --resource-group prod-acme-rg \
  --revision-weight <healthy-revision-name>=100
```

---

## Critical Rules

- **Never deploy while Terraform is running** — it can recreate resources and break FQDNs
- **Never replace Container App env vars** — always use incremental updates
- **Production deploys require `main` branch** — the workflow enforces `github.ref == refs/heads/main`
- **Both `COMMISSION_API_URL` and `COMMISSION_API_WEBHOOK_URL` must match** — missing one causes silent failures (see incident 2026-03-06)
- **Commission-api schema changes need manual migration BEFORE deploy** — the workflow does NOT run Drizzle migrations
- **`ERP_POSTING_ENABLED` is slot-sticky** — `false` on staging, `true` on production. Never change this.
- If post-swap health fails, the deploy workflow auto-retries up to 3 swaps before giving up — check logs before manual intervention

---

## Platform Deployment (ArgoCD + Helm + AKS)

**Detection:** If deploying a service under `apps/platform/`, use this path instead of Azure App Service.

### Build & Push

CI builds Docker image on push, tags with `sha-{commit}`, pushes to GHCR.

### Deploy (GitOps)

1. CI updates image tag in `charts/values/{service}.yaml`
2. ArgoCD detects change, triggers sync automatically
3. Rolling update with zero-downtime (ADR-0015)

### Monitor

```bash
argocd app get platform-{service}
kubectl rollout status deployment/{service} -n platform-{bc} --timeout=300s
kubectl get pods -n platform-{bc} -l app={service}
```

### Rollback

```bash
argocd app rollback platform-{service} {revision}
```

### Health Verify

Only the **gateway + frontend** are exposed publicly via Traefik at `dev.platform.acme-example.co.uk`
(there is no per-service public host — backend BC services are internal):

```bash
# Public edge (Traefik):
curl -s https://dev.platform.acme-example.co.uk/healthz                                          # frontend (nginx)
curl -s -o /dev/null -w '%{http_code}\n' https://dev.platform.acme-example.co.uk/api/v1/health   # gateway

# Internal BC services — verify via port-forward (not publicly routable):
kubectl -n platform-{bc} port-forward deploy/platform-{service} 8080:3000
curl -s http://localhost:8080/health/ready
```
