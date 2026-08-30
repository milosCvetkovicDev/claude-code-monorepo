# Reference Loading

Rule files are organized in tiers. Only essential rules are loaded automatically.
Detailed workflow and architecture references are loaded on-demand.

## On-Demand Reference Locations

When a PM command (`/pm:*`) is invoked, read the relevant reference:

| Trigger | Read |
| -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/pm:prd-new`, `/pm:prd-parse`                                 | `~/.claude/references/workflow/quality-workflow.md`                                                                                                           |
| `/pm:arch-create`                                              | `acme/.claude/references/architecture/architecture-operations.md`, `acme/.claude/references/architecture/ddd-practices.md`                                |
| `/pm:epic-decompose`                                           | `~/.claude/references/workflow/scale-routing.md`                                                                                                              |
| `/pm:tests-generate`                                           | `~/.claude/references/workflow/test-first-development.md`, `~/.claude/references/workflow/loop-engineering.md`                                                |
| `/pm:readiness-check`                                          | `~/.claude/references/workflow/readiness-gate.md`                                                                                                             |
| `/pm:epic-sync`                                                | `~/.claude/references/git/worktree-operations.md`                                                                                                             |
| `/pm:issue-start`                                              | `~/.claude/references/workflow/agent-coordination.md`, `~/.claude/references/workflow/test-execution.md`, `~/.claude/references/workflow/loop-engineering.md` |
| `/pm:epic-review`                                              | `~/.claude/references/workflow/review-triage.md`, `~/.claude/references/workflow/loop-engineering.md`                                                         |
| `/pm:epic-merge`                                               | `~/.claude/references/git/branch-operations.md`                                                                                                               |
| `/pm:issue-close`, `/pm:prod-verify`                           | `~/.claude/references/workflow/loop-engineering.md`                                                                                                           |
| `/pm:epic-close`                                               | `~/.claude/references/workflow/loop-engineering.md`                                                                                                           |
| `/loop`, `/triage`, `verify-loop`, or any loop/automation work | `~/.claude/references/workflow/loop-engineering.md` (+ project `docs/loop-engineering.md` if present)                                                         |
| Milestone commands | `~/.claude/references/workflow/milestone-operations.md`                                                                                                       |
| Git branching | `~/.claude/references/git/branch-operations.md`                                                                                                               |
| Git worktrees | `~/.claude/references/git/worktree-operations.md`                                                                                                             |
| AST-based search | `~/.claude/references/git/use-ast-grep.md`                                                                                                                    |
| Editing `.github/workflows/*.yml` or `.github/actions/**`      | `~/.claude/references/cicd/github-actions-patterns.md`, `~/.claude/references/cicd/verified-versions.md`                                                      |
| Editing `Dockerfile*` or `docker-compose*.yml`                 | `~/.claude/references/cicd/docker-patterns.md`                                                                                                                |
| Editing `charts/**` (Helm/K8s/ArgoCD)                          | `~/.claude/references/cicd/k8s-helm-argocd-patterns.md`                                                                                                       |
| Any CI/CD version change | `~/.claude/references/cicd/verified-versions.md`                                                                                                              |
| `/cicd-troubleshoot` skill | All four `~/.claude/references/cicd/*.md` files |

Do NOT preemptively read these files. Only read them when the user invokes the relevant command or explicitly asks about the topic.
