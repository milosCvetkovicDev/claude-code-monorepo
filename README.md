# claude-code-monorepo

**Claude Code skills, hooks, subagents, `CLAUDE.md` files, MCP config and memory — the real,
sanitized configuration from seven months of shipping a production TypeScript monorepo.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude_Code-configuration-d29922.svg)](https://docs.anthropic.com/en/docs/claude-code)
[![Sanitized](https://img.shields.io/badge/sanitized-6_audit_rounds-success.svg)](SANITIZATION.md)

A near-complete reference export of the Claude Code setup I used to build and ship a
13-service TypeScript platform — roughly 250k lines, ~780 merged PRs, seven months,
largely as a single engineer.

This is not a starter template. It is the **real configuration**, sanitized: full skill
texts, full hook scripts, the actual memory tree, and one complete epic walkthrough. The
company, product, people and infrastructure identifiers have been renamed to consistent
fictional ones — see [`SANITIZATION.md`](SANITIZATION.md).

---

## The idea

> "Loop engineering is replacing yourself as the person who prompts the agent.
> You design the system that does it instead."
> — [Addy Osmani](https://addyosmani.com/blog/loop-engineering/)

Two disciplines run through everything here:

- **Maker ≠ checker.** The agent that does the work never grades it. A _separate_ agent
  confirms. `done` is a claim, not a proof.
- **Verifiable stop conditions.** Every "is it finished?" must be machine-checkable — a
  command that exits 0, a named RED test that turns GREEN. Never a vibe.

---

## Six layers

| Layer          | Question it answers                                | Where                                                                     |
| -------------- | -------------------------------------------------- | ------------------------------------------------------------------------- |
| **Context**    | What must it always know?                          | `project/**/CLAUDE.md` (19 files), `global/rules/`, `global/references/`  |
| **Skills**     | How is this kind of task done here?                | `project/.claude/skills/` (71), `global/commands/` (53)                   |
| **Agents**     | Who does it — and who checks it?                   | `project/.claude/agents/` (23), `global/agents/` (8)                      |
| **Hooks**      | What must never happen, whatever the model thinks? | `project/.claude/hooks/` (34 scripts, 28 wired across 8 lifecycle events) |
| **Connectors** | What real systems can it touch?                    | `project/.mcp.json`, plugin config in `settings.json`                     |
| **State**      | What survives the session ending?                  | `global/memory/` (172 files), `examples/epic-walkthrough/`                |

---

## Layout

```
project/          repo-scoped config, as it sits in the monorepo
  .claude/
    skills/       71 skills — procedure, not prose
    agents/       23 domain + review agents, tool-scoped
    hooks/        34 hook scripts, 28 wired — the only rules the model can't argue with
    commands/     7 project slash-commands
    references/   checklists and templates loaded on demand
    settings.json hook wiring, permissions, model + effort
  **/CLAUDE.md    19 nested instruction files, at their original paths
  .mcp.json       MCP servers
  docs/           partial — CLAUDE.md files and design notes only; some links
                  from the nested CLAUDE.md files point at monorepo docs not
                  included in this export

global/           machine-scoped config (~/.claude equivalent)
  rules/          8 always-resident rules
  references/     16 on-demand references, pulled by a routing table
  commands/pm/    45 PM ceremony commands (see attribution)
  agents/         8 review + analysis agents
  skills/         1 vendored third-party skill (kubernetes-skill)
  scripts/        PM helper scripts
  memory/         172 durable facts — sanitized real history, not synthetic
  settings.json model, permissions deny-list, plugins
  statusline.sh   Catppuccin statusline

docs/
  loop-engineering.md the map: six primitives → concrete tools
  ultracode-workflows.md deterministic multi-agent fan-out
  architecture/    the system this setup was used to build — C4 context down to
                   deep-dives on events, the broker and multi-tenancy
  worktree-workspace-allocation.md one integer per worktree derives every port,
                   database and container name — so N checkouts run at once

examples/
  epic-walkthrough/        one epic end-to-end: PRD → epic → architecture →
                           RED test manifest → readiness report → 10 task
                           specs → GitHub mapping → execution status
```

---

## Where to start

1. **`docs/loop-engineering.md`** — the thesis and how the pieces connect.
2. **`examples/epic-walkthrough/`** — the whole ceremony, in artefacts, on one real epic.
   Read `readiness-report.md` and `test-manifest.md` first: they are what "done" means.
3. **`project/.claude/settings.json`** — 28 of the 34 hook scripts wired across 8 lifecycle
   events.
4. **`project/.claude/skills/verify-loop/`** and **`triage/`** — the two loops.
5. **`global/memory/MEMORY.md`** — the index into seven months of hard-won gotchas.

See [`install.md`](install.md) for wiring this into a machine.

## If you came here looking for…

| Looking for                                             | Go to                                                                                                                         |
| ------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Claude Code **hooks** examples (all 8 lifecycle events) | [`project/.claude/hooks/`](project/.claude/hooks/) + wiring in [`settings.json`](project/.claude/settings.json)               |
| **`CLAUDE.md`** examples — root, nested, machine-level  | [`project/CLAUDE.md`](project/CLAUDE.md), [`project/apps/*/CLAUDE.md`](project/apps/), [`global/CLAUDE.md`](global/CLAUDE.md) |
| Claude Code **skills** (`SKILL.md`) for a real codebase | [`project/.claude/skills/`](project/.claude/skills/) — 71 of them                                                             |
| **Subagents** with scoped tools, maker ≠ checker        | [`project/.claude/agents/`](project/.claude/agents/), [`global/agents/`](global/agents/)                                      |
| **Memory** that survives sessions, and its index        | [`global/memory/MEMORY.md`](global/memory/MEMORY.md)                                                                          |
| **MCP** server config and plugin wiring                 | [`project/.mcp.json`](project/.mcp.json), [`global/settings.json`](global/settings.json)                                      |
| **Permission deny-lists** that actually hold            | [`global/settings.json`](global/settings.json) → `permissions.deny`                                                           |
| **Multi-agent workflows** (deterministic fan-out)       | [`docs/ultracode-workflows.md`](docs/ultracode-workflows.md), [`project/.claude/wf-*.mjs`](project/.claude/)                  |
| **PRD → epic → RED tests → readiness gate**, worked     | [`examples/epic-walkthrough/`](examples/epic-walkthrough/)                                                                    |
| Running **N git worktrees** of one monorepo at once     | [`docs/worktree-workspace-allocation.md`](docs/worktree-workspace-allocation.md)                                              |
| How to **sanitize** a real setup before publishing      | [`SANITIZATION.md`](SANITIZATION.md) — six rounds, what each one missed                                                       |

---

## Attribution

The PM ceremony's skeleton is not mine:

- **[automazeio/ccpm](https://github.com/automazeio/ccpm)** — the `/pm:*` command set, the
  on-disk `epics/` + `prds/` state model, the GitHub sync, and six of the eight rules in
  `global/rules/`. Its license is preserved at `global/commands/pm/LICENSE`.
- **[yahsan2/gh-sub-issue](https://github.com/yahsan2/gh-sub-issue)** — the `gh` extension
  giving real parent/child issue links, so an epic issue genuinely owns its task issues.

Added on top (mine): `arch-create`, `tests-generate`, `readiness-check`, `prod-verify`,
`epic-start-worktree`, the whole loop-engineering layer, the 71 project skills, the 34
hook scripts (28 wired across 8 lifecycle events), the agent fleet, and the memory system.

Influences, not dependencies — neither is installed here, both changed how this was built:

- **[BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD)** — the PRD → architecture →
  sharded epics → context-carrying story files shape.
- **[addyosmani/agent-skills](https://github.com/addyosmani/agent-skills)** and the
  [loop engineering essay](https://addyosmani.com/blog/loop-engineering/) — maker/checker
  discipline and verifiable stop conditions. (The plugin _is_ installed; the ideas are the
  larger debt.)

---

## What was removed

Honesty about the gaps, so nobody mistakes this for a complete mirror:

- **Business-only memories (21 files)** — business-domain knowledge with no transferable
  engineering lesson underneath. Deleted rather than renamed: a rename would have left the
  domain knowledge intact under different labels.
- **52 of 53 epics and 58 of 59 PRDs** — work products, not setup. One complete epic is
  kept as `examples/epic-walkthrough/`.
- **Two epic execution prompts** (~490 KB) — too business-dense to sanitize usefully.
- **Session state** — transcripts, worktrees, caches, `settings.local.json`, plugin
  binaries, and everything under the runtime directories.

Money figures, entity row-ids, hostnames and public IPs that survive in the memory tree
have been replaced with deterministic fakes. They read plausibly; none of them are real.

Sanitization took six rounds — a scripted rename, then five adversarial multi-agent
audits, each of which found real leaks the previous round's method could not see. What
they found — and why the credential-rotation list an export like this produces belongs
with your secrets rather than in the repo — is in [`SANITIZATION.md`](SANITIZATION.md).
It is worth reading as a worked example of why a denylist alone is not a sanitization
strategy.

## Third-party content

`global/skills/kubernetes-skill/` is a vendored copy of
[LukasNiessen/kubernetes-skill](https://github.com/LukasNiessen/kubernetes-skill)
(commit `b7d3250`, Copyright 2025 Lukas Niessen). It is included because it was part of
the working setup, not because it is mine. See its `VENDORED.md` and `LICENSE`.

## License

Configuration and prose are MIT (see `LICENSE`; third-party attributions in `NOTICE`),
except `global/commands/pm/**` and `global/scripts/pm/**`, which are governed by the
upstream CCPM license preserved alongside them.
