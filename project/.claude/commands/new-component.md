---
description: Scaffold a new @acme/ui component — token-driven, themeable, accessible, typed, with stories and tests.
argument-hint: <ComponentName> [one-line purpose]
---

Create a new `@acme/ui` component: **$ARGUMENTS**.

Follow the design-system rules in `packages/ui/CLAUDE.md`. Work in this order:

1. **Check it doesn't exist.** Grep the package for the name and near-synonyms; if a component is close,
   extend it instead of adding a new one. If it originated in the Platform prototype (e.g. `StatusStepper`,
   `MetricRail`/`Metric`, `AmountCell`, `Segmented`, `Kbd`), read `design/platform-prototype/` and match it.
2. **Design the API.** Define props with exported TypeScript types: `variant` / `size` enums over boolean
   soup, controlled with an uncontrolled fallback, `forwardRef`, `className` + aria/data passthrough. State
   the API before coding it.
3. **Implement token-driven + themeable.** Pull colour/spacing/radius/shadow/type from tokens — no hardcoded
   values a token covers. Must work across the full matrix: all 6 accent presets (`data-theme`), light/dark/
   system, comfortable/compact density, wireframe fidelity, and forced reduced-motion — with no caller effort.
4. **Accessibility (WCAG 2.2 AA).** Keyboard operable, visible focus, correct ARIA roles, status by text +
   icon (never colour alone), ≥44px targets, `prefers-reduced-motion` honoured.
5. **States.** Cover default / hover / active / focus / disabled; plus loading / empty / error for data
   components. Disabled surfaces a caller-supplied reason — never a dead control.
6. **Stories + tests.** Storybook stories for every variant, size and state incl. dark mode + both densities;
   unit and a11y tests.
7. **Wire it up.** Export from the package index and add an entry to the component inventory (`COMPONENTS.md`):
   name, purpose, props, variants, states.
8. **Report** the public API, tokens used, a11y coverage, and which Platform screens will consume it.

If the name or intended behaviour is ambiguous, ask before scaffolding.
