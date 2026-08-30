# Situation → Command Mapping

Quick reference for which commands to suggest based on the current situation. Used by the using-superpowers skill for contextual suggestions.

## Situation Detection Rules

| Situation | Signal | Suggested Commands |
| ---------------------- | --------------------------------------------------------------- | ---------------------------------------------- |
| Test failure | Test runner output contains `FAIL`, `Error`, assertion failures | `/bug-fix`, `/ralph-fix-tests`, `/ralph-debug` |
| Build failure | `tsc` errors, webpack errors, Nx build failures | `/ralph-green-build`, `/cicd-troubleshoot`     |
| Large diff | `git diff --stat` shows > 400 lines changed | `/simplify`, `/code-review` with change sizing |
| New dependency | `package.json` modified with new package | `/security-audit`, `/adr-create`               |
| CI failure | GitHub Actions check failed | `/cicd-troubleshoot`, `/github-refresh`        |
| Production error | Error logs, user reports, monitoring alerts | `/incident`, `/hotfix`, `/production-access`   |
| New API endpoint | Creating routes, controllers, or DTOs | `/api-change` with contract-first gate |
| Database change | Migration files, schema changes | `/db-migration` with rollback plan |
| Frontend visual change | Component modifications, style changes | `/frontend-change`, accessibility check |
| Security concern | Auth changes, input handling, secrets | `/security-audit`, launch-readiness |
| Performance issue | Slow queries, high latency, memory usage | `/performance`, performance checklist |
| Starting new work | No active branch, fresh session | `/pm:issue-start`, `/explore-codebase`         |
| Finishing work | All tests pass, ready to ship | `/pr-create`, `/launch-readiness`              |
| Code review needed | PR created, changes ready for review | `/code-review`, `/full-review`                 |
| Debugging session | Investigating unexpected behavior | `/debug-loop`, `/ralph-debug`                  |
| Deprecating code | Removing old patterns, migration | `/deprecation-lifecycle`                       |

## PM Workflow Suggestions

After each PM command, suggest the next step:

| Just Completed | Next Step | Also Consider |
| -------------------- | ------------------------ | --------------------------------------- |
| `/pm:prd-new`        | `/pm:prd-parse`          | Review PRD with stakeholders |
| `/pm:prd-parse`      | `/pm:epic-decompose`     | `/pm:arch-create` for complex epics |
| `/pm:epic-decompose` | `/pm:tests-generate`     | Review task breakdown |
| `/pm:tests-generate` | `/pm:epic-sync`          | `/pm:readiness-check` for complex epics |
| `/pm:epic-sync`      | `/pm:issue-start`        | Review GitHub issues |
| `/pm:issue-start`    | Work on implementation | Check test manifest |
| `/pm:issue-close`    | `/pm:issue-start` (next) | `/pm:epic-review` if all done |
| `/pm:epic-review`    | `/pm:epic-merge`         | Address review findings |
| `/pm:epic-merge`     | `/pm:prod-verify`        | Monitor deployment |
| `/pm:prod-verify`    | `/pm:epic-close`         | Document learnings |
