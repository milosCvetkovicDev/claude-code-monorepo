# Scale-Adaptive Routing

Determine the appropriate workflow complexity based on project scope. Routing is SUGGESTED, never enforced — the user can always override.

## Complexity Assessment

After `/pm:epic-decompose` creates tasks, assess:

| Factor | Quick | Standard | Complex | Program |
|--------|-------|----------|---------|---------|
| Task count | 1-3 | 4-7 | 8+ | Any |
| Domain count | 1 | 1 | 2+ | 2+ |
| External deps | 0 | 0-1 | 2+ | Any |
| Milestone | No | No | No | Yes |
| Duration | Hours-days | Days-weeks | Weeks | Months |

**Domain detection**: Count distinct domains from task file patterns:
- Backend-only: API, services, repositories, migrations
- Frontend-only: components, hooks, pages, styles
- Infrastructure-only: Terraform, CI/CD, deployment
- Multi-domain: 2+ of above

## Flow Definitions

### Quick Flow (1-3 tasks, single domain)
Skip brainstorming, architecture, readiness check.

```
prd-new → prd-parse → epic-decompose → tests-generate → epic-sync → implement → review → merge
```

### Standard Flow (4-7 tasks, single domain)
Current Maximum Confidence workflow. Architecture and readiness optional.

```
brainstorming → prd-new → prd-parse → epic-decompose → tests-generate → epic-sync → implement → review → merge
```

### Complex Flow (8+ tasks OR multi-domain)
Full workflow with architecture and readiness gate required.

```
brainstorming → prd-new → prd-parse → arch-create → epic-decompose → tests-generate → readiness-check → epic-sync → implement → review → merge
```

### Program Flow (multi-milestone)
Long-running projects. Adds program-level coordination.

```
milestone-init (once) → then per-milestone: full Complex flow with master architecture inheritance
```

## Automatic Suggestion

After `epic-decompose`:
```
Based on {count} tasks across {domain_count} domain(s):
Recommended: {Quick|Standard|Complex|Program}
Override? Type the flow name or press Enter for recommended.
```

## Detection Triggers

| Context Clue | Flow |
|-------------|------|
| 1-3 tasks | Quick |
| 4-7 tasks, one app directory | Standard |
| 8+ tasks | Complex |
| Tasks touch both backend and frontend | Complex |
| `.claude/milestones/` exists | Program |
| `docs/strategy/` exists with roadmap | Suggest Program |
| ≤3 tasks but touches Terraform | Standard (infra needs care) |

## Manual Override

User can force any flow regardless of task count. No justification needed.
