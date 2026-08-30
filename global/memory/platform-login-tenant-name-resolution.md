---
name: platform-login-tenant-name-resolution
description: "Platform /auth/login + reset accept a tenant NAME (slug) or UUID, resolved server-side;"
metadata:
  node_type: memory
  type: project
  originSessionId: 00000000-0000-0000-0000-000000000045
---

**Platform pre-auth password login accepts a tenant NAME (slug) OR a UUID in the request-body `tenantId`.** `/auth/login` and `/auth/password/reset-request` are `@Public` (pre-auth) → the gateway's JWT-based `x-tenant-id` resolution does NOT cover them (no JWT yet). `AuthController` resolves the identifier via **`TenantIdentifierResolver`** (`apps/platform/auth-service/src/modules/auth/tenant-identifier.resolver.ts`): UUID passes through (no call); a slug → tenant UUID via the shared **`TENANT_RESOLVER`** (`ITenantResolver.resolveSlug` → tenant-service `/internal/tenants/by-slug/:slug`) — the SAME resolver SSO/OIDC uses. Unknown tenant → login throws generic `InvalidCredentials` (no leak; deliberately NOT dummy-hash timing-equalised because tenant existence is non-confidential — SSO/public subdomains already disclose it); reset → silent no-op.

**Why it exists — a gap #1636 left.** Epic #1589 / **PR #1636 (hostname tenant resolution)** made the FE resolve the tenant from the HOSTNAME and send the resolved **slug** in the login body (`SignInPage`: `login({ tenantId: tenantSlug })`; no more `?tenant=`/`'default'`), BUT added NO backend slug-resolution for the pre-auth path — so tenant-mode password login 500'd on main (slug → `findByEmail(email, slug)` → user-service 400 → unhandled 500 → gateway 502). #1636 likely shipped this because its e2e exercises SSO (already resolves slugs), not tenant-mode password login. **Closed by #1635 (squash `c45cb279`, 2026-07-03)** — login/reset DTOs relaxed `@IsUUID`→`@IsString`+`@IsNotEmpty`+`@MaxLength(255)`.

**Gotcha:** the Platform ValidationPipe is `ValidationPipe({ transform: true })` but **does NOT enforce DTO decorators at runtime** on auth endpoints (malformed body → 500, not 400) — likely an SWC `design:paramtypes` metatype gap. So `@IsUUID` never actually blocked the slug; the real fix is the controller resolver. (Filed as a separate follow-up — service-wide.)

**Follow-ups (spawned):** promote `ITenantResolver`/`TENANT_RESOLVER` from `modules/oidc/domain/ports` to a shared location (both PR reviewers flagged); confirm long-term ownership of pre-auth slug resolution with the #1589 identity team + add the missing tenant-mode-password-login e2e. See [[platform-identity-epic-prep]], [[platform-v2-design-setup-and-claude-distribution]]. Related: [[platform-local-sso-setup]] (its "FE `?tenant=freshco`" note is superseded — FE now host-derives the slug; backend accepts it in `tenantId`).
