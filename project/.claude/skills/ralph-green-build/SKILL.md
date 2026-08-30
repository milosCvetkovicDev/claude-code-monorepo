---
name: ralph-green-build
description: "Ralph Loop: fix everything until build, lint, typecheck, and tests all pass. Use when the user wants an autonomous loop to achieve a fully green build. Do not use for test-only failures (use ralph-fix-tests) or single-bug TDD (use ralph-debug)."
model: sonnet
args: "[--base <ref>]"
---

# Ralph Green Build

Start a Ralph Loop that gets the entire build pipeline green: typecheck, lint, build, and tests — fixing issues in priority order until everything passes.

## When to Use

- After merging main and getting a broken build
- After a dependency update broke multiple things
- Before creating a PR — ensure everything is clean
- CI pipeline failures that need fixing locally
- Overnight "make it green" runs in a tmux session

## Input

- **--base** (optional): Git ref to compare against for affected scope (default: `main`)

## Workflow

### Step 1: Launch Ralph Loop

Invoke `/ralph-loop` with:

```
/ralph-loop "You are getting the Acme monorepo build pipeline fully green.

## Pipeline Order (fix in this sequence)
1. Typecheck — type errors block everything
2. Lint — style issues are fast to fix
3. Build — compilation must succeed
4. Tests — verify behavior

## On Each Iteration

### Step 1: Run Pipeline
Execute these commands and capture ALL output:

1. 'npx nx affected -t typecheck --base=<BASE>' (or 'npx nx run-many -t typecheck' if no base)
2. 'npx nx affected -t lint --base=<BASE>'
3. 'npx nx affected -t build --base=<BASE>'
4. 'npx nx affected -t test --base=<BASE>'

### Step 2: Triage
Count failures per stage. Fix in priority order:
- Typecheck errors FIRST (they cascade into build/test failures)
- Lint errors SECOND (quick wins)
- Build errors THIRD
- Test failures LAST (once everything compiles)

### Step 3: Fix
For each failure:
1. Read the error message carefully
2. Locate the source file
3. Implement the minimal fix
4. Follow Acme conventions:
   - Big.js for money — never Number
   - Functional service exports — never classes
   - Repository factory with TradingCompany
   - TypeScript strict mode — no escape hatches
   - Zod for request validation

### Step 4: Verify
Re-run the specific stage that failed:
- 'npx nx run <project>:typecheck' for type errors
- 'npx nx run <project>:lint' for lint errors
- 'npx nx run <project>:test' for test failures

### Step 5: Commit
After fixing a batch of related issues:
1. Run 'npx nx format:write'
2. Commit: 'fix(<project>): fix <typecheck|lint|build|test> errors — <summary>'

## Decision Rules
- Type errors: add proper types, NEVER add 'any' or '// @ts-ignore'
- Lint errors: fix the code, don't disable rules
- Build errors: check imports, missing exports, circular deps
- Test errors: determine if source or test is wrong (check spec/CLAUDE.md)
- If an error repeats 3 times: document it, skip to next error

## Completion
When ALL four pipeline stages pass, output: <promise>BUILD GREEN</promise>
Only output this when ALL of these are true:
1. 'npx nx affected -t typecheck --base=<BASE>' exits 0
2. 'npx nx affected -t lint --base=<BASE>' exits 0
3. 'npx nx affected -t build --base=<BASE>' exits 0
4. 'npx nx affected -t test --base=<BASE>' exits 0" --completion-promise "BUILD GREEN" --max-iterations 30
```

## Example Usage

```
# Fix everything affected since main
/ralph-green-build

# Fix everything affected since a specific commit
/ralph-green-build --base HEAD~10
```

## Safety

- Max 30 iterations
- Fixes in dependency order (types → lint → build → tests)
- Never disables lint rules or adds `@ts-ignore`
- Commits per batch of related fixes
- Documents persistent errors instead of looping forever
