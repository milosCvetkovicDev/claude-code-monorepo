---
name: platform-frontend-axe-a11y-flake-main-red
description: Platform Pipeline was red on every main push (flaky MfaSetupPage axe timeout + HIGH-CVE deps) — RESOLVED by #1330 2026-06-18; kept as the diagnostic record
metadata:
  node_type: memory
  type: project
  originSessionId: 00000000-0000-0000-0000-000000000009
---

**RESOLVED by #1330 (`2f386b50`, merged 2026-06-18)** — "fix: unblock Platform image rebuild — 3 HIGH-CVE deps + platform-frontend axe testTimeout". Until then the **"Platform Pipeline"** workflow was `failure` on essentially every `main` push (6/6 consecutive runs 2026-06-18: f3693e4b/fbe55ea2/5c66f921/ce4379ad/0f2be250/a466f691) from two unrelated reds — a steady-state condition, NOT a per-PR regression, so don't assume your merge broke main when you see it red.

What was wrong + how #1330 fixed each:

1. **Flaky `platform-frontend:test`** — `apps/platform-frontend/src/pages/auth/__tests__/MfaSetupPage.spec.tsx > has no axe violations`. Root cause: `apps/platform-frontend/vite.config.mts` kept vitest's **5s default** and missed the workspace unit-mode **30s** bump (#1208); the jsdom axe-core scan takes ~9.8s under self-hosted-runner load → timeout. The same assertion passes 5× for sibling components (305–1036ms); only the heavy one flaked. Surfaces on main pushes because `nx-set-shas` reaches back to an old successful SHA, pulling platform-frontend into the affected set even when the PR didn't touch it (so it's invisible on the PR, only bites on the main push). **Fix: #1330 added `testTimeout: 30000` to vite.config.mts** (axe-core a11y class flake, same root as [[feedback_platform_auth_user_service_test_flaky]] / [[otel-js-dual-track-and-vitest-mock]] #1208 lineage, different project).
2. **Gateway-image Trivy** — distroless `nodejs22-debian12` base-image lag + bun.lock dep CVEs. **#1330 bumped the 3 HIGH-CVE deps** (package.json/package-lock) to unblock the image rebuild; remaining distroless-base entries stay in `.trivyignore`.

Diagnostic lesson that still holds: the **required merge gate is the legacy "CI" workflow** (`main` + `ci-gate` + helm-unittest), which was green throughout. "Is main healthy?" = check the **CI** workflow conclusion, not "Platform Pipeline". For a one-off flaky red, `gh run rerun --failed <run>` usually passes the axe test on retry.
