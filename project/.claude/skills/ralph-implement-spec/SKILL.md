---
name: ralph-implement-spec
description: "Ralph Loop: implement all phases of a technical spec autonomously with continuous verification. Use when the user has a spec file and wants fully autonomous implementation. Do not use for manual phase-by-phase work (use implement-phase) or non-spec feature work (use new-feature)."
model: sonnet
args: <spec-file> [--start-phase <N>]
---

# Ralph Implement Spec

Start a Ralph Loop that reads a technical specification and implements all phases sequentially, validating each phase before moving to the next.

## When to Use

- Implementing a multi-phase technical spec overnight
- Long-running feature implementation in a tmux session
- Resuming spec implementation from a specific phase
- Hands-off implementation of approved specs

## Input

- **spec-file** (required): Path to approved technical specification (e.g., `docs/plans/commission-export-spec.md`)
- **--start-phase** (optional): Phase number to start from (default: 1). Use when resuming.

## Prerequisites

Before launching:

1. Spec MUST be approved (check for review summary section)
2. Branch should be clean (`git status` shows no uncommitted changes)
3. Database should be running (`docker compose up -d`)

## Workflow

### Step 1: Validate Inputs

1. Verify spec file exists and is readable
2. Check for approval markers in the spec
3. Determine starting phase number
4. Count total phases in the spec

### Step 2: Launch Ralph Loop

Invoke `/ralph-loop` with the following prompt (substitute spec path and start phase):

```
/ralph-loop "You are implementing a technical specification for the Acme monorepo.

## Spec File
Read: <SPEC_FILE>

## Starting Phase
Begin at Phase <START_PHASE>. Skip already-completed phases (check git log for commits matching 'feat(*): implement phase N').

## For Each Phase
1. Read the phase section from the spec
2. Read relevant CLAUDE.md files (root + target project)
3. Create tasks from the phase requirements
4. Implement each task following Acme conventions
5. After all tasks: run validation
   - npx nx run <project>:build
   - npx nx run <project>:lint
   - npx nx run <project>:test
   - Any custom validation criteria from the spec
6. If validation passes:
   - Run 'npx nx format:write'
   - Stage and commit: 'feat(<project>): implement phase N - <title>'
   - Move to Phase N+1
7. If validation fails:
   - Analyze the error
   - Fix and retry (up to 3 attempts per phase)
   - If stuck after 3 attempts: commit partial work, document blocker, move to next phase

## Acme Conventions (CRITICAL)
- ALWAYS use Nx generators for new projects/libs: 'nx generate @nx/<plugin>:application|library'
- NEVER manually create directories for apps or libs
- Backend services: functional exports, NOT classes
- Repository factory pattern with TradingCompany parameter
- Big.js for money/decimals — API sends strings, DB stores numeric
- Dates: UTC always, ISO format in API, timestamptz in DB
- Multi-tenancy: tradingCompanyId as first parameter in service functions
- Zod for request validation
- TypeScript strict mode — no 'any' without justification

## Commit Strategy
- One commit per phase: 'feat(<project>): implement phase N - <phase-title>'
- Run 'npx nx format:write' before every commit
- Include Co-Authored-By line

## Progress Tracking
At the start of each iteration, check git log for completed phase commits.
Report: 'Phase N/M: <title> — [DONE|IN PROGRESS|PENDING]'

## Completion
When ALL phases are implemented and validated, output: <promise>ALL PHASES COMPLETE</promise>
Only output this when every phase has a passing commit." --completion-promise "ALL PHASES COMPLETE" --max-iterations 50
```

## Example Usage

```
# Implement full spec from the beginning
/ralph-implement-spec docs/plans/commission-export-spec.md

# Resume from phase 4
/ralph-implement-spec docs/plans/acme-mcp-spec.md --start-phase 4
```

## Safety

- Max 50 iterations (enough for 8 phases with retries)
- One commit per phase (easy to revert individual phases)
- Never uses `--force` flags
- Documents blockers instead of silently skipping
- Checks git log to avoid re-implementing completed phases
