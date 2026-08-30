---
name: feedback_skill_precedence
description: When multiple skills overlap (agent-skills vs superpowers vs custom), prefer agent-skills for engineering process, PM commands for tracking
type: feedback
originSessionId: 00000000-0000-0000-0000-000000000069
---
When multiple skills cover the same capability (TDD, debugging, code review, implementation, verification), use this precedence:

1. **PM commands (`/pm:*`)** — for project tracking, GitHub sync, status management. Always the backbone.
2. **Agent-skills (addyosmani)** — for engineering process (how to build, test, review, debug). Preferred over superpowers/custom equivalents.
3. **Custom skills** — only when they have project-specific logic that agent-skills lacks (e.g., `hotfix`, `deploy`, `db-migration`).
4. **Superpowers** — for meta-workflows only (`brainstorm`, `write-plan`, `execute-plan`, `dispatching-parallel-agents`, `using-git-worktrees`). NOT for TDD, debugging, or code review.

**Why:** Three plugin sources created overlapping skills for TDD, debugging, code review, and implementation. Without precedence, the wrong skill gets invoked or two conflicting skills run. Agent-skills are the most comprehensive and opinionated engineering process skills.

**How to apply:**
- Starting implementation? → `agent-skills:incremental-implementation`, NOT `superpowers:executing-plans`
- Writing tests? → `agent-skills:test-driven-development`, NOT `superpowers:test-driven-development`
- Debugging? → `agent-skills:debugging-and-error-recovery`, NOT `superpowers:systematic-debugging`
- Code review? → `agent-skills:code-review-and-quality`, NOT `superpowers:requesting-code-review`
- Planning/brainstorming? → `superpowers:brainstorm` / `superpowers:write-plan` (agent-skills doesn't cover meta-workflow)
- Deploying? → custom `deploy` skill (project-specific Azure/Terraform logic)
