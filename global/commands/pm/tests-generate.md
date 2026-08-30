---
allowed-tools: Bash, Read, Write, LS, Task
---

# Tests Generate

Generate failing test suites from PRD acceptance criteria (Red phase of TDD).

## Usage
```
/pm:tests-generate <epic_name>
```

## Required Rules

**IMPORTANT:** Before executing this command, read and follow:
- `.claude/references/workflow/test-first-development.md` - For test-first conventions
- `.claude/rules/datetime.md` - For timestamps

## Preflight Checklist

1. **Verify PRD exists:**
   ```bash
   test -f .claude/prds/$ARGUMENTS.md || echo "❌ PRD not found. Run: /pm:prd-new $ARGUMENTS"
   ```

2. **Verify epic exists:**
   ```bash
   test -d .claude/epics/$ARGUMENTS/ || echo "❌ Epic not found. Run: /pm:prd-parse $ARGUMENTS"
   ```

3. **Check for existing test manifest:**
   ```bash
   if [ -f .claude/epics/$ARGUMENTS/test-manifest.md ]; then
     echo "⚠️ Test manifest already exists for '$ARGUMENTS'. Overwrite? (yes/no)"
   fi
   ```

## Instructions

### 1. Read Requirements

Read the PRD from `.claude/prds/$ARGUMENTS.md`:
- Extract all Gherkin scenarios from the "Acceptance Criteria (Gherkin)" section
- Extract testing requirements from the "Testing Requirements" section
- Extract production verification steps from the "Production Verification" section

Read the epic from `.claude/epics/$ARGUMENTS/epic.md`:
- Identify target apps from "Technical Approach" section
- Identify affected file patterns from task files

### 2. Detect Target Frameworks

Based on the epic's target apps, determine which test frameworks to use:

| Target App | Unit Tests | Integration Tests | E2E Tests |
|------------|-----------|-------------------|-----------|
| legacy-api | Jest (`test/services/`) | Jest + supertest (`test/integration/`) | — |
| legacy-web | Jest + @testing-library (`src/**/*.spec.tsx`) | — | Playwright (`apps/legacy-web-e2e/`) |
| domain-api | Bun test (`test/unit/`) | Bun test + Elysia (`test/integration/`) | — |
| domain-web | — | — | Playwright (`apps/domain-web-e2e/`) |

Read existing test files in the target app to understand current patterns:
```bash
# Find existing tests to study patterns
ls apps/{target-app}/test/**/*.spec.ts 2>/dev/null || ls apps/{target-app}/test/**/*.test.ts 2>/dev/null
```

### 3. Generate Tests Using Agent

Use the Task tool to spawn the `acceptance-test-writer` agent:

```yaml
Task:
  description: "Generate failing tests for $ARGUMENTS"
  subagent_type: "acceptance-test-writer"
  prompt: |
    Generate a complete failing test suite for epic: $ARGUMENTS

    PRD location: .claude/prds/$ARGUMENTS.md
    Epic location: .claude/epics/$ARGUMENTS/epic.md

    Requirements:
    1. Read the PRD and extract ALL Gherkin scenarios
    2. Read existing test files to match conventions exactly
    3. Generate ALL test layers:
       - .feature files (Gherkin acceptance tests)
       - E2E specs (Playwright with POM)
       - Integration tests (Jest/Bun matching app framework)
       - Unit test stubs (Jest/Bun matching app framework)
    4. ALL tests must FAIL (red phase)
    5. Create test manifest at .claude/epics/$ARGUMENTS/test-manifest.md

    Return: List of all generated files and their test counts
```

### 4. Verify Generation

After the agent completes:

```bash
# Count generated test files
echo "Generated test files:"
find . -name "*.spec.ts" -newer .claude/epics/$ARGUMENTS/epic.md 2>/dev/null | wc -l
find . -name "*.test.ts" -newer .claude/epics/$ARGUMENTS/epic.md 2>/dev/null | wc -l
find . -name "*.feature" 2>/dev/null | wc -l
```

### 5. Post-Generation Output

```
✅ Test suite generated for: $ARGUMENTS

📋 Test Manifest: .claude/epics/$ARGUMENTS/test-manifest.md

Generated:
  - {n} Gherkin scenarios (.feature files)
  - {n} E2E test stubs (Playwright)
  - {n} Integration test stubs
  - {n} Unit test stubs

All tests are intentionally FAILING (red phase).
Implementation will make them pass (green phase).

Next steps:
  1. Review generated tests: cat .claude/epics/$ARGUMENTS/test-manifest.md
  2. Sync to GitHub: /pm:epic-sync $ARGUMENTS
  3. Start implementation: /pm:epic-start $ARGUMENTS
```

## Error Handling

If no Gherkin scenarios found in PRD:
```
❌ No Gherkin acceptance criteria found in PRD.
The PRD must include a "## Acceptance Criteria (Gherkin)" section.
Fix: /pm:prd-edit $ARGUMENTS (add Gherkin scenarios)
```

If target app cannot be determined:
```
❌ Cannot determine target app from epic.
The epic must specify target apps in "Technical Approach" section.
Fix: /pm:epic-edit $ARGUMENTS
```

## Agent Skill Integration

Use `agent-skills:test-driven-development` for the red/green/refactor cycle. This replaces `superpowers:test-driven-development`.
