---
description: Recreate a Acme Platform prototype screen in this codebase, end to end, using @acme/ui.
argument-hint: <screen name or hash route, e.g. "invoice detail" or "#/commission/rules">
---

Implement the Acme Platform screen: **$ARGUMENTS**.

Work in this order and show your reasoning at each step:

1. **Locate it in the prototype.** Find the matching screen in `design/platform-prototype/` (search
   `screens-*.jsx` and the hash route in `app.jsx`). Read the component and any pieces it renders.
2. **Restate the design.** Summarise layout (grid/flex, widths, spacing), the components used, exact copy,
   the interactions, and every state (empty / loading / error / permission-denied / success).
3. **Map to `@acme/ui`.** For each element, name the existing kit component to reuse. Flag anything that
   needs a new primitive (`StatusStepper`, `MetricRail`/`Metric`, `AmountCell`, `Segmented`, `Kbd`, …) and
   build it as a reusable, themeable component.
4. **List the domain rules that apply here** — take them from `@design/platform-prototype/CLAUDE.md` and
   `docs/platform/doc-site/platform/features/`, quote each one, and say how this UI enforces it. Two
   conventions always apply: RBAC disable-with-reason (a gated control states *why* it is disabled), and
   status rendered as text + icon, never colour alone. A rule you cannot find in the spec is a question
   for the team, not a rule to infer.
5. **Implement** in this repo's stack and patterns — TypeScript, real components, server-side list
   filter/sort, typed data shapes. Do not port the prototype's HTML/Babel.
6. **Cover the non-functionals:** all states, WCAG 2.2 AA (focus, keyboard, `role="grid"` tables, ARIA),
   the full config matrix (6 accent presets, light/dark/system, comfortable/compact, wireframe,
   reduced-motion), responsive down to mobile card degradation, en-GB / GBP /
   DD-MM-YYYY, right-aligned monospace money.
7. **Report:** components reused vs. added, rules enforced, and any spec gaps to resolve with the team.

If the screen name is ambiguous or spans multiple prototype views, ask which one before building.
