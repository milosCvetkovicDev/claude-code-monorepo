---
name: POC-gated approach for cross-cutting infra
description: For large cross-cutting infrastructure changes (data tier, multi-tenancy, security model), user requires POC-first with empirical validation gates before any concrete implementation. CI/CD must stay green throughout. Use parallel Claude Code sessions where feasible.
type: feedback
originSessionId: 00000000-0000-0000-0000-000000000015
---
# POC-Gated Approach for Cross-Cutting Infra Changes

**Rule:** When a proposed change spans multiple services / shared libraries / infrastructure layers and has high blast radius, prefer a POC-gated plan over direct implementation. Each "I'm not sure" becomes a POC with binary pass/fail and an ADR amendment recording the outcome.

**Why:** During the 2026-05-08 Platform data-tier redesign session, two architecture boards (11 + 8 expert agents) surfaced 22 issues and 40+ edge cases that direct implementation would have hit in production. The user explicitly directed: "we need to succeed in this. include POCs wherever you are not sure. prove before concrete implementation. CI/CD must be without errors and failures, builds should be smooth too." Original 4-month estimate was off by 2× because it assumed problems we now know exist would not exist.

**How to apply:**
- Before committing to a non-trivial cross-cutting architectural change, draft a spec that lists every uncertainty as a POC with explicit pass/fail criteria.
- Group POCs into dependency waves (Wave 0 foundation → Wave 1 gating → Wave 2 main build → Wave 3 resilience → Wave 4 production-gating).
- Each POC merges only with green CI; ADR amendment in same PR; one POC per PR.
- Document scope-cut triggers (e.g., "if POC B1 fails, drop RLS") so failure routes to scope amendment, not project failure.
- Use multiple parallel Claude Code sessions (one per task category) on isolated worktrees via `acme-worktree create <suffix>`. See `parallel-sessions.md` runbook in any epic that uses this pattern.
- Honest timeline includes the POC phase. Don't compress estimates by skipping POCs.
