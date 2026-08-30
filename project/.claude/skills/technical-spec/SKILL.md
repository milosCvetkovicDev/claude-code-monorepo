---
name: technical-spec
description: "Create a technical specification with architecture reviews for new features or systems. Use when the user needs a detailed spec before implementation (data models, API contracts, component design). Do not use for system-level architecture docs (use system-design) or converting designs to specs (use design-to-spec)."
model: sonnet
---

# Technical Specification Workflow

You are orchestrating technical specification creation with mandatory architecture reviews.

## Workflow Steps

### Step 1: Requirements Clarification

Before creating the spec, ensure you understand:

- What problem is being solved?
- What are the constraints (time, technology, team)?
- What existing patterns should be followed?
- What are the non-goals (explicit scope boundaries)?

Use the **interview-user agent** if requirements are unclear.

### Step 2: Create Technical Specification

Use the **technical-spec agent** to create a comprehensive specification:

**Output location**: `docs/plans/YYYY-MM-DD-{feature-name}-technical-spec.md`

**Required sections**:

1. Overview (summary, goals, non-goals)
2. Current State (what exists, affected components)
3. Proposed Design (architecture, data flow, APIs)
4. Security Considerations
5. Implementation Phases
6. Testing Strategy
7. Risks & Mitigations
8. Open Questions

### Step 3: Architecture Reviews (MANDATORY)

After spec creation, run these 5 reviews **in parallel**:

```
Run in parallel:
1. ddd-expert - Domain model, bounded contexts, aggregates, value objects
2. review-enterprise-architect - Clean Architecture, SOLID, system design
3. review-azure-architect - Azure patterns, cost, security (if Azure involved)
4. review-devops-architect - CI/CD, deployment, observability
5. review-tech-lead - Technology choices, maintainability, conventions
```

**Review output format**:

```markdown
## Review Summary

| Reviewer | Verdict | Critical | High | Medium |
| -------------------- | ---------------------------- | -------- | ---- | ------ |
| DDD Expert | APPROVED/CONDITIONAL/BLOCKED | N        | N    | N      |
| Enterprise Architect | APPROVED/CONDITIONAL/BLOCKED | N        | N    | N      |
| Azure Architect | APPROVED/CONDITIONAL/BLOCKED | N        | N    | N      |
| DevOps Architect | APPROVED/CONDITIONAL/BLOCKED | N        | N    | N      |
| Tech Lead | APPROVED/CONDITIONAL/BLOCKED | N        | N    | N      |

### Critical Issues (MUST FIX before implementation)

1. [Issue] - [Location] - [Fix required]

### High Priority (SHOULD FIX before implementation)

1. [Issue] - [Recommendation]

### Consolidated Recommendations

1. [Recommendation]
```

### Step 4: Address Review Findings

For each critical finding:

1. Update the technical spec with the fix
2. Document why certain recommendations were accepted/rejected
3. Add new risks identified by reviewers

### Step 5: Final Approval

Spec is approved when:

- [ ] All critical issues resolved
- [ ] High priority issues addressed or documented as accepted risk
- [ ] At least 3 of 4 reviewers approve
- [ ] Open questions have answers or are marked "to be determined during implementation"

## Review Criteria by Reviewer

### DDD Expert Focus

- Bounded context identification and boundaries
- Aggregate design and consistency boundaries
- Value objects for domain concepts
- Ubiquitous language alignment
- Domain events for cross-aggregate communication
- Entity vs value object decisions

### Enterprise Architect Focus

- Clean Architecture layer separation
- SOLID principles compliance
- Module boundaries (Nx tags)
- Dependency direction (inward only)
- System integration patterns

### Azure Architect Focus

- Well-Architected Framework (5 pillars)
- Azure SDK usage patterns
- Cost optimization
- Security hardening
- Multi-tenancy enforcement

### DevOps Architect Focus

- CI/CD integration
- Deployment strategy
- Observability (logging, metrics, alerts)
- Operational runbooks
- Rollback procedures

### Tech Lead Focus

- Technology choice justification
- Project conventions compliance
- Developer experience
- Maintainability
- Testing feasibility

## Output

After reviews complete, provide:

1. **Spec file path**: `docs/plans/YYYY-MM-DD-{name}-technical-spec.md`
2. **Review summary table** (verdicts + issue counts)
3. **Critical issues list** (blocking implementation)
4. **Recommended changes** (prioritized)
5. **Approval status**: APPROVED / CONDITIONAL / BLOCKED

## Example

```
User: "Create a technical spec for the acme-mcp server"

Claude:
1. Creates spec at docs/plans/2026-01-29-acme-mcp-technical-spec.md
2. Runs 5 review agents in parallel
3. Consolidates findings:

## Review Summary

| Reviewer | Verdict | Critical | High | Medium |
|----------|---------|----------|------|--------|
| DDD Expert | CONDITIONAL | 2 | 1 | 1 |
| Enterprise Architect | CONDITIONAL | 5 | 3 | 2 |
| Azure Architect | CONDITIONAL | 5 | 2 | 3 |
| DevOps Architect | CONDITIONAL | 3 | 4 | 2 |
| Tech Lead | BLOCKED | 4 | 2 | 3 |

**Status**: BLOCKED - Address 4 critical issues from Tech Lead before proceeding

### Critical Issues
1. Use Node.js, not Bun (Tech Lead)
2. Services as namespaces, not classes (Enterprise Architect)
3. KQL injection prevention required (Azure Architect)
4. Remove azure_slot_swap tool (Tech Lead, DevOps)
5. Missing bounded context boundaries (DDD Expert)
```
