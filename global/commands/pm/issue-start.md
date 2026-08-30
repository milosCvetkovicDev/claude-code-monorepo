---
allowed-tools: Bash, Read, Write, LS, Task
---

# Issue Start

Begin work on a GitHub issue with parallel agents based on work stream analysis.

## Usage
```
/pm:issue-start <issue_number>
```

## Quick Check

1. **Get issue details:**
   ```bash
   gh issue view $ARGUMENTS --json state,title,labels,body
   ```
   If it fails: "❌ Cannot access issue #$ARGUMENTS. Check number or run: gh auth login"

2. **Find local task file:**
   - First check if `.claude/epics/*/$ARGUMENTS.md` exists (new naming)
   - If not found, search for file containing `github:.*issues/$ARGUMENTS` in frontmatter (old naming)
   - If not found: "❌ No local task for issue #$ARGUMENTS. This issue may have been created outside the PM system."

3. **Check for analysis:**
   ```bash
   test -f .claude/epics/*/$ARGUMENTS-analysis.md || echo "❌ No analysis found for issue #$ARGUMENTS
   
   Run: /pm:issue-analyze $ARGUMENTS first
   Or: /pm:issue-start $ARGUMENTS --analyze to do both"
   ```
   If no analysis exists and no --analyze flag, stop execution.

## Instructions

### 1. Ensure Worktree Exists

Check if epic worktree exists:
```bash
# Find epic name from task file
epic_name={extracted_from_path}

# Check worktree
if ! git worktree list | grep -q "epic-$epic_name"; then
  echo "❌ No worktree for epic. Run: /pm:epic-start $epic_name"
  exit 1
fi
```

### 2. Read Analysis

Read `.claude/epics/{epic_name}/$ARGUMENTS-analysis.md`:
- Parse parallel streams
- Identify which can start immediately
- Note dependencies between streams

### 2b. Load Previous Issue Intelligence

Find the most recently completed issue in this epic:
```bash
prev_issue=""
prev_updated=""
for tf in .claude/epics/{epic_name}/[0-9]*.md; do
  [ -f "$tf" ] || continue
  s=$(head -10 "$tf" | grep '^status:' | sed 's/^status: *//')
  if [ "$s" = "closed" ]; then
    u=$(head -10 "$tf" | grep '^updated:' | sed 's/^updated: *//')
    if [ "$u" \> "$prev_updated" ]; then
      prev_updated="$u"
      prev_issue="$tf"
    fi
  fi
done
```

If a completed issue exists:
- Read its "Dev Agent Record" section (files modified, completion notes)
- Read review feedback from `.claude/epics/{epic_name}/review-report.md` (if exists)
- Include as context block in agent prompts:

```markdown
## Previous Issue Intelligence
### Last Completed: #{prev_number} - {title}
**Files Modified**: {from Dev Agent Record > File List}
**Completion Notes**: {from Dev Agent Record > Completion Notes}
**Review Feedback**: {relevant findings from review-report.md}
**Patterns Established**: {conventions from Dev Notes that should carry forward}
```

If no completed issues exist (first issue in epic), skip this section.

### 3. Setup Progress Tracking

Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

Create workspace structure:
```bash
mkdir -p .claude/epics/{epic_name}/updates/$ARGUMENTS
```

Update task file frontmatter `updated` field with current datetime.

### 4. Launch Parallel Agents

For each stream that can start immediately:

Create `.claude/epics/{epic_name}/updates/$ARGUMENTS/stream-{X}.md`:
```markdown
---
issue: $ARGUMENTS
stream: {stream_name}
agent: {agent_type}
started: {current_datetime}
status: in_progress
---

# Stream {X}: {stream_name}

## Scope
{stream_description}

## Files
{file_patterns}

## Progress
- Starting implementation
```

Launch agent using Task tool:
```yaml
Task:
  description: "Issue #$ARGUMENTS Stream {X}"
  subagent_type: "{agent_type}"
  prompt: |
    You are working on Issue #$ARGUMENTS in the epic worktree.
    
    Worktree location: ../epic-{epic_name}/
    Your stream: {stream_name}
    
    Your scope:
    - Files to modify: {file_patterns}
    - Work to complete: {stream_description}
    
    Requirements:
    1. Read full task from: .claude/epics/{epic_name}/{task_file}
    2. Work ONLY in your assigned files
    3. Commit frequently with format: "Issue #$ARGUMENTS: {specific change}"
    4. Update progress in: .claude/epics/{epic_name}/updates/$ARGUMENTS/stream-{X}.md
    5. Follow coordination rules in /references/workflow/agent-coordination.md

    ## Test-First Requirements (MANDATORY)
    Follow /references/workflow/test-first-development.md:
    1. Read acceptance criteria from the task file
    2. Check if tests already exist (from /pm:tests-generate)
    3. If no tests exist, write FAILING tests FIRST (red phase)
    4. Implement code to make tests pass (green phase)
    5. Run tests before every commit — only commit when tests pass
    6. Check test manifest at .claude/epics/{epic_name}/test-manifest.md
    7. REFACTOR: Once tests are green, improve code quality:
       - Remove duplication (DRY)
       - Improve naming and readability
       - Simplify complex logic
       - Ensure consistent patterns with existing codebase
       - Run tests again after refactoring — must stay green
    8. Self-review: Check your own changes for bugs, edge cases,
       and adherence to project conventions before marking done

    ## Context Loading (MANDATORY)
    Before starting any work:
    1. If `.claude/project-context.md` exists, read it for project conventions
    2. If `.claude/milestones/*/master-architecture.md` exists, read relevant sections
    3. If `.claude/epics/{epic_name}/architecture.md` exists, read it for patterns
    4. Previous Issue Intelligence (if loaded above) — follow established patterns

    ## File Modification Boundaries
    When modifying the task file, ONLY change:
    - Task/Subtask checkboxes (mark [x] when done)
    - Dev Agent Record section (model, notes, file list)
    - Status field in frontmatter
    Do NOT modify: Description, Acceptance Criteria, Dev Notes, Dependencies

    If you need to modify files outside your scope:
    - Check if another stream owns them
    - Wait if necessary
    - Update your progress file with coordination notes

    Complete your stream's work and mark as completed when done.
```

### 5. GitHub Assignment

```bash
# Assign to self and mark in-progress
gh issue edit $ARGUMENTS --add-assignee @me --add-label "in-progress"
```

### 6. Output

```
✅ Started parallel work on issue #$ARGUMENTS

Epic: {epic_name}
Worktree: ../epic-{epic_name}/

Launching {count} parallel agents:
  Stream A: {name} (Agent-1) ✓ Started
  Stream B: {name} (Agent-2) ✓ Started
  Stream C: {name} - Waiting (depends on A)

Progress tracking:
  .claude/epics/{epic_name}/updates/$ARGUMENTS/

Monitor with: /pm:epic-status {epic_name}
Sync updates: /pm:issue-sync $ARGUMENTS
```

## Error Handling

If any step fails, report clearly:
- "❌ {What failed}: {How to fix}"
- Continue with what's possible
- Never leave partial state

## Important Notes

Follow `/rules/datetime.md` for timestamps.
Keep it simple - trust that GitHub and file system work.

## Agent Skill Integration

When implementing work within this issue, use these agent-skills (not superpowers equivalents):
- `agent-skills:incremental-implementation` — for building in thin vertical slices
- `agent-skills:test-driven-development` — for red/green/refactor cycle (replaces `superpowers:test-driven-development`)
- `agent-skills:context-engineering` — for loading the right context before coding
- `agent-skills:source-driven-development` — when using external APIs/libraries, verify against official docs
- `agent-skills:debugging-and-error-recovery` — if something breaks during implementation (replaces `superpowers:systematic-debugging`)
- `agent-skills:frontend-ui-engineering` — for UI-specific work
- `agent-skills:api-and-interface-design` — for API contract work