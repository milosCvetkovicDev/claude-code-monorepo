---
name: implement-all
description: "Execute all phases of a technical specification sequentially with validation between phases. Use when the user has a complete spec and wants to implement everything in order. Do not use for a single phase (use implement-phase) or when no spec exists (use new-feature)."
model: sonnet
args: <spec-file>
disable-model-invocation: true
---

# Implement All Phases

You are implementing all phases from a technical specification sequentially.

## Input

- **Spec file**: Path to technical specification

## Prerequisites

Before starting:

1. Verify the spec exists and is readable
2. Check that the spec has been approved (look for review summary section)
3. If not approved, warn the user and ask if they want to proceed anyway

## Workflow

### Step 1: Parse Specification

1. Read the technical specification file
2. Extract all phases (look for "### Phase N:" or "## Phase N:")
3. Count total phases
4. Create a task list for tracking overall progress

### Step 2: Execute Each Phase

For each phase (in order):

```
Phase N of M: <Phase Title>
├── Run /implement-phase <spec-file> --phase N
├── Run /validate-phase <spec-file> --phase N
├── If validation fails:
│   ├── Report failure
│   ├── Ask user: Fix and retry? Skip? Abort?
│   └── Handle response
└── If validation passes:
    └── Continue to Phase N+1
```

### Step 3: Final Review

After all phases complete:

1. Run `/full-review` on all changed files
2. Report any critical/high findings
3. Suggest fixes if needed

### Step 4: Summary Report

## Output Format

```markdown
## Implementation Complete

### Spec: docs/plans/acme-mcp-technical-spec.md

### Phase Summary

| Phase | Title | Status | Commit |
| ----- | ------------------- | ------- | ------- |
| 1     | Project Scaffolding | ✅ Pass | abc1234 |
| 2     | Core Dev Tools | ✅ Pass | def5678 |
| 3     | Azure Operations | ✅ Pass | ghi9012 |
| 4     | ERP Integration | ✅ Pass | jkl3456 |
| 5     | Code Intelligence | ✅ Pass | mno7890 |
| 6     | Error Handling | ✅ Pass | pqr1234 |
| 7     | Testing & Docs | ✅ Pass | stu5678 |
| 8     | Deployment | ✅ Pass | vwx9012 |

### Final Review Results

| Reviewer | Verdict | Critical | High | Medium |
| --------- | -------- | -------- | ---- | ------ |
| Tech Lead | APPROVED | 0        | 1    | 3      |

### Files Changed

- 45 files added
- 12 files modified
- 0 files deleted

### Next Steps

1. Address 1 high-priority finding from review
2. Create PR with `/pr-create`
3. Request code review from team
```

## Error Handling

### Phase Failure

If a phase fails validation:

1. Report which phase failed and why
2. Ask user via AskUserQuestion:
   - **Fix and retry**: User fixes issues, then retry this phase
   - **Skip phase**: Mark as skipped, continue to next (risky)
   - **Abort**: Stop implementation, keep completed phases

### Abort Behavior

If user aborts:

1. Report completed phases and their commits
2. Report the failing phase
3. Do NOT revert completed phases
4. User can resume later with `/implement-phase --phase N`

## Safeguards

- **Pause between phases**: Add 2-second pause to allow user to interrupt
- **Progress tracking**: Update task list after each phase
- **Checkpoint commits**: Each phase has its own commit (easy to revert)
- **No force operations**: Never use `--force` flags
