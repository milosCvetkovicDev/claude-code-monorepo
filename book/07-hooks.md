# 7 · Hooks — what must never happen

> Part II — The Layers · [← Agents](06-agents.md) · [Contents](README.md) · [Next: Connectors →](08-connectors.md)

---

## The problem hooks solve

Every layer so far speaks to the model. Context informs it, skills instruct it, agents
advise and audit it — and the model, being a model, weighs all of that against whatever
it currently believes and *decides*. Usually well. But "usually" is not a security
posture, and some rules must hold precisely in the moment the model has convinced
itself an exception is warranted. That moment is real: the classic incident shape of
agentic coding is not malice, it is *confident helpfulness* — a force-push to fix
history, a `git clean` to tidy up, a merge because everything looked green.

A **hook** is a shell script the harness runs at a lifecycle event, outside the model's
control. It cannot be persuaded, doesn't read the conversation, and its exit code is
law. If instructions are onboarding and skills are training, hooks are the building's
physics: the door is locked whether or not you have a good reason.

The inventory: **34 scripts** in [`project/.claude/hooks/`](../project/.claude/hooks/),
**28 wired** across **8 lifecycle events** in
[`project/.claude/settings.json`](../project/.claude/settings.json) (the remaining six
are utilities and superseded variants, kept on disk).

## A session's lifecycle, hook by hook

Reading [`settings.json`](../project/.claude/settings.json) top to bottom is reading a
session's biography:

**`SessionStart`** — before the first prompt: `env-check.sh` (Node version, Docker,
environment), `git-sync.sh` (pull main, or merge main into the feature branch),
`load-github-context.sh` (open PRs and issues into context — and the triage inbox,
which is how the discovery loop's findings surface without being asked for), and
`worktree-doctor.sh` (drift check across the parallel-workspace registry,
[chapter 12](12-running-many-at-once.md)).

**`PreToolUse`** — the gate, matched per tool. Five scripts guard `Bash`:
`block-dangerous-commands.sh` (below), `enforce-nx-commands.sh` (bare `jest`/`tsc` →
use Nx), `dev-ephemeral-close-check.sh`, `pre-commit-checks.sh` (typecheck + affected
tests *before a commit is even attempted* — 300s timeout, because it gates real work),
and `launch-readiness-gate.sh`. Two guard `Write`/`Edit`:
`protect-sensitive-files.sh` (`.env*`, `*.pem`, `*.key`, `credentials.json` —
unwritable) and `source-driven-dev.sh`.

**`PostToolUse`** — the cleanup-and-validate pass after every write: `auto-format.sh`
(Prettier, so formatting is never a review comment), then six *validators* that
immediately check what was just written — `validate-infra-files.sh`,
`validate-security.sh`, `enforce-nestjs-patterns.sh`, `validate-event-contracts.sh`,
`validate-helm-charts.sh`, `validate-k8s-manifests.sh`. An invalid Helm chart is caught
at the moment of authorship, seconds after the mistake, not twenty minutes later in CI.

**`Stop`** — the quality gate: `quality-gate-tests.sh` runs affected tests when
uncommitted changes exist, so the model cannot end a turn on broken code without the
breakage being surfaced. Plus `learnings-reminder.sh` — a nudge toward the
`session-learnings` skill, layer 6's front door.

**`Notification` / `SessionEnd` / `Setup` / `UserPromptSubmit`** — desktop
notifications when input is needed, resource cleanup (Nx daemon stopped, orphaned
processes killed), deep-cache cleanup on `claude --maintenance`, and a per-prompt
reminder tied to ephemeral dev instances.

The wiring itself teaches a few small lessons: every entry quotes
`"$CLAUDE_PROJECT_DIR"` (paths with spaces), every entry sets an explicit `timeout`
sized to its job (5s for a grep-gate, 300s for a test run), and the long one sets a
`statusMessage` so a slow gate reads as *working*, not *hung*.

## Anatomy of the flagship: `block-dangerous-commands.sh`

[The script](../project/.claude/hooks/block-dangerous-commands.sh) opens conventionally
— parse the tool input from stdin, match the command against a pattern list
(`git push --force` to main, `git reset --hard origin/main`, `rm -rf /`, `git clean
-fd`, fork bombs, disk-destroyers), exit 2 to block. Any agent harness should have this
much.

The second half is where it becomes *this* setup's hook: the PR-merge guard, which is
[chapter 2](02-loops-not-prompts.md)'s "the loop never merges" made mechanical. It
blocks `gh pr merge`, `gh pr enable-auto`, `gh pr review --approve|--dismiss`, the REST
merge endpoint *and* the GraphQL `mergePullRequest` mutation — every road to a merge
the CLI offers — unless the command carries a deliberate, human-typed prefix:

```
BLOCKED: PR merge / approval is gated (loop-engineering 'never merge').
For a deliberate human merge, confirm with the user, then PREFIX the command:
  ALLOW_PR_MERGE=1 gh pr merge ...
```

Read the comment block around it in the source — it is unusually honest engineering
writing. Three of its judgments are worth pulling out:

- **Anchoring over matching.** Triggers fire only at a *command start* (line start,
  after `;`/`&&`/`|`, after env-var assignments), so an `echo` that merely *mentions*
  `gh pr merge` doesn't false-block, while an env-prefixed real invocation still trips.
  Naive substring matching fails in both directions; the memory tree records the
  inverse bug ([`feedback_force_push_hook_main_substring`](../global/memory/feedback_force_push_hook_main_substring.md)
  — a force-push guard once matched "main" as a substring inside another word).
- **The bypass is position-anchored too.** `ALLOW_PR_MERGE=1` counts only as an
  assignment at the very front of the command — not embedded in a string, a comment,
  or a `=10` value. An escape hatch that can be triggered accidentally (or smuggled
  in) is not an escape hatch.
- **The threat model is stated in the file.** *"Best-effort guard, NOT a sandbox …
  BRANCH PROTECTION is the real merge guarantee — this hook only stops the
  well-behaved loop from merging."* A hook that knows what it is not protecting
  against is worth ten that don't. The same section adds a production-write guard with
  the same convention: prod *reads* flow freely, mutating SQL needs
  `ALLOW_PROD_WRITE=1`.

## Design rules for a hook layer

Distilled from the 34, for anyone building their own:

1. **Fail open on ambiguity, closed on match.** Every script exits 0 when it can't
   parse its input. A hook that blocks work on its own bugs gets deleted within a week,
   and then protects nothing.
2. **Escape hatches are prefixes, never disables.** `ALLOW_PR_MERGE=1`,
   `ALLOW_PROD_WRITE=1`, `SKIP_HOOKS=1` — visible in the command, greppable in
   history, decaying automatically (the next command is guarded again). Contrast a
   commented-out hook, which is a permanent disable wearing a temporary costume.
3. **Warn where blocking would be wrong.** A force-push to a *feature* branch warns;
   to main it blocks. `enforce-nx-commands.sh` reminds rather than refuses. Guards
   that overreach train users to bypass them.
4. **Guard against your own recursion.** `quality-gate-tests.sh` checks
   `stop_hook_active` before running — a Stop hook that triggers work that triggers
   the Stop hook is an infinite loop with good intentions.
5. **Price the gate honestly.** The install guide's warning bears repeating: the Stop
   test-gate is excellent when affected tests finish in ~2 minutes and miserable
   otherwise. *"Don't disable it and keep the reputation of having it."*

## Primary sources

- [`project/.claude/settings.json`](../project/.claude/settings.json) — the full wiring, all 8 events
- [`project/.claude/hooks/block-dangerous-commands.sh`](../project/.claude/hooks/block-dangerous-commands.sh) — the flagship, comments included
- [`project/.claude/hooks/`](../project/.claude/hooks/) — all 34, plus the original [`README.md`](../project/.claude/hooks/README.md) quick-reference
- [`project/.claude/hooks/quality-gate-tests.sh`](../project/.claude/hooks/quality-gate-tests.sh) — the Stop gate, recursion guard included

---

> **Next:** the outer boundary — which real systems the agent can reach, and the
> permission surface that decides what it may do when it gets there.
> [Chapter 8 — Connectors: what it can touch →](08-connectors.md)
