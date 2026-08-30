---
name: Platform GitOps topology (ArgoCD + ApplicationSet + gitops/dev) — DEPRECATED
description: DEPRECATED 2026-05-11. Two-branch GitOps wiring (main + gitops/dev) is being replaced by single-branch AppOfApps + Argo Rollouts per the platform-redesign epic. Redirect → docs/platform/operations/deployment-guide.md. Kept on disk so older pointers don't 404; content below describes the legacy topology only.
type: project
originSessionId: 00000000-0000-0000-0000-000000000061
---

> # ⚠️ DEPRECATED — 2026-05-11
>
> The two-branch GitOps topology described below is being decommissioned
> by the **platform-redesign** epic (epic #631). The replacement
> is single-branch GitOps with an AppOfApps Application bootstrapping
> per-bundle Applications via ApplicationSet (ADR-0033), and Argo
> Rollouts SLO-driven canaries for deploy verification (ADR-0034).
>
> **Read instead:**
>
> - [`docs/platform/operations/deployment-guide.md`](../../../../projects/acme-platform/docs/platform/operations/deployment-guide.md) — current build/deploy/rollback procedures (rewrite tracked under task #658)
> - [`docs/platform/operations/rollback-runbook.md`](../../../../projects/acme-platform/docs/platform/operations/rollback-runbook.md) — three-path rollback (auto / `git revert` / break-glass) per ADR-0034
> - Memory: [platform-redesign-topology.md](platform-redesign-topology.md) — the new memory entry tracking the in-flight epic
>
> Decommission of `gitops/dev` itself is task #672 (chain-blocked on
> #655/#661/#667/#671). Until that lands, the legacy debugging checklist
> below remains technically useful for the dev cluster — but treat it as
> archaeology, not policy.

> ## ✅ Decommission Complete — 2026-05-15
>
> Task #672 has landed. `gitops/dev` is now fully inert:
> - ArgoCD ApplicationSet `targetRevision` points to `main` (#672 update)
> - Deploy workflow writes to `main` (#667 / PR #782)
> - Build-push release manifest reads from `main` (#672)
> - No live workflow, manifest, or script reads from `gitops/dev`
>
> The branch is retained for git history. Branch protection rules remain
> in place. The debugging checklist below is **archaeology only** — do
> not follow it. Current operational procedures live at
> `docs/platform/operations/deployment-guide.md`.

---

Platform deploys to dev AKS via a two-branch GitOps loop. Discovered 2026-05-06 after a 6-hour debug session — was previously undocumented and took 3 expert subagents to map.

## Topology

- `main` is the source-of-truth for **chart templates** (`charts/platform-base/templates/**`), **values base files** (`charts/values/<svc>.yaml`), the **ApplicationSet manifest** (`charts/argocd/applicationset.yaml`), and the **AppProject manifest** (`charts/argocd/appproject.yaml`).
- `gitops/dev` is a long-lived **tag-overlay branch** that contains its own copy of `charts/values/<svc>.yaml` with bumped `image.tag` values. It is NEVER merged back to main; it diverges forward forever.
- `.github/workflows/platform-deploy.yml` auto-triggers after Build & Push on main, checks out gitops/dev, runs `yq -i '.image.tag = ...' charts/values/<svc>.yaml`, and pushes directly to `origin gitops/dev`.
- ArgoCD reads chart templates from `main` BUT image tags from `gitops/dev` — controlled by the ApplicationSet template at `charts/argocd/applicationset.yaml:93` (`targetRevision: gitops/dev`) plus the per-service Helm `valueFiles` chain.
- A dedicated AppProject `platform-services` (NOT `default`) gates which destination namespaces and source repos are allowed.

## How it actually breaks

1. **ApplicationSet drift**: cluster ApplicationSet has `targetRevision: main` but repo manifest has `gitops/dev` (or vice versa). Symptom: `ArgoCD Synced=Synced trivially because no drift exists between cluster and main`, but pods stay on old tags. Fix: `kubectl apply -f charts/argocd/applicationset.yaml -n argocd` to re-sync. Found 2026-05-06 — cluster had stale `main`.
2. **Missing AppProject**: ApplicationSet declares `project: platform-services` but only `default` exists. Symptom: `application references project platform-services which does not exist` in app-controller logs. Fix: `kubectl apply -f charts/argocd/appproject.yaml -n argocd`.
3. **Missing values files on gitops/dev**: when a new service is added on main, its `charts/values/<svc>.yaml` MUST be seeded onto gitops/dev or the deploy workflow's `yq` step has nothing to bump. With `ignoreMissingValueFiles: true` set on ApplicationSet, the missing file is silently dropped → Helm renders with empty `bc` and `image.tag` → schema validation fails → app stuck `Unknown`. Found 2026-05-06: audit/reporting/ai missing on gitops/dev.
4. **ESO `v1beta1` discovery error**: chart template using `external-secrets.io/v1beta1` against an ESO 2.x cluster (which only serves `v1`). Already fixed on `main` by PR #610 — but the fix needs to land on `gitops/dev` too via cherry-pick or the deploy script doesn't render manifests. ArgoCD's controller may also cache the v1beta1 resource discovery; restart `argocd-application-controller-0` after the fix.

## Debugging checklist (run in order)

1. `kubectl get applicationset platform-services -n argocd -o jsonpath='{.spec.template.spec.source.targetRevision}'` → must be `gitops/dev`. If not, `kubectl apply -f charts/argocd/applicationset.yaml -n argocd`.
2. `kubectl get appproject platform-services -n argocd` → must exist. If not, `kubectl apply -f charts/argocd/appproject.yaml -n argocd`.
3. `git ls-tree origin/gitops/dev -- charts/values/` → file count must match `git ls-tree origin/main -- charts/values/`. Missing files cause Unknown sync.
4. Look in app-controller logs (`kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --since=120s --tail=300`) for: `references project ... does not exist`, `failed to discover server resources for group version`, `values don't meet the specifications of the schema`.
5. Image-mismatch in deploy-workflow `Verify rollout health` step (`platform-deploy.yml:464`) currently only `warn`s — does not fail the run. Treat a green deploy as untrustworthy until pod images are checked directly.

## What "right" looks like

- Cluster bootstrap script (`scripts/platform/cluster-bootstrap.sh:146`) re-applies AppProject + ApplicationSet on every run. ESO Helm chart upgrades go through the same path.
- Deploy workflow gains an early step `kubectl apply -f charts/argocd/applicationset.yaml -n argocd` to make drift impossible.
- Deploy workflow's image-mismatch check at line 464 should `error`, not `warn`.
- Adding a new platform service requires a one-time PR that creates `charts/values/<svc>.yaml` on **both** `main` and `gitops/dev`. A pre-merge check would prevent the recurring missing-file bug.
