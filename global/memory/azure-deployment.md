# Azure Deployment

## Environment URLs (Development)
| Service | URL |
|---------|-----|
| Legacy Backend | https://development-acme-legacy-api-web-app.azurewebsites.net |
| LegacyWeb Frontend | https://acme-legacy-web-dev.azurestaticapps.net |
| Commission API | https://dev-acme-domain-api.acme-env-dev.uksouth.azurecontainerapps.io |

## Dev-2 Instance URLs
| Service | URL |
|---------|-----|
| LegacyWeb Frontend | https://acme-legacy-web-dev2.azurestaticapps.net |
| Legacy Backend | https://dev-2-acme-legacy-api-web-app.azurewebsites.net |
| Commission API | https://dev-2-acme-domain-api.acme-env-dev2.uksouth.azurecontainerapps.io |

## Database
- Development: `development-acme-postgres.postgres.database.azure.com` / `legacy_development`
- Password in Key Vault: `az keyvault secret show --vault-name <env>-acme-kv --name postgres-password`
- Subscription: `00000000-0000-0000-0000-000000000002` (Sponsorship)

## App Service Env Var Changes
- **Must explicitly restart**: `az webapp restart --name <app> --resource-group <rg>`
- Not always automatic after `az webapp config appsettings set`

## Container App Troubleshooting
- Check logs: `az containerapp logs show --name <app> --resource-group <rg> --type console --tail 50`
- Revision status: `az containerapp revision list --name <app> --resource-group <rg> --query "[].{name:name,health:healthState}"`
- ActivationFailed: check logs first, then `az containerapp show -o yaml` for full config
- Outbound IPs: `az containerapp show --query "properties.outboundIpAddresses"` (dynamic!)
- Fix and trigger new revision: `az containerapp update --revision-suffix <name>`

## PostgreSQL Firewall
- Container Apps without VNet use dynamic IPs — use `allow_azure_services = true`
- Manual access: whitelist IP on BOTH PG firewall AND Key Vault
- `sslmode=require` mandatory
- **Always clean up firewall rules after**

## Deploying from Feature Branch
```bash
gh workflow run deploy-dev-ephemeral.yml --ref <branch> -f instance=dev-2 -f action=deploy
gh run list --workflow=deploy-dev-ephemeral.yml --limit 3
gh run watch <run-id> --exit-status
```

## User Identities Across Environments
The same person has a different application row id **and** a different Entra object id in every
environment. Resolve identity fixtures per environment (query them, or read them from that
environment's seed) — never copy an id from dev into a prod procedure, and never hardcode one in a
test.

## Commission Proxy Error Mapping
- 500+ -> 502, 4xx -> preserved, fetch fail -> 503, timeout -> 504
- `EnvironmentVariableNotFoundError` extends `ServerError` (was `NotFoundError` — fixed)
