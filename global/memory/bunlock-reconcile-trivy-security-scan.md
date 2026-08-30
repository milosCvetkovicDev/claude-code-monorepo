---
name: bunlock-reconcile-trivy-security-scan
description: How to reconcile the stale root bun.lock with package-lock to clear bun.lock-only HIGH CVEs in the Trivy Security Scan — the regen quirks bun has
metadata:
  node_type: memory
  type: reference
  originSessionId: 00000000-0000-0000-0000-000000000009
---

The informational **Security Scan** workflow (`.github/workflows/security-scan.yml`, Trivy `fs` of `.`, HIGH/CRITICAL, `--ignore-unfixed`, `--ignorefile .trivyignore`, exit-code 1) periodically goes red on CVEs that exist **only in the root `bun.lock`**. Root cause: npm `overrides` in `package.json` propagate to `package-lock.json` but **NOT to `bun.lock`** — bun.lock only updates when someone runs `bun install` and commits it, and no CI step regenerates it (the `.trivyignore` "will resolve in CI" comments were aspirational). So bun.lock drifts stale and Trivy flags its old transitive copies (the npm/bun Trivy parsers also differ on dev-dep scoping, so a version flagged in bun.lock may be silent in package-lock).

**The fix = regenerate bun.lock so the existing overrides + dep ranges apply.** Procedure (done in PR #1333, 2026-06-19):

1. Worktree off `origin/main`; `bun --version` (had 1.3.12).
2. `bun install --ignore-scripts` — **MUST use `--ignore-scripts`**: a plain `bun install` crashes on `drizzle-kit`'s nested `esbuild` postinstall ("Expected 0.25.12 but got 0.27.5") and never writes the lockfile. `--ignore-scripts` only skips lifecycle scripts; lockfile _resolution_ is identical and safe to commit (the Dockerfiles' `bun install --production` runs their own scripts in a clean container).
3. This applies every pending override (e.g. it bumped axios 1.15.0→1.18.0, which had been _violating_ the `^1.17.0` override floor) + direct-range fixes — broader than just the flagged CVEs; that IS the reconciliation.
4. For a CVE where the package is vulnerable in **both** lockfiles (not just stale) — e.g. form-data 4.0.5 (fix 4.0.6) — add a **new** `overrides` entry and regen **both** lockfiles (`bun install --ignore-scripts` + `npm install --package-lock-only --ignore-scripts`).

**bun override limitations (learned the hard way):** bun honors ONLY plain package-name override keys. It **ignores nested overrides** (`"@angular-devkit/core": { "ajv": ... }`) and **version-scoped keys** (`"form-data@^4.0.0": "..."` is silently not applied) — both print/behave as no-ops. So a global `"form-data": "^4.0.6"` was required (it also force-bumps the legacy `@azure/core-http` 3.x path to 4.x; form-data v4 is API-compatible with its multipart use on Node 22). `bun update <transitive>` is the WRONG tool — it adds the pkg to package.json deps and doesn't dedupe the transitive copies.

**Verify with REAL Trivy via Docker** (local `trivy` not installed; `aquasec/trivy:0.58.0` tag failed to pull, use `:latest`), mounting a cache volume; do NOT prefix with `timeout` (absent on macOS → exit 127):
`docker run --rm -v "$PWD":/work:ro -v trivy-cache:/root/.cache/ aquasec/trivy:latest fs --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --ignorefile /work/.trivyignore --skip-dirs '**/node_modules' --exit-code 1 /work` → expect 0 across bun.lock + all package-lock.json. Also run `bun install --frozen-lockfile --ignore-scripts` ("no changes" = lock matches package.json).

**Cleanup:** when the regen resolves a CVE that `.trivyignore` was suppressing as "bun.lock only," REMOVE that entry (the file's own policy). For a newly-disclosed advisory you can't safely fix (e.g. nodemailer GHSA-p6gq-j5cr-w38f — transitive of the `preview-email` DEV tool, `mailparser` pins it exactly 7.0.13, fix 9.0.1 is a 2-major bump, vuln `raw`-send path unused) → document in `.trivyignore` instead of forcing the bump. See [[platform-frontend-axe-a11y-flake-main-red]] (the other half of the Platform-Pipeline/Security-Scan red), [[otel-js-dual-track-and-vitest-mock]] (@grpc bun.lock lag precedent).
