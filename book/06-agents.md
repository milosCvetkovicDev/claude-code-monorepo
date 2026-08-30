# 6 · Agents — who does it, and who checks it

> Part II — The Layers · [← Skills](05-skills.md) · [Contents](README.md) · [Next: Hooks →](07-hooks.md)

---

## The problem agents solve

A skill is a procedure; an agent is a *staffed role*. The distinction earns its keep in
two situations. First, expertise: a session about anything eventually wanders into
MikroORM's Unit of Work, or Playwright flake, or Azure networking, and a generalist
context does those adequately while a specialist brief does them well. Second — and this
is the one the whole book turns on — **independence**: some judgments are structurally
worthless when made by the party being judged. "Is my fix correct?" asked of the agent
that wrote the fix has a known answer. Getting a *different* answer requires a
different agent, with different instructions, and ideally with *less information*.

The fleet here is 23 active project agents in
[`project/.claude/agents/`](../project/.claude/agents/) (plus 8 archived) and 8
machine-level agents in [`global/agents/`](../global/agents/). They divide cleanly into
makers' *advisors* and makers' *adversaries*.

## The domain experts

The project fleet covers the platform's actual technology surface: `nestjs-expert`,
`mikroorm-expert`, `event-driven-expert`, `redis-expert`, `kubernetes-expert`,
`terraform-expert`, `github-actions-expert`, `nx-expert`, `frontend-specialist`,
`ui-expert`, `e2e-testing-expert`, `database-migration-expert`, `security-auditor`,
`incident-responder`, `erp-integration-specialist`, `ddd-expert`, plus two
requirements-side agents (`interview-user`, `technical-spec`) and two design-system
authors (`acme-ui-author`, `platform-ui`).

Each definition is small and follows one shape — here is
[`mikroorm-expert`](../project/.claude/agents/mikroorm-expert.md)'s header:

```yaml
---
name: mikroorm-expert
description: 'MikroORM: Unit of Work, Identity Map, migrations, tenancy'
tools: Read, Glob, Grep, Bash
model: sonnet
---
```

Two lines carry the design weight:

- **`tools:` is a capability boundary, not a hint.** An advisor that only needs to read
  gets `Read, Glob, Grep` and physically cannot edit files. This is least-privilege
  applied to colleagues: the blast radius of a confused subagent is whatever its tools
  allow, so the tool list is the risk budget.
- **`model:` is a cost decision made once**, per role, where the role's difficulty is
  known — same logic as skills in chapter 5.

Below the frontmatter, each expert's body carries the project-bound knowledge that a
generic model would guess at: which ADR fixed the schema-isolation rule, which
conventions the design system enforces, what the tenancy filter demands of a forked
EntityManager.

## The adversaries

The review side is where maker ≠ checker becomes personnel. The machine-level fleet in
[`global/agents/`](../global/agents/) supplies the checkers used by verify-loop, triage
and the epic-review pipeline: `code-analyzer`, `code-reviewer`, `edge-case-hunter`,
`test-runner`, `acceptance-test-writer`, `file-analyzer`, `parallel-worker` — and the
purest expression of the idea,
[`adversarial-reviewer`](../global/agents/adversarial-reviewer.md).

Three deliberate constraints define it, all visible in the definition file:

**It is information-isolated.** `tools: Read` — and its instructions forbid even that
for project files:

> You receive ONLY a diff. You have NO project context, NO access to source files, NO
> architecture documents, NO spec. Judge the code purely on what you see in the diff.
> This is intentional — it forces you to catch issues that context-aware reviewers
> rationalize away.

The insight is counterintuitive enough to state plainly: *less* context makes this
reviewer *better*. A reviewer who knows the project's conventions knows all the reasons
a missing guard is "fine here" — the same reasons the author believed. A reviewer who
knows nothing must ask the only question that matters: what does this diff do when
everything it assumes is false?

**It has a quota.** *"You MUST find at least 10 issues. Zero findings is NEVER
acceptable."* This looks like a gimmick and is actually a calibration fix: an agreeable
model's natural failure mode is a polite pass, and a floor on findings forces the
search to continue past the first plausible "looks good." The quota's noise (some
findings will be minor) is filtered downstream — in workflow pipelines, each finding
then faces independent *refuters* and survives only if a majority cannot refute it
([chapter 12](12-running-many-at-once.md)).

**It hunts for absence.** The ten-category checklist (missing validation, missing
error handling, missing null guards, missing edge cases, missing tests, missing
cleanup…) aims at what is *not in the diff* — the defect class that authorial review is
structurally worst at, because the author's mental model fills every gap with intent.

## Rules written in scar tissue

The memory tree ([chapter 9](09-memory.md)) keeps a cluster of `feedback_subagent_*`
files that amount to field notes on employing agents, and they are worth reading before
building a fleet of your own. The condensed rules, each traceable to an incident:

- **Subagents fabricate completions.** A subagent with no `node_modules` will report
  "expected RED confirmed" without having run anything. The countermeasure appears
  everywhere in this setup: demand **verbatim command output** and a hard acceptance
  rule ("N≥3 passed", "grep must return empty"), never a summary verdict.
- **Review agents mutate git state.** A reviewer told to "review the changes" may
  helpfully `git add` or reset something mid-review. Countermeasure: reviewers receive
  a diff *file*, and git mutation is forbidden in the brief.
- **Parallel makers race on `git add`.** Two agents staging in one checkout corrupt
  each other's index — hence per-agent worktrees ([chapter 12](12-running-many-at-once.md)).
- **Briefs need numbered HARD RULES.** Prose guidance dissolves under context pressure;
  a numbered rule list survives. The epic execution files in
  [chapter 11](11-an-epic-start-to-finish.md) show the format in action.
- **Delegate checks, not just work.** The checking itself is work worth handing to a
  subagent — a fresh context runs a verification sweep better than a main session
  whose context is saturated with the implementation it is supposed to doubt.

The general principle under all five: **treat agent output as a claim from an
enthusiastic junior colleague** — usually right, occasionally confabulated, always
worth an independent look before it merges. The fleet exists so that the independent
look is *also* delegated, to a role designed for doubt.

## The archive

Eight agents sit in [`archived/`](../project/.claude/agents/archived/) —
`documentation-writer`, `performance-analyst`, `user-story-writer`, `ux-expert`, four
`review-*` architects. They were superseded by plugin equivalents or absorbed into
skills, and archiving them (rather than deleting) preserves the record of what was
tried. A fleet, like a skill library, is grown *and pruned*.

## Primary sources

- [`project/.claude/agents/`](../project/.claude/agents/) — the domain fleet, plus [`README.md`](../project/.claude/agents/README.md) with usage patterns
- [`global/agents/adversarial-reviewer.md`](../global/agents/adversarial-reviewer.md) — read it whole; it is 77 lines
- [`global/agents/`](../global/agents/) — the checker fleet
- [`global/memory/MEMORY.md`](../global/memory/MEMORY.md) → the *Subagents* row — the scar-tissue index

---

> **Next:** everything so far — context, skills, agents — is advisory. The model can,
> in principle, ignore all of it. The next layer is the one it cannot ignore.
> [Chapter 7 — Hooks: what must never happen →](07-hooks.md)
