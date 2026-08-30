# CLAUDE.md — @acme/ui (Platform UI kit)

Extends root `CLAUDE.md`. Nx lib `platform-ui` (`libs/platform/ui`) — the shared Platform component kit.
Two barrels: **`@acme/ui`** (`src/index.ts`) and **`@acme/ui/domain`** (`src/domain/index.ts`).
`apps/platform-frontend` and `apps/platform-design-demo` consume it; the demo is the live reference.

## This is where new UI primitives are born (policy AD-7)

Platform pages must not add bespoke components — any gap is filled **here first**: implementation +
Storybook story + test + export from the correct barrel, then consumed downstream. Keep components
themeable (light/dark, comfortable/compact) and accessible by construction (WCAG 2.2 AA).

## Structure

`src/lib/` (components), `src/domain/` (finance domain bits: `TypeBadge`, `LifecycleStepper`,
`fmtGBP`, charts — Waterfall/ErpStatusPie/FailureTrend/CommissionStackedBar/AgeingBar),
`src/theme/`, `src/styles/`, `.storybook/`, `test/`. Barrels: `src/index.ts`, `src/domain/index.ts`.

## Design alignment

Components realise the **"Platform v2"** design — `docs/platform/design/platform-v2-prototype/` (appearance),
`docs/platform/design/platform-v2-alignment.md` (mapping + invariants). Prototype primitives promoted into
the kit: `StatusStepper`, `MetricRail`/`Metric`, `AmountCell`, `Segmented`, `Kbd`, `DescriptionList`.

## Config matrix — the kit owns this (`src/theme/`)

`ThemeProvider` applies and persists the presentation axes so apps get them for free; components must
render correctly across all of them with **no caller effort**, reading tokens only.

- **Tokens** = the `--brand-50…950` CSS-var channels re-pointed by `data-theme` (`src/styles/theme.css`
  - `preset.css`), 8-pt spacing, `soft`/`pop` shadows, Inter + JetBrains Mono. Never hardcode a hex/px a
    token covers. **Status colours are fixed** (meaning) — never re-skin them with the accent.
- **Axes** (`src/theme/accents.ts`; `ThemeProvider.tsx`; localStorage `acme:accent|mode|density|fidelity`):
  6 accents (`data-theme`), theme light/dark/system (`.dark`, `system` via `matchMedia`), density
  comfortable/compact (`.density-*`), fidelity mockup/wireframe (`.wireframe`). Storybook `.storybook/
preview.tsx` exposes accent/mode/density/fidelity as toolbar globals — keep them working.
- **Known gaps (see `docs/platform/design/platform-v2-alignment.md`):** there is **no `FidelityToggle`**
  component (fidelity is provider-applied but not user-switchable), and the forced **`.force-reduce-motion`**
  class exists in CSS but is **not wired** into `ThemeProvider` (only OS `prefers-reduced-motion` is
  honoured). Completing either = kit component first, then render in `apps/platform-frontend` `AppLayout`.

## Bars every component must clear

- **A11y:** visible focus, full keyboard operability, correct ARIA; data tables expose `role="grid"`
  - arrow-key nav; honour `prefers-reduced-motion`; adequate target sizes. Both themes.
- **Status** renders as **text + icon, never colour alone**. Money right-aligned monospace, en-GB.
- **Story + test required** — a new/changed component ships with a Storybook story and a test.

## Gotchas (see `.design-sync/` and memory)

- The kit is synced to a Claude Design "Design System" project via `/design-sync` (`.design-sync/`).
- `@nx/vite:test` needs `reporters: ['default']` or output is blindfolded (empty output froze image
  builds before — #1370/#1398). Run tests via Nx: `nx test platform-ui`.
- Two barrels must both stay exported; `@acme/ui/domain` bits are public API (don't drop them).
