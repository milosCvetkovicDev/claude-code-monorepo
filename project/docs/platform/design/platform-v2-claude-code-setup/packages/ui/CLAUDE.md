# @acme/ui — design-system authoring guide for Claude Code

`@acme/ui` is the **productized component kit + token system** that Platform and every other Acme app
consumes. It is the **single source of truth for components and tokens**. Components here are
**presentational and reusable**, and contain **no app or domain logic** — domain rules live in the apps
(see the Platform app's `CLAUDE.md`).

## The token contract (the interface with every app)
- **Colour:** brand/accent is an 11-step scale delivered as **CSS-var channels**, re-skinnable via
  `data-theme="…"`. Status colours are fixed (they carry meaning). Apps consume tokens — never hardcode hex.
- **Type:** Inter for UI; **JetBrains Mono** for every figure, ID, code and currency (right-aligned, tabular).
- **Spacing** on an 8-pt grid; radius `md`+; elevation `soft` (cards) / `pop` (popovers, modals).
- **Modes:** every component supports **light + dark** and **comfortable + compact** density out of the box.

## Configurations the kit must support (first-class, not per-app)
The prototype ships a full runtime configuration matrix; the kit must absorb it so apps get it for free:
- **6 accent presets** — `indigo` (default), `steel`, `graphite`, `ocean`, `emerald`, `copper` — as
  `data-theme` token sets over the `--brand-*` channels. Components read tokens only, so switching `data-theme`
  re-skins everything. Ship the presets in the kit; status colours stay fixed.
- **Theme** light / dark / system, **density** comfortable / compact (via a density context or `.density-*`
  wrapper — not per-component hacks), **fidelity** mockup / wireframe (components stay legible under the
  grayscale layer), and **forced reduced-motion** (honour both `prefers-reduced-motion` and `.force-reduce-motion`).
- Storybook must expose accent / theme / density as toolbar globals so every story is checked across the matrix.

## Every component must
- Be **token-driven** and themeable; **light/dark + density** parity with no caller effort.
- Meet **WCAG 2.2 AA**: keyboard, visible focus, correct ARIA (grid/dialog/menu/tablist), **status = text +
  icon, never colour alone**, ≥44px targets, `prefers-reduced-motion`.
- Be **typed** (exported prop types), `forwardRef` where wrapping a DOM node, pass through `className` + aria/data.
- Cover its **states**: default / hover / active / focus / disabled (reason surfaced by caller); plus
  loading / empty / error for data components.
- Ship with **Storybook stories** (every variant/size/state incl. dark + both densities) and **tests**.

## API conventions
- `variant` + `size` enums over boolean soup; controlled with an uncontrolled fallback; composable, not
  layout-opinionated.
- Shared contracts live in the kit and are rendered by components: **status → colour + icon**, the
  **lifecycle registry**, and formatters (`fmtGBP`, `fmtNum`, `fmtDate`, `fmtPct`, en-GB).

## Current inventory + what to add
- **Established:** Button, Badge, Card, Modal, Tabs, Tooltip, Popover, Toast, Spinner, Field/Input/Select,
  EmptyState, KPITile, Sparkline, PageHeader, DataTable, LifecycleStepper, TypeToConfirm.
- **Promote from the Platform prototype (build/maintain here):** `StatusStepper`, `MetricRail`/`Metric`,
  `AmountCell` (orig+GBP+FX), `Segmented`, `Kbd`. Match the prototype in `design/platform-prototype/`.
- **DataTable** needs a real `role="grid"` + arrow-key cell nav and mobile card degradation with a frozen
  key column — build these into the kit so every app inherits them.

## Handshake with the apps
When an app (Platform) needs a primitive that doesn't exist, it's authored **here first**, exported +
documented, then consumed. Keep `COMPONENTS.md` (the inventory) current so consumers know what exists.

## Tooling
- Subagent **`acme-ui-author`** — use for building/maintaining kit components.
- Command **`/new-component <Name>`** — scaffold a component with stories, tests, tokens, a11y and export.
