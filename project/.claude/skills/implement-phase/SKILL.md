---
name: implement-phase
description: "Execute a single phase from a technical specification with proper validation. Use when the user has a multi-phase spec and wants to implement one phase at a time. Do not use for implementing all phases (use implement-all) or when no spec exists."
model: sonnet
disable-model-invocation: true
args: <spec-file> --phase <number>
---

# Implement Phase

You are implementing a single phase from an approved technical specification.

## Input

- **Spec file**: Path to technical specification (e.g., `docs/plans/acme-mcp-technical-spec.md`)
- **Phase number**: Which phase to implement (1-based)

## Workflow

### Step 1: Load Context

1. Read the technical specification file
2. Extract the specified phase section (look for "### Phase N:" or "## Phase N:")
3. Read all relevant CLAUDE.md files:
   - Root `/CLAUDE.md`
   - Target project `apps/<project>/CLAUDE.md` (if exists)
   - Related libs `libs/*/CLAUDE.md` (if referenced)

### Step 2: Create Task List

For each task in the phase, create a TaskCreate entry with:

- Subject: Task title from spec
- Description: Full task details
- ActiveForm: "Implementing <task>"

### Step 3: Execute Tasks

For each task (in order):

1. **Mark task in_progress** using TaskUpdate
2. **Check conventions**:
   - If creating projects/apps: Use Nx generator (NEVER manual mkdir)
   - If writing services: Use functional exports (not classes) for backend
   - If adding dependencies: Use `npm install`
3. **Implement the task**:
   - Follow patterns from CLAUDE.md
   - Use existing code as reference (grep for similar patterns)
   - Write minimal, focused code (no over-engineering)
4. **Verify task**:
   - Build passes: `nx run <project>:build`
   - Lint passes: `nx run <project>:lint`
   - Tests pass (if written): `nx run <project>:test`
5. **Mark task completed** using TaskUpdate

### Step 4: Phase Validation

After all tasks complete:

1. Read the "Validation" section for this phase from the spec
2. Run each validation criterion
3. Report pass/fail for each

### Step 5: Commit

If all validations pass:

1. Stage relevant changes: `git add <files>`
2. Commit with message: `feat(<project>): implement phase N - <phase-title>`

## Convention Enforcement (CRITICAL)

### Nx Usage

```bash
# CORRECT - Use Nx generators
nx generate @nx/node:application acme-mcp --directory=apps/acme-mcp --tags="scope:backend,type:mcp-server"

# WRONG - Never create apps manually
mkdir apps/acme-mcp  # DON'T DO THIS
```

### Service Pattern (Backend)

```typescript
// CORRECT - Functional exports (legacy-api pattern)
export const checkDatabaseStatus = async (dataSource: DataSource): Promise<DbStatus> => {
  // implementation
};

// WRONG - Class-based services
export class DatabaseService {
  constructor(private dataSource: DataSource) {}
  async checkStatus() {
    /* ... */
  }
}
```

### Bundler Choice

```json
// CORRECT - Use esbuild (matches nx-cache-server-bun)
{
  "executor": "@nx/esbuild:esbuild",
  "options": {
    "platform": "node",
    "format": ["esm"]
  }
}
```

### Multi-Tenancy (Backend)

```typescript
// CORRECT - Always require tradingCompanyId as first parameter
export const findPendingSyncs = async (
  tradingCompanyId: number, // REQUIRED
  filters: SyncFilters
): Promise<PendingSync[]> => {
  if (!tradingCompanyId) {
    throw new Error('tradingCompanyId is required');
  }
  // implementation
};
```

## Error Handling

If a task fails:

1. **Stop execution** - Do not proceed to next task
2. **Report error** with:
   - Which task failed
   - Error message
   - Suggested fix
3. **Do not commit** partial work
4. **Ask user** how to proceed using AskUserQuestion:
   - Retry with fix
   - Skip this task
   - Abort phase

## Output

After phase completion, report:

```markdown
## Phase N Implementation Complete

### Tasks Completed

- [x] Task 1: Create project structure
- [x] Task 2: Add dependencies
- [x] Task 3: Implement core service

### Validation Results

| Criterion | Status |
| ----------------- | ------ |
| Build passes | ✅     |
| Tests pass | ✅     |
| Lint passes | ✅     |
| MCP server starts | ✅     |

### Commit

`abc1234` feat(acme-mcp): implement phase 1 - project scaffolding

### Next Steps

Run `/implement-phase <spec-file> --phase 2` to continue.
```
