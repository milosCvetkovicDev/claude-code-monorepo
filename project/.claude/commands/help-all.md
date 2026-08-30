# Help: All Commands

Display the full categorized command catalog for the Acme project.

## Instructions

Print the following catalog. Do not read files or explore the codebase — just output this reference.

---

## PM Workflow (in order)

| Command | Description |
| ---------------------------- | ----------------------------------------------------------------- |
| `/pm:prd-new <name>`         | Create new Product Requirements Document via brainstorming |
| `/pm:prd-parse <name>`       | Convert PRD to technical implementation epic |
| `/pm:arch-create <name>`     | Create architecture document for epic (optional)                  |
| `/pm:epic-decompose <name>`  | Break epic into concrete, actionable tasks |
| `/pm:tests-generate <name>`  | Generate failing test suites from acceptance criteria (red phase) |
| `/pm:readiness-check <name>` | Validate epic is ready for implementation (optional)              |
| `/pm:epic-sync <name>`       | Push epic and tasks to GitHub as issues |
| `/pm:issue-start <number>`   | Begin work on a GitHub issue with parallel agents |
| `/pm:issue-close <number>`   | Complete issue with verification and sync |
| `/pm:epic-review <name>`     | Run multi-agent code review on epic branch |
| `/pm:epic-merge <name>`      | Merge epic branch to main |
| `/pm:prod-verify <name>`     | Verify deployment in production |
| `/pm:epic-close <name>`      | Close epic and all associated issues |

## Development

| Command | Description |
| ------------------ | ------------------------------------------ |
| `/new-feature`     | Implement a new feature end-to-end |
| `/api-change`      | Modify or create API endpoints |
| `/frontend-change` | Modify React/MUI frontend components |
| `/db-migration`    | Create and run database migrations |
| `/bug-fix`         | Investigate, reproduce, fix, and test bugs |
| `/refactor`        | Refactor code with safety checks |
| `/hotfix`          | Emergency production fix workflow |

## Code Quality

| Command | Description |
| ----------------- | ------------------------------------------ |
| `/code-review`    | Review code changes for quality and issues |
| `/full-review`    | Comprehensive multi-axis code review |
| `/security-audit` | OWASP-aligned security review |
| `/performance`    | Performance analysis and optimization |
| `/simplify`       | Simplify code with Chesterton's Fence gate |
| `/test-affected`  | Run tests for affected projects |
| `/sonar-scan`     | Run SonarQube analysis |

## Autonomous Loops

| Command | Description |
| ----------------------- | ------------------------------------- |
| `/implement-all`        | Full autonomous implementation loop |
| `/ralph-implement-spec` | Ralph: implement from specification |
| `/ralph-fix-tests`      | Ralph: fix failing tests autonomously |
| `/ralph-green-build`    | Ralph: get build to green |
| `/ralph-debug`          | Ralph: systematic debugging loop |
| `/ralph-refactor`       | Ralph: autonomous refactoring |
| `/debug-loop`           | Iterative debugging until fixed |

## Infrastructure

| Command | Description |
| -------------------- | ------------------------------------- |
| `/deploy`            | Deploy to environment |
| `/launch-readiness`  | Run 6-area pre-deploy readiness check |
| `/infra-change`      | Modify Terraform/infrastructure |
| `/dev-ephemeral`      | Manage development instances |
| `/cicd-troubleshoot` | Debug CI/CD pipeline issues |
| `/k8s-troubleshoot`  | Debug Kubernetes/Helm issues |

## Lifecycle

| Command | Description |
| ------------------------ | ----------------------------------------------------------- |
| `/deprecation-lifecycle` | Manage code deprecation: detect, deprecate, migrate, remove |
| `/adr-create`            | Create Architecture Decision Record |
| `/requirements-changed`  | Handle changed requirements |
| `/update-deps`           | Update npm dependencies safely |
| `/cleanup`               | Clean up unused code and files |

## Utilities

| Command | Description |
| ------------------- | -------------------------------------- |
| `/commit`           | Create conventional commit with checks |
| `/pr-create`        | Create pull request with template |
| `/explore-codebase` | Navigate and understand codebase |
| `/add-docs`         | Add documentation |
| `/technical-spec`   | Generate technical specification |
| `/system-design`    | Design system architecture |
| `/incident`         | Production incident response |
| `/erp-issue`       | Debug ERP integration issues |

## Status & Navigation

| Command | Description |
| -------------------- | ------------------------------------- |
| `/env-status`        | Show environment status |
| `/github-refresh`    | Refresh GitHub context |
| `/session-learnings` | Review learnings from current session |
| `/help-all`          | This catalog |

---

**Tip:** Commands are skills that guide the agent through structured workflows. Use `/pm:*` commands for the full development ceremony, or individual commands for specific tasks.
