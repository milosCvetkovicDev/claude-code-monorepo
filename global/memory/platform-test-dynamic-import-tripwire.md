---
name: platform-test-dynamic-import-tripwire
description: 'Platform test dynamic-import of a @acme/* lib reddens "ESLint Security Rules" by forbidding that lib''s static importers (app.module)'
metadata:
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000016
---

**Never `await import('@acme/<lib>')` (dynamic import) in a Platform service test.** `@nx/enforce-module-boundaries` then classifies that lib as _lazy-loaded_ and fires **"Static imports of lazy-loaded libraries are forbidden"** on every file that STATICALLY imports it — typically `app.module.ts` (e.g. `import { AppExceptionFilter } from '@acme/service-bootstrap'`). The error points at the _static_ line (a pre-existing, main-green import you didn't touch), which is misleading — the real cause is your test's dynamic import. Fix: use a **static top-level import** in the test (mount the module via the statically-imported symbol).

**Why:** the rule reads the Nx **project graph**, which records dynamic-import edges project-wide — so a dynamic import in `test/**` taints `src/**` static importers even though the lint target only globs `src/**`.

**How to apply:**

- In Platform tests, statically import modules/providers (`import { ProxyModule } from '../src/...'`, `import { AppExceptionFilter } from '@acme/service-bootstrap'`), never `await import()` of a `@acme/*` package.
- The check is `nx lint <project>` run **fresh** by `security-scan.yml` → surfaces as the **"ESLint Security Rules"** check (informational, not a required gate, but fix it). The `ci`/`ci-gate` lint is **nx-cached** and can pass stale-green on the same violation — so a green `ci-gate` does NOT mean lint is clean. Reproduce with `nx lint <project> --skip-nx-cache`.
- After editing dynamic imports, run **`nx reset`** before re-linting — the project graph caches the old edge and yields a stale false-positive otherwise.
- Hit + fixed on #1254 / PR #1341 (2026-06-19). Relates to [[feedback_reproduce_ci_exact_env]], [[platform-gateway-crossservice-spec-typecheck-gap]].

**Sibling gotcha — root-package.json PRs fan out to ALL projects:** any Platform PR that edits the root `package.json` (e.g. promoting a dep like undici to prod) invalidates the global Nx input, so `ci/ci` + `main` run **`nx affected` across all ~40 projects** instead of just the changed one. That drags in the platform's known load-sensitive flakes — **`platform-event-bus:test`** (amqplib timing/reconnect resilience suite) and the **"Failed to start plugin worker"** nx-daemon spawn flake — which red the required `ci-gate`/`platform-ci-gate`. These are NOT your code: confirm by running the named project locally (`nx run <proj>:test --skip-nx-cache` → passes) then **re-run the failed CI job** (`gh run rerun <runId> --failed`); a flake lands on a different load-lottery project each run. Don't re-diagnose, re-run. Beware: back-to-back `gh run rerun` on overlapping runs can `CANCELLED` an in-flight job (concurrency) — re-run once, singly. See [[feedback_platform_auth_user_service_test_flaky]], [[dev-runner-vm-topology-and-fallback-oom]].

**Dep hygiene:** a package imported directly in source MUST be a declared dep. undici was dev-only (transitive via testcontainers, `dev:true`) → absent from the Dockerfile `npm ci --omit=dev` image → runtime crash. And pin to the CVE-clean version: undici **≥7.28.0** (7.24.6 = CVE-2026-9697 HIGH, SOCKS5/TLS MitM) or deploy-time Trivy hard-gate blocks the image.
