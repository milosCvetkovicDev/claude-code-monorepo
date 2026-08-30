---
name: test-affected
description: "Run tests only for Nx projects affected by current git changes using nx affected. Use when the user wants to verify their changes pass tests without running the entire test suite. Do not use for writing new tests (use implement-unit-tests) or debugging test failures (use debug-loop)."
model: haiku
---

# Test Affected Projects

Run tests only for projects affected by recent changes.

## Workflow

### 1. Check What's Affected

```bash
# See affected projects
npx nx show projects --affected

# See affected projects with base
npx nx show projects --affected --base=main
```

### 2. Run Affected Tests

```bash
# Run tests for affected projects
npx nx affected -t test

# With specific base branch
npx nx affected -t test --base=main

# With verbose output
npx nx affected -t test --verbose
```

### 3. Run Affected Lint (Optional)

```bash
npx nx affected -t lint
```

### 4. Run All Affected Targets

```bash
# Run both lint and test
npx nx affected -t lint test
```

## Options

| Flag | Purpose |
| ----------------- | ----------------------------------------------------- |
| `--base=<ref>`    | Base commit/branch to compare against (default: main) |
| `--head=<ref>`    | Head commit/branch (default: HEAD)                    |
| `--verbose`       | Show detailed output |
| `--parallel=<n>`  | Run n tasks in parallel |
| `--skip-nx-cache` | Skip Nx cache |

## Common Scenarios

### Before Committing

```bash
npx nx affected -t lint test --base=HEAD~1
```

### Before PR

```bash
npx nx affected -t lint test --base=main
```

### After Merging Main

```bash
npx nx affected -t test --base=main~1
```

## Output

Report:

- Which projects are affected
- Test results (pass/fail)
- Any failing tests with details
- Coverage summary if available
