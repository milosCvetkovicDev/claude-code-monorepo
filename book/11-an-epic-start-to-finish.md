# 11 · An epic, start to finish

> Part III — In Motion · [← The ceremony](10-the-ceremony.md) · [Contents](README.md) · [Next: Running many at once →](12-running-many-at-once.md)

---

Everything so far has been the machine described at rest. This chapter runs it — one
real epic, **#1623 · platform-trading-hardening**, followed through every ceremony step
with the actual artefacts, which are preserved intact in
[`examples/epic-walkthrough/`](../examples/epic-walkthrough/). Dates and issue numbers
are real; only the domain vocabulary is renamed. Read this chapter with the artefacts
open — each section header links its primary source.

The story also contains the book's best moment, so it is worth flagging in advance:
midway through, **the verification machinery catches a defect in itself**, and the
response to that is the whole method in miniature.

## The morning: a gap analysis becomes a PRD

*July 2nd, 11:25 UTC* — [`PRD.md`](../examples/epic-walkthrough/PRD.md).

The trading backend was *functionally* mature: lifecycles shipped, RBAC shipped,
outbox, contract tests, BDD suites. The epic began with a gap analysis run **against
the as-built code rather than the docs**, asking what separates "works" from
"enterprise-ready." The answer became a PRD stating five failure classes — and note
the framing rule it sets for itself: each gap is stated *as the failure mode, not as a
list of endpoints that exhibit it*, because "the fix has to be the cross-cutting
mechanism, not a sweep of call sites":

1. **A broken feedback loop** — a downstream context published a contract-defined
   event; nothing consumed it, so state never advanced and the contexts drifted.
2. **Concurrency unsafety** — an availability check with no lock lets two writers
   jointly exceed a shared quota; no version column means silent lost updates; no
   idempotency key means a retry duplicates records.
3. **Unsafe redelivery** — at-least-once delivery into consumers with no inbox ledger.
4. **Data-governance gaps** — physical deletes on some endpoints, none on others.
5. **Contract infidelity** — filters, a derived status, commands and export that the
   contract defines and the API doesn't serve.

Ten user stories, fifteen functional requirements, each requirement carrying Gherkin
scenarios with concrete worked examples — a two-writer race on one quota, a version
3-vs-4 stale write, a reused idempotency key. Those scenarios are not documentation;
in three steps they will become the RED suite. The PRD even flags a time-honesty
principle in passing, about debt carried on an assumption: *"debt with a correctness
consequence needs a date, not an assumption."*

## The architecture pass: three decisions, made once

*11:36 UTC* — [`architecture.md`](../examples/epic-walkthrough/architecture.md).

`/pm:arch-create` answers the questions the PRD deliberately left open, and its
decision matrix separates **inherited** constraints (outbox convention, Redis
cache-only, per-schema isolation — *not re-debated*) from the three genuinely new
choices, each becoming an ADR:

- **ADR-0066** — quota serialization via `PESSIMISTIC_WRITE` on the source rows in
  deterministic order (not an advisory lock, not the deferred saga — which stays the
  long-term target, now with its debt note amended).
- **ADR-0067** — optimistic locking with MikroORM's native version column, `version`
  in the mutation DTO, mismatch → 409 `STALE_WRITE`. Declared a *platform-wide*
  convention, not a local fix.
- **ADR-0068** — inbox `processed_event` + `idempotency_key` + `parked_message` as
  per-service PG tables, the inbox insert transactional with the state change; the
  DLX demoted to transport backstop. Also platform-wide.

The document then goes further down than most architecture docs dare: naming
conventions (table shapes, error codes, metric families), module structure per
service, and an FR→file map. That depth is what lets ten parallel task agents later
produce code that looks like one person wrote it.

## The epic and its ten tasks

*11:30–11:45 UTC* — [`epic.md`](../examples/epic-walkthrough/epic.md), task files
[`1624`](../examples/epic-walkthrough/1624.md)–[`1633`](../examples/epic-walkthrough/1633.md).

The epic's strategy line deserves quoting because it is the quiet reason the whole
thing stayed tractable: *"maximally reuse-driven: every new capability extends an
existing, shipped mechanism rather than introducing a new one."* The consumer mirrors
an existing consumer; soft delete reuses the tenant filter's mechanism; filters reuse
a shipped parser; audit reuses the activity recorder. Ten tasks, T1–T10 — **tests
first (T1), production verification last (T10)**, nine parallelizable, one
deliberately sequential. Each task file carries acceptance criteria cross-referenced
to PRD Gherkin, a Definition of Done thirteen checkboxes long, and its
`depends_on` / `conflicts_with` edges — which will matter shortly.

## The hinge: sixty tests that must fail correctly

*11:46 UTC* — [`test-manifest.md`](../examples/epic-walkthrough/test-manifest.md).

`/pm:tests-generate` produced the RED suite: 28 files — 10 Gherkin features, 88 step
definitions, 9 testcontainers specs, 5 unit stubs, one message-pact — 60 test cases
in all. The manifest's defining feature is its **"RED reason" column**: every file
documents *why* it fails, and the reasons are engineered, not incidental. Two
distinct RED mechanisms are used deliberately:

- **Import-RED** — the spec statically imports a module that does not exist yet
  (`invoice-processed.handler`), failing at collection. Proof the implementation is
  absent.
- **Behavior-RED** — the spec drives *real, existing* code and asserts the future
  behavior: two genuine `em.fork()` racers against today's unlocked availability
  check; a stale write that today silently succeeds, asserted to reject. Proof the
  *current* behavior is what the PRD says it is.

The distinction is verification craft: an import-RED can only tell you code is
missing; a behavior-RED pins down what the system does *now*, so the GREEN flip later
means exactly one thing. And writing the specs against the contract paid immediately
— it surfaced that an existing endpoint returned a different error code and HTTP
status than the contract specifies. A drift *only a test written from the contract*
could catch; it entered T4's scope on the spot.

## The gate: a CRITICAL that refused to be waved through

*11:48 UTC* — [`readiness-report.md`](../examples/epic-walkthrough/readiness-report.md).

`/pm:readiness-check` — an independent checker, not the epic's author — audited the
package: a 15-row FR-coverage matrix (every FR covered by an implementation task *plus*
T1's tests *plus* T10's verification — "no single-touchpoint FRs"), twelve validation
checks, findings by severity. It found one CRITICAL: the epic's BDD scenarios were
not yet on disk (generation was in flight). The report's handling of it is the
ceremony's character in one line:

> **Resolution path: wait for landing + independent verification; this report will be
> updated and the verdict flipped to READY. Do NOT override.**

And the flip, when it came at 12:19, was earned, not assumed — the frontmatter records
what "independently verified" meant: file counts matched the manifest, zero existing
test files modified, the five import-RED targets confirmed absent, and both services'
typechecks failing with *exactly* the expected missing-module errors and nothing else.
Verdict: READY — 0 CRITICAL, 1 MAJOR (example-maps lagging, mitigated, ~1h fix
recommended into T1), 5 MINOR, each with an owner and a timing.

## Sync, and the plan meets the graph

*20:00 UTC* — [`github-mapping.md`](../examples/epic-walkthrough/github-mapping.md),
[`execution-status.md`](../examples/epic-walkthrough/execution-status.md).

`/pm:epic-sync` created issue #1623 with real child issues #1624–#1633. Then
execution planning did something quietly sophisticated: it read the tasks'
`conflicts_with` edges and **graph-coloured them into waves** — five mutually
non-conflicting tasks in Wave 1; #1628 alone in Wave 2 (it conflicts with three);
#1631 alone in Wave 3; observability after its dependencies; prod-verify last. The
status file also records a judgment call *against* the default tooling:

> Epic-start's "all agents in ONE shared branch" is unsafe here: 5 conflict edges +
> git-add races. Using per-issue worktrees, merged sequentially.

That is [chapter 6](06-agents.md)'s scar tissue (the git-add race memory) changing an
execution plan in real time.

## The pilot — and the day the tests were wrong

*July 2nd evening → July 3rd* — [`execution-status.md`](../examples/epic-walkthrough/execution-status.md),
[`1625.md`](../examples/epic-walkthrough/1625.md).

Wave 0 landed the RED baseline (#1624): dependencies installed, RED verified —
typecheck failing on exactly the four missing-implementation modules. Then #1625, the
inbound write-back consumer, ran as the **Wave 1 pilot**, and the pilot did what
pilots are for: it surfaced **three systematic defects in the RED baseline itself** —

1. **Wrong SQL placeholder dialect** — raw `conn.execute` calls used PostgreSQL's
   `$1` placeholders where MikroORM needs `?`. Four files affected.
2. **A broken step-expression escape** — `/api` inside Cucumber expressions, where
   `/` is the alternation operator, aborted the *entire* BDD suite at load. The bug
   also existed in a previously merged file — meaning the BDD suite **had not been
   gating CI** and nobody knew.
3. **A fixture that failed itself** — a seed helper's default left a row in DRAFT
   while the scenario asserted CONFIRMED, so the test failed on its own setup rather
   than on the missing behavior it existed to specify.

Every layer of the method shows up in how this was handled. The three defects were
fixed in a dedicated remediation commit *to the baseline*, so every later task
inherits a clean RED. The no-regression proof was empirical: the full integration
run's failure set was re-checked against the baseline commit and shown identical.
One of the three ("$1 vs ?") was initially **mis-ruled fine by the reviewing lead
and corrected by an empirical run** — recorded without embarrassment, alongside the
memory-tree lesson it minted: *"run the test, don't overrule empirical with
static."* And the episode produced a permanent upgrade to the ceremony itself:

> **RED verification lesson: typecheck-only is insufficient — must RUN testcontainers.**

This is the point of the whole apparatus, stated by accident. The RED suite is the
measuring instrument for everything downstream; the pilot calibrated the instrument
*before* nine parallel tasks trusted it. A process that cannot catch its own defects
just propagates them at machine speed.

#1625 itself finished **verified green by independent re-run**: testcontainers 3/3,
pact 9/9, 517 unit tests passing, 86 BDD scenarios loading with the write-back
scenarios green — and one scenario correctly stopping at a `pending('009')` metric
step, because that assertion belongs to task #1632 and the suite says so. Even the
incompleteness is typed.

## What the walkthrough is for

The export freezes the epic at this moment — pilot proven, waves planned, baseline
clean — which is the right freeze-frame: every ceremony artefact exists, and the
remaining tasks are repetition of a now-calibrated loop. Read the artefacts in this
order and you will have watched the entire method work once:

| Order | Artefact                                                                     | What it shows                                    |
| ----- | ---------------------------------------------------------------------------- | ------------------------------------------------ |
| 1     | [`PRD.md`](../examples/epic-walkthrough/PRD.md)                              | verifiable requirements, Gherkin with worked examples |
| 2     | [`architecture.md`](../examples/epic-walkthrough/architecture.md)            | inherited vs decided; the three ADRs             |
| 3     | [`epic.md`](../examples/epic-walkthrough/epic.md)                            | reuse-driven decomposition into ten tasks        |
| 4     | [`test-manifest.md`](../examples/epic-walkthrough/test-manifest.md)          | the RED suite and its engineered failure reasons |
| 5     | [`readiness-report.md`](../examples/epic-walkthrough/readiness-report.md)    | the independent gate, and a CRITICAL done right  |
| 6     | [`github-mapping.md`](../examples/epic-walkthrough/github-mapping.md)        | state synced to real issues                      |
| 7     | [`execution-status.md`](../examples/epic-walkthrough/execution-status.md)    | wave planning, the pilot, the baseline remediation |
| 8     | [`1624.md`](../examples/epic-walkthrough/1624.md)–[`1633.md`](../examples/epic-walkthrough/1633.md) | what a task spec looks like when an agent will execute it |

---

> **Next:** the pilot ran one maker at a time. The remaining question of scale — many
> agents inside one task, many workstreams on one machine — is machinery of its own.
> [Chapter 12 — Running many at once →](12-running-many-at-once.md)
