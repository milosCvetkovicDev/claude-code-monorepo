---
name: workflow-pm-plus-agent-skills
description: How PM commands and agent-skills plugin layer together — PM tracks/syncs, agent-skills guides engineering process
type: feedback
originSessionId: 00000000-0000-0000-0000-000000000069
---
PM commands handle project management (tracking, syncing, GitHub). Agent-skills handle engineering process (how to build, test, review). They layer together.

**Why:** Agent-skills plugin (addyosmani/agent-skills) was added to complement the existing PM workflow. PM is the backbone sequence; agent-skills activate based on the type of engineering work.

**How to apply:**

| Phase | PM Command | Agent Skill |
|-------|-----------|-------------|
| Define | `pm:prd-new` | `idea-refine` |
| Spec | `pm:prd-parse` | `spec-driven-development` |
| Architect | `pm:arch-create` | `api-and-interface-design` |
| Plan | `pm:epic-decompose` | `planning-and-task-breakdown` |
| Test First | `pm:tests-generate` | `test-driven-development` |
| Gate | `pm:readiness-check` | — |
| Sync | `pm:epic-sync` | `git-workflow-and-versioning` |
| Build | `pm:issue-start` | `incremental-implementation`, `context-engineering`, `source-driven-development`, `frontend-ui-engineering` |
| Bug | — | `debugging-and-error-recovery` |
| Close | `pm:issue-close` | `code-review-and-quality` |
| Review | `pm:epic-review` | `security-and-hardening`, `performance-optimization` |
| Merge | `pm:epic-merge` | — |
| Ship | `pm:prod-verify` | `shipping-and-launch` |
| Done | `pm:epic-close` | — |

Agent skills activate automatically via the using-agent-skills flowchart — no manual invocation needed.
