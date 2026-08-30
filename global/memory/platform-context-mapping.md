---
name: platform-context-mapping
description: Platform DDD bounded context map, event models, and tactical design pipeline — the architectural blueprint for the rebuild
type: project
---

## Platform Bounded Context Map (2026-03-24)

**9 bounded contexts**, 13 services, 67 entities. Full spec at `docs/platform/context-mapping/bounded-context-map.md`.

| BC | Type | Services | Entities |
|---|---|---|---|
| Trading | Core | trading + inventory | 21 |
| Finance | Supporting | accounting | 15 |
| Commission | Supporting (own BC) | commission | 5 |
| Identity | Generic | auth + user | 10 |
| Platform | Generic | tenant + gateway | 3 |
| Communication | Generic | notification + document | 6 |
| Compliance | Generic | audit | 1 |
| Analytics | Generic | reporting | 3 |
| AI/ML | Generic | ai | 4 |

**Why:** Services ≠ bounded contexts. The spec assigns BCs explicitly — Identity has 2 services (auth + user), Trading has 2 (trading + inventory), but they share a BC.

**How to apply:** When designing modules/epics, scope them to bounded contexts, not services. A module can contain multiple NestJS services within one BC.

## Source of Truth Hierarchy

1. CTO spec (docs site) → business/domain decisions
2. DDD best practices → structural decisions (BC boundaries)
3. Our discretion → technical decisions (modules, deployment)
4. Current code → migration reference ONLY, never a guide for Platform design

**Why:** Legacy code has 190 issues. Using its coupling patterns to drive Platform boundaries would inherit problems. Mid-session we caught ourselves merging auth+user "because they're coupled in code" — wrong reasoning.

**How to apply:** When making Platform architecture decisions, always check the spec first. Only reference code for "what currently exists" during migration mapping.

## Two Deviations from the Spec

1. **Commission as its own BC** — the spec folds it into Finance. DDD analysis: different aggregate root, different lifecycle, different vocabulary; it is already deployed as a separate service with its own database.
2. **Enriched `trading.line-item.finalised` event** — the spec pairs a minimal payload with a synchronous REST callback. We propose an enriched event instead, so the consumer never has to call back at runtime.

## DDD Tactical Design Pipeline (in DoR)

Added to `readiness-gate.md` as Rule 6. Six phases:

```
A: Event Modeling      → docs/platform/context-mapping/event-models/{bc}.md
B: Event Storming      → docs/platform/context-mapping/event-storming/{bc}.md (Core only)
C: Aggregate Design    → docs/platform/context-mapping/aggregates/{bc}.md
D: BDD Scenarios       → .feature files
E: Use Case Mapping    → docs/platform/context-mapping/use-cases/{bc}.md
F: Implementation      → code
```

Missing Phase A or C for Core/Supporting BCs = CRITICAL (blocks sync).

**Why:** Ensures no implementation starts without validated domain models.

## Event Modeling Schedule

| BC | Depth | Status | Needed Before |
|---|---|---|---|
| Identity + Platform | Light | Done (2026-03-24) | M1 Sprint 2 |
| Trading | Deep | Done (2026-03-24) | M2 Sprint 3 |
| Finance | Deep | Not started | M3 Sprint 5 |
| Commission | Medium | Not started | M3 Sprint 6 |
| Communication | Light | Not started | M3 Sprint 6 |
| Compliance, Analytics, AI/ML | Light | Not started | M4 Sprint 7-8 |

Each BC modeled one milestone ahead of implementation.

## Trading BC DDD Pipeline — Complete (2026-03-24)

All three design phases done for the Core subdomain:
- **Phase A (Event Model):** 526 lines — all commands, events, payloads, business rules
- **Phase B (Event Storming):** 1,048 lines — actors, 12-phase timeline, 15 policies, 5 hotspots, 4 process flows
- **Phase C (Aggregate Design):** 814 lines — 6 aggregates, 71 invariants, 15 value objects, 6 domain services, 9 repository interfaces

Remaining for Trading: Phase D (BDD scenarios) + Phase E (Use Case Mapping) before M2.

## Architecture Planning Status — READY TO IMPLEMENT (2026-03-24)

| AP | Status |
|---|---|
| AP-1 Architecture walkthrough | COMPLETE |
| AP-2 Technical decisions | COMPLETE (36 decisions) |
| AP-3 Monorepo structure | COMPLETE (28 libs, tags, boundaries) |
| AP-4 Schema design | PARTIAL (ORM patterns during Sprint 1) |
| AP-5 Development workflow | COMPLETE (DDD pipeline, CI/CD, testing) |
| AP-6 Sprint 1 backlog | COMPLETE (13 tasks, 110 BDD scenarios) |

Completeness audit passed after fixing 3 blockers (stale Redis refs, missing K8s decisions, undocumented auth model).
