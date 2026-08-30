---
name: argocd-serverside-diff-for-large-crds
description: "ArgoCD `ServerSideApply=true` syncOption does NOT propagate to the diff path — large CRDs (~1 MB OpenAPI schemas) trip K8s 256 KiB annotation limit on every refresh"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000008
---

App-level `syncOptions: [ServerSideApply=true]` only governs the APPLY path. The DIFF path stays client-side, comparing chart-rendered vs live state directly. When K8s API server normalises CRD fields (e.g. `spec.conversion.strategy: None`, `spec.preserveUnknownFields: false`), every refresh sees them as drift and tries to patch. The patch attempt writes `kubectl.kubernetes.io/last-applied-configuration` containing the full CRD spec; for CRDs > 256 KiB the annotation exceeds the K8s `metadata.annotations` 262144-byte limit and the apply fails:

> "<crd>.actions.github.com" is invalid: metadata.annotations: Too long: may not be more than 262144 bytes

**Why:** 2026-05-24 the `arc` app's sync failed for hours on `autoscalingrunnersets.actions.github.com` because the gha-runner-scale-set subchart's 4 CRDs render to ~500 KB-1 MB each. `ServerSideApply=true` was already on but didn't help. Fix took three steps to land: (1) strip the legacy bloated annotations from live CRDs, (2) add `ServerSideDiff=true` syncOption, (3) belt-and-braces `ignoreDifferences` for `apiextensions.k8s.io/CustomResourceDefinition` paths `/spec/conversion` and `/spec/preserveUnknownFields`. See PR #908 for the durable fix.

**How to apply:** Any ArgoCD Application that ships large CRDs (subchart with full OpenAPI schemas, anything > ~300 KB rendered) MUST set BOTH `ServerSideApply=true` AND `ServerSideDiff=true` syncOptions. If the diff still flags `/spec/conversion` or `/spec/preserveUnknownFields` after that, add the targeted `ignoreDifferences` block. Don't troubleshoot by stripping bloated annotations from live CRDs alone — without the syncOptions fix, the bloat will return on the next sync attempt.

Related: [[feedback_argocd_app_set_drift]] (separate sync failure mode surfaced the same day on the same Application).
