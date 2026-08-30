---
name: arc-rbac-supplement-missing-list
description: "Upstream gha-runner-scale-set-controller v0.10.0 chart grants the controller SA `create/delete/get/patch/update` on secrets but NOT `list`; EphemeralRunner finalizer cleanup needs `list`, stuck CRs accumulate"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000008
---

The `gha-runner-scale-set-controller` Helm subchart (v0.10.0) creates a
dynamic `arc-gha-rs-controller-listener` Role in the controller's release
namespace with this rule on `secrets`:

```
verbs: [create, delete, get, patch, update]
```

The verb `list` (and `watch`) are NOT included. This is an upstream chart
omission — the controller binary's
`cleanupContainerHooksResources` (in `ephemeralrunner_controller.go`) calls
`client.List` on secrets with a label selector to enumerate runner-linked
secrets during EphemeralRunner finalizer execution. Without `list`, the
finalizer logs the same error on every reconcile and never completes.

**Symptom on dev-acme-aks (discovered 2026-05-26):**

- Controller log floods every ~10 s with: `Failed to clean up container
  hooks resources: failed to list runner-linked secrets: secrets is
  forbidden ... cannot list resource "secrets"`.
- EphemeralRunner CRs whose pods have already completed accumulate in
  Phase=Running with `deletionTimestamp` set and finalizer
  `ephemeralrunner.actions.github.com/finalizer` stuck. 13+ orphan CRs since
  2026-05-22 on a 4-day-old install.
- 7 EphemeralRunnerSets for 3 logical scale-sets — old ERSes don't GC
  because their ER children never finalize.
- Pods themselves are cleaned up by kubelet, so AKS node footprint is
  unaffected, but K8s API churn + controller noise grows over time.

**Why:** Found while investigating PR #939 ci-v2.yml validation failures.
The validation failures themselves were the unrelated 2026-05-26 10:57Z
"Incident with Actions and Pages" (auth subsystem) outage on GitHub
Actions — codeload 404s, git-clone 403s, every workflow run after 12:19Z
failed regardless of runner class. The ARC bookkeeping debt was the
incidental finding while ruling out ARC as the failure cause.

**How to apply:**

- The acme repo already has a chart `charts/arc/templates/arc-controller-
  rbac-supplement.yaml` whose sole purpose is to fill upstream RBAC gaps.
  Add a `secrets` rule with `list, watch` verbs to its Role (no need to
  duplicate the existing 5 verbs — RBAC is additive).
- DO NOT edit the dynamically created `arc-gha-rs-controller-listener`
  Role with kubectl — the controller recreates it on reconcile from
  hardcoded verbs in the upstream binary.
- Upstream gap may go away with future
  `gha-runner-scale-set-controller` chart bumps; re-check
  `manager_cluster_role.yaml` and `manager_single_namespace_controller_role.yaml`
  in the subchart at each version upgrade.

[[feedback_gha_npm_ci_heartbeat_timeout]] is a separate ARC-side finding
from the same investigation session (npm ci silent-cold-cache → heartbeat
kill).

**Tracking**:
- Upstream: [actions/actions-runner-controller#4510](https://github.com/actions/actions-runner-controller/issues/4510) — filed 2026-05-26, documents code-vs-chart-Role mismatch versus ADR-2023-04-11.
- Downstream issue: #945 (closed by merge).
- Downstream PR: #946 — MERGED 2026-05-26 14:12Z as squash commit `7314dc28` on main. Two commits: initial fix + review-panel-fix follow-up (added 12-case helm-unittest suite, dropped `watch` verb, added upstream-tracking marker, reworded "no privilege escalation" framing to "scope-narrow privilege expansion").

**Final shipped verbs** on secrets in supplement Role: `[list]` only. `watch` was deliberately dropped — the upstream `cleanupRunnerLinkedSecrets` code path uses one-shot `client.List`, not an informer.

**Retire-when**: upstream chart `gha-runner-scale-set-controller` >= the version that absorbs #4510. Check `manager_listener_role.yaml` in the subchart at each version bump.

**Cluster verification (2026-05-26)**:
- ArgoCD synced `arc` app to `7314dc28` at 14:27:08Z; Role gained `secrets: [list]` rule immediately.
- 62 → 20 orphan CRs drained on first reconcile pass (~30s).
- 17 historical orphans from 2026-05-22 → 2026-05-26 remained stuck in finalizer-backoff after the Role landed — controller workqueue had parked them on long retry intervals after 4 days of failures. Fix: `kubectl rollout restart deploy/arc-gha-rs-controller -n arc-system`. Forces fresh list/watch, re-queues all CRs with default backoff.
- After restart: 17 → 0 stuck CRs within ~30s. EphemeralRunnerSets 7 → 3 (only the live scale-sets remain). Controller cleanup-error log floods stopped entirely.

**Cleanup-pattern note**: when fixing finalizer-stall RBAC bugs, expect a controller pod restart to be needed in addition to the chart sync if the workqueue has accumulated stale-state items beyond default backoff (~minutes). Don't promise "auto-recovery on next reconcile" without verifying workqueue freshness.

**UPDATE 2026-05-29 — refined root cause (maintainer pushback on #4510):** ARC maintainer `nikola-jokic` replied (comment 4555485130) DISPUTING the "upstream chart omission" framing: the controller lists secrets only namespace-scoped (no ADR violation), and that access is supposed to come from the **`gha-runner-scale-set` (runner-set) chart's manager Role** in the target namespace — he asked how we hit the stuck state. **Verified root cause:** our `charts/arc/Chart.yaml` depends ONLY on `gha-runner-scale-set-controller` (the controller chart); we declare the 3 `AutoscalingRunnerSet` as **raw CRs** (`charts/arc/templates/runner-scale-set-*.yaml`), NOT via the `gha-runner-scale-set` runner-set chart. So the runner-set chart's manager Role (which carries the `list` secrets grant + finalizer) is never created — the only namespace secrets Role bound to the controller SA is the controller-dynamically-created `...-listener` Role (5 verbs, no `list`). So it's **not (necessarily) an upstream bug** — it's that our GitOps direct-CR pattern bypasses the chart that would provision the manager Role. Our supplement is still a valid mitigation (namespace-correct: everything is in single ns `arc-system`). **Open question to maintainer (reply drafted 2026-05-29, awaiting post):** is direct-CR deployment supported? If yes → either the controller-created listener Role should include `list`, or docs must tell direct-CR users to provision it. If no → switch to driving each scale set through the `gha-runner-scale-set` chart. **Importance: MEDIUM** — we're mitigated (not blocking); matters for charts/arc correctness-by-design + closing the upstream loop. Separate layer from the 2026-05-29 ci-v2 `/cache`-mount failure ([[dev-runner-vm-topology-and-fallback-oom]] is yet another layer).

**FINAL RESOLUTION 2026-06-01 (maintainer comment 4592867609) — direct-CR pattern is UNSUPPORTED; upstream will NOT fix.** nikola-jokic: *"The only installation method supported is through helm. With helm, we apply necessary resources during installation… So the installation method you use is not really supported."* So #4510 is resolved-as-unsupported (close as not-planned). **Verified definitively** by fetching the upstream `gha-runner-scale-set/templates/manager_role.yaml` (v0.10.0): it grants the controller SA, in the runner-set namespace, `secrets: create/delete/get/`**`list`**`/patch/update` + `serviceaccounts:…/list/…` + `pods` + `pods/status` + `roles`/`rolebindings: create/delete/get/patch/update` + `configmaps:get` (if githubServerTLS), PLUS an `actions.github.com/cleanup-protection` finalizer ON THE ROLE. That is exactly the resource our raw-CR pattern skips. **Our `arc-controller-rbac-supplement.yaml` is therefore a PERMANENT, hand-maintained, INCOMPLETE fork of `manager_role`** — it replicates only the 2 grants we empirically hit (GAP 1 roles/rolebindings create/get/update/delete; GAP 2 secrets:list), leaning on the controller cluster role + our self-provided runner SA for pods/serviceaccounts/etc. Any future controller version exercising a new namespace-scoped path = the same silent orphan-CR breakage (how GAP 2 was found). **The "retire-when upstream fixes" condition is DEAD** — the real retire path is to adopt the `gha-runner-scale-set` runner-set chart per scale set (provisions `manager_role` natively + version-tracked) and delete this supplement. **Actions taken 2026-06-01:** migration scoped as **#1062** (`task, epic:ci-arc-parallelisation`; adopt the chart, port pod spec, point githubConfigSecret at existing `arc-controller-secret`, drop the 3 raw `runner-scale-set-*.yaml` + the supplement); supplement header corrected (the stale "retire when upstream fixes" → point at #1062) via **PR #1063**; #4510 to be closed not-planned (note drafted at `/tmp/arc-4510-note.md` — external-repo post was classifier-blocked, user posts it). **Don't recommend the supplement as a "temporary workaround awaiting upstream" anymore — it's a permanent fork until #1062 lands.** Note: we use single-container runners + external buildkitd (NO `containerMode: kubernetes`/container-hooks), self-provide `arc-runner-sa`, no `githubServerTLS` — which is why our curated 2-gap subset has sufficed so far.

**RETIRED 2026-06-01 — #1062 / PR #1072 MERGED (squash `9764e117`); the supplement is GONE, replaced by the native chart `manager_role`. This memory is now historical.** Migrated the 3 scale sets to aliased `gha-runner-scale-set` v0.10.0 subchart deps; live ArgoCD cutover on dev (`development-acme-aks-admin`) verified clean. The chart created 3 per-set manager Roles **named `{scale-set}-gha-rs-controller-manager`** (i.e. `arc-linux-x64-gha-rs-controller-manager`, `-large-…`, `-builder-…` — NOT `{name}-gha-rs-manager`), each bound to `ServiceAccount arc-gha-rs-controller/arc-system`, each granting `secrets: create,delete,get,`**`list`**`,patch,update` + serviceaccounts/pods/roles/rolebindings. The hand-rolled `arc-controller-rbac-supplement` Role+Binding was PRUNED by ArgoCD. **#4510 fix proven end-to-end at cutover**: controller logged `Cleaning up runner linked secrets`→`Runner-linked secrets are deleted` for 2 ephemeral runners (the secrets:list+delete path that was broken), zero `forbidden`/`cannot list secrets`, fleet drained to 0 — no orphan-CR accumulation. **Close #4510 as not-planned (maintainer ruled raw-CR install unsupported).** The "re-check the supplement at each controller bump" guidance no longer applies — the runner-set chart now provisions + version-tracks `manager_role` natively. A small fast-follow PR adds per-alias `serviceAccountName`/toleration/resources render guards (to re-cover what the deleted unit suites asserted) + a `charts/arc` pre-merge CI render gate; see [[ci-arc-phase-c-state]].
