# Platform — repo guide for Claude Code

This repo implements **Acme Platform**, a multi-tenant UK commodity-trading + finance platform, using the
`@acme/ui` component kit. Trading and finance screens are implemented from a committed **hi-fi prototype**
— recreate its look, copy and behaviour in this codebase; never ship the prototype's HTML/JSX.

## Read before building UI
- **Design + domain spec:** @design/platform-prototype/CLAUDE.md
- **Feature specs (authoritative for rules):** @docs/platform/doc-site/platform/features/
- **The prototype screen you're implementing:** `design/platform-prototype/screens-*.jsx`

## Must-hold invariants (the rules themselves live in the feature specs above)
- Rates are **configuration**, sourced from the rules table. **Never hard-code or invent a rate** — an invented rate is a silently wrong financial record, not a failing test.
- Status is **derived** from stored fields, never set by hand; no control writes a status directly.
- Irreversible actions are behind **type-to-confirm** and snapshot what they will be audited against.
- Corrections are **additive delta adjustments** beside the immutable original — never mutate an original record.
- Posting to an external system is **idempotent under a stable key**, so a retry cannot double-post.
- Money: an amount in a non-base currency shows **original + base amount + rate + as-at date**, with the rate snapshotted at confirmation.
- Status renders as **text + icon, never colour alone**. en-GB, dates **DD/MM/YYYY**, money right-aligned monospace.
- **RBAC:** gate every financial/destructive action by persona; disabled controls state *why*.

## Conventions
- Reuse `@acme/ui` primitives. New ones introduced by the prototype to promote into the kit:
  `StatusStepper`, `MetricRail`/`Metric`, `AmountCell`, `Segmented`, `Kbd`.
- Every list/table screen ships **empty / loading (skeleton) / error+retry / permission-denied** states.
- Type everything: `Deal`, `Invoice`, `CommissionLine`, `Payout`, `Adjustment`, `Counterparty`, …
- Target WCAG 2.2 AA in **both** themes; tables need a real `role="grid"` + arrow-key nav and mobile card degradation.

## Configuration surface (persisted; keep the same axes/keys)
The app exposes and persists a full config matrix — every screen/component must support all of it, driven by
tokens/contexts in `@acme/ui`:
- **Accent** (`accent`): indigo·steel·graphite·ocean·emerald·copper via `data-theme`. **Theme** (`theme`):
  light·dark·system. **Density** (`density`): comfortable·compact. **Fidelity** (`fidelity`): mockup·wireframe.
  **Reduce motion** (`reduceMotion`), **banner** (`bannerHidden`), **persona** (RBAC), **tenant** (multi-tenant).
- Surfaced via the **Tweaks panel** + top-bar switchers; restored from localStorage. Detail: @design/platform-prototype/CLAUDE.md.

## Tooling in this repo
- Subagent **`platform-ui`** — use for any trading/finance UI work; it applies the kit + these rules.
- Command **`/implement-screen <name>`** — recreate a prototype screen in this codebase, end to end.
