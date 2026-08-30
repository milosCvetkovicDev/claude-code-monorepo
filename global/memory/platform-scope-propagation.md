---
name: platform-scope-propagation
description: How SUPERADMIN platform-scope (ADR-0029) reaches BC services — the two-part fix for "Platform access required"/403 on every /api/v1/platform/* route (2026-07-20)
metadata:
  node_type: memory
  type: reference
  originSessionId: 00000000-0000-0000-0000-000000000009
---

**SUPERADMIN `/api/v1/platform/*` routes were 403 for EVERYONE** (the Create-Tenant wizard's
"Platform access required" panel; also `/platform/users`). It was a TWO-PART bug, both halves
hidden by mocked tests, fixed + deployed 2026-07-20 (PRs #1746 propagation, #1748 guard-wiring;
gateway `sha-56d6cad`, tenant/user `sha-e8c1500`). Verified live via header-identity smoke:
SUPERADMIN+`x-platform-scope:true` → **200**; no-identity → 401; no-scope → 403; ADMIN+scope → 403.

**Part 1 — the claim was validated at the gateway but NEVER propagated to BC services (#1746).**
`auth-service` issues `platformScope:true` in SUPERADMIN JWTs (`isSuperAdmin ? {platformScope:true}:{}`);
the gateway validated it in-process but forwarded NOTHING. Fix = complete the `x-platform-scope`
header propagation, docs-aligned with ADR-0029 (added an impl note there):

- `@acme/auth-client` `GatewayIdentityGuard` reads `x-platform-scope === 'true'` → `user.platformScope` (strict).
- gateway `JwtValidationGuard` sets `x-platform-scope:'true'` from the verified JWT claim.
- gateway ingress strip-hook (`GATEWAY_INJECTED_HEADERS`) strips any client copy (forge prevention —
  same class as `x-super-admin`; the claim bypasses the MikroORM tenant filter).
- `@acme/platform-contracts` `GATEWAY_HEADERS.PLATFORM_SCOPE = 'x-platform-scope'`.
- **Egress route-scope (security-critical):** forward `x-platform-scope` ONLY for a route whose registry
  entry is flagged `ServiceRoute.platformScope:true` (the two `/api/v1/platform/*` entries). Gate off
  the ALREADY-RESOLVED `route` object, NOT a re-parsed `req.path` — else a double-encoded traversal
  (`%252e%252e`) that `resolveService` routes to a business service but `isPlatformRoute(req.path)`
  re-normalises to a platform path LEAKS the cross-tenant header (security-auditor caught this as HIGH;
  `resolveService` decodes 0×, WHATWG `new URL().pathname` decodes/collapses — they diverge). It is
  deliberately NOT in `IDENTITY_HEADERS`/`FORWARDABLE_REQUEST_HEADERS`. `StripPlatformScopeMiddleware`
  is a NO-OP for the header (NestJS middleware runs BEFORE the guard that sets it) — belt-and-suspenders only.

**Part 2 — the platform controllers didn't RUN GatewayIdentityGuard (#1748).** `platform-tenant.controller`

- `platform-user.controller` used `@UseGuards(PlatformScopeGuard)` with NO `GatewayIdentityGuard` — but
  that guard (`libs/platform/auth-client/.../gateway-identity.guard.ts:88`) is the ONLY code that builds
  `request.user` from the headers. Without it `request.user` is undefined → `PlatformScopeGuard`'s
  `if(!user) throw` 403s regardless of the (now-delivered) claim. Discriminator: a platform request with
  NO `x-user-id` returned 403 (not the 401 GatewayIdentityGuard raises) = the identity guard never ran.
  Fix = `@UseGuards(GatewayIdentityGuard, PlatformScopeGuard)` (identity FIRST) on both.

**META (recurring Platform failure mode):** the platform specs inject `request.user` directly, so BOTH
gaps were invisible to green tests — same "green-vs-mocks, broken-vs-real-wire" class as the
tenant-provisioning epic. Guard against it with a **guard-chain metadata regression test**
(`Reflect.getMetadata('__guards__', Controller)` toEqual `[GatewayIdentityGuard, PlatformScopeGuard]`)
and a real header-identity smoke, NOT a mocked controller call. Relates to
[[platform-gateway-trust-unsigned-headers]] (headers unsigned, NetworkPolicy-trusted; signing = #1443/#1669),
[[platform-import-type-disables-validationpipe]], [[platform-tenant-provisioning-epic]].

**Model note (ADR-0029 vs feature doc):** SUPERADMIN JWTs have a `tenantId` (home tenant, `DEV_BOOTSTRAP.TENANT_ID`
for the dev seed) PLUS `platformScope:true` — NOT `tenantId=null` (user.md:665 says null; the CODE follows
ADR-0029, tenantId present). Dev SUPERADMINs (seeded by `admin-bootstrap.seed.ts` from `DEV_SUPERADMINS`)
are seeded on `DEV_BOOTSTRAP.TENANT_ID`, so a TENANT's `/admin/users` page (tenant-scoped `findAll(tenantId)`)
correctly shows "No users" for a fresh tenant — SUPERADMINs are platform-scoped, not tenant users (expected, not a bug).
