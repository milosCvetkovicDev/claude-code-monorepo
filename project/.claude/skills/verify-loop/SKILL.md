---
name: verify-loop
description: "Run work toward a goal until a VERIFIABLE stop condition is true, graded by a SEPARATE checker — never the agent that did the work. Formalizes loop engineering's '/goal' pattern and 'done is a claim, not a proof'. Use to drive any task to a provable finish (tests pass, lint clean, condition met) where you want to walk away with confidence, especially under /loop or in a Workflow. Do not use for open-ended exploration with no checkable end state, or for autonomous bug-fixing where a single agent suffices (use debug-loop)."
---

# Verify loop

The verification half of loop engineering. A loop running unattended is also a loop making mistakes
unattended — the only thing that lets you walk away is a checker that is **not** the maker. This skill
turns "I think it's done" into "a separate grader confirmed the stop condition is true."

Use it to wrap any maker (an issue implementation, a refactor, a fix) so it cannot declare victory
on its own homework.

## Required input: a verifiable stop condition

Before any work, state the condition as something a machine or an independent agent can check —
not a vibe. Good conditions:

- A command that must exit 0: `nx affected -t test lint typecheck`, `nx test <project>`, `nx e2e ...`
- A specific assertion: "the RED test `<path>::<name>` now passes and no other test regressed"
- A measurable bound: "p95 of `<endpoint>` < 200ms in the bench output"

If you cannot write a checkable condition, **stop** and ask the user for one. An unverifiable goal
cannot be loop-driven safely — that is the point of this skill.

## The loop

Repeat until the checker confirms the condition or a bound is hit:

1. **Maker turn** — do the smallest next increment toward the goal. Run the condition's command
   yourself and capture verbatim output. (Within a `/loop`, this is one iteration; within a Workflow,
   one `agent()` call or pipeline stage.)
2. **Checker turn — a DIFFERENT grader.** Hand the checker ONLY the evidence (diff + the verbatim
   command output / test results), not your narrative. The checker must independently decide whether
   the stop condition is _actually_ met and try to **refute** it (look for: unrelated tests skipped,
   the condition narrowed, output stale, a regression elsewhere). It returns `met: true|false` + why.
   - Prefer a different agent for the checker: `adversarial-reviewer` (diff-only, information-isolated)
     or `code-reviewer`, or in a Workflow a separate `agent()` with a verdict schema. For higher-stakes
     goals, use a stronger model / higher effort for the checker than the maker.
3. **Decide**:
   - Checker `met: true` ⇒ **done.** Report the condition, the proof (command + output), and the
     checker's confirmation. Stop.
   - Checker `met: false` ⇒ feed its reasoning back to the maker and loop (go to 1).

## Bounds (never loop forever)

- **Max iterations**: default 8. If the same failure repeats 3×, stop and report the blocker.
- **Budget**: in a Workflow, gate on `budget.remaining()`; under `/loop`, stop and hand back to the user.
- **No-progress guard**: if two consecutive maker turns produce no change in the condition's output,
  stop — you are stuck, not converging.
- On any bound, write what was tried and the remaining gap; never claim done on a bound exit.

## Patterns

**Under `/loop`** — self-paced verifiable finish:

```
/loop verify-loop: make `nx affected -t test lint typecheck` exit 0; checker = adversarial-reviewer
```

Re-runs each iteration, maker then checker, until the checker confirms green.

**In a Workflow** — maker/checker as pipeline stages (one finding/task verifies the moment its draft
is ready; the grader is a separate agent):

```
pipeline(tasks,
  t => agent(makePrompt(t), {label: `make:${t.id}`, phase: 'Make', isolation: 'worktree'}),
  (made, t) => agent(`Refute that this meets: ${t.condition}. Reject if uncertain.\n${made.evidence}`,
                     {label: `check:${t.id}`, phase: 'Verify', schema: VERDICT}))
```

**Perspective-diverse checking** — for a goal that can fail in several ways, run N checkers with
distinct lenses (correctness / regression / does-it-actually-reproduce) instead of N identical ones,
and require a majority `met: true`.

## Anti-rationalization

| If you're thinking...                   | Remember...                                                         |
| --------------------------------------- | ------------------------------------------------------------------- |
| "I ran the tests, they pass, it's done" | You are the maker. A separate checker confirms, or it isn't proven. |
| "The condition is basically met"        | "Basically" is not a stop condition. It exits 0 or it doesn't.      |
| "Close enough after 8 tries"            | A bound exit is a blocker to report, never a success to claim.      |
| "The checker is overkill here"          | The checker is the only reason you can leave the loop unattended.   |

## Relationship to other skills

- `debug-loop` — autonomous single-agent fix iteration; use when one agent suffices and you do not
  need an independent grader. `verify-loop` adds the separate-checker discipline on top.
- `verification-before-completion` — the one-shot "prove it before you claim it" gate; `verify-loop`
  is its iterating, maker/checker-separated form.
- `triage` — its Step 4 maker→checker pipeline is this skill applied per finding.
- PM ceremony: `tests-generate` writes the RED tests that become this skill's stop condition;
  `issue-close` / `prod-verify` are where you run it. See `docs/loop-engineering.md`.
