# Readiness Gate

Validation protocol for verifying implementation readiness before syncing to GitHub.

## When to Run

Run `/pm:readiness-check <name>` after `epic-decompose` and `tests-generate`, before `epic-sync`. Required for Complex and Program flows. Optional for Standard. Skip for Quick.

## FR Coverage Matrix

Map every Functional Requirement from the PRD to task coverage:

```markdown
| FR ID | PRD Requirement | Task Coverage | Status |
|-------|----------------|---------------|--------|
| FR1   | User can register | #201, #203 | Full |
| FR2   | Reset password | NOT FOUND  | MISSING |
| FR3   | Admin disable | #204       | Partial |
```

### Building the Matrix
1. Extract ALL FRs from PRD "Functional Requirements" section (full text, no summaries)
2. Extract ALL Gherkin scenarios from PRD "Acceptance Criteria" section
3. For each FR/scenario, scan ALL task files for matching coverage
4. Mark: Full (≥1 task covers it), Partial (mentioned but incomplete), MISSING (no coverage)
5. Calculate: `coverage = (Full + Partial) / Total * 100`

## Validation Rules

### Rule 1: User-Facing Value
Tasks must describe user-visible outcomes. Reject: "Setup Database", "Configure CI", "Create Base Classes". Accept: "Users can view profile" (involves setup but delivers value).

### Rule 2: No Forward Dependencies
Task X cannot depend on unshipped tasks in other epics. Dependencies must flow backward to completed work. Check `depends_on` fields.

### Rule 3: BDD Acceptance Criteria
Every task must have Given/When/Then ACs, reference PRD Gherkin scenarios, or use `(AC: N)` cross-references on subtasks.

### Rule 4: Architecture Cohesion
If `architecture.md` exists: every implementation task must reference at least one architecture decision in Dev Notes. Task file patterns must align with architecture §4.

### Rule 5: Cross-Epic Dependencies (Multi-Milestone)
If `.claude/milestones/<program>/program.md` exists: check milestone dependency graph. Verify prerequisite milestones/epics are completed or in-progress.

### Rule 6: DDD Tactical Design Completeness

Each bounded context must complete a DDD tactical design pipeline before implementation begins. The pipeline has 6 phases — each phase gates the next. Check artifacts at `docs/platform/context-mapping/`.

**DDD Tactical Design Pipeline:**

```
Phase A: Event Modeling
    │     Command → Event flows + payload schemas + read models
    │     Output: event-models/{bc-name}.md
    │
    ├──► Phase A.1: Context Map (first epic per milestone)
    │     BC relationships with named patterns (ACL, OHS, Partnership, etc.)
    │     Output: context-map.md
    │
    ├──► Phase A.2: Bounded Context Canvas (per context)
    │     One-page BC summary: language, communication, rules, aggregates
    │     Output: canvases/{bc-name}.md
    │
    ├──► Phase B: Design-Level Event Storming (per context)
    │     Deep dive: actors, policies, hotspots, process flows
    │     Output: event-storming/{bc-name}.md
    │
    ├──► Phase C: Aggregate Design + Invariant Analysis
    │     Aggregate boundaries, consistency rules, invariants per aggregate
    │     Output: aggregates/{bc-name}.md
    │
    ├──► Phase C.1: Repository Contracts (per aggregate root)
    │     Domain-layer interfaces, persistence-ignorant, domain-named queries
    │     Output: documented in aggregates/{bc-name}.md or architecture.md
    │
    ├──► Phase D: BDD Scenarios → Acceptance Tests
    │     Gherkin scenarios derived from event model + aggregate invariants
    │     Output: .feature files in test directories
    │
    ├──► Phase D.0: Example Mapping (before BDD, Core + Supporting BCs)
    │     Rules → Examples → Counter-examples → Questions
    │     Output: example-maps/{bc-name}/{feature}.md
    │
    ├──► Phase E: Application Service / Use Case Mapping
    │     Map commands to application services, define ports and adapters
    │     Output: use-cases/{bc-name}.md
    │
    └──► Phase F: Implementation (Entities, VOs, Domain Events, Repos)
          Code the tactical patterns: entities, value objects, domain events,
          repositories, domain services, application services
          Output: working code
```

**Required phases by BC type:**

| BC Subdomain | Required Phases | Notes |
|---|---|---|
| Core (Trading) | A + A.1 + A.2 + B + C + C.1 + D.0 + D + E + F | Full pipeline — no shortcuts |
| Supporting (Finance, Commission) | A + A.1 + A.2 + C + C.1 + D.0(rec) + D + E + F | Event Storming optional, Example Mapping recommended |
| Generic (Identity, Platform, Communication, Compliance, Analytics, AI/ML) | A + A.1 + D + F | Light Event Model + BDD scenarios + implement |

**Artifact locations:**

| Phase | Location |
|---|---|
| A: Event Models | `docs/platform/context-mapping/event-models/{bc-name}.md` |
| A.1: Context Map | `docs/platform/context-mapping/context-map.md` |
| A.2: BC Canvas | `docs/platform/context-mapping/canvases/{bc-name}.md` |
| B: Event Storming | `docs/platform/context-mapping/event-storming/{bc-name}.md` |
| C: Aggregate Design | `docs/platform/context-mapping/aggregates/{bc-name}.md` |
| C.1: Repo Contracts | In `aggregates/{bc-name}.md` or `architecture.md` |
| D.0: Example Maps | `docs/platform/context-mapping/example-maps/{bc-name}/{feature}.md` |
| D: BDD Scenarios | Test directories (`.feature` files) |
| E: Use Case Mapping | `docs/platform/context-mapping/use-cases/{bc-name}.md` |
| Event Catalog | `docs/platform/context-mapping/event-catalog.md` |
| ACL Registry | `docs/platform/context-mapping/acl-registry.md` |
| F: Implementation | Source code |

**Timing:** Phases A–C are completed during Phase 1b (Architecture), after `/pm:arch-create`. Phase D.0 (Example Mapping) runs between Phase A and Phase D. Phase D aligns with Phase 2 (Test Scaffolding). Phase E bridges architecture to implementation. Phase F is Phase 4 (Implementation). Each BC completes phases A–C one milestone ahead of its implementation.

### Rule 7: Context Map Completeness

If multiple BCs are involved in the epic:
- A Context Map must exist at `docs/platform/context-mapping/context-map.md`
- Every BC relationship must use a named pattern (Shared Kernel, Customer-Supplier, Conformist, ACL, OHS, Published Language, Partnership, Separate Ways)
- New BCs introduced by this epic must be added to the context map

### Rule 8: Anti-Corruption Layer for Legacy Dependencies

If any task in the epic requires data from legacy Express/TypeORM modules:
- An ACL adapter must be designed (port interface in domain layer, adapter in infrastructure)
- No direct imports from `apps/legacy-api/` in new NestJS modules
- ACL tracked in `docs/platform/context-mapping/acl-registry.md`
- ACL lifecycle documented (created when, removed when)

### Rule 9: Domain Event Infrastructure

If the epic's BC produces or consumes domain events:
- Domain Event infrastructure pattern must be decided in master architecture (or per-epic architecture)
- Event catalog entry must exist for every event the epic produces
- Events must follow the standard envelope (eventId, eventType, aggregateId, version, payload, metadata)
- Event versioning strategy documented for events with existing consumers

### Rule 10: Example Mapping Coverage (Core + Supporting BCs)

For Core BCs: Example Mapping must be completed before BDD scenario writing.
For Supporting BCs: Example Mapping is recommended but not blocking.
- Each business rule from Event Model should have ≥2 examples and ≥1 counter-example
- Unresolved questions must be marked as RESOLVED or explicitly deferred

### Rule 11: Kubernetes Manifest Validation

If the epic deploys to Kubernetes:
- Helm values file must exist in `charts/values/{service}.yaml`
- Values must define: `resources` (requests + limits), `livenessProbe`, `readinessProbe`
- Init container must be configured for services with DB migrations (ADR-0015)
- No `latest` image tag — must use SHA or semantic version
- No plaintext secrets in values — must use ExternalSecret (ADR-0020)

### Rule 12: Event Contract Validation

If the epic produces or consumes integration events:
- Every event in architecture.md §6.3 must have a matching contract in `@acme/event-contracts`
- Event contracts must include `version` field (starting at 1)
- Event metadata must include `tenantId`
- Event names must be past tense
- Consumer must have idempotency guard (processed_events table)

## Severity Tiers

### CRITICAL (blocks sync)
- Missing FR coverage (any FR with status MISSING)
- Forward dependency on unshipped epic
- Task with zero acceptance criteria
- Architecture decision contradicted by task
- **DDD Phase A missing:** No Event Model exists for the epic's bounded context
- **DDD Phase A incomplete:** Event Model exists but missing payload schemas for events the epic produces
- **DDD Phase C missing (Core/Supporting):** No Aggregate Design exists for Core or Supporting BC
- **DDD Phase D missing:** No BDD scenarios (.feature files) exist for the epic's acceptance criteria
- **Context Map missing (Rule 7):** Multi-BC epic has no context map, or new BC not added to map
- **ACL violation (Rule 8):** Task imports directly from legacy `apps/legacy-api/` without ACL adapter design
- **Domain Event infrastructure undecided (Rule 9):** Epic produces events but no infrastructure pattern chosen in architecture

### MAJOR (warn, recommend fix)
- Single-coverage FR (only one task covers it)
- No architecture reference when architecture.md exists
- Task estimated XL or larger (should break down)
- Cross-epic dep on in-progress (not completed) epic
- Partial FR coverage
- **DDD Phase A depth:** Event Model at lower depth than required for the BC type
- **DDD Phase B missing (Core):** No Event Storming output for Core BC
- **DDD Phase E missing (Core/Supporting):** No Use Case Mapping for Core or Supporting BC
- **Context Map relationship untyped (Rule 7):** BC relationship exists but no named pattern assigned
- **ACL lifecycle undocumented (Rule 8):** ACL exists but no removal criteria documented
- **Event catalog missing (Rule 9):** Epic produces events not listed in event catalog
- **Event version missing (Rule 9):** Event schema has no version number
- **Example Mapping missing for Core BC (Rule 10):** Core BC business rules have no example maps
- **BC Canvas missing (Core/Supporting):** No Bounded Context Canvas for Core or Supporting BC
- **Repository contracts undefined (Core/Supporting):** No domain-layer repository interfaces for aggregate roots

### MINOR (note)
- Missing effort estimates
- Naming inconsistencies
- Optional AC missing
- Task description shorter than 2 sentences
- DDD artifacts not updated since last BC boundary change
- **Example Mapping missing for Supporting BC (Rule 10):** Recommended but not blocking
- **BC Canvas missing for Generic BC:** Optional but recommended for developer onboarding
- **Unresolved Example Mapping questions:** Questions marked PENDING without explicit deferral reason
- **Event catalog out of date:** Catalog doesn't reflect latest event model changes
- **Helm values missing for deployed service (Rule 11):** Service deploys to K8s but no values file
- **Event contract missing version (Rule 12):** Integration event contract has no version number
- **Consumer missing idempotency guard (Rule 12):** Event consumer has no processed_events check

## Verdict Criteria

| Verdict | Condition | Action |
|---------|-----------|--------|
| READY | 0 CRITICAL, ≤2 MAJOR | Proceed to `/pm:epic-sync` |
| NEEDS WORK | 0 CRITICAL, 3+ MAJOR | List findings, allow proceed or fix |
| NOT READY | 1+ CRITICAL | Block sync, user can override with "override" |

## User Override

If NOT READY, present findings and require explicit "override" confirmation. Log override in readiness report.

## Readiness Report Format

At `.claude/epics/<name>/readiness-report.md`:

```yaml
---
checked: <ISO datetime>
epic: <name>
verdict: READY | NEEDS_WORK | NOT_READY
critical_count: 0
major_count: 2
minor_count: 3
fr_coverage: 95%
overridden: false
---
```

Body: FR Coverage Matrix, Findings by severity, Verdict, Next Steps.
