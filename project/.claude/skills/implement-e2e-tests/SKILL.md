---
name: implement-e2e-tests
description: "Create Playwright end-to-end tests using the Page Object Model pattern for Acme frontend flows. Use when the user needs E2E test coverage for a feature or user flow. Do not use for unit tests (use implement-unit-tests) or integration tests (use implement-integration-tests)."
model: sonnet
disable-model-invocation: true
args: <feature-or-flow>
---

# Implement E2E Tests

## Input

- **feature-or-flow**: The feature or user flow to test (e.g., "invoice finalization", "user login")

## Workflow

### Step 1: Analyze the Feature

1. Read the feature requirements or user story
2. Identify the pages/screens involved
3. List the critical user flows to test
4. Categorize tests:
   - **Smoke tests** (`@smoke`): Critical path, run on every PR
   - **Regression tests**: Full coverage, run nightly

### Step 2: Create/Update Page Objects

Create `apps/legacy-web-e2e/src/pages/<feature>.page.ts` using the Page Object template from `references/test-templates.md`. Include locators for container, submit button, table, and search input. Add navigation, action, and assertion helper methods.

### Step 3: Create Test File

Create `apps/legacy-web-e2e/src/tests/<feature>.spec.ts` using the test file template from `references/test-templates.md`. Include:
- **Smoke tests** (`@smoke`): list display, search functionality
- **Regression tests**: create, edit, empty state, error handling

### Step 4: Add Missing data-testid Attributes

Add `data-testid` attributes to frontend components that lack them. Use the naming convention `<feature>-<element>` (e.g., `<feature>-container`, `<feature>-table`). Document all added test IDs in the output.

### Step 5: Update Fixtures (if needed)

If the auth fixture does not exist, create it using the template from `references/test-templates.md` (Auth Fixture section).

### Step 6: Run Tests

```bash
# Run all tests for this feature
npx nx run legacy-web-e2e:e2e -- --grep="<Feature>"

# Run smoke tests only
npx nx run legacy-web-e2e:e2e -- --grep="@smoke"

# Run in headed mode for debugging
npx nx run legacy-web-e2e:e2e -- --headed --grep="<Feature>"

# Run in UI mode
npx nx run legacy-web-e2e:e2e -- --ui
```

## Output

````markdown
## E2E Tests Implemented: <feature>

### Files Created/Modified

- `src/pages/<feature>.page.ts` (created)
- `src/tests/<feature>.spec.ts` (created)
- `src/fixtures/auth.fixture.ts` (modified, if needed)

### Test Coverage

| Category | Tests | Description |
| ---------- | ----- | -------------------------- |
| Smoke | 2     | List display, search |
| Regression | 4     | Create, edit, empty, error |

### Test IDs Added to Frontend

- `<feature>-container`
- `<feature>-table`
- `<feature>-submit-button`
- `<feature>-search-input`

### Run Commands

```bash
# All tests
npx nx run legacy-web-e2e:e2e -- --grep="<Feature>"

# Smoke only
npx nx run legacy-web-e2e:e2e -- --grep="@smoke" --grep="<Feature>"
```
````

### Verification

| Test Suite | Status |
| ---------- | ------ |
| Smoke | ✅     |
| Regression | ✅     |

## Conventions

- Page Objects in `src/pages/`
- Tests in `src/tests/`
- Use `data-testid` for stable selectors
- Tag smoke tests with `@smoke`
- Use `authenticatedPage` fixture for auth
- Wait for `networkidle` after navigation/actions
- Test both happy path and error cases
