---
name: refactor
description: "Plan and execute code refactoring: improve structure, reduce tech debt, apply design patterns, and maintain test coverage. Use when the user wants to restructure code without changing behavior. Do not use for adding new features (use new-feature) or fixing bugs (use bug-fix)."
model: sonnet
---

# Refactoring Workflow

You are orchestrating a code refactoring effort with proper planning and verification.

## Workflow Steps

### Step 1: Architecture Analysis

Use the **review-enterprise-architect agent** and **ddd-expert agent** to:

- Identify areas needing refactoring
- Assess Clean Architecture compliance
- Check SOLID principle violations
- Evaluate current technical debt
- Prioritize refactoring targets
- Analyze domain model health (aggregates, value objects)
- Identify bounded context violations

### Step 2: Technical Specification

Use the **technical-spec agent** to:

- Document the refactoring scope
- Define target architecture
- Identify affected components
- Plan the refactoring sequence
- Define success criteria

Output: Technical spec in `docs/plans/`

### Step 3: Incremental Refactoring

Refactor in small, testable increments:

**Pattern 1: Extract Service**

```typescript
// After: Thin controller + service
import * as InvoiceService from '../services/InvoiceService';

// Before: Logic in controller
const create = async (req, res) => {
  // 50 lines of business logic
};

const create = async (req, res) => {
  const tradingCompany = req.getTradingCompanyOrThrow();
  const result = await InvoiceService.create(req.body, tradingCompany);
  res.json(buildInvoiceResponse(result));
};
```

**Pattern 2: Repository Factory**

```typescript
// Before: Direct repository access
const repo = getRepository(Customer);
const customers = await repo.find({ where: { companyId } });

// After: Factory with TradingCompany
const repo = CustomersRepository(tradingCompany);
const customers = await repo.findAll(); // Auto-filtered
```

**Pattern 3: Value Objects**

```typescript
// Before: Primitive obsession
const calculateTotal = (amount: number, quantity: number) => {
  return amount * quantity; // Floating point errors!
};

// After: Value objects with Big.js
const calculateTotal = (amount: Big, quantity: Big): Big => {
  return amount.times(quantity);
};
```

### Step 4: Test Verification

After each refactoring step:

```bash
# Run affected tests
nx run legacy-api:test

# Run all tests to catch regressions
nx run-many -t test
```

Ensure:

- All existing tests pass
- Behavior unchanged
- No new regressions

### Step 5: Code Quality Review

Use the **review-tech-lead agent** to verify:

- Refactoring improves code quality
- Project conventions followed
- No new technical debt introduced
- Names reveal intent
- Functions do one thing

### Step 6: Test Quality Review

Use the **review-test-architect agent** to verify:

- Test coverage maintained or improved
- Tests still meaningful after refactor
- No flaky tests introduced

## Refactoring Principles

### Do

- Small, incremental changes
- Run tests after each change
- Commit frequently
- Keep behavior identical
- Follow project patterns

### Don't

- Big bang rewrites
- Change behavior while refactoring
- Skip tests
- Mix refactoring with feature work
- Introduce new patterns inconsistently

## Common Refactoring Targets

| Smell | Refactoring |
| -------------------- | ----------------------- |
| Fat controller | Extract to service |
| Direct repo access | Use repository factory |
| Number for money | Use Big.js |
| Shared mutable state | Dependency injection |
| Copy-paste code | Extract shared function |
| Long function | Extract helper methods |
| `any` types | Add proper types |

## Output

Provide:

- Refactoring summary
- Files changed
- Tests verified
- Before/after comparison
- Remaining technical debt
