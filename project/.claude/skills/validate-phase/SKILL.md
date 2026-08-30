---
name: validate-phase
description: "Verify that a completed implementation phase meets its technical specification criteria. Use when a phase has been implemented and the user wants to confirm it matches the spec. Do not use for general code review (use code-review) or running tests (use test-affected)."
model: sonnet
disable-model-invocation: true
args: <spec-file> --phase <number>
---

# Validate Phase

You are validating that a phase implementation meets its acceptance criteria.

## Input

- **Spec file**: Path to technical specification
- **Phase number**: Which phase to validate

## Workflow

### Step 1: Extract Validation Criteria

1. Read the technical specification
2. Find the phase's "Validation" section
3. Parse each criterion into a testable check

### Step 2: Run Standard Checks

Always run these checks for the affected project:

| Check | Command | Pass Condition |
| ---------- | ---------------------------- | -------------------------- |
| Build | `nx run <project>:build`     | Exit code 0                |
| Lint | `nx run <project>:lint`      | Exit code 0, no errors |
| Test | `nx run <project>:test`      | Exit code 0, all pass |
| Type Check | `nx run <project>:typecheck` | Exit code 0 (if available) |

### Step 3: Run Custom Criteria

For each custom criterion in the spec's Validation section, determine how to test it:

| Criterion Type | Test Method |
| ------------------------------ | --------------------------------------------------- |
| "Server starts without errors" | Run server, check for startup log, kill after 5s |
| "Can query database"           | Run integration test or manual query |
| "Tool returns expected output" | Invoke tool, validate JSON schema |
| "Multi-tenancy is enforced"    | Run unit test verifying tradingCompanyId validation |
| "API endpoint returns 200"     | Use curl or run integration test |

### Step 4: Report Results

## Output Format

### Success

```markdown
## Phase N Validation Results

### Standard Checks

| Check | Status | Details |
| ---------- | ------- | ---------------------- |
| Build | ✅ Pass | 2.3s |
| Lint | ✅ Pass | 0 errors, 0 warnings |
| Test | ✅ Pass | 15 tests, 100% passing |
| Type Check | ✅ Pass | No errors |

### Custom Criteria

| Criterion | Status | Evidence |
| -------------------------------- | ------- | ---------------------------------------- |
| MCP server starts without errors | ✅ Pass | Server started on stdio, no errors in 5s |
| Basic health check tool works | ✅ Pass | Returned `{"status": "ok"}`              |

### Overall: ✅ PASS

Phase N validation complete. Ready for Phase N+1.
```

### Failure

```markdown
## Phase N Validation Results

### Standard Checks

| Check | Status | Details |
| ----- | ------- | ----------------------- |
| Build | ✅ Pass | 2.3s |
| Lint | ❌ Fail | 3 errors |
| Test | ⚠️ Skip | Blocked by lint failure |

### Lint Errors
```

apps/acme-mcp/src/services/database.service.ts:15:1
error: Unexpected 'any'. Specify a different type.

```

### Overall: ❌ FAIL

Fix lint errors before proceeding.

### Suggested Fixes

1. Replace `any` with proper type at line 15
```

## Optional: Run Review Agents

If the user requests `--with-review`, also run:

1. `review-tech-lead` on changed files
2. `review-enterprise-architect` on architecture

Report any critical/high findings that should be addressed before proceeding.
