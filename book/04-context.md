# 4 · Context — what it always knows

> Part II — The Layers · [← The six layers](03-the-six-layers.md) · [Contents](README.md) · [Next: Skills →](05-skills.md)

---

## The problem context solves

An agent with no context re-derives your conventions from scratch, every session, and
gets them *almost* right — which is worse than wrong, because almost-right survives
review. It runs `jest` directly in an Nx monorepo and misses the cache. It writes
camelCase column names into a snake_case database. It starts a dev server that hangs
the shell. None of these are intelligence failures; they are onboarding failures. The
context layer is the onboarding document — except it must onboard a colleague who
arrives with total amnesia, every single session, and bills by the token.

That last clause is the design constraint people miss. Context is not free: every
resident instruction occupies the same window the actual work needs. So the layer is
really two problems in one — *what must always be present?* and *what can wait until
it's needed?* — and this setup answers them with three tiers.

## Tier 1 — always resident: the `CLAUDE.md` hierarchy

Nineteen `CLAUDE.md` files sit in the [`project/`](../project/) tree at their original
paths, plus one at machine level. They form a hierarchy that loads narrowest-relevant:
the root file always, the nested ones when work enters their directory.

**The machine-level file is thirteen lines.** Read
[`global/CLAUDE.md`](../global/CLAUDE.md) in full — it fits on one screen. It states a
writing-style rule, names the development workflow (the full PM sequence from
[chapter 10](10-the-ceremony.md)), and compresses the entire loop-engineering discipline
into one paragraph. That is all a *machine-scoped* file should carry, because everything
project-specific belongs to a project.

**The project root file is ~200 lines** —
[`project/CLAUDE.md`](../project/CLAUDE.md) — and it is worth reading as a specimen,
because almost every line is a scar with a rule grown over it:

> - Never start dev servers (`nx serve`, `npm run dev`) in Claude shell — Nx hangs in
>   non-interactive mode. Output the exact commands for the user to run in their own
>   terminal instead.
> - Before running any destructive command (`git push --force`, `terraform destroy`,
>   `DELETE`/`UPDATE` SQL, `az resource delete`, `rm -rf`), always show the command and
>   ask for explicit confirmation.
> - Limit tangential debugging to 2-3 attempts, then ask user.
> - Fix code to match specs, NOT docs to match code.

Notice what these have in common: none of them is a *style preference*. Each one
prevents a concrete, previously-experienced failure — a hung shell, a destroyed
resource, a rabbit-hole afternoon, docs quietly rewritten to bless a bug. The install
guide's advice for writing your own is the same idea from the other side: *"write what
a competent new hire would need on their first day and no more."*

**The seventeen nested files** scope instructions to where they're true. A sample of
what lives where:

| File                                                                      | What it scopes                                                                  |
| ------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| [`apps/legacy-api/CLAUDE.md`](../project/apps/legacy-api/CLAUDE.md)       | the Express/TypeORM monolith's patterns — kept apart from the platform's        |
| [`apps/domain-api/CLAUDE.md`](../project/apps/domain-api/CLAUDE.md)       | a Bun + Elysia service: its Drizzle migration discipline, Docker platform flags |
| [`libs/platform/ui/CLAUDE.md`](../project/libs/platform/ui/CLAUDE.md)     | the design-system kit — "where new UI primitives are born" (policy AD-7)        |
| [`infra/CLAUDE.md`](../project/infra/CLAUDE.md)                           | Terraform: the resources that must never be destroyed, the IDs never hardcoded  |
| [`libs/data-seeding/CLAUDE.md`](../project/libs/data-seeding/CLAUDE.md)   | the test-data factories and their dependency order                              |

The payoff of nesting is *precision without residency*: the monolith's TypeORM rules
never spend tokens in a session about the React front end, and vice versa. The cost is
drift risk — nineteen files can disagree — which is why each nested file opens by
deferring to the root for anything project-wide.

## Tier 2 — always resident, but portable: the eight rules

[`global/rules/`](../global/rules/) holds eight files that travel to every project on
the machine. They are procedural, not informational — less "here is our stack" and more
"here is how an operation is always done":

- [`standard-patterns.md`](../global/rules/standard-patterns.md) — the house style for
  command output: fail fast, trust the system, minimal output. Contains the memorable
  inversion *"Simple is not simplistic"* and a list of anti-patterns (over-validation,
  verbose ceremony, permission-asking) with corrections.
- [`github-operations.md`](../global/rules/github-operations.md) — every `gh` write
  operation checks the remote first, so a template repo can never be accidentally
  synced into. Trust the CLI; handle failure at failure time.
- [`datetime.md`](../global/rules/datetime.md) — timestamps come from `date -u`, never
  from the model's imagination. Flagged HIGHEST PRIORITY, because a plausible-looking
  hallucinated timestamp in frontmatter is undetectable later.
- [`frontmatter-operations.md`](../global/rules/frontmatter-operations.md) /
  [`strip-frontmatter.md`](../global/rules/strip-frontmatter.md) — how the PM ceremony's
  YAML state is read, updated, and cleaned before anything is posted to GitHub.
- [`path-standards.md`](../global/rules/path-standards.md) — no absolute paths with
  usernames in anything public-facing; a privacy rule that earned its place (see
  [`SANITIZATION.md`](../SANITIZATION.md) for what home paths leak).
- [`cicd-guardrails.md`](../global/rules/cicd-guardrails.md) — before touching *any*
  CI/CD file, read the matching reference first; never write GitHub Actions syntax,
  Docker commands or Helm templates from memory; SHA-pin every action. The rule exists
  because CI/CD is where plausible hallucination is most expensive: a wrong flag fails
  twenty minutes later, in a queue, on someone else's runner.
- [`reference-loading.md`](../global/rules/reference-loading.md) — the routing table.
  Which brings us to tier 3.

## Tier 3 — loaded on demand: references and the routing table

Sixteen documents in [`global/references/`](../global/references/) hold the deep
material: CI/CD patterns with verified action versions, git worktree operations, the
test-first development contract, agent-coordination protocols, the readiness gate's
checklist. None of them is resident. Instead,
[`reference-loading.md`](../global/rules/reference-loading.md) — itself resident, and
small — maps *triggers* to *files* (abridged):

> | Trigger                                                   | Read                                                          |
> | --------------------------------------------------------- | ------------------------------------------------------------- |
> | `/pm:tests-generate`                                      | `workflow/test-first-development.md`, `workflow/loop-engineering.md` |
> | Editing `.github/workflows/*.yml`                         | `cicd/github-actions-patterns.md`, `cicd/verified-versions.md` |
> | Editing `Dockerfile*` or `docker-compose*.yml`            | `cicd/docker-patterns.md`                                     |
> | Git worktrees                                             | `git/worktree-operations.md`                                  |
>
> Do NOT preemptively read these files. Only read them when the user invokes the
> relevant command or explicitly asks about the topic.

This is the context layer's central trick, and it scales where flat context cannot: the
*index* is always present, the *content* almost never is. A session that never touches
CI/CD never pays for the CI/CD patterns; the session that does gets the full document,
current versions and all, at exactly the moment of need. The same shape recurs at layer
six — [`MEMORY.md`](../global/memory/MEMORY.md) is an index over 172 memory files, and
chapter 9 will show it under load.

## What context deliberately does *not* do

Two boundaries keep this layer honest.

**Context does not enforce.** "Never `git push --force` to main" appears in a
`CLAUDE.md` — and *also* in a PreToolUse hook that blocks the command outright. The
instruction teaches; the hook guarantees. When you find a rule stated at this layer
only, that is a considered judgment that advisory strength is enough; when the rule
matters mechanically, [chapter 7](07-hooks.md) has it again in executable form.

**Context does not accumulate learnings.** A hard-won gotcha does not get appended to
`CLAUDE.md` — that path leads to a 2,000-line file that is all residency and no
hierarchy. Learnings go to the memory tree ([chapter 9](09-memory.md)), which has an
index, a taxonomy, and an archive tier for exactly that purpose. `CLAUDE.md` stays at
"first day" material; memory holds month seven.

## Primary sources

- [`global/CLAUDE.md`](../global/CLAUDE.md) — the whole machine scope, 13 lines
- [`project/CLAUDE.md`](../project/CLAUDE.md) — the root instruction file
- [`project/apps/`](../project/apps/), [`project/libs/`](../project/libs/) — the nested files, in place
- [`global/rules/`](../global/rules/) — the eight resident rules
- [`global/references/`](../global/references/) + [`reference-loading.md`](../global/rules/reference-loading.md) — the on-demand tier and its router

---

> **Next:** the layer that turns "here is what we know" into "here is how we do things"
> — 71 skills, what makes one worth writing, and the anatomy of the two that run the
> loops.
> [Chapter 5 — Skills: how work is done here →](05-skills.md)
