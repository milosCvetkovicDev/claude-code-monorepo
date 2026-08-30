---
name: platform-dev-superadmin-seed
description: Dev-Platform superadmin seed for the team's human operators — password+TOTP works; MS SSO LIVE on dev (verified 2026-07-01)
metadata:
  node_type: memory
  type: project
  originSessionId: 00000000-0000-0000-0000-000000000009
---

PR #1517 (`feat/platform-superadmin-seed`, off main 2026-06-30) seeds the team's real human operators as
**dev/local** SUPERADMINs alongside the synthetic tenant-admin fixture. The roster itself — who, at which
address, under which user id — lives in code (see below), not in this note; nothing about it is
environment-specific except the gate it sits behind.

Each operator gets BOTH login methods (spec allows both on one account — `auth.md:23`; only an SSO-only
account with no password is blocked, `login.use-case.ts:101`):

- **password + TOTP 2FA** — ENABLED per-user `mfa_config`; login requires the shared dev password `<DEV_SUPERADMIN_PASSWORD>` **and** an authenticator code.
  - an authenticator code. Per-operator TOTP secrets in `auth-service` `admin-bootstrap.constants.ts`
    (`DEV_SUPERADMIN_TOTP_SECRETS`); roster (identity only) in `@acme/platform-contracts` `DEV_SUPERADMINS`.
- **Microsoft Entra SSO** — email-matched JIT link (`matchOrProvisionUser → linkIdentity`).

**Enrollment:** `npx tsx scripts/platform/dev-superadmin-mfa.ts [email]` prints the `otpauth://` URI
(SHA1/6/30) + current code (reuses `tests/platform/lib/totp.mjs`). MS Authenticator → Add account → Other.

**Two gates before login actually works on dev:**

1. Seed only takes effect when the operator re-seeds dev (user-service + auth-service bootstrap with
   `NODE_ENV=development` + `SEED_ON_BOOTSTRAP=true`). No migration.
2. **MS SSO half is operator/Azure-gated** — `oidc_provider` is seeded as a DISABLED placeholder
   UNLESS real OIDC config is supplied (see SSO chain below). Password+TOTP works WITHOUT it.

**MS SSO enablement chain (4 PRs, 2026-06-30) — ALL FOUR MERGED; SSO LIVE on dev (verified 2026-07-01):**

- **#1517** `feat/platform-superadmin-seed` — password+TOTP seed (base). **MERGED**.
- **#1518** `feat/platform-dev-oidc-entra` — **DEDICATED** Entra app via count-gated Terraform module
  `infra/modules/platform-oidc-entra` (NOT the legacy SPA app — Platform needs confidential-client Web
  flow). Gated `enable_platform_oidc_app=false`; writes client secret to KV
  `platform-auth-oidc-client-secret` in `development-acme-kv`. Outputs `client_id` / `authority`
  (`https://login.microsoftonline.com/00000000-…/v2.0`) / redirect
  (`https://dev.platform.acme-example.co.uk/api/v1/auth/oidc/freshco/callback`, ADR-0058 /api/v1).
  **`terraform apply` is OPERATOR-ONLY** (outward-facing Entra reg). **APPLIED 2026-06-30** (4 add):
  client_id `00000000-0000-0000-0000-000000000031`, app obj `00000000-0000-0000-0000-000000000032`,
  SP `00000000-0000-0000-0000-000000000033`; KV secret `platform-auth-oidc-client-secret` live in
  `development-acme-kv`. Apply needs the var-wall 4: github_app PEM = **gitops-pusher** (app id
  `<GITHUB_APP_ID>`, `~/Downloads/acme-gitops-pusher.*.private-key.pem`), runner principal = ukwest VM
  `00000000-0000-0000-0000-000000000034` — but ALL 4 are INERT under `-target=module.platform_oidc_entra`.
  NOTE: dev runner VM renamed → **`development-acme-ukwest-runner`** (UK West, running; old
  `development-acme-runner` gone); state's `runner_acr_push` grant points to STALE deleted-VM
  principal `00000000…` (neither ukwest `00000000` nor ARC `00000000`) — orphaned, cleanup ticket **#1520**.
  GHA runners healthy: repo-level `acme-ukwest-01`/`02` online (label `acme-ukwest`).
- **#1519** `feat/platform-oidc-seed-wiring` (stacked on #1517) — **app capability**: seed reads
  `OIDC_CLIENT_ID/SECRET/AUTHORITY/REDIRECT_URI` (optional, in `auth.config.ts`) → when all 4 set,
  provisions `oidc_provider` ENABLED (or promotes the disabled placeholder via new
  `OidcProvider.configure()` + `enable()`). Secret written THROUGH the app so
  `SecretEncryptionSubscriber` AES-256-GCM-encrypts it — **NEVER raw SQL** the `client_secret`.
  Threaded via `AuthSeedModule.forRoot(... , oidc)` → `AUTH_SEED_OIDC_CONFIG` token. **MERGED**.
- **#1521** `feat/platform-oidc-chart-delivery` (base main) — **chart env delivery**, **OPEN**. New
  optional `.Values.oidc` block in `platform-base` (clientId/authority/redirectUri → OIDC\__ env on the
  app container ONLY when clientId set; deployment+rollout; declared in values.yaml + values.schema.json
  — schema is `additionalProperties:false`). Secret via the EXISTING `.Values.secrets` MAP (merges,
  unlike the env LIST): `OIDC_CLIENT_SECRET` → ESO from KV `platform-auth-oidc-client-secret` → secretKeyRef.
  `overlays/dev/identity.yaml` sets `auth-service.oidc._`+`secrets.OIDC_CLIENT_SECRET`(prod overlays
do NOT → disabled there, env-safe). +6 helm-unittest;`helm template` bundle verified. **MERGED 2026-06-30.**

**SSO LIVE on dev — VERIFIED 2026-07-01:** `curl -sSI https://dev.platform.acme-example.co.uk/api/v1/auth/oidc/freshco/login`
→ **HTTP 302** to `login.microsoftonline.com/00000000-…/oauth2/v2.0/authorize` with the correct
`client_id=00000000-0000-0000-0000-000000000031`, exact `redirect_uri=…/api/v1/auth/oidc/freshco/callback`,
`scope=openid profile email`, PKCE S256 + state + nonce. Proves `oidc_provider` row is seeded+ENABLED
and auth-service is wired (real client_id, not placeholder). Token-exchange leg strongly evidenced by
the deployed `email_verified`-gate fix (`f0bf02d`, #1528) — that code only runs POST code→token exchange,
which needs the correct `client_secret`. The only unproven step is a full human browser round-trip
(sign in as a seeded superadmin → JIT email-link). Legacy app id `00000000…` does NOT exist in tenant —
dedicated app is correct.

**Confirmed apply mechanics (2026-07-01):** the `-target=module.platform_oidc_entra` apply returned
**No changes** (already applied from the `acme-platform-oidc-entra` worktree, which shares the same remote
state). A BLANKET `terraform apply` on dev-platform is NOT safe-by-omission but safe-by-ERROR: 7 pre-existing
KV secrets (internal-api + commission/document/notification pg+rmq) would hit azurerm v4.58.0
ImportAsExistsError (create-conflict, NOT silent rotation) — plus `module.github_app` (KV names exist
out-of-band) would also create-conflict, and the `rmq_password` resources LOST their `ignore_changes`
(task 1185) so a naive later `terraform import` of them would breaking-rotate live AMQP creds
(#983/#1154 class). Reconciling that drift (import DNS #1396 + the 7 secrets, RMQ preflight
`scripts/platform/rmq-reimport-preflight.sh` first) is a SEPARATE deliberate task — never bundle into an
SSO/routine apply. Surgical `-target=module.platform_oidc_entra` is the clean path (4 resources, prunes the rest).

**Per-role tenant test users (#1763/#1765, LIVE-VERIFIED dev 2026-07-21):** login-capable
NON-SUPERADMIN fixtures in the dev tenant (`DEV_TENANT_FIXTURE_USERS`), one per tenant-assignable
role — **password-only, NO TOTP** (the 2FA mandate is SUPERADMIN-only). Their addresses are derived
from the role name, so one of them collides with the bootstrap admin address on the
`(tenant_id,email)` unique index — and because the fixture insert is ONE atomic batch, a single
duplicate fails ALL rows. Passwords `<TENANT_FIXTURE_PASSWORD>` in auth `admin-bootstrap.constants.ts`
`DEV_TENANT_FIXTURE_PASSWORDS` (keyed by USER_ID, not email). Login: `POST /api/v1/auth/login`
`{email,password,tenantId}` (field is **`tenantId`**, accepts slug|UUID) → 200
`{userId,sessionId}`. Both seed legs iterate the array
generically+idempotently (user-service→identity.user+user_role via `seedRolesAndPermissions`
roleIdMap, which resolves every assignable role; auth→credential). Gated NODE_ENV=development

- SEED_ON_BOOTSTRAP=true (both true on dev). [[platform-tenant-provisioning-epic]].

Azure Cache for Redis 6.0 GETDEL fix landed first (#1514) so MFA verify works — see
[[platform-azure-cache-redis-6-0-no-getdel]].
