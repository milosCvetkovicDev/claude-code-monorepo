# Loop engineering in Acme

> "Loop engineering is replacing yourself as the person who prompts the agent. You design the
> system that does it instead." — [Addy Osmani, _Loop Engineering_](https://addyosmani.com/blog/loop-engineering/)

A **loop** is a recursive goal: you define a purpose and a verifiable stop condition, and a system —
not you, turn by turn — finds the work, distributes it, checks the results, tracks state, and decides
the next step. The leverage point moves from _prompting_ to _designing the loop_. That design is
_harder_ than prompt engineering, not easier: it demands sustained engineering judgment. Two engineers
can build the same loop and get opposite results — one moves faster on work they understand, the other
uses it to avoid understanding. The loop doesn't know the difference. You do.

This page is the map. It names the practice, points to the pieces we already had, and documents the
two new ones that complete the loop.

> **Ultracode companion:** loop engineering replaces _you as the prompter_; **ultracode workflows**
> replace the _sequential maker_ — fanning implementation out across many agents (maker ≠ checker,
> deterministic control flow) with the `Workflow` tool. See
> [`ultracode-workflows.md`](./ultracode-workflows.md) for the per-phase execution plan and script
> skeletons.

## The six primitives → what we use

| Primitive | Role in the loop | In Acme |
| ----------------- | --------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| **Automations**   | Discovery + triage on a schedule | `triage` skill + `/loop` + `/schedule` + the opt-in GHA template |
| **Worktrees**     | Isolate parallel agents so they don't collide | `acme-worktree`, `isolation: worktree`, `worktree-doctor.sh`, `using-git-worktrees`                     |
| **Skills**        | Encode project knowledge so agents don't re-derive it | `.claude/skills/**` (~70), CLAUDE.md, `memory/**`                                                         |
| **Connectors**    | Connect agents to real tools | MCP: github, argocd, context7, playwright, acme-mcp |
| **Sub-agents**    | Separate **maker** from **checker**                             | `adversarial-reviewer`, `code-reviewer`, `edge-case-hunter`, the review panel; Workflow verifier patterns |
| **State on disk** | Loop memory across runs ("the agent forgets, the repo doesn't") | PM `.claude/epics/**`, `.claude/prds/**`, `memory/**`, and the triage **inbox**                           |

We had every building block. What was missing was the **assembly** — the loop that wires discovery →
state → maker/checker → connectors — plus a verifiable-stop convention. Those are the two new skills.

## The two loops

### 1. `triage` — the discovery loop (automations + state)

`.claude/skills/triage/` scans repo health (is `main` red? failing-check or conflicted PRs? open bug
issues? recently-introduced-bug candidates?), classifies each finding, and writes a ranked, on-disk
**inbox** at `.claude/triage/inbox.md` (git-ignored; durable copy → a `triage-inbox` GitHub issue for
scheduled runs). In `mode=auto-pr` it additionally runs a maker→checker pipeline for **safe-category
findings only** and opens PRs — never merges.

- Discovery is a read-only script: `.claude/skills/triage/scripts/discover.sh` (safe to run anywhere).
- The allowlist + hard NO-list + guardrails live in `.claude/skills/triage/references/autonomy-policy.md`.
- The inbox surfaces automatically at session start (via the `load-github-context.sh` hook).

### 2. `verify-loop` — the verification loop (sub-agents, the `/goal` pattern)

`.claude/skills/verify-loop/` drives any task to a **provable** finish: it runs until a _verifiable
stop condition_ is true, graded by a **separate checker** — never the agent that did the work. "The
model that wrote the code is too nice grading its own homework." `done` is a claim, not a proof; the
checker's pass + green gates are the proof. This is the only thing that lets you leave a loop unattended.

## Run modes (you chose both)

| Mode | How | When |
| -------------------------- | --------------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| **Now**                    | `/triage`                                                                               | A standing morning pass while you're at the desk |
| **Local recurring**        | `/loop /triage` (self-paced) or `/loop 30m /triage`                                     | Keep triaging while you work on something else |
| **Scheduled / unattended** | a `/schedule` cloud routine running `/triage`, **or** activate `assets/triage-loop.yml` | The canonical "fires each morning, you read the inbox" automation |

`CronCreate` (the in-session `/schedule` shortcut) is **session-only** — it dies when Claude exits.
For a true close-the-laptop loop use a `/schedule` cloud routine or the GitHub Actions template (read
the CI/CD guardrails before activating that). Scheduled runs should use `durable=github-issue` so the
inbox survives a fresh checkout.

## Autonomy posture

The loop **opens PRs but never merges**. Branch protection + required checks + the FD's prod sign-off
are the human gate, and that gate is the point. Auto-PRs are restricted to a narrow safe-category
allowlist (lint/format, patch/minor deps, docs/typos, proven-flaky-test quarantine with a tracking
issue, one-line fixes with a reproducing test) and are blocked entirely from infra, CI/CD, migrations,
secrets, auth, and money/commission logic. Everything else lands in the inbox. See the autonomy policy
for the full contract. This is the article's "still review what the loop produces" made structural.

## Loop engineering in the PM ceremony

The triage loop sits **above** the ceremony (its inbox feeds `/pm:prd-new` and issue creation); the
verify-loop sits **inside** it (the stop-condition discipline). Each step maps to a primitive:

| Ceremony step | Primitive | Concrete loop action |
| --------------------------- | -------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `prd-new` / `prd-parse`     | State | The PRD is durable state. Capture **verifiable** acceptance conditions, not vibes — they become verify-loop stop conditions. |
| `arch-create`               | Sub-agents | Judge-panel: generate independent approaches, score with parallel judges, synthesize. Maker ≠ judge.                         |
| `epic-decompose`            | Worktrees | Decompose so independent tasks can run as parallel makers in isolated worktrees. Mark which are AUTO-safe.                   |
| `tests-generate`            | State + verify | **The hinge.** RED tests _are_ the machine-checkable stop condition for `verify-loop`. Emit them explicitly.                 |
| `readiness-check`           | Sub-agents (checker) | A checker gate before sync — an independent reviewer, not the author.                                                        |
| `epic-sync` / `issue-start` | Worktrees + maker | Each issue runs as a **maker** in its own worktree (`isolation: worktree`).                                                  |
| `issue-close`               | Verify | Run `verify-loop`: a separate checker confirms RED→GREEN and no regression before close.                                     |
| `epic-review`               | Sub-agents (checker) | The adversarial review pipeline — the canonical maker/checker split. Feed it the diff; forbid git mutation.                  |
| `epic-merge`                | Connectors | Gates + green CI via the github connector. Never `--admin`/`--no-verify` to force it.                                        |
| `prod-verify`               | Verify | `verify-loop` against production evidence — cite a real query, not "looks fine."                                             |
| `epic-close`                | State | Update state; route any leftover/unhandled items to the **triage inbox** so nothing is dropped.                              |

The agent-facing per-step actions live in `~/.claude/references/workflow/loop-engineering.md`, loaded
on-demand at the loop-touchpoint PM steps — `tests-generate`, `issue-start`, `issue-close`,
`epic-review`, `prod-verify`, `epic-close` — via routing rows in `~/.claude/rules/reference-loading.md`.
Those rows and that reference live in **global** `~/.claude` config (not shipped in this repo): a fresh
environment must add them before the per-step actions load. See the PR that introduced this page for
the exact rows.

## The four risks — and how this setup answers them

| Risk (from the article)                                           | Mitigation here |
| ----------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| **Comprehension debt** — code you didn't write, didn't understand | Auto-PRs are tiny + mechanical + labelled `triage-loop`; never merge; you review every PR.   |
| **Cognitive surrender** — accepting loop output without opinions | The inbox demands a human decision per finding; "still review what the loop produces."       |
| **Verification gap** — a loop making mistakes unattended | `verify-loop`'s separate checker; refute-by-default; reject-if-uncertain.                    |
| **Token cost** — usage varies wildly on a schedule | Per-run AUTO-PR budget (5); read-only default; a scoped low-budget key for the GHA template. |

## Quick start

1. `/triage` — read your inbox right now (read-only, opens nothing).
2. `/loop 30m /triage` — keep it running while you work.
3. `verify-loop: make \`nx affected -t test lint typecheck\` exit 0; checker = adversarial-reviewer`
   — drive any task to a checker-confirmed finish.
4. To go unattended: set up a `/schedule` routine, or read the CI/CD guardrails and activate
   `.claude/skills/triage/assets/triage-loop.yml`.
