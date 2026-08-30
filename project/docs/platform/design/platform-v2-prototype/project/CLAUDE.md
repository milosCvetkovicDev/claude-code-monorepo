# Acme Platform — prototype → implementation notes

## What this is

This project is a **high-fidelity, clickable prototype** of the Acme Platform trading + finance
workspace, built in React-via-Babel with Tailwind (CDN). It is a **design reference**, not shippable
code. The task for implementation is to **recreate these screens in the real `platform` codebase using
`@acme/ui`** — lift the exact look, tokens, copy and behaviour; do not ship the HTML/JSX here.

Fidelity: **hi-fi** (final colours, type, spacing, interactions). Recreate pixel-close.

## Where things live

- `index.html` — mount, Tailwind config (brand scale as CSS-var channels), script load order.
- `styles.css` — `:root` design tokens + `[data-theme="…"]` accent presets, print & reduced-motion.
- `ui.jsx` — the shared kit (`@acme/ui` equivalents) + formatters (`fmtGBP`, `fmtNum`, `fmtDate`, `fmtPct`).
- `table.jsx` — `DataTable` (sort/filter/saved-views/selection/totals/skeleton/empty).
- `charts.jsx` — hand-built SVG charts (Okabe-Ito palette, view-as-table + export).
- `data.js` — all fixtures (single mock dataset; realistic UK figures).
- `screens-*.jsx` — one file per area (dashboard, trading, deal-detail, finance ×3, other, auth, trading-system).
- `app.jsx` / `shell.jsx` — router (hash), persona/tenant/theme/density state, sidebar, command palette, Tweaks.

## Single sources of truth (use these, don't re-derive)

- **Lifecycles / state machines** → `LIFECYCLES` in `ui.jsx` (deal, purchase, sale, invoice, payout, month:
  steps + transitions + labels + off-path). Screen maps (`PURCHASE_NEXT`, `INVOICE_FLOW`, …) derive from it.
- **Status → colour + icon** → `STATUS_STYLES` + `STATUS_ICONS` in `ui.jsx`. Status must always render as
  **text + icon**, never colour alone (WCAG).
- **Commission maths** → `calcCommission` + `COMMISSION_RULES` in `screens-finance2.jsx` / `data.js`.
- **RBAC** → `PERSONAS[].can` + `.canSee` in `data.js`; denial reasons are per-screen strings (see below).

## Invariants that MUST hold

- **Tenancy — hostname resolution**: each tenant (workspace) is a subdomain of the base domain, and
  some tenants may serve a white-labelled custom domain instead. The apex is not a tenant — it hosts
  discovery plus superadmin sign-in. Credentials are per-tenant, and the tenant is resolved from the
  hostname **before** password entry, so there is no post-auth tenant picker and no in-session tenant
  switch — switching means opening the other origin. Pre-auth screens never reveal whether an address
  exists or which tenants it belongs to (discovery email only). Full change log: **AUTH-FLOW-CHANGES.md**.
- Commission schemes and rates are **configuration, not code** — always sourced from the rules table,
  never hard-coded or invented. The scheme itself is business policy and is not part of this export.
- Status is **derived** from stored fields, never set by hand. A screen that lets a user pick a status
  directly is a bug: it lets the UI assert a state the data does not support.
- Lifecycles are declared **once** (`LIFECYCLES`) — steps, transitions, labels, off-path states — and
  every screen derives from that declaration rather than hard-coding its own order.
- Irreversible actions are guarded by **type-to-confirm**, and they snapshot whatever they will be
  audited against at the moment they fire, rather than recomputing it later from live data.
- Corrections are **append-only deltas beside an immutable original** — never a mutation and never a
  delete. "Reverse" is a new guarded record, not an undo.
- Posting to an external system is **idempotent under a stable key**, so a retried request cannot
  double-post; non-production runs use a distinguishable reference prefix (`TEST-YYYYMMDD-…`) so test
  records can never be mistaken for real ones.
- Money: an amount in a non-base currency always shows **original + base amount + the rate + its as-at
  date**, and the rate is snapshotted at confirmation. A converted figure without the rate and date it
  used cannot be audited.
- Email: never retry a recipient the provider has marked **SUPPRESSED**. Dates **DD/MM/YYYY**, en-GB.

## Configuration surface (all persisted to localStorage; defaults in `app.jsx` `TWEAK_DEFAULTS`)

Every screen and component must render correctly across this **full matrix** — the design system supports
each axis as a first-class token/context contract, never a per-screen override:

- **Accent** (`accent`) — 6 presets: `indigo` (default) · `steel` · `graphite` · `ocean` · `emerald` · `copper`.
  Set as `data-theme="…"` on `<html>`; drives the `--brand-*` CSS-var scale. Status colours stay fixed; never hardcode brand hex.
- **Theme** (`theme`) — `light` · `dark` · `system` (toggles `.dark`; system follows `prefers-color-scheme`).
- **Density** (`density`) — `comfortable` · `compact` (wrapper class `.density-*`; row/control padding).
- **Fidelity** (`fidelity`) — `mockup` · `wireframe` (`.wireframe` desaturates; charts fall back to `currentColor`).
- **Reduce motion** (`reduceMotion`) — forces `.force-reduce-motion`; honour it AND `prefers-reduced-motion`.
- **Prototype banner** (`bannerHidden`) — chrome toggle (prototype-only).
- **Persona** (`persona`) — 5 RBAC roles gate nav + actions. **Tenant** (`tenant`) — 4 tenants; multi-tenant context.
  All surface through the **Tweaks panel** (accent/theme/density/fidelity + motion/banner) and the top-bar
  switchers (persona/tenant), and restore from localStorage on load. In production wire these to user/tenant
  settings — keep the same axes, keys and defaults.

## Component mapping for `@acme/ui`

- **Reuse if present**: Button, Badge, Card, Modal, Tabs, Tooltip, Popover, Toast, Spinner, Field/Input/Select,
  EmptyState, KPITile, Sparkline, PageHeader, DataTable, LifecycleStepper, TypeToConfirm.
- **New primitives introduced here (promote into the kit)**: `StatusStepper`, `MetricRail`/`Metric`,
  `AmountCell` (orig+GBP+FX), `Segmented`, `Kbd`. All now live in `ui.jsx`.

## Known gaps to implement properly (prototype shortcuts)

- **Responsive tables**: only `overflow-x-auto` today. Production needs mobile **card degradation + a frozen
  key column** at ≤640px.
- **DataTable a11y**: rows are keyboard-selectable, but it is not a full `role="grid"` with arrow-key cell
  navigation — add for production.
- **Dark-mode contrast**: not audited to AA — verify both themes.
- Detail views for historical periods have rollup fixtures only, no line-level ones, so they degrade to
  the rollup rather than rendering the detail. Wire to real data.
- Verify the `fidelity: wireframe` tweak maps to a real low-fi mode (or drop it).

## Build reality

Prototype uses Babel-in-browser, Tailwind CDN, and `window`-global components — fine for a mock, not for
production. Target: real components + TypeScript types for every `data.js` fixture (Deal, Invoice,
CommissionLine, Payout, Adjustment, Counterparty, …), server-side filtering/sorting on lists.
