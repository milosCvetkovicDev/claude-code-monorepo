# Ultracode workflows — execution plan

> Deep-dive · narrated by [chapter 12 — Running many at once](../12-running-many-at-once.md) · [Contents](../README.md)

> Companion to [chapter 2 — Loops, not prompts](../02-loops-not-prompts.md). Loop engineering replaces **you as
> the prompter**. Ultracode workflows replace the **sequential maker**: instead of one agent doing
> task after task in one context, you author a deterministic script that fans the work out across
> many agents — to be _comprehensive_ (decompose and cover in parallel), _confident_ (independent
> perspectives + adversarial checks before committing), or to take on _scale one context can't hold_
> (migrations, audits, broad sweeps). The leverage point moves from _doing the work_ to _designing
> the fan-out_.

The `Workflow` tool runs a JS script in the background; `agent()` / `parallel()` / `pipeline()`
spawn sub-agents, and `maker ≠ checker` is structural — the agent that writes a thing never grades
it. This page is the execution plan: **when** to reach for a workflow, **which** pattern fits each
implementation phase, and **copy-paste script skeletons** grounded in this monorepo.

Every skeleton in §3 is a complete, loadable script: it opens with the required pure-literal
`export const meta` and defines its schemas. Identifiers marked `// PLACEHOLDER` are the only things
you substitute. (Plain JS only — no TS types; `Date.now()`/`Math.random()`/`new Date()` throw inside a
script.)

## 0. When to reach for a workflow (opt-in only)

Workflows can spawn dozens of agents and burn a large token budget, so they are **opt-in**. Author one
only when:

- the prompt contains the keyword **`ultracode`**, or ultracode is on for the session, or
- the user explicitly asks ("use a workflow", "fan out agents", "orchestrate this with subagents"), or
- a skill/command instructs it.

| Use a workflow when…                                                              | Do it inline (no workflow) when…                       |
| --------------------------------------------------------------------------------- | ------------------------------------------------------ |
| The work decomposes into N independent units you want covered in parallel | A single-file edit or a one-fact lookup |
| You want independent perspectives / adversarial verification before commit | A conversational turn |
| Scale exceeds one context (sweep every BC, audit every chart, port 30 components) | You already know the file and the change is mechanical |

**Hybrid is the norm:** scout inline first (list the components, find the call-sites, scope the diff),
**then** call `Workflow` to pipeline over the discovered work-list. You don't need the shape before the
_task_ — only before the _orchestration step_.

## 1. The pattern toolbox

| Pattern | Shape | Reach for it when |
| ----------------------- | --------------------------------------------------------------------- | -------------------------------------------------------------------- |
| **pipeline** (default)  | each item flows through all stages independently, **no barrier**      | multi-stage per-item work (port→verify, review→refute)               |
| **parallel** (barrier)  | await all thunks, then continue | you genuinely need _all_ results together (dedup, count, early-exit) |
| **loop-until-dry**      | keep spawning finders until K rounds find nothing new | unknown-size discovery (bugs, edge cases, missing exports)           |
| **adversarial verify**  | N skeptics per finding, each prompted to **refute**; kill on majority | promote only findings that survive a refutation attempt |
| **judge panel**         | N independent attempts → parallel judges score → synthesize | wide solution space (architecture, design approach)                  |
| **multi-modal sweep**   | agents each search a different way (by-container/content/entity/time) | one search angle won't find everything |
| **completeness critic** | a final agent asks "what's missing?"                                  | before claiming a sweep/audit is done |

**Default to `pipeline()`.** A barrier is only correct when stage N needs cross-item context from _all_
of stage N-1 (dedup, total count, "compare against the others"). "I need to flatten/map/filter first"
is **not** a barrier — do it inside a pipeline stage.

## 2. Mapping the implementation lifecycle to workflows

The PM ceremony (see [chapter 10 — The ceremony](../10-the-ceremony.md)) stays the backbone; ultracode
accelerates the **parallelizable** steps. Run one workflow **per phase** and read each result before
deciding the next — you stay in the loop between phases.

| Ceremony step | Pattern | Concrete fan-out |
| --------------------------------------- | ------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `prd-new` / `prd-parse` / `arch-create` | **judge panel**                       | Generate 3 independent approaches (MVP-first / risk-first / user-first), score with parallel judges, synthesize from the winner. Maker ≠ judge.                                                                             |
| `epic-decompose`                        | **parallel**                          | One agent per task-file batch authoring `NNN.md` from the epic — a genuine barrier because the renumber/sync step needs the whole set at once.                                                                              |
| `tests-generate`                        | **pipeline** (per AC)                 | Stage 1 author RED tests from each Gherkin AC; stage 2 verifier returns the **verbatim** `nx test` output and must show the spec listed **and failing** (not "no tests found"). RED tests = the verify-loop stop condition. |
| `issue-start` (implement)               | **pipeline** (per task/component)     | Stage 1 maker writes only its files; stage 2 **independent** verifier runs `nx test/typecheck` and returns **verbatim** output. The @acme/ui port→verify (§3.1).                                                          |
| `epic-review`                           | **pipeline** → **adversarial verify** | Per-dimension finders, each finding adversarially verified as it lands (§3.2). The canonical maker/checker split.                                                                                                           |
| design-sync re-sync | **pipeline** (render → grade)         | Each new/changed component renders, then an independent grade stage compares it to the storybook reference. Per-component, no cross-item dependency — the §3.1 shape.                                                       |
| `epic-close`                            | **completeness critic**               | A final agent: "what AC is uncovered, what claim is unverified?" → leftovers route to the triage inbox.                                                                                                                     |

## 3. Script skeletons (grounded in this repo)

### 3.1 Parallel implement: port→verify per unit (the @acme/ui pattern)

The shape that drove the `platform-ui-design-alignment` epic. Each maker writes **only its triplet**
(`Component.tsx` + `.stories.tsx` + `__tests__/*.spec.tsx`); an **independent** verifier proves it,
returning verbatim test output. No maker touches barrels/config (those are stitched in the main session
to avoid write races).

```js
export const meta = {
  name: 'port-components',
  description: 'Port design components to @acme/ui, each independently verified',
  phases: [{ title: 'Port' }, { title: 'Verify' }],
};
const COMPONENTS = args; // PLACEHOLDER: e.g. ['Switch','NavItem','AmountCell'] — scouted inline first
const VERDICT = {
  type: 'object',
  required: ['pass', 'output'],
  properties: { pass: { type: 'boolean' }, output: { type: 'string' }, notes: { type: 'string' } },
};

const results = await pipeline(
  COMPONENTS,
  // Stage 1: the item is the first arg (a stage's signature is (prevResult, originalItem, index);
  // for stage 1 prevResult IS the item).
  (name) =>
    agent(
      `Port ${name} to libs/platform/ui per kit conventions (named exports, typed *Props, brand-*/slate-* ` +
        `tokens + dark:*, one Showcase story, RTL+axe spec). Write ONLY its three files. No barrel/config edits.`,
      { label: `port:${name}`, phase: 'Port' }
    ),
  // Stage 2: drop the item if the maker died (agent() returns null rather than throwing, so the
  // pipeline would otherwise verify a component that was never written). Returning null drops it.
  (portResult, name) =>
    portResult == null
      ? null
      : agent(
          `Adversarially verify ${name}. Run \`nx test platform-ui -- ${name}\` and \`nx typecheck platform-ui\`. ` +
            `Return VERBATIM output. PASS only if the spec shows N≥3 passing (render + behaviour + axe); ` +
            `0 passed or spec-not-listed = FAIL regardless of exit code. Grep the .tsx for indigo-/raw hex → must be empty.`,
          {
            label: `verify:${name}`,
            phase: 'Verify',
            schema: VERDICT,
            agentType: 'adversarial-reviewer',
          }
        ).then((v) => ({ name, ...v }))
);
return results.filter(Boolean);
// Then, in the MAIN session: stitch src/index.ts + src/domain/index.ts barrels, run the full gate, commit.
```

### 3.2 Adversarial review: dimensions → find → refute (epic-review)

Each finding faces **N independent refuters** and survives only on a refute-minority (the toolbox's
"kill on majority"). Refuters default to `refuted: true` when uncertain.

```js
export const meta = {
  name: 'review-diff',
  description: 'Multi-dimension review, each finding refuted by an independent panel',
  phases: [{ title: 'Review' }, { title: 'Verify' }],
};
const REFUTERS = 3; // skeptics per finding; survives on ≥2 NOT-refuted
const DIMENSIONS = [
  { key: 'correctness', prompt: 'Find correctness bugs in the diff.' },
  { key: 'a11y', prompt: 'Find WCAG/axe violations in the diff.' },
  { key: 'perf', prompt: 'Find performance regressions in the diff.' },
];
const FINDINGS = {
  type: 'object',
  required: ['findings'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['title', 'file'],
        properties: { title: { type: 'string' }, file: { type: 'string' } },
      },
    },
  },
};
const VERD = {
  type: 'object',
  required: ['refuted'],
  properties: { refuted: { type: 'boolean' }, why: { type: 'string' } },
};

const reviewed = await pipeline(
  DIMENSIONS,
  (d) => agent(d.prompt, { label: `review:${d.key}`, phase: 'Review', schema: FINDINGS }),
  (review, d) =>
    parallel(
      (review?.findings ?? []).map(
        (f, i) => () =>
          // index i keeps each refuter's label unique even when two findings share a file
          parallel(
            Array.from(
              { length: REFUTERS },
              (_x, k) => () =>
                agent(
                  `Try to REFUTE this ${d.key} finding: "${f.title}" in ${f.file}. Default refuted=true if uncertain.`,
                  {
                    label: `verify:${d.key}:${i}:${k}`,
                    phase: 'Verify',
                    schema: VERD,
                    agentType: 'adversarial-reviewer',
                  }
                )
            )
          ).then((votes) => {
            const survives = votes.filter(Boolean).filter((v) => !v.refuted).length >= 2;
            return { ...f, dimension: d.key, survives };
          })
      )
    )
);
return reviewed
  .flat()
  .filter(Boolean)
  .filter((f) => f.survives); // only findings a majority could not refute
```

### 3.3 Loop-until-dry: find missing exports / edge cases

```js
export const meta = {
  name: 'find-until-dry',
  description: 'Spawn finders until 2 consecutive rounds surface nothing new',
  phases: [{ title: 'Find' }],
};
const FINDERS = args.finders; // PLACEHOLDER: [{ prompt: 'Find unbarrelled exports in libs/platform/ui' }, ...]
const ITEMS = {
  // PLACEHOLDER: the finder's output contract — must include the `items` array keyed below
  type: 'object',
  required: ['items'],
  properties: {
    items: {
      type: 'array',
      items: {
        type: 'object',
        required: ['id'],
        properties: { id: { type: 'string' }, detail: { type: 'string' } },
      },
    },
  },
};
const key = (x) => x.id; // PLACEHOLDER: dedup key

const seen = new Set(),
  confirmed = [];
let dry = 0;
while (dry < 2) {
  // stop after 2 consecutive empty rounds
  const found = (
    await parallel(FINDERS.map((f) => () => agent(f.prompt, { phase: 'Find', schema: ITEMS })))
  )
    .filter(Boolean)
    .flatMap((r) => r?.items ?? []); // guard: a result missing `items` contributes nothing
  const fresh = found.filter((x) => !seen.has(key(x))); // dedup vs ALL seen, not just confirmed
  if (!fresh.length) {
    dry++;
    continue;
  }
  dry = 0;
  fresh.forEach((x) => seen.add(key(x)));
  confirmed.push(...fresh);
}
return confirmed;
```

### 3.4 Budget-scaled depth

`FLEET` scales the per-round fan-out to the turn's token target; the loop keeps going until the budget
is nearly spent. Guard on `budget.total` — with no target, `remaining()` is `Infinity` and the loop
would run to the 1000-agent cap.

```js
export const meta = {
  name: 'find-to-budget',
  description: 'Find bugs at a depth scaled to the turn token budget',
  phases: [{ title: 'Find' }],
};
const BUGS = {
  // PLACEHOLDER: the finder's output contract — `.bugs` is consumed below
  type: 'object',
  required: ['bugs'],
  properties: {
    bugs: {
      type: 'array',
      items: {
        type: 'object',
        required: ['description'],
        properties: { description: { type: 'string' }, file: { type: 'string' } },
      },
    },
  },
};
const FLEET = budget.total ? Math.max(1, Math.floor(budget.total / 100_000)) : 3; // finders per round
const bugs = [];
while (budget.total && budget.remaining() > 50_000) {
  const round = await parallel(
    Array.from(
      { length: FLEET },
      (_x, i) => () =>
        agent(`Find bugs in the changed files (independent pass ${i}).`, {
          phase: 'Find',
          schema: BUGS,
        })
    )
  );
  bugs.push(...round.filter(Boolean).flatMap((r) => r?.bugs ?? []));
  log(`${bugs.length} found, ${Math.round(budget.remaining() / 1000)}k left`);
}
return bugs;
```

## 4. Guardrails (non-negotiable)

- **Maker ≠ checker.** The agent that writes never grades. Use `agentType: 'adversarial-reviewer'` (diff-only,
  information-isolated) or a distinct verifier for the verify stage. "The model that wrote the code is too
  nice grading its own homework." This applies to _every_ §3 pattern, including the budget-scaled loop — pair
  it with a refute stage (§3.2) before acting on its findings.
- **Verifiable stop conditions, never vibes.** RED tests, green `nx affected -t test lint typecheck`,
  `list_files` confirming an upload — machine-checkable evidence, not "looks done."
- **Verify subagent claims independently — they fabricate completions.** Demand **verbatim** tool output and
  a hard acceptance rule (`N≥3 passed`, grep-must-be-empty). A subagent with no `node_modules` will report
  "expected RED" without running anything.
- **No write races.** Shared config + barrels (`src/index.ts`, `tsconfig.base.json`, `theme.css`) are edited
  in the **main session**; fan-out agents create only their own files. Use `isolation: 'worktree'` on a
  fan-out stage only when its agents mutate the same files in parallel (it adds worktree setup + disk per
  agent). _Distinct_ from the ceremony's per-issue worktree — that isolates whole issues at
  `issue-start`, not stages within one workflow.
- **The loop opens PRs but never merges.** No `--admin` / `--no-verify` / auto-merge from a workflow. The
  human gate is branch protection + the required checks (`Validate Terraform`, `ci-gate`, `platform-ci-gate` —
  path-filtered, so a docs/non-infra PR may legitimately need an admin merge by a human) + the FD's prod
  sign-off. `contents: write` in a GHA token _can_ merge via the API — branch protection, not token scope,
  is what holds the line (see `.claude/skills/triage/assets/triage-loop.yml`).
- **No silent caps.** If a workflow bounds coverage (top-N, no-retry, sampling), `log()` what was dropped.
- **Outward-facing publishes stay human-gated.** Anything that writes to an external system (claude.ai/design
  upload, GitHub issue close, deploy) is a checkpoint — self-certified quality claims (e.g. a visual "match"
  grade) must be transparently labelled as agent assessment, and the harness may (correctly) require a human.

## 5. Worked example — the `platform-ui-design-alignment` epic

What ultracode bought, and where the human stayed in the loop:

- **Implement (T1–T7):** parallel **port→verify** (§3.1) across the new primitives — each maker wrote its
  triplet, an independent verifier proved it RED→GREEN. **Review:** two expert-panel rounds + an
  **adversarial review** of the ports (§3.2); every surviving finding was actioned (Switch double-opacity,
  dev-name guard, focus-ring) + ~15 coverage tests.
- **Re-sync (T8):** the design-sync converter rebuilt the bundle and graded the components the diff flagged
  (vs the prior anchor: Badge changed + 8 added, of which the 4 genuinely-new primitives were absent from the
  live project) against the storybook reference; the upload took the live project from 61 → **65** components
  (the 4 new primitives + a new `domain/` group), confirmed via `list_files`.
- **Gotchas the loop surfaced (now guarded):** `nx build-storybook --output-dir` is **CWD-relative** → the
  fresh storybook landed under `libs/platform/ui/.design-sync/sb-reference`, not the repo-root copy `resync.mjs`
  read, silently dropping the 4 new components from the bundle (caught by `window.AcmeUi: 61 ≠ 65` before
  upload). And the harness **blocked self-certified `match` grades** from being written/published as
  "verified" — the human checkpoint on an outward-facing publish. See `.design-sync/NOTES.md`.

## 6. Quick start

1. Scout inline → build the work-list (`nx show projects`, `git diff --name-only`, list the components).
2. `Workflow({ script })` with a `pipeline()` over that list, maker stage + independent verifier stage.
3. Read the returned result; stitch shared files + run the full gate in the **main session**; commit.
4. For review/audit: a `pipeline` of per-dimension finders, each finding adversarially refuted (§3.2).
5. Iterate workflow-per-phase; route any leftover to the **triage inbox** at `epic-close`.
