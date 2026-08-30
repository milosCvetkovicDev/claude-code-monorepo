# Triage autonomy policy

This is the contract that decides what the triage loop is allowed to do **without a human**.
Read this before classifying any finding. When in doubt, a finding is INBOX, not AUTO.

The loop may **open pull requests** but may **never merge** them. Branch protection, required
checks, and a human production sign-off already sit between an open PR and production — that human
gate is the point. The loop's job is to _propose verified work_, never to _land it_.

## Decision: AUTO vs INBOX

A finding is **AUTO** (eligible for a maker→checker→PR pipeline) only if **all** are true:

1. It falls in the **safe-category allowlist** below.
2. It does **not** touch any path on the **hard NO-list** below.
3. A failing signal reproduces it (a red check, a lint error, a failing test) — never a hunch.
4. The fix is small and mechanical: roughly **≤ ~40 changed lines across ≤ 3 files**.
5. The **separate checker** (a different agent than the maker — see SKILL.md Step 4) signs off,
   AND the repo's own gates pass locally (`nx affected -t lint test typecheck`, pre-commit hook).

Anything that fails even one test is **INBOX**: it is written to the inbox state file with a
recommended action for a human. The loop never silently drops a finding.

## Safe-category allowlist (AUTO-eligible)

| Category | What's allowed | Hard limit |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| Lint / format | `nx format:write` on affected projects (Prettier; purely cosmetic)                                                                       | Prettier only. `eslint --fix` is NOT AUTO — see STOP rules |
| Dependency bumps | **patch / minor** bumps that already have a green dependabot-style PR or pass affected build+test | Never major; never if lockfile drift fails CI                                |
| Docs / typos | Markdown, comments, JSDoc, obvious string typos | No behavioral change |
| Flaky-test quarantine | Mark a _proven_ flaky test (intermittent on identical SHA) with the project's skip/retry + **always open a tracking issue** and label it | Never quarantine a test that fails deterministically — that hides a real bug |
| Obvious one-liner fix | A one-line null-check / off-by-one / wrong-constant fix **that a new failing test reproduces** and the checker confirms | Must ship the reproducing test in the same PR                                |

PRs from the loop carry the label `triage-loop` and a body that states: the finding, the
reproducing signal, the maker's change, and the checker's verdict. Open as **draft** if the
checker raised any non-blocking concern.

### Category STOP rules (the safe/unsafe boundary — enforce, don't assume)

- **AUTO lint = `nx format:write` only** (Prettier, whitespace/quotes/semicolons — cannot change
  behaviour), scoped to exclude every hard-NO path below. **`eslint --fix` is NOT auto-eligible:**
  its autofixes (`prefer-const`, `no-unused-vars` removal, `no-floating-promises`, import reordering)
  can change runtime behaviour. If an eslint autofix is genuinely wanted, route it through the
  one-liner gate (reproducing test + checker), never the lint category.
- **Flaky quarantine requires proof, not a guess.** `discover.sh` only reports the latest run — it
  does NOT establish flakiness. Before quarantining, the maker MUST re-run the suspect test **≥5×
  on the exact failing SHA** and attach the pass/fail counts; the checker MUST confirm genuine
  intermittency from that output. If it fails on every run it is **deterministic → INBOX as a real
  bug**, never quarantined. Always open a tracking issue for any quarantine.

## Hard NO-list (always INBOX — never AUTO, no exceptions)

Never auto-edit, and never open a PR that touches:

- `infra/**`, `charts/**`, `.github/**`, any Terraform / Helm / K8s / ArgoCD / CI-CD file
- Any database migration (`**/migrations/**`) or schema change
- Secrets, env files, Key Vault, credentials, auth/identity logic, token/session handling
- **Financial logic** — anything that computes or attributes money. It is specified by worked
  examples and signed off by a human, so an autonomous edit has no way to know it is right.
  Enforce this one by **path glob**, not by description: a path-scoped action (`nx format:write`,
  a codemod, an autofix) does not read the description, so a rule expressed only in prose is not a
  rule. The globs are therefore listed here, in the policy itself:
  - money domain — `libs/commission/**`, `apps/domain-api/**`,
    `apps/platform/commission-service/**`, `apps/legacy-api/src/services/commission/**`
  - its end-to-end suite — `apps/domain-web-e2e/**` (an e2e spec is where a formula's expected
    numbers are written down, so editing it edits the specification)
  - external posting / OAuth adapters — `apps/legacy-api/src/api/erp/**`,
    `apps/legacy-api/src/models/api/erp/**`, `apps/acme-mcp/src/infrastructure/erp/**`
  - anything else doing decimal math (`Big.js`) or period-boundary rules, wherever it lives

  Extend the list whenever a money-touching project is added. A path that is not on it is
  AUTO-eligible by default, and that default is the wrong way round for this category — so
  adding the project and adding its glob is one change, not two.
- Production config, deploy workflows, or anything that runs against a live environment
- Anything labelled as needing a named human's sign-off, `epic:*` scope decisions, or flagged in
  CLAUDE.md as gated

Also never:

- **Merge** a PR, approve a PR, or dismiss a review
- Use `--no-verify` or `--admin`, or skip any hook (use `SKIP_HOOKS=1` only where `.husky/*`
  already sanctions it; never to bypass a real failure)
- Force-push, rebase shared branches, delete branches you did not create, or touch `main` directly
- Run any destructive command (`terraform apply/destroy`, `kubectl delete`, `az ... delete`,
  `DELETE`/`UPDATE` SQL, `rm -rf`) — these are confirmation-gated for humans only
- Spend more than the per-run budget (default: stop after **5 AUTO PRs** per run; the rest → INBOX)

## Maker / checker discipline

- The agent that **writes** the fix must **not** be the agent that **grades** it. "The model that
  wrote the code is too nice grading its own homework."
- Maker: an isolated git worktree (`isolation: worktree`), drafts the smallest fix + a reproducing test.
- Checker: a **different** agent — prefer `adversarial-reviewer` (diff-only, information-isolated) or
  `code-reviewer`, prompted to **refute** the fix. Default to "reject if uncertain." Verify the agent
  type resolves before relying on it (these are runtime/plugin-provided; in a headless run they may
  be absent — see the STOP rule).
- **STOP rule — no checker, no PR.** If a distinct checker agent cannot be dispatched (unknown agent
  type, headless run without the plugin, dispatch error), the finding is **demoted to INBOX**, never
  auto-PR'd. The maker must never grade its own work, and "I couldn't find a checker" is not a pass.
- Two checker rejections on the same finding ⇒ demote to INBOX with the checker's reasoning attached.
- `done` is a claim, not a proof. The checker's pass + green local gates are the proof.
