---
name: full-review
description: "Comprehensive multi-reviewer code review dispatching specialized agents (tech lead, architect, security, performance, testing) in parallel. Use for thorough reviews of large PRs or pre-release audits. Do not use for quick single-file reviews (use code-review)."
disable-model-invocation: true
model: sonnet
---

# Full Review Workflow

You are orchestrating a comprehensive code review using multiple specialized reviewers.

## Workflow Steps

### Step 0: Smoke Test (Gate)

**Run tests BEFORE reviewing** - abort if tests fail:

```bash
# Quick check - affected tests only
nx affected -t test

# If critical changes, run full suite
nx run-many -t test
```

**If tests fail, fix them first. Don't waste time reviewing broken code.**

### Step 1: Identify Changes

Analyze what has changed:

```bash
git diff main --stat
git log main..HEAD --oneline
```

Categorize changes:

- Backend code changes
- Frontend code changes
- Database migrations
- Infrastructure changes
- Test changes

### Step 2: Parallel Reviews

Run these reviews **in parallel** for efficiency:

#### Security Review

Use the **security-auditor agent** to check:

- OWASP Top 10 vulnerabilities
- Multi-tenant data isolation
- Secret management
- Authentication/authorization
- Input validation

#### Code Quality Review

Use the **review-tech-lead agent** to check:

- Project conventions compliance
- Code clarity and maintainability
- Error handling patterns
- TypeScript quality (no untyped `any`)
- Naming and structure

#### Test Quality Review

Use the **review-test-architect agent** to check:

- Test coverage for new code
- Assertion quality (not just "toBeDefined")
- Test independence
- E2E test reliability

### Step 3: Conditional Reviews

Based on what changed, also run:

**If backend changes:**

- Verify service namespace imports
- Check repository factory pattern
- Validate Zod schemas

**If frontend changes:**

- Verify useCallback for API hooks
- Check Big.js usage for decimals
- Validate MSAL configuration

**If database changes:**
Use **database-migration-expert agent** to verify:

- Migration is reversible
- Indexes created concurrently
- Multi-tenancy columns present

**If infrastructure changes:**
Use **review-azure-architect agent** and **review-devops-architect agent** to verify:

- Security hardening
- Cost optimization
- Deployment safety

### Step 4: Consolidate Findings

Compile all review findings into categories:

- **Blocking**: Must fix before merge
- **Should Fix**: Expected to address
- **Suggestions**: Optional improvements

## Output

Provide a consolidated review report:

```markdown
## Full Review Summary

**Verdict**: APPROVE / REQUEST CHANGES / BLOCK

### Security Review

- [findings]

### Code Quality Review

- [findings]

### Test Quality Review

- [findings]

### Blocking Issues

1. [issue]

### Should Fix

1. [issue]

### Suggestions

1. [suggestion]
```
