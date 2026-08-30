---
name: bug-fix
description: "Investigate, reproduce, fix, and test bugs in the Acme codebase. Use when the user reports a bug, error, or unexpected behavior that needs fixing. Do not use for performance issues (use performance) or infrastructure problems (use dev-troubleshoot)."
model: sonnet
---

# Bug Fix Workflow

You are orchestrating a bug fix from investigation through resolution.

## Workflow Steps

### Step 1: Reproduce & Understand
First, ensure you can reproduce the bug:
- Get specific reproduction steps from the user
- Identify affected environment (dev/prod)
- Determine severity and impact

### Step 2: Investigation
Use the **Explore agent** to investigate the bug:
- Understand the reported symptoms
- Find the relevant code paths
- Identify the root cause
- Document affected files
- Check if multi-tenancy is involved

### Step 3: Write Failing Test (TDD)
**CRITICAL: Write the test BEFORE fixing the bug**
```bash
# Create test that reproduces the bug
nx run legacy-api:test -- --testNamePattern="bug description"
```
- Test MUST fail without the fix (proves test catches the bug)
- Test should verify the expected correct behavior
- Include edge cases discovered during investigation

### Step 4: Fix Implementation
Based on investigation findings:
- Implement the **minimal fix** - don't over-engineer
- Ensure multi-tenancy is not affected
- Use Big.js for any decimal calculations
- Follow thin controller / service namespace patterns

**Verify fix:**
```bash
# Test should now pass
nx run legacy-api:test -- --testNamePattern="bug description"
```

### Step 5: Regression Testing
```bash
# Run all affected tests
nx affected -t test

# Run full test suite if critical bug
nx run-many -t test
```

### Step 6: Code Quality Review
Use the **review-tech-lead agent** to verify:
- Code follows project conventions
- No `any` types without justification
- Proper error handling
- Fix is minimal and focused

### Step 7: Test Quality Review
Use the **review-test-architect agent** to verify:
- Test actually catches the bug (fails without fix)
- Edge cases are tested
- No flaky test patterns introduced
- Assertions are specific (not just `toBeDefined`)

## Quick Checklist
- [ ] Bug reproduced locally
- [ ] Root cause identified
- [ ] Failing test written FIRST
- [ ] Fix implemented (minimal)
- [ ] Test passes with fix
- [ ] No regressions
- [ ] Reviews completed

## Output
Provide a summary including:
- Root cause explanation
- Files modified
- Tests added/updated (with proof test failed before fix)
- Review findings addressed
