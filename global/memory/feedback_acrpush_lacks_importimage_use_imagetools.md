---
name: feedback_acrpush_lacks_importimage_use_imagetools
description: "Built-in AcrPush lacks registries/importImage/action so `az acr import` fails as \"registry not found\"; vendor third-party images via `az acr login` + `docker buildx imagetools create`"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000035
---

To vendor a third-party image into **developmentacmeacr** using the image-build UAMI (`AZURE_CLIENT_ID_RUNNER_IMAGE` = `development-acme-arc-image-build-identity`), do NOT use `az acr import` — use `az acr login` + `docker buildx imagetools create`.

**Why (az-verified 2026-05-27, #959):** the built-in **AcrPush** role grants only `Microsoft.ContainerRegistry/registries/push/write` (+ `pull/read`) — it does NOT include `registries/importImage/action`, which `az acr import` requires. The UAMI holds only AcrPush, so `az acr import` is denied and Azure **masks the RBAC failure as** `ERROR: The resource with name 'developmentacmeacr' ... could not be found in subscription 'Microsoft Azure Sponsorship'`. The first #959 vendor run (26518184598) failed exactly this way — the misleading "not found" is RBAC, not a missing registry. (An earlier review *assumed* AcrPush bundles importImage; it does not.)

**The fix that works with AcrPush (data-plane only):**
```
az acr login --name developmentacmeacr            # AcrPush suffices for the docker credential
docker buildx imagetools create \
  --tag developmentacmeacr.azurecr.io/<repo>:<tag> \
  docker.io/<src>/<repo>:<tag>                        # public source = anonymous pull; only the push needs auth
```
`imagetools create` copies the full (multi-arch) manifest registry-to-registry and **preserves the source digest** (so you can digest-pin). Alternative: grant the UAMI a role with `importImage` (Contributor includes it) — but that's an RBAC change tied to the dedicated-UAMI epic #963; imagetools needs no grant.

**Two more facts (2026-05-27):**
- **rabbitmq is bootstrap-managed**, NOT an ArgoCD app — `cluster-bootstrap.sh` does `helm upgrade --install bitnami/rabbitmq`. So `charts/infrastructure/rabbitmq-values.yaml` changes do NOT auto-sync; the live broker re-points only on a manual `helm upgrade` (operator-gated).
- The dev broker runs `bitnamilegacy/rabbitmq:**4.1.3-debian-12-r1**` (verified via `kubectl`), NOT the chart-appVersion `3.13.7` the bitnami 16.3.3 docs imply — always read the live image tag before vendoring.

Related: [[bitnami-secure-image-deprecation]], [[feedback_subagent_cannot_write_claude_breadcrumbs]].
