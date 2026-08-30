# CLAUDE.md — `acme-worktree` (multi-instance workspace allocator)

`acme-worktree` is a workspace allocator, not a git wrapper: it hands each worktree one integer
and derives every port, database name and Docker Compose project name from it, so N checkouts of
this monorepo run side by side without collision. Around that sit a JSON registry with
allocate/free semantics, generated env files for four apps, a symlinked shared agent-config
directory, tmux session management, and a `doctor` that repairs registry drift.

Script: `scripts/local-multi-instance/acme-worktree` (bash, `set -euo pipefail`, requires `jq`,
`git`, `tmux`). Registry: `scripts/local-multi-instance/multi-instance.config.json`.

## Port arithmetic

`Port = base + (instance - 1)`. Bases come from `portAllocation`; the jq fallbacks below apply if
a key is missing.

| Service       | Config key  | Base (fallback) | #1    | #2    | #3    |
| ------------- | ----------- | --------------- | ----- | ----- | ----- |
| Backend       | `backend`   | 3000            | 3000  | 3001  | 3002  |
| Frontend      | `frontend`  | 4200            | 4200  | 4201  | 4202  |
| Domain API    | `domainApi` | 3200            | 3200  | 3201  | 3202  |
| Database      | `database`  | 5433            | 5433  | 5434  | 5435  |
| Domain DB     | `domainDb`  | 5444            | 5444  | 5445  | 5446  |
| Blob emulator | `azurite`   | 10000           | 10000 | 10001 | 10002 |

Instance **1 is reserved for the primary checkout** (`acme`). `next_available_instance` scans from
**2** to `defaults.maxInstances` (10) and returns the lowest integer absent from the registry.
Ranges only overlap at instance 201 (backend 3000 vs domain API 3200), so `maxInstances` can be
raised well past 10 without arithmetic collisions.

Also derived per instance:

| Derived value   | Instance 1                   | Instance ≥ 2                                |
| --------------- | ---------------------------- | ------------------------------------------- |
| Database name   | `defaults.primaryDbName`     | `defaults.dbNamePrefix` + name with `-`→`_` |
| Compose project | `defaults.projectNamePrefix` | `<projectNamePrefix>-<name>`                |

## Subcommands

Dispatch aliases: `rm`=`remove`, `ls`=`list`, `config`=`configure`. Bare invocation prints help.

| Command     | Args                       | Does                                                                                                        |
| ----------- | -------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `create`    | `<name> [existing-branch]` | Worktree at `<workspace-root>/acme-<name>`, symlink `.claude`, allocate instance, register, write env files |
| `remove`    | `<name>`                   | Kill tmux session, unregister (frees the number), `git worktree remove --force`, prune agent project dir    |
| `list`      | —                          | Table: directory, branch, instance #, ports, cloud alias, `.claude` mode                                    |
| `open`      | `[name]`                   | Attach/create tmux session `acme-<name>` and launch the agent CLI                                           |
| `configure` | `[name]`                   | Regenerate env files for a named worktree or the current directory                                          |
| `status`    | `[name]`                   | Instance #, alias, branch, all six ports, DB name, compose project, URLs, running containers                |
| `align`     | `[name]`                   | Fetch `origin/main`, then rebase or merge the worktree's branch onto it                                     |
| `doctor`    | `[--dry-run]`              | `git worktree prune` + free registry entries whose directory is gone                                        |

### Non-obvious behaviour

**`create`** — aborts if the target directory exists _or_ the name is already registered. With an
explicit branch argument it attaches to that existing branch and does **not** fetch (use this for
PR review). With no branch it prompts for a type — `1) feat 2) fix 3) chore 4) none 5) other` —
and always runs `git fetch origin main` then branches from `origin/main`. Non-TTY (piped, agent-
driven) silently falls back to choice 4, i.e. a bare branch named `<name>`. The cloud alias is
auto-generated as `dev-` plus the first letter of each hyphen-separated word (`domain-reporting` →
`dev-dr`); an alias longer than 20 chars warns (storage-account names are capped at 24 with the
`developmentacme…` prefix) but never blocks. Any pre-existing real `.claude/` directory in the new
worktree is `rm -rf`'d and replaced by the symlink.

**`remove`** — refuses if the directory is missing (so deleting the directory first is what strands
a registry entry; see _Registry drift_) and refuses the primary name `acme`. Uncommitted changes
are classified: `.remember/`, `node_modules/`, `dist/`, `coverage/`, `.next/`, `out/`, `*.log`,
`*.tsbuildinfo` are **safe** and discarded with a notice; anything else is **valuable** and requires
typing `yes`. It offers to delete a local branch only when the branch name equals `<name>`
_exactly_, so a `feat/<name>` branch created by the interactive prompt survives removal. It also
deletes the agent session-project directory for that worktree.

**`list`** — walks `git worktree list --porcelain`. `.claude` mode is shown as `⊘ shared` (symlink),
`◉ local` (real directory) or `✗ missing`. Registry lookup keys off the directory basename: exactly
`acme` → primary, `acme-<suffix>` → `<suffix>`. Anything else shows `--` for instance/ports even if
it is registered. Rows are printed only on the porcelain `branch` line, so **detached-HEAD worktrees
produce no output at all**.

**`open`** — the picker filters to paths under `<workspace-root>/acme-*`, skipping the primary and
agent-isolation worktrees. If the session already exists and the foreground process is a plain
shell, it corrects a stale cwd and starts the agent CLI; if the foreground is anything else it warns
and only attaches (it will not send keys into a running program). Inside tmux it uses
`switch-client`, otherwise `attach-session`.

**`configure`** — with no argument it infers the name from the current directory's basename and errors
if it doesn't match `acme` or `acme-*`. If the name isn't in the registry it **auto-registers**,
consuming an instance number — running it in a stray directory therefore burns a slot. Safe to
re-run; it is the recovery path after any manual surgery on env files.

**`align`** — refuses on detached HEAD and on a dirty tree (it ignores `?? .claude`, ` D .claude/`
and `?? .remember/`). On branch `main` it only ever fast-forwards, never merges. Otherwise it reports
ahead/behind and prompts: **rebase** is the default for branches with no upstream (linear history),
**merge** is the default for pushed branches (avoids force-push). Non-TTY takes the default. Exit
code 2 means conflicts are left in the worktree for you to resolve.

**`doctor`** — idempotent and safe; never touches the primary entry. `--dry-run` reports only. It is
wired to a session-start hook, so registry orphans are usually already cleaned before you look.
It is **one-directional** — see _Known limitations_.

## Registry: `multi-instance.config.json`

Keys are **worktree names** (directory suffixes), not directory names and not branch names.

| Key                            | Managed by | Meaning                                                                    |
| ------------------------------ | ---------- | -------------------------------------------------------------------------- |
| `$schema`, `$comment`          | human      | Documentation only; the CLI never reads them                               |
| `instances.<name>.instance`    | **CLI**    | The integer everything is derived from                                     |
| `instances.<name>.azureAlias`  | **CLI**    | Alias for ephemeral cloud environments; `null` for the primary             |
| `instances.<name>.description` | **CLI**    | Set to `Worktree for <branch>` at create time; not kept in sync afterwards |
| `portAllocation.*`             | human      | Six port bases (see table above)                                           |
| `defaults.dbNamePrefix`        | human      | Prefix for non-primary databases (fallback `app_dev_`)                     |
| `defaults.projectNamePrefix`   | human      | Compose project prefix and directory prefix (fallback `acme`)              |
| `defaults.primaryDbName`       | human      | Instance 1's database (fallback `app_development`)                         |
| `defaults.maxInstances`        | human      | Upper bound for allocation (fallback 10)                                   |

Every read is `jq -r '… // <default>'`, so a **typo'd or missing key silently falls back** rather
than failing. If a workspace comes up on unexpected ports, validate the JSON key spelling first.

Hand-edit `portAllocation` and `defaults`; let the CLI own `instances`. Editing `instances` by hand
is legitimate only to repair drift — keep instance numbers unique.

## Generated files per workspace

`configure_env_files` runs on both `create` and `configure`.

| Path                                          | Written when          | Mode                                                                                                                                                                                                            |
| --------------------------------------------- | --------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `apps/legacy-api/.env`                        | always                | **In place.** Copied from the primary checkout (or `.env.template`) if absent, then `PORT`, `DB_PORT`, `DB_NAME`, `AZURITE_PORT`, `DOMAIN_API_URL`, `DOMAIN_API_WEBHOOK_URL` are set; all other lines preserved |
| `.env` (repo root)                            | always                | Symlink → `apps/legacy-api/.env`                                                                                                                                                                                |
| `apps/legacy-web/.env.local`                  | if the app dir exists | **Overwritten.** `VITE_LEGACY_HOST`, `VITE_PORT`                                                                                                                                                                |
| `apps/legacy-api/docker-compose.override.yml` | if the app dir exists | **Overwritten.** `name: <compose project>` only                                                                                                                                                                 |
| `apps/legacy-web-e2e/.env.e2e.local`          | if the app dir exists | **Overwritten**, but `E2E_TEST_USER_EMAIL` / `_PASSWORD` / `_TOTP_SECRET` are read from the old file first and carried across                                                                                   |
| `apps/domain-api/.env`                        | always                | Copied from the primary if absent, then `PORT`, `DATABASE_URL`, `LEGACY_BACKEND_URL` set **in place**                                                                                                           |
| `scripts/local-multi-instance/.env`           | if the dir exists     | **Overwritten.** `COMPOSE_PROJECT_NAME` + all six port vars; consumed by `docker-compose.yml`                                                                                                                   |

Two consequences worth internalising:

- **Overwritten files lose manual edits** on the next `configure`. Only the two `.env` files and the
  three preserved E2E credentials survive.
- **`create` copies the primary checkout's real `.env`**, so live secrets propagate into every new
  workspace automatically — no secret-manager lookup, but also no isolation. Treat every workspace
  as holding the same secrets as the primary. The generated `DATABASE_URL` embeds the local Compose
  Postgres user and password; in this repository they appear as `<user>:<password>` placeholders —
  substitute your own or source them from the environment before running.

`sed_inplace` branches on `$OSTYPE` for the BSD/GNU `sed -i` difference. `set_env_var` is idempotent:
it rewrites a matching `^NAME=` line or appends one.

## Shared agent config: the symlink + skip-worktree contract

`create` makes `<worktree>/.claude` a symlink to the **primary checkout's** `.claude`, sets
`--skip-worktree` on every tracked file under `.claude/`, and appends `.claude` to that worktree's
`info/exclude`. The skip-worktree bits are load-bearing: without them git sees the whole tree as
deleted (it cannot traverse the symlink as a directory) and tries to materialise files _through_ the
link. `remove` clears the bits and deletes the symlink before removing the worktree.

**Never commit `.claude` changes from a `⊘ shared` worktree** — edits land in the primary's directory
on disk but are invisible to that worktree's index. Commit them from the primary checkout.

Three failure modes, all seen in practice:

1. **`git reset --hard origin/main` fails**: `error: Entry '.claude/…' not uptodate. Cannot merge.`
   The tracked path is being updated through the symlink.

   ```bash
   ls -la .claude          # confirm it is a symlink
   rm .claude
   git reset --hard origin/main
   acme-worktree configure <suffix>   # restores env files; worktree may end up ◉ local
   ```

2. **The symlink turns into a real directory and every hook 404s.** Clearing skip-worktree on a
   `.claude` file — or letting a merge update one whose bit was cleared — makes git delete the
   symlink and create a real `.claude/` holding that single file. Symptom: every hook fails with
   `No such file or directory`. The primary's `.claude` is untouched.

   ```bash
   git update-index --skip-worktree .claude/<file>    # re-protect
   rm .claude/<file> && rmdir .claude/<dirs…> .claude
   ln -s <primary-checkout>/.claude .claude
   ls .claude/hooks/                                  # verify hooks resolve
   ```

   Rule: never clear skip-worktree on a `.claude` file to "help" a merge; resolve it in the index.

3. **skip-worktree masks an on-disk deletion.** Files under `.claude/` vanish, hooks break, and
   `git status` stays clean because the bits suppress worktree-vs-index diffs. Related symptom:
   `git checkout HEAD -- .claude/foo` → `pathspec … did not match any file(s) known to git`.
   ```bash
   git ls-files -v .claude/ | grep '^S'    # diagnose: S prefix = skip-worktree
   git ls-files -z .claude/hooks/ | xargs -0 git update-index --no-skip-worktree
   git checkout -- .claude/hooks/
   ```
   Leave the bits **off** for `.claude/hooks/` afterwards so a future deletion is git-visible and
   self-recoverable. Bits on for symlink-shared trees, bits off for hooks in a real-directory
   checkout — the choice is context-specific. Caveat once bits are off: a blanket `git add -A` can
   sweep `.claude` edits into a commit, so scope your adds.

## Naming gotchas that cost real time

- Every command takes the **directory suffix**: directory `acme-infra` → `acme-worktree configure infra`.
  Not `acme-infra` (→ looks for `acme-acme-infra`), not the cloud alias `dev-i`.
- The primary is the literal name `acme`; it cannot be removed or unregistered.
- Worktree name ≠ branch name. `create infra` with the default prompt produces branch `feat/infra`,
  and `remove infra` will not offer to delete it.
- Directories not matching `acme-*`, and worktrees in detached HEAD, are **silently skipped** by
  `list`, `open` and `align` — invisible rather than reported.

## Lifecycle rules

- **One worktree per branch; the worktree holding `main` is sync-only** — never edit or commit there.
  Under trunk-based squash-merge, a direct `main` commit is orphaned the moment a PR merges.
- **Branch from `origin/main`**, which `create` does for you. Raw equivalent:
  `git fetch origin main && git worktree add <path> -b <name> origin/main`.
- **Remove within hours of merge.** Stale worktrees cost gigabytes each on this monorepo and hold an
  instance number. Keep only: the `main` holder, long-running track branches, and active work.
- **Align long-running branches periodically** (weekly, or before resuming after a pause) with
  `acme-worktree align`. After rebase push with `--force-with-lease`; after merge push normally.
- Audit with `acme-worktree list` on a regular cadence.

## This tool vs agent-isolation worktrees

They are for different lifecycles and are not interchangeable.

|                  | `acme-worktree create`         | Agent isolation (`isolation: "worktree"`) |
| ---------------- | ------------------------------ | ----------------------------------------- |
| Lifetime         | Human-paced, days to weeks     | Ephemeral, one agent run                  |
| Location         | `<workspace-root>/acme-<name>` | `<repo>/.claude/worktrees/agent-*`        |
| Ports / DB / env | Allocated and generated        | None                                      |
| Cleanup          | Explicit `remove`              | Automatic when the agent changes nothing  |

Agent isolation is wrong for development work (no env or port setup, so nothing will start);
`acme-worktree` is wrong for a one-off agent sandbox (it consumes a scarce instance number and
persists across sessions). After any worktree-authoring agent run, diff its branch against the base
and revert files outside the intended scope — agents drift into unrelated files to silence lint and
hooks, and their "I only touched my files" claim is not evidence.

## Troubleshooting

**"No available instance numbers"** — run `acme-worktree doctor --dry-run`, then `doctor`. If the
registry is already clean, either raise `defaults.maxInstances` or remove a worktree. Check both
drift directions before raising the cap.

**Port already in use (`EADDRINUSE`)** — `lsof -i :<port>`, then `acme-worktree status <name>` to
confirm which instance owns it. The common cause is an _unregistered_ worktree already running on a
number the allocator has since handed out again.

**Container name conflict** — the Compose project name is the isolation boundary. Stop the app-level
stack before starting the multi-instance one:
`cd apps/legacy-api && docker compose down`, then
`docker compose -f scripts/local-multi-instance/docker-compose.yml up` from the workspace root.
Verify with `docker ps --filter label=com.docker.compose.project=<project>` (this is what `status` runs).

**Wrong database** — `acme-worktree status` prints the expected name; compare against
`grep DB_NAME apps/legacy-api/.env` and `grep DATABASE_URL apps/domain-api/.env`. A mismatch means
env files were edited by hand or the workspace was created before a `defaults` change; fix with
`acme-worktree configure`.

**Registry drift, direction A (entry without directory)** — caused by deleting a worktree with `rm`
or `git worktree remove` instead of `acme-worktree remove`. The instance number stays reserved
forever. `doctor` fixes this, and the session-start hook runs it automatically.

**Registry drift, direction B (directory without entry)** — `doctor` does **not** detect this. Check
it manually (ADDITION — not implemented by the tool):

```bash
cfg=scripts/local-multi-instance/multi-instance.config.json
root=$(dirname "$(git rev-parse --show-toplevel)")
prefix=$(jq -r '.defaults.projectNamePrefix // "acme"' "$cfg")
for d in "$root"/"$prefix"-*; do
  n=$(basename "$d"); n=${n#"$prefix"-}
  jq -e --arg n "$n" '.instances[$n]' "$cfg" >/dev/null 2>&1 || echo "unregistered: $n"
done
```

Register each hit with `acme-worktree configure <n>` before creating anything new.

## Known limitations (verified, not hypothetical)

1. **`doctor` is one-directional.** It frees entries whose directory is gone but never notices
   directories that were never registered. Observed on a live machine: 28 worktree directories on
   disk, 3 registry entries. `next_available_instance` can therefore hand a number to a new
   workspace that a running-but-unregistered one already uses — precisely the port collision the
   tool exists to prevent.
2. **The installed copy is a regular file, not a symlink.** `~/.local/bin/acme-worktree` and the
   repo copy drift apart the moment either is edited. RECOMMENDATION (addition): install by
   symlinking to the repo copy so there is one source of truth.
3. **Paths are hardcoded** in the script header: the main repository path, the workspace root, the
   `acme-` directory prefix, the per-app directories, and the agent project-directory slug. Moving
   the repo or renaming an app requires editing the script, not the config.
4. **Two literal secrets are inlined** in the generator — the domain database `DATABASE_URL`
   credentials and a default E2E user email. In this repository both are placeholders; in any real
   port they must come from the environment or a secret manager.
5. **Non-conforming worktrees are invisible, not reported.** Directories outside the `acme-*` prefix
   and detached-HEAD worktrees are skipped silently by `list`, `open` and `align`.

## Related files

| File                         | Purpose                                                          |
| ---------------------------- | ---------------------------------------------------------------- |
| `acme-worktree`              | The CLI (nine subcommands)                                       |
| `multi-instance.config.json` | Instance registry + port bases                                   |
| `docker-compose.yml`         | Per-instance stack; reads the generated `.env` in this directory |
| `README.md`                  | User-facing documentation                                        |
