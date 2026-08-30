---
name: platform-import-type-disables-validationpipe
description: "Platform controllers importing @Body/@Query DTOs via `import type` silently disable the global ValidationPipe (metatype→Object); strict whitelist pipe makes it load-bearing"
metadata:
  node_type: memory
  type: project
  originSessionId: 00000000-0000-0000-0000-000000000062
---

Platform-wide Platform bug (found via auth PR #1635). A controller that imports its
`@Body()`/`@Query()`/`@Param()` DTO with **`import type { XDto }`** silently disables
runtime validation: the type-only import is elided from compiled JS, so the param's
`design:paramtypes` metatype degrades to `Object`, and NestJS `ValidationPipe.toValidate()`
skips any `Object` metatype. Malformed input reaches the domain (unhandled 500, or silently
accepted). **NOT** an SWC-config issue — `.swcrc` already has `decoratorMetadata: true`.
Fix = value import (`import { XDto }`); split mixed lines, keep response types as
`import type`. ESLint `consistent-type-imports` is NOT configured, so value imports stick.

**18 controllers / 5 services** affected. Two classes:

- **Safe fix (DTOs already class-validator-decorated + auth uses lenient `transform`-only
  pipe):** auth-service (auth/mfa/oidc) + accounting-service (bank-account/exchange-rate/
  invoice) — **FIXED + shipped** with runtime guards (`test/validation-pipe-runtime.spec.ts`
  in each; RED→GREEN proven).
- **Epic (deferred) = issue #1639:** tenant/trading/commission/user — their ~20 DTOs have
  **zero class-validator decorators** (Swagger-only) AND run the **strict**
  `whitelist+forbidNonWhitelisted` pipe. So the `import type` bug is _load-bearing_: a naive
  flip would strip/400 every write request. Fixing = authoring validators for ~150 fields
  (per-endpoint tests + a human acceptance pass). **user-service + gateway register NO pipe** (no
  `APP_PIPE`) → flip is a no-op there until a pipe is added. Handoff doc written this session.

Gotchas when writing the runtime guard test: guards (`GatewayIdentityGuard`/`PermissionsGuard`
via `@Require*Permission`) run BEFORE pipes → override them or the malformed request 401s
before reaching the pipe. The vitest `unplugin-swc` transform matches the prod `.swcrc`
(both `decoratorMetadata:true`), so a `Test.createTestingModule` + Fastify `inject` test
faithfully reproduces prod — no harness divergence. OIDC callback exemption preserved:
`OidcCallbackQuery` is all-`@IsOptional`, main.ts keeps `whitelist`/`forbidNonWhitelisted`
off. See [[platform-commission-epic]], [[platform-trading-hardening-epic]], [[platform-tenant-resolution-epic]].
