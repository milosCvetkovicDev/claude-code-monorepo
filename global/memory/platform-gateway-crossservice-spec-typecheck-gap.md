---
name: platform-gateway-crossservice-spec-typecheck-gap
description: Platform gateway cross-service specs must live in test/e2e (vitest-only @platform/* alias breaks tsc); run typecheck before claiming a Platform PR green
metadata:
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000009
---

A vitest spec under `apps/platform/gateway/src/**` that imports another service via the
`@platform/auth-service/*` (or `@platform/user-service/*`, `@platform/tenant-service/*`) alias
will PASS `nx test:unit` but FAIL `nx typecheck` with TS2307 — that alias is defined
ONLY in `apps/platform/gateway/vitest.config.ts`, NOT as a `tsconfig.base.json` path
mapping. The gateway `typecheck` target runs `tsc --noEmit -p tsconfig.json` whose
`include: ["src/**/*.ts"]` / `exclude: [..., "test"]` typechecks src specs but skips
`test/`. CI's `nx affected -t typecheck` (inside `ci / ci` → `platform-ci-gate`) then goes
RED while `vitest run` stays green locally, masking it.

**Rule:** cross-service gateway specs go in `apps/platform/gateway/test/e2e/` (alongside
`full-auth-flow.integration.spec.ts`), importing the gateway's own modules via
`../../src/modules/...`. The vitest factory (`definePlatformServiceVitestConfig`, unit mode)
includes `test/**/*.spec.ts`, so they still run under `test:unit`.

**Why:** I shipped #1322's RS256 round-trip spec under `src/__tests__/`; test+lint were
green so I called it done, but expert review (and `nx typecheck platform-gateway`) caught
the TS2307. **Before claiming any Platform PR green, run `typecheck` too — not just
`test:unit` + `lint`.** The `@nx/vite:test` reporter is also opaque on failure (no
"Test Files" summary); re-run with `-- --reporter=verbose` to see which test failed.

How to apply: when adding a gateway spec that imports another BC, put it in
`test/e2e/`; always include `nx typecheck <project>` in pre-push verification for Platform
services. See [[feedback_reproduce_ci_exact_env]], [[platform-gateway-integration-suite-rots-undetected]].
