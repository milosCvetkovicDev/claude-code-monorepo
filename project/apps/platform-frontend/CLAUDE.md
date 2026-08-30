# CLAUDE.md — Platform Frontend

Extends root `CLAUDE.md`. React + `@acme/ui` (NOT MUI) + Vite. This app renders the Platform
trading & finance screens from the approved **"Platform v2"** design.

## Build from the design — always

- **Design (appearance):** the vendored "Platform v2" prototype at
  `docs/platform/design/platform-v2-prototype/` (project/screens-\*.jsx, chats/). Recreate it faithfully —
  never port the prototype's HTML/Babel.
- **Rules (behaviour, authoritative):** feature specs at `docs/platform/doc-site/platform/features/`.
  Where prototype and spec conflict, follow the spec and **surface the conflict**.
- **Mapping + invariants:** `docs/platform/design/platform-v2-alignment.md`.
- **Route UI work through the tooling:** the **`platform-ui`** subagent, or `/implement-screen <name>`.

## Kit only — no bespoke (policy AD-7)

Use `@acme/ui` + `@acme/ui/domain` (Nx lib `platform-ui`, `libs/platform/ui`). Any missing component
is built in `libs/platform/ui` **first** (impl + story + test + barrel), then consumed — **no `@mui`,
no bespoke primitives** in pages. `apps/platform-design-demo` is the live kit reference.

## Configuration surface (Platform v2 config matrix)

The app is wrapped in the kit `ThemeProvider` (`app/app.tsx`); `index.html` has an anti-FOUC
pre-paint script. All presentation config is **token/context driven — never per-screen CSS**, and
persisted to localStorage. Do not regress this matrix when adding screens.

| Axis | localStorage key | Status on `main`                                                                                 |
| ------------------------------------------------------------------------ | ------------------- | ------------------------------------------------------------------------------------------------ |
| **accent** (indigo·steel·graphite·ocean·emerald·copper via `data-theme`) | `acme:accent`     | ✅ user-facing (`AccentPicker` in `AppLayout` header), persisted |
| **theme** (light·dark·system)                                            | `acme:mode`       | ✅ user-facing (`ThemeToggle`), persisted |
| **density** (comfortable·compact)                                        | `acme:density`    | ✅ user-facing (`DensityToggle`), persisted (visibly affects `DataTable` rows)                   |
| **fidelity** (mockup·wireframe)                                          | `acme:fidelity`   | ⚠️ plumbed + persisted, **no toggle rendered** (deliberate per FR-S5 `it.todo`)                  |
| **reduceMotion** (forced)                                                | —                   | ⚠️ only OS `prefers-reduced-motion` honoured; forced `.force-reduce-motion` toggle **not wired** |
| **persona** (RBAC)                                                       | — (server identity) | ✅ real auth (`RequireAuth`/`RequireRole`/`canPerform`), **not** a demo persona switcher |
| **tenant**                                                               | — (server)          | ⚠️ `TenantSwitcher` built but switch endpoints parked (#1276)                                    |
| **banner**                                                               | —                   | ➖ prototype-only device; not shipped |

Any NEW presentation axis is added in `@acme/ui` first (ThemeProvider + a toggle), then rendered
in `AppLayout` — never a page-local hack. Never re-skin fixed **status** colours with the accent.

## Structure

`src/`: `pages/`, `components/<domain>/` (`trading`, `dashboard`, `notifications`, `search`,
`shared`), `api/` (typed client + array query-key factory + TanStack hooks per FR-D3), `hooks/`,
`routing/`, `providers/`, `types/`, `styles/`.

## Must-hold invariants (detail in the feature specs — never invent)

- Rates and rate schemes come from the feature spec or config — a UI never invents or hard-codes one _(the schemes themselves are business policy and are not part of this export)_.
- Lifecycle status is **derived server-side** and therefore never user-editable; the irreversible transition is role-gated **and** type-to-confirm.
- Financial records are append-only: a correction is a compensating entry rendered beside the immutable original, never an in-place edit.
- Posting to an external system of record is **idempotent** — the UI may retry, and a retry must not double-post.
- Periods close as a **monotonic, forward-only** state machine evaluated in UTC: no reopening, no future period.
- A converted amount is shown with its **source amount, the rate used and the rate's as-at date**; the rate is snapshotted at the moment the transaction is confirmed, not read live at render.
- Status = **text + icon, never colour alone**. en-GB, dates **DD/MM/YYYY**, money right-aligned monospace.
- **RBAC:** gate every financial/destructive action by persona; disabled controls state _why_.

## Quality bar (every list/table screen)

Ship **empty / loading (skeleton) / error+retry / permission-denied** states. WCAG 2.2 AA in light
**and** dark: visible focus, keyboard, `role="grid"` + arrow-key nav, ARIA, `prefers-reduced-motion`.
Responsive dense → tablet → mobile card degradation (frozen key column ≤640px). Type every data shape;
lists filter/sort **server-side**.

## Conventions

- Env vars via helper (`getRequiredEnvironmentVariableValue()` pattern), not raw `import.meta.env`.
- Numbers: `Big` from `big.js` (parse strings→Big; Big→string for API). Named imports only.
- Row models for kit `DataTable` = `type` (not `interface`); assert `getByRole('grid')` in specs.
