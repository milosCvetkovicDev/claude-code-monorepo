---
name: m6-execution-state
description: M6 Production Launch — Wave 1 merged (#499), Wave 2 migration merged (#551/#487). #483 stakeholder review and all downstream items POSTPONED indefinitely.
type: project
originSessionId: 00000000-0000-0000-0000-000000000042
---

M6 epic started 2026-04-16. Epic #481, branch `epic/platform-m6-production-launch`, worktree at `../epic-platform-m6-production-launch`.

## Current State (2026-04-24): Wave 1 + Wave 2 (#487) Merged, remainder POSTPONED

### Wave 1 — Merged via PR #499 (squash 70ffde01, 2026-04-23)
| Issue | Task | Notes |
|-------|------|-------|
| #482 | E2E tests (Playwright) | 30 files, 12 journey tests |
| #489 | Performance tests (k6) | 16 files, 5 k6 scripts, CI workflow |
| #492 | Security hardening | 3 security docs, gap analysis |
| #485 | Monitoring & alerting | 31 files, dashboards, alerts, production overlays |
| #486 | Custom report builder | 15 files, 80+ tests, SQL injection prevention |
| #493 | AI service | 63 files, 145 tests |
| #494 | SUPERADMIN cross-tenant | JWT claims, tenant filter bypass, audit log. Completed in PR #499 after 9-reviewer pass (controllers missing `@Req()`, deactivateUser actor bug, jwt.service platformScope escalation, etc.) |
| #484 | Frontend hardening | Route guards, dashboard grid, widget catalogue |

### Wave 2 — Partial Merge
| Issue | Task | State |
|-------|------|-------|
| #487 | Data migration scripts | **Merged** via PR #551 (squash 59a59776, 2026-04-24). `scripts/migration/` workspace: BaseMigrator + 11 entity migrators (one of them consolidating several legacy tables into a single target entity), verification + reconciliation against a configured tolerance, reverse migration + rollback. 148 tests green, strict TS. Seven parallel streams (T/F/A/B/C/E/D) + consolidation. |
| #483 | Stakeholder review | **POSTPONED indefinitely** (user decision, 2026-04-23 + 2026-04-24). Do NOT launch without explicit go-ahead. |

### Wave 3 — Blocked by #483 postpone
- **#490** Tenant cutover procedures — was blocked on #487 (now unblocked) but depends on Wave 2 sign-off from #483. **Blocked until #483 unpostponed.**
- **#488** UAT and bug fixes — depends on #483. **Blocked.**

### Wave 4 — Blocked
- **#491** Phased tenant cutover — depends on #490, #488. **Blocked.**

## #487 deferred items (tracked for follow-up, not blocking anything)
- Reverse migrators for the remaining entity types — only the Wave 2 minimum set shipped in both directions.
- `DatasetInvariant` API for cross-row invariants (slug uniqueness, sidecar-row presence, orphan detection, parent-has-at-least-one-child).
- Child-entity migrators.
- DB-level integration tests for BaseMigrator (current 148 tests are unit-level).
- A derived-column back-population pass: the lookup helper exists, but the migrators that need it currently write NULL.

## PM Workflow Position

```
prd-new ✅ → prd-parse ✅ → arch-create ✅ → epic-decompose ✅ → tests-generate ✅ →
readiness-check ✅ → epic-sync ✅ → epic-start ✅ →
[Wave 1 ✅ → PR #499 merged] →
[Wave 2: #487 ✅ → PR #551 merged; #483 POSTPONED] →
Wave 3 BLOCKED → Wave 4 BLOCKED → epic-review → epic-merge → prod-verify → epic-close
```

**Why:** The epic cannot close until Waves 3 + 4 land, which depend on #483. Since #483 is indefinitely postponed, the epic branch `epic/platform-m6-production-launch` stays open but dormant. The two merged PRs (#499, #551) already delivered production-ready code to `main`; the remaining work is operational sign-off + cutover rehearsal that requires stakeholder involvement.

**How to apply:** Do NOT launch #483, #488, #490, #491 unless the user explicitly unblocks #483. When that happens, resume from Wave 2 sign-off → Wave 3. Until then treat the M6 epic as frozen.
