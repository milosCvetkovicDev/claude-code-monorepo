---
name: Platform Sprint 2 DDD Completeness Review
description: DDD expert audit found 4 CRITICAL + 9 MAJOR + 2 MINOR gaps. Everything not needing a policy ruling was fixed in the event model, BDD scenarios, and context map.
type: project
---

DDD completeness audit completed 2026-03-25. Reviewed event models, BDD scenarios, context map against DDD phases A+D+F requirements for Generic subdomain.

**Why:** Phase A (Event Modeling) and Phase D (BDD Scenarios) were claimed complete. DDD review found they were not — missing aggregate roots, incomplete payload schemas, untested business rule boundaries, and no cross-BC relationship mapping.

**How to apply:** Event model at `docs/platform/context-mapping/event-models/identity-platform.md` now has aggregate roots, repository ports, consumer ordering notes, and all missing payload schemas. BDD scenarios have boundary tests added. Context map has Identity↔Platform Partnership relationship.

## Findings Fixed (2026-03-25)

1. **A3 CRITICAL:** Task 8 said "BR1-BR40" — only BR1-BR10 exist. Fixed typo to "BR1-BR10"
2. **A5/T1 CRITICAL:** No aggregate roots declared. Fixed — added to event model:
   - Auth-service: `Credential` (aggregate root), Session/RefreshToken/MfaConfig within aggregate, OidcProvider separate
   - User-service: `User` (aggregate root), Invitation subordinate to User aggregate, Role/Permission separate
   - Tenant-service: `Tenant` (aggregate root), TenantConfig/FeatureFlag within aggregate
3. **A1 MAJOR:** `auth.identity.unlinked` missing payload. Added
4. **A4 MAJOR:** Session entity not in event model. Added as read model with column list in auth aggregate section
5. **A7 MAJOR:** User/Invitation aggregate boundary. Clarified — Invitation is part of User aggregate (evidence: revoke deactivates User)
6. **A8 MINOR:** `platform.tenant.reactivated` missing payload. Added
7. **A6 MAJOR:** Permission matrix not embedded. Added read model section with role→permission summary + exact file reference
8. **D1 MAJOR:** the password-history rule was tested only in the middle of its range, never at the edge. Added a scenario on each side of the threshold — the first value outside the window IS accepted, the last value inside it IS rejected. Any business rule with a boundary needs a test on both sides of it, or the off-by-one is invisible
9. **D2 MAJOR:** one tenant tier had no scenario at all — an entire enum branch untested. Added to platform-tenant.feature
10. **T2 MAJOR:** Domain vs integration events not distinguished. Added "Event Types" section to event model header
11. **T3 MAJOR:** Repository interfaces not defined. Added ICredentialRepository, IRefreshTokenRepository, ISessionRepository, IOidcProviderRepository, IUserRepository, IInvitationRepository, IRoleRepository, IRolePermissionRepository, ITenantRepository, ITenantConfigRepository, IFeatureFlagRepository
12. **CC1 MAJOR:** Identity↔Platform relationship not in context map. Added Partnership relationship + `acme.identity` exchange for `auth.*` events
13. **A2 MAJOR:** Suspension consumer ordering not defined. Added consumer ordering note in tenant-service section

## Still Escalated (overlap with previous review)

- **D4 CRITICAL:** the same three open questions as the requirements review — single vs multi-role, `businessUnitId`, and the role-permission policy question — affect 15 BDD scenarios. Already escalated.

## Not Fixed (acknowledged, defer to sprint)

- **D3 MAJOR:** No cross-service scenario for notification-service receiving invitation event. Notification-service doesn't exist at M1. Add contract test stub when notification-service is built.
- **CC2 MINOR:** `platform.user.*` naming implies Platform BC but events are from Identity BC. Document convention, don't rename.
