---
name: POC-5 Phase 4 gap tasks (ALL CLOSED 2026-05-13 — incl. #608)
description: Phase 4 Workload Identity tasks #659/#660/#633/#635 + POC-5 gaps #689/#690/#692 + dev TF unblocker #608 all closed. Phase 4 fully done.
type: project
originSessionId: 00000000-0000-0000-0000-000000000060
---
# POC-5 Phase 4 gap tasks — ALL CLOSED 2026-05-13

Phase 4 Workload Identity codification + dev TF unblock complete. All 8 tracking issues closed.

**Why:** Earlier memories framed this as iterative ("4 originals + 3 gap tasks + #608 blocker"). That framing churned twice this session. Now it's resolved end-to-end: helix-agent decommissioned, dev TF unblocked, Microsoft Graph CI SP perms granted.

**How to apply:** When next Platform-platform-redesign work is picked, do NOT treat ANY of these issues as ready — they are closed. ADR-0035 can transition to Accepted once #689/#690/#692 live-cluster verification is run (now unblocked because dev TF apply succeeds).

## Issue mapping (all CLOSED)

| Issue | State | Title |
|-------|-------|-------|
| **#659** | CLOSED | Migrate nx-cache-server image to ACR (closes #521) |
| **#660** | CLOSED | ESO Workload Identity end-to-end audit |
| **#633** | CLOSED | Imminent-expiry alerting (Azure Function or CronJob) |
| **#635** | CLOSED | Security audit by security-auditor agent |
| **#689** | CLOSED | ESO sync-failure Grafana alert (POC-5 gap) |
| **#690** | CLOSED | ACR Image Updater token surface removal (POC-5 gap) |
| **#692** | CLOSED | Redis URL KV provisioning codified (POC-5 gap) |
| **#608** | CLOSED 2026-05-13 11:10:45Z | Dev terraform-deploy blocked since 2025-12-22 |

## #608 actual root cause (corrected from issue body)

Original write-up framed #608 as a single CI SP permission gap on the sponsorship `development-acme-rg`. Two independent problems:

1. **Cross-subscription RBAC coupling**: `helix_agent` created role assignments scoped to `shared-acme-log-analytics` in subscription `00000000-...` ("Azure subscription 1"), which the dev CI SP `f9745361-...` has no access to. The "Role Based Access Control Reader" role suggested in the original remediation does not exist as a built-in role. Fix: decommission helix-agent end-to-end (PR #727 merged `b73a1b38`, PR #729 merged `d2ef146d`, plus TF state rm + manual `az` cleanup).
2. **Microsoft Graph permission gaps**: `authentication-entra-id` module needs 3 Graph Application-level perms granted to CI SP via `az rest .../appRoleAssignments`. Granted 2026-05-13: `Application.Read.All`, `AppRoleAssignment.ReadWrite.All`, `DelegatedPermissionGrant.ReadWrite.All`.

## Residual / out of scope (harmless)

- 4 orphaned role assignments on `shared-acme-log-analytics` in the other subscription (principal is gone — owner of that sub can prune)
- `apps/helix-agent/`, `infra/modules/helix-agent/`, doc references in `.claude/context/` and `docs/` — separate cleanup if desired
- `infra/CLAUDE.md` Common Gotchas note for CI SP — original AC asked for this; deferred since the gotcha class (cross-sub TF dependencies) is now eliminated for dev

## Source evidence

- POC-5 audit deliverable: `.claude/epics/platform-redesign/poc-results/poc-5-result.md` §5
- Per-issue close-out streams: `.claude/epics/platform-redesign/updates/{689,690,692}/stream-A.md`
- Per-issue local task files: `.claude/epics/platform-redesign/{659,660,633,635,689,690,692}.md`
- #608 closure: https://github.com/initech-trading-platform/acme/issues/608#issuecomment-4440307582
