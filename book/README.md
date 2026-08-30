# The Book

**A guided reading of this repository, high level to low level — how one engineer and a
fleet of agents shipped a 13-service platform, and the configuration that made it
possible.**

Each chapter opens with a concept, descends into how *this* setup implements it — with
excerpts from the real files, not paraphrase — and ends at the primary sources, so you
are never more than one link from the actual skill, hook, agent or memory it describes.
Read it cover to cover (~1–2 hours), or jump in anywhere; every chapter stands alone.

---

## Part I — The Idea

| Ch. | Chapter                                                                  | What it covers                                                              |
| --- | ------------------------------------------------------------------------ | --------------------------------------------------------------------------- |
| 1   | [One engineer, thirteen services](01-one-engineer-thirteen-services.md)  | Why the numbers force a different job — and what this repository actually is |
| 2   | [Loops, not prompts](02-loops-not-prompts.md)                            | The thesis: six primitives, two loops, the autonomy posture, the four risks  |
| 3   | [The six layers](03-the-six-layers.md)                                   | The mental model — one bug fix traced through all six layers, and the repo map |

## Part II — The Layers

| Ch. | Chapter                                     | The question it answers                            |
| --- | ------------------------------------------- | -------------------------------------------------- |
| 4   | [Context](04-context.md)                    | What must it always know?                          |
| 5   | [Skills](05-skills.md)                      | How is this kind of task done *here*?              |
| 6   | [Agents](06-agents.md)                      | Who does it — and who checks it?                   |
| 7   | [Hooks](07-hooks.md)                        | What must never happen, whatever the model thinks? |
| 8   | [Connectors](08-connectors.md)              | What real systems can it touch?                    |
| 9   | [Memory](09-memory.md)                      | What survives the session ending?                  |

## Part III — In Motion

| Ch. | Chapter                                                        | What it covers                                                                  |
| --- | -------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| 10  | [The ceremony](10-the-ceremony.md)                             | The 13-step PM workflow, and where the loops thread through it                   |
| 11  | [An epic, start to finish](11-an-epic-start-to-finish.md)      | Epic #1623 through every step — including the day the tests themselves were wrong |
| 12  | [Running many at once](12-running-many-at-once.md)             | Multi-agent fan-out, and one integer per parallel workspace                      |

## Part IV — What It Built

| Ch. | Chapter                                                  | What it covers                                                        |
| --- | -------------------------------------------------------- | --------------------------------------------------------------------- |
| 13  | [The system it built](13-the-system-it-built.md)         | The platform itself — a bridge into the 40-document architecture volume |

## Appendices

- [**A · Installing this setup**](appendix-a-install.md) — what goes where, in
  dependency order, and what to edit before use
- [**B · Attribution and lineage**](appendix-b-attribution-and-lineage.md) — what is
  borrowed, what is original, what merely influenced
- [**The sanitization story**](../SANITIZATION.md) — six adversarial audit rounds that
  made a real export publishable; this book's de-facto chapter on operational security

## Deep-dives

Reference material narrated by [chapter 12](12-running-many-at-once.md), kept whole
because it is meant to be *used*, not just read:

- [`deep-dives/ultracode-workflows.md`](deep-dives/ultracode-workflows.md) — workflow
  patterns, complete script skeletons, guardrails
- [`deep-dives/worktree-workspace-allocation.md`](deep-dives/worktree-workspace-allocation.md)
  — twelve principles for collision-free parallel workspaces

---

*In a hurry?* [Chapter 2](02-loops-not-prompts.md) +
[chapter 11](11-an-epic-start-to-finish.md) is the twenty-minute version: the idea,
and the idea surviving contact with reality.
