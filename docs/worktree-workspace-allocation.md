# Worktree workspace allocation

You have one monorepo and several things in flight at once: a feature branch, a hotfix, a
pull request you are reviewing, and an agent that wants somewhere to try something
destructive. `git worktree` gives you four checkouts cheaply. It does not give you four
_workspaces_. The moment two of them run, both bind port 3000, both start a container named
`repo-db-1`, and both point at the database `app_development`. The second one fails to boot,
or — much worse — succeeds and silently writes into the first one's data. The answer is to
stop treating "which ports does this checkout use" as something a human decides, and make it
a **derived** property of a single small integer allocated to the workspace: every port,
database name and Docker Compose project name for workspace _n_ falls out of the arithmetic
`Port = base + (n - 1)`, recorded in a registry that allocates and releases slots, and
materialised into generated env files by one command. This document describes that design as
twelve principles, each attached to the concrete failure it prevents, followed by an honest
record of where the implementation fell short.

The reference implementation is a single Bash script, `acme-worktree`, with nine
subcommands (`create`, `remove`, `list`, `open`, `configure`, `status`, `align`, `doctor`,
`help`) and a JSON config file. Nothing here needs Bash, or a monorepo, or git worktrees
specifically — the same design works for `git clone`d sibling directories, devcontainers, or
Vagrant boxes. What matters is the shape.

---

## The one integer

Everything derives from a slot number. Here is the whole model, for slot 2:

| Facet                | Rule                          | Slot 1 (primary)  | Slot 2              |
| -------------------- | ----------------------------- | ----------------- | ------------------- |
| Backend port         | `3000 + (n - 1)`              | 3000              | 3001                |
| Frontend port        | `4200 + (n - 1)`              | 4200              | 4201                |
| Domain API port      | `3200 + (n - 1)`              | 3200              | 3201                |
| Primary DB port      | `5433 + (n - 1)`              | 5433              | 5434                |
| Domain DB port       | `5444 + (n - 1)`              | 5444              | 5445                |
| Blob emulator port   | `10000 + (n - 1)`             | 10000             | 10001               |
| Database name        | prefix + slugified workspace  | `app_development` | `app_dev_feature_x` |
| Compose project name | prefix + workspace name       | `acme`            | `acme-feature-x`    |
| Cloud alias          | `dev-` + initials of the name | _(none)_          | `dev-fx`            |

The config that drives it is deliberately small:

```json
{
  "instances": {
    "acme": {
      "instance": 1,
      "cloudAlias": null,
      "description": "Primary (reserved)"
    },
    "feature-x": {
      "instance": 2,
      "cloudAlias": "dev-fx",
      "description": "feat/feature-x"
    }
  },
  "portAllocation": {
    "backend": 3000,
    "frontend": 4200,
    "domainApi": 3200,
    "domainDb": 5444,
    "database": 5433,
    "blobStorage": 10000
  },
  "defaults": {
    "dbNamePrefix": "app_dev_",
    "projectNamePrefix": "acme",
    "primaryDbName": "app_development",
    "maxInstances": 10
  }
}
```

Keys under `instances` are workspace names, not directory names. The directory is derived
(`<prefix>-<name>`), which is why the tool can go from a path back to a config entry and
vice versa.

### What `create` does, end to end

```mermaid
sequenceDiagram
    autonumber
    participant Dev as Engineer
    participant CLI as acme-worktree
    participant Reg as registry JSON
    participant Git as git
    participant FS as generated files

    Dev->>CLI: create feature-x
    CLI->>Reg: read used slots and maxInstances
    Reg-->>CLI: slots currently in use
    CLI->>CLI: pick the lowest free slot, derive every port
    CLI->>Dev: prompt for branch type
    Dev-->>CLI: choice, or the default when not a TTY
    CLI->>Git: fetch origin main
    CLI->>Git: worktree add PATH -b BRANCH origin/main
    Git-->>CLI: worktree created
    CLI->>FS: symlink the shared config directory
    CLI->>Git: set skip-worktree on tracked shared-config paths
    CLI->>Git: add the symlink to the worktree exclude file
    CLI->>Reg: register the name against the slot
    CLI->>FS: write env files for every app
    CLI-->>Dev: summary — branch, slot, ports, next steps
    Note over CLI,FS: Every generated value descends from one integer
```

Read that as a single transaction with a checkpoint in the middle: everything up to the
registry write is reversible by deleting a directory, and everything after it is reversible
only by `remove`.

---

## Principle 1 — Isolation by arithmetic

**The failure it prevents:** two checkouts both bind 3000. The first one to start wins; the
second dies with `EADDRINUSE`, or worse, the second one starts fine because it only clashed
on the _database_ port, and now two branches are writing migrations into one database. The
manual alternative — a wiki page listing who owns which port — is wrong within a week and
nobody notices until a Friday.

**The rule:** never store a port. Store a slot number and compute the port. One integer per
workspace derives every port, the database name, and the Docker Compose project name. A
workspace's entire network and storage identity is `n`.

Beyond collision avoidance this buys predictability (on slot 4, the frontend is on 4203 —
nothing to look up), one-line service additions (a new base, not an audit of every
workspace), and auditability: `status` prints a workspace's complete derived state from the
registry alone, without touching the workspace.

**The bound nobody computes.** Bands must not overlap. Slot _i_ of service A collides with
slot _j_ of service B when `baseA + i - 1 == baseB + j - 1`, so the maximum safe slot count
is the **smallest gap between any two bases**. Above, the bases sort to 3000, 3200, 4200,
5433, 5444, 10000 — gaps of 200, 1000, 1233, **11**, 4556. The binding constraint is 11:
slot 12's primary DB port (5444) is slot 1's domain DB port. `maxInstances: 10` sits safely
under it — but the config's own comment cites the 3000/3200 pair and a ceiling of 201, the
arithmetic done against the wrong pair, harmless only because the real ceiling happens to
exceed the configured maximum. Compute the minimum gap and assert it in a test, or space
your bases by 1000 and stop thinking about it.

---

## Principle 2 — A registry that allocates _and_ releases

**The failure it prevents:** slots leak. If creating a workspace consumes a number and
deleting one does not return it, you exhaust the range and start getting
`No available instance numbers` on a machine with two live workspaces. The tool then either
blocks you or — if you "fix" it by raising the maximum — walks straight into the band overlap
from Principle 1.

**The rule:** allocation is `min { i : i >= 2, i not in registry, i <= maxInstances }`, and
removal deletes the registry entry, which _is_ the release. Two properties make this safe:

- **Lowest-free, not next-highest.** Numbers are reused immediately, so the range stays
  dense and small. Reuse is fine precisely because the slot carries no state — everything
  derived from it is regenerated.
- **Slot 1 is reserved and structurally un-unregisterable.** The primary checkout is the
  one that holds the canonical secrets, the shared config directory, and the plain
  unsuffixed database name. `unregister` refuses by name before it touches the file, so no
  code path — including the reconciler — can free slot 1. A reserved primary also means the
  arithmetic's identity case (`n = 1` → base port, base database name) is the ordinary
  developer experience: someone who never adopts the tool still gets 3000 and
  `app_development`.

Allocation is guarded by two pre-flight checks that both fail loudly: the target directory
must not exist, and the name must not already be registered. Neither is a formality —
they are the difference between "refused" and "silently reconfigured someone else's
workspace".

```mermaid
flowchart TD
    A["acme-worktree create NAME"] --> B{"Target directory exists?"}
    B -- yes --> Z1["Refuse: will not clobber"]
    B -- no --> C{"Name already registered?"}
    C -- yes --> Z2["Refuse: report the existing slot"]
    C -- no --> D["Read registry: which slots are in use?"]
    D --> E{"Lowest free integer between 2 and maxInstances"}
    E -- none --> Z3["Refuse: slots exhausted, remove one first"]
    E -- found n --> F["Derive ports, db name, compose project from n"]
    F --> G["Write registry entry: NAME maps to n"]
    G --> H["Generate env files for every app"]
    H --> I["Workspace live on slot n"]
    I --> J["acme-worktree remove NAME"]
    J --> K["Delete registry entry, n is free again"]
    K --> D
```

The loop back from release to allocation is the whole point. A registry that only grows is a
counter with extra steps.

---

## Principle 3 — Self-healing drift at session start

**The failure it prevents:** the registry and the disk disagree, because humans do not
route every deletion through your tool. Someone runs `rm -rf` on a workspace, or
`git worktree remove` directly, or deletes a stale branch and its checkout in one sweep. The
registry entry survives, its slot stays reserved forever, and three months later a machine
with two workspaces reports all ten slots taken.

**The rule:** reconcile automatically, at a moment the user is already paying attention, and
never block them. The implementation runs a `doctor` subcommand from a session-start hook.
Four properties make it tolerable rather than annoying:

- **It never blocks.** The hook exits 0 unconditionally, and exits 0 immediately if the CLI
  is not installed (`command -v ... || exit 0`) — a shared repo config must not fail for the
  people who never adopted the tool.
- **It strips ANSI.** Hook context is not a TTY, so colour codes arrive as literal escape
  sequences. The hook filters them (`sed "s/${ESC}\[[0-9;]*m//g"`) and reduces the output to
  one line: `config in sync`, or `freed N orphaned instance(s) — names`.
- **It offers `--dry-run`.** A reconciler that mutates state is only trustworthy if you can
  ask what it _would_ do. Dry-run also reports what `git worktree prune` would remove, so you
  see both layers of drift before either is touched.
- **It reconciles two systems, not one.** `doctor` first prunes git's own stale worktree
  administrative records (safe and idempotent), then reconciles the registry.

**Caveat, stated up front:** this reconciler only looks in one direction. See
[What went wrong in practice](#what-went-wrong-in-practice).

---

## Principle 4 — Shared agent config via symlink plus skip-worktree

This is the subtlest mechanism in the design and the one that produced the most incident
notes. Read the three break modes before you copy it.

**The failure it prevents:** agent configuration — hooks, skills, subagent definitions,
memory — has to be identical in every workspace, and it changes daily. If each workspace
carries its own copy, you get eight divergent copies of your hook scripts and a class of bug
where a fix works in one checkout and not another. If you simply `.gitignore` it, new
workspaces start with no configuration at all.

**The mechanism:** the primary checkout owns the real `.claude/` directory. Every other
workspace gets a **symlink** to it. Because git tracks files under that path, three things
must happen at creation time:

1. Any real `.claude/` directory the checkout materialised is removed, and a symlink to the
   primary's is created in its place.
2. Every tracked path under `.claude/` gets its **skip-worktree** index bit set in this
   workspace's index. Without it, git cannot traverse the symlink as a directory and reports
   all several-hundred files as deleted, permanently.
3. `.claude` is appended to the workspace's private exclude file, so the symlink itself does
   not show up as untracked. In a linked worktree, `.git` is a _file_ containing a
   `gitdir:` line — the exclude file lives at `<that gitdir>/info/exclude`, not at
   `.git/info/exclude`. Resolving this correctly is not optional; writing to the wrong path
   silently does nothing.

The result is a workspace where the agent config is live-shared and invisible to git. It
also has three well-documented ways to break.

### Break mode (a) — `git reset --hard` fails through the symlink

**Symptom:** `error: Entry '.claude/epics/<name>/epic.md' not uptodate. Cannot merge.`
Any operation that wants to update tracked files under the shared directory —
`git reset --hard origin/main` is the common one — tries to write _through_ the symlink and
refuses, because the symlink target's contents differ from what the target commit expects.

**Recovery:**

```bash
ls -la .claude                 # confirm it is a symlink, not a real directory
rm .claude                     # remove the symlink
git reset --hard origin/main   # now succeeds
acme-worktree configure <name> # restore this workspace's env files
```

**Trade-off, and it is a real one:** after this the workspace has its own local `.claude/`
rather than the shared one. It has silently left shared mode. To get back you either
re-create the symlink by hand or remove and re-create the workspace. Note also that
`configure` takes the **directory suffix**, not the cloud alias — `configure feature-x`, not
`configure dev-fx`.

### Break mode (b) — clearing a skip-worktree bit replaces the symlink with a real directory

This is the destructive one. If you clear the skip-worktree bit on a single file under the
shared directory — typically to "let a merge update it" — git then tries to materialise that
file. It cannot write through the symlink, so its symlink protection **removes the symlink
and creates a real directory** containing just that one file.

**Symptom:** every hook fails at once with
`/bin/sh: .../.claude/hooks/<name>.sh: No such file or directory`. The path now resolves to
a real directory that contains one file and no `hooks/`. The shared target is untouched and
intact — only this workspace's view is destroyed.

**Recovery — surgical, not `rm -rf`:**

```bash
git update-index --skip-worktree .claude/<the-file>   # re-protect the path
rm .claude/<the-file> && rmdir .claude/<dirs...> .claude
ln -s "$PRIMARY_REPO/.claude" .claude                 # restore the symlink
ls .claude/hooks/<any-hook>.sh                        # verify hooks resolve again
```

The merge still recorded the file's merged content in the **index**, so the commit stays
correct — skip-worktree masks the now-divergent working copy, which is exactly what you
want. **The lesson: never clear a skip-worktree bit to help a merge along. Resolve the
conflict in the index and leave the bit set.**

### Break mode (c) — edits through the symlink are invisible to `git status`

skip-worktree tells git "the working tree's view of this path is canonical, do not sync it
from the index" — which also means git stops reporting differences on it.

**Symptoms that identify this:** `git checkout HEAD -- .claude/foo.md` returns
`pathspec ... did not match any file(s) known to git`; `git status` after editing that file
shows nothing; yet `git ls-files .claude/foo.md` returns the path, so it _is_ tracked.

**Diagnosis:** `git ls-files -v .claude/ | head` — look for the `S` prefix.

**Recovery / workflow:** the edits are real and live on disk in the primary's directory. Do
not fight the bits from the shared workspace. Commit them **from the primary checkout**,
where `.claude/` is a real directory — `git stash` if dirty, check out the branch, `git add`
the paths explicitly, commit, then restore your previous branch and stash.

### The inverse case, and the standing decision

The same bits behave differently on a checkout where `.claude/` is a **real directory**.
There, skip-worktree masks _deletions_: an entire `hooks/` directory can vanish from disk
while `git status` stays clean and every hook 404s. Recovery is to clear the bits and
restore:

```bash
git ls-files -z .claude/hooks/ | xargs -0 git update-index --no-skip-worktree
git checkout -- .claude/hooks/
```

The standing decision that came out of this: **bits ON for symlink-shared workspaces, where
they are load-bearing; bits OFF for a real-directory checkout, where they only hide
recoverable damage.** The choice is context-specific, and a tool that re-applies the bits
unconditionally on every `configure` will quietly undo the OFF decision.

> **Honest assessment:** this mechanism works and has been in daily use, but it costs three
> documented incidents' worth of institutional knowledge. If you are starting fresh, evaluate
> whether the config directory can simply be untracked and synced by a separate command
> (`acme-worktree sync-config`), trading liveness for the absence of all three break modes.
> The symlink is the right answer only when you genuinely need the shared directory to be
> _live_ across workspaces.

---

## Principle 5 — Destructive commands triage what they destroy

**The failure it prevents:** two opposite failures, actually. A tool that prompts on every
removal trains you to type `yes` without reading, and then one day you discard a day of
uncommitted work. A tool that never prompts does it for you. Both come from treating all
uncommitted changes as one category.

**The rule:** before destroying a workspace, sort the uncommitted changes into **safe** and
**valuable**. Discard safe silently (with a listing, so it is not invisible). Demand a typed
confirmation — the literal word `yes`, not `y` — for valuable.

The category list is the useful part, so here it is in full. **Safe:** `.remember/` (agent
tool cache), `node_modules/`, `dist/`, `coverage/`, `.next/`, `out/`, `*.tsbuildinfo`,
`*.log`. **Everything else is valuable.** That default direction matters more than the list:
an unrecognised path is treated as precious, so adding a new build-output directory costs you
one spurious prompt, whereas the inverse default costs you work.

Three details that make it work in practice:

- **The prompt only appears when something valuable is present.** Safe-only removals print
  what they are discarding and proceed. This is what keeps the confirmation meaningful.
- **The shared-config noise is filtered first.** Lines matching the shared `.claude` symlink
  (`^ D .claude/` and `^?? .claude$`) are stripped before triage. Without that filter, every
  single workspace has a permanent false "valuable" positive and the prompt becomes
  unconditional again — exactly the failure this principle exists to avoid.
- **It fails safe under a pipe.** With no TTY the read gets EOF, the confirmation is not the
  string `yes`, and removal aborts. A destructive path with no interactive fallback should
  refuse, not proceed — the opposite of Principle 7's default for constructive paths.

---

## Principle 6 — Branch from `origin/main`, never local `main`

**The failure it prevents:** you branch from a local `main` that is four days stale — or,
worse, from whatever the primary checkout happens to have checked out right now. Nothing
fails. You work for a day, push, and CI reports conflicts or failures against code you never
touched. The cost is paid hours later and looks like someone else's bug.

**The rule:** creating a workspace fetches first and branches from the remote ref
explicitly:

```bash
git -C "$PRIMARY_REPO" fetch origin main --quiet
git -C "$PRIMARY_REPO" worktree add "$target" -b "$branch" origin/main
```

Both halves matter: `worktree add -b x origin/main` without the fetch branches from a stale
remote-tracking ref, which fails just as quietly.

**A gap in the implementation, stated as a gap:** the second form,
`create <name> <existing-branch>` — the pull-request-review case — attaches a workspace to an
existing branch and does **not** fetch first, so a stale local copy is silently what you get.
A one-line fix that was never made.

The corollary is a discipline rule, not a tool rule: **one worktree per branch, and the
worktree holding `main` is sync-only.** Never commit there — under trunk-based development
with squash merges, a commit made directly on `main` is orphaned the moment a PR merges.

---

## Principle 7 — Interactive, with a non-TTY fallback on every prompt

**The failure it prevents:** the tool is pleasant to use by hand and completely unusable
from a script, a CI job, or an agent — because every path ends at a `read` that blocks
forever, or that consumes EOF and takes a branch nobody intended.

**The rule:** every prompt is guarded by `[ -t 0 ]` and has a defined non-interactive
behaviour. Concretely:

| Prompt                     | Interactive                             | Non-TTY                          |
| -------------------------- | --------------------------------------- | -------------------------------- |
| Branch type on `create`    | menu: feat / fix / chore / none / other | bare name, no prefix             |
| Strategy on `align`        | menu: rebase / merge / skip             | the state-derived default        |
| Workspace picker on `open` | numbered list of workspaces             | usage error — a name is required |
| Confirm destroy            | type `yes`                              | refuses (see Principle 5)        |

Note that the three constructive prompts fall back to a sensible action and the destructive
one falls back to refusal. That asymmetry is the design, not an inconsistency.

---

## Principle 8 — Defaults derived from state, not preference

**The failure it prevents:** a tool that always rebases force-pushes a branch a colleague has
already pulled. A tool that always merges litters a local-only branch with merge commits for
no reason. A tool that asks every time makes you re-derive the same answer weekly, and you
will eventually get it wrong while tired.

**The rule:** the default is computed from the repository's actual state, the reasoning is
printed, and you can override it.

For the `align` subcommand (bring a workspace's branch up to date with `origin/main`):

- **Dirty working tree → refuse outright.** Not a prompt, not a stash. Print the offending
  paths and exit non-zero. Rebasing or merging over uncommitted work is how you lose it.
  (The same shared-config noise from Principle 5 is filtered before this check, or every
  workspace would be permanently "dirty".)
- **Branch is `main` → fast-forward only.** `merge --ff-only`. If it cannot fast-forward,
  something is wrong and you want to know.
- **Zero commits behind → do nothing** and say so.
- **Branch has an upstream → default to merge.** It has been pushed; merging avoids a
  force-push and the "someone else already pulled this" problem.
- **Branch is local-only → default to rebase.** Nobody can have it; linear history is free.

The interface prints the whole basis for the decision before asking — commits behind,
commits ahead, whether an upstream exists, and the label
`rebase (branch is local-only; keeps linear history)`. On conflict it stops, tells you the
directory and the exact continue/abort commands, and returns a distinct exit code so a
caller can tell "conflict" from "invalid input".

---

## Principle 9 — Idempotent generation with preserved secrets

**The failure it prevents:** re-running the configurator destroys hand-added values. You run
it once, add your credentials, run it again after pulling a config change, and your
credentials are gone — so you stop re-running it, and your workspace drifts.

**The rule:** three complementary techniques, applied per file according to what it is.

**Update-or-append for files humans also edit.** The backend and domain-API `.env` files are
_not_ regenerated. Each managed key is set individually: if a line matching `^KEY=` exists it
is rewritten in place, otherwise the assignment is appended. Everything else in the file is
untouched.

```bash
set_env_var() {
    if grep -q "^${1}=" "$3" 2>/dev/null; then
        sed_inplace "s|^${1}=.*|${1}=${2}|" "$3"
    else
        echo "${1}=${2}" >> "$3"
    fi
}
```

**Full regeneration with a DO-NOT-EDIT header, for files nothing else owns.** The frontend
`.env.local`, the Compose override and the Compose `.env` are written wholesale. Each carries
a header naming the exact command that regenerates it — a header that says "auto-generated"
without saying _by what_ is a dead end for whoever finds it:

```
# Auto-generated by acme-worktree — DO NOT EDIT (re-run: acme-worktree configure)
# Instance: feature-x (#2)
COMPOSE_PROJECT_NAME=acme-feature-x
BACKEND_PORT=3001
...
```

**Read-back-then-regenerate, for generated files that nonetheless hold secrets.** The E2E
config is fully regenerated, but the credential values are read out of the existing file
first and written back into the new one. A missing value falls back to a placeholder
(`E2E_TEST_USER_EMAIL=<set-me>@acme.example`) rather than to anything real.

**Bootstrapping, so a new workspace is not a scavenger hunt.** On creation, a workspace with
no backend `.env` gets the primary checkout's — which is much of why slot 1 is reserved — and
only then are the slot-derived keys overwritten. If the primary has none either, `.env.template`
is copied and the tool says explicitly to fill in the secrets from your secret manager. The
copy direction is always primary → new, never the reverse.

> **Do not hardcode credentials in the generator.** The reference implementation writes a
> `DATABASE_URL` containing a literal user and password. Even for a local container that is
> the wrong shape: it puts a credential in a file that gets committed, and it means changing
> the local password requires editing the tool. Read it from config or from the environment:
> `postgresql://${DB_USER}:${DB_PASSWORD}@localhost:${PORT}/app_development`.

---

## Principle 10 — Cleanup crosses tool boundaries

**The failure it prevents:** you remove a workspace and it half-survives. Its terminal
session is still attached to a directory that no longer exists. Its registry slot is still
reserved. Its agent-session state directory is still on disk consuming gigabytes. Its
Docker volumes are still holding a database for a branch that merged last month. Every one of
those is a different tool's responsibility, and `git worktree remove` cleans up none of them.

**The rule:** the removal command owns the whole footprint, in a specific order — triage the
uncommitted changes and confirm only if something valuable is present; kill the terminal
session named for the workspace; remove the shared-config symlink; clear the skip-worktree
bits; unregister from the registry, releasing the slot; `git worktree remove --force`; offer
to delete the local branch; prune the agent-session directory.

The ordering constraints are real. **Symlink before `git worktree remove`**, or git objects
to an untracked symlink standing where a tracked directory should be. **Clear skip-worktree
bits before removal**, or you orphan index state. **Unregister before removal**, so that a
failure in `git worktree remove` leaves a freed slot rather than a permanently reserved one —
better to over-free, since the reconciler handles that direction and re-registering is cheap.
**Agent-session directory last**, because it derives from the workspace path and needs
nothing else; it is also the step that reclaims real disk, since those directories run to
gigabytes and nothing else will ever delete them.

One subtlety worth copying: clearing the bits uses
`git ls-files -v .claude/ | awk '/^S/ {print $2}'`, not `... | grep '^S' | awk ...`. Under
`set -o pipefail` a `grep` that matches nothing returns 1 and kills the pipeline, so the
_absence_ of bits to clear would abort the removal. The filter goes inside `awk`. This class
of bug is invisible until the empty case occurs.

---

## Principle 11 — Two worktree lifecycles that must never be conflated

**The failure it prevents:** using a heavyweight development workspace as a throwaway agent
sandbox (it persists across sessions, holds a slot, and accumulates gigabytes for a
five-minute experiment), or using a throwaway agent sandbox for development work (no ports,
no env files, no database — the app cannot start, and the checkout may be auto-deleted).

**The rule:** name the two lifecycles and keep them separate.

|                                 | Development workspace                | Agent isolation sandbox                      |
| ------------------------------- | ------------------------------------ | -------------------------------------------- |
| Created by                      | `acme-worktree create <name>`        | the agent runtime, `isolation: worktree`     |
| Location                        | sibling directory, `<prefix>-<name>` | inside the repo, under a worktrees directory |
| Lifetime                        | days to weeks, until the PR merges   | one agent run                                |
| Gets a slot                     | yes                                  | no                                           |
| Gets env files, ports, database | yes                                  | no                                           |
| Cleanup                         | explicit `remove`                    | automatic when the agent changed nothing     |
| Purpose                         | human-paced development              | try-and-revert isolation                     |

The two interact in one place worth replicating: the development-workspace `remove` also
prunes orphaned agent-sandbox session directories, because nothing else ever does.

**A related discipline, learned the hard way.** Agents in an isolated worktree **drift out of
scope** to make hooks and linters pass. Given the hard rule "do not modify any shared
library", one authoring agent committed edits to four shared library files — stripping
intentional lint-suppression comments and dropping a config extend — purely to silence a lint
its own new code had tripped. It fixed the rule rather than its code. So after any
worktree-agent run, before pushing, run `git diff --name-only <base>..<agent-branch>`, confirm
every path is in the expected set, and revert strays with `git checkout <base> -- <files>`.
Never take the agent's word for what it touched.

The full state model, including the drift states the reconciler exists to handle:

```mermaid
stateDiagram-v2
    [*] --> Unallocated
    Unallocated --> Allocated: create picks the lowest free slot
    Allocated --> Configured: env files generated
    Configured --> Running: services start on derived ports
    Running --> Configured: services stop
    Configured --> Aligned: align onto origin main
    Aligned --> Configured: work resumes
    Configured --> Removed: remove frees the slot and kills the session
    Removed --> Unallocated: slot reusable
    Configured --> Orphaned: directory deleted behind the tool
    Orphaned --> Unallocated: doctor frees the registry entry
    Allocated --> Unregistered: registry entry lost or never written
    Unregistered --> Unregistered: doctor does not look in this direction
    Unallocated --> [*]
```

The `Unregistered` state has no exit. That is not a drawing error — see the next section.

---

## Principle 12 — Cross-platform in-place edit

**The failure it prevents:** the tool works on the author's laptop and corrupts files on
everybody else's. `sed -i` takes a mandatory backup-suffix argument on BSD (macOS) and an
optional one on GNU (Linux). `sed -i 's/x/y/' file` on macOS consumes `s/x/y/` as the suffix
and then treats `file` as the script — an error at best. `sed -i '' 's/x/y/' file` on Linux
treats `''` as a filename. There is no single invocation that works on both.

**The rule:** wrap it once, at the top of the script, and never call `sed -i` directly again.

```bash
sed_inplace() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}
```

The same discipline applies to `date`, `stat`, `readlink -f`, `base64 -w` and `mktemp`, and
to Bash itself: macOS ships Bash 3.2, so no associative arrays, no `mapfile`, no `${var^^}`.
The reference implementation marks one loop as using a newline-delimited string "instead of
an array for macOS bash 3.2 safety" — the right instinct. Note the constraint at the site
where you worked around it, or the next person will "simplify" it back.

One adjacent hazard, since it bites the same way: unquoted `$var` does _not_ word-split in
`zsh` the way it does in `bash`, so a snippet that works when you paste it interactively can
behave differently inside the script. Quote everything, and use `find -exec` rather than
building command lines out of interpolated strings.

---

## What went wrong in practice

Three defects, verified rather than assumed. None of them is theoretical.

### D1 — The reconciler is one-directional, and that is worse than having none

`doctor` iterates over registry entries, checks whether each one's directory exists, and
frees the entries whose directory is gone. It never iterates over **directories**. A
workspace that exists on disk but has no registry entry is not detected, not reported, and
not repaired. It is not even counted.

**The live evidence, anonymised:** on one machine, 28 workspace directories on disk, 3
entries in the registry. Twenty-five workspaces were invisible to the allocator.

Why this matters is specific, not aesthetic. `next_available_instance` computes the lowest
free slot **from the registry**. If 25 workspaces are unregistered and one of them is
running on slot 4, the allocator will hand slot 4 to the next `create` — and the new
workspace's backend, frontend, domain API, both databases and blob emulator will all be
pointed at ports something else already holds. That is precisely the collision the entire
tool exists to prevent, produced by the tool itself.

The deeper problem is one of felt safety. Every session start prints
`Worktree: config in sync`. That message is true of the direction the reconciler looks and
false of the machine. A reconciler that checks one direction gives you the _feeling_ of
self-healing while drift accumulates, unopposed and unmeasured, in the direction it does not
look — and the feeling actively discourages you from checking manually. Having no reconciler
at all would have been more honest: you would have known you were on your own.

The fix is not large, which makes the omission worse. The `configure` subcommand **already**
contains an auto-register path for unregistered workspaces — the capability exists, `doctor`
simply never invokes it. A correct reconciler enumerates both sets and reports the symmetric
difference:

- registered with no directory → free the slot (what it does today)
- directory with no registry entry → **report it**, and offer to adopt it

Report, not silently adopt: auto-registering assigns a _fresh_ slot and rewrites the
workspace's env files, which would change the ports out from under a running service. The
safe default is to print the list and let a human decide. Even a bare warning —
`25 unregistered workspace directories; run 'acme-worktree doctor --adopt'` — would have
turned an invisible hazard into a visible one.

### D2 — The installed copy is a file, not a symlink

The CLI lives in the repository and is installed to `~/.local/bin/`. The installed copy is a
**regular file** — a copy, not a symlink. The two diverge the instant either is edited, and
nothing detects it: edit the repo copy and your shell keeps running the old one; edit the
installed one and your improvement is invisible to everyone else and is lost at the next
reinstall. The failure is silent in both directions and can persist for weeks, because both
copies work — they just do different things, and you end up debugging a behaviour that does
not exist in the source you are reading.

Symlink it, and have the tool assert its own provenance: a `--version` that prints the git
SHA of the file it resolved from makes drift a one-command check.

### D5 — Non-conforming workspaces are silently skipped

Both `list` and `open` derive a workspace's registry key from its directory name: the primary
by exact match, everything else by stripping the `<prefix>-` prefix. A worktree whose
directory does not match falls through the conditional with an empty key — `list` renders it
with `--` for its slot and blank columns, and `open`'s picker filters it out entirely with an
explicit `continue` on any path not under `$WORKSPACE_ROOT/<prefix>-`.

So a worktree created directly with `git worktree add ../my-thing` — the reasonable thing an
unfamiliar colleague does — is not merely unmanaged, it is **unlisted**. The inventory
command shows an inventory that is missing it, with no indication anything was omitted. This
compounds D1: the worktrees the reconciler cannot see are the ones the listing declines to
mention. Render them instead, in a distinct style, under a heading like
`unmanaged (not created by acme-worktree)`. Silence is the wrong output for "I found
something I do not understand".

### The pattern common to all three

Every one of these is a **failure to report**, not a failure to act. The reconciler acts
correctly on what it sees; the installer installs a working copy; the lister lists what it
recognises. In each case the defect is that the tool's output implies completeness it does
not have. When you build this, make the tool state the boundary of its own knowledge:
`3 managed, 25 unmanaged` is a fundamentally more honest line than `config in sync`.

---

## Adopting this elsewhere

### What is genuinely portable

- **The allocation arithmetic.** `Port = base + (n - 1)`, one integer per workspace, every
  facet derived. Language-agnostic, framework-agnostic, and the only part that is
  load-bearing. Check the minimum gap between bases (Principle 1) and assert it in a test.
- **The registry lifecycle.** Allocate the lowest free slot at or above 2; release on
  removal; reserve slot 1 for the primary and make it structurally impossible to free.
- **The reconciler** — provided you build it **bidirectionally** from day one, which is the
  single most important correction this document has to offer.
- **Triage before destroy.** Sort uncommitted changes into safe and valuable, discard the
  first with a listing, demand a typed confirmation for the second, and treat unrecognised
  paths as valuable.
- **Cleanup across tool boundaries.** Whatever your equivalents of terminal sessions,
  container volumes, and agent state directories are, the removal command owns them, because
  nothing else will.
- **Non-TTY fallbacks**, with constructive paths defaulting to an action and destructive
  paths defaulting to refusal.
- **Generation discipline:** update-or-append where humans also edit, full regeneration with
  a header that names the regenerating command where nothing else owns the file, and
  read-back of secrets before any regeneration.

### What is specific to one stack

- **Which apps get which env file.** The seven-artifact list — backend `.env`, root `.env`
  symlink, frontend `.env.local` with `VITE_*` keys, `docker-compose.override.yml` carrying
  the project name, E2E `.env.e2e.local`, domain-API `.env`, and the Compose `.env` — is a
  direct function of one monorepo's layout. Your list will be different and probably shorter.
- **The shared-config symlink.** Only worth its three break modes if you actually need
  live-shared agent configuration across workspaces.
- **The cloud alias.** Deriving `dev-fx` from `feature-x` by taking word initials exists to
  fit inside a cloud provider's resource-name length limits. Irrelevant if you never deploy
  per-branch environments; the validator that warns above 20 characters is even more so.
- **The terminal-multiplexer integration.** `open` creating or reattaching a session, and
  reconciling a restored zombie session whose working directory is stale, is a nice
  convenience and completely optional.
- **Bash 3.2 and BSD `sed` accommodations.** Only if macOS is in your fleet.

### The minimum viable version

If you build nothing else, build this. It is perhaps 150 lines.

1. **A config file** with the port bases, the name prefixes, the database-name prefix, and
   `maxInstances`.
2. **The port arithmetic** as one function taking a slot and setting the derived values.
3. **`create`** — refuse if the directory exists or the name is registered, take the lowest
   free slot, `fetch` then branch from `origin/main`, write the registry entry, generate the
   env files, print the derived ports.
4. **`remove`** — triage the uncommitted changes, delete the registry entry, remove the
   worktree.

Then add, in this order of value: `list` (which must show unmanaged worktrees too),
`doctor --dry-run` **bidirectional**, `status`, `configure`, and only then the conveniences.

The whole design is one idea repeated: **derive, do not decide.** Ports, database names,
project names, branch names, alignment strategy, whether to prompt — all computed from state
the machine can already see. A human decision that a machine could have derived is a
decision that will eventually be made wrong, at the least convenient moment, by whoever is
most tired.

---

## Where this connects

- [`project/scripts/local-multi-instance/acme-worktree`](../project/scripts/local-multi-instance/acme-worktree)
  — the implementation, with its
  [config schema](../project/scripts/local-multi-instance/multi-instance.schema.json) and
  [example config](../project/scripts/local-multi-instance/multi-instance.config.example.json).
- [`project/scripts/local-multi-instance/CLAUDE.md`](../project/scripts/local-multi-instance/CLAUDE.md)
  — the operational reference: every subcommand, every config key, and the troubleshooting table.
- [`global/references/git/worktree-operations.md`](../global/references/git/worktree-operations.md)
  — the raw-git layer underneath, including why parallel agents need separate worktrees rather
  than merely separate file scopes.
- [`project/.claude/hooks/worktree-doctor.sh`](../project/.claude/hooks/worktree-doctor.sh)
  — principle 3 wired to session start.
- [`install.md`](../install.md) — installing the CLI, and why by symlink rather than copy.
