# Architecture Operations

Standard patterns for the architecture phase in the CCPM workflow.

## Core Principles

- Architecture decisions are COLLABORATIVE — the command facilitates, the user decides
- Per-epic architecture INHERITS from master architecture in multi-milestone projects
- ADRs go in `docs/adr/` following existing project conventions
- Architecture references in tasks use `architecture.md §X.Y` notation

## Decision Categories

8 categories, each facilitated collaboratively. Skip categories that are N/A for the epic scope.

### 1. Data Architecture

Database choice, ORM, schema design, migrations strategy, validation library, caching layer, DDD modeling (entities, value objects, aggregates).

- Example: "PostgreSQL + MikroORM with DDD entity modeling, Unit of Work"
- Acme agents: `ddd-expert`, `database-migration-expert`

### 2. Auth & Security

Authentication method, authorization model (RBAC/ABAC), token strategy (JWT signing), API security (rate limiting, CORS), encryption, secrets management.

- Example: "Local JWT validation with jose, Entra ID for identity"
- Acme agents: `security-auditor`

### 3. API & Communication

REST vs GraphQL, API documentation (Swagger/OpenAPI), error response format, rate limiting, versioning, inter-service communication.

- Example: "NestJS REST with @nestjs/swagger, standardized error DTOs"
- Acme agents: `api-designer`

### 4. Frontend Architecture

State management, component organization (feature-based, atomic), routing, performance (code splitting, lazy loading), form handling.

- Example: "TanStack Query for server state, feature-based component folders"
- Acme agents: `frontend-specialist`, `ui-expert`

### 5. Infrastructure & Deployment

Hosting platform, CI/CD pipeline, environment strategy, monitoring/observability, scaling, IaC tool.

- Example: "Azure Container Apps, GitHub Actions, Terraform"
- Acme agents: `terraform-expert`, `review-azure-architect`

### 6. Domain Event Infrastructure

How domain events are published, subscribed to, and handled within the modular monolith. This is a one-time decision that affects all BCs.

- Options: NestJS EventEmitter (simple), MikroORM Entity Events (lifecycle), Aggregate Domain Events + EventEmitter (DDD-proper), Transactional Outbox (guaranteed delivery)
- Includes: event envelope standard, event catalog location, event versioning strategy
- Example: "Aggregate Domain Events collected in entity, published after MikroORM flush via NestJS EventEmitter"
- Acme agents: `ddd-expert`
- Full details: `/rules/ddd-practices.md` Practice 4

### 7. Anti-Corruption Layer Strategy (Migration Projects)

How new modules interact with legacy code during strangler fig migration. Prevents legacy model leakage.

- Includes: per-BC ACL assessment, adapter interface design, translation mapping, lifecycle tracking
- Example: "Port interface in domain layer, LegacyCustomerAdapter in infrastructure, tracked in acl-registry.md"
- Rules: Never import directly from legacy apps. Always go through a port. Track ACL removal criteria.
- Full details: `/rules/ddd-practices.md` Practice 2

### 8. Domain Logic Placement

Where business logic lives: entities vs domain services vs application services. Prevents anemic domain models.

- Includes: single-aggregate invariants (entity), cross-aggregate rules (domain service), orchestration (application service)
- Example: "Invariants in aggregate root methods, cross-aggregate pricing in PricingService, workflow in CreateSaleUseCase"
- Acme agents: `ddd-expert`
- Full details: `/rules/ddd-practices.md` Practice 3

## Architecture Document Format

Lives at `.claude/epics/<name>/architecture.md`.

### Frontmatter

```yaml
---
name: <epic-name>
status: active
created: <ISO datetime>
updated: <ISO datetime>
prd: .claude/prds/<name>.md
epic: .claude/epics/<name>/epic.md
master: .claude/milestones/<program>/master-architecture.md # only if multi-milestone
---
```

### Sections (appended incrementally)

```markdown
# Architecture: <epic-name>

## 1. Context Analysis

FRs, NFRs, constraints from PRD. Technical implications from epic.

## 2. Decision Matrix

| Category | Decision | Version | Rationale | ADR | Inherited? |
| -------- | -------- | ------- | --------- | --- | ---------- |

## 3. Implementation Patterns

### 3.1 Naming Conventions

### 3.2 Structure Conventions

### 3.3 Format Conventions (API responses, error shape, dates, numbers)

### 3.4 Anti-Patterns (NEVER DO)

## 4. Project Structure

### 4.1 Directory Tree

### 4.2 Requirement-to-File Mapping

| FR/AC | Target File | Layer |

## 5. Cross-Cutting Concerns

Error handling, logging, testing, monitoring.

## 6. DDD Design (if applicable)

### 6.1 Context Map Relationships

Which BCs does this epic interact with? What relationship pattern for each?
| This BC | Related BC | Pattern | Direction | Notes |
|---------|-----------|---------|-----------|-------|

### 6.2 Anti-Corruption Layers (migration epics)

Which legacy modules does this BC need data from?
| Legacy Module | Port Interface | Adapter | Translation | Removal Criteria |
|--------------|---------------|---------|-------------|-----------------|

### 6.3 Domain Event Contracts

What events does this BC produce and consume?
| Event | Direction | Version | Payload Schema | Consumers/Producers |
|-------|-----------|---------|---------------|-------------------|

### 6.4 Domain Logic Placement

Where do key business rules live?
| Business Rule | Location | Type | Rationale |
|--------------|----------|------|-----------|
| {rule} | Deal.confirm() | Entity method | Single-aggregate invariant |
| {rule} | PricingService | Domain Service | Cross-aggregate calculation |

### 6.5 Repository Contracts

Domain-layer interfaces for each aggregate root.
| Aggregate Root | Repository Interface | Key Query Methods |
|---------------|---------------------|------------------|
```

## Master Architecture (Multi-Milestone)

For multi-milestone projects, a master architecture lives at `.claude/milestones/<program>/master-architecture.md`. Same format as per-epic but project-wide scope.

### Inheritance

When `arch-create` runs:

1. Check for master architecture
2. If exists: load shared decisions, show as "Inherited from master"
3. Only prompt for epic-specific decisions not covered by master
4. If user wants to override: create a superseding ADR

### Evolution

- New patterns can be added to master
- Existing decisions can be superseded (new ADR with `Supersedes: ADR-NNNN`)
- Master tracks both old and new decisions with applicability notes (e.g., "Drizzle for M2 modules, Prisma for M3+")

## ADR Integration

### Numbering

```bash
next_adr=$(ls docs/adr/[0-9]*.md 2>/dev/null | sed 's|.*/||;s|-.*||' | sort -n | tail -1 | awk '{printf "%04d", $1+1}')
[ -z "$next_adr" ] && next_adr="0001"
```

### Format

Follow existing `docs/adr/README.md` template: Title, Date, Status, Context, Decision, Consequences, Alternatives Considered, References.

### When to Create ADRs

Create when: multiple alternatives seriously considered, long-term implications, team might question the choice, or superseding a previous ADR.

### Superseding

New ADR: `**Supersedes:** ADR-NNNN`. Old ADR status → `Superseded by ADR-MMMM`. Update master architecture.

## Architecture References in Tasks

Tasks reference architecture using section notation:

- `architecture.md §2` — Decision Matrix
- `architecture.md §3.1` — Naming Conventions
- `master-architecture.md §3.4` — Anti-Patterns

Appears in task files under `## Dev Notes > ### Architecture Patterns`.

## Collaborative Decision Process

For each category during `arch-create`:

1. Present relevant context from PRD and epic
2. If master architecture exists, show inherited decisions
3. For undecided categories: list 2-3 options with trade-offs
4. Ask user to choose (never auto-generate)
5. For complex decisions, suggest spawning relevant Acme agent
6. Record decision with rationale
