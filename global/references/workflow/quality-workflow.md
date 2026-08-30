# Maximum Confidence Workflow

Layered process combining CCPM commands with quality plugins and always-on hooks.
Every feature follows: Requirements → Tests (RED) → Sync → Implement (GREEN) → Review → Merge → Production Verify → Cleanup.

## Workflow Phases

### Phase 1: Requirements

```
/superpowers:brainstorming              # explore problem space, alternatives, edge cases
/pm:prd-new {name}                      # create PRD with Gherkin acceptance criteria
/pm:prd-parse {name}                    # convert PRD to structured epic
```

> **Next →** Phase 1b (if Complex/Program): `/pm:arch-create {name}` — or skip to `/pm:epic-decompose {name}`

### Phase 1b: Architecture + DDD Tactical Design (Complex/Program flow)

```
/pm:arch-create {name}                 # collaborative architecture decisions + ADRs
```

Produces: `.claude/epics/{name}/architecture.md`, ADRs in `docs/adr/`
Leverages Acme agents: ddd-expert, api-designer, database-migration-expert if available.
Skip for Quick flow. Optional for Standard flow. Required for Complex/Program.

**IMPORTANT:** `arch-create` MUST run BEFORE `epic-decompose` so that tasks can reference architecture decisions (`architecture.md §X.Y`) in their Dev Notes.

**DDD Tactical Design Pipeline (within Phase 1b):**

For Platform bounded contexts, Phase 1b includes the full DDD tactical design sequence.
Required phases vary by BC type (see `/rules/readiness-gate.md` Rule 6).
Full DDD practices reference: `/rules/ddd-practices.md`.

```
Phase A:   Event Modeling                  # command → event flows + payload schemas
Phase A.1: Context Map                     # BC relationships with named patterns (first epic per milestone)
Phase A.2: Bounded Context Canvas          # one-page BC summary (Core + Supporting BCs)
Phase B:   Design-Level Event Storming     # actors, policies, hotspots (Core BCs only)
Phase C:   Aggregate Design + Invariants   # aggregate boundaries, consistency rules
Phase C.1: Repository Contracts            # domain-layer interfaces per aggregate root
```

**One-time decisions (first arch-create of program):**
- Domain Event Infrastructure pattern (Practice 4) — how events are published/subscribed
- ACL Strategy (Practice 2) — how new modules access legacy data during migration
- Domain Logic Placement guidelines (Practice 3) — entity vs domain service vs app service

Produces: artifacts in `docs/platform/context-mapping/{event-models,event-storming,aggregates,use-cases,canvases,example-maps}/`
Also: `docs/platform/context-mapping/context-map.md`, `event-catalog.md`, `acl-registry.md`

Phase D.0 (Example Mapping) runs between Phase A and Phase D for Core + Supporting BCs.
Phase D (BDD Scenarios) aligns with Phase 2 (Test Scaffolding) below.
Phase E (Use Case Mapping) bridges architecture to implementation.
Phase F (Implementation) is Phase 4.

> **Next →** Phase 1c: `/pm:epic-decompose {name}` — break epic into tasks (now WITH architecture references)

### Phase 1c: Epic Decomposition

```
/pm:epic-decompose {name}               # break into tasks (tests-first ordering)
```

Tasks are created AFTER architecture so they can:
- Reference `architecture.md §X.Y` in Dev Notes
- Align file patterns with architecture §4 (Project Structure)
- Include DDD layer assignments (domain/application/infrastructure)
- Cross-reference aggregate design from §6

For Quick flow (no architecture), `epic-decompose` runs directly after `prd-parse`.

> **Next →** Phase 2: `/pm:tests-generate {name}`

### Phase 2: Test Scaffolding (RED)

```
/qodo-skills:qodo-get-relevant-rules    # load coding standards for test patterns
/superpowers:test-driven-development     # enforce TDD discipline
/pm:tests-generate {name}               # generate failing tests from Gherkin scenarios
```

Generates: `.feature` files, Playwright E2E stubs, integration stubs, unit stubs — all intentionally failing.

> **Next →** Phase 2b (if Complex/Program): `/pm:readiness-check {name}` — or Phase 3: `/pm:epic-sync {name}`

### Phase 2b: Readiness Gate (Complex/Program flow)

```
/pm:readiness-check {name}            # FR coverage, quality validation, architecture cohesion
```

Produces: `.claude/epics/{name}/readiness-report.md`
Blocks sync if NOT READY (user can override).

> **Next →** Phase 3: `/pm:epic-sync {name}`

### Phase 3: Sync & Workspace

```
/pm:epic-sync {name}                    # push issues to GitHub, create worktree
```

**Acme-worktree integration:** epic-sync creates a bare worktree without env setup. Replace it:

```bash
# Remove the bare worktree that epic-sync created
git worktree remove ../epic-{name} 2>/dev/null
git branch -D epic/{name} 2>/dev/null

# Create Acme-aware worktree with env isolation
acme-worktree create {name} epic/{name}
acme-worktree open {name}
```

This gives you: unique ports, configured env files, `.claude/` symlink, instance registration.

> **Next →** Phase 4: `acme-worktree open {name}` then `/pm:issue-start {number}` — begin implementation

### Phase 4: Implementation (per issue)

```
/qodo-skills:qodo-get-relevant-rules    # load coding standards for this scope
/pm:issue-analyze {number}              # identify parallel work streams
/pm:issue-start {number}                # launch agents: red → green → refactor per stream
```

Always-on during implementation (no manual invocation needed):
- **semgrep** — scans every Write/Edit for security vulnerabilities
- **auto-format.sh** — runs Prettier after every file edit
- **pre-commit-checks.sh** — typecheck + affected tests before every `git commit` (5 min timeout)
- **protect-sensitive-files.sh** — blocks writes to `.env`, credentials, `terraform.tfstate`
- **block-dangerous-commands.sh** — prevents `rm -rf`, `git push --force`, etc.
- **enforce-nx-commands.sh** — requires `nx run`, blocks bare `jest`/`tsc`/`eslint`
- **validate-infra-files.sh** — validates `.tf` and `.github/` YAML after edits

> **Next →** Phase 5: `/superpowers:verification-before-completion` — verify before closing each issue

### Phase 5: Issue Completion

```
/superpowers:verification-before-completion   # evidence-based self-check (run tests, read output)
/superpowers:requesting-code-review           # dispatch automated code review agent
/pm:issue-close {number}                      # mark done, close on GitHub
```

> **Next →** If more issues remain: repeat Phase 4-5. If all issues done → Phase 6: `/pr-review-toolkit:review-pr all`

### Phase 6: Epic Review

```
/pr-review-toolkit:review-pr all        # 6 specialized review agents:
                                        #   code-reviewer, code-simplifier, comment-analyzer,
                                        #   pr-test-analyzer, silent-failure-hunter, type-design-analyzer
/pm:epic-review {name}                  # lint + typecheck + quality scan + code-analyzer agent
```

Individual review aspects can be run separately:
```
/pr-review-toolkit:review-pr tests      # test coverage gaps
/pr-review-toolkit:review-pr errors     # silent failures, bad error handling
/pr-review-toolkit:review-pr types      # type design, encapsulation, invariants
/pr-review-toolkit:review-pr comments   # comment accuracy, stale docs
/pr-review-toolkit:review-pr code       # bugs, conventions, quality
/pr-review-toolkit:review-pr simplify   # unnecessary complexity, DRY violations
```

> **Next →** Phase 7: `/superpowers:finishing-a-development-branch` then `/pm:epic-merge {name}`

### Phase 7: Merge

```
/superpowers:finishing-a-development-branch   # pre-merge checklist
/pm:epic-merge {name}                        # PR creation, CI gates, merge
/code-review:code-review                     # 5 parallel agents + Haiku scoring → posts to GitHub PR
/qodo-skills:qodo-pr-resolver               # resolve any Qodo review findings
```

**Acme-worktree cleanup:** After epic-merge, the CCPM cleanup targets the wrong path. Run manually:

```bash
acme-worktree remove {name}
# → kills tmux session, unregisters instance, frees ports, removes worktree
```

> **Next →** Phase 8: `/pm:prod-verify {name}` — verify in production before closing

### Phase 8: Production

```
/pm:prod-verify {name}                  # execute production verification runbook
/pm:epic-close {name}                   # mark epic complete, close GitHub issues
```

> **Next →** Phase 9: `acme-worktree remove {name}` — cleanup, then start next feature

## Always-On Quality Layers

Two sources: Acme project hooks (in `settings.json`) and plugin hooks (semgrep, hookify).

### Acme Project Hooks

Active in any Acme worktree (defined in `.claude/settings.json`):

| Hook | Trigger | What It Does | Timeout |
|---|---|---|---|
| block-dangerous-commands.sh | PreToolUse[Bash] | Blocks `rm -rf`, `--force`, destructive ops | 5s |
| enforce-nx-commands.sh | PreToolUse[Bash] | Requires `nx run`, blocks bare `jest`/`tsc` | 5s |
| pre-commit-checks.sh | PreToolUse[Bash] | Typecheck + affected tests before `git commit` | 300s |
| protect-sensitive-files.sh | PreToolUse[Write\|Edit] | Blocks writes to `.env`, credentials | 5s |
| auto-format.sh | PostToolUse[Write\|Edit] | Runs Prettier after every file edit | 30s |
| validate-infra-files.sh | PostToolUse[Write\|Edit] | Validates `.tf` and `.github/` YAML | 15s |
| validate-security.sh | PostToolUse[Write\|Edit] | ESLint security rules on Platform `.ts` files | 30s |
| enforce-nestjs-patterns.sh | PostToolUse[Write\|Edit] | Blocks legacy imports, process.env, console.log in Platform | 15s |
| validate-event-contracts.sh | PostToolUse[Write\|Edit] | Checks event version, tenantId, past-tense naming | 15s |
| validate-helm-charts.sh | PostToolUse[Write\|Edit] | Helm lint, resource limits, probe checks on chart files | 15s |
| validate-k8s-manifests.sh | PostToolUse[Write\|Edit] | K8s YAML validation, no plaintext secrets, no `latest` tag | 15s |
| quality-gate-tests.sh | Stop | Runs affected typecheck + tests when Claude stops | 180s |

### Plugin Hooks

Active globally when plugin is installed:

| Plugin | Hook | Trigger | What It Does |
|---|---|---|---|
| semgrep | PostToolUse | Write\|Edit | Security scan (`semgrep mcp -k post-tool-cli-scan`) |
| semgrep | SessionStart | startup | Inject secure coding defaults |
| semgrep | UserPromptSubmit | * | Reinforce secure defaults on every prompt |
| hookify | Various | Configurable | Custom rule-based prevention per `~/.claude/hookify.*.local.md` |

### Combined Quality Gate on Commit

When `git commit` runs, these fire in sequence:
1. **pre-commit-checks.sh** — typecheck + affected tests (5 min timeout, blocks commit on failure)
2. **quality-gate-tests.sh** — runs affected tests when Claude stops after completing work (3 min timeout)

## Quality Tool Reference

| Tool | Invocation | When to Use | What It Provides |
|---|---|---|---|
| superpowers:brainstorming | `/superpowers:brainstorming` | Before PRD creation | Explore requirements, alternatives, edge cases |
| superpowers:test-driven-development | `/superpowers:test-driven-development` | Before implementation | Interactive TDD enforcement (red-green-refactor) |
| superpowers:verification-before-completion | `/superpowers:verification-before-completion` | Before closing issues | Evidence-based self-check: run tests, read output |
| superpowers:requesting-code-review | `/superpowers:requesting-code-review` | After implementation | Dispatch code-reviewer agent with precise context |
| superpowers:subagent-driven-development | `/superpowers:subagent-driven-development` | Complex implementation | Fresh subagent per task + two-stage review (spec + quality) |
| superpowers:systematic-debugging | `/superpowers:systematic-debugging` | Bug investigation | 4-phase: root cause → pattern → hypothesis → fix |
| superpowers:finishing-a-development-branch | `/superpowers:finishing-a-development-branch` | Before merge | Pre-merge quality checklist |
| pr-review-toolkit:review-pr | `/pr-review-toolkit:review-pr all` | Epic review | 6 specialized agents (code, tests, errors, types, comments, simplify) |
| code-review:code-review | `/code-review:code-review` | After PR creation | 5 parallel agents + Haiku scoring → posts to GitHub PR |
| feature-dev:feature-dev | `/feature-dev:feature-dev {desc}` | Complex features | 7-phase guided dev: discovery → explore → clarify → architect → implement → review → summary |
| qodo-skills:qodo-get-relevant-rules | `/qodo-skills:qodo-get-relevant-rules` | Before coding tasks | Load project-specific coding standards from Qodo |
| qodo-skills:qodo-get-rules | `/qodo-skills:qodo-get-rules` | Session start | Load all org/repo coding rules from Qodo |
| qodo-skills:qodo-pr-resolver | `/qodo-skills:qodo-pr-resolver` | After PR review | Resolve Qodo review findings interactively or in batch |
| arch-create | `/pm:arch-create` | After prd-parse (Complex/Program) | Architecture decisions, ADRs, implementation patterns |
| readiness-check | `/pm:readiness-check` | After tests-generate (Complex/Program) | FR coverage matrix, quality validation, readiness verdict |
| project-context | `/pm:project-context` | Before first issue-start | Project-specific implementation rules, migration state |
| milestone-init | `/pm:milestone-init` | Start of multi-milestone program | Program structure, milestone tracking, master architecture stub |
| adversarial-reviewer | (via epic-review Layer 1) | During review | Blind diff-only review, minimum 10 findings |
| edge-case-hunter | (via epic-review Layer 2) | During review | Mechanical edge case analysis with JSON output |
| nestjs-expert | (agent) | NestJS code review | Module structure, DI, guards, pipes, exception handling |
| mikroorm-expert | (agent) | MikroORM code review | Entity design, UoW, tenant isolation, repository contracts |
| event-driven-expert | (agent) | Event architecture review | Outbox, exchanges, DLX, idempotent consumers |
| kubernetes-expert | (agent) | K8s/Helm review | Charts, probes, resource limits, ArgoCD, ESO |
| redis-expert | (agent) | Redis review | Cache strategy, TTL, invalidation, anti-patterns |
| observability-expert | (agent) | Observability review | OTel, logging, traces, metrics, health endpoints |

## Scale-Adaptive Routing

After `/pm:epic-decompose`, the system suggests the appropriate workflow complexity:

| Flow | Trigger | Skip | Add |
|------|---------|------|-----|
| Quick | 1-3 tasks, 1 domain | brainstorming, arch, readiness | — |
| Standard | 4-7 tasks, 1 domain | — | — |
| Complex | 8+ tasks OR multi-domain | — | arch-create, readiness-check |
| Program | multi-milestone | — | milestone-init, master-arch, cross-epic deps |

See `/rules/scale-routing.md` for full routing criteria.

## Multi-Milestone Programs

For projects spanning months with multiple milestones (e.g., Platform):
- `/pm:milestone-init` creates program structure with milestone tracking
- `master-architecture.md` captures shared decisions across all epics
- `project-context.md` tracks migration state (which modules migrated)
- Cross-epic readiness validation prevents implementing against unstable dependencies

See `/rules/milestone-operations.md` and `/rules/platform-workflow-guide.md` for details.

## Cross-References

- Test conventions: `/rules/test-first-development.md`
- Test execution: `/rules/test-execution.md`
- Agent coordination: `/rules/agent-coordination.md`
- Branch operations: `/rules/branch-operations.md`
- Worktree operations: `/rules/worktree-operations.md`
- GitHub operations: `/rules/github-operations.md`
- Architecture operations: `/rules/architecture-operations.md`
- Readiness gate: `/rules/readiness-gate.md`
- Review triage: `/rules/review-triage.md`
- Scale routing: `/rules/scale-routing.md`
- Milestone operations: `/rules/milestone-operations.md`
- Platform workflow guide: `/rules/platform-workflow-guide.md`
- DDD practices: `/rules/ddd-practices.md`
