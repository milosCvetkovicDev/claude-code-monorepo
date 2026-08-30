---
name: ralph-refactor
description: "Ralph Loop: incremental refactoring with continuous test verification after each change. Use when the user wants autonomous refactoring with guaranteed green tests. Do not use for manual refactoring (use refactor) or feature implementation (use ralph-implement-spec)."
model: sonnet
args: <target-description> [--project <name>] [--pattern <refactoring-pattern>]
---

# Ralph Refactor

Start a Ralph Loop that performs incremental refactoring with test verification after every change, ensuring behavior is preserved throughout.

## When to Use

- Extracting fat controllers into service namespaces
- Converting raw repository access to factory pattern
- Replacing Number with Big.js for money calculations
- Eliminating `any` types across a module
- Overnight refactoring runs in a tmux session

## Input

- **target-description** (required): What to refactor and why
- **--project** (optional): Target Nx project (default: `legacy-api`)
- **--pattern** (optional): Specific refactoring pattern: `extract-service`, `repository-factory`, `bigjs-money`, `remove-any`, `value-objects`

## Workflow

### Step 1: Launch Ralph Loop

Invoke `/ralph-loop` with the following prompt:

```
/ralph-loop "You are performing incremental refactoring in the Acme monorepo.

## Refactoring Target
<TARGET_DESCRIPTION>

## Target Project
<PROJECT>

## Refactoring Pattern
<PATTERN or 'general'>

## Core Principle
NEVER change behavior. Every iteration must leave all tests passing.

## Iteration Strategy

### On First Iteration
1. Analyze the target code — identify all refactoring opportunities
2. Create a prioritized list of changes (smallest/safest first)
3. Estimate total changes needed
4. Start with change #1

### On Each Subsequent Iteration
1. Check git log for what was already refactored
2. Pick the next change from the prioritized list
3. Implement ONE refactoring step
4. Run tests: 'npx nx run <project>:test'
5. If tests pass: commit and continue
6. If tests fail: revert the change, try a different approach
7. Move to next change

## Acme Refactoring Patterns

### extract-service
```typescript
// BEFORE: Logic in controller
router.post('/invoices', async (req, res) => {
  const tradingCompany = req.getTradingCompanyOrThrow();
  // 50 lines of business logic...
  res.json(result);
});

// AFTER: Thin controller + service namespace
import * as InvoiceService from '../services/InvoiceService';
router.post('/invoices', async (req, res) => {
  const tradingCompany = req.getTradingCompanyOrThrow();
  const result = await InvoiceService.create(req.body, tradingCompany);
  res.json(buildInvoiceResponse(result));
});
```

### repository-factory
```typescript
// BEFORE: Direct repository access
const repo = getRepository(Customer);
const customers = await repo.find({ where: { companyId } });

// AFTER: Factory with TradingCompany
const repo = CustomersRepository(tradingCompany);
const customers = await repo.findAll();
```

### bigjs-money
```typescript
// BEFORE: Floating point arithmetic
const total = amount * quantity;

// AFTER: Big.js precision
const total = new Big(amount).times(quantity);
```

### remove-any
```typescript
// BEFORE: Untyped
const processData = (data: any) => { ... }

// AFTER: Properly typed
const processData = (data: InvoiceLineItem) => { ... }
```

## Commit Strategy
- One commit per refactoring step: 'refactor(<project>): <what was refactored>'
- Run 'npx nx format:write' before every commit
- NEVER batch unrelated refactorings in one commit

## Progress Tracking
Each iteration: report 'Refactoring step N/M: <description> — [DONE|IN PROGRESS|SKIPPED]'

## Completion
When ALL identified refactoring steps are complete and tests pass, output: <promise>REFACTOR COMPLETE</promise>
Only output this when:
1. All planned refactoring steps are done (or documented as skipped with reason)
2. All project tests pass
3. No new 'any' types introduced
4. All changes committed" --completion-promise "REFACTOR COMPLETE" --max-iterations 30
```

## Example Usage

```
# Extract services from fat controllers
/ralph-refactor "Extract business logic from invoice controller into InvoiceService namespace" --pattern extract-service

# Convert money calculations to Big.js
/ralph-refactor "Replace all Number-based money calculations with Big.js in commission module" --pattern bigjs-money --project legacy-api

# General refactoring
/ralph-refactor "Clean up the sync module — reduce complexity, improve naming, add types"
```

## Safety

- Max 30 iterations (one refactoring step per iteration)
- Tests run after EVERY change — reverts if tests break
- One commit per step — easy to cherry-pick or revert
- Never changes behavior — only structure
- Skips and documents changes that are too risky
