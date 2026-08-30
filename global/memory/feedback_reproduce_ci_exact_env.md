---
name: feedback_reproduce_ci_exact_env
description: "When a CI check fails but passes locally, reproduce CI's EXACT toolchain + checkout/dep state BEFORE diagnosing — local drift manufactures false greens and wrong root causes"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000035
---

When a CI check fails but passes locally, reproduce CI's **exact** environment BEFORE diagnosing — both the **tool version** and the **checkout/dependency state**. On #947/#950 (2026-05-27) I chased **three** wrong root causes for a `ci / helm-unittest` failure because local diverged from CI on two axes:

1. **Tool version:** local helm was **v4.1.3**; CI pins **helm v3.16.4** (`azure/setup-helm@…v5.0.0`, `version: v3.16.4` in `.github/workflows/_ci.yml`). I — and two independent code-review subagents — got false-greens on v4.
2. **Checkout / dep state:** local had `charts/bundles/*/charts/*.tgz` present (gitignored, left over from an earlier `helm dependency build`); CI's fresh checkout has none, and `_ci.yml` ran `helm unittest` WITHOUT `helm dependency build`. So CI rendered **zero subchart templates** → "template … not exists or not selected" — the ACTUAL cause, completely invisible locally.

**Why:** chasing local-only symptoms produced two plausible-but-wrong fixes (Rollout cutover, then a genuinely-stale SecretStore test) that would have shipped if the user's **watch-then-merge** gate hadn't caught the CI red. Verifying on the wrong env is worse than not verifying — it manufactures false confidence (and contaminates subagent reviews, which inherit your local env).

**How to apply:** For any "fails in CI, passes locally":
- Read the workflow for the **pinned tool version** (`azure/setup-helm version:`, `NODE_VERSION`, plugin `--version`) and install THAT exact version locally (download the pinned binary to `/tmp`, isolate plugins via `HELM_DATA_HOME`).
- Reproduce CI's **checkout/dep state**: `git check-ignore` the build artifacts; grep the workflow for a missing prep step (`helm dependency build`, `npm ci`, etc.); temporarily hide gitignored artifacts to simulate a fresh checkout.
- Only THEN diagnose. Fastest tell for this class: gitignored deps + a workflow that skips the build step.

The fix for #950 was a one-line `helm dependency build` in `_ci.yml`'s bundle loop (deps are `file://` → offline) + retargeting the stale SecretStore test. See [[platform-dev-deploy-recovery]].

**Related (helm-specific instance of this same principle, created in parallel by the sister session):** [[feedback_helm_version_mismatch_masks_failures]] — the concrete (helm v3.16.4 + unittest v0.7.2 + `helm dependency build`) reproduction recipe. This file is the general principle; that one is the helm instance. Consolidate if they drift.
