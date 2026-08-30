---
name: new-feature
description: "Plan and implement a new feature from requirements through implementation, including design, spec, and code. Use when the user has a feature request without an existing spec or design. Do not use when a spec already exists (use implement-all) or for bug fixes (use bug-fix)."
model: sonnet
---

# New Feature Workflow

You are orchestrating a new feature from requirements gathering through implementation.

## Workflow Steps

### Step 1: Requirements Gathering

Use the **interview-user agent** to:

- Understand the problem being solved
- Identify user personas and use cases
- Uncover edge cases (empty states, errors, permissions)
- Clarify multi-tenancy requirements
- Determine ERP integration needs
- Document out-of-scope items

Output: Requirements document in `docs/requirements/`

### Step 2: User Story Creation

Use the **user-story-writer agent** to:

- Transform requirements into formal user stories
- Define acceptance criteria (Given/When/Then)
- Estimate complexity (XS/S/M/L/XL)
- Break down XL stories into smaller pieces

Output: User stories with acceptance criteria

### Step 3: Domain Model Review

Use the **ddd-expert agent** to:

- Analyze bounded context impact
- Design aggregates and entities
- Identify value objects needed
- Ensure ubiquitous language alignment
- Review domain event needs

Output: Domain model recommendations

### Step 4: Technical Specification

Use the **technical-spec agent** to:

- Design the technical approach
- Identify affected components
- Define API contracts (decimals as strings!)
- Plan database changes (with tradingCompanyId!)
- Specify testing strategy
- Identify risks and mitigations

Output: Technical spec in `docs/plans/`

### Step 5: Implementation

#### Backend Implementation

Follow project conventions:

- Thin controllers, service namespace imports
- Repository factory pattern with TradingCompany
- Zod validation with validateRequest middleware
- Big.js for decimals, UTC for dates

#### Frontend Implementation

Use the **frontend-specialist agent** to guide:

- React components with proper TypeScript interfaces
- useCallback for API hooks (REQUIRED)
- Response parsing with Big.js for decimals
- MSAL auth with empty scopes
- MUI components following theme patterns

### Step 6: Reviews (Parallel)

Run these reviews in parallel:

- **ddd-expert agent**: Domain model integrity
- **review-tech-lead agent**: Code quality and conventions
- **review-test-architect agent**: Test coverage and quality
- **security-auditor agent**: Security vulnerabilities

### Step 7: Documentation

Use the **documentation-writer agent** if needed to:

- Update API documentation
- Create/update runbooks
- Document architectural decisions (ADR)

## Output

Provide a summary including:

- Feature overview
- Files created/modified
- API endpoints added
- Database migrations created
- Test coverage
- Review findings addressed


## Assumptions Gate

Before starting implementation, explicitly state your assumptions:

```
ASSUMPTIONS:
- [ ] {assumption about requirements}
- [ ] {assumption about architecture}
- [ ] {assumption about scope}
→ Correct me now or I will proceed with these.
```

Present assumptions as a checkbox list. Wait for user confirmation before proceeding. Do not silently fill in ambiguous requirements.
