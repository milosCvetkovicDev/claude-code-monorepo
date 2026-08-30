---
name: platform-ui-test-blindfold-and-icu-casing
description: "platform-ui:test froze Platform image builds via an @nx/vite:test reporter blindfold hiding an ICU compact-casing flake — NOT cache poisoning (#1506 refuted)"
metadata:
  node_type: memory
  type: project
  originSessionId: 00000000-0000-0000-0000-000000000009
---

**Episode (2026-06-29, PR #1507, fixes #1370, refutes #1506).** `platform-ui:test` failed in CI with **exit 1 and ZERO output**, aborting the `ci/ci` job before the gateway image build → froze every Platform image build since #1500 (blocked the #1396 / epic #1265 deploy).

**Three proven facts (multi-agent + adversarially verified; cited from source):**

1. **The empty output is an executor blindfold, not the failure.** `@nx/vite:test` (→`@nx/vitest`) runs vitest with ONLY its silent internal `NxReporter` **unless `reporters` is set in the vitest config**, reporting success purely from `process.exitCode`. So platform-ui:test produced zero spec output **even when passing**. `platform-frontend` has `reporters:['default']` and streams. **Fix/lesson: when a vitest project on the @nx/vite:test executor fails with no output, add `reporters: ['default']` to its vitest.config FIRST to restore diagnosability — don't theorize (OOM/cache) blind.**

2. **The real bug = ICU compact-notation casing nondeterminism (the pre-existing #1370 flake).** `Intl.NumberFormat({notation:'compact'})` emits the en-GB thousands suffix as lowercase `k` on the CI runner's older ICU but uppercase `K` on dev's modern ICU. `KPITile` expected `£100.0K`, runner rendered `£100.0k`. Both `KPITile` and the shared `fmtGBP` (`libs/platform/ui/src/domain/formatters.ts`) formatted straight from `Intl`. **Durable fix:** `normalizeCompactCasing` in `libs/platform/ui/src/lib/format.ts` uppercases the single compact magnitude letter (k→K, m→M; bn/tn + plain numbers untouched), routed through both formatters → deterministic across Node/ICU. Prior team workaround (loosening `formatters.spec` to accept either case, #1398) was wrong — it leaves PROD rendering inconsistently per the deployed image's ICU.

3. **#1506 ("cache serves stale FAILED results") is REFUTED — mechanically impossible.** Nx 22.6.4 caches/PUTs only `code===0` tasks (`task-orchestrator.js:824-826`; `NX_CACHE_FAILURES` unset), ignores cached non-zero on read, and PRs hold a **read-only** token (Bun cache server 403s on write; `apps/nx-cache-server-bun`). In CI a cache hit shows `🔁 ...[remote cache]`; a fresh fail shows `❌` with NO tag. platform-ui:**build** was a `🔁` hit while platform-ui:**test** was always `❌` fresh (build's `production` named-input excludes vitest.config.ts; test's hash changed). **So `.github/ci-cache-version.txt` bumps and source "re-keys" are USELESS against a failing test — every affected run re-runs it fresh and re-fails. Don't chase cache theories for a re-failing test.**

Build-gate linkage: the failing step is `_ci.yml` "Test affected Platform libs (non-service)" (`nx affected -t test`, NX_PARALLEL=6), no continue-on-error, immediately before the gateway image build in the same job → its exit 1 reddens `platform-ci-gate` and skips `build-push`. See [[platform-identity-epic-prep]], [[platform-frontend-ui-adoption-epic]] (#1370), [[path-filtered-required-checks]].

**Downstream outcome (same day):** #1507 merged → main pipeline built gateway `sha-6b8cdad` (carries #1495 CORS soft-reject ADR-0058 + #1503 @acme/config) → deployed to dev via charts bump PR #1512 (`charts/values/gateway.yaml`, ArgoCD `platform-gateway` auto-sync). **#1396 login VERIFIED live on dev**: dev-origin `POST /api/v1/auth/login` flipped `500 CORS_REJECTED` → `200` + TOTP MFA challenge (valid seed creds `admin@freshco.test`); unlisted origin soft-rejects (no ACAO header, not 403/500). #1506 + #1370 CLOSED. #1396/epic #1265 still OPEN pending operator/human Steps 3 (DNS Terraform adoption #1502) + 5 (A5/A6 sign-offs). Minor non-blocking follow-up: auth-service 500s (gateway 502) on an EMPTY `{}` login body (should 400) — only reachable now CORS no longer blocks first.
