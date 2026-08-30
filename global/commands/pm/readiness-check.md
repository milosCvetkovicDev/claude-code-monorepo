---
allowed-tools: Bash, Read, Write, LS
---

# Readiness Check

Validate that an epic is ready for implementation by checking requirements coverage, architecture cohesion, and cross-epic dependencies.

## Usage
```
/pm:readiness-check <feature_name>
```

## Required Rules

**IMPORTANT:** Before executing this command, read and follow:
- `.claude/references/workflow/readiness-gate.md` - For validation rules and severity tiers
- `.claude/rules/datetime.md` - For timestamps

## Preflight Checklist

Do not bother the user with preflight checks progress. Just do them and move on.

1. **Verify feature_name provided:**
   - If not: "❌ Feature name required. Run: /pm:readiness-check <feature_name>"

2. **Verify PRD exists:**
   - Check `.claude/prds/$ARGUMENTS.md`
   - If not: "❌ PRD not found: $ARGUMENTS"

3. **Verify epic and tasks exist:**
   - Check `.claude/epics/$ARGUMENTS/epic.md`
   - Check for task files: `.claude/epics/$ARGUMENTS/[0-9]*.md`
   - If no tasks: "❌ No tasks found. Run: /pm:epic-decompose $ARGUMENTS first"

4. **Check for architecture (note, don't block):**
   - If `.claude/epics/$ARGUMENTS/architecture.md` exists: include in validation
   - If not: "ℹ️ No architecture document — cohesion check skipped"

## Instructions

### 1. Read All Artifacts

Load completely (no summarizing):
- PRD from `.claude/prds/$ARGUMENTS.md`
- Epic from `.claude/epics/$ARGUMENTS/epic.md`
- Architecture from `.claude/epics/$ARGUMENTS/architecture.md` (if exists)
- ALL task files from `.claude/epics/$ARGUMENTS/[0-9]*.md`
- Test manifest from `.claude/epics/$ARGUMENTS/test-manifest.md` (if exists)

### 2. Build FR Coverage Matrix

Extract every FR from PRD "Functional Requirements" section. If absent, use "Acceptance Criteria (Gherkin)" scenarios. If neither, use "User Stories".

For each FR/scenario, scan ALL task files for coverage. Build:
```markdown
| FR ID | PRD Requirement | Task Coverage | Status |
```
Calculate: `coverage = (Full + Partial) / Total * 100`

### 3. Run Validation Checks

Per `/references/workflow/readiness-gate.md`:

**Check 1 — User-facing value:** Scan task names and descriptions. Flag internal-only setup tasks.

**Check 2 — Forward dependencies:** Verify `depends_on` references point to tasks within this epic or completed epics.

**Check 3 — BDD acceptance criteria:** Verify Given/When/Then ACs or PRD Gherkin references.

**Check 4 — Architecture cohesion:** If architecture.md exists, verify Dev Notes reference decisions.

**Check 5 — Cross-epic dependencies:** If `.claude/milestones/*/program.md` exists, check milestone dependency graph.

### 4. Classify Findings

Assign severity per `/references/workflow/readiness-gate.md`:
- CRITICAL: Missing FR, forward deps, zero ACs, architecture contradictions
- MAJOR: Single-coverage FR, no arch reference, XL tasks, in-progress prerequisite
- MINOR: Missing estimates, naming issues

### 5. Determine Verdict

- READY: 0 CRITICAL, ≤2 MAJOR
- NEEDS WORK: 0 CRITICAL, 3+ MAJOR
- NOT READY: 1+ CRITICAL

### 6. Create Readiness Report

Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

Create `.claude/epics/$ARGUMENTS/readiness-report.md` with frontmatter and body per `/references/workflow/readiness-gate.md`.

### 7. Present Results

If READY:
```
✅ Readiness: READY
FR Coverage: {n}% ({covered}/{total})
Findings: 0 critical, {n} major, {n} minor
Next: /pm:epic-sync $ARGUMENTS
```

If NEEDS WORK:
```
⚠️ Readiness: NEEDS WORK
FR Coverage: {n}%
Major findings:
  - {finding}
Fix or proceed: /pm:epic-sync $ARGUMENTS
```

If NOT READY:
```
❌ Readiness: NOT READY
Critical findings:
  - {finding}
Fix critical findings. Type "override" to proceed anyway.
```

## Error Recovery

- If PRD has no FR section: fall back to Gherkin scenario coverage
- If no tasks exist: stop with clear message
- If architecture check fails: skip, note in report

## Important Notes

- Required for Complex/Program flows. Optional for Standard. Skip for Quick.
- Follow `/references/workflow/readiness-gate.md` for all rules
- Follow `/rules/datetime.md` for timestamps
