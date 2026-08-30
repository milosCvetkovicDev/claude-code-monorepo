# 1 · One engineer, thirteen services

> Part I — The Idea · [Contents](README.md) · [Next: Loops, not prompts →](02-loops-not-prompts.md)

---

## The situation

A multi-tenant commodity-trading platform: an API gateway plus twelve microservices across
nine bounded contexts, a React front end on a 98-component design system, deployed to
Kubernetes by GitOps with canary releases and automatic rollback — running alongside the
Express/TypeORM monolith it is strangling. Roughly 250,000 lines of TypeScript. About 780
merged pull requests. Seven months. Largely one engineer.

Those numbers do not add up under the normal model of software work. One person cannot
review 780 of their own PRs with fresh eyes, hold nine bounded contexts in working memory,
keep a legacy system alive while replacing it, and still ship — not by typing faster, and
not by prompting an AI assistant harder, either. Prompting is still the same job with a
better keyboard: you decide the next step, you check the result, you decide the next step.
The throughput ceiling is *you*, turn by turn.

The only way the numbers add up is to change the job. Stop being the person who prompts
the agent, and become the person who **designs the system that prompts the agent** — a
system that knows the codebase's conventions so agents don't re-derive them, that blocks
the catastrophic commands no matter how confident the model feels, that separates the
agent doing the work from the agent grading it, and that defines "done" as something a
machine can check rather than something a tired human vibes at 11pm.

This repository is that system, exported whole.

## What you are holding

This is not a starter template, and it is not advice. It is the **real, working Claude
Code configuration** the platform above was built with — full skill texts, full hook
scripts, the actual agent fleet, the genuine memory tree with seven months of accumulated
scar tissue, and one complete epic carried from PRD to verified-green, artefact by
artefact. Company, product, people and infrastructure identifiers have been renamed to
consistent fictional ones (`Initech`, `Acme`, `the FD`); the engineering is untouched.
How that sanitization was done — six adversarial rounds, each finding a leak class the
previous round's method could not see — is its own story, told in
[`SANITIZATION.md`](../SANITIZATION.md).

The distinction matters because configuration repos tend to be aspirational: the hooks
someone *thinks* would be nice, the skills someone wrote in an afternoon of enthusiasm.
Everything here earned its place by failing first. The hook that blocks `gh pr merge`
exists because an autonomous loop once needed a merge gate that could not be argued with.
The memory file that says *"subagents fabricate completions — a subagent with no
`node_modules` will report 'expected RED' without running anything"* exists because one
did. The rule that RED tests must be **run**, not just typecheck-verified, was paid for
by a pilot task that found three defects in its own test baseline
([chapter 11](11-an-epic-start-to-finish.md) tells that story in full).

## Two disciplines, stated up front

Everything in this book reduces to two rules. You will meet them in every chapter, so
here they are without ceremony:

**Maker ≠ checker.** The agent that does the work never grades it. A separate agent —
ideally one that cannot even see the project context the maker rationalized with —
confirms. `done` is a claim, not a proof. *"The model that wrote the code is too nice
grading its own homework."*

**Verifiable stop conditions.** Every "is it finished?" must be machine-checkable: a
command that exits 0, a named RED test that turns GREEN, a metric under a bound. Never a
vibe. If you cannot write the condition down as something a machine can evaluate, you
cannot safely leave a loop running against it — and leaving loops running is the entire
point.

Neither idea is original here. The framing comes from Addy Osmani's
[loop engineering](https://addyosmani.com/blog/loop-engineering/) essay, and the
maker/checker split is as old as double-entry bookkeeping. What this repository adds is
the *implementation*: what those two rules look like when they are enforced by hooks,
encoded in skills, staffed by an agent fleet, and threaded through a project-management
ceremony — on a real codebase, under real deadlines, with the failures documented.

## How to read this book

The chapters run high-level to low-level, and each one ends at the real files — you are
never more than one link from the primary source.

- **Part I** (you are here) states the idea: the loops, and the six-layer mental model
  that organizes everything else.
- **Part II** descends through the six layers one at a time — context, skills, agents,
  hooks, connectors, memory — each chapter opening with the concept and closing inside
  the actual configuration.
- **Part III** puts the machine in motion: the PM ceremony, one real epic followed
  start to finish, and the fan-out machinery for running many agents and many
  workstreams at once.
- **Part IV** shows what all of it built, bridging into the architecture volume — 40
  documents and 239 diagrams describing the platform itself.
- **The appendices** cover installing pieces of this on your own machine (deliberately:
  *pieces*, in dependency order, not the whole thing at once) and the full lineage of
  what is borrowed and what is original.

If you have twenty minutes, read [chapter 2](02-loops-not-prompts.md) and
[chapter 11](11-an-epic-start-to-finish.md) — the idea, and the idea surviving contact
with reality. If you came here for a specific artifact — a hooks example, a `CLAUDE.md`
layout, a memory-index format — the [cover page's lookup table](../README.md#if-you-came-here-looking-for)
jumps straight to it.

One caution before you settle in, and it is the same one the install guide opens with:
**nothing here should be adopted wholesale.** A `Stop` hook that runs your affected tests
is excellent on a repo with a two-minute suite and miserable on one without. Most of the
71 skills encode *this* codebase's conventions, not yours. The value of the export is not
that you can copy it — it is that every mechanism comes attached to the failure it
prevents, and the failures transfer even where the fixes don't.

---

> **Next:** the thesis in full — what a loop is, the six primitives that build one, and
> the two loops that ran this project.
> [Chapter 2 — Loops, not prompts →](02-loops-not-prompts.md)
