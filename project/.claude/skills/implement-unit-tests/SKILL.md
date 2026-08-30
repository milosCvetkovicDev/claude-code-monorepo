---
name: implement-unit-tests
description: "Create Jest unit tests for backend services, domain logic, or frontend component logic. Use when the user needs isolated unit test coverage. Do not use for integration tests with database (use implement-integration-tests) or Playwright E2E tests (use implement-e2e-tests)."
model: sonnet
disable-model-invocation: true
args: <file-or-module>
---

# Implement Unit Tests

## Input

- **file-or-module**: The file or module to test (e.g., `InvoicesService`, `InvoiceTable.tsx`)

## Workflow

### Step 1: Analyze the Target

1. Read the source file to understand:
   - Functions/methods to test
   - Dependencies to mock
   - Edge cases and error paths
2. Determine test file location:
   - Backend: `test/unit/<path>/<File>.spec.ts`
   - Frontend: `src/<path>/<File>.spec.tsx`

### Step 2: Create Test File (Backend)

Create `test/unit/services/<Service>.spec.ts` using the backend test template from `references/test-templates.md`. Include tests for:
- Happy path (return expected data)
- Not found (throw NotFoundError)
- Multi-tenancy enforcement (tradingCompany passed to repository)
- Edge cases (null, empty, boundary values)

### Step 3: Create Test File (Frontend Component)

Create `src/components/<path>/<Component>.spec.tsx` using the frontend test template from `references/test-templates.md`. Include tests for:
- Rendering data correctly
- Click/select callbacks
- Loading state
- Empty state
- User input handling

### Step 4: Create Test Fixtures

Create fixtures using the templates from `references/test-templates.md` (Test Fixtures section):
- Backend: `test/fixtures/<entity>.fixture.ts` with `createMock<Entity>` factory
- Frontend: `test/utils.ts` with `createTestQueryClient` helper

### Step 5: Test Edge Cases

Always test:

1. **Happy path**: Normal operation
2. **Not found**: Entity doesn't exist
3. **Validation errors**: Invalid input
4. **Empty state**: No data
5. **Multi-tenancy**: tradingCompany enforcement (backend)
6. **Loading state**: Async operations (frontend)
7. **Error handling**: API failures

### Step 6: Run Tests

```bash
# Run specific test file
nx run <project>:test -- --testPathPattern=<File>.spec

# Run with coverage
nx run <project>:test -- --coverage --testPathPattern=<File>.spec

# Run in watch mode
nx run <project>:test -- --watch --testPathPattern=<File>.spec
```

## Output

````markdown
## Unit Tests Implemented: <File>

### Test File

`<test-file-path>`

### Test Coverage

| Function/Method | Tests | Coverage |
| --------------- | ----- | -------- |
| <functionName>  | 4     | 100%     |
| <anotherFunc>   | 3     | 95%      |

### Test Cases

- ✅ should return data when found
- ✅ should throw NotFoundError when not found
- ✅ should enforce multi-tenancy
- ✅ should handle empty input
- ✅ should validate required fields

### Mocked Dependencies

- `<Repository>` - Database access
- `use<Feature>Query` - Data fetching hook

### Run Command

```bash
nx run <project>:test -- --testPathPattern=<File>.spec
```
````

### Coverage Report

| Metric | Percent |
| --------- | ------- |
| Lines | 95%     |
| Branches | 90%     |
| Functions | 100%    |

## Conventions

- Use Arrange-Act-Assert pattern
- One assertion per test (when practical)
- Descriptive test names: "should \<behavior\> when \<condition\>"
- Mock external dependencies
- Test error paths and edge cases
- Verify multi-tenancy for backend services
- Coverage target: 80% lines, 75% branches
