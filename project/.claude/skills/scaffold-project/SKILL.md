---
name: scaffold-project
description: "Create a new Nx project (library or app) following Acme monorepo conventions: directory structure, TypeScript config, linting, testing, and CI integration. Use when the user needs a new library or project within the monorepo. Do not use for full application scaffolding (use new-app)."
model: sonnet
disable-model-invocation: true
args: <project-name> --type <type> [--scope <scope>]
---

# Scaffold Project

You are creating a new Nx project following workspace conventions.

## Input

- **project-name**: Name of the new project (kebab-case)
- **type**: Project type (see supported types below)
- **scope** (optional): Scope tag for libraries

## Supported Types

| Type | Generator | Default Tags | Directory |
| -------------- | ----------------------- | ---------------------------------- | -------------- |
| `backend-app`  | `@nx/node:application`  | `scope:backend`, `type:app`        | `apps/`        |
| `frontend-app` | `@nx/react:application` | `scope:frontend`, `type:app`       | `apps/`        |
| `mcp-server`   | `@nx/node:application`  | `scope:backend`, `type:mcp-server` | `apps/`        |
| `library`      | `@nx/node:library`      | `type:lib` + requires `--scope`    | `libs/`        |
| `shared-lib`   | `@nx/node:library`      | `scope:shared`, `type:lib`         | `libs/shared/` |
| `e2e`          | `@nx/playwright:config` | `scope:e2e`, `type:e2e`            | `apps/`        |

## Workflow

### Step 1: Validate Input

1. Check project name is kebab-case: `/^[a-z][a-z0-9-]*$/`
2. Check project name is unique (not already in workspace)
3. For `library` type, verify `--scope` is provided
4. Verify the type is supported

### Step 2: Determine Generator Options

Based on project type, construct the Nx generator command:

```bash
# Backend App
nx generate @nx/node:application <name> \
  --directory=apps/<name> \
  --tags="scope:backend,type:app" \
  --bundler=esbuild

# Frontend App
nx generate @nx/react:application <name> \
  --directory=apps/<name> \
  --tags="scope:frontend,type:app" \
  --bundler=vite \
  --style=none \
  --routing=true

# MCP Server
nx generate @nx/node:application <name> \
  --directory=apps/<name> \
  --tags="scope:backend,type:mcp-server" \
  --bundler=esbuild

# Library (with scope)
nx generate @nx/node:library <name> \
  --directory=libs/<name> \
  --tags="scope:<scope>,type:lib" \
  --buildable

# Shared Library
nx generate @nx/node:library <name> \
  --directory=libs/shared/<name> \
  --tags="scope:shared,type:lib" \
  --buildable
```

### Step 3: Run Generator

1. Execute the Nx generator command
2. Wait for completion
3. Verify project was created successfully

### Step 4: Create CLAUDE.md

Create a CLAUDE.md file for the new project:

```markdown
# CLAUDE.md - <Project Name>

## Overview

<Brief description of the project's purpose>

## Quick Reference

\`\`\`bash

# Development

nx run <project>:serve

# Build

nx run <project>:build

# Test

nx run <project>:test

# Lint

nx run <project>:lint
\`\`\`

## Project Structure

\`\`\`
<project>/
├── src/
│ └── main.ts
├── project.json
└── tsconfig.json
\`\`\`

## Conventions

- Follow patterns from root CLAUDE.md
- <Add project-specific conventions>
```

### Step 5: Verify Setup

1. Run build: `nx run <project>:build`
2. Run lint: `nx run <project>:lint`
3. Verify both pass

### Step 6: Update Root CLAUDE.md (if needed)

If creating a significant new app, consider adding it to the project structure section in the root CLAUDE.md.

## Output

```markdown
## Project Scaffolded: <project-name>

### Type: <type>

### Location: apps/<project-name>/ or libs/<project-name>/

### Tags: scope:backend, type:mcp-server

### Files Created

- `apps/<project-name>/project.json`
- `apps/<project-name>/src/main.ts`
- `apps/<project-name>/tsconfig.json`
- `apps/<project-name>/CLAUDE.md`

### Verification

| Check | Status |
| ----- | ------ |
| Build | ✅     |
| Lint | ✅     |

### Next Steps

1. Implement the main functionality in `src/main.ts`
2. Add dependencies as needed
3. Write tests
```

## Error Handling

If generator fails:

1. Report the error message
2. Common issues:
   - Project name already exists
   - Invalid characters in name
   - Missing plugin (suggest `npm install @nx/<plugin>`)
3. Suggest fix and offer to retry
