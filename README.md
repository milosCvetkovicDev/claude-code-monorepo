# claude-code-monorepo

**Claude Code skills, hooks, subagents, `CLAUDE.md` files, MCP config and memory — the real,
sanitized configuration from seven months of shipping a production TypeScript monorepo.
Organized as a book: read it high-level to low-level, cover to cover.**

[![Read online](https://img.shields.io/badge/read-online-3fb950.svg)](https://miloscvetkovicdev.github.io/claude-code-monorepo/)
[![book-guard](https://github.com/milosCvetkovicDev/claude-code-monorepo/actions/workflows/book-guard.yml/badge.svg)](https://github.com/milosCvetkovicDev/claude-code-monorepo/actions/workflows/book-guard.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude_Code-configuration-d29922.svg)](https://docs.anthropic.com/en/docs/claude-code)
[![Sanitized](https://img.shields.io/badge/sanitized-6_audit_rounds-success.svg)](SANITIZATION.md)

A near-complete reference export of the Claude Code setup used to build and ship a
13-service TypeScript platform — roughly 250k lines, ~780 merged PRs, seven months,
largely as a single engineer. Not a starter template: the **real configuration**, with
full skill texts, full hook scripts, the actual memory tree, and one complete epic
walkthrough. Identifiers are renamed to consistent fictional ones — see
[`SANITIZATION.md`](SANITIZATION.md).

Two disciplines run through everything here:

- **Maker ≠ checker.** The agent that does the work never grades it. A *separate* agent
  confirms. `done` is a claim, not a proof.
- **Verifiable stop conditions.** Every "is it finished?" must be machine-checkable — a
  command that exits 0, a named RED test that turns GREEN. Never a vibe.

---

## 📖 Start here: the book

The guided reading of this repository lives in [**`book/`**](book/README.md) — thirteen
chapters, high level to low level, each descending from concept into the real files.
~1–2 hours cover to cover; every chapter stands alone.

**Prefer a website?** The same two volumes, with search and navigation, are at
**[miloscvetkovicdev.github.io/claude-code-monorepo](https://miloscvetkovicdev.github.io/claude-code-monorepo/)**.

|          | Chapters                                                                                                                                                                                                                                                          |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **I · The Idea**       | [1 One engineer, thirteen services](book/01-one-engineer-thirteen-services.md) · [2 Loops, not prompts](book/02-loops-not-prompts.md) · [3 The six layers](book/03-the-six-layers.md)                                                                |
| **II · The Layers**    | [4 Context](book/04-context.md) · [5 Skills](book/05-skills.md) · [6 Agents](book/06-agents.md) · [7 Hooks](book/07-hooks.md) · [8 Connectors](book/08-connectors.md) · [9 Memory](book/09-memory.md)                                               |
| **III · In Motion**    | [10 The ceremony](book/10-the-ceremony.md) · [11 An epic, start to finish](book/11-an-epic-start-to-finish.md) · [12 Running many at once](book/12-running-many-at-once.md)                                                                          |
| **IV · What It Built** | [13 The system it built](book/13-the-system-it-built.md) → [`docs/architecture/`](docs/architecture/README.md) (40 docs, 239 diagrams)                                                                                                              |
| **Appendices**         | [A Installing this setup](book/appendix-a-install.md) · [B Attribution and lineage](book/appendix-b-attribution-and-lineage.md) · [The sanitization story](SANITIZATION.md)                                                                          |

*In a hurry?* [Chapter 2](book/02-loops-not-prompts.md) +
[chapter 11](book/11-an-epic-start-to-finish.md) — the idea, and the idea surviving
contact with reality.

---

## The six layers

The mental model the book is organized around ([chapter 3](book/03-the-six-layers.md)):

| Layer          | Question it answers                                | Where                                                                     |
| -------------- | -------------------------------------------------- | ------------------------------------------------------------------------- |
| **Context**    | What must it always know?                          | `project/**/CLAUDE.md` (19 files), `global/rules/`, `global/references/`  |
| **Skills**     | How is this kind of task done here?                | `project/.claude/skills/` (71), `global/commands/` (53)                   |
| **Agents**     | Who does it — and who checks it?                   | `project/.claude/agents/` (23), `global/agents/` (8)                      |
| **Hooks**      | What must never happen, whatever the model thinks? | `project/.claude/hooks/` (34 scripts, 28 wired across 8 lifecycle events) |
| **Connectors** | What real systems can it touch?                    | `project/.mcp.json`, plugin config in `settings.json`                     |
| **State**      | What survives the session ending?                  | `global/memory/` (172 files), `examples/epic-walkthrough/`                |

## Layout

```
book/             ← the guided reading: 13 chapters + appendices + deep-dives
project/          repo-scoped config, frozen at its original monorepo paths
  .claude/        skills (71) · agents (23) · hooks (34) · commands · settings.json
  **/CLAUDE.md    19 nested instruction files
  .mcp.json       MCP servers (incl. a custom in-repo server)
global/           machine-scoped config (~/.claude equivalent)
  rules/ references/ commands/pm/ agents/ memory/ (172 files) settings.json
docs/architecture/  the system this setup was used to build — C4 context down
                    to deep-dives on events, the broker and multi-tenancy
examples/epic-walkthrough/  one epic end-to-end: PRD → architecture → RED tests
                    → readiness gate → 10 task specs → execution status
```

The `project/` and `global/` trees are deliberately **unmodified** — what you see is
where these files actually lived. The book links into them; it never rearranges them.

## If you came here looking for…

| Looking for                                             | Go to                                                                                                                         |
| ------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Claude Code **hooks** examples (all 8 lifecycle events) | [`project/.claude/hooks/`](project/.claude/hooks/) + wiring in [`settings.json`](project/.claude/settings.json) · [ch. 7](book/07-hooks.md) |
| **`CLAUDE.md`** examples — root, nested, machine-level  | [`project/CLAUDE.md`](project/CLAUDE.md), [`project/apps/*/CLAUDE.md`](project/apps/), [`global/CLAUDE.md`](global/CLAUDE.md) · [ch. 4](book/04-context.md) |
| Claude Code **skills** (`SKILL.md`) for a real codebase | [`project/.claude/skills/`](project/.claude/skills/) — 71 of them · [ch. 5](book/05-skills.md)                                |
| **Subagents** with scoped tools, maker ≠ checker        | [`project/.claude/agents/`](project/.claude/agents/), [`global/agents/`](global/agents/) · [ch. 6](book/06-agents.md)         |
| **Memory** that survives sessions, and its index        | [`global/memory/MEMORY.md`](global/memory/MEMORY.md) · [ch. 9](book/09-memory.md)                                             |
| **MCP** server config and plugin wiring                 | [`project/.mcp.json`](project/.mcp.json), [`global/settings.json`](global/settings.json) · [ch. 8](book/08-connectors.md)     |
| **Permission deny-lists** that actually hold            | [`global/settings.json`](global/settings.json) → `permissions.deny` · [ch. 8](book/08-connectors.md)                          |
| **Multi-agent workflows** (deterministic fan-out)       | [`book/deep-dives/ultracode-workflows.md`](book/deep-dives/ultracode-workflows.md) · [ch. 12](book/12-running-many-at-once.md) |
| **PRD → epic → RED tests → readiness gate**, worked     | [`examples/epic-walkthrough/`](examples/epic-walkthrough/) · [ch. 11](book/11-an-epic-start-to-finish.md)                     |
| Running **N git worktrees** of one monorepo at once     | [`book/deep-dives/worktree-workspace-allocation.md`](book/deep-dives/worktree-workspace-allocation.md)                        |
| How to **sanitize** a real setup before publishing      | [`SANITIZATION.md`](SANITIZATION.md) — six rounds, what each one missed                                                       |

## Honesty about the gaps

This is a near-complete mirror, not a complete one. Business-only memories (21 files),
52 of 53 epics, 58 of 59 PRDs, two business-dense execution prompts and all session
state were removed rather than renamed; surviving money figures, row-ids and hostnames
are deterministic fakes. The full account — including why the credential-rotation list
an export like this produces belongs with your secrets rather than in the repo — is in
[`SANITIZATION.md`](SANITIZATION.md), which is worth reading as a worked example of why
a denylist alone is not a sanitization strategy.

## Attribution & license

The PM ceremony's skeleton derives from
[automazeio/ccpm](https://github.com/automazeio/ccpm); the loop-engineering framing
follows [Addy Osmani's essay](https://addyosmani.com/blog/loop-engineering/);
`global/skills/kubernetes-skill/` is a vendored copy of
[LukasNiessen/kubernetes-skill](https://github.com/LukasNiessen/kubernetes-skill).
What is borrowed, what is original and what merely influenced is itemized in
[**Appendix B**](book/appendix-b-attribution-and-lineage.md).

Configuration and prose are MIT (see [`LICENSE`](LICENSE); third-party attributions in
[`NOTICE`](NOTICE)), except `global/commands/pm/**` and `global/scripts/pm/**`, which
are governed by the upstream CCPM license preserved alongside them.
