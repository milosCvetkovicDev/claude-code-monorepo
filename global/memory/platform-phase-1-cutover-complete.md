---
name: platform-phase-1-cutover-complete
description: Phase 1 (#655, #661) executed 2026-05-11; full 12/12 service recovery 2026-05-12 via 3 small fix-up PRs (#707 gateway, #712 reporting) + static-secret synthesis for audit/reporting. Single-branch GitOps on main is live. Read before assuming cluster is in any prior described state.
type: project
originSessionId: 00000000-0000-0000-0000-000000000046
---
# Platform Phase 1 cutover-COMPLETE state (2026-05-12 morning)

Cutover executed end-to-end + full 12/12 service recovery across this session. Cluster is now under single-branch GitOps on `main`. ApplicationSet retargeted, root AppOfApps active, **all 12 service pods Ready**. Application Health=Degraded labels remain because ESO ExternalSecret CRDs report SecretSyncedError (the pre-existing Workload Identity gap, #708) — but pods themselves are healthy because they run on static K8s Secrets, not ESO-managed ones.

## What's in cluster now (verified 2026-05-12 08:45 UTC)

- `Application/platform-root` in `argocd` namespace (path `charts/argocd`, targetRevision `main`, automated `prune+selfHeal`, `ServerSideApply=true`)
- `ApplicationSet/platform-services` rewritten to `targetRevision: main` by root-app's reconcile
- All 12 child Applications **Synced** (Health=Degraded label is a leftover from ESO ExternalSecret CRDs failing to refresh from KV — does not reflect pod health)
- Namespaces `platform-compliance` + `platform-analytics` created (audit/reporting were previously Missing because of `CreateNamespace=false` + no ns)
- `argocd-application-controller` StatefulSet memory limit bumped 512Mi → 2Gi (manual `kubectl patch` — see follow-up issue #710)
- **All 12 services Ready:**
  - gateway: 1/1 on `sha-4fc331c` (fixed via #707 — `sha-34e7e05` didn't exist in ACR)
  - auth, tenant, user, trading, inventory, accounting, commission, document, notification: 1/1 each on `sha-34e7e05`
  - audit-service: 2/2 on `sha-f9bcb54` (recovered after manual K8s Secret synthesis from working services' patterns — KV had no `platform-audit-*` secrets pre-staged)
  - reporting-service: 1/1 on `sha-4fc331c` (fixed via #712 — `sha-f9bcb54` had a `seedSystemReports/tenant-filter.platformScope` bootstrap crash; Phase 0 build #678 included the fix)

## Manual K8s Secrets created 2026-05-12 (NOT under ESO; tracked by #708 for proper WI replacement)

- `platform-compliance/audit-secrets` — database-url (schema=audit), rabbitmq-uri, azure-storage-connection-string. Synthesized from `commission-secrets` (DB pattern) + `document-secrets` (storage). Same legacy user + same shared postgres + same shared rabbitmq.
- `platform-analytics/reporting-secrets` — database-url (schema=reporting), rabbitmq-uri. Synthesized from `commission-secrets`.

These are static, not ESO-managed. They match the 10 other services' static-Secret pattern from cluster setup 42 days ago. Replace with ESO when #708 lands.

## Revised root cause of the 5-day "broken cluster" state

This is the critical correction to the prior `cutover-pending` memory:

| Hypothesis | Reality |
|---|---|
| PR #611 selector split caused the 5-day outage | **Wrong.** PR #611 made the failure mode VISIBLE for 6 services. But the actual paralysis was `argocd-application-controller` being **OOMKilled** at the 512Mi memory limit, ~10 restarts/day, processing 1–3 syncs per restart cycle before crashing. With the controller down ~50% of the time, NOTHING was reliably reconciling. Bumping to 2Gi made the controller stable; queued syncs cleared in ~3 minutes. |

The OOM was already happening on 2026-05-06 (5+ days of CrashLoopBackOff). PR #611's selector immutability was a real issue, but it would have been visible as a quick SyncError on a healthy controller; with the controller stuck, EVERYTHING looked stuck.

## Other discoveries worth remembering

- **Forward-port pattern has a hidden assumption.** gitops/dev tags are NOT guaranteed to correspond to existing ACR images. Legacy `_deploy.yml` bumps tags in gitops/dev without verifying nx-affected actually rebuilt that service. Gateway hit this on 2026-05-11 — `gateway:sha-34e7e05` doesn't exist; fixed by separate PR #707 → `sha-4fc331c`. Forward-port runbook step 3 should add an "ACR image existence check" before bumping tags.
- **ESO Workload Identity is broken cluster-wide.** SecretStore in every platform-* namespace fails with `ServiceAccount "platform-<svc>" not found`. The `platform-base` chart doesn't create the per-service ServiceAccount that SecretStore's WI auth needs. 10/12 services run because they have static manually-created K8s Secrets from cluster setup (42d old). Newly-deployed services (audit, reporting) have no static Secret and fail. Separate follow-up.
- **Application HARD refresh sometimes required.** After merging a values change to main, ArgoCD's Synced status can become "ahead of reality" (Sync=Synced but Deployment image stale) until repo-server cache invalidates. `kubectl patch app <name> -n argocd -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'` forces re-render.
- **POC-2's 10s bootstrap measurement doesn't generalize.** POC-2 measured a 1-app AppOfApps on an existing argocd namespace. With 13 apps + saturated controller, full convergence was ~30 min including controller stabilization. Don't budget cutover windows based on POC-2.

## Operational reminders unchanged from prior session

- **GitHub App `acme-platform-poc-deploy` (ID 3675407):** still `repository_selection: all` — narrow to `selected` before #664 promotes to production use.
- **Private key:** still in `~/Downloads/acme-platform-poc-deploy.2026-05-11.private-key.pem` — move to 1Password.
- **Scratch repo `acme-platform-poc-1-scratch`:** can be deleted.

## What lands next

- **PM closures:** `/pm:issue-close 655` and `/pm:issue-close 661` (cutover delivered both). Plus a follow-up comment on epic #631 summarising the outcome.
- **Follow-up issues to open** (this session will surface them):
  1. `platform-base` chart: add per-service ServiceAccount template with Workload Identity annotation
  2. Legacy `_deploy.yml`: tag bumps run without image-presence verification — duplicates gateway-class bug
  3. ArgoCD controller memory: 2Gi limit currently a manual patch; should land in the bootstrap chart values
- **Next milestones already unblocked:** #663 (cluster-bootstrap.sh), #664 (Terraform App), #667 (CI deploy to main), #672 (decommission gitops/dev). POC-3 (#675 Argo Rollouts), POC-4 (#676 bundle umbrella charts).

## Where things live

- **Runbook (updated this session):** `.claude/epics/platform-redesign/cutover-phase-1.md` on `platform` — section 4b broken-cluster path. **Does NOT yet capture the OOMKilled-controller discovery or the ACR-existence-check pattern** — runbook update is a follow-up.
- **Rollback snapshot:** `/tmp/argocd-snapshot-20260511-175809` (14 files). Move out of `/tmp` if keeping for 7 days.
- **PR #705** (image-tag forward-port): merged 9f43b31c (2026-05-11)
- **PR #706** (Phase 1 manifests on main): merged 27f0062a (2026-05-11)
- **PR #707** (gateway tag fix): merged 3a5cca65 (2026-05-11)
- **PR #712** (reporting tag bump for tenant-filter bootstrap fix): merged 8200c157 (2026-05-12)

## What this memory replaces

Supersedes `platform-phase-1-cutover-pending.md` (now stale — delete after reading this).
