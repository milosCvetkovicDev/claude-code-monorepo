---
name: ralph-fix-tests
description: "Ralph Loop: autonomously fix all failing tests until green. Use when tests are broken and the user wants an automated fix loop. Do not use for writing new tests (use implement-unit-tests) or non-test build failures (use ralph-green-build)."
model: sonnet
args: "[--project <name>] [--base <ref>]"
---

# Ralph Fix Tests

Start a Ralph Loop that autonomously runs failing tests, analyzes errors, implements fixes, and iterates until all tests pass.

## When to Use

- Multiple tests failing after a merge or rebase
- Test suite broken by dependency updates
- Fixing tests after a large refactoring
- Overnight test-fixing runs in a tmux session

## Input

- **--project** (optional): Specific Nx project to test (e.g., `legacy-api`, `legacy-web`). Defaults to affected projects.
- **--base** (optional): Git ref to compare against (default: `main`)

## Workflow

### Step 1: Determine Scope

Based on arguments, build the test command:

- If `--project` provided: `npx nx run <project>:test`
- If `--base` provided: `npx nx affected -t test --base=<ref>`
- Default: `npx nx affected -t test --base=main`

### Step 2: Launch Ralph Loop

Invoke `/ralph-loop` with the following prompt (substitute the test command):

```
/ralph-loop "You are fixing failing tests in the Acme monorepo.

## Your Task
Run: <TEST_COMMAND>

## On Each Iteration
1. Run the test command and capture ALL output
2. Count total tests, passing, and failing
3. For each failing test:
   - Read the error message and stack trace
   - Locate the source file and test file
   - Determine if the fix belongs in SOURCE code or TEST code
   - Implement the MINIMAL fix
4. Re-run the test command to verify
5. If new failures appear, fix those too

## Acme Conventions (CRITICAL)
- Use Big.js for ALL money/decimal calculations — never raw Number
- Multi-tenancy: every query MUST filter by tradingCompanyId
- Service pattern: functional exports (not classes)
- Repository pattern: use factory with TradingCompany parameter
- Zod for validation schemas
- Use Nx commands: 'npx nx run <project>:test' — NEVER raw jest

## Decision Rules
- Fix SOURCE code when: test expectation matches the spec/requirements
- Fix TEST code when: test has wrong expectations, outdated mocks, or bad assertions
- If unsure which is correct: check the technical spec in docs/plans/ or CLAUDE.md
- After 3 failed attempts on the same error: commit what works, document the blocker

## Commit Strategy
- Commit after every batch of successful fixes: 'fix(<project>): fix failing tests - <summary>'
- Run 'npx nx format:write' before staging

## Completion
When ALL tests pass, output: <promise>ALL TESTS PASSING</promise>
Only output this when the test command exits with code 0 and zero failures." --completion-promise "ALL TESTS PASSING" --max-iterations 25
```

## Example Usage

```
# Fix all affected tests
/ralph-fix-tests

# Fix only backend tests
/ralph-fix-tests --project legacy-api

# Fix tests broken since a specific commit
/ralph-fix-tests --base HEAD~5
```

## Safety

- Max 25 iterations by default (prevents runaway loops)
- Commits after each batch of fixes (easy rollback with `git revert`)
- Never changes test expectations without checking the spec first
- Stops and documents blockers after 3 attempts on the same error
