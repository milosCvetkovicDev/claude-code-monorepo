---
allowed-tools: Bash, Read, Write, LS
---

# Milestone Init

Initialize a multi-milestone program with milestone tracking, master architecture, and migration state support.

## Usage
```
/pm:milestone-init <program-name>
```

## Required Rules

**IMPORTANT:** Before executing this command, read and follow:
- `.claude/rules/datetime.md` - For timestamps
- `.claude/references/workflow/milestone-operations.md` - For milestone conventions

## Preflight Checklist

Do not bother the user with preflight checks progress. Just do them and move on.

1. **Verify program name:**
   - Must be kebab-case (lowercase, hyphens only)
   - If invalid: "❌ Program name must be kebab-case. Example: platform-migration"

2. **Check for existing program:**
   - If `.claude/milestones/$ARGUMENTS/` exists:
   - Ask: "⚠️ Program '$ARGUMENTS' already exists. Overwrite? (yes/no)"

3. **Check for strategy docs:**
   - Search for `docs/strategy/*.md`
   - If found: "Found strategy documents — can extract milestones from them"

## Instructions

### 1. Gather Program Information (Interactive)

Ask the user:
1. **Description**: one-line summary
2. **Timeline**: target start and end dates
3. **Milestone count**: how many (suggest ~1 per quarter)

### 2. Check for Strategy Documents

If `docs/strategy/technology-strategy.md` or similar exists:
- Read and extract quarterly goals
- Offer: "Found strategy with {n} quarters. Auto-generate milestones? (yes/no)"
- If yes: map quarters to milestones with scope, KPIs, initiatives

### 3. Define Milestones

For each milestone:
- **Name**: kebab-case (m1-foundation, m2-nestjs-phase1)
- **Scope**: what it delivers (2-3 sentences)
- **Target dates**: start and end
- **Dependencies**: which prior milestones must complete first
- **KPIs**: measurable success criteria

### 4. Create Directory Structure

Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

```bash
mkdir -p .claude/milestones/$ARGUMENTS/milestones
```

Create per-milestone directories.

### 5. Create program.md

```yaml
---
name: $ARGUMENTS
description: [from step 1]
status: active
started: [datetime]
target_completion: [from step 1]
milestones_total: [count]
milestones_completed: 0
---
```

Body: Overview, Timeline table, Dependency Graph, Epics by Milestone (empty), Success Criteria, Risk Register.

### 6. Create milestone.md Files

For each milestone:
```yaml
---
name: <name>
program: $ARGUMENTS
status: backlog
depends_on: []
target_start: <date>
target_end: <date>
epics: []
completed_epics: 0
total_epics: 0
---
```

Body: Scope, Epics table (empty), KPIs, Dependencies, Notes.

### 7. Create master-architecture.md Stub

```yaml
---
name: $ARGUMENTS-master-architecture
status: stub
created: [datetime]
updated: [datetime]
program: $ARGUMENTS
---
```

Body: "Populated when first /pm:arch-create runs."

### 8. Create project-context.md Stub

```yaml
---
generated: [datetime]
updated: [datetime]
program: $ARGUMENTS
migration_tracked: true
---
```

Body: Migration State table stub.

## Post-Creation

```
✅ Program initialized: $ARGUMENTS

📁 .claude/milestones/$ARGUMENTS/
  program.md — {count} milestones
  master-architecture.md — stub
  project-context.md — stub

Milestones:
  M1: {name} ({dates})
  M2: {name} ({dates}) — depends on M1
  ...

Next:
  1. /pm:prd-new <first-epic>
  2. /pm:project-context
```

## Error Recovery

- If strategy doc parsing fails: manual milestone entry
- If directory creation fails: check permissions
- Never leave partial state

## Important Notes

- Only needed for multi-milestone programs (6+ months)
- For single features, use standard CCPM flow
- Master architecture is a STUB until first `/pm:arch-create`
- Follow `/references/workflow/milestone-operations.md` for conventions
- Follow `/rules/datetime.md` for timestamps
