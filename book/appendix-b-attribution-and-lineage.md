# Appendix B · Attribution and lineage

> Appendices · [← Installing this setup](appendix-a-install.md) · [Contents](README.md)

---

Nothing here was built in a vacuum, and pretending otherwise would be both dishonest
and — worse — would hide the most reusable fact about this setup: it is an *assembly*
of other people's good ideas plus a verification spine. This appendix records what
came from where, what was added, and what merely influenced.

## Direct dependencies (code in this repo)

**[automazeio/ccpm](https://github.com/automazeio/ccpm)** (MIT, Copyright © 2025 Ran
Aroussi) — the skeleton of the PM ceremony: the `/pm:*` command set, the on-disk
`epics/` + `prds/` state model, the GitHub sync, the companion scripts in
[`global/scripts/pm/`](../global/scripts/pm/), and six of the eight rules in
[`global/rules/`](../global/rules/). The upstream license is preserved at
[`global/commands/pm/LICENSE`](../global/commands/pm/LICENSE), and
[`global/commands/pm/NOTICE.md`](../global/commands/pm/NOTICE.md) is the
authoritative per-command provenance record.

**[yahsan2/gh-sub-issue](https://github.com/yahsan2/gh-sub-issue)** — the `gh`
extension providing real parent/child issue links, so an epic issue genuinely owns
its task issues. Without it, `epic-sync`'s issue tree would be labels and prayers.

**[LukasNiessen/kubernetes-skill](https://github.com/LukasNiessen/kubernetes-skill)**
(Copyright 2025 Lukas Niessen) — vendored at
[`global/skills/kubernetes-skill/`](../global/skills/kubernetes-skill/) (commit
`b7d3250`), included because it was part of the working setup, not because it is
original here. Its `VENDORED.md` records provenance; its upstream `LICENSE` and OSS
metadata are retained untouched.

## Added on top (original to this setup)

The loop-engineering spine and everything project-specific:

- The five ceremony commands that convert tracking into verification:
  `arch-create`, `tests-generate`, `readiness-check`, `prod-verify`,
  `epic-start-worktree` (plus `milestone-init`, `test-reference-update`)
- The two loops: the [`triage`](../project/.claude/skills/triage/SKILL.md) and
  [`verify-loop`](../project/.claude/skills/verify-loop/SKILL.md) skills, with the
  autonomy policy
- The 71 project skills and 7 project commands
- The 34 hook scripts, including the anchored PR-merge and prod-write gates
- The agent fleet — 23 project agents and the 8 machine-level checkers, including
  `adversarial-reviewer`'s information-isolation design
- The memory system: the index discipline, the four types, the 172 files of content
- The worktree workspace allocator (`acme-worktree`) and
  [its design document](deep-dives/worktree-workspace-allocation.md)
- The [ultracode workflow patterns](deep-dives/ultracode-workflows.md) and their
  guardrails
- The custom MCP server ([`acme-mcp`](../project/apps/acme-mcp/))
- This book, the [architecture volume](../docs/architecture/), and the
  [sanitization process](../SANITIZATION.md) that made publication possible

## Influences (ideas, not code)

**[Addy Osmani — *Loop Engineering*](https://addyosmani.com/blog/loop-engineering/)**
and **[addyosmani/agent-skills](https://github.com/addyosmani/agent-skills)** — the
largest intellectual debt: the six-primitive framing, maker ≠ checker as discipline,
verifiable stop conditions, and the four named risks that [chapter 2](02-loops-not-prompts.md)
answers. The agent-skills plugin *is* installed (see
[`global/settings.json`](../global/settings.json)); the ideas are the larger
borrowing.

**[BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD)** — the shape of
PRD → architecture → sharded epics → context-carrying story files. Not installed;
the ceremony's document flow echoes it deliberately.

**[Geoffrey Huntley — the Ralph Wiggum technique](https://ghuntley.com/ralph/)** —
the same-prompt-repeated iteration model behind the five `ralph-*` skills, bounded
and adapted to this codebase.

**Anthropic's Claude Code plugin ecosystem** — several project skills are explicit
*extensions* of plugin-provided bases (`verification-before-completion`,
`systematic-debugging`, `test-driven-development`), and the
[skill-precedence rule](../project/CLAUDE.md) exists precisely to keep these three
sources composed rather than colliding.

## The same setup, on a public project

Almost everything in this export was used on a private employer codebase you cannot
read — which makes the configuration hard to check against real output. One public
project closes that gap:
[**football-trackers**](https://github.com/milosCvetkovicDev/football-trackers) is a
real-time GPS tracking system (ESP32 firmware → MQTT → Bun/Elysia ingest → a live
React coach view), built with the *machine-scoped* half of this setup — the same
`global/CLAUDE.md`, the same eight rules, the same PM ceremony and the same
maker ≠ checker discipline.

It is a smaller system than the platform of [chapter 13](13-the-system-it-built.md),
but it is *readable end to end*: 25 ADRs, a hardware-free e2e suite, CI-enforced
static guards, and a documented privacy posture. If you want to see what this
configuration's habits look like in code someone can actually open — the ADR trail,
the guard-per-failure-mode reflex, the "verify by execution" commit messages — read
that repository alongside this one.

## License

Configuration and prose are MIT (see [`LICENSE`](../LICENSE); third-party
attributions in [`NOTICE`](../NOTICE)), **except** `global/commands/pm/**` and
`global/scripts/pm/**`, which are governed by the upstream CCPM license preserved
alongside them, and the vendored `kubernetes-skill`, which keeps its own.

---

> Back to the [Contents](README.md) · or start over at
> [Chapter 1 — One engineer, thirteen services](01-one-engineer-thirteen-services.md)
