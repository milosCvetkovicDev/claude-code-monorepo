---
name: platform-v2-design-setup-and-claude-distribution
description: '"Platform v2" Claude Design "Claude Code setup" export integrated (platform-ui agent + /implement-screen); and the .claude-symlink vs docs-per-branch distribution mechanism for pushing changes to ALL acme sister sessions'
metadata:
  node_type: memory
  type: reference
  originSessionId: 00000000-0000-0000-0000-000000000067
---

The **"Platform v2"** product design (Claude Design project `00000000-0000-0000-0000-000000000053`,
owner Milos) ships a **"Claude Code setup"** export (`Platform v2.zip`: root `CLAUDE.md` + `README.md`

- `.claude/agents/platform-ui.md` + `.claude/commands/implement-screen.md`). Integrated 2026-07-01:

* **Live for all sessions:** path-adapted `platform-ui` subagent (`.claude/agents/platform-ui.md`) +
  `/implement-screen <name>` command (`.claude/commands/implement-screen.md`) — recreate a Platform
  trading/finance prototype screen on `@acme/ui`. Domain invariants are verified against the
  AUTHORITATIVE feature specs before shipping — a screen that looks right but contradicts a
  documented invariant does not ship (the invariants themselves are business policy and are not part
  of this export). Distinct from the KIT sync in [[platform-ui-design-sync]] (project 00000000).
* **Durable record:** PR **#1561** (`docs/platform-v2-design-alignment` → main) — verbatim export at
  `docs/platform/design/platform-v2-claude-code-setup/` (byte-identical + `PROVENANCE.md`), adapted
  `docs/platform/design/platform-v2-alignment.md`, additive pointer in root `CLAUDE.md`. Prototype itself
  stays vendored at `docs/platform/design/platform-v2-prototype/` — the setup export does NOT refresh
  screens (re-export the prototype handoff bundle for that). See [[platform-finance-ui-epic]].

- **Bundle 2 (`Platform v2 (1).zip`, 2026-07-01) — design-system authoring side + config matrix.** Adds
  `acme-ui-author` subagent + `/new-component` (kit-first: author in `@acme/ui` FIRST, then consume;
  policy AD-7) + `packages/ui/CLAUDE.md`→`libs/platform/ui/CLAUDE.md`. Threads the 8-axis **config matrix**
  through everything. All folded into PR #1561.
- **CONFIG-SURFACE AUDIT (origin/main, 2026-07-01, 11 axes, adversarially verified via workflow):** KIT
  strong — `ThemeProvider` (`libs/platform/ui/src/theme/`) wires + persists 4 theme axes (localStorage
  `acme:accent|mode|density|fidelity`), all 6 accents (`[data-theme]` in `styles/theme.css`), Storybook
  toolbar globals complete. APP (`apps/platform-frontend`, MUI GONE, uses `KitThemeProvider` + FOUC guard):
  **accent/theme/density fully user-facing** (`AccentPicker`/`ThemeToggle`/`DensityToggle` in `AppLayout`).
  GAPS (all low/med, NO functional regression): **fidelity/wireframe** plumbed+persisted but NO
  `FidelityToggle` (deliberate per FR-S5 `it.todo`); **forced reduceMotion** `.force-reduce-motion` CSS
  exists but NOT wired in TS (OS `prefers-reduced-motion` works); **tenant** `TenantSwitcher` built but
  switch endpoints parked (#1276); **tweaks-panel** not aggregated (scattered header toggles); **banner**
  absent (prototype-only). **persona=real auth** (RequireAuth/RequireRole/canPerform — NOT a demo switcher;
  correct). Dead CSS: `.row-y` (theme.css) unused. To reach parity: add FidelityToggle + wire forced
  reduceMotion (kit-first → render in AppLayout).
- **PARITY IMPLEMENTED — PR #1562** (`feat/platform-config-matrix-parity` → main, code — separate from
  the docs PR #1561): kit-first per AD-7. `ThemeProvider` got a 5th axis **`reduceMotion`** →
  `.force-reduce-motion` + `acme:reduce-motion` localStorage; new kit controls **FidelityToggle**,
  **ReduceMotionToggle**, and a unified **SettingsPanel** ("Tweaks" popover aggregating accent swatches
  - theme + density + fidelity + reduce-motion). App `AppLayout` header now renders one `<SettingsPanel/>`
    (replaced the scattered trio); `index.html` FOUC applies force-reduce-motion; FR-S5 test decision
    flipped (fidelity+reduce-motion NOW exposed; persona switcher STAYS dropped = real auth). Demo top bar
    uses SettingsPanel. VERIFIED green off origin/main: platform-ui 380 tests+typecheck+build, platform-frontend
    455 tests+typecheck, demo 6+typecheck, lint 0 errors. **React edit needed `react.fetched`
    source-driven-dev breadcrumb** (skill fetched React docs → touched primary `.claude/.source-driven-dev/`;
    see [[feedback_source_driven_dev_breadcrumb_cwd]]). Tenant switch still backend-blocked (#1276); banner
    = prototype-only, not built.
- **FE ALIGNMENT SWEEP + kit hardening — epic `platform-v2-fe-alignment`, PR #1565** (`feat/platform-fe-alignment-sweep`
  → `feat/platform-config-matrix-parity`, STACKED on #1562; retarget to main after #1562 merges). PM ceremony
  done (PRD + epic.md + 7 tasks in `.claude/epics/platform-v2-fe-alignment/`; 001=tooling/#1561, 002=config-matrix/
  #1562, 003=money✓, 004=kit-adoption✓, 005=states✓, 006=kit-hardening✓, 007=prototype-fidelity OPEN).
  TWO adversarial audit workflows drove it: (a) **app alignment audit** (21 confirmed — tokens 0/clean,
  theming-matrix 0/clean, kit-adoption 3, states 7, a11y 1, **locale-money 8**, prototype-fidelity 2);
  (b) **kit expert review** (security **CLEAN**/hardened — sanitizeHref + CSV formula-injection guard + no
  XSS/ReDoS; MUI-purity **PURE** 0 @mui; code-quality 6, perf 3, dark-mode 1; docs=missing COMPONENTS.md).
  Fixed+verified+committed: money (fmtGBP/2dp/fmtPct on 5 dashboard widgets + InvoiceDetailPage), kit
  code-quality+perf+dark-mode (10, +9 specs — DataTable col-order reconcile + filter/order decouple +
  enum-memo, CodeInput mid-edit, chart ÷0 guards, Intl hoist, BulletChart), `COMPONENTS.md` inventory,
  app states (7) + kit-adoption (3, incl NotificationPrefs table→DataTable). GATE GREEN: platform-ui 393 /
  platform-frontend 468 / demo 6 tests, typecheck 3/3, **lint 0 errors**. OPEN: 007 (RecentActivity widget +
  Payouts MetricRail — additive), epic-sync (GitHub issues not yet created).
  **LESSON (reinforces [[feedback_review_subagents_mutate_git_state]] + [[feedback_nx_format_write_overreaches_scope]]):**
  the app subagent ran `nx format:write` which reformatted my 2 UNCOMMITTED app swaps, then it `git checkout`-
  REVERTED them as "unrelated drift" → my work vanished. **Commit before dispatching a subagent into the same
  worktree, or brief it NOT to run repo-wide format:write / revert files it didn't create.** Also: a subagent's
  `// eslint-disable-next-line react-hooks/exhaustive-deps` errored lint (that rule is NOT configured in
  platform-ui → "Definition for rule not found"); grep/Edit mis-detected the file as binary — removed via `sed Nd`.

**DISTRIBUTION MECHANISM — "make all sister sessions up to date" (reusable):**

- **`.claude/` is symlink-shared across EVERY worktree** (`<wt>/.claude → $PROJECT_ROOT/.claude`).
  Dropping a file into the primary `.claude/agents|commands|skills/…` makes it **instantly live for all
  local sister sessions** — no git, no merge. New/reloaded sessions pick it up (running ones may need
  `/agents` reload). `.claude` is git-**excluded** (`.git/info/exclude:18` matches ANY path component
  named `.claude`, at any depth) → new `.claude` files need `git add -f` to track; usually you DON'T —
  the symlink is the distribution. (Also means a nested `docs/.../.claude/` is excluded — de-dot to
  `agents/`,`commands/` when vendoring an export.)
- **`docs/**`and root`CLAUDE.md`are per-branch** (each worktree checks out its own branch's copy) →
to reach every checkout / fresh clone / teammate they must land on **main via PR**, then each worktree
merges main. Agent/command files should therefore reference only always-present tracked paths (vendored
prototype +`docs/platform/doc-site/platform/features/`) and carry their invariants INLINE.
- **3 alignment layers (idiomatic acme):** (1) always-on = root `CLAUDE.md` pointer (keep LEAN — it
  loads for backend/infra/CI too, so never inline the whole design spec); (2) on-demand = `.claude/`
  agent+command (symlink-shared); (3) **scoped auto-load = subtree `CLAUDE.md`** — acme already gives
  `apps/legacy-web`,`apps/legacy-api`,`infra`,`libs/shared/domain-types`,`docs/platform` their own,
  loaded ONLY when editing that subtree. Added `apps/platform-frontend/CLAUDE.md` + `libs/platform/ui/CLAUDE.md`
  (PR #1561) so UI-code sessions auto-load design rules without global bloat. Scoped `CLAUDE.md` are
  normal TRACKED files (only the `.claude` DIR is excluded).
- **Clean-branch tip:** build such a PR in a throwaway worktree off `origin/main`
  (`git worktree add -b <br> <path> origin/main`) so you don't disturb the primary's in-progress branch.
  Fresh worktree has no `node_modules` → commit/push with `SKIP_HOOKS=1`; format-check authored md from
  the PRIMARY (`npx prettier --check`); prettier-ignore any byte-identical vendored bundle.
