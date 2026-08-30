# Platform Workflow Guide

Concrete examples for using the enhanced CCPM workflow with the Platform migration program (Express to NestJS).

## 1. Program Setup

Initialize Platform as a multi-milestone program:

```
/pm:milestone-init platform
```

The interactive flow reads the programme's strategy document and turns each milestone into a
directory. Six is what this one produced; the shape that matters is the ordering rule, not the
count — foundation before migration, low-dependency domains before core ones, retirement of the
old runtime only once nothing still routes to it, hardening last:

- M1: Foundation & quick wins — logging, DB indexes, auth, caching
- M2: Migration phase 1 — scaffold plus the reference-data domains
- M3: Migration phase 2 — the core transactional domains and the external-system integration
- M4: Complete & optimise — the remaining domains
- M5: Infrastructure — retirement of the legacy runtime, caching, right-sizing
- M6: Hardening — load testing, verification, sign-off

Creates:

```
.claude/milestones/platform/
  program.md                    # 6 milestones, dependency graph, KPIs
  master-architecture.md        # Stub — populated by first arch-create
  project-context.md            # Migration state tracking
  milestones/m1-foundation/milestone.md
  milestones/m2-nestjs-phase1/milestone.md
  milestones/m3-nestjs-phase2/milestone.md
  milestones/m4-complete/milestone.md
  milestones/m5-infrastructure/milestone.md
  milestones/m6-hardening/milestone.md
```

## 2. Master Architecture (One-Time, First Epic)

```
/pm:prd-new nestjs-reference-data
/pm:prd-parse nestjs-reference-data
/pm:arch-create nestjs-reference-data
```

Since master architecture is a stub, `arch-create` creates BOTH:

- `.claude/milestones/platform/master-architecture.md` — shared decisions
- `.claude/epics/nestjs-reference-data/architecture.md` — epic-specific

Master captures project-wide decisions:

- Data: PostgreSQL + MikroORM, DDD entity modeling
- API: NestJS 11 REST with @nestjs/swagger
- Auth: Local JWT validation with jose (replacing Azure-dependent auth)
- Frontend: React 18 + MUI 5 (unchanged — backend migration only)
- Infrastructure: Azure Container Apps (unchanged)
- Patterns: DDD + Clean Architecture (domain/application/infrastructure)
- Anti-patterns: Never import from Express modules, never use TypeORM in new code

**DDD Practices decisions (new — resolved during first arch-create):**

- Domain Event Infrastructure: Aggregate Domain Events (Option C) — events collected in entity, published after MikroORM flush
- ACL Strategy: Port interface in domain layer, adapter in infrastructure, tracked in `acl-registry.md`
- Domain Logic Placement: invariants in entities, cross-aggregate in domain services, orchestration in app services
- Event Versioning: version number on every event, upcasters for breaking changes, catalog at `event-catalog.md`
- Context Map: created at `docs/platform/context-mapping/context-map.md` with typed relationships

**DDD artifacts created:**

- `docs/platform/context-mapping/context-map.md` — BC relationships
- `docs/platform/context-mapping/event-catalog.md` — all domain events
- `docs/platform/context-mapping/acl-registry.md` — legacy adapters tracking

ADRs created in `docs/adr/`:

- ADR-0012: NestJS modular monolith architecture
- ADR-0013: MikroORM for new modules (replacing TypeORM)
- ADR-0014: Strangler fig migration pattern
- ADR-0015: Domain Event infrastructure (Aggregate Domain Events pattern)

## 3. Epic Lifecycle (Per Module Migration)

Example: Migrating Countries + Currencies (Milestone M2)

### Step 1: Requirements

```
/pm:prd-new nestjs-countries-currencies
```

PRD includes Gherkin scenarios for all CRUD operations + API compatibility.

### Step 2: Technical Epic

```
/pm:prd-parse nestjs-countries-currencies
```

### Step 3: Architecture + DDD Design (inherits from master)

```
/pm:arch-create nestjs-countries-currencies
```

- Shows: "Inherited from master: NestJS + MikroORM + DDD. Override? [Enter to accept]"
- Epic-specific decisions: module file structure, data migration strategy
- Creates ADR if alternatives were seriously considered

**DDD practices executed during arch-create:**

- **Context Map update** (Practice 1): Adds Reference Data BC relationships to context map
  - Reference Data → Trading: Customer-Supplier (Trading consumes product/customer data)
  - Reference Data → Legacy Express: ACL (reads legacy data during migration)
- **BC Canvas** (Practice 5): Creates `docs/platform/context-mapping/canvases/reference-data.md`
  - Ubiquitous language: Country, Currency, Product, ProductGroup
  - Inbound: CRUD commands from API Gateway
  - Outbound: ProductCreated, CurrencyRateUpdated events
- **ACL Assessment** (Practice 2): Reference Data needs legacy customer data
  - Port: `LegacyReferenceDataPort` in domain layer
  - Adapter: `TypeOrmReferenceDataAdapter` in infrastructure
  - Tracked in `acl-registry.md` — removal when M2 migration complete
- **Repository Contracts** (Practice 9): Domain interfaces for Country, Currency, Product aggregates
- **Domain Logic Placement** (Practice 3): Documented in architecture.md §6.4
  - Currency conversion invariants → CurrencyRate value object
  - Product validation → Product aggregate root
  - Cross-product rules → ProductGroupService domain service

### Step 4: Decompose (enhanced tasks)

```
/pm:epic-decompose nestjs-countries-currencies
```

Creates 6 tasks, each with:

- AC cross-refs: `- [ ] Create Country entity (AC: 1, 2)`
- Dev Notes referencing `architecture.md §3.1` and `master-architecture.md §2`
- Dev Agent Record section (empty, filled by implementing agent)
- File Modification Rules section

Output suggests: "6 tasks, 1 domain — Recommended: Complex flow"

### Step 5a: Example Mapping (Practice 6 — Supporting BC, recommended)

Before writing BDD scenarios, run Example Mapping for key business rules:

```markdown
## Example Map: Retention Window Selection

### RULE: A record is purged under the retention policy in force when it was created

#### EXAMPLES:

- Given the policy was 30 days when the record was created, When the purge job runs, Then the record is purged at 30 days
- Given the policy later changed to 90 days, When the purge job runs, Then that record still purges at 30 days

#### COUNTER-EXAMPLES:

- Given no policy was in force at creation, When purge is attempted, Then the record is skipped and flagged (it must NOT fall back to today's policy)

#### QUESTIONS:

- Does an explicit legal hold override the creation-time policy? → RESOLVED: hold wins
- What about records imported without a creation timestamp? → PENDING: ask domain expert
```

Output: `docs/platform/context-mapping/example-maps/<bc>/<rule>.md`

The shape is what matters: one rule per map, concrete examples, at least one counter-example
(the fallback that looks helpful and is wrong), and questions marked RESOLVED or PENDING so an
unanswered one cannot be quietly assumed away in the test.

### Step 5b: Test Scaffolding (RED)

```
/pm:tests-generate nestjs-countries-currencies
```

Gherkin scenarios derived from Example Maps + Event Model. Unresolved questions from Example Mapping become TODO comments in test stubs.

### Step 6: Readiness Gate

```
/pm:readiness-check nestjs-countries-currencies
```

- FR Coverage Matrix: 10/10 FRs covered (100%)
- Cross-epic check: M1 foundation completed
- Architecture cohesion: all tasks reference architecture
- **Context Map: ✅** Reference Data BC added with typed relationships (Rule 7)
- **ACL designed: ✅** LegacyReferenceDataPort interface defined (Rule 8)
- **Domain Event contracts: ✅** ProductCreated, CurrencyRateUpdated in event catalog (Rule 9)
- **Example Mapping: ✅** 3 feature maps completed, 1 pending question deferred (Rule 10)
- **BC Canvas: ✅** reference-data canvas created
- Verdict: READY

### Step 7: Sync & Implement

```
/pm:epic-sync nestjs-countries-currencies
/pm:issue-analyze 201
/pm:issue-start 201
```

Agent loads:

- `project-context.md` (migration state: Countries=in-progress)
- `master-architecture.md §2` (DDD patterns)
- `architecture.md §3` (naming conventions)
- `architecture.md §6` (DDD design — context map, ACL, events, logic placement, repo contracts)
- `docs/platform/context-mapping/canvases/reference-data.md` (BC canvas)
- `docs/platform/context-mapping/event-catalog.md` (events to produce)
- Previous Issue Intelligence (from issue #200 if available)

**DDD practices applied during implementation (Phase F):**

- Agent uses **repository contracts** from §6.5 — implements MikroORM versions behind domain interfaces
- Agent follows **domain logic placement** from §6.4 — invariants in entities, not services
- Agent uses **ACL adapter** from §6.2 — reads legacy data through port, not direct import
- Agent implements **aggregate domain events** — `this.addDomainEvent(new ProductCreated(...))` in entity
- Agent creates **factories** for complex aggregates (Practice 8) if creation involves lookups
- Agent uses **specifications** for combinable business rules (Practice 7) if 3+ rules
- **ddd-expert agent** reviews during implementation for anemic model, ACL violations, leaky boundaries

### Step 8: Review with Triage

```
/pm:epic-review nestjs-countries-currencies
```

- Layer 1 (Blind): 14 findings (adversarial-reviewer, diff only)
- Layer 2 (Context): 6 edge cases (edge-case-hunter)
- Layer 3 (Existing): 3 bugs, 2 quality items (code-analyzer + code-reviewer)
- **DDD review** (ddd-expert agent): anemic model check, ACL violations, repository contracts, event design
- Triage: 4 patches, 2 decisions, 8 deferred, 9 dismissed
- User resolves 2 decisions, batch-applies 4 patches

### Step 9: Merge & Verify

```
/pm:epic-merge nestjs-countries-currencies
/pm:prod-verify nestjs-countries-currencies
/pm:epic-close nestjs-countries-currencies
```

### Step 10: Update Context

```
/pm:project-context
```

Updates migration state: Countries=migrated, Currencies=migrated

## 4. Cross-Milestone Dependencies

```
/pm:readiness-check nestjs-invoices
```

Cross-epic dependency check:

- MAJOR: This epic references Customers entity from M2
- Customers epic status: in-progress (70% complete)
- Risk: Customers API contract may change before this epic ships
- Recommendation: Wait for Customers epic-close, or pin to current API contract

User can: wait, override, or pin to current version.

## 5. Architecture Evolution

During M3, the team discovers Drizzle has a critical bug affecting migrations.
Decision: Switch to Prisma for remaining modules.

```
/pm:arch-create nestjs-purchases
```

In Data Architecture category:

- "Master architecture specifies Drizzle ORM. Override? (yes/no)"
- User: yes
- Creates ADR-0019: Switch from Drizzle to Prisma (Supersedes ADR-0013 partially)
- Updates master-architecture.md: "Drizzle (M2 modules) / Prisma (M3+ modules)"

## 6. Migration State Tracking

Mid-project state (during M3):

```
/pm:project-context
```

Updates `.claude/project-context.md`:

```
## Migration State
| Domain | Current Stack | Target | Status | Milestone |
|--------|--------------|--------|--------|-----------|
| Countries | NestJS + Drizzle | — | migrated | M2 |
| Currencies | NestJS + Drizzle | — | migrated | M2 |
| Units | NestJS + Drizzle | — | migrated | M2 |
| Products | NestJS + Drizzle | — | migrated | M2 |
| ProductGroups | NestJS + Drizzle | — | migrated | M2 |
| Customers | NestJS + Prisma | — | in-progress | M3 |
| Sales | Express + TypeORM | NestJS + Prisma | planned | M3 |
| Invoices | Express + TypeORM | NestJS + Prisma | planned | M3 |
| Deals | Express + TypeORM | NestJS + Prisma | planned | M4 |
| Stock | Express + TypeORM | NestJS + Prisma | planned | M4 |
```

Agents use this to:

- Follow Drizzle patterns for M2 modules, Prisma for M3+
- Know which services are available on NestJS vs still on Express
- Avoid importing from Express modules when NestJS equivalents exist

## 7. Review Triage in Practice

```
/pm:epic-review nestjs-customers
```

Output:

```
REVIEW TRIAGE SUMMARY
Layers: Blind(14) + EdgeCase(6) + Analyzer(3) + Reviewer(2) = 25 raw
After dedup: 18 unique
Classified:
  Patches (auto-fixable):     4
  Decisions needed:           2
  Deferred (pre-existing):    8
  Dismissed (noise):          4

DECISIONS NEEDED (2):
#1 [blind+edge] customer.service.ts:89
   Soft-delete vs hard-delete for inactive customers?
   Context: Express uses soft-delete. PRD doesn't specify.
   Choose: [S]oft-delete / [H]ard-delete / [D]efer

#2 [edge] customer.repository.ts:45
   findAll() has no pagination — 500 customers today, what about 5000?
   Context: Master arch says "paginate lists >100 items".
   Choose: [P]aginate now / [D]efer (follow-up issue)

PATCHES (4) — apply all? [Y/n]:
#3 customer.controller.ts:23 — Missing @ApiResponse(404)
#4 customer.service.ts:112 — Unguarded null on optional field
#5 customer.e2e.spec.ts:67 — Assertion checks status but not body
#6 customer.dto.ts:15 — Zod allows empty string for name

DEFERRED (8) — pre-existing (D to view)
DISMISSED (4) — noise (X to view)
```

## 8. Quick Flow for Small Fixes

During Platform, small fixes still use Quick flow:

```
/pm:prd-new fix-exchange-rate-rounding
/pm:prd-parse fix-exchange-rate-rounding
/pm:epic-decompose fix-exchange-rate-rounding
```

2 tasks created — "Recommended: Quick flow"

```
/pm:tests-generate fix-exchange-rate-rounding
/pm:epic-sync fix-exchange-rate-rounding
/pm:issue-start 210
/pm:issue-close 210
/pm:epic-review fix-exchange-rate-rounding
/pm:epic-merge fix-exchange-rate-rounding
```

No arch-create, no readiness-check — the feature is small enough.

## Domain-to-Module Migration Sequence

Epics are ordered by **controller dependency analysis**, not by business priority: build the
call graph of the legacy controllers, count inbound edges per domain, and migrate the sinks
first. A domain nothing else reads can be cut over behind a route rewrite; a domain that six
other controllers read cannot, until those six are either migrated or fronted by an ACL.

The sequence that falls out has the same shape in every strangler migration:

```
M2 — sinks and scaffolding (nothing depends on these, or they are cross-cutting):
  Epic: nestjs-shared-module   -> auth, config, DB connection, health checks
  Epic: nestjs-testing-infra   -> test harness, OpenAPI generation
  Epic: nestjs-reference-data  -> the read-mostly lookup domains
  Epic: nestjs-<entity>-start  -> one core entity, CRUD only, to prove the pattern

M3 — core transactional domains (high inbound-edge count):
  Epic: nestjs-<entity>-complete -> the same entity, full behaviour
  Epic: nestjs-<domain>-a        -> a core aggregate and its documents
  Epic: nestjs-<domain>-b        -> its counterpart aggregate
  Epic: nestjs-external-sync     -> third-party integration, tokens, ACL
  Epic: nestjs-background-jobs   -> job runner migration

M4 — the remaining domains, in any order (all now depend only on migrated code)

M5 — infrastructure:
  Epic: legacy-retirement       -> remove the old app, redirect all traffic
  Epic: performance-optimization -> caching, connection pooling

M6 — hardening:
  Epic: final-verification      -> load testing, sign-off
```

Two rules earn their place here. **The scaffolding epic is not milestone zero** — it ships in
the same milestone as the first real domain, because a shared module written before anything
consumes it is written against guesses. And **one entity is deliberately split across two
milestones** (`-start` / `-complete`): the first pass proves the migration pattern on a real
domain object at CRUD depth, and everything learned there is priced into the estimates for the
rest. Splitting the *first* core entity is cheap; discovering the pattern is wrong on the fifth
is not.

Sizing: expect an epic to decompose into 4–8 tasks. If it produces more, it is two epics that
have not been separated yet.

## DDD Practice Adoption by Milestone

| Practice | M1 (Generic BCs)         | M2 (Supporting)                | M3+ (Core)                     |
| ------------------------------ | ------------------------ | ------------------------------ | ------------------------------ |
| #1 Context Map | Create initial map | Update with new BCs | Update with Core relationships |
| #2 ACL Strategy | Design for legacy access | Active ACLs for Reference Data | ACLs for Trading/Invoicing |
| #3 Domain Service Guidelines | Optional | Apply to business logic | Strictly enforced |
| #4 Domain Event Infrastructure | Decide pattern | First events published | Full event-driven flows |
| #5 BC Canvas | Optional | Create per Supporting BC       | Required per Core BC           |
| #6 Example Mapping | Skip (Generic)           | Recommended | Required |
| #7 Specification Pattern | Skip | Optional | When 3+ combinable rules |
| #8 Factory Pattern | Skip | Optional | When complex creation |
| #9 Repository Contracts | Define interfaces | Implement MikroORM repos | Strict aggregate root only |
| #10 Event Versioning | Define strategy | First version tracking | Upcasters for breaking changes |

Full DDD practices reference: `/rules/ddd-practices.md`

## Plugin Integration Quick Reference

| When | Plugin/Skill | Purpose |
| --------------------- | -------------------------------------------- | ---------------------------------------- |
| Before arch-create | `superpowers:brainstorming`                  | Explore problem space |
| Before arch-create | `qodo-skills:qodo-get-relevant-rules`        | Load coding standards |
| During arch-create | Acme agents (ddd-expert, api-designer)     | Expert input + DDD practices |
| After arch-create | Context Map, BC Canvas, ACL assessment | DDD artifacts (Practices 1, 2, 5)        |
| Before tests-generate | Example Mapping (Core/Supporting BCs)        | Edge case discovery (Practice 6)         |
| Before issue-start | `superpowers:test-driven-development`        | TDD enforcement |
| During implementation | ddd-expert agent | Anemic model, ACL, repo contracts review |
| After implementation | `superpowers:verification-before-completion` | Evidence-based check |
| During epic-review | `pr-review-toolkit:review-pr`                | 6 additional review agents |
| During epic-review | ddd-expert agent | Domain model integrity review |
| After PR creation | `code-review:code-review`                    | Posts review to GitHub |
| Before merge | `superpowers:finishing-a-development-branch` | Pre-merge checklist |

## M2 Preparation: Milestone Transition Checklist

Concrete steps for transitioning from M1 (Platform Foundation) to M2 (Traders Can Execute Deals).

### Phase 0: M1 Completion (prerequisites)

M2 **cannot start** until M1 is complete. M1 Sprint 2 runs in its own separate session/worktree.

**M1 Sprint 2 checklist** (run in a dedicated session):

1. Clear the open decision blockers raised in review — none of them may be assumed away
2. Apply the outstanding review patches from `review-report.md`
3. `acme-worktree create m1-sprint2 epic/platform-m1-platform-foundation` → separate session
4. Implement issues #207–#211 (auth, tenant, user, tenant-isolation, integration tests)
5. Review → merge → verify → close → `acme-worktree remove m1-sprint2`
6. `/pm:project-context` — update migration state (auth, tenant, user = migrated)

**Verify M1 is done before proceeding:**

```bash
gh issue list --label platform-m1 --state open --json number,title
# Should return empty — all 13 issues closed
```

### Phase 0b: State Sync (fix stale files)

Before starting M2, sync files that drifted during M1:

```
# ✅ DONE (2026-03-27): master-architecture.md fully synced
#   All 14 pending decisions moved to confirmed. Status: active.
#   ADRs 0017-0020 created (RabbitMQ, Outbox, OTel, ESO)
#   All agents updated with Platform dual-stack sections
#   6 new agents created (nestjs, mikroorm, event-driven, kubernetes, redis, observability)
#   5 new hooks + ESLint security + SonarQube configured

# Still needed:
# Update program.md:
#   - M1 status: in-progress → completed
#   - Add M1 epic to epics-by-milestone section
#   - Update milestones_completed: 0 → 1

# Update milestone m1 file:
#   - Status: in-progress → completed
#   - completed_epics: 0 → 1

# Verify project-context.md migration state reflects reality

# Install ESLint security plugins (run once):
#   npm install -D eslint-plugin-security eslint-plugin-no-secrets
```

### Phase 1: M2 Requirements

M2 scope: Core trading workflow + reference data. This is **Complex flow** (multi-domain, 8+ tasks expected).

```
# 1a. Read CTO specifications
#     Primary sources in docs/platform/doc-site/:
#     - features/trading.md (66KB — deal lifecycle, purchases, sales)
#     - features/reference-data.md (customers, products, currencies)
#     - services/trading.md (service architecture)
#     - services/data-model.md (entity relationships)
#     - legacy/platform-issues/issues-summary.md (190 defects to address)

# 1b. Brainstorm scope and approach
/superpowers:brainstorming                  # explore trading domain, edge cases, DDD boundaries

# 1c. Create PRD(s) — split by BC type
#     Option B (recommended): Two epics — different DDD depth required.
#       - nestjs-reference-data (Countries, Currencies, Products, Customers) → Supporting BC
#       - nestjs-trading-core (Deals, Purchases, Sales) → Core BC

/pm:prd-new nestjs-reference-data           # Supporting BC — CRUD + API compatibility
/pm:prd-new nestjs-trading-core             # Core BC — full DDD treatment

# 1d. Parse PRDs to structured epics
/pm:prd-parse nestjs-reference-data
/pm:prd-parse nestjs-trading-core
```

### Phase 1b: Architecture + DDD Tactical Design

```
# 2a. Load coding standards
/qodo-skills:qodo-get-relevant-rules

# 2b. Architecture for first epic (Reference Data — simpler, sets patterns)
/pm:arch-create nestjs-reference-data
#     Inherits from master-architecture.md
#     Epic-specific: module file structure, MikroORM entity design, data migration
#
#     DDD practices to execute during arch-create:
#     - Context Map update (Practice 1): Add Reference Data BC relationships
#       Reference Data → Trading: Customer-Supplier
#       Reference Data → Legacy Express: ACL
#     - BC Canvas (Practice 5): docs/platform/context-mapping/canvases/reference-data.md
#     - ACL Assessment (Practice 2): Reference Data needs legacy customer/product data
#       Port: LegacyReferenceDataPort, Adapter: TypeOrmReferenceDataAdapter
#     - Repository Contracts (Practice 9): Country, Currency, Product, Customer repos
#     - Domain Logic Placement (Practice 3): What goes in entities vs services

# 2c. Architecture for Core BC
/pm:arch-create nestjs-trading-core
#     Full DDD pipeline required (Core BC):
#     - Context Map update: Trading → Invoicing (Partnership), Trading → Stock (Customer-Supplier)
#     - BC Canvas: docs/platform/context-mapping/canvases/trading.md
#     - Event Modeling (Phase A): Deal lifecycle events, Purchase/Sale events
#     - Event Storming (Phase B): Required for Core — actors, policies, hotspots
#     - Aggregate Design (Phase C): Deal, Purchase, Sale aggregate boundaries
#     - Repository Contracts (Phase C.1): Domain interfaces per aggregate
#     - ACL Assessment: Trading needs legacy exchange rates, customer credit data
#     - Domain Logic Placement: Deal.confirm(), PricingService, CreateSaleUseCase
#     - Event Catalog entries: DealCreated, DealConfirmed, StockAllocated, etc.

# 2d. Decompose into tasks
/pm:epic-decompose nestjs-reference-data
/pm:epic-decompose nestjs-trading-core
```

### Phase 2: Test Scaffolding + Example Mapping

```
# 3a. Example Mapping for Core BC (Required — Practice 6)
#     Run one 25-minute example mapping session per core invariant, timeboxed,
#     one rule per map. Take each rule from the feature spec verbatim; do not
#     paraphrase it into the session, and do not invent the ones nobody wrote down.
#     Output: docs/platform/context-mapping/example-maps/trading/{feature}.md

# 3b. Example Mapping for Supporting BC (Recommended)
#     Same session, lower bar: the supporting BCs' rules are usually lookup and
#     hierarchy rules, so one map per aggregate is enough.
#     Output: docs/platform/context-mapping/example-maps/reference-data/{feature}.md

# 3c. Generate tests (RED phase)
/pm:tests-generate nestjs-reference-data
/pm:tests-generate nestjs-trading-core
```

### Phase 2b: Readiness Gate

```
# 4a. Readiness check — Complex flow, REQUIRED
/pm:readiness-check nestjs-reference-data
#     Validates: FR coverage, architecture cohesion, DDD artifacts
#     Rules checked: Context Map (Rule 7), ACL (Rule 8),
#     Domain Events (Rule 9), Example Mapping (Rule 10)

/pm:readiness-check nestjs-trading-core
#     Full DDD pipeline validation for Core BC:
#     Phase A (Event Model): CRITICAL if missing
#     Phase B (Event Storming): MAJOR if missing for Core
#     Phase C (Aggregates): CRITICAL if missing for Core
#     Phase D.0 (Example Maps): MAJOR if missing for Core
#     BC Canvas: MAJOR if missing for Core
```

### Phase 3: Sync + Worktree Setup

**One worktree for all M2 work.** Both epics (reference-data + trading-core) live on the same branch in the same worktree. This keeps all M2 code together and avoids cross-worktree coordination.

```
# 5a. Sync both epics to GitHub (creates issues, renames task files)
/pm:epic-sync nestjs-reference-data
/pm:epic-sync nestjs-trading-core
#     epic-sync creates bare git worktrees at ../epic-<name>.
#     We replace them with a single Acme worktree.

# 5b. Remove the bare worktrees epic-sync created
git worktree remove ../epic-nestjs-reference-data 2>/dev/null
git worktree remove ../epic-nestjs-trading-core 2>/dev/null
git branch -D epic/nestjs-reference-data 2>/dev/null
git branch -D epic/nestjs-trading-core 2>/dev/null

# 5c. Create a single Acme worktree for all M2 work
acme-worktree create m2 feat/platform-m2
#     → Creates ~/projects/acme-m2
#     → Symlinks .claude/ from primary ~/projects/acme/
#     → Auto-assigns instance number + ports
#     → Writes all 7 env files (backend, frontend, docker, e2e, commission)
#     → Branch: feat/platform-m2

# 5d. Open a separate Claude session in the worktree
acme-worktree open m2
#     → Creates/attaches tmux session + launches Claude Code
#     → All hooks fire (settings.json is in symlinked .claude/)
#     → Full context window dedicated to M2 work
```

**Why one worktree, not two:**

- Both epics share the same platform libs from M1
- Reference Data entities are imported by Trading module — easier if co-located
- Single branch = single PR = single CI run
- Avoids merge conflicts between worktrees touching shared types

**Why acme-worktree over plain `git worktree` / `epic-start-worktree`:**

- Port isolation (unique backend/frontend/DB ports — can run alongside primary Acme)
- Env files auto-generated from primary instance secrets (no manual Keeper lookups)
- `.claude/` symlinked (agents, hooks, skills, settings always in sync with primary)
- Instance registered in `multi-instance.config.json` for tracking
- `acme-worktree open` gives tmux session with Claude pre-launched

**Worktree layout:**
| What | Path | Branch |
|------|------|--------|
| Primary repo | `~/projects/acme` | `main` |
| M1 Sprint 2 (separate session) | `~/projects/acme-m1-sprint2` | `epic/platform-m1-platform-foundation` |
| M2 (separate session) | `~/projects/acme-m2` | `feat/platform-m2` |

### Phase 4: Implementation (inside M2 worktree session)

Both epics run in the same session. Reference Data first (simpler, sets patterns), then Trading Core.

```
# Session setup (run once when opening the M2 worktree session)
/context:prime                              # load project context
/pm:project-context                         # load migration state for agents
/qodo-skills:qodo-get-relevant-rules        # load coding standards

# --- Epic 1: Reference Data (Supporting BC) ---

# Option A: Batch — launch all issues with parallel agents
/pm:epic-start nestjs-reference-data        # identifies ready issues, spawns agents

# Option B: Issue-by-issue (more control)
/pm:issue-analyze {number}                  # decompose into parallel work streams
/pm:issue-start {number}                    # RED → GREEN → REFACTOR per stream
/superpowers:verification-before-completion  # evidence-based self-check
/pm:issue-close {number}                    # mark done, close on GitHub

# --- Epic 2: Trading Core (Core BC) ---
# Issue-by-issue recommended — Core BC needs more careful DDD discipline

/pm:issue-analyze {number}
/pm:issue-start {number}
/superpowers:verification-before-completion
/pm:issue-close {number}

# DDD practices enforced during implementation:
# - ddd-expert agent reviews for anemic models, ACL violations
# - Repository contracts from architecture.md §6.5
# - Domain logic placement from §6.4
# - Aggregate domain events from Practice 4
# - Specification pattern (Practice 7) when 3+ combinable rules
# - Factory pattern (Practice 8) when complex aggregate creation
```

### Phase 5-8: Review → Merge → Verify → Close

```
# 5. Review (inside M2 worktree)
/pr-review-toolkit:review-pr all            # 6 specialized review agents
/pm:epic-review nestjs-reference-data       # 3-layer: adversarial + edge + analyzer
/pm:epic-review nestjs-trading-core         # same for Trading

# 6. Merge
/code-review:code-review                    # 5 agents + scoring → posts to GitHub PR
/superpowers:finishing-a-development-branch  # pre-merge checklist
/pm:epic-merge nestjs-reference-data        # tests → PR → CI → merge
/pm:epic-merge nestjs-trading-core

# 7. Cleanup worktree
acme-worktree remove m2                   # kills tmux, unregisters, frees ports

# 8. Verify + close
/pm:prod-verify nestjs-reference-data
/pm:prod-verify nestjs-trading-core
/pm:epic-close nestjs-reference-data
/pm:epic-close nestjs-trading-core
/pm:project-context                         # update migration state
```

### Tooling Reference for M2

#### PM Commands (user-level, `~/.claude/commands/pm/`)

| Command | When | What It Does |
| --------------------- | ----------- | ---------------------------------------------------------- |
| `/pm:prd-new`         | Phase 1     | Brainstorm + write PRD with Gherkin ACs |
| `/pm:prd-parse`       | Phase 1     | Convert PRD → technical epic.md |
| `/pm:arch-create`     | Phase 1b | Collaborative architecture decisions + ADRs |
| `/pm:epic-decompose`  | Phase 1c | Break epic into numbered task files (AFTER arch-create)    |
| `/pm:tests-generate`  | Phase 2     | Generate failing test suites (RED phase)                   |
| `/pm:readiness-check` | Phase 2b | FR coverage, DDD artifacts, architecture validation |
| `/pm:epic-sync`       | Phase 3     | Push to GitHub, rename files to issue IDs, create worktree |
| `/pm:epic-start`      | Phase 4     | Launch parallel agents on branch (batch)                   |
| `/pm:issue-analyze`   | Phase 4     | Decompose issue into work streams |
| `/pm:issue-start`     | Phase 4     | Launch agents per work stream (requires worktree)          |
| `/pm:issue-close`     | Phase 4     | Close issue locally + GitHub |
| `/pm:epic-review`     | Phase 5     | 3-layer adversarial code review → review-report.md |
| `/pm:epic-merge`      | Phase 6     | Tests → PR → CI → merge → worktree cleanup |
| `/pm:prod-verify`     | Phase 7     | Production verification runbook |
| `/pm:epic-close`      | Phase 8     | Archive epic, close GitHub issues |
| `/pm:project-context` | After close | Update migration state tracking |

#### Acme Agents (project-level, `.claude/agents/`)

| Agent | Used During M2                      | Purpose |
| --------------------------- | ----------------------------------- | ---------------------------------------------------------- |
| `ddd-expert`                | arch-create, implementation, review | Domain modeling, aggregate design, anemic model detection |
| `nestjs-expert`             | implementation, review | NestJS modules, DI, guards, pipes, exception handling |
| `mikroorm-expert`           | implementation, review | Entity design, UoW, tenant isolation, repository contracts |
| `event-driven-expert`       | arch-create, implementation | RabbitMQ exchanges, outbox, DLX, idempotent consumers |
| `kubernetes-expert`         | deploy, review | Helm charts, ArgoCD, probes, resource limits, ESO          |
| `redis-expert`              | implementation, review | Cache-aside, TTL strategy, invalidation, key naming |
| `observability-expert`      | implementation, review | OpenTelemetry, Grafana, structured logging, traces |
| `api-designer`              | arch-create | REST API contracts, DTOs, OpenAPI (dual-stack)             |
| `database-migration-expert` | arch-create, implementation | MikroORM + TypeORM migrations (dual-stack)                 |
| `nx-expert`                 | scaffold, CI issues | Nx workspace, generators, executors |
| `security-auditor`          | review | OWASP, K8s, RabbitMQ, Redis, NestJS security |
| `interview-user`            | requirements | Gather domain requirements interactively |
| `e2e-testing-expert`        | test writing | Playwright test strategy, Page Objects |

#### Global Agents (user-level, `~/.claude/agents/`)

| Agent | Used By | Purpose |
| ------------------------ | ------------------------- | ---------------------------------------------------- |
| `acceptance-test-writer` | `/pm:tests-generate`      | Generate Gherkin + Playwright + Jest/Bun test suites |
| `adversarial-reviewer`   | `/pm:epic-review` Layer 1 | Blind diff-only review (no project context)          |
| `edge-case-hunter`       | `/pm:epic-review` Layer 2 | Mechanical path tracer for missing guards |
| `code-analyzer`          | `/pm:epic-review` Layer 3 | Deep bug hunt with full context |
| `parallel-worker`        | `/pm:issue-start`         | Coordinates multiple work streams |
| `test-runner`            | General | Runs tests and analyzes results |

#### Quality Skills (invoked at checkpoints)

| Skill | When | Purpose |
| --------------------------------------------- | --------------------- | ------------------------------------- |
| `/superpowers:brainstorming`                  | Before PRD            | Explore problem space, alternatives |
| `/superpowers:test-driven-development`        | Before implementation | TDD discipline enforcement |
| `/superpowers:verification-before-completion` | After each issue | Evidence-based self-check |
| `/superpowers:requesting-code-review`         | After implementation | Dispatch code review agent |
| `/superpowers:finishing-a-development-branch` | Before merge | Pre-merge quality checklist |
| `/superpowers:systematic-debugging`           | When stuck | 4-phase root cause analysis |
| `/qodo-skills:qodo-get-relevant-rules`        | Session start | Load project coding standards |
| `/pr-review-toolkit:review-pr all`            | Before merge | 6 specialized review agents |
| `/code-review:code-review`                    | After PR creation | 5 agents + scoring → GitHub PR review |
| `/ralph-implement-spec`                       | Complex issues | Autonomous spec implementation loop |
| `/debug-loop`                                 | Failing tests | Autonomous fix iteration |

#### Implementation Skills (project-level, `.claude/skills/`)

| Skill | Purpose |
| ----------------------------- | ---------------------------------------------------------------------- |
| `implement-nestjs-module`     | **NEW** — Full DDD module scaffold (domain/app/infra layers)           |
| `implement-domain-event`      | **NEW** — Event contract + outbox + publisher + consumer + DLX + tests |
| `implement-helm-chart`        | **NEW** — Per-service Helm values + ArgoCD Application + ESO           |
| `implement-cache-layer`       | **NEW** — Redis cache-aside + TTL + event-driven invalidation |
| `k8s-troubleshoot`            | **NEW** — K8s pod debugging, ArgoCD rollback, RabbitMQ/Redis checks |
| `sonar-scan`                  | **NEW** — Run SonarQube locally, fetch quality gate results |
| `implement-endpoint`          | REST endpoint (dual-stack: Express legacy + NestJS Platform)              |
| `implement-unit-tests`        | Jest/Vitest unit tests |
| `implement-integration-tests` | DB integration tests with real services |
| `implement-e2e-tests`         | Playwright E2E tests with Page Objects |
| `implement-component`         | React/MUI component implementation |
| `commit`                      | Quality-checked git commit (Prettier + typecheck + affected tests)     |
| `pr-create`                   | Structured PR with description, linked issues, checklist |
| `test-affected`               | Run only tests for Nx-affected projects |

#### Always-On Hooks (fire automatically during development)

| Hook | Trigger | What It Does |
| ----------------------------- | ------------------------ | ---------------------------------------------------------------- |
| `block-dangerous-commands.sh` | PreToolUse[Bash]         | Blocks `rm -rf`, `--force`, destructive ops |
| `enforce-nx-commands.sh`      | PreToolUse[Bash]         | Requires `nx run`, blocks bare `jest`/`tsc`                      |
| `pre-commit-checks.sh`        | PreToolUse[Bash]         | Typecheck + affected tests before `git commit` (5 min)           |
| `protect-sensitive-files.sh`  | PreToolUse[Write\|Edit]  | Blocks writes to `.env`, credentials |
| `auto-format.sh`              | PostToolUse[Write\|Edit] | Runs Prettier after every file edit |
| `validate-infra-files.sh`     | PostToolUse[Write\|Edit] | Validates `.tf` and `.github/` YAML                              |
| `validate-security.sh`        | PostToolUse[Write\|Edit] | **NEW** — ESLint security rules on Platform `.ts` files |
| `enforce-nestjs-patterns.sh`  | PostToolUse[Write\|Edit] | **NEW** — Blocks legacy imports, process.env in Platform |
| `validate-event-contracts.sh` | PostToolUse[Write\|Edit] | **NEW** — Event version, tenantId, past-tense naming |
| `validate-helm-charts.sh`     | PostToolUse[Write\|Edit] | **NEW** — Helm lint, resources, probes, secrets |
| `validate-k8s-manifests.sh`   | PostToolUse[Write\|Edit] | **NEW** — K8s YAML validation, no `latest`, no plaintext secrets |
| `quality-gate-tests.sh`       | Stop | Runs affected tests when Claude stops (3 min)                    |
| `hookify`                     | Various | Custom prevention rules per `.local.md` files |

**Note:** These hooks work in acme-worktrees because `.claude/` is symlinked from the primary repo. `settings.json` (which defines hooks) is read from the symlinked `.claude/settings.json`.

**Note:** Semgrep plugin is currently **disabled**. Enable via `~/.claude/plugins/installed_plugins.json` if security scanning on every edit is desired.

#### MCP Servers

| Server | Command | Use During M2                                       |
| ------------ | -------------------------------------- | --------------------------------------------------- |
| `nx-mcp`     | `npx nx mcp`                           | Nx generators, project graph, affected analysis |
| `azure`      | `npx @azure/mcp@latest server start`   | Azure resource management for dev instances |
| `acme-mcp` | `bun run apps/acme-mcp/src/index.ts` | DB status, entity info, route chains, health checks |

#### acme-worktree Commands

```
acme-worktree create <name> [branch]   # Create worktree + configure env
acme-worktree remove <name>            # Kill tmux, unregister, free ports
acme-worktree list                     # Show all worktrees with ports/status
acme-worktree open <name>              # Open tmux session + launch claude
acme-worktree configure [name]         # Re-generate env files (idempotent)
acme-worktree status [name]            # Show instance details + Docker status
```

Location: `~/.local/bin/acme-worktree` (33KB bash script)
Config: `scripts/local-multi-instance/multi-instance.config.json`
Worktree path: `~/projects/acme-<name>/`

### Estimated M2 Timeline

Based on M1 velocity (13 tasks, ~2 weeks):

- Reference Data epic: ~6-8 tasks, 1-2 weeks
- Trading Core epic: ~10-15 tasks, 2-3 weeks
- Total M2: 3-5 weeks with review + merge overhead
