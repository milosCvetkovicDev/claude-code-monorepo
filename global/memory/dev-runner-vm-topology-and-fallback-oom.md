---
name: dev-runner-vm-topology-and-fallback-oom
description: "Legacy dev CI runner is ONE VM hosting both agents (dev sub); when down, Platform coverage tests OOM on the 2-core GitHub-hosted fallback"
metadata: 
  node_type: memory
  type: project
  originSessionId: 00000000-0000-0000-0000-000000000008
---

**Legacy self-hosted CI runner topology** (pre-ARC, kept as fallback through Phase D of [[ci-pipeline-architecture]] epic #835):

- `dev-runner-01` and `dev-runner-02` (registered in GitHub as two `ubuntu-latest-4-cores` self-hosted agents) are **ONE** Azure VM — `development-acme-runner` (8-core, Standard_D8s_v5) — hosting both agents on a 4/4 vCPU split. Source: `infra/environments/development/main.tf:579-587`, second agent codified in #822. So both GH agents offline = the single host VM is down.
- The VM lives in the **dev subscription**, NOT the Sponsorship sub. A Sponsorship-authed `az` session cannot see it (cross-sub Resource Graph returns 0). To restart (needs dev-sub access): `az vm start -g development-acme-rg -n development-acme-runner` — documented at `infra/.../output.tf:107`. Both agents return together.
- Auto-shutdown 17:00 UTC; auto-start 06:00 UTC Mon-Fri. **Observed FAILING 2026-05-29** (Fri, both agents offline at 08:39 UTC, past the 06:00 schedule). The auto-start mechanism is in the dev sub.
- VMs are "deprecated in Phase A" (only monitoring moved to the ARC pool via `platform-runner-health.yml` #918); **permanent decommission is Phase E / #845** (`terraform destroy` gated to Phase E + 90 days per ADR-0039). They MUST stay warm as fallback through Phase D.

**Fallback-OOM failure mode** (recurs whenever the VM is down):
When the VM is down, the Platform reusable CI `_ci.yml` (`workflow_call`-only; called by `platform-pipeline.yml` on every Platform PR; `platform-ci.yml` is dispatch-only since #948) falls to the GitHub-hosted **2-core / 7 GB** `ubuntu-latest`. Its "Test affected Platform projects (with coverage)" step ran ~14 Nest-bootstrap suites with `--coverage` at `NX_PARALLEL=2` → two concurrent coverage suites OOM-kill random workers.

**Diagnostic signature (fallback-OOM, NOT a code defect):** different innocent *untouched* projects die each run; zero vitest assertion / "Test Files failed" / timeout markers (process dies before the summary); same suite set green on `main` + pre-rebase heads on the same `ubuntu-latest` type. (Same OOMKill tell as [[feedback_gha_npm_ci_heartbeat_timeout]] — discriminate by "different projects each run + no summary".)

**Why:** undersized fallback runner; `--coverage` instrumentation is memory-heavy; 2 suites concurrent > 7 GB.
**How to apply:** when Platform CI OOMs with that signature, it's the fallback path, not the diff — check VM state (`az vm` in dev sub), restart the VM, OR rely on the interim fix. Interim fix shipped: **PR #1001** overrides `NX_PARALLEL=1` on the coverage step only (one suite at a time, ~halves peak RSS; lint/build/typecheck stay at 2). Permanent fix = **Phase D ARC cutover (#844)** → `arc-linux-x64-large` (8Gi req / 12Gi limit) lets `NX_PARALLEL` rise again; revert the override when #844 lands. For a code-clean PR blocked by this, admin-merge is justified (required checks = `main (CI)` + `Validate Terraform`).
