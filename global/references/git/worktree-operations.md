# Worktree Operations

Git worktrees give one repository several working directories, each on its own branch. That
buys parallel development — and a set of failure modes that only appear once several
worktrees, or several agents, are live at once.

For the tooling that automates the whole lifecycle (port allocation, generated env files,
shared agent config, reconciliation), see
[`worktree-workspace-allocation.md`](../../../docs/worktree-workspace-allocation.md) and the
`acme-worktree` CLI. This file is the raw-git reference underneath it.

---

## Creating worktrees

Branch from `origin/main`, not from local `main`:

```bash
git fetch origin main
git worktree add ../epic-{name} -b epic/{name} origin/main
```

**Not** `git checkout main && git pull && git worktree add ...`. Two reasons, and both bite
hours later rather than immediately:

- Checking out `main` to refresh it requires `main` to be free. Under one-worktree-per-branch
  it usually is not, and the fix people reach for — `--ignore-other-worktrees` — races the
  index and refs.
- Branching from whatever local `main` happens to point at silently inherits any staleness. The
  work looks fine locally and fails in CI against the real base.

The explicit fetch costs a second and removes the entire class.

## One worktree per branch, and `main` is sync-only

Git already enforces one worktree per branch. The additional rule is that the worktree holding
`main` is never edited and never committed to — it exists to be fast-forwarded.

Under trunk-based development with squash merges, any commit made directly on `main` becomes
orphaned the moment a PR merges. Keeping `main` read-only makes that impossible rather than
merely discouraged.

## Parallel agents: worktrees isolate, file scope does not

Do **not** run two mutating agents in the same worktree, even when their file scopes are
provably disjoint.

Git's index is per-worktree, not per-directory. Two agents that each run `git add` then
`git commit` interleave on that single shared index. The recorded outcome of trying it: commit
titles belonging to one stream with diffs belonging to the other, one stream's untracked file
swept into the other's commit, and an intermediate commit destroyed entirely by a concurrent
`git reset`. File content survived; attribution was unrecoverable without a soft reset and an
atomic replay.

Two ways to do it safely:

1. **Give each stream its own worktree.** Isolation comes from the worktree, not from
   discipline about paths.
2. **Serialize the commit step.** Parallel read and edit is fine; funnel every `git add` and
   `git commit` through one sequenced phase with a coordinator.

If you must dispatch parallel committers anyway, put these in each agent's hard rules:

- Before `git add`, run `git status --short` and abort if anything outside your declared file
  scope appears as `??`, `M`, or staged.
- Never run `git reset`. Only the coordinator may.
- Pre-stage a soft-reset target commit **before** launching, so rewinding is cheap when a race
  happens.

## Verify what an agent actually changed

A worktree-isolated agent that trips a repo lint rule with its own new code will often "fix"
the rule or a neighbouring file rather than its own code, and commit the lot. This has happened
with an explicit hard rule forbidding exactly that.

So before pushing or opening a PR from an agent branch:

```bash
git diff --name-only {base}..{agent-branch}
```

Every path must be in the slice's expected set. Revert strays with
`git checkout {base} -- {files}`. Never accept "I only touched my files" as evidence.

Agents commonly commit with hooks skipped (a fresh worktree has no `node_modules`), so the
formatter and the test suite still need to run somewhere that does.

## Working in a worktree

```bash
cd ../epic-{name}
git add {files}
git commit -m "Issue #{number}: {change}"
```

Small, focused commits. `Issue #{number}: {description}` as the message format.

## Merging back

```bash
cd {main-repo}
git fetch origin main
git merge --ff-only origin/main      # refresh the sync-only main worktree
git merge epic/{name}
```

Then clean up — see below, because `git worktree remove` alone is not enough.

## Removing a worktree

```bash
git worktree remove ../epic-{name}
git branch -d epic/{name}
```

Removal is worth doing promptly: on a large monorepo each stale worktree is several gigabytes,
and if you are allocating instance numbers they are a finite resource.

Git cleans up the directory and its admin record. It does **not** clean up anything else the
workspace acquired — a terminal session, a registry entry, an agent-session directory, a Docker
project. Whatever created those has to remove them, which is the argument for a wrapper command
that owns the whole lifecycle.

### When removal fails

```bash
git worktree remove --force ../epic-{name}   # dirty worktree
git worktree remove -f -f {path}             # locked (e.g. an agent worktree); commits survive
git worktree prune                           # directory deleted behind git's back
```

`git worktree prune` reconciles git's records with the disk. Note what it does **not** do: any
registry of your own that tracks these worktrees stays stale, because git does not know it
exists. Reconciliation has to run in both directions or drift accumulates in the direction
nobody checks.

## Shared configuration by symlink

Where several worktrees share one agent-config directory by symlinking it to the primary
worktree, the tracked files under that path carry the `skip-worktree` index bit. That bit is
what makes the arrangement work — without it git reports every shared file as deleted.

Three consequences, all of which have cost real time:

- `git reset --hard` fails on tracked paths under the symlink. Remove the symlink, reset, then
  re-create it.
- Clearing a `skip-worktree` bit — usually to "help" a merge update one file — makes git delete
  the symlink and materialize a real directory containing only that file. Every hook then fails
  with `No such file or directory`. Resolve such conflicts in the index and leave the bit set.
- Edits made through the symlink are invisible to `git status`. They must be committed from the
  worktree where the directory is real.

## Two lifecycles, not one

|             | Development worktree         | Agent-isolation worktree          |
| ----------- | ---------------------------- | --------------------------------- |
| Created by  | a person, deliberately       | an agent, automatically           |
| Lives for   | days to weeks                | one task                          |
| Environment | ports, env files, containers | none                              |
| Cleanup     | explicit, by command         | automatic if unchanged            |
| Location    | sibling of the repo          | inside the repo's agent directory |

They are not interchangeable. An agent-isolation worktree has no environment setup, so it is
the wrong tool for development. A development worktree persists across sessions and consumes an
instance slot, so it is the wrong tool for a one-off sandbox.

## Best practices

1. **One worktree per epic**, not per issue.
2. **Branch from `origin/main` with an explicit fetch** — never from local `main`.
3. **Never edit the `main` worktree.** It is for fast-forwarding.
4. **One mutating agent per worktree.** The index is shared even when file scopes are not.
5. **Diff agent branches against base** before trusting them.
6. **Remove within hours of merge.** Stale worktrees are expensive and slots are finite.
7. **Reconcile in both directions** — records without directories _and_ directories without
   records.
