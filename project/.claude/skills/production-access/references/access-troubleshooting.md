# Production Access Troubleshooting

## Azure Login Issues

```bash
az logout
az account clear
az login
az account show
```

## Key Vault Access Denied

**Error:** `The user, group or application does not have secrets list permission`

**Fix:**
1. Request access from Azure admin.
2. Azure Portal → Key Vault → Access policies.
3. Add access policy with Secret permissions: Get, List.
4. Wait 5-10 minutes for propagation.
5. Test: `az keyvault secret list --vault-name kv-acme-prod-sp-uks-001`

## Database Connection Refused

**Causes:**
- Firewall rules — your IP not whitelisted
- Wrong credentials — check Key Vault secrets
- SSL required — add `sslmode=require`

**Add Firewall Rule (requires admin):**
```bash
az postgres flexible-server firewall-rule list \
  --resource-group rg-acme-prod-uks \
  --name psql-acme-prod-sp-uks-001

az postgres flexible-server firewall-rule create \
  --resource-group rg-acme-prod-uks \
  --name psql-acme-prod-sp-uks-001 \
  --rule-name "MyIP-$(date +%Y%m%d)" \
  --start-ip-address "$(curl -s ifconfig.me)" \
  --end-ip-address "$(curl -s ifconfig.me)"
```

## Application Insights Access Denied

**Error:** `Authorization failed`

**Fix:** Request Reader role on Application Insights resource:
```bash
az role assignment list \
  --scope "/subscriptions/<subscription-id>/resourceGroups/rg-acme-prod-uks/providers/Microsoft.Insights/components/appi-acme-prod-sp-uks-001" \
  --assignee "$(az account show --query user.name -o tsv)"
```
