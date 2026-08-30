---
name: source-driven-dev
description: 'Fetch and verify official documentation before writing framework-specific code. Use when editing files that import tracked frameworks (NestJS, MikroORM, Fastify, React, MUI, Playwright, Terraform, Helm, ArgoCD). Enforced by PreToolUse hook.'
---

# Source-Driven Development

Verify against official documentation before implementing framework-specific code. This prevents hallucinated APIs, deprecated patterns, and version mismatches.

## Tracked Frameworks

| Framework | Import Pattern | Doc Source |
| ---------- | ------------------------------ | ----------------------------------- |
| NestJS     | `@nestjs/`                     | context7 or nestjs.com |
| MikroORM   | `@mikro-orm/`                  | context7 or mikro-orm.io |
| Fastify | `fastify`                      | context7 or fastify.dev |
| React | `from 'react'`, `from "react"` | context7 or react.dev |
| MUI        | `@mui/`                        | context7 or mui.com |
| Playwright | `@playwright/`                 | context7 or playwright.dev |
| Terraform | `terraform`                    | context7 or developer.hashicorp.com |
| Helm | `helm`                         | context7 or helm.sh |
| ArgoCD     | `argocd`                       | context7 or argo-cd.readthedocs.io |

## Workflow

### Step 1: Detect Framework Usage

Before writing or editing a file, check if it imports any tracked framework.

### Step 2: Fetch Documentation

If a tracked framework is detected:

1. Use **context7** (preferred) or **WebFetch** to retrieve current documentation for the specific API/feature you are implementing
2. After successful fetch, create a breadcrumb file:
   ```bash
   mkdir -p .claude/.source-driven-dev
   touch .claude/.source-driven-dev/{framework}.fetched
   ```
3. The PreToolUse hook will block your Write/Edit until this breadcrumb exists

### Step 3: Implement with Citation

After implementing code based on fetched documentation, add a source citation comment:

```typescript
// Source: https://docs.nestjs.com/controllers — verified 2026-04-10
```

Format: `// Source: {url} — verified {YYYY-MM-DD}`

Place the citation:

- Above the function/class that uses the documented API
- One citation per distinct API usage (not per line)

### Step 4: Handle Unavailable Documentation

If documentation cannot be fetched (network issues, context7 unavailable):

1. Mark the implementation with an `[UNVERIFIED]` flag:
   ```typescript
   // [UNVERIFIED] — could not fetch NestJS docs for @UseGuards pattern
   @UseGuards(AuthGuard)
   ```
2. Still create the breadcrumb (to unblock the hook) but note the limitation
3. Add a TODO for later verification

## Hook Enforcement

A PreToolUse hook (`.claude/hooks/source-driven-dev.sh`) enforces this workflow:

- **Triggers on**: Write, Edit tool calls
- **Checks**: Whether breadcrumb file exists for detected frameworks
- **Blocks with exit 2**: When framework detected but no breadcrumb
- **Allows with exit 0**: When breadcrumb exists or no framework detected

## Breadcrumb Cleanup

Breadcrumb files in `.claude/.source-driven-dev/` are session-scoped. They are cleaned up by the `cleanup-resources.sh` hook on session end. This ensures each new session requires fresh documentation verification.

## When This Skill Does NOT Apply

- Files with no tracked framework imports (plain TypeScript, utilities, configs)
- Test files (`.spec.ts`, `.test.ts`) — testing framework APIs are well-known
- Generated files (migrations, Nx configs)
- Markdown, JSON, YAML files

## Anti-Rationalization Table

| If you're thinking...                         | Remember...                                                                                      |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| "I know this API from memory"                 | APIs change between versions. Verify against current docs — what you remember may be deprecated. |
| "The docs are probably the same as last time" | Even minor version bumps can change behavior. Always check current documentation.                |
| "Context7 is slow, I'll skip it this time"    | A wrong API call costs more time than a doc fetch. The hook exists for a reason.                 |
