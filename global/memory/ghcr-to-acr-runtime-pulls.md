---
name: GHCR → ACR migration for Azure runtime pulls
description: Retire the GHCR PAT + registry-password secret pattern; Azure workloads pull from ACR via managed identity. Tracked as issue #521, driven by the 2026-04-09→04-20 nx-cache-server-bun outage.
type: project
originSessionId: 00000000-0000-0000-0000-000000000037
---
**Fact**: All Azure runtime Container Apps (`domain-api`, `nx-cache-server-bun`, `helix-agent`) and eventually AKS pods (Platform M6+) must migrate from GHCR-with-PAT pulls to ACR-with-managed-identity pulls. Tracked as GitHub issue #521. ADR-0027 captures the decision.

**Why**: On 2026-04-09 the GHCR PAT in `nx-cache-server-bun`'s `registry-password` secret expired. Revision fell into `ImagePullBackOff`, held 100 % traffic, served nothing — undetected for **11 days** until a developer's pre-push hook returned 504 from the cache server. Every other Container App will hit this same failure mode on its next PAT rotation cycle (30-90 days). A P1 `ContainerAppSystemLogs_CL` ImagePullBackOff alert shipped in PR #519 so the next silent failure is audible, but the real fix is to retire PATs entirely: managed identity = no secret, no rotation, no expiry.

**How to apply**:
- When the user mentions Container App image pulls, GHCR tokens, `registry-password` secrets, or `ImagePullBackOff` incidents, remember this migration is pending and suggest #521 as the canonical fix rather than rotating PATs again.
- If you're editing a Container App's `registries` block, check whether ACR migration has landed (look for `registries.identity = "system"` in the target); if not, flag it as "will be retired by #521".
- Don't add new Container Apps with the PAT pattern — they'd just be more migration work. New apps should use ACR + managed identity from day one.
- Don't use `:main` or other floating tags in Container App image refs (violates CLAUDE.md). Git SHA tags only. #521 fixes this alongside the ACR switch.
- Short-term unblock pattern we used 2026-04-20: `gh auth token` piped directly to `az containerapp secret set` — acceptable for emergency rotation but session-scoped, not durable. Do **not** script this as the normal rotation path; it just delays #521.

**Effort**: ~1 day split across ACR provisioning (~2h, Terraform), CI dual-push (~1h), per-Container-App migration ×3 (~5h including verify/rollback).

**Sequence**: ACR in development-acme-rg first (validate), then prod-acme-rg; dual-push CI change; then Container Apps one at a time (dev → prod), starting with nx-cache-server-bun. AKS pod migration folds into the M6 cutover work.

**References**:
- Issue: https://github.com/initech-trading-platform/acme/issues/521
- ADR: `docs/adr/0027-acr-for-azure-runtime-pulls.md`
- Alert (already landed): `infra/modules/app-insights/main.tf` — `container_app_image_pull_failure` scheduled-query alert
- Incident artefacts: PR #519 review triage at `.claude/reviews/pr-519/`
