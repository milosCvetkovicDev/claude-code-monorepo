---
name: sonarqube-local-scan
description: Gotchas for running the local SonarQube scan (/sonar-scan skill) on the acme Platform code
metadata:
  node_type: memory
  type: project
  originSessionId: 00000000-0000-0000-0000-000000000029
---

Local SonarQube scan (`/sonar-scan` skill, `docker-compose.platform.yml` `tools` profile, `sonar-project.properties`, scope = `apps/platform`+`libs/platform`). Established 2026-06-08 (branch `chore/sonarqube`, PR from commit a7f8a03c).

**Start it:** `docker compose -f docker-compose.platform.yml --env-file /dev/null --profile tools up -d sonarqube`. The `--env-file /dev/null` is REQUIRED — the repo `.env` line 58 (`someone@initech.example = <REDACTED-PASSWORD>`) is a malformed var name that breaks docker-compose env parsing. SonarQube only needs `PLATFORM_SONAR_PORT` (defaults 9000), so bypassing `.env` is safe. Fresh `admin/admin` works for API + token mint immediately.

**Run scanner** (no node_modules needed): `docker run --rm -e SONAR_HOST_URL=http://host.docker.internal:9000 -e SONAR_TOKEN=<tok> -v $PWD:/usr/src sonarsource/sonar-scanner-cli`.

**Type-aware analysis is the big lever.** Without `sonar.typescript.tsconfigPaths`, SonarJS runs TYPE-BLIND and emits false positives — notably S4325 on `require('x') as typeof import('x')` (can't see require()→any) and S3735 `void`. Set `sonar.typescript.tsconfigPaths=apps/platform/**/tsconfig.json,libs/platform/**/tsconfig.json` + `sonar.javascript.node.maxspace=4096`. That alone cleared 18 FP smells (134→116). Project eslint is NOT type-aware (no `parserOptions.project`), so you can't cross-check with `@typescript-eslint/no-unnecessary-type-assertion` via normal lint.

**Exclude `migrations/**`and`benchmarks/**`/`\*.bench.ts`** (mirror the eslint exclusions): S101 fires on `Migration_NNN_*` class names — NEVER rename them (MikroORM tracks migrations by class name). Benchmarks carry a HIGH "hardcoded credential" FP (a bench test password). Verify de-cast safety: `noUnusedLocals:true` means typecheck catches orphaned imports; type assertions are compile-erased so runtime is identical (no test regression possible). Per-project `nx run <proj>:typecheck` bypasses the workspace TS-reference `sync` gate that blocks `nx affected`.

**Quality gate (Sonar way) = ERROR is usually just coverage.** Only failing condition is `new_coverage>=80%` at 0% because no lcov is uploaded; new-code period baselines at the FIRST scan, so subsequent edits become "new code" with 0 coverage. All quality conditions (rel/sec/maint/dup on new code) pass. To green it (done 2026-06-08, new_coverage 0→91%): (1) `nx run-many -t test:unit --coverage` for apps (lcov → `coverage/apps/platform/<svc>` via the shared `definePlatformServiceVitestConfig`); (2) **libs (event-bus, service-bootstrap) have BESPOKE vitest configs with NO coverage block** — add one (`provider:'v8'`, `reporter:['text','lcov']`, `reportsDirectory: coverage/libs/platform/<lib>`) or their lcov never reaches the glob and well-tested code reads as 0% (outbox-reaper was 99% but invisible); (3) `sonar.coverage.exclusions=**/testing/**,**/*.bench.ts` so test-support scaffolding (bootstrap harness, exercised only by testcontainer suites) doesn't drag the bar. lcov glob = `coverage/apps/platform/*/lcov.info,coverage/libs/platform/*/lcov.info`. SonarQube `new_uncovered_lines` per file counts ONLY changed lines that are uncovered (not the whole file) — target tests at those; `fromTrusted` reconstitution factories + entity `updateContent` optional-field paths were the untested de-cast carriers.

Related: [[feedback_fix_source_not_alert]] (fix the scanner config, don't rename migrations), [[mikroorm-v6-filter-disable-syntax]].
