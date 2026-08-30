---
name: production-access
description: "Access Azure Key Vault secrets, production PostgreSQL database, and Application Insights error logs for Acme production environments. Use when the user needs production credentials, wants to query production data, or investigate production errors. Do not use for local development issues (use dev-troubleshoot) or infrastructure changes (use infra-change)."
---

# Production Access

Access production resources securely: Key Vault secrets, PostgreSQL database, and Application Insights logs.

## Security Rules

- Default to **read-only** database access unless performing approved maintenance.
- **Never commit secrets** — use Key Vault references only.
- **Clear credentials** from environment after use (`unset` variables).

## Step 1: Verify Azure Authentication

```bash
az account show
```

If not authenticated or wrong subscription:
```bash
az login
az account set --subscription "Initech Ltd - Prod-Acme-Legacy"
```

## Step 2: Access Key Vault Secrets

List secrets:
```bash
az keyvault secret list \
  --vault-name kv-acme-prod-sp-uks-001 \
  --query "[].{Name:name, Enabled:attributes.enabled}" \
  -o table
```

Get a specific secret:
```bash
az keyvault secret show \
  --vault-name kv-acme-prod-sp-uks-001 \
  --name "<secret-name>" \
  --query "value" \
  -o tsv
```

See `references/azure-resources.md` for Key Vault names per environment and common secret names.

## Step 3: Connect to Production Database

Retrieve credentials from Key Vault and connect:
```bash
DB_HOST=$(az keyvault secret show --vault-name kv-acme-prod-sp-uks-001 --name "db-host" --query "value" -o tsv)
DB_PORT=$(az keyvault secret show --vault-name kv-acme-prod-sp-uks-001 --name "db-port" --query "value" -o tsv)
DB_NAME=$(az keyvault secret show --vault-name kv-acme-prod-sp-uks-001 --name "db-name" --query "value" -o tsv)
DB_USERNAME=$(az keyvault secret show --vault-name kv-acme-prod-sp-uks-001 --name "db-username" --query "value" -o tsv)
DB_PASSWORD=$(az keyvault secret show --vault-name kv-acme-prod-sp-uks-001 --name "db-password" --query "value" -o tsv)

PGPASSWORD="$DB_PASSWORD" psql \
  -h "$DB_HOST" \
  -p "$DB_PORT" \
  -U "$DB_USERNAME" \
  -d "$DB_NAME" \
  --set=sslmode=require
```

Always use read-only transactions:
```sql
BEGIN TRANSACTION READ ONLY;
-- queries here
ROLLBACK;
```

## Step 4: Query Error Logs

Prefer acme-mcp tools when available:
```
mcp__acme-mcp__azure_errors({
  environment: 'prod-acme-legacy',
  timeRangeMinutes: 60,
  severity: ['Error', 'Critical'],
  limit: 50
})
```

For Azure CLI fallback or KQL queries, see `references/app-insights-queries.md`.

## Step 5: Clean Up

```bash
unset DB_PASSWORD DB_HOST DB_PORT DB_NAME DB_USERNAME
```

## Common Operations

| Operation | Tool |
|-----------|------|
| Check ERP OAuth tokens | `mcp__acme-mcp__erp_token_status` |
| Check database health | `mcp__acme-mcp__db_status` |
| Check deployment status | `mcp__acme-mcp__azure_deployment_status` |

## Troubleshooting

See `references/access-troubleshooting.md` for Azure login issues, Key Vault access denied, database connection refused, and Application Insights access denied.
