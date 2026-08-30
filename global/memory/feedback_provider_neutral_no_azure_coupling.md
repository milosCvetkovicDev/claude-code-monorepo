---
name: feedback_provider_neutral_no_azure_coupling
description: "Platform platform must use cloud-native, provider-neutral solutions — no coupling to Azure-proprietary services where a CNCF/OSS alternative exists"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000016
---

Directive (Milos, 2026-06-08): "we don't want to couple to azure, so choose the cloud native solutions that are not coupled to any provider."

**Why:** portability / avoid vendor lock-in. The Platform platform should be runnable on any cloud; Azure-proprietary services are a strategic liability. This is a binding architectural principle, not a per-task preference.

**How to apply:**

- Prefer CNCF / OSS, vendor-neutral building blocks: Prometheus/Grafana/Mimir/Loki/Tempo/OpenTelemetry (observability), RabbitMQ Cluster Operator + upstream images (messaging), ArgoCD/Helm/Kustomize (GitOps), Harbor (registry), OpenBao/Vault/SOPS (secrets), SPIFFE/SPIRE or K8s SA tokens (identity), cluster-autoscaler (capacity). External Secrets Operator (ESO) is the neutral abstraction — keep it; swap the BACKEND, not ESO.
- Treat as Azure coupling to avoid/replace where a neutral option exists: Azure Key Vault (secret store), Azure Workload Identity Federation (pod identity), Azure Container Registry, AKS Managed Prometheus/Grafana, Azure Service Bus, Azure Monitor as the primary alerting path.
- Pragmatic line: the AKS substrate itself (managed control plane, node SKUs, the bootstrap "secret-zero") is unavoidable while hosted on Azure — node SKU choices (e.g. D4as_v7) are necessarily provider-specific; that's the infra edge, not application coupling. Watch the **auto-unseal re-coupling trap**: self-hosted Vault/OpenBao auto-unseal usually pulls in a cloud KMS — pick a neutral unseal (Transit/Shamir/K8s-native) or a serverless store (SOPS+age).
- This SUPERSEDES the already-built Azure-coupled choices on main: ADR-0035 (workload-identity-end-to-end = Azure WIF) and ADR-0038 (KV secret provisioning). Reconcile/supersede them, don't extend them.

Anchors [[platform-dev-stabilization-epic]] (AD-4). Also relevant to any future Platform infra ADR.
