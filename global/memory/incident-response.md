# Incident Response

## Azure PG Access
1. Whitelist IP on BOTH PG firewall AND Key Vault
2. Password: `az keyvault secret show --vault-name <env>-acme-kv --name postgres-password`
3. Connect: `sslmode=require` mandatory
4. Envs: `prod` (prod-acme-rg, legacy_prod) | `development` (development-acme-rg, legacy_development)
5. **Always clean up firewall rules after**

## pg-boss Job Replay
INSERT new job from dead letter: copy name+data, set `retrycount=0, state='created'`
Verify via App Insights: `CONFIRMATION_EMAIL_SENT` event

## App Insights KQL
- Dead letters: `traces | where message has "JOB_DEAD_LETTER"`
- Emails: `traces | where message has "CONFIRMATION_EMAIL"`
- Commission webhooks: `traces | extend log = parse_json(message) | where log.category == "COMMISSION_WEBHOOK"`

## Email Validation (2026-02-06)
Defense-in-depth: API boundary (`sanitizedEmailSchema` Zod transform+pipe) -> Service layer (`sanitizeEmail()`) -> Job layer (fail-fast)
Key files: `emailHelpers.ts`, `Customer*Schema.ts`, `SalesService.ts`, `PurchasesService.ts`, `SendConfirmationEmailJob.ts`

## SQL Safety
- Always BEGIN/COMMIT
- Audit SELECT before UPDATE
- Use `REGEXP_REPLACE` over TRIM
- `chr(9)` for tabs in docker exec
- `<>` not `!=` in docker exec
