# Terraform Patterns & Gotchas

## Container App State Drift (CRITICAL)
- `terraform apply` **replaces entire template block** — manually-set env vars silently removed
- Different from App Service where `app_settings` merge
- **Rule: After manually setting ANY env var on a Container App, immediately add to Terraform**

## Sensitive Variables in `for_each` (CRITICAL)
- `for_each` CANNOT use sensitive values — even if derived from sensitive var (taints the whole expression)
- Error message is misleading: "Cannot use a X value in for_each"
- **Fix**: Non-sensitive values in `for_each`, sensitive values only inside `content` block
- Ternary branches must have compatible types: `condition ? ["x"] : []` (not `toset` vs `[]`)

## Circular Dependencies
- When module A needs B's URL and B needs A's URL: use environment-level variable to break cycle
- Example: `commission_api_url` variable set post-deploy via `az webapp config`

## Key Vault Patterns
### Container App Secrets
```hcl
env { name = "VAR"; secret_name = "secret-ref" }
secret { name = "secret-ref"; key_vault_secret_id = "https://vault.vault.azure.net/secrets/name"; identity = "System" }
```

### App Service (Key Vault Reference)
```
@Microsoft.KeyVault(VaultName=<name>;SecretName=<secret>)
```

### Conditional Webhook Secret
```hcl
"WEBHOOK_SECRET" = var.use_key_vault && var.webhook_url != "" ? "@Microsoft.KeyVault(...)" : ""
```

## Dev Instance Pattern
- `use_key_vault = false` for dev instances (direct values)
- `use_key_vault = true` for production (Key Vault refs via managed identity)
- `allow_azure_services = true` on postgres for Container App DB access

## Password Drift
- `random_password` in state can drift from actual PG password
- Quick fix: `az postgres flexible-server update --admin-password "<value>"`

## Version Issues
- TF 1.6.0 crashes with sensitive values in conditionals -> use 1.7.5+
- State lock stuck after crash -> `az storage blob lease break -b <blob> -c tfstate --account-name <sa>`
- Azure Container Apps `failure_count_threshold` max is 10

## Required Key Vault Secrets (development-acme-kv)
| Secret | Used By | Purpose |
|--------|---------|---------|
| `commission-database-url` | domain-api | PostgreSQL connection |
| `legacy-api-api-key` | domain-api | API auth |
| `commission-webhook-secret` | both | Webhook HMAC |
| `commission-azure-client-secret` | domain-api | Entra ID OAuth |
| `commission-session-secret` | domain-api | Session (32+ chars) |
