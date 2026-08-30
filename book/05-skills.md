# 5 · Skills — how work is done here

> Part II — The Layers · [← Context](04-context.md) · [Contents](README.md) · [Next: Agents →](06-agents.md)

---

## The problem skills solve

Context (chapter 4) tells the agent what is true. It does not tell the agent what to
*do* when the user says "fix this bug" — and left to improvise, a capable model will
produce a *different* competent procedure every time. One session reproduces the bug
first; the next dives straight into a fix; a third refactors en route. All defensible,
none repeatable, and repeatability is what turns an assistant into infrastructure.

A **skill** is a written procedure for one kind of task, in this codebase, loaded when
that kind of task appears. The operative word is *procedure*: the best skills here read
like a checklist a senior engineer would hand a new team member, not like prose about
values. There are 71 of them in
[`project/.claude/skills/`](../project/.claude/skills/), plus 53 machine-level commands
in [`global/commands/`](../global/commands/) — the PM ceremony among them, which gets
its own chapter ([10](10-the-ceremony.md)).

## Anatomy of a skill

Every skill is a directory with a `SKILL.md`, whose frontmatter does more work than it
appears to. Here is [`bug-fix`](../project/.claude/skills/bug-fix/SKILL.md)'s, in full:

```yaml
---
name: bug-fix
description: "Investigate, reproduce, fix, and test bugs in the Acme codebase.
  Use when the user reports a bug, error, or unexpected behavior that needs
  fixing. Do not use for performance issues (use performance) or infrastructure
  problems (use dev-troubleshoot)."
model: sonnet
---
```

Three design choices worth stealing:

- **The description is a routing contract, not a summary.** It states when to use the
  skill *and when not to, naming the alternative*. With 71 skills, mis-routing is the
  dominant failure mode, and every "do not use for X (use Y)" clause is a fence between
  two skills that were once confused.
- **`model: sonnet`** — a mechanical bug-fix workflow doesn't need the most expensive
  model. Cost discipline is set per-procedure, where the procedure's difficulty is
  known, not per-session.
- Parameterized skills add an `args` line and `disable-model-invocation: true` — they
  are tools to be called deliberately (`/implement-domain-event deal-confirmed`), not
  patterns to be auto-matched.

Bodies are stepwise and imperative. Skills that need supporting material carry a
`references/` directory ([`triage`](../project/.claude/skills/triage/) ships its
autonomy policy; [`design-review`](../project/.claude/skills/design-review/) its
checklists) and sometimes `scripts/` or `assets/` — a skill is allowed to be a small
software package, not just a prompt.

## A taxonomy of 71

The catalogue is best understood as five families:

**Lifecycle skills** map to the moments of a working day: `bug-fix`, `new-feature`,
`api-change`, `frontend-change`, `db-migration`, `refactor`, `hotfix`, `pr-create`,
`commit`, `deploy`, `incident`. These are the auto-invoked workhorses.

**Generator skills** (`implement-*`, 12 of them) scaffold this platform's specific
patterns: [`implement-domain-event`](../project/.claude/skills/implement-domain-event/SKILL.md)
produces the *whole* pattern — event contract, aggregate method, outbox entry,
publisher, consumer, dead-letter handler, idempotency guard, and tests — because on
this platform an event without its idempotency guard is a bug half-shipped.
`implement-nestjs-module`, `implement-helm-chart`, `implement-endpoint` and the three
`implement-*-tests` skills do the same for their patterns. This family is the strongest
argument that skills beat prose context: a convention *enforced by generation* never
drifts.

**Autonomous-loop skills**: the two loop-engineering skills from
[chapter 2](02-loops-not-prompts.md) —
[`triage`](../project/.claude/skills/triage/SKILL.md) and
[`verify-loop`](../project/.claude/skills/verify-loop/SKILL.md) — plus five `ralph-*`
skills (`ralph-fix-tests`, `ralph-implement-spec`, `ralph-debug`, `ralph-refactor`,
`ralph-green-build`) implementing the [Ralph Wiggum
technique](https://ghuntley.com/ralph/): the same prompt fed repeatedly, each iteration
building on state visible in files and git history, with a hard iteration cap (15–50
depending on the skill).

**Guardrail skills** encode discipline rather than tasks:
[`verification-before-completion`](../project/.claude/skills/verification-before-completion/SKILL.md)
(*"Your eyes are not a test suite. Show concrete evidence"*),
[`systematic-debugging`](../project/.claude/skills/systematic-debugging/SKILL.md),
[`test-driven-development`](../project/.claude/skills/test-driven-development/SKILL.md),
[`source-driven-dev`](../project/.claude/skills/source-driven-dev/SKILL.md). Several
extend plugin-provided base skills with project specifics — extension, not duplication.

**Operations skills** wrap the platform's sharp edges: `k8s-troubleshoot`,
`cicd-troubleshoot`, `dev-instance`, `production-access`, `launch-readiness`,
`erp-issue`, `sonar-scan`, `env-status`.

And one meta-skill closes the loop between layers:
[`session-learnings`](../project/.claude/skills/session-learnings/SKILL.md) scans a
session for gotchas worth preserving and writes them to the memory tree — the bridge
from layer 2 to layer 6, run at the end of a working day. Its own instruction is the
right one: *"Be highly selective — only document what prevents future mistakes or saves
real time."*

## When does a procedure become a skill?

The rule of thumb, from [Appendix A](appendix-a-install.md):

> The third time you explain the same procedure, it becomes a skill.

The first time is a conversation. The second time might be coincidence. The third time
is a pattern, and every future explanation is a tax that a `SKILL.md` pays off. The
corollary matters just as much: **don't port these 71** — most encode conventions that
are not yours. A skill library is grown, not installed.

## Precedence: when skill worlds collide

This setup runs its own skills alongside two third-party skill collections
(agent-skills and superpowers — see [Appendix B](appendix-b-attribution-and-lineage.md)), which
means overlapping claims on the same task. The root
[`project/CLAUDE.md`](../project/CLAUDE.md) settles it with an explicit precedence
order:

> 1. **PM commands (`/pm:*`)** — project tracking, GitHub sync, status. Always the backbone.
> 2. **Agent-skills** — engineering process (build, test, review, debug).
> 3. **Custom skills** — only for project-specific logic (deploy, hotfix, db-migration…).
> 4. **Superpowers** — meta-workflows only. NEVER for TDD, debugging, or code review.

Unremarkable-looking, but it removes a whole class of nondeterminism: without a written
order, *which* debugging methodology loads depends on phrasing luck. With one, the
answer is a lookup. If you adopt more than one skill source, write this paragraph on
day one.

## The machine-level commands

[`global/commands/`](../global/commands/) carries what should exist on every project:
the 45 PM ceremony commands under [`pm/`](../global/commands/pm/) (chapter 10; lineage
in [Appendix B](appendix-b-attribution-and-lineage.md)), three
[`context/`](../global/commands/context/) commands that create, prime and update a
project's context files, two [`testing/`](../global/commands/testing/) commands, and a
[`code-rabbit.md`](../global/commands/code-rabbit.md) for driving an external review
bot's findings to resolution.

## Primary sources

- [`project/.claude/skills/`](../project/.claude/skills/) — all 71, each a directory with `SKILL.md`
- [`triage`](../project/.claude/skills/triage/SKILL.md) and [`verify-loop`](../project/.claude/skills/verify-loop/SKILL.md) — the two loops, worth reading end to end
- [`implement-domain-event`](../project/.claude/skills/implement-domain-event/SKILL.md) — the generator family's best specimen
- [`global/commands/`](../global/commands/) — the machine-level 53
- [`project/.claude/README.md`](../project/.claude/README.md) — the original in-repo quick-reference ("I want to… → skill")

---

> **Next:** procedures need executors — and graders. The agent fleet: fifteen domain
> experts, a review panel, and the one agent that is deliberately kept ignorant.
> [Chapter 6 — Agents: who does it, and who checks it →](06-agents.md)
