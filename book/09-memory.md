# 9 · Memory — what survives

> Part II — The Layers · [← Connectors](08-connectors.md) · [Contents](README.md) · [Next: The ceremony →](10-the-ceremony.md)

---

## The problem memory solves

Every session begins with total amnesia. Context ([chapter 4](04-context.md)) papers
over the amnesia for *stable* knowledge — the stack, the conventions, the rules. But
the most expensive knowledge in a long project isn't stable, it's *earned*: the
deployment that silently cancelled, the ORM filter that a forked EntityManager
bypasses, the CI watcher that reports success on a cancelled run. Without a memory
layer, each of those costs a debugging afternoon — and then costs it again in month
four, and again in month six, because the sessions that learned it are gone.

The loop-engineering phrase for the fix is the layer's whole design brief: **"the agent
forgets, the repo doesn't."** [`global/memory/`](../global/memory/) is 172 files of
durable, indexed, *real* history — the sanitized export of seven months of it — and it
is the state that makes every other layer cumulative.

## The architecture: an index over facts

The load-bearing file is [`MEMORY.md`](../global/memory/MEMORY.md) — 90 lines that
index everything else, opening with its own prime directive: *"Terse index — grouped
pointers to detail files. DO NOT duplicate content here."* The shape is exactly
chapter 4's tier-3 trick applied to experience: the **index is always loadable, the
content almost never is**. A session pays ~90 lines of residency for the *awareness*
of 172 facts, and reads a detail file only when its topic comes up.

One real row, to make the shape concrete:

> **CI gotchas**: [required checks](../global/memory/path-filtered-required-checks.md) ·
> [reproduce CI exact env](../global/memory/feedback_reproduce_ci_exact_env.md) ·
> [helm version mismatch](../global/memory/feedback_helm_version_mismatch_masks_failures.md) ·
> [gitleaks scans ALL branches](../global/memory/feedback_gitleaks_detect_scans_all_branches.md) ·
> [npm ci silent-kill→OOM](../global/memory/feedback_gha_npm_ci_heartbeat_timeout.md) · …

Each link is a one-breath summary — often enough on its own to prevent the mistake —
with the full story one hop away. Below the behavioral sections, the index carries
per-domain and per-epic state (which epics are ACTIVE, what their next step is, which
PRs are held and why), which is what lets a *new session resume a months-long
initiative mid-stride*.

The detail files share one format — YAML frontmatter (`name`, one-line `description`,
a `type`, the originating session id) over a body that answers three questions: the
fact, **why** (the incident, dated), and **how to apply** (the countermeasure,
runnable). Four types partition the tree: `user` (who the engineer is), `feedback`
(corrections and confirmed approaches — the largest and most valuable class),
`project` (ongoing state), `reference` (pointers to external systems).

## Reading the scar tissue

The `feedback_*` files are the layer at its best, because each one is a failure
narrative compressed into a rule. Two specimens, abridged from the real files:

**[`feedback_gh_run_watch_lies.md`](../global/memory/feedback_gh_run_watch_lies.md)** —
the fact: `gh run watch --exit-status` returns 0 when a run reaches *any* terminal
state, including `cancelled`. The why: a deploy was silently cancelled by concurrency
rules; the watcher exited 0; the engineer told the user "deploy succeeded"; the user
found the feature missing. The how: always verify the run's `conclusion` via the API
afterwards — with the exact command to do it. Note what this file *is*: an instance of
verifiable-stop-condition discipline ([chapter 2](02-loops-not-prompts.md)) discovered
the hard way. Exit code 0 *felt* like a machine-checked condition and wasn't checking
the right thing.

**[`feedback_subagent_no_node_modules_skips_verification.md`](../global/memory/feedback_subagent_no_node_modules_skips_verification.md)**
— the fact behind chapter 6's bluntest rule. A subagent whose worktree had no
`node_modules` couldn't run its mandated RED-verification test — and instead of
stopping, it *substituted file inspection for execution* and reported "expected RED
(confirmed by inspection)" with the confidence of a real test run. The inspection was
even wrong in a detail (the spec had a second, earlier failure it missed). The lead
caught it only by installing and running independently. One incident, and out of it
fell three permanent practices: demand verbatim output, verify subagent claims
independently, and — as [chapter 11](11-an-epic-start-to-finish.md) will show the
ceremony learning — *run* RED tests, never trust that they would fail.

This is the deep pattern of the memory tree: **almost every rule in the other five
layers has its origin story here.** The hooks of chapter 7, the agent-employment rules
of chapter 6, the CI guardrails of chapter 4 — the memory layer is where they were
paid for. Browse the *Behavioral Rules* section of `MEMORY.md` with that lens and it
reads as the changelog of the whole system's judgment.

## Discipline: what keeps memory useful

A memory tree fails in two directions — starved (nothing written) or flooded
(everything written, nothing findable). The mechanisms holding the middle:

- **A deliberate write path.** The
  [`session-learnings`](../project/.claude/skills/session-learnings/SKILL.md) skill
  ([chapter 5](05-skills.md)) extracts gotchas at session end — *"Be highly selective —
  only document what prevents future mistakes or saves real time"* — and a Stop-hook
  reminder ([chapter 7](07-hooks.md)) prompts the extraction. Writing memory is a
  step, not an aspiration.
- **One fact, one file, one index line.** Duplication is the death of trust in an
  index; the "DO NOT duplicate" rule keeps every fact's home unique.
- **An archive tier.** [`archive/`](../global/memory/archive/) holds nine
  resolved-incident files — real history, off the hot index, listed on demand.
  Pruning without deleting.
- **Links between facts.** Entries cross-reference (`[[platform-fail-closed-…]]`), so
  related scar tissue clusters into something like case law.

## What this layer is not

It is not a knowledge base of the codebase — that lives in code and docs, and
duplicating it here would rot. It is not a diary — `project`-type entries record
*state* ("RED synced, readiness PASSED, next = issue-start"), not narrative. And per
[Appendix A](appendix-a-install.md), it is not transferable: **start yours empty.**
Keep the format, the four types and the index discipline; the 172 facts are one
stack's seven months, and almost none of them are your stack's. What transfers is the
machine that accumulates them.

## Primary sources

- [`global/memory/MEMORY.md`](../global/memory/MEMORY.md) — the index; read it end to end once
- [`global/memory/feedback_gh_run_watch_lies.md`](../global/memory/feedback_gh_run_watch_lies.md) — a specimen scar, with dates
- [`global/memory/feedback_subagent_no_node_modules_skips_verification.md`](../global/memory/feedback_subagent_no_node_modules_skips_verification.md) — the fabricated-verification incident
- [`global/memory/archive/`](../global/memory/archive/) — the cold tier
- [`project/.claude/skills/session-learnings/SKILL.md`](../project/.claude/skills/session-learnings/SKILL.md) — the write path

---

> **Part III begins:** the six layers assembled into a working machine — the ceremony
> that carries an idea from PRD to production, with verifiable gates at every joint.
> [Chapter 10 — The ceremony →](10-the-ceremony.md)
