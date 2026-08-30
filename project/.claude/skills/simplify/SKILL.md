---
name: simplify
description: 'Review changed code for reuse, quality, and efficiency, then fix any issues found. Respects simplify-ignore annotations to protect critical code blocks.'
model: sonnet
---

# Simplify Workflow

You are reviewing code for simplification opportunities — reducing complexity, improving readability, and eliminating unnecessary abstractions while preserving behavior.

## Pre-flight

1. Identify changed files (from git diff or user input)
2. For each file, check for `simplify-ignore-start` / `simplify-ignore-end` annotations
3. Protected blocks are automatically hidden by the simplify-ignore hook — do NOT attempt to modify placeholder lines (`BLOCK_*`)

## Simplification Targets

- Unnecessary abstractions or indirection
- Overly complex conditionals that can be flattened
- Redundant null/undefined checks
- Copy-paste code that should use shared utilities
- Unused imports, variables, or parameters
- Verbose patterns that have concise idiomatic alternatives

## Protection Categories

The following categories mark code that MUST NOT be simplified:

- `perf-critical` — Performance-sensitive code with measured benchmarks
- `business-rule` — Business logic matching stakeholder-verified formulas
- `workaround` — Temporary fixes for known platform/library bugs
- `integration-contract` — External API contracts that must match exactly

## Chesterton's Fence Gate

Before simplifying any block of code longer than 5 lines, you MUST:

1. Explain the purpose of the block in one sentence
2. State why simplification won't break that purpose
3. Only then proceed with the change

If you cannot explain the purpose, ASK the user before modifying.

## Rule of 500 Advisory

When a file exceeds 500 lines:

- Flag it with: "This file is {N} lines. Consider extracting:"
- Suggest 2-3 extraction targets based on logical grouping
- Do NOT auto-extract — present options to user

## Test After Each Step

After each simplification change:

1. Run affected tests: `nx run-many -t test --projects={affected}`
2. If tests fail, revert the change immediately
3. Only proceed to next change after green tests
