---
name: wi-pod-azure-login-confused-deputy
description: "On an ARC/WI pod, `azure/login` action with `client-id: ${{ secrets.AZURE_CLIENT_ID }}` SILENTLY authenticates as the CI SP instead of the pod's arc-runner-sa — defeats per-label SA isolation"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000008
---

The WI webhook injects four env vars into every pod with `azure.workload.identity/use: "true"` on its ServiceAccount: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_FEDERATED_TOKEN_FILE`, `AZURE_AUTHORITY_HOST`. These belong to the pod's bound SA (e.g. `arc-runner-sa` with KV+AcrPull only).

If a workflow step then runs `azure/login@v3` with explicit `client-id: ${{ secrets.AZURE_CLIENT_ID }}` — the EXPLICIT secret wins. The action authenticates as the CI service principal (which has much broader permissions: e.g. `Azure Kubernetes Service Contributor Role`, AKS write, KV read across multiple vaults). The pod's tight SA identity is bypassed. There is NO warning, NO error — the auth succeeds and the workflow runs with the wrong (broader) identity.

This is a confused-deputy: the pod's declared identity is shadowed by the action's input, and per-label SA isolation (the whole point of `arc-runner-sa` / `arc-builder-sa` / `arc-buildkitd-sa`) is defeated.

**Why:** 2026-05-24 PR #911 (closed) had exactly this pattern. The 5-reviewer panel caught it: workflow had `runs-on: arc-linux-x64` AND `azure/login` with secrets. Reviewer-confirmed scenario: a compromised CI step in `arc-linux-x64` could authenticate as the CI SP and acquire credentials the pod's SA was never granted. Defeats the per-label SA architecture (REV N2-sec).

**How to apply:** Two correct patterns for ARC pods:

1. **WI-native (preferred)** — drop `azure/login` entirely, use the injected env vars:
   ```bash
   az login --service-principal \
     --username "$AZURE_CLIENT_ID" \
     --tenant "$AZURE_TENANT_ID" \
     --federated-token "$(cat "$AZURE_FEDERATED_TOKEN_FILE")"
   ```
   Authenticates as the pod's SA. Canonical pattern: see `arc-smoke.yml` steps.

2. **If you need a DIFFERENT identity than the pod's SA** (e.g. broader perms for ops monitoring) — stay on `ubuntu-latest`, not ARC. Don't override WI on an ARC pod; it defeats the isolation.

NEVER use `az login --identity` on an ARC pod — that dials IMDS which is unreachable from a pod's network namespace.

[[feedback_argocd_app_set_drift]] is a different confused-deputy class (drift between live state and git) on the same Azure infrastructure surface.
