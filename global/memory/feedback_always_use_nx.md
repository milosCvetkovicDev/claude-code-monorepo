---
name: always-use-nx-commands
description: User insists on always using Nx commands, never raw tool invocations
type: feedback
---

Always consult Nx monorepo docs and use Nx commands for everything — never run tsc, eslint, jest, prettier, or vitest directly.

**Why:** This is an Nx monorepo. Running tools directly bypasses Nx's project graph, caching, and task pipeline. It can miss dependencies, produce inconsistent results, and waste CI cache.

**How to apply:** Use `nx run <project>:<target>` or `nx run-many` / `nx affected` for all build, test, lint, typecheck, and format operations. Even for single-project tasks, go through Nx.
