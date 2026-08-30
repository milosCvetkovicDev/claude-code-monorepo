---
name: debug-loop
description: "Autonomous debugging loop that runs scripts, analyzes failures, implements fixes, and iterates until tests pass without human intervention. Use when a script or test is failing and the user wants automated fix iterations. Do not use for manual investigation (use bug-fix) or CI/CD failures (use cicd-troubleshoot)."
---

# Autonomous Debug Loop

This skill enables fully autonomous debugging where Claude iterates on script/test failures independently until everything passes, without requiring user intervention at each step.

## When to Use

- Running tests that are failing and need fixes
- Debugging scripts that encounter errors
- Fixing compilation errors until build succeeds
- Resolving integration test failures
- Any repetitive debug cycle that would normally require multiple back-and-forth iterations

## Core Philosophy

**Autonomous operation** - Claude should:

- Make decisions independently based on error messages
- Try multiple approaches if the first fix doesn't work
- Continue iterating until success or clear blocker
- Document all attempts and reasoning
- Only ask for help when truly stuck

## Workflow

### 1. Initial Run

Execute the script/test and capture all output:

- Full stdout and stderr
- Exit codes
- Stack traces
- Error messages
- Test failure details

### 2. Analyze Failures

For each error/failure:

- Identify the root cause from error messages
- Locate the relevant source files
- Understand the expected vs actual behavior
- Determine if this is a code bug, config issue, or environment problem

### 3. Implement Fix

Make targeted changes:

- Prefer minimal, surgical fixes over large refactors
- Fix one issue at a time when possible
- Update tests if the error indicates test bugs
- Adjust configuration if env-related

### 4. Verify Fix

Re-run the same command:

- Check if this specific error is resolved
- Note any new errors that appear
- Track progress (e.g., "5 tests failing → 3 tests failing")

### 5. Iterate

Continue the loop:

- If all tests pass → SUCCESS, document fixes made
- If new errors appear → Analyze and fix (go to step 2)
- If same error persists → Try alternative approach
- If stuck after 3 attempts → Report blockage and ask for guidance

### 6. Summary Report

When complete (success or blocked):

- List all fixes implemented
- Show before/after test results
- Document any remaining issues
- Suggest follow-up work if needed

## Decision-Making Guidelines

### When to Make Decisions Autonomously

✅ **Fix these without asking**:

- Syntax errors and typos
- Missing imports
- Type errors with clear solutions
- Test assertion updates when requirements changed
- Configuration typos (wrong variable names)
- Missing null checks
- Obvious logic bugs

### When to Ask for Guidance

❌ **Stop and ask about**:

- Business logic decisions (which rule is correct?)
- Architecture changes (should we refactor this?)
- Breaking changes (this will affect other features)
- Security implications (credential handling, auth)
- Data loss risks (migration, deletion)
- Can't determine root cause after reading code

## Example Execution

```
User: "Run the test suite until it all passes"

Claude:
1. Running: npm test
   → 5 tests failing
   → Error: Cannot find module '@acme/config-types'

2. Analysis: Missing dependency in package.json

3. Fix: Add "@acme/config-types": "workspace:*" to package.json

4. Re-run: npm test
   → 3 tests failing (progress!)
   → Error: Expected 'EUR' but got 'GBP'

5. Analysis: Test data using wrong currency in mock

6. Fix: Update test builder to use EUR

7. Re-run: npm test
   → 1 test failing
   → Error: Database connection timeout

8. Analysis: PostgreSQL not running

9. Fix: Start Docker: docker compose up -d

10. Re-run: npm test
    → ✅ All tests passing!

Summary:
✅ Fixed missing dependency
✅ Updated test currency data
✅ Started database
✅ All 5 tests now passing
```

## Iteration Limits

**Default**: Max 10 iterations
**Safety**: If same error repeats 3 times, stop and ask
**Timeout**: If iteration takes >5 minutes, report and ask

## Output Format

Each iteration should show:

```
🔄 Iteration N/10
Command: <command>
Result: <pass/fail>
Errors: <count>

[If failed]
📊 Analysis: <root cause>
🔧 Fix: <what I'm changing>
```

Final output:

```
✅ SUCCESS - All issues resolved
🛠️  Fixes applied:
   1. <fix 1>
   2. <fix 2>
   3. <fix 3>

📈 Progress: X failures → 0 failures
⏱️  Total iterations: N
```

## Best Practices

1. **Read error messages carefully** - Most errors tell you exactly what's wrong
2. **Fix one thing at a time** - Don't batch unrelated fixes
3. **Verify each fix** - Always re-run to confirm it worked
4. **Document as you go** - User should understand what happened
5. **Know when to stop** - Don't get stuck in infinite loops
6. **Preserve working code** - Only change what's needed

## Integration with Other Skills

- Use `/run-script` first for config validation
- Use `/test-affected` to narrow scope to affected tests
- Use debugging patterns from `/systematic-debugging` when stuck

## Headless Mode Example

For fully autonomous operation via CLI:

```bash
claude --headless \
  --max-turns 10 \
  --task "Run npm test and fix all failures until passing" \
  --allowedTools "Read,Write,Edit,Bash,Grep,Glob"
```
