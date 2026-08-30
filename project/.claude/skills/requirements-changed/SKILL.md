---
name: requirements-changed
description: "Handle requirement changes mid-implementation: assess impact, update specs, adjust implementation plan, and communicate scope changes. Use when stakeholder requirements change after work has started. Do not use for new requirements (use new-feature) or initial spec creation (use technical-spec)."
model: sonnet
disable-model-invocation: true
---

# Requirements Changed Workflow

## Phase 1: Analysis & Planning

### Step 1: Document the Change

Create a change record at `docs/requirements/changes/CHG-{number}.md`:

```markdown
# Requirements Change Record

**Change ID**: CHG-{number}
**Date**: YYYY-MM-DD
**Requested By**: {stakeholder}
**Priority**: Critical / High / Medium / Low

## Original Requirement

{What was originally specified}

## New Requirement

{What is now required}

## Reason for Change

{Business justification}
```

### Step 2: Clarify Requirements

Use the **interview-user agent** to:

- Understand the full scope of the change
- Identify hidden requirements and edge cases
- Confirm acceptance criteria
- Understand timeline constraints

Output: Updated requirements in change record

### Step 3: Domain Impact Analysis

Use the **ddd-expert agent** to:

- Analyze bounded context impact
- Assess aggregate boundary changes
- Identify new value objects needed
- Check ubiquitous language alignment
- Evaluate domain event flow changes

**Key Questions:**

- Does this change the core domain model?
- Are we introducing new bounded contexts?
- Does this break existing aggregate invariants?

---

## Phase 2: DDD Pattern Selection

### Step 4: Select DDD Implementation Approach

Use the **ddd-expert agent** to recommend the right DDD patterns:

| Change Type | Recommended Pattern |
| --------------------------- | ------------------------- |
| New business concept | Value Object or Entity |
| Complex object creation | Factory Pattern |
| Cross-aggregate operation | Domain Service |
| State change notification | Domain Events |
| External system integration | Anti-Corruption Layer |
| Data transformation | Specification Pattern |
| Complex business rules | Policy / Strategy Pattern |

**Document the selected approach:**

```markdown
## DDD Implementation Strategy

### Selected Patterns

1. {Pattern} - {Justification}
2. {Pattern} - {Justification}

### Aggregate Changes

- {Aggregate}: {Change description}

### New Value Objects

- {ValueObject}: {Purpose}

### Domain Events

- {Event}: {Trigger and handlers}
```

---

## Phase 3: Architecture Review

### Step 5: Architecture Reviews (Parallel)

Run these reviews in parallel:

```
1. ddd-expert - Domain model integrity, pattern selection validation
2. review-enterprise-architect - Clean Architecture, SOLID compliance
3. review-tech-lead - Implementation feasibility, code quality
4. review-test-architect - Test strategy impact
```

If infrastructure affected:

```
5. review-azure-architect - Azure resources, cost impact
6. review-devops-architect - CI/CD, deployment impact
```

### Step 6: Update Technical Specification

Use the **technical-spec agent** to:

- Update or create technical spec
- Document DDD patterns to implement
- Define implementation phases
- Update risk register

Output: `docs/plans/YYYY-MM-DD-{feature}-change-spec.md`

---

## Phase 4: Implementation

### Step 7: Implement Domain Layer Changes

Following the DDD patterns identified:

**Value Objects:**

```typescript
// Add to @acme/domain-types
export class NewValueObject {
  private constructor(private readonly value: Big) {}

  static create(value: string): NewValueObject {
    // Validation logic
    return new NewValueObject(new Big(value));
  }

  equals(other: NewValueObject): boolean {
    return this.value.eq(other.value);
  }
}
```

**Entities/Aggregates:**

```typescript
// Update entity with new business rules
@Entity()
export class AffectedEntity {
  // New fields/methods per DDD analysis

  applyBusinessRule(): void {
    // Encapsulate business logic in entity
  }
}
```

**Domain Services:**

```typescript
// For operations spanning multiple aggregates
export const DomainService = {
  performCrossAggregateOperation: async (
    aggregate1: Aggregate1,
    aggregate2: Aggregate2,
    tradingCompany: TradingCompany
  ): Promise<Result> => {
    // Domain logic here
  },
};
```

### Step 8: Implement Infrastructure Changes

**Database migrations:**

```bash
npm run typeorm migration:generate -- -d apps/legacy-api/src/data-source.ts apps/legacy-api/src/migrations/ChangeDescription
```

**API changes:**

- Update Zod schemas
- Update controllers (thin!)
- Update services (namespace imports)
- Update repositories (factory pattern)

**Frontend changes:**

- Update API hooks
- Update components
- Update form validation

---

## Phase 5: Expert Testing

### Step 9: Test Strategy

Use the **review-test-architect agent** to define:

**Unit Tests:**

- [ ] Value object creation and equality
- [ ] Entity business rule enforcement
- [ ] Domain service operations
- [ ] Aggregate invariant protection

**Integration Tests:**

- [ ] Repository operations with new fields
- [ ] API endpoint changes
- [ ] Cross-service interactions

**E2E Tests:**

- [ ] User workflows affected by change
- [ ] Regression scenarios
- [ ] Edge cases from requirements

### Step 10: Implement Tests

```bash
# Run affected tests during implementation
nx run legacy-api:test --testPathPattern={affected-area}

# Run full test suite before PR
nx run-many -t test
```

---

## Phase 6: Documentation

### Step 11: Update Documentation

Use the **documentation-writer agent** for:

**Architecture Decision Record (ADR):**
Create `docs/adr/ADR-{number}-{title}.md`:

```markdown
# ADR-{number}: {Title}

## Status

Accepted

## Context

{Why was this change needed?}

## Decision

{What DDD patterns/approach was chosen?}

## Consequences

{What are the implications?}
```

**API Documentation:**

- Update endpoint documentation
- Document breaking changes
- Add migration guide if needed

**Runbooks (if operational impact):**

- Update `docs/runbooks/` with new procedures
- Document rollback steps

**Update CLAUDE.md (if patterns changed):**

- Document new conventions
- Update code examples

---

## Phase 7: Review & Approval

### Step 12: Final Reviews (Parallel)

Run final validation:

```
1. ddd-expert - Verify domain model integrity maintained
2. review-tech-lead - Code quality and conventions
3. review-test-architect - Test coverage adequate
4. security-auditor - No security regressions
```

### Step 13: Stakeholder Communication

Prepare summary for stakeholders:

```markdown
## Requirements Change Complete

### Change Summary

{One paragraph overview}

### What Changed

| Area | Changes |
| ------------ | --------- |
| Domain Model | {summary} |
| API          | {summary} |
| Database | {summary} |
| Frontend | {summary} |

### DDD Patterns Applied

- {Pattern}: {Where and why}

### Breaking Changes

{List any breaking changes}

### Migration Required

{Yes/No - migration steps if yes}

### Documentation Updated

- [ ] ADR created
- [ ] API docs updated
- [ ] Runbooks updated
- [ ] CLAUDE.md updated (if needed)

### Test Coverage

- Unit: {X}%
- Integration: {Y} tests
- E2E: {Z} scenarios
```

---

## Output Checklist

After completing this workflow:

- [ ] Change record documented
- [ ] Requirements clarified with stakeholder
- [ ] Domain impact analyzed
- [ ] DDD patterns selected and documented
- [ ] Architecture reviews completed
- [ ] Technical spec updated
- [ ] Domain layer implemented
- [ ] Infrastructure changes implemented
- [ ] Tests written and passing
- [ ] ADR created
- [ ] Documentation updated
- [ ] Final reviews passed
- [ ] Stakeholder summary prepared

---

## Quick Reference: DDD Pattern Selection

| Scenario | Pattern | Example |
| -------------------------- | --------------------- | ------------------------------- |
| Immutable business concept | Value Object | Money, Quantity, DateRange |
| Identity-based concept | Entity | Customer, Invoice |
| Consistency boundary | Aggregate | Invoice + LineItems |
| Complex creation logic | Factory | InvoiceFactory.createFromSale() |
| Cross-aggregate logic | Domain Service | PricingService.calculate()      |
| State change notification | Domain Event | InvoiceFinalizedEvent |
| External system boundary | Anti-Corruption Layer | ErpAdapter |
| Complex query | Specification | OverdueInvoiceSpec |
