---
name: ralph-debug
description: "Ralph Loop: TDD bug fix — write failing test, fix, verify, iterate until resolved. Use when the user wants an autonomous TDD cycle for a specific bug. Do not use for non-bug test failures (use ralph-fix-tests) or manual debugging (use bug-fix)."
model: sonnet
args: <bug-description> [--project <name>] [--github-issue <number>]
---

# Ralph Debug

Start a Ralph Loop that follows TDD methodology to fix a bug: write a failing test first, then implement the fix, and iterate until the test passes.

## When to Use

- Reproducing and fixing a reported bug
- Fixing a bug linked to a GitHub issue
- Overnight bug-fixing in a tmux session
- Complex bugs requiring multiple fix attempts

## Input

- **bug-description** (required): Description of the bug to fix
- **--project** (optional): Target Nx project (default: `legacy-api`)
- **--github-issue** (optional): GitHub issue number for context

## Workflow

### Step 1: Gather Context

If `--github-issue` provided, fetch issue details:
```bash
gh issue view <number> --json title,body,labels,comments
```

### Step 2: Launch Ralph Loop

Invoke `/ralph-loop` with the following prompt:

```
/ralph-loop "You are fixing a bug in the Acme monorepo using TDD.

## Bug Description
<BUG_DESCRIPTION>

## Target Project
<PROJECT> (default: legacy-api)

## GitHub Issue
<ISSUE_DETAILS or 'None'>

## TDD Workflow (STRICT ORDER)

### Phase 1: Investigate (iteration 1-2)
1. Search codebase for relevant code paths (use Grep/Glob)
2. Read related source files, tests, and CLAUDE.md
3. Identify the root cause
4. Check if multi-tenancy is involved
5. Document: affected files, root cause, expected vs actual behavior

### Phase 2: Write Failing Test (iteration 2-3)
1. Write a test that reproduces the bug BEFORE fixing anything
2. The test MUST:
   - Describe the bug clearly in the test name
   - Assert the CORRECT expected behavior
   - Include edge cases discovered during investigation
3. Run the test: 'npx nx run <project>:test -- --testNamePattern=\"<test-name>\"'
4. Verify the test FAILS (proves it catches the bug)
5. If test passes: your test doesn't catch the bug — rewrite it

### Phase 3: Implement Fix (iteration 3-5)
1. Implement the MINIMAL fix — don't over-engineer
2. Follow Acme conventions:
   - Big.js for any decimal/money calculations
   - Repository factory with TradingCompany
   - Functional service exports (not classes)
   - Zod validation for inputs
3. Run the specific test: 'npx nx run <project>:test -- --testNamePattern=\"<test-name>\"'
4. If test passes: move to Phase 4
5. If test fails: analyze error, adjust fix, retry

### Phase 4: Regression Check (iteration 5-6)
1. Run full project tests: 'npx nx run <project>:test'
2. If regressions found: fix them without breaking the bug fix test
3. Run affected tests: 'npx nx affected -t test'

### Phase 5: Commit (iteration 6-7)
1. Run 'npx nx format:write'
2. Stage changes: source fix + new test
3. Commit: 'fix(<project>): <concise bug description>'
4. If GitHub issue provided, include 'Fixes #<number>' in commit body

## Decision Rules
- Fix SOURCE code when: test expectation matches the spec
- Fix TEST code when: test has wrong expectations
- If the bug is in multi-tenancy: ALWAYS verify tradingCompanyId filtering
- If the bug involves money: ALWAYS use Big.js (never floating point)
- After 3 failed fix attempts: document what you tried, ask for approach

## Completion
When the bug fix test passes AND no regressions exist, output: <promise>BUG FIXED AND TESTS PASSING</promise>
Only output this when:
1. The new bug-reproducing test passes WITH the fix
2. All project tests pass (no regressions)
3. Changes are committed" --completion-promise "BUG FIXED AND TESTS PASSING" --max-iterations 15
```

## Example Usage

```
# Fix a described bug
/ralph-debug "Commission totals are wrong for multi-currency invoices"

# Fix a bug from a GitHub issue
/ralph-debug "Invoice PDF shows wrong dates" --github-issue 142

# Fix a frontend bug
/ralph-debug "DataGrid pagination resets on filter change" --project legacy-web
```

## Safety

- Max 15 iterations (TDD shouldn't need more)
- Test-first approach ensures the fix is verified
- Regression check catches collateral damage
- Commits only when fix + tests are green
- Documents approach after 3 failed attempts
