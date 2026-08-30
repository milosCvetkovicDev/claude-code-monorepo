---
name: platform-tenant-provisioning-epic
description: ACTIVE epic #1723 — SUPERADMIN Create-Tenant + tenant Onboarding provisioning UI wizards on @acme/ui; RED baseline synced, readiness gate passed, awaiting issue-start
metadata:
  node_type: memory
  type: project
  originSessionId: 00000000-0000-0000-0000-000000000009
---

**ACTIVE epic #1723 (synced 2026-07-19)** — the two Platform provisioning UI flows: SUPERADMIN
**Create-Tenant** wizard + tenant **Onboarding** wizard in `apps/platform-frontend` on `@acme/ui`,
recreating the Platform v2 prototype against the (mostly) already-built platform-tenant + onboarding
backend. Branch `feat/platform-tenant-provisioning` (2 commits: RED baseline `d7c130bc` +
readiness remediation `9f8a98b3`). PRD/epic/architecture/task-files/**test-manifest.md**/
**remediation-spec.md** all in `.claude/epics/platform-tenant-provisioning/` (git-EXCLUDED). Followed full
PM ceremony: prd → arch-create → epic-decompose (11 tasks) → tests-generate (RED) → readiness-check →
epic-sync. **Next = issue-start** (kit-first order).

**Issues:** epic **#1723**; tasks **#1724**(001 WizardStepper) **#1725**(002 ProgressRail)
**#1726**(003 DomainInput adornment) **#1727**(004 slug-availability) **#1728**(005 onboarding BOLA guard)
**#1729**(006 first-admin invite) **#1730**(007 tenant-settings: company-details+defaults+erp-test)
**#1731**(008 FE clients+safeHref) **#1732**(009 Create-Tenant wizard) **#1733**(010 Onboarding wizard)
**#1734**(011 OWASP+axe gate). Dep order: leaves 001-006 ∥; 007[5]; 008[4,5,6,7]; 009[1,3,8]; 010[2,5,7,8]; 011[9,10].

**RED baseline (~29 spec files) verified maker≠checker** — nx exit=1 on platform-ui / platform-tenant-service /
platform-user-service / platform-frontend for the missing-impl reason, zero pre-existing regression. Two REAL
backend defects were confirmed by arch-review + are blocking tasks: **005 BOLA** — `OnboardingController`
has NO `@UseGuards` (doc-mandated cross-tenant guard missing); **006 INVITE-GAP** — create-tenant consumer
makes only an INVITED user, no Invitation/token/email. e2e = `nx e2e platform-frontend-e2e`
(`src/tenant-provisioning/{create-tenant,onboarding}.spec.ts`, run at issue-close vs a live stack).

**Readiness gate (5 independent reviewers) caught + fixed before sync:**

- **The company-details body is FLAT, not nested** — task 007 had drifted to a nested `erpConfig{apiCredentials}`
  shape that would 400-reject the FE's flat body AND stored third-party integration credentials **plaintext**
  (violated the Tenant AES-256-GCM at-rest invariant).
- **Architectural resolution (KEY):** this epic stores **NO per-tenant ERP API credentials**. Per-tenant state
  keeps only a non-secret account identifier; the ERP **test-connection** is **platform-credentialed**
  (`POST /api/v1/tenants/:id/erp/test-connection` → uses the platform's own ERP integration plus that identifier,
  no secret in the response). This dissolved the flat/nested + plaintext-cred + ADMIN-vs-SUPERADMIN conflicts
  at once. If per-tenant ERP OAuth is ever needed → separate SUPERADMIN task via `updateIntegrationCredentials` (encrypted).
- **Scope decisions:** the tenant defaults are **persisted** via a new `PATCH /api/v1/tenants/:id/settings`; one
  further required field was **added** from the PRD (the PRD is source of truth) alongside the platform ERP
  test-connection; Playwright e2e **added** (RED-by-construction).

**Kit-first (AD-7):** two new `@acme/ui` primitives — `WizardStepper` (horizontal numbered, roving focus)

- `ProgressRail` (vertical rail) — authored/storied/tested in the kit BEFORE app import. Every new component
  needs Storybook + tests; OWASP-for-React is a merge gate (task 011). Non-blocking issue-start carry-overs
  (in the manifest): 011 SEC-GATE #3/#5 independence; primitive wireframe-axe (001/002); 004 extend-artifact
  re-verify at issue-close; shared 005/007 guard message; `POST /tenants/logo` has NO backend handler (follow-up).
  Relates to [[platform-fail-closed-tenant-filter-forked-em]] (backend guard specs use Nest Fastify harness, not
  neutered testcontainers), [[platform-import-type-disables-validationpipe]] (runtime DTOs), [[platform-finance-ui-epic]].

**ALL 11 IMPLEMENTED + GREEN (2026-07-19), maker→checker each.** Branch tip `f62101eb` (leaves+fixes
`ddb55485`, 007 `a61ceb17`, 008 `e197bf76`, 009+010 `cb2d054e`, 011 `f62101eb`); full suites green incl.
platform-frontend 709 passed. **Checkers caught 5 prod-breaking defects the mocked specs HID (recurring
"green-but-broken"):** (1) #006 FLAT payload vs DomainEvent envelope → invite dead in prod (fixed:
TenantEventPublisher.publishTenantCreated + real SUPERADMIN userId + contract test); (2) #005 BOLA — user
chose **ADR-0029 STRICT own-tenant only** (dropped SUPERADMIN cross-tenant read); (3) #008 checkSlugAvailable
returned backend verbatim → enumeration oracle (whitelist {slug,available}); (4) #009/010 imported
updateTenantSettings/updateCompanyDetails/testErpConnection as NAMED from admin.ts which only had
tenantApi.\* → undefined at runtime, masked by named mocks (added top-level named exports); (5) #011 owasp
grep false-positived on **tests**+comments → grep PRODUCTION for real `dangerouslySetInnerHTML=`, mutation-
proven. **META: always run a checker that exercises the REAL module/wire-format, not the mocked spec.**

**EPIC-REVIEW DONE + epic-merge PR #1738 OPEN (2026-07-19, awaiting USER merge).** Branch `feat/platform-tenant-provisioning`
(tip `223c0ceb`, 16 ahead / 0 behind origin/main — merged main in `7ceac6a8`). Epic-review caught **B1: the
wizards were never routed** (the 11 per-task mocked reviews structurally couldn't see it) → fixed in `a5d125a5`
(mount `/platform/tenants/new` SUPERADMIN + `/onboarding` in-page NonAdminGuard, nav entry, repoint dead
SuccessScreen link) plus FE-vs-real-DTO contract fixes. Two post-review **fast-follows** landed `223c0ceb`:
(A) **erpCompanyId persistence** — captured in company_details FLAT body (NOT a `{erpCompanyId}`-only partial
PATCH → 400s on required whitelist); (B) **D4 invite concurrency** — Migration 004 partial unique index
`invitation_tenant_email_pending_uq (tenant_id,email) WHERE status='PENDING'` (raw SQL — private `_email`/`_status`
reject typed `@Unique`; cols are `email`/`status` per Migration 001, underscore stripped) + `createFirstAdminInvitation`
catches `UniqueConstraintViolationException`→return null (idempotent no-op, same as duplicatePending fast path).
Verified maker≠checker: user-events 23 (2 new D4), invitation.service 43, OnboardingWizard 26, typecheck both clean.
**Merged to main** as `1f439fd2` (PR #1738, 2026-07-19).

**DEPLOYED + LIVE-VERIFIED on dev-platform (2026-07-19).** tenant/user `sha-762b1a6`, frontend `sha-fd4eea1`;
**Migration 004 applied** (init-container log "Applied Migration_004_invitation_pending_unique_index"). Backend
behaviorally verified via header-identity smoke (port-forward tenant-service): onboarding no-identity→401,
cross-tenant ADMIN→403 `ONBOARDING_ACCESS_DENIED`, company-details PATCH→401(not 404). Frontend: `/platform/tenants/new`
→ redirects to `/login` (RequireRole works), new bundle serves. **The deploy was a saga — 3 latent defects the
SKIPPED epic build-push had hidden surfaced only when CI/images were finally forced:** (1) ReDoS slug regex lint
error (fixed PR #1739 — `slug.ts` decomposed to star-height-1 charset + boundary checks); (2) `user.integration.spec.ts`
built UserEventConsumer with 3 args (task-006 made invitationService a REQUIRED 4th param, fail-loud) → fixed;
(3) tenant-scope.guard.spec.ts coverage gap filled. **KEY DEPLOY LESSONS (see [[platform-deploy-trigger-and-writeback]]):**
build-push only rebuilds `$SHA~1..$SHA` — a skipped epic build leaves NO images AND its full CI never ran, so latent
defects hide; **`ci-cache-version.txt` bump is TOO BROAD** (marks the ENTIRE monorepo incl. legacy-api
affected → legacy CI runs full-affected + fails on infra-dependent tests → blocks merge; REVERTED). Correct fix =
**targeted rebuild**: touch ONLY the services needing images (test-file touches suffice) so nx-affected stays scoped,
legacy un-affected. Then manual chart-tag bump PR (writeback GH006-blocked): identity-bundle tenant/user + `charts/values/platform-frontend.yaml`.
Rollout: identity canary has TIMED 2m pauses (`kubectl argo rollouts promote <r> -n platform-identity --full` to skip);
**platform-frontend is manual-sync** (`kubectl -n argocd patch application platform-frontend --type merge -p '{"operation":{"sync":{"revision":"<sha>"}}}'`).
**Playwright e2e NOT cleanly runnable vs live dev** — globalSetup needs seeded superadmin creds+TOTP (not in repo) and
posts `/auth/login` (dev gateway routes `/api/v1/...`); webServer runs `nx serve` (dev-server, hangs). Validated via
header-identity smoke + browser instead. **Follow-ups DONE — PR #1743 (auto-merge armed, reviewed+approved):** guard
unification (abstract `OwnTenantAdminGuard` base + 2 subclasses, both codes kept); seed workspace-discovery template
(new idempotent migration, ON CONFLICT); env-drive `WORKSPACE_BASE_DOMAIN`→`getPlatformBaseDomain()` (fixes dev URL);
slug latest-wins AbortController (+ teeth-verified out-of-order race test). **`POST /tenants/logo` DEFERRED → issue #1742**
(no handler + no real Platform blob storage + wizards don't call it → product/storage decision). **Follow-up PR #1743 MERGED +
DEPLOYED (2026-07-20): PR #1744 bumped tenant-service/notification-service/platform-frontend all → `sha-9b02917`; template-seed
Migration20260719000000 Applied; all 3 apps Synced/Healthy.** Accepted test gap: no testcontainers migration test for the seed
(verified correct on every axis; heavy infra for a low-risk data seed).

**INVITE EMAIL pipeline COMPLETE — PR #1755 merged `cf4c224` (2026-07-20).** Closed the #006 INVITE-GAP end-to-end: the
docs-mandated final leg (identity-platform.md L304 `platform.user.invited` → notification sends email) was MISSING — nothing
consumed it. Added the notification-service consumer (`handleUserInvited`, binds `acme.platform`) + a designed accept-email
renderer; user-service `enableRelay:true` + entity fieldName fixes. Real delivery via **ACS** (already live on dev — comms-bundle
`provider:acs`, base domain + KV secrets set 2026-07-19; my "it's mock" was a legacy-file misread). Adversarially reviewed
(maker≠checker security+correctness): fixed audit-lane token leak (→[[platform-outbox-relay-audit-feed-leaks-secrets]]),
reconnect-helper weakness (→[[platform-reconnect-consumer-helper-hardened]]), token-at-rest in `notification_delivery` (redact after
DELIVERED send), tenant forgery cross-check; residuals #1756/#1757. Deploy = bump comms-bundle notification L16 + identity-bundle
user-service L354 → `sha-cf4c224` (RMQ grant rides identity-bundle as a subchart). Verified: unit+147 notif+248 user+89 real-PG integration green.

**DEPLOYED + LIVE-VERIFIED END-TO-END on dev-platform (2026-07-20).** notification `sha-cf4c224`+user-service `sha-cf4c224`
(PR #1758 `c7d3c2e9`); both canary rollouts promoted; RMQ topology confirmed (`user-service.platform.tenant.created`←platform.tenant.created,
`notification-service.platform.events`←platform.user.invited, both 1 consumer, no ACCESS_REFUSED). Header-identity smoke on the REAL
endpoint `POST /api/v1/platform/tenants` → full chain fired: user-service "First-admin invitation created" → notification "Created
user-invited delivery" → **"ACS accepted email"** (real send). **KEY: two create paths — the FE/gateway uses `POST /api/v1/platform/tenants`
→ `PlatformTenantController` → `PlatformTenantService.create({createdByUserId: context.userId})` → CreateTenantUseCase (threads the REAL
SUPERADMIN userId, ADR-0029). The LEGACY `TenantController` (`POST /api/v1/tenants`, still mounted) hardcoded `createdById='system'` in
create/update/suspend/delete — a non-UUID that DLXed the invite (uuid inviter insert) + 500'd soft-delete; NOT the FE path. **FIXED PR #1759
(`1c997445`) + DEPLOYED `sha-1c99744` (PR #1760 `e00cf7ec`): guarded with GatewayIdentityGuard + `@CurrentUser().userId` on all 5 mutating
endpoints; added tenant.controller.spec.ts (first unit test). LIVE-VERIFIED: legacy create → "First-admin invitation created" → "ACS accepted
email" (op aa8adf6b), no DLX. Both create paths now fire the invite end-to-end.** Build note: the shared event-bus change made accounting-service "affected" → its `finance-ui-consumer` FR-G4 **[RED] scaffold\*\*
failed the pipeline pact gate → build-push skipped; unblocked via break-glass `gh workflow run platform-build-push.yml` ([[feedback_cross_poc_red_scaffolds_break_prs]]).

**FIRST-ADMIN ONBOARDING-JOURNEY REMEDIATION (2026-07-21) — 3 live defects the user hit walking create-tenant → invite → accept → set-password, ALL masked by mocked guards/gateway in tests:**

1. **Forgot-password sent NO email** — `identity.password.reset-requested` carried no token + notification had no reset consumer (same class as #006 invite-gap). Fix mirrors invite pipeline: auth event carries token+expiresAt, relay.auditSecretFields strips `payload.token` from audit lane, notification `handlePasswordReset` sends designed reset email (link `…/password/reset?token=`), redact-after-DELIVERED. **PR #1767 (`5baccc4f`) → DEPLOYED `sha-5baccc4` (PR #1770) + LIVE-VERIFIED** (reset-request → "Created password-reset delivery" → "ACS accepted email").
2. **Invite-accept 401 "No authentication token provided"** — the GATEWAY, not the token: service-registry gated whole `/api/v1/invitations` prefix `requiresAuth:true`, but `/accept` is PUBLIC (unauthenticated invitee — identity-user.feature). FE then auto-`/auth/refresh`→401→misleading "session expired" modal. Fix: more-specific `/api/v1/invitations/accept` registry entry `requiresAuth:false` BEFORE the general prefix (first-match); FE `preAuth` request opt-out of refresh/session-expiry; accept handler ApiResponse 401→400/409 (service already returned 400/409). **Also fixed the `platform-api-prefix-guard`** (`scripts/ci/check-platform-api-prefix.mjs`): FORWARD check now matches an ANCESTOR controller (`pathPrefix.startsWith(controllerPrefix+'/')`) — a public sub-route is served by its parent BC controller; +negative test proves it doesn't weaken the guard. **PR #1768 (`a4c23b6e`) → deploy PR #1771 (gateway+user-service `sha-a4c23b6`).**
3. **Create-tenant Defaults step 403 `TENANT_SCOPE_MISMATCH`** — the wizard runs as a platform SUPERADMIN, not a member of the tenant it is creating, yet PATCHed the ADMIN own-tenant `/tenants/:id/settings`. Surfaced a doc-vs-code divergence: `tenant.md` models one `PUT /tenants/:id/config` (SUPERADMIN all / ADMIN own, emits `platform.tenant.config.updated`); the code had grown a **write-only** parallel settings route with a duplicate field under a second name (audit: NO readers). Resolved **doc-first**. **ADR-0073**: retire `PATCH /settings` (controller+use-case+DTO+specs); add shared `UpdateTenantConfigUseCase` (em.transactional + emits config.updated) behind `PUT /tenants/:id/config` (ADMIN, TenantScopeGuard) + `PUT /platform/tenants/:id/config` (SUPERADMIN cross-tenant, PlatformScopeGuard — required because gateway forwards x-platform-scope only on /platform/_ per ADR-0029; TenantConfig is TENANT_EXEMPT so cross-tenant resolves cleanly); collapse the duplicated pair onto the canonical name and relocate the remaining defaults to flat optional `settings._`; wizard→platform config route. **PR #1769 (`6aa0a7bc`), tenant-service building.** **`docs/platform/doc-site/` is READ-ONLY (the architecture source) — code aligns to it, new decisions go in ADRs (docs/adr/, highest was 0072).\*\* Meta: reset+invite+config all had the SAME failure signature — a real backend/gateway defect invisible to specs that mocked the guard/gateway; run the checker against the REAL wire (gateway registry, real guard chain), not the mock.

**ALL DEPLOYED + LIVE-VERIFIED on dev-platform (2026-07-21), final images `sha-1ed8771`** (auth/user/tenant in identity-bundle, notification in comms-bundle; frontend `sha-6aa0a7b`; gateway `sha-a4c23b6`). Journey verified: reset email (ACS accepted), invite-accept (400 from service not gateway 401), create-tenant config routes mounted. **CONFIG-ROUTE 500 REGRESSION + the fix that matters most:** `PUT /platform/tenants/:id/config` 500'd `Trying to query by not existing property TenantConfig.tenantId` — the fail-closed tenant filter is `default:true` (applies to EVERY entity); TenantConfig is TENANT_EXEMPT + maps `_tenantId`, so a caller's `em.transactional` fork with a filter param injects a `{tenantId}` cond that throws. Fix: `MikroOrmTenantConfigRepository.findByTenantId` disables the filter (`{filters:{tenant:false}}`) #1776. **WHY IT SLIPPED: #1769 was unit-tested with a MOCKED repo, AND the shared testcontainers `setup.ts` NEUTERS the filter (`cond:()=>({})`, `default:false`) — no test hit the real filter.** Added `mikro-orm-tenant-config-filter.tc.spec.ts` booting the REAL `createMikroOrmConfig` filter: RED reproduces the exact 500, GREEN with the fix (incl. full find→mutate→save round-trip). **RULE: for a route that touches a TENANT_EXEMPT entity in a transactional fork, the real-filter integration test is mandatory — mocked-repo unit tests are green-but-broken.** Follow-ups #1756/#1757 (token-at-rest M1 outbox scrub-on-PUBLISHED + M2 notification no-DLQ-token) PR #1774; #1761 pact→self-hosted 8-vCPU (+ubuntu fallback, exactly-one-runs preserves the gate) PR #1775; #1742 tenant logo upload (Fastify @fastify/multipart + real @azure/storage-blob adapter, config-gated NullTenantAssetStorage→503 until storage provisioned, magic-byte validation, ADR-0074) PR #1777 — all merged+deployed. **#1742 OPEN INFRA HANDOFF: logo 503s until an operator provisions the Azure Storage account+container+`TENANT_ASSET_STORAGE_CONNECTION_STRING` KV secret via Terraform (operator-only; az-CLI would be TF drift).** ADR-0073 (config reconciliation) + ADR-0074 (tenant-asset storage) on main.
