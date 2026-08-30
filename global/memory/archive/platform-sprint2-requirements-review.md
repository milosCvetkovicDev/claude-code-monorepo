---
name: Platform Sprint 2 Requirements Review
description: Comprehensive cross-reference review of T8/T9/T10 specs — 11 of 15 questions resolved architecturally, 4 escalated
type: project
---

Sprint 2 requirements review completed 2026-03-25. Cross-referenced task files, PRD, event models, BDD scenarios, CTO spec pages, and architecture docs.

**Why:** Need 100% clarity before implementation. Found contradictions within the CTO spec itself.

**How to apply:** Reference resolved decisions in task files (207.md, 208.md, 209.md "Sprint 2 Requirements Review" sections). Check pending CTO decisions before starting implementation.

## 4 Escalated Questions — all resolved

Every decision below was marked "may be revised" in the specs it touched.

1. **Multi-role RBAC** — UserRole join table, NO UNIQUE on userId, JWT `roles: string[]`, permissions = union. BDD updated.
2. **`businessUnitId` OMITTED from M1 JWT** — searched all docs/platform/ files, found in exactly 3 files (auth architecture + auth service + gateway), NO backing entity anywhere. Omit a claim until something exists that can populate it.
3. **No periodic password expiry (NIST SP 800-63B aligned)** — NIST Rev 4 says SHALL NOT require periodic changes. Microsoft/Auth0/AWS all agree. Store `passwordChangedAt`, make `maxPasswordAgeDays` configurable per tenant (default: disabled). Invest in breached password detection + MFA instead.
4. The fourth was pure authorisation policy — which role may perform a privileged domain action, and which may read across scopes. That is the business's call, not the architecture's, and the answer is not part of this export; what carried over here is only that the BDD scenarios were corrected to match it.

## 11 Resolved Decisions (architect-level, no CTO input needed)

- **Q4 MFA challenge:** Redis token, 5min TTL, standard timeout → re-authenticate
- **Q5 Onboarding:** Manual checklist, no cross-service validation. All 5 steps at M1
- **Q6 tenant.purge event:** Doc gap — added payload schema to event model
- **Q8 Credential creation:** Port interface within Identity BC. Password never on event bus
- **Q9 Auth↔User calls:** HTTP internal endpoints per spec (/internal/users/:id/auth-context)
- **Q10 Event bus:** Real RabbitMQ with transactional outbox (confirmed by user)
- **Q11 auth.oidc.failed:** Doc gap — added event to event model (3 BDD scenarios reference it)
- **Q12 OIDC allowedDomains:** Invalid question — column doesn't exist in OidcProvider entity
- **Q13 Session lastActivityAt:** Tracking field only, no sliding expiry
- **Q14 API keys:** Defer to later sprint. AGENT role seeded at M1, authenticates via login
- **Q15 Tenant limits:** Store all in JSONB, enforce maxUsers only at M1

## Docs Updated

- `.claude/epics/platform-m1-platform-foundation/207.md` — resolved decisions + pending CTO items
- `.claude/epics/platform-m1-platform-foundation/208.md` — resolved decisions for tenant-service
- `.claude/epics/platform-m1-platform-foundation/209.md` — resolved decisions + pending CTO items
- `docs/platform/context-mapping/event-models/identity-platform.md` — added auth.oidc.failed + platform.tenant.purge
