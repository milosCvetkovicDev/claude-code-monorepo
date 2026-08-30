# Milestone Operations

Rules for managing multi-milestone programs spanning months with multiple epics per milestone.

## When to Use

Use milestones when: 6+ months of work, multiple phases, cross-phase dependencies, technology strategy driving the work, or migration projects.

## Directory Structure

```
.claude/milestones/<program>/
  program.md                    # Master plan
  master-architecture.md        # Shared architecture decisions
  project-context.md            # Migration state tracking
  milestones/
    m1-<name>/milestone.md
    m2-<name>/milestone.md
    ...
```

## program.md

```yaml
---
name: <program>
description: <one-line>
status: active | paused | completed
started: <ISO datetime>
target_completion: <ISO datetime>
milestones_total: 6
milestones_completed: 0
---
```

Body: Overview, Timeline table, Dependency Graph, Epics by Milestone, Success Criteria, Risk Register.

## milestone.md

```yaml
---
name: m1-<name>
program: <program>
status: backlog | in-progress | completed
depends_on: []
target_start: <date>
target_end: <date>
epics: []
completed_epics: 0
total_epics: 0
---
```

Body: Scope, Epics table, KPIs, Dependencies, Notes.

## Master Architecture

At `.claude/milestones/<program>/master-architecture.md`. Same format as per-epic architecture but project-wide scope.

### Key Differences
- Captures decisions spanning ALL epics
- Per-epic architecture inherits shared decisions
- Updated when decisions evolve via ADR superseding
- Created during first `arch-create` of the program

### Evolution
- New patterns added as project progresses
- Decisions superseded via new ADR + master update
- Tracks both old and new when modules use different decisions

## Migration State Tracking

For migration projects, track in `project-context.md`:

```markdown
## Migration State
| Domain | Current Stack | Target Stack | Status | Milestone |
|--------|--------------|-------------|--------|-----------|
| Countries | NestJS + Drizzle | — | migrated | M2 |
| Customers | Express + TypeORM | NestJS + Prisma | in-progress | M3 |
| Sales | Express + TypeORM | NestJS + Prisma | planned | M3 |
```

Agents use this to: follow correct patterns per module, know which services are on new vs old stack, avoid importing from old-stack modules when new equivalents exist.

## Cross-Milestone Dependencies

### During Readiness Check
1. Read `program.md` dependency graph
2. Find prerequisite milestones
3. Check prerequisite status:
   - `completed` → OK
   - `in-progress` → MAJOR warning
   - `backlog` → CRITICAL (block sync)

## Updating Progress

After each `/pm:epic-close`:
1. Update epic status in `milestone.md`
2. Recalculate: `completed_epics / total_epics * 100`
3. If all epics complete → milestone status = `completed`
4. Update `program.md` epics section
5. Check if dependent milestones are unblocked

## Best Practices

1. One milestone per quarter — aligns with business cadence
2. 3-5 epics per milestone — manageable scope
3. Master architecture early — create during first milestone
4. Update migration state — run `/pm:project-context` after each epic-close
5. KPIs per milestone — copy from technology strategy
6. Risk register — update as risks materialize
