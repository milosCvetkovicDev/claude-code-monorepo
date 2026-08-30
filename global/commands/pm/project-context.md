---
allowed-tools: Bash, Read, Write, LS
---

# Project Context

Generate or update a lean project context file that provides agents with project-specific implementation rules.

## Usage
```
/pm:project-context
```

No arguments — operates on the current project directory.

## Preflight Checklist

Do not bother the user with preflight checks progress. Just do them and move on.

1. **Verify project root:**
   - Check for `package.json`, `go.mod`, `Cargo.toml`, or other project marker
   - If none: "❌ Not in a project directory"

2. **Check existing context:**
   - If `.claude/project-context.md` exists: UPDATE mode (preserve user-added rules)
   - If not: CREATE mode

## Instructions

### 1. Scan Project Configuration

Read if they exist:
```bash
cat package.json 2>/dev/null | head -100
ls tsconfig.json jest.config.* playwright.config.* vite.config.* .eslintrc.* nx.json 2>/dev/null
ls .claude/epics/*/architecture.md 2>/dev/null | tail -1
ls .claude/milestones/*/master-architecture.md 2>/dev/null
```

Extract: dependencies with exact versions, framework config, build/test scripts.

### 2. Sample Existing Code Patterns

Read 3-5 representative source files to identify:
- Import style (named vs default, barrel files)
- Error handling patterns
- Naming conventions
- Test patterns
- Type usage (strict, enums, branded types)

### 3. Check for Duplication with CLAUDE.md

Read the project's CLAUDE.md. Do NOT duplicate rules already there. project-context.md is for rules agents would NOT know from CLAUDE.md or general best practices.

### 4. Generate Content (7 Categories)

Include ONLY project-specific rules. Generic coding advice wastes tokens.

#### 4.1 Tech Stack & Versions
Exact versions from package.json where version-specific behavior matters.

#### 4.2 Language-Specific Rules
TypeScript strictness, path aliases, import conventions specific to this project.

#### 4.3 Framework-Specific Rules
Patterns unique to this codebase (e.g., "always use TanStack Query, never useEffect for data fetching").

#### 4.4 Testing Rules
Which framework for which app. File naming. Mock vs real service conventions.

#### 4.5 Code Quality & Style
Lint rules, Prettier config, import ordering that's project-specific.

#### 4.6 Dev Workflow Rules
Branch naming, commit format, which commands to use.

#### 4.7 Critical Don'ts (Anti-Patterns)
Project-specific mistakes to avoid with concrete examples.

### 5. Migration State (if multi-milestone)

If `.claude/milestones/*/program.md` exists, add:
```markdown
## Migration State
| Domain | Current Stack | Target Stack | Status | Milestone |
|--------|--------------|-------------|--------|-----------|
```

Populate from milestone data and codebase scan.

### 6. Write File

Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

Write to `.claude/project-context.md`:
```yaml
---
generated: [datetime]
updated: [datetime]
project_root: .
categories: 7
migration_tracked: true|false
---
```

In UPDATE mode: preserve sections marked `# [USER-ADDED]` and only update auto-generated sections.

## Post-Creation

```
✅ Project context: .claude/project-context.md

Categories: {n}
Rules: {total_count}
Migration tracking: {yes/no}

Loaded by agents during /pm:issue-start.
Update after each epic: /pm:project-context
```

## Error Recovery

- If package.json unreadable: generate from available config
- If no source files: minimal context from config only

## Important Notes

- LEAN: only rules agents would NOT already know
- Do NOT duplicate what's in CLAUDE.md
- Run before first `/pm:issue-start`
- Re-run after each `epic-close` to update migration state
- Follow `/rules/datetime.md` for timestamps
