---
name: platform-gateway-integration-suite-rots-undetected
description: Platform gateway's end-to-end integration specs manually instantiate cross-service use-cases and rot silently — they only run when gateway is in the nx `affected` set, which the gateway almost never is.
metadata:
  node_type: memory
  type: reference
  originSessionId: 00000000-0000-0000-0000-000000000009
---

**Gateway's e2e integration suite can be RED on `main` for a long time without anyone noticing.** `apps/platform/gateway/test/e2e/*.integration.spec.ts` (full-auth-flow, rbac-matrix, tenant-isolation) **manually instantiate** auth-service/user-service use-cases (`new LoginUseCase(...)`, `new UserEventConsumer(...)`, etc.) with in-memory test doubles — they do NOT use the services' real DI modules. So whenever an upstream **constructor signature changes**, these manual call-sites break, but the failure only surfaces when `platform-gateway` is in the nx **`affected`** set for some PR — and gateway is almost never affected (nothing most PRs change is imported by gateway), so its suite simply **doesn't run in CI**.

Concrete instance (2026-06-17): #1270 refactored `LoginUseCase` to delegate session minting to a new `SessionIssuer` (dropped session/refresh repos + token-generator + JwtService, added `SessionIssuer` + `EntityManager`). The gateway specs kept the old 11-arg call → `userServiceClient` landed in the wrong position → `this.userServiceClient.findByEmail is not a function` (15 failing tests). This stayed silently red on `main` from #1270's merge until #1314 added a method to `IUserRepository` that the gateway test-doubles implement, pulling gateway into THAT PR's affected set and exposing it. Fixed in #1315 (construct a real `SessionIssuer`, update both `LoginUseCase` call-sites to the 8-arg signature).

**How to apply:**

- When you change a constructor on any auth/user-service use-case or a port method on `IUserRepository`/`ISessionRepository`/etc., grep `apps/platform/gateway/test/e2e/` for manual `new <UseCase>(`/`implements I<Repo>` and update them — they will NOT be caught by CI unless gateway is affected.
- After ANY epic that touches auth/user/tenant services, run `nx test:unit platform-gateway --skip-nx-cache` once locally to catch silent rot; don't trust the green gate (gateway likely never ran).
- Durable fix (not yet done, flagged in #1315): give gateway a periodic full-suite run (cron/scheduled CI), OR replace the manual cross-service instantiation with the services' real DI modules. Related: [[platform-identity-epic-prep]], [[feedback_reproduce_ci_exact_env]].
