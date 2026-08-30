# Test-First Development Rule

All features follow the Red-Green-Refactor cycle. Tests are the specification, not an afterthought.

## Core Principles

1. **Tests BEFORE implementation** — Write failing tests first (red), then make them pass (green), then refactor
2. **Gherkin for acceptance criteria** — User stories use `Given/When/Then` syntax
3. **No commit without passing tests** — Every commit must have all related tests green
4. **Production verification is part of Done** — Features aren't done until verified in production

## Acceptance Criteria Format

All PRD user stories must include Gherkin scenarios:

```gherkin
Feature: {feature_name}
  As a {persona}
  I want {capability}
  So that {benefit}

  Scenario: {scenario_name}
    Given {precondition}
    When {action}
    Then {expected_result}
```

## Test Layer Requirements

Every feature must include:

### 1. Acceptance Tests (Gherkin)
- `.feature` files defining expected behavior in plain English
- Serve as living documentation and the acceptance gate

### 2. E2E Tests (Playwright)
- Follow Page Object Model pattern
- Use `BasePage` / `BasePaginatedPage` base classes
- Locators: prefer `getByRole()` > `getByLabel()` > `[data-testid]`
- Tags: `@smoke` for critical paths, `@crud` for CRUD operations
- Test IDs: `FEAT-001`, `FEAT-002` prefix format
- Always clean up mocks in `afterEach`

### 3. Integration Tests
- **Jest + supertest** (legacy-api): `// given / // when / // then` comments, Builder pattern, `setupDatabase()` lifecycle
- **Bun test + Elysia** (domain-api): `bun:test` imports, `app.handle(new Request(...))`, `mock.module()` for mocking
- Real database for legacy integration tests, mocked repos for domain-api

### 4. Unit Tests
- **Jest** (legacy services, legacy-web components): `mockRepositoryWith()`, `@testing-library` patterns
- **Bun test** (domain-api): pure function testing, `bun:test` imports
- Test one thing per test, use descriptive names

## Task Ordering

When decomposing epics into tasks:
1. **Test tasks come FIRST** (lowest sequence numbers, no dependencies)
2. **Implementation tasks depend on test tasks** (code makes tests pass)
3. **Production verification task is LAST** (depends on all other tasks)

## Agent Instructions

When agents are spawned to work on tasks:
1. Read acceptance criteria from the task file
2. Check if tests already exist (from `/pm:tests-generate`)
3. If no tests exist, write failing tests FIRST (red phase)
4. Implement code to make tests pass (green phase)
5. Run tests before every commit — only commit when all tests pass
6. Check test manifest at `.claude/epics/{epic}/test-manifest.md`
7. **REFACTOR** — Once tests are green, improve code quality:
   - Remove duplication (DRY)
   - Improve naming and readability
   - Simplify complex logic
   - Ensure consistent patterns with existing codebase
   - Run tests again after refactoring — must stay green
8. **Self-review** — Check your own changes for bugs, edge cases, and adherence to project conventions before marking done

## Complementary Quality Tools

These tools enhance the TDD cycle but do not replace it:

### Before Writing Tests (RED phase)
- `/qodo-skills:qodo-get-relevant-rules` — load project-specific coding standards
- `/superpowers:test-driven-development` — interactive TDD enforcement

### During Implementation (GREEN phase)
- **semgrep** (automatic) — scans every Write/Edit for security issues
- **auto-format** (automatic) — runs Prettier after every file edit
- **pre-commit-checks** (automatic) — typecheck + affected tests before every commit

### After Implementation (REFACTOR phase)
- `/superpowers:verification-before-completion` — evidence-based self-check
- `/superpowers:requesting-code-review` — automated code review dispatch

### Full workflow context
See `/rules/quality-workflow.md` for the end-to-end process that wraps TDD.

## Definition of Done

Every task must satisfy:
- [ ] Acceptance tests written (Gherkin scenarios)
- [ ] Unit tests written and passing
- [ ] Integration tests written and passing
- [ ] E2E tests pass (if UI changes involved)
- [ ] Code refactored for quality (refactor phase)
- [ ] Self-reviewed for bugs, edge cases, and conventions
- [ ] Automated code review passed (`/pm:epic-review`)
- [ ] PR created and CI checks pass
- [ ] Production verification steps documented
- [ ] Architecture decisions referenced in Dev Notes (if architecture.md exists)
- [ ] Dev Agent Record completed (model, files, completion notes)

Every epic must additionally satisfy:
- [ ] All task tests pass in CI
- [ ] Production health check passes after deployment
- [ ] Business smoke test passes in production
- [ ] Application Insights monitored for 15 minutes post-deploy — no new errors
- [ ] Stakeholder sign-off (if required by PRD)

## Production Verification

Features are NOT done when merged. They are done when verified in production:

1. **Infrastructure**: Health endpoints respond correctly
2. **Business logic**: Key API calls return expected data
3. **Monitoring**: No new errors in Application Insights for 15 minutes
4. **Rollback criteria**: Know what failure looks like and how to roll back

## Framework Detection

When generating tests, detect the target app:
- `legacy-api` → Jest + supertest + TypeORM + Builder pattern
- `legacy-web` → Jest + @testing-library + @swc/jest
- `domain-api` → Bun test + Elysia `app.handle()`
- `legacy-web-e2e` → Playwright + BasePage POM
- `domain-web-e2e` → Playwright + BasePage POM

Read `jest.config.ts`, `project.json`, or `playwright.config.ts` to confirm.
