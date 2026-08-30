---
name: platform-local-sso-setup
description: How to enable Microsoft Entra SSO on the LOCAL docker-compose Platform stack — the 3 blockers + fixes
metadata:
  node_type: memory
  type: reference
  originSessionId: 00000000-0000-0000-0000-000000000009
---

Enabling **Microsoft Entra SSO on the local docker-compose Platform stack** (not the dev cluster) needs THREE things beyond a running stack. Verified working 2026-07-01. Related to the dev-cluster delivery in [[platform-dev-superadmin-seed]] (#1517/#1518/#1519), but that covers AKS, not local.

**The 3 blockers (all must be cleared):**

1. **Compose must pass `OIDC_*` to auth-service.** `docker-compose.platform.yml` auth-service block has an explicit `environment:` list and NO `env_file:`, so `.env.platform` values do NOT reach the container by default. Added 4 passthrough lines `OIDC_CLIENT_ID/OIDC_CLIENT_SECRET/OIDC_AUTHORITY/OIDC_REDIRECT_URI: ${…:-}` (empty default → seed writes DISABLED placeholder, unchanged behaviour). Set all four in `.env.platform`; the seed (#1519 logic in `apps/platform/auth-service/src/seed/admin-bootstrap.seed.ts`) then PROMOTES the tenant's `auth.oidc_provider` to `is_enabled=true` on the next auth-service restart. Verify: seed log flips from "disabled OIDC placeholder" → "ENABLED Entra OIDC provider".

2. **Entra app needs a `http://localhost` redirect URI.** The dedicated dev app **"Acme Platform OIDC (development)"** (client_id `00000000-0000-0000-0000-000000000031`, tenant `00000000-0000-0000-0000-000000000005`) only had the dev-cluster redirect. It's a confidential **Web** client → use `--web-redirect-uris` (NOT spa). Add `http://localhost:5173/api/v1/auth/oidc/freshco/callback`, preserving existing (fetch `web.redirectUris`, jq-append, `az ad app update`). Entra allows http for localhost (loopback exemption). Needs write access to the shared app (Application Administrator / owner) — else operator/Portal task.

3. **FE tenant slug — NO code change.** Route is `/api/v1/auth/oidc/:tenantSlug/login`; `SignInPage.resolveTenantId()` reads `?tenant=`/`?tenantId=`, falling back to `'default'`. The seeded local tenant is **`freshco`** (admin@freshco.test). So open **`http://localhost:5173/login?tenant=freshco`** → `startSso('freshco')`. Do NOT hardcode the slug in shared FE code.

**Secret handling:** `.env.platform` (gitignored) `OIDC_CLIENT_ID`/`OIDC_AUTHORITY`/`OIDC_REDIRECT_URI` are NON-secret (mirror `charts/overlays/dev/identity.yaml`). `OIDC_CLIENT_SECRET` comes from Key Vault **`development-acme-kv`** secret **`platform-auth-oidc-client-secret`** (`az keyvault secret show … -o tsv`) — NEVER print it, NEVER raw-SQL it (the seed encrypts via AesGcm).

**Restart to apply:** `docker compose --env-file .env.platform -f docker-compose.platform.yml -f docker-compose.platform.seed.yml up -d --force-recreate --no-deps auth-service`.

**Gotchas:** AADSTS50011 right after adding the redirect → Entra propagation up to ~1 min. The authenticating MS account must map to a seeded user in the local tenant — the human operators are seeded as superadmins for exactly this, whereas the synthetic admin fixture is password/TOTP only and is not a real MS identity. For sign-out / most testing, password+TOTP login works without any of this — local SSO is only needed to exercise the OIDC flow itself.

NOTE (2026-07-01): the compose passthrough (blocker 1) is currently an UNCOMMITTED local change on `fix/platform-local-bringup-order-and-migrate-env`, kept OUT of PR #1576. Split into its own PR if the team wants durable local-OIDC support.
