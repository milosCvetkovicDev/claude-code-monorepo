# 8 · Connectors — what it can touch

> Part II — The Layers · [← Hooks](07-hooks.md) · [Contents](README.md) · [Next: Memory →](09-memory.md)

---

## The problem connectors solve

An agent confined to the filesystem can only reason about the world; it cannot check
it. It guesses at column names instead of querying the schema, reads a workflow file
instead of the workflow's actual failing run, and "verifies" a deployment by re-reading
the manifest that describes it. The connector layer is what upgrades claims into
observations — and, symmetrically, it is the layer where an agent stops being sandboxed
and starts touching systems that matter. So it is really two designs in one: **reach**
(which systems, through what interfaces) and **restraint** (what is allowed once
there). This setup is more instructive about the second than the first.

## Reach: the MCP servers

[`project/.mcp.json`](../project/.mcp.json) declares two servers:

**`azure`** — the stock Azure MCP server, giving structured access to the cloud estate
(Container Apps, AKS, Key Vault, Application Insights, Monitor) instead of a thicket of
memorized `az` incantations.

**`acme-mcp`** — the interesting one: a **custom, in-repo MCP server**
([`project/apps/acme-mcp/`](../project/apps/acme-mcp/)) that the monorepo builds for
its own assistant. Its tools are the questions this team actually asked mid-session:
database health and job-queue statistics, ERP-sync debugging (pending syncs, failed
jobs, token status), entity-schema and route-tracing lookups, Application Insights
error queries, deployment slot status. Note the config detail in
[`.mcp.json`](../project/.mcp.json): its credentials arrive as
`${DB_PASSWORD:-}`-style environment expansions — the config file commits the *shape*
of access, never a secret.

The custom server is a pattern worth generalizing. The alternative to `acme-mcp` is
the model reconstructing each of those answers from raw SQL and `az` CLI calls every
time — slower, permission-hungrier, and wrong more often. Wrapping your platform's ten
most-asked runtime questions into an MCP server is the connector-layer equivalent of
writing a skill: it converts a repeated improvisation into a reliable primitive.

Beyond `.mcp.json`, further connectors arrive as **plugins**:
[`global/settings.json`](../global/settings.json) enables 13 of the 41 marketplace
plugins it lists — github, playwright, context7, typescript-lsp, superpowers,
agent-skills and friends — and the project adds the Nx plugin (whose MCP tools the root
`CLAUDE.md` insists on for generator work). The 28 explicit `false` entries are not
noise; they are decisions. A connector surface, like a fleet, is curated: every enabled
plugin is context the model carries and capability someone must reason about.

## Restraint: the permission surface

The permission config across the two `settings.json` files is small enough to read in
a minute and dense enough to teach three lessons.

**The deny-list protects what must never leak** —
[`global/settings.json`](../global/settings.json):

```json
"deny": [
  "Read(/~/.ssh/**)",
  "Read(/~/.aws/**)",
  "Read(/~/.azure/**)",
  "Read(./**/*.pem)",
  "Read(./**/*.key)",
  "Read(./**/id_rsa)",
  "Read(./**/.env.production)",
  "Read(./**/.env.production.local)"
]
```

Credentials and key material are *unreadable* — not "please don't read", but the tool
call fails. This overlaps deliberately with the `protect-sensitive-files` hook from
[chapter 7](07-hooks.md), which makes the same paths *unwritable*: two mechanisms, two
failure modes covered. The install guide calls copying this deny-list "the cheapest
safety in the whole setup," and it is.

**The project deny-list enforces the autonomy posture** —
[`project/.claude/settings.json`](../project/.claude/settings.json):

```json
"deny": [
  "mcp__plugin_github_github__merge_pull_request",
  "mcp__plugin_github_github__pull_request_review_write"
]
```

This is the fourth and final layer of "the loop never merges"
([chapter 2](02-loops-not-prompts.md)): the skill states it, the hook gates the CLI,
this denies the MCP route, and branch protection backstops them all. A rule this
load-bearing gets enforced at every interface it could travel through.

**The allow-list grants *scoped* trust, not categories.** The global allows are
surgical: `psql` to one named production host, `az keyvault *`, `az monitor *`,
`terraform -chdir=infra/modules/network validate` — even a single fully-specified
log-tail command, wrapped in `gtimeout 15`. Contrast the shape of what is *not* there:
no `Bash(*)`, no blanket `az *`, no generic database access. Each allow answers "what
do I do often enough that the prompt is friction, and safely enough that skipping the
prompt is fine?" — and nothing else. Note also what the *pairing* achieves: production
`psql` is allowed (reads must be cheap during an incident), while the
`ALLOW_PROD_WRITE=1` hook guard from chapter 7 catches mutating SQL on that same
connection. Allow the channel, gate the verbs.

## Telling the environment the truth

The most unusual block in [`global/settings.json`](../global/settings.json) is
`autoMode.environment`: eight plain-English statements describing the operating
context — who the organization is, which GitHub org is company-owned and pushable,
which cloud subscription is in play, which domains are trusted, and which
infrastructure operations are normal to *edit* but confirmation-gated to *apply*:

> "Infrastructure as code: Terraform files (infra/ directory), Helm charts (charts/
> directory), Kubernetes manifests. Editing these files is normal development work,
> but applying them to live infrastructure requires explicit user confirmation. This
> includes: terraform apply/destroy, helm upgrade/uninstall, kubectl apply/delete,
> argocd sync/app delete."

This is connector policy in prose: instead of enumerating every risky command, it
states the *principle* (edit freely, apply deliberately) once, and the model applies
it to commands no denylist author thought of. It complements the mechanical layers the
way case law complements statute — hooks catch the enumerable, environment statements
cover the long tail.

## The boundary, drawn in one paragraph

Put the pieces together and the agent's world has a legible shape: it can **see**
almost everything (code, cloud state, CI, database health — minus credentials), **do**
routine engineering freely (edit, test, format, plan), **operate** scoped tools
without friction (the allow-list), and is **stopped at exactly four kinds of doors**:
secrets (deny + hook), merges (deny + hook + protection), production mutation (hook
prefix + confirmation), and infrastructure apply (environment statement +
confirmation). Everything in this chapter exists to make that sentence true even on
the model's most confident day.

## Primary sources

- [`project/.mcp.json`](../project/.mcp.json) — server declarations, env-var secret shape
- [`project/apps/acme-mcp/`](../project/apps/acme-mcp/) — the custom MCP server, with its own `CLAUDE.md`
- [`global/settings.json`](../global/settings.json) — plugins, allow/deny, `autoMode.environment`
- [`project/.claude/settings.json`](../project/.claude/settings.json) — the merge-tool denies, next to the hook wiring

---

> **Next:** the last layer — the one that makes the other five cumulative. Seven months
> of scar tissue, indexed in 90 lines.
> [Chapter 9 — Memory: what survives →](09-memory.md)
