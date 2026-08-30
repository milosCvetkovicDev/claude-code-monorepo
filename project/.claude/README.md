# Claude Code Guide for Acme

Quick reference for skills, agents, and workflow optimization.

## Skills (Invoke with `/skill-name`)

| I want to...                | Skill |
| --------------------------- | ------------------- |
| Fix a bug | `/bug-fix`          |
| Build a new feature | `/new-feature`      |
| Create a PR                 | `/pr-create`        |
| Review code before merge | `/full-review`      |
| Make frontend changes | `/frontend-change`  |
| Add/modify an API endpoint | `/api-change`       |
| Create database migration | `/db-migration`     |
| Fix urgent production issue | `/hotfix`           |
| Improve code structure | `/refactor`         |
| Understand the codebase | `/explore-codebase` |
| Update npm packages | `/update-deps`      |
| Run security audit | `/security-audit`   |
| Investigate performance | `/performance`      |
| Handle production incident | `/incident`         |
| Fix ERP sync issues | `/erp-issue`       |
| Modify infrastructure | `/infra-change`     |
| Create documentation | `/add-docs`         |
| Create new application | `/new-app`          |
| Create a technical spec | `/technical-spec`   |

## Loop engineering

A system prompts the agents, not you. Full map (six primitives → our tools, run modes, PM-ceremony integration): [`docs/loop-engineering.md`](../docs/loop-engineering.md).

| I want to...                              | Skill |
| ----------------------------------------- | -------------- |
| Triage repo health → a ranked inbox | `/triage`      |
| Drive a task to a checker-verified finish | `/verify-loop` |

`/triage` is read-only by default (writes `.claude/triage/inbox.md`, opens nothing); run it standing, with `/loop /triage`, or on a `/schedule`. `verify-loop` runs until a verifiable stop condition is graded true by a **separate** checker — never the maker (`done` is a claim, not a proof).

## Agents

Specialized reviewers/experts used by skills automatically. Can also be invoked directly:

```
"Use the security-auditor agent to check this code"
```

| Agent | Expertise |
| ----------------------------- | --------------------------------------------- |
| `api-designer`                | REST API design, DTOs, validation |
| `database-migration-expert`   | TypeORM migrations, schema changes |
| `ddd-expert`                  | Domain modeling, aggregates, bounded contexts |
| `e2e-testing-expert`          | Playwright tests, Page Object Model |
| `frontend-specialist`         | React/MUI components, hooks, state |
| `github-actions-expert`       | CI/CD workflows, composite actions |
| `incident-responder`          | Production diagnosis, rollback |
| `interview-user`              | Requirements gathering interviews |
| `nx-expert`                   | Nx workspace, generators, caching |
| `review-azure-architect`      | Azure Well-Architected Framework |
| `erp-integration-specialist` | the ERP OAuth, sync, invoices |
| `security-auditor`            | OWASP vulnerabilities, auth |
| `technical-spec`              | Specs from requirements |
| `terraform-expert`            | Terraform/Azure IaC                           |
| `ui-expert`                   | MUI design system, accessibility |

## Ralph Loop Skills (Autonomous Iteration)

Ralph Loop skills run **autonomously** using the [Ralph Wiggum technique](https://ghuntley.com/ralph/) — the same prompt is fed repeatedly, with each iteration building on previous work visible in files and git history.

| I want to...              | Skill | Max iterations |
| ------------------------- | ----------------------- | -------------- |
| Fix all failing tests | `/ralph-fix-tests`      | 25             |
| Implement a full spec | `/ralph-implement-spec` | 50             |
| Fix a specific bug (TDD)  | `/ralph-debug`          | 15             |
| Refactor incrementally | `/ralph-refactor`       | 30             |
| Get the whole build green | `/ralph-green-build`    | 30             |

```bash
# Examples
/ralph-fix-tests --project legacy-api
/ralph-implement-spec docs/plans/commission-export-spec.md
/ralph-debug "Invoice totals wrong for multi-currency" --github-issue 142
/ralph-green-build
```

**Best practices**: Run in tmux. Start from clean git state. Monitor with `head -10 .claude/ralph-loop.local.md`. Cancel with `/cancel-ralph`. Review with `/full-review` before merging.

## Hooks (Auto-Installed)

Hooks run automatically. First-time setup: `claude --init`

| When | What Happens |
| ---------------- | ----------------------------------------------- |
| Session starts | Git syncs, Docker checked, GitHub PRs loaded |
| You edit a file | Prettier auto-formats |
| Before bash runs | Dangerous commands blocked, Nx usage encouraged |
| Before file edit | Sensitive files (.env, keys) protected |
| Claude finishes | Affected tests run (quality gate)               |
| Session ends | Nx daemon stopped, orphaned processes killed |

See `.claude/hooks/README.md` for full documentation.

## File Locations

```
.claude/
├── agents/               # Agent definitions (15 active + 8 archived)
├── skills/               # Skill workflows (~50 skills, incl. 5 Ralph Loop)
├── hooks/                # Automation hooks (~23 hooks)
├── settings.json         # Project settings
├── plugin.json           # Plugin manifest
└── README.md             # This file
```
