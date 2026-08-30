---
name: No Platform deploys to prod-acme-legacy
description: Platform / AKS workloads (audit-service, reporting-service, trading-service, M5+) are NOT deployed to prod-acme-legacy and will not be. Directive from user 2026-04-20. Scope narrows planning for infra work and audit ACs.
type: feedback
originSessionId: 00000000-0000-0000-0000-000000000037
---
**Rule**: Do not deploy any Platform-stack workload (AKS pods, audit-service, reporting-service, trading-service, notification-service, any `apps/platform/*` service) to `prod-acme-legacy`. Prod-acme-legacy stays legacy-only: `legacy-api` App Service, `legacy-web` Static Web App, `domain-api` Container App, `nx-cache-server-bun` Container App, `helix-agent` Container App.

**CLARIFICATION (2026-05-25 PM)**: This directive is narrowly scoped to the EXISTING `prod-acme-legacy` Azure environment. It is NOT a statement that Platform stays development-only forever. **Platform IS projected to have its own future production environment** on new infrastructure (vendor TBD per ADR-0042). The directive exists to prevent accidental deployment to the wrong env during the development window — a focus-protection rule, not a production-ban. If a session reads "Platform stays development-only" and concludes Platform will never have production, that's a misreading — confirm with the user.

**Why**: User directive 2026-04-20. Reason not captured verbatim, but context is that the Platform migration stays on the `development` environment until a future explicit decision. `prod-acme-legacy` is the revenue-critical production — changes there must be small, auditable, and reversible. Dropping a full AKS stack into it during the M5/M6 window is outside the current risk appetite.

**How to apply**:
- When writing infra changes that involve Platform services (AKS, audit-service, reporting-service, trading-service, etc.), scope them to `development` only. Do not wire modules into `infra/environments/prod-acme-legacy/*.tf`.
- When writing audit / verification specs (like `updates/516/audit-checklist.md`), mark Platform-service ACs as `out-of-scope-for-prod` rather than `pending` or `defer-to-M6`.
- When writing ADRs or planning docs (like ADR-0027 ACR migration), treat prod-acme-legacy's scope as the three Container Apps only. AKS work is a separate workstream limited to development.
- When Platform M6 "Production Launch" work comes up, do not assume that means prod-acme-legacy. Confirm the target environment with the user first.
- When the user asks about "production", clarify if needed: they may mean prod-acme-legacy (legacy), or a future Platform production (not yet defined).

**Scope**:
- Applies to: prod-acme-legacy Terraform, deploy workflows, audit ACs, scope language in PRs.
- Does NOT apply to: development environment (Platform AKS stays there), open-ended architectural planning (fine to discuss post-cutover options).

**References**:
- User directive captured mid-session 2026-04-20 while PR #519 was in flight.
- ADR-0027 (ACR migration) updated 2026-04-20 to reflect this scope narrowing.
- AC 6 in PR #519's `updates/516/audit-results.md` marked OUT OF SCOPE per this directive.
