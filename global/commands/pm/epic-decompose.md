---
allowed-tools: Bash, Read, Write, LS, Task
---

# Epic Decompose

Break epic into concrete, actionable tasks.

## Usage
```
/pm:epic-decompose <feature_name>
```

## Required Rules

**IMPORTANT:** Before executing this command, read and follow:
- `.claude/rules/datetime.md` - For getting real current date/time

## Preflight Checklist

Before proceeding, complete these validation steps.
Do not bother the user with preflight checks progress ("I'm not going to ..."). Just do them and move on.

1. **Verify epic exists:**
   - Check if `.claude/epics/$ARGUMENTS/epic.md` exists
   - If not found, tell user: "❌ Epic not found: $ARGUMENTS. First create it with: /pm:prd-parse $ARGUMENTS"
   - Stop execution if epic doesn't exist

2. **Check for existing tasks:**
   - Check if any numbered task files (001.md, 002.md, etc.) already exist in `.claude/epics/$ARGUMENTS/`
   - If tasks exist, list them and ask: "⚠️ Found {count} existing tasks. Delete and recreate all tasks? (yes/no)"
   - Only proceed with explicit 'yes' confirmation
   - If user says no, suggest: "View existing tasks with: /pm:epic-show $ARGUMENTS"

3. **Validate epic frontmatter:**
   - Verify epic has valid frontmatter with: name, status, created, prd
   - If invalid, tell user: "❌ Invalid epic frontmatter. Please check: .claude/epics/$ARGUMENTS/epic.md"

4. **Check epic status:**
   - If epic status is already "completed", warn user: "⚠️ Epic is marked as completed. Are you sure you want to decompose it again?"

## Instructions

You are decomposing an epic into specific, actionable tasks for: **$ARGUMENTS**

### 1. Read the Epic
- Load the epic from `.claude/epics/$ARGUMENTS/epic.md`
- Understand the technical approach and requirements
- Review the task breakdown preview

### 2. Analyze for Parallel Creation

Determine if tasks can be created in parallel:
- If tasks are mostly independent: Create in parallel using Task agents
- If tasks have complex dependencies: Create sequentially
- For best results: Group independent tasks for parallel creation

### 3. Parallel Task Creation (When Possible)

If tasks can be created in parallel, spawn sub-agents:

```yaml
Task:
  description: "Create task files batch {X}"
  subagent_type: "general-purpose"
  prompt: |
    Create task files for epic: $ARGUMENTS

    Tasks to create:
    - {list of 3-4 tasks for this batch}

    For each task:
    1. Create file: .claude/epics/$ARGUMENTS/{number}.md
    2. Use exact format with frontmatter and all sections
    3. Follow task breakdown from epic
    4. Set parallel/depends_on fields appropriately
    5. Number sequentially (001.md, 002.md, etc.)

    Return: List of files created
```

### 4. Task File Format with Frontmatter
For each task, create a file with this exact structure:

```markdown
---
name: [Task Title]
status: open
created: [Current ISO date/time]
updated: [Current ISO date/time]
github: [Will be updated when synced to GitHub]
depends_on: []  # List of task numbers this depends on, e.g., [001, 002]
parallel: true  # Can this run in parallel with other tasks?
conflicts_with: []  # Tasks that modify same files, e.g., [003, 004]
---

# Task: [Task Title]

## Description
Clear, concise description of what needs to be done

## Acceptance Criteria
- [ ] Specific criterion 1 (AC: 1)
- [ ] Specific criterion 2 (AC: 2)
- [ ] Specific criterion 3 (AC: 3)

## Technical Details
- Implementation approach
- Key considerations
- Code locations/files affected

## Dependencies
- [ ] Task/Issue dependencies
- [ ] External dependencies

## Effort Estimate
- Size: XS/S/M/L/XL
- Hours: estimated hours
- Parallel: true/false (can run in parallel with other tasks)

## Definition of Done
- [ ] Acceptance tests written (Gherkin scenarios)
- [ ] Unit tests written and failing (red phase) — then passing after implementation
- [ ] Integration tests written and passing
- [ ] E2E tests pass (if UI changes involved)
- [ ] Code implemented and makes all tests pass (green phase)
- [ ] Code refactored for quality (refactor phase — DRY, naming, simplification)
- [ ] Self-reviewed for bugs, edge cases, and conventions
- [ ] Automated code review passed (/pm:epic-review)
- [ ] PR created and CI checks pass
- [ ] Production verification steps documented
- [ ] Deployed and verified in production (see /pm:prod-verify)
- [ ] Architecture decisions referenced in Dev Notes (if architecture.md exists)
- [ ] Dev Agent Record completed (model, files, completion notes)

## Dev Notes
### Architecture Patterns
- [Auto-populated from architecture.md if it exists, e.g., "architecture.md §3.1: Use NestJS modules with feature-based organization"]
- [If no architecture.md: "N/A — no architecture document for this epic"]

### Project Structure
- [File locations from architecture.md §4 if available]
- [Otherwise: derive from epic Technical Approach section]

### References
- [architecture.md §X.Y — specific decisions relevant to this task]
- [master-architecture.md §X.Y — inherited decisions if multi-milestone]
- [Task #<prev> Dev Notes — patterns established by previous task, if applicable]

## Dev Agent Record
- Agent Model Used: [to be filled by implementing agent]
- Completion Notes: [to be updated per subtask completion]
- File List: [to be updated — all files created/modified/deleted]

## File Modification Rules
Implementing agents may ONLY modify these sections: Task/Subtask checkboxes, Dev Agent Record, File List, Status.
Do NOT modify: Description, Acceptance Criteria, Dev Notes, Dependencies, Definition of Done.
```

### 3b. Populate Architecture References

If `.claude/epics/$ARGUMENTS/architecture.md` exists:
1. Read the architecture document
2. For each task, identify which decisions from §2 (Decision Matrix) apply
3. Identify which patterns from §3 (Implementation Patterns) the task should follow
4. Populate each task's "Dev Notes > Architecture Patterns" with specific references
5. Populate "Dev Notes > Project Structure" with file locations from §4

If `.claude/milestones/*/master-architecture.md` also exists:
- Include inherited decisions with notation: `master-architecture.md §X.Y`

If no architecture document exists, set Dev Notes to: "N/A — no architecture document for this epic"

### 3c. AC Cross-References

Every subtask checkbox must include acceptance criteria cross-references:
```markdown
- [ ] Create LoginForm component with validation (AC: 1, 3)
- [ ] Implement /api/auth/login endpoint (AC: 1, 2)
- [ ] Add JWT token generation and storage (AC: 3)
```

Where the numbers reference the Acceptance Criteria items in the same task.

### 3. Task Naming Convention
Save tasks as: `.claude/epics/$ARGUMENTS/{task_number}.md`
- Use sequential numbering: 001.md, 002.md, etc.
- Keep task titles short but descriptive

### 4. Frontmatter Guidelines
- **name**: Use a descriptive task title (without "Task:" prefix)
- **status**: Always start with "open" for new tasks
- **created**: Get REAL current datetime by running: `date -u +"%Y-%m-%dT%H:%M:%SZ"`
- **updated**: Use the same real datetime as created for new tasks
- **github**: Leave placeholder text - will be updated during sync
- **depends_on**: List task numbers that must complete before this can start (e.g., [001, 002])
- **parallel**: Set to true if this can run alongside other tasks without conflicts
- **conflicts_with**: List task numbers that modify the same files (helps coordination)

### 5. Task Types and Test-First Ordering

**CRITICAL: Test tasks must be created FIRST with the lowest sequence numbers.**

Follow `/references/workflow/test-first-development.md`:
1. **Testing tasks** (001.md, 002.md) — Write failing tests from Gherkin acceptance criteria. `depends_on: []`, `parallel: true`
2. **Setup tasks** — Environment, dependencies, scaffolding
3. **Data tasks** — Models, schemas, migrations. `depends_on: [test-task-numbers]`
4. **API tasks** — Endpoints, services, integration. `depends_on: [test-task-numbers]`
5. **UI tasks** — Components, pages, styling. `depends_on: [test-task-numbers]`
6. **Documentation tasks** — README, API docs
7. **Production Verification task** (ALWAYS the last task) — Verify in production. `depends_on: [all-other-tasks]`

**Mandatory quality check**: At least ONE testing task must exist. The production verification task must ALWAYS be the last task.

### 6. Parallelization
Mark tasks with `parallel: true` if they can be worked on simultaneously without conflicts.

### 7. Execution Strategy

Choose based on task count and complexity:

**Small Epic (< 5 tasks)**: Create sequentially for simplicity

**Medium Epic (5-10 tasks)**:
- Batch into 2-3 groups
- Spawn agents for each batch
- Consolidate results

**Large Epic (> 10 tasks)**:
- Analyze dependencies first
- Group independent tasks
- Launch parallel agents (max 5 concurrent)
- Create dependent tasks after prerequisites

Example for parallel execution:
```markdown
Spawning 3 agents for parallel task creation:
- Agent 1: Creating tasks 001-003 (Database layer)
- Agent 2: Creating tasks 004-006 (API layer)
- Agent 3: Creating tasks 007-009 (UI layer)
```

### 8. Task Dependency Validation

When creating tasks with dependencies:
- Ensure referenced dependencies exist (e.g., if Task 003 depends on Task 002, verify 002 was created)
- Check for circular dependencies (Task A → Task B → Task A)
- If dependency issues found, warn but continue: "⚠️ Task dependency warning: {details}"

### 9. Update Epic with Task Summary
After creating all tasks, update the epic file by adding this section:
```markdown
## Tasks Created
- [ ] 001.md - {Task Title} (parallel: true/false)
- [ ] 002.md - {Task Title} (parallel: true/false)
- etc.

Total tasks: {count}
Parallel tasks: {parallel_count}
Sequential tasks: {sequential_count}
Estimated total effort: {sum of hours}
```

Also update the epic's frontmatter progress if needed (still 0% until tasks actually start).

### 9. Quality Validation

Before finalizing tasks, verify:
- [ ] All tasks have clear acceptance criteria
- [ ] Task sizes are reasonable (1-3 days each)
- [ ] Dependencies are logical and achievable
- [ ] Parallel tasks don't conflict with each other
- [ ] Combined tasks cover all epic requirements

### 10. Post-Decomposition

After successfully creating tasks:
1. Confirm: "✅ Created {count} tasks for epic: $ARGUMENTS"
2. Show summary:
   - Total tasks created
   - Parallel vs sequential breakdown
   - Total estimated effort
3. Suggest next step: "Ready to sync to GitHub? Run: /pm:epic-sync $ARGUMENTS"
4. Suggest scale routing based on task count and domain analysis:
   ```
   Based on {count} tasks across {domain_count} domain(s):
   Recommended workflow: {Quick|Standard|Complex|Program}
     Quick (1-3 tasks): /pm:tests-generate → /pm:epic-sync (skip arch + readiness)
     Standard (4-7): current workflow
     Complex (8+): /pm:arch-create first → then continue
   ```
   See `/references/workflow/scale-routing.md` for routing criteria.

## Error Recovery

If any step fails:
- If task creation partially completes, list which tasks were created
- Provide option to clean up partial tasks
- Never leave the epic in an inconsistent state

Aim for tasks that can be completed in 1-3 days each. Break down larger tasks into smaller, manageable pieces for the "$ARGUMENTS" epic.
