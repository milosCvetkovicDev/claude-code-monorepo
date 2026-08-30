---
name: feedback_keep_dev_platform_healthy
description: "Standing directive — dev-platform is recovered/healthy; always verify and keep it running, healthy, and stable when doing any Platform-stack work."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000011
---

**Directive (user, 2026-06-01):** dev-platform is now a HEALTHY, running environment again. Keep it that way — **always check** cluster health and ensure changes keep it running, healthy, and stable. Do not let it regress to Degraded.

**Why:** dev-platform was Degraded across 5 layers and took a costly multi-session recovery to restore (see [[platform-dev-deploy-recovery]] for the 2026-05-26 recovery; another full recovery happened 2026-06-01 — RMQ 403 drift, ESO self-heal loop, CPU deadlock, platform-root OutOfSync loop, inventory/ai crashloops). Recovery is expensive and error-prone; preserving the healthy baseline is far cheaper than re-recovering.

**Healthy baseline as of 2026-06-01 (the state to maintain):** 12/13 Platform services `1/1 Running`, 0 restarts; platform-root + grafana-provisioning `Synced/Healthy`; ESO self-heal loop eliminated; OutOfSync loop fixed (#1042→#1043 ignoreDifferences). Only **ai-service** remains `Init:CrashLoop` (B4 / #957 — a separate migration issue, known/out-of-scope, NOT a regression).

**How to apply:**
- Before AND after any change touching the Platform deploy path (charts/argocd, charts/bundles, images, RMQ topology, ESO/KV secrets, CNPG, deploy workflows), verify dev-platform health — ArgoCD app Sync/Health (argocd-mcp, see [[reference_argocd_mcp]]) and pod state.
- Treat a change that could destabilise dev-platform as requiring a health check as part of "done", not an afterthought. If a deploy regresses health, fix-forward or roll back promptly (see [[platform-redesign-topology]] for rollback runbooks).
- Pure docs / test-only / non-deploy PRs (e.g. #1037: docs + `test/poc/**`) do NOT touch the deploy path and are health-neutral — but anything that syncs to the cluster does.
- Watch the known fragilities: RMQ per-service password drift needs `rabbitmqctl change_password` or `kubectl delete user.rabbitmq.com` (an operator restart does NOT re-push — [[rmq-topology-operator-rotation-gotcha]]); ArgoCD OutOfSync loops need `ignoreDifferences` jqPathExpressions + RespectIgnoreDifferences, not just ServerSideDiff.
