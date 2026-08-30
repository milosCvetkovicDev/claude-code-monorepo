---
name: argocd-app-set-drift
description: "ArgoCD `argocd app set -p` writes helm.parameters into the live Application but NEVER syncs back to the source Application manifest in git — silent drift surface"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000008
---

If an ArgoCD Application sets helm parameters via `argocd app set -p name=value` (CLI or UI), those parameters live ONLY in the cluster's live Application resource. They are NOT reflected in `charts/argocd/<app>.yaml` in git, and AppOfApps self-heal does NOT re-add them on diff because git's source has no `helm.parameters` block at all. Result: silent drift surface that accumulates without warning.

**Why:** 2026-05-24 the `arc` Application's sync failed for 30+ hours on a PV immutability error because the `azureFiles.resourceGroupName` parameter required by the chart had been added live but never committed. The new `arc-buildkitd-sa` work (PR #901) required adding a 6th parameter; the failure was indistinguishable from the existing drift. Diagnosis took 20 min once we knew to look at the live `spec.source.helm.parameters` vs the git file.

**How to apply:** When working with any ArgoCD Application in `charts/argocd/`:
- Before editing the chart, dump live `helm.parameters` (`kubectl get app <name> -n argocd -o json | jq .spec.source.helm.parameters`) and reconcile against git.
- When introducing a new required value, add it to BOTH the live app (via `kubectl patch application` or `argocd app set`) AND commit to `charts/argocd/<app>.yaml` in the same PR — never just one or the other.
- Treat `spec.source.helm.parameters` missing from git as a defect on any Application that needs envspec values.

Related: [[feedback_argocd_serverside_diff_for_large_crds]] (separate sync failure mode surfaced the same day).
