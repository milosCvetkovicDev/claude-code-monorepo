---
allowed-tools: Bash, Read, LS, Task
---

# Epic Review

Run automated code review and quality checks on an epic branch before merging.

## Usage
```
/pm:epic-review <epic_name>
```

## Required Rules

**IMPORTANT:** Before executing this command, read and follow:
- `.claude/rules/datetime.md` - For getting real current date/time
- `.claude/references/workflow/test-first-development.md` - For quality expectations

## Preflight Checklist

Before proceeding, complete these validation steps.
Do not bother the user with preflight checks progress. Just do them and move on.

1. **Verify epic exists:**
   - Check if `.claude/epics/$ARGUMENTS/epic.md` exists
   - If not found: "❌ Epic not found: $ARGUMENTS"

2. **Verify branch exists:**
   ```bash
   git branch -a | grep "epic/$ARGUMENTS" || echo "❌ No branch for epic: $ARGUMENTS. Run: /pm:epic-start $ARGUMENTS"
   ```

3. **Check for uncommitted changes:**
   ```bash
   git stash list | head -5
   git status --porcelain | head -10
   ```
   If uncommitted changes exist: "⚠️ Uncommitted changes found. Commit before review."

## Instructions

### 1. Gather Changes

Get the full diff of the epic branch vs main:
```bash
# Ensure we have latest
git fetch origin

# Get change summary
echo "=== Files Changed ==="
git diff --stat main...epic/$ARGUMENTS

echo "=== Change Counts ==="
git diff --shortstat main...epic/$ARGUMENTS

# Get the full diff for analysis
git diff main...epic/$ARGUMENTS > /tmp/epic-$ARGUMENTS-diff.txt

# List changed files
git diff --name-only main...epic/$ARGUMENTS > /tmp/epic-$ARGUMENTS-files.txt
```

### 2. Run Linting & Type Checks

Detect project type and run appropriate checks:
```bash
# Switch to epic branch for checks
git checkout epic/$ARGUMENTS

# Node.js / TypeScript projects
if [ -f package.json ]; then
  # Nx monorepo
  if [ -f nx.json ]; then
    echo "=== Nx Lint (affected) ==="
    npx nx affected --target=lint --base=main 2>&1 || echo "LINT_FAILED"

    echo "=== TypeScript Type Check ==="
    npx nx affected --target=build --base=main 2>&1 || echo "TYPECHECK_FAILED"
  else
    # Standard Node.js
    echo "=== Lint ==="
    npm run lint 2>&1 || echo "LINT_FAILED"

    echo "=== TypeScript Type Check ==="
    npx tsc --noEmit 2>&1 || echo "TYPECHECK_FAILED"
  fi
fi

# Go projects
if [ -f go.mod ]; then
  echo "=== Go Vet ==="
  go vet ./... 2>&1 || echo "VET_FAILED"
fi

# Rust projects
if [ -f Cargo.toml ]; then
  echo "=== Clippy ==="
  cargo clippy 2>&1 || echo "CLIPPY_FAILED"
fi

# Return to previous branch
git checkout -
```

### 3. Quality Checks

Scan for common quality issues in changed files:
```bash
changed_files=$(git diff --name-only main...epic/$ARGUMENTS)

echo "=== Quality Scan ==="

# Check for debug statements left in code
echo "--- Debug Statements ---"
for f in $changed_files; do
  [ -f "$f" ] || continue
  grep -n "console\.log\|console\.debug\|debugger\|print(" "$f" 2>/dev/null | head -5
done

# Check for TODO/FIXME comments in new code
echo "--- TODO/FIXME ---"
git diff main...epic/$ARGUMENTS | grep "^+" | grep -i "TODO\|FIXME\|HACK\|XXX" | head -10

# Check for new source files without corresponding tests
echo "--- Missing Test Files ---"
for f in $changed_files; do
  # Skip test files, config files, docs
  echo "$f" | grep -qE "\.(spec|test)\.(ts|tsx|js|jsx)$" && continue
  echo "$f" | grep -qE "\.(md|json|yml|yaml|css|scss|html)$" && continue
  echo "$f" | grep -qE "^\.claude/" && continue

  # Check if it's a new source file
  if echo "$f" | grep -qE "\.(ts|tsx|js|jsx)$"; then
    # Look for corresponding test file
    base=$(echo "$f" | sed 's/\.\(ts\|tsx\|js\|jsx\)$//')
    test_exists=false
    for ext in spec.ts test.ts spec.tsx test.tsx spec.js test.js; do
      [ -f "${base}.${ext}" ] && test_exists=true
    done
    if [ "$test_exists" = false ]; then
      echo "  No test for: $f"
    fi
  fi
done

# Check for large functions (>50 lines) in changed files
echo "--- Large Functions ---"
for f in $changed_files; do
  [ -f "$f" ] || continue
  echo "$f" | grep -qE "\.(ts|tsx|js|jsx)$" || continue
  # Count function lengths (simplified heuristic)
  awk '/^[[:space:]]*(async )?(function|const .* = |export .* = ).*\{/{start=NR} /^\}/{if(start && NR-start>50) print FILENAME":"start" - function spans "NR-start" lines"; start=0}' "$f" 2>/dev/null
done
```

### 3b. Information-Isolated Review Layers

Run enhanced review pipeline per `/references/workflow/review-triage.md`:

#### Layer 1: Blind Adversarial Review (diff ONLY — no project context)
```yaml
Task:
  description: "Blind adversarial review: $ARGUMENTS"
  subagent_type: "adversarial-reviewer"
  prompt: |
    Review this code diff. You have NO project context.
    You MUST find at least 10 issues. Focus on what is MISSING.

    Diff:
    {contents of /tmp/epic-$ARGUMENTS-diff.txt}
```

#### Layer 2: Context-Aware Edge Case Analysis
```yaml
Task:
  description: "Edge case analysis: $ARGUMENTS"
  subagent_type: "edge-case-hunter"
  prompt: |
    Trace all branching paths in these changed files for epic/$ARGUMENTS:
    {contents of /tmp/epic-$ARGUMENTS-files.txt}

    Read full source files for context. Walk every if/else, switch, try/catch,
    loop, and async path. Report every missing guard as JSON.
```

Launch Layers 1 and 2 IN PARALLEL alongside the existing Layer 3 below.

### 4. Spawn Code Review Agent

Launch the `code-analyzer` agent to perform deep review:

```yaml
Task:
  description: "Code review for epic: $ARGUMENTS"
  subagent_type: "code-analyzer"
  prompt: |
    Review the code changes in epic branch: epic/$ARGUMENTS

    Changed files:
    {list from /tmp/epic-$ARGUMENTS-files.txt}

    Full diff is at: /tmp/epic-$ARGUMENTS-diff.txt

    Focus on:
    1. Logic errors and potential bugs
    2. Edge cases not handled
    3. Security vulnerabilities (injection, auth bypasses, data exposure)
    4. Performance issues (N+1 queries, missing indexes, unbounded loops)
    5. Error handling completeness
    6. Code consistency with existing patterns
    7. DRY violations (duplicated logic)
    8. Naming quality and readability

    Read the actual source files for context, not just the diff.

    Provide your findings in the standard Bug Hunt Summary format.
    Rate the overall quality: APPROVE / NEEDS FIXES / CRITICAL ISSUES
```

If a `code-reviewer` agent exists at `.claude/agents/code-reviewer.md`, also spawn it for a quality-focused review:

```yaml
Task:
  description: "Quality review for epic: $ARGUMENTS"
  subagent_type: "code-reviewer"
  prompt: |
    Review code quality for epic branch: epic/$ARGUMENTS

    Changed files:
    {list from /tmp/epic-$ARGUMENTS-files.txt}

    Focus on code quality improvements:
    1. Code style consistency with existing codebase
    2. Opportunities to simplify complex logic
    3. Import organization
    4. Dead code and unused variables
    5. Function complexity (suggest splitting large functions)
    6. Error message clarity
    7. Type safety improvements

    Provide actionable improvement suggestions.
    Rate: CLEAN / MINOR IMPROVEMENTS / SIGNIFICANT REFACTORING NEEDED
```

### 5. Triage and Generate Review Report

After all review layers complete (Layers 1, 2, and 3), triage findings per `/references/workflow/review-triage.md`:

1. **Normalize** all findings from all layers to common format: `| ID | Source | Severity | Location | Description |`
2. **Deduplicate** findings pointing to same file:line with same root issue. Combine sources.
3. **Classify** each into one bucket: `patch` (clear fix), `decision_needed` (ambiguous), `defer` (pre-existing), `dismiss` (noise)

Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

Create `.claude/epics/$ARGUMENTS/review-report.md`:

```markdown
---
reviewed: {current_datetime}
branch: epic/$ARGUMENTS
status: {pass|needs-fixes}
---

# Code Review Report: $ARGUMENTS

## Summary
- Files changed: {count}
- Lines added: {added} | Lines removed: {removed}
- Issues found: {critical_count} critical, {warning_count} warnings

## Critical Issues (must fix before merge)
{List from code-analyzer findings — only high-confidence bugs}

## Warnings (should fix)
{List from code-analyzer + code-reviewer findings}

## Quality Checks
- [ ] Lint: {pass/fail}
- [ ] TypeScript: {pass/fail}
- [ ] No debug statements: {pass/fail with count}
- [ ] Test coverage for new files: {pass/fail with missing list}
- [ ] No TODO/FIXME in new code: {pass/fail with count}

## Code Analyzer Findings
{Summary of code-analyzer agent output}

## Code Quality Assessment
{Summary of code-reviewer agent output, if available}

## Recommendation
{APPROVE — safe to merge | NEEDS FIXES — list specific action items}
```

Set `status: pass` if no critical issues. Set `status: needs-fixes` if any critical issues found.

### 6. Output

If review passed:
```
✅ Code review passed for epic: $ARGUMENTS

Summary:
  Files reviewed: {count}
  Critical issues: 0
  Warnings: {count}

Quality checks:
  ✓ Lint passed
  ✓ TypeScript passed
  ✓ No debug statements
  ⚠️ {warnings if any}

Report: .claude/epics/$ARGUMENTS/review-report.md

Next: Merge via PR: /pm:epic-merge $ARGUMENTS
```

If review needs fixes:
```
❌ Code review found issues for epic: $ARGUMENTS

Critical issues ({count}):
  - {issue 1}: {file}:{line}
  - {issue 2}: {file}:{line}

Warnings ({count}):
  - {warning 1}

Report: .claude/epics/$ARGUMENTS/review-report.md

Fix issues and re-run: /pm:epic-review $ARGUMENTS
```

## Error Handling

If any check fails to run:
- Report which check failed
- Continue with remaining checks
- Note failures in review report
- "⚠️ {check} could not run: {reason}. Manual review recommended."

## Important Notes

- Review is automated — human review is still recommended for complex changes
- The review report is used by `/pm:epic-merge` as a quality gate
- Re-run the review after fixing issues to update the report
- Follow `/rules/datetime.md` for timestamps

## Agent Skill Integration

Use these agent-skills during epic review (not superpowers equivalents):
- `agent-skills:code-review-and-quality` — for the five-axis review process
- `agent-skills:security-and-hardening` — for OWASP and security checks
- `agent-skills:performance-optimization` — for performance review (measure first, optimize what matters)
