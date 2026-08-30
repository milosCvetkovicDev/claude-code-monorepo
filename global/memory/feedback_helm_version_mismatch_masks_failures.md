---
name: helm-version-mismatch-masks-failures
description: "Local helm v4 vs CI helm v3.16.4 silently mask both real failures and bad fixes during helm-unittest debugging. Always reproduce CI's exact (helm-version, unittest-plugin-version) tuple before propagating any helm-chart diagnosis or fix."
metadata:
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000008
---

## TL;DR

**Human-engineer runbook** with the canonical reproduction recipe + worked example: [`docs/runbooks/cicd/debugging-ci-failures-that-pass-locally.md`](../../../../projects/acme/docs/runbooks/cicd/debugging-ci-failures-that-pass-locally.md) (merged via PR #952, squash `1d4e5880`). The runbook generalises this lesson to "two axes of CI-local drift" (tool version + checkout/dependency state) and includes the isolated-helm-v3-install recipe. **If you're an AI session that fetched this memory, also read that runbook** — it has the shell commands you'll want to suggest to the user.

When debugging `ci / helm-unittest` failures (or any chart-render failure), **the local helm binary's version matters more than the test assertion text**. CI pins helm v3.16.4 + helm-unittest v0.7.2. If your `helm` is v4 (homebrew default), you can verify-and-be-wrong twice:

1. **False-fail on local that masks the real issue.** v3 and v4 differ in subchart-dependency handling — v3 requires `helm dependency build` from a `Chart.lock` before tests can render umbrella charts; v4 may auto-fetch or be more permissive. Tests that pass locally on v4 fail on CI v3 with "template not exists or not selected" when the `.tgz` subchart archives are absent (they're gitignored at `charts/bundles/*/charts/*.tgz`, so a fresh CI checkout has zero deps until `helm dependency build` runs).

2. **False-green on local that masks a bad fix.** A test edit that looks fine when rendered on local v4 still fails on CI v3 because v3 processes templates with different default values / inheritance semantics. This burned PR #947's initial diagnosis cycle twice — first attributing the failure to PR #880's Rollout default switch (verified-green-on-v4, still red on CI), then to PR #752's ClusterSecretStore default (also v4-green-while-CI-red), before sister rendered the chart against CI's exact env and discovered the actual cause was missing `helm dependency build` in `_ci.yml`.

## How to apply

> **Canonical recipe lives in the runbook** at [`docs/runbooks/cicd/debugging-ci-failures-that-pass-locally.md`](../../../../projects/acme/docs/runbooks/cicd/debugging-ci-failures-that-pass-locally.md). The recipe below is the AI-session quick version; the runbook has the isolated `HELM_DATA_HOME` + `HELM_PLUGINS` install pattern that keeps v3 plugins separate from a v4 global, and the `git check-ignore -v` step for confirming an artifact is gitignored before assuming it's missing in CI.

**Before any helm-unittest diagnosis or PR review:**

```bash
helm version --short                                  # check your local version
brew install helm@3                                   # if you need v3 alongside v4
PATH=/opt/homebrew/opt/helm@3/bin:$PATH helm version  # use v3 explicitly
# OR specifically v3.16.4 via tarball install if available; check `charts/Chart.yaml` for chart api compat
```

Match CI's pin (currently `azure/setup-helm@dda3372f752e03dde6b3237bc9431cdc2f7a02a2 # v5.0.0` with `version: v3.16.4` in `.github/workflows/_ci.yml`'s `helm-unittest` job).

**The bundle-render reproduction recipe** that should be run FIRST when any `01-render-defaults` / `03-per-service-primitives` test fails:

```bash
helm version --short  # confirm v3.16.4
helm plugin install https://github.com/helm-unittest/helm-unittest --version v0.7.2
cd $PROJECT_ROOT  # or any clean checkout
helm dependency build charts/bundles/identity-bundle  # CRITICAL — subchart .tgz are gitignored
helm unittest charts/bundles/identity-bundle
```

If the test passes here but fails in CI, the bug is upstream of helm — usually `_ci.yml`'s loop is missing a setup step. If the test fails here too, then the test or the chart is at fault.

## Acme-specific notes

- **`charts/bundles/*/charts/*.tgz` is gitignored** (see top of `.gitignore`). The `Chart.lock` is committed, so `helm dependency build` is deterministic and offline (`file://` deps under `repository:` in each bundle's `Chart.yaml`). CI's `_ci.yml` `helm-unittest` job runs `helm dependency build "charts/bundles/${bundle}-bundle"` immediately before `helm unittest` for each bundle, after PR #950 (`05f9347f`). Don't remove that step.
- helm-unittest plugin pin: `v0.7.2` (per `_ci.yml` install step). Don't bump without re-validating all bundle test files — [[feedback_helm_unittest_v072_syntax]] catalogues v0.7.2 syntax constraints.
- The chart-render path includes target-defaults from `nx.json`-equivalent helm sources (helmfile, etc. if any). When asserting `.targets[...]` for unit-test inclusion, prefer `helm show values --skip-tests` or `nx show project --json` rather than direct `jq` on `project.json`/`values.yaml` — see PR #951 for the bootstrap-harness guard pattern.

## Indexed history

- PR #947's first diagnosis (Rollout default switch from #880) was wrong; verified-on-v4 mismatch with CI v3
- PR #947's second diagnosis (ClusterSecretStore default from #752) was correct but PARTIAL; the real CI failure was that subchart `.tgz` files weren't built — only surfaced when sister reproduced on helm v3.16.4
- PR #950 landed both: ClusterSecretStore test edit + `helm dependency build` step
- PR #952 (merged 2026-05-27, squash `1d4e5880`) landed the human-engineer runbook at `docs/runbooks/cicd/debugging-ci-failures-that-pass-locally.md` + a pointer entry in `troubleshooting.md`

## Related

- [[feedback_helm_unittest_v072_syntax]] — syntax-side companion to this version-side lesson
- [`docs/runbooks/cicd/debugging-ci-failures-that-pass-locally.md`](../../../../projects/acme/docs/runbooks/cicd/debugging-ci-failures-that-pass-locally.md) — runbook for humans; covers both tool-version AND checkout-state axes of CI-local drift
- [`docs/runbooks/cicd/troubleshooting.md`](../../../../projects/acme/docs/runbooks/cicd/troubleshooting.md) — general CI/CD troubleshooting (has a one-line pointer to the runbook above)
