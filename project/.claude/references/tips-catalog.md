# Tips Catalog

Contextual tips shown during development sessions. Maximum 1 tip per session, context-relevant, never repeated in the same session.

## Tip Selection Rules

1. Check session breadcrumb at `.claude/.tips-shown` — skip if tip ID already listed
2. Match trigger condition against current context
3. Show the first matching tip that hasn't been shown
4. Append tip ID to `.claude/.tips-shown`

## Tips

### Development Workflow

| ID        | Trigger | Tip |
| --------- | ------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `tip-001` | First `/pm:issue-start` of session | **Did you know?** You can run `/help-all` to see every available command organized by category.                                                          |
| `tip-002` | Editing a file with framework imports | **Did you know?** The source-driven-dev hook ensures you fetch current docs before editing framework code. If blocked, use context7 to fetch docs first. |
| `tip-003` | Running `/simplify` or `/refactor`    | **Did you know?** You can protect code blocks from simplification with `/* simplify-ignore-start: reason */` annotations.                                |
| `tip-004` | Creating a commit with > 400 lines | **Did you know?** Large commits are harder to review. Consider splitting into smaller, focused commits.                                                  |
| `tip-005` | Running `/code-review`                | **Did you know?** Code review now auto-loads security, performance, and accessibility checklists based on which files changed.                           |

### Quality & Safety

| ID        | Trigger | Tip |
| --------- | -------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `tip-006` | First deploy command of session | **Did you know?** The launch-readiness gate blocks deploys until you run a 6-area readiness check. Use `/launch-readiness` first. |
| `tip-007` | Test failure in output | **Did you know?** Try `/ralph-fix-tests` for autonomous test fixing, or `/ralph-debug` for systematic debugging.                  |
| `tip-008` | Adding a new npm package | **Did you know?** New dependencies should have an ADR if they add > 100KB to the bundle. Run `/adr-create` to scaffold one.       |
| `tip-009` | Modifying auth-related code | **Did you know?** Run `/security-audit` after auth changes. The security checklist covers Acme-specific patterns.               |
| `tip-010` | Working in `apps/legacy-api/` | **Did you know?** Legacy Express code may have a Platform replacement. Run `/deprecation-lifecycle detect` to check.                 |

### Productivity

| ID        | Trigger | Tip |
| --------- | ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `tip-011` | Long session (> 30 messages) | **Did you know?** In long sessions, context can get stale. Re-read key files before making assumptions about their current state.                                               |
| `tip-012` | First PR creation of session | **Did you know?** `/pr-create` includes change sizing. PRs over 400 lines get flagged for splitting.                                                                            |
| `tip-013` | Working on multiple issues | **Did you know?** Parallel tasks in an epic can be worked on simultaneously with `/pm:issue-start`. Each gets its own agent stream.                                             |
| `tip-014` | Running `/incident`          | **Did you know?** Check the production quick reference in memory for DB connection strings, app service names, and deploy commands.                                             |
| `tip-015` | First brainstorming session | **Did you know?** Brainstorming now offers structured ideation frameworks: SCAMPER for existing features, First Principles for new architecture, JTBD for user-facing features. |
| `tip-016` | Claiming a task is complete | **Did you know?** The verification skill now requires concrete evidence (test output, build log, screenshots) — not just "it looks right."                                      |
