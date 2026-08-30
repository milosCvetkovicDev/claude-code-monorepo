---
name: platform-body-dto-import-type-disables-validation
description: "NestJS gotcha — `import type` on a @Body/@Query DTO silently disables the global ValidationPipe for that route"
metadata:
  node_type: memory
  type: reference
  originSessionId: 00000000-0000-0000-0000-000000000018
---

In Platform NestJS services (`emitDecoratorMetadata: true`), a controller that imports its
`@Body()` / `@Query()` DTO with **`import type { FooDto }`** silently disables the global
`ValidationPipe` for that route: `import type` erases the runtime class reference, so
`design:type` metadata becomes `Object`, and `ValidationPipe.toValidate(Object)` returns
false → **every class-validator decorator (`@IsNotEmpty`, `@MaxLength`, `@IsUUID`, …) is
dead**. A malformed/blank/over-long body reaches the use-case instead of 400ing.

**Fix:** value-import the DTO (`import { FooDto }`). Precedent both ways exists in-repo
(accounting-month/public-resolve value-import correctly; bank-account/exchange-rate/invoice
were `import type` → broken).

**Tests that MISS it:** validating the DTO class directly via `plainToInstance`+`validate`
(e.g. auth-service `test/dto-validation.spec.ts`), or calling the controller method directly
(e.g. `auth-controller-tenant-resolution.spec.ts`) — both bypass the pipe and pass while the
HTTP boundary is unguarded. **Only an HTTP-level test catches it:** Fastify `app.inject()` with
the real `ValidationPipe({transform:true})` + `AppExceptionFilter`, asserting a bad body → 400.
Template: `apps/platform/auth-service/test/tenant-slug-login.spec.ts`.

Found 2026-07-03 hardening #1635 pre-auth login (`LoginRequest`/`PasswordResetRequestDto`
were `import type`). Fixed in auth.controller (PR #1642). See [[platform-tenant-resolution-epic]],
`docs/adr/0069-pre-auth-tenant-slug-resolution.md`.

**Repo-wide audit ALREADY LANDED on main via #1640** (merged 2026-07-03, `7db59033`): value-import
fix across accounting `bank-account`/`exchange-rate`/`invoice` + auth `auth.controller`
(login/reset), `mfa.controller`, `oidc.controller`, with `validation-pipe-runtime.spec.ts` tests.
My parallel audit PR #1644 was a strict subset → **closed as dup**. LESSON: FF/rebase on origin/main
BEFORE starting a repo-wide audit — this exact fix had already merged (see [[feedback_audit_workflow_stale_worktree]]).
**Caveat on #1640:** it also armed the pipe on `OidcCallbackQuery` — auth `main.ts` leaves that query
un-whitelisted for use-case validation (conditional fields), so verify a real conditional callback
still validates. **Not this bug:** trading/commission request DTOs have ZERO validator decorators
(domain-layer validation), so value-import is a no-op — latent trap if validators are added later.
Durable guard = a lint rule forbidding `import type` on `@Body`/`@Query`/`@Param` DTOs (needs AST
import↔usage cross-check; recommended, not yet built).
