# Azure Resource Names

## Environments

| Resource Type | Development | Prod-Acme-Legacy |
|--------------|-------------|-------------------|
| Key Vault | `kv-acme-dev-uks-001` | `kv-acme-prod-sp-uks-001` |
| PostgreSQL | `psql-acme-dev-uks-001` | `psql-acme-prod-sp-uks-001` |
| Application Insights | `appi-acme-dev-uks-001` | `appi-acme-prod-sp-uks-001` |
| Resource Group | `rg-acme-dev-uks` | `rg-acme-prod-uks` |

## Common Key Vault Secrets

| Secret Name | Description |
|-------------|-------------|
| `db-host` | PostgreSQL hostname |
| `db-port` | PostgreSQL port (usually 5432) |
| `db-username` | Database username |
| `db-password` | Database password |
| `db-name` | Database name |
| `erp-client-id` | ERP OAuth client ID |
| `erp-client-secret` | ERP OAuth client secret |
| `commission-webhook-secret` | Webhook authentication |

## Required Permissions

- **Key Vault**: Key Vault Secrets Officer or Key Vault Reader
- **Database**: Firewall rule allowing your IP
- **App Insights**: Reader role on Application Insights resource
