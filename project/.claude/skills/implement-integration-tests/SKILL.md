---
name: implement-integration-tests
description: "Create integration tests that verify database interactions and API endpoint behavior together. Use when the user needs tests spanning service + database layers. Do not use for unit tests (use implement-unit-tests) or E2E browser tests (use implement-e2e-tests)."
model: sonnet
disable-model-invocation: true
args: <module-or-endpoint>
---

# Implement Integration Tests

## Input

- **module-or-endpoint**: The module or API endpoint to test (e.g., `SaleInvoicesRepository`, `POST /api/v1/invoices`)

## Workflow

### Step 1: Analyze Integration Points

1. Identify dependencies:
   - Database tables involved
   - External APIs called
   - File system access
2. Determine test isolation strategy:
   - Transaction rollback (preferred)
   - Test database cleanup
   - Mock external services

### Step 2: Set Up Test Database Utilities

Create `apps/legacy-api/test/utils/test-db.ts` using the utility pattern from `references/test-templates.md` (Test Database Utility section).

### Step 3: Create Repository Integration Test

Create `test/integration/repositories/<Repository>.integration.spec.ts` using the repository test template from `references/test-templates.md`. Include tests for:
- `findAll` — returns only entities for the given trading company
- `findById` — returns entity when found, null when not
- `create` — creates entity with correct trading company

### Step 4: Create API Integration Test

Create `test/integration/routes/<resource>.integration.spec.ts` using the API test template from `references/test-templates.md`. Include tests for:
- `GET /resources` — 200 with list, 401 without auth, 403 for wrong trading company
- `POST /resources` — 201 on success, 400 for invalid input
- `GET /resources/:id` — 200 when found, 404 when not

### Step 5: Create Seed Data

Create `test/fixtures/seed.ts` using the seed template from `references/test-templates.md`. Seed two trading companies and a test user.

### Step 6: Run Tests

```bash
# Run integration tests (requires database)
nx run legacy-api:test -- --testPathPattern=integration

# Run specific integration test
nx run legacy-api:test -- --testPathPattern=<Resource>.integration

# Run with verbose output
nx run legacy-api:test -- --testPathPattern=integration --verbose
```

## Output

````markdown
## Integration Tests Implemented: <module-or-endpoint>

### Test Files

- `test/integration/repositories/<Repository>.integration.spec.ts`
- `test/integration/routes/<resource>.integration.spec.ts`

### Test Coverage

| Endpoint/Method | Tests | Status |
| ------------------ | ----- | ------ |
| GET /resources | 3     | ✅     |
| POST /resources | 2     | ✅     |
| GET /resources/:id | 2     | ✅     |

### Multi-Tenancy Tests

- ✅ Returns only data for authenticated trading company
- ✅ Rejects requests for unauthorized trading company
- ✅ Creates entities with correct trading company ID

### Setup Requirements

- Test database: `legacy_test`
- Docker: PostgreSQL must be running
- Seed data: Automatically created/cleaned per test

### Run Command

```bash
nx run legacy-api:test -- --testPathPattern=integration
```
````

## Conventions

- Use transaction rollback for test isolation
- Test multi-tenancy boundaries
- Test authentication and authorization
- Seed test data in beforeAll
- Clean up with transaction rollback in afterEach
- Separate integration tests from unit tests
