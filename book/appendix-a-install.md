# Appendix A · Installing this setup

> Appendices · [← The system it built](13-the-system-it-built.md) · [Contents](README.md) · [Next: Attribution and lineage →](appendix-b-attribution-and-lineage.md)

---

Nothing here installs itself. Read before you copy — a hook that runs your test suite on
every `Stop` is excellent on a repo with fast tests and miserable on one without.

## Layout mapping

| This repo                                                                                                        | Goes to                                     | Scope                               |
| ---------------------------------------------------------------------------------------------------------------- | ------------------------------------------- | ----------------------------------- |
| `global/rules/`, `global/references/`, `global/agents/`, `global/commands/`, `global/skills/`, `global/scripts/` | `~/.claude/`                                | every project on the machine        |
| `global/settings.json`                                                                                           | `~/.claude/settings.json`                   | merge, don't overwrite              |
| `global/statusline.sh`                                                                                           | `~/.claude/statusline.sh`                   | `chmod +x`                          |
| `global/CLAUDE.md`                                                                                               | `~/.claude/CLAUDE.md`                       | your personal standing instructions |
| `global/memory/`                                                                                                 | `~/.claude/projects/<project-slug>/memory/` | per-project; **start empty**        |
| `project/.claude/`                                                                                               | `<your-repo>/.claude/`                      | commit this with the repo           |
| `project/**/CLAUDE.md`                                                                                           | mirror the paths into your repo             | per-directory instructions          |
| `project/.mcp.json`                                                                                              | `<your-repo>/.mcp.json`                     | edit servers first                  |
| `project/scripts/local-multi-instance/acme-worktree`                                                             | `~/.local/bin/` — **symlink, not copy**     | optional; see below                 |

## Start here, not everywhere

Adopting all 34 hook scripts (28 wired across 8 lifecycle events) and 71 skills on day one
produces a setup you don't understand and can't debug. In dependency order:

**1. Context.** A root `CLAUDE.md` and `~/.claude/CLAUDE.md`. Nothing else works without
this. Write what a competent new hire would need on their first day and no more.

**2. Two or three hooks.** The ones that pay immediately:

- `block-dangerous-commands.sh` — `PreToolUse` on `Bash`
- `auto-format.sh` — `PostToolUse` on `Write`/`Edit`
- `protect-sensitive-files.sh` — `PreToolUse` on `Write`/`Edit`

Add `quality-gate-tests.sh` (`Stop`) and `pre-commit-checks.sh` (`PreToolUse` on `Bash`)
**only when your affected-test run is under ~2 minutes.** Both have generous timeouts
because they gate real work; on a slow suite they will feel like the tool is broken.

**3. A permission deny-list.** Copy `global/settings.json`'s `permissions.deny` more or
less verbatim — credentials and key material unreadable, PR-merge denied. This is the
cheapest safety in the whole setup.

**4. Skills, as you notice repetition.** The rule of thumb: the third time you explain the
same procedure, it becomes a skill. Don't port all 71 — most encode conventions that are
not yours.

**5. Memory, from zero.** `global/memory/` here is _my_ seven months of gotchas; almost
none of it applies to your stack. Keep `MEMORY.md`'s format and the four frontmatter types,
delete the content, let yours accumulate.

**6. The PM ceremony,** if you want tracked epics. Needs `gh` authenticated and the
sub-issue extension:

```bash
gh extension install yahsan2/gh-sub-issue
```

Then `/pm:init`. See `global/commands/pm/NOTICE.md` for what is upstream CCPM and what I
added.

## The worktree CLI, if you want it

`project/scripts/local-multi-instance/acme-worktree` allocates a workspace per worktree — ports,
database name and Docker project name all derived from one integer — so several checkouts of the
same monorepo run at once without colliding. It is optional and independent of everything else
here. The design, and the reasons behind each rule, are in
[`deep-dives/worktree-workspace-allocation.md`](deep-dives/worktree-workspace-allocation.md).

Needs `jq`, `git` and `tmux`. Install it by **symlink, not copy**:

```bash
ln -sf "$PWD/project/scripts/local-multi-instance/acme-worktree" ~/.local/bin/acme-worktree
cp project/scripts/local-multi-instance/multi-instance.config.example.json \
   project/scripts/local-multi-instance/multi-instance.config.json
```

The symlink matters. The original of this script was installed as a copy, and the two versions
were one edit away from disagreeing at any moment with nothing to detect it — you would be
debugging the version you were not reading.

Then edit the config's `paths` and `apps` blocks to match your repo before the first run. Every
port, database name and container name comes from that file; nothing is inferred from directory
names.

`acme-worktree doctor --dry-run` is the safe first command. It reports drift in both directions —
registry entries whose worktree is gone, and worktrees that were never registered — and changes
nothing.

## Things you must edit before use

- **`project/.mcp.json`** — the server list points at an `acme-mcp` binary that does not
  exist here. Delete or replace it.
- **`global/settings.json` → `permissions.allow`** — scoped to cloud resources that aren't
  yours.
- **`autoMode.environment`** — eight statements describing an organisation that isn't
  yours. Rewrite or remove.
- **`project/.claude/settings.json` → `enabledPlugins`** — assumes marketplaces you may
  not have added.
- **Hooks referencing project tooling** — `enforce-nx-commands.sh` assumes an Nx monorepo;
  `enforce-nestjs-patterns.sh`, `validate-helm-charts.sh`, `validate-k8s-manifests.sh` and
  `validate-event-contracts.sh` each assume a stack. Read before wiring.

## Copy or symlink?

Symlink `~/.claude/{rules,references,agents,commands}` at this repo if you want a single
source of truth across machines and are happy editing here. Copy `project/.claude/` — it
belongs to the repo it governs and should diverge per project.

One caveat learned the hard way: if `.claude` is a symlink inside a git worktree, a
`git reset --hard` will not traverse it, and `git add` from a subagent can race. Keep the
symlink at `~/.claude`, not inside a repo.

## Verifying it works

```bash
claude                       # SessionStart hooks should fire visibly
/pm:help                     # PM suite loaded
/triage                      # read-only; writes .claude/triage/inbox.md
```

If the `Stop` hook makes sessions feel slow, that is the affected-test run — fix the tests
or drop the hook. Don't disable it and keep the reputation of having it.
