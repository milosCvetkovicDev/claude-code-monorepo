# Loop engineering in the PM ceremony

Loaded on-demand by the loop-touchpoint PM steps. Loop engineering = a system prompts the agents, not
you. Two disciplines weave through the ceremony:

- **Maker ≠ checker** — the agent that does the work never grades it. A _separate_ agent (different
  instructions, often a stronger model) confirms. `done` is a claim, not a proof.
- **Verifiable stop conditions** — every "is it done?" must be machine-checkable (a command that
  exits 0, a named RED test that goes GREEN, a measured bound), never a vibe.

If the project defines them (e.g. Acme): `verify-loop` is the maker/checker stop-condition skill;
`triage` is the discovery loop whose inbox catches leftovers. Use them where flagged below.

## Per-step actions

- **prd-new / prd-parse** — State lives on disk (the PRD). Write acceptance criteria as **verifiable
  conditions** (a test that will pass, a command that will exit 0), so later steps can prove them.

- **arch-create** — Generate independent approaches and score them with parallel **judge** agents;
  synthesize from the winner. The judges are not the proposer.

- **epic-decompose** — Decompose so independent tasks can run as **parallel makers in isolated
  worktrees**. Note which tasks are mechanical/safe vs judgment-heavy.

- **tests-generate** — The hinge. The RED tests you emit here **are** the verify-loop stop condition.
  Make them concrete and runnable (`nx test <project>`, a named spec). State the exact command that
  must exit 0 for the issue to be "done."

- **readiness-check** — A **checker** gate before sync: an independent reviewer, not the author.

- **issue-start** — Run the implementation as a **maker** in its own worktree (`isolation: worktree`).
  Keep it to the smallest increment toward the stop condition.

- **issue-close** — Do **not** let the maker self-certify. Run `verify-loop` (or at minimum a separate
  checker): confirm the named RED test is GREEN and nothing else regressed, with verbatim output.

- **epic-review** — The canonical maker/checker split. Feed reviewers the **diff** (information-isolated
  where possible, e.g. `adversarial-reviewer`); forbid git mutation; re-check the branch after.

- **epic-merge** — Gates + green CI through the github connector. Never `--admin` / `--no-verify` to
  force a merge; fix the failure instead.

- **prod-verify** — Verification against **real** evidence: cite a production query/result, not "looks
  fine." This is verify-loop pointed at prod.

- **epic-close** — Update state and route any leftover/unhandled items to the **triage inbox** so the
  next loop run picks them up — nothing is silently dropped.

## Anti-patterns

- Maker grading its own homework → always a separate checker.
- "Basically done" / "tests probably pass" → run the condition, paste the output.
- Bound/iteration-limit hit reported as success → it's a blocker, report the gap.
- Findings discovered mid-epic but out of scope → inbox them, don't drop them.
