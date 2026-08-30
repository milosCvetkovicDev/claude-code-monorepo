export const meta = {
  name: 'platform-ui-review-fixes',
  description: 'Parallel fixes for the expert-review polish + missing tests',
  phases: [{ title: 'Fix' }],
};

const LIB = 'libs/platform/ui/src';

const RULES = `
HARD RULES:
- Edit ONLY the files named in YOUR TASK. Never touch any other component, the barrels (index.ts/domain/index.ts), or config files not named.
- Do NOT run git/commit. You MAY run read-only greps and (for the tests task) the named nx test command to self-verify.
- Strict TypeScript, no \`any\`, named exports, keep brand-* tokens themeable. Match existing file style.
- Editing a React (.tsx) file is allowed (the react breadcrumb exists). Make minimal, surgical edits — do not rewrite whole files unless necessary.
`;

const TASKS = [
  {
    id: 'badge-dark',
    label: 'Badge dark-mode variants',
    prompt: `Fix: ${LIB}/lib/Badge.tsx — the first status block (OPEN, LOCKABLE, LOCKED, DRAFT, CONFIRMED, RECEIPTED, FINALISED, INVOICED) has full \`dark:\` variants, but the SECOND block (CANCELLED, PENDING_APPROVAL, APPROVED, REJECTED, PROCESSING, PROCESSED, FAILED, PAID, VOID, CALCULATED, Active, Inactive, POSTED, PENDING, SKIPPED) and the fallback style have NO dark: variants, so they are near-invisible in dark mode. Add \`dark:bg-<colour>-950 dark:text-<colour>-300 dark:ring-<colour>-900\` to every status entry that lacks them, following the exact pattern already used by OPEN/LOCKABLE. Pick the dark shade family matching each entry's existing light colour (emerald/rose/amber/sky/slate/violet/teal). Do the same for any light-only entry in ${LIB}/domain/TypeBadge.tsx. Change ONLY these two files.`,
  },
  {
    id: 'charts-darkmode-props',
    label: 'Chart dark-mode + dynamic props',
    prompt: `Fix these chart files only (each is hand-built SVG in ${LIB}/domain/charts):
1. Heatmap.tsx — the intensity ramp is hardcoded indigo \`hsl(238 70% L%)\` and ignores the accent. Replace it so cells follow the live brand token: use inline style \`background: \`rgb(var(--brand-600) / \${alpha})\`\` where alpha scales 0..1 with the cell's normalised intensity (keep a low floor so empty cells are faint). Remove the hardcoded hue.
2. DonutChart.tsx and ErpStatusPie.tsx — replace \`stroke="white"\` (slice separators) with \`stroke="currentColor" strokeOpacity="0.15"\` so separators invert in dark mode.
3. CommissionStackedBar.tsx — the \`fill="#cbd5e1"\` background bars don't adapt to dark mode. Replace with a dark-aware approach: \`className="text-slate-300 dark:text-slate-700"\` on the rect + \`fill="currentColor"\`.
4. RevenueLineChart.tsx — (a) replace the FY-divider \`stroke="#94a3b8"\` with \`className="text-slate-400 dark:text-slate-600" stroke="currentColor"\`; (b) it currently finds the FY divider by \`data.findIndex(d => d.m === 'Nov 25')\` and renders a hardcoded 'FY 25-26 start' legend — replace with an optional prop \`fyDividerMonth?: string\` on RevenueLineChartProps: the divider (and its legend label, derived from the prop) render ONLY when the prop matches a data month; default undefined => no divider, no FY legend entry.
5. BulletChart.tsx — the threshold marker is hardcoded at \`left: '60%'\`. Add an optional prop \`threshold?: number\` (0..100 as a percent of max). Render the marker ONLY when threshold is provided; otherwise omit it. Default => no marker.
6. AgeingBar.tsx — it defines \`const colours = [SEMANTIC.positive, '#0072B2', '#E69F00', '#D55E00']\`. Replace the three raw hex with CHART_PALETTE references (they are CHART_PALETTE[0], [1], [5]) imported from './palette'. Keep SEMANTIC.positive.
Type every new prop. Keep all other behaviour identical.`,
  },
  {
    id: 'theme-a11y',
    label: 'Focus-ring contrast + spinner reduced-motion + KPITile sr-only',
    prompt: `Three small fixes:
1. ${LIB}/styles/theme.css — under the \`prefers-reduced-motion: reduce\` block, \`.cc-spinner\` is reinstated with \`animation: ... infinite !important\` (keeps spinning). Replace that override so under reduced motion the spinner does NOT animate: set \`animation: none\` for .cc-spinner (and .cc-spinner-dot) inside the reduced-motion block; the conic-gradient ring still reads as a loading indicator while static.
2. Focus-ring contrast: grep ${LIB} for \`brand-400\` used in focus contexts (e.g. \`focus:ring-brand-400\`, \`focus-visible:ring-brand-400\`) in Input.tsx, Select.tsx, CodeInput.tsx, and DataTable.tsx search. brand-400 is too light under the graphite/copper presets (fails 3:1). Bump those focus ring utilities from brand-400 to brand-500. Change ONLY the focus-ring colour utilities — leave non-focus styling alone. (If no brand-400 focus utilities exist, report that and change nothing.)
3. ${LIB}/lib/KPITile.tsx — the delta chip conveys up/down only via colour + arrow icon. Add a visually-hidden text node inside the delta chip: \`<span className="sr-only">{up ? 'up' : 'down'} {Math.abs(delta)}% vs prior period</span>\`. Keep the visible arrow + percentage.
Touch only theme.css, the focus-ring files you actually change, and KPITile.tsx.`,
  },
  {
    id: 'specs',
    label: 'Missing behavioural specs (request-changes)',
    prompt: `Add the missing high-value specs the test review demanded. Mirror the existing spec style (${LIB}/lib/__tests__/CodeInput.spec.tsx, Popover.spec.tsx). Use @testing-library/react + userEvent; globals are on (describe/it/expect/vi); setup mocks matchMedia + IntersectionObserver. Write these files ONLY:

1. ${LIB}/lib/__tests__/CountUp.spec.tsx — import { CountUp } from '../CountUp'. (a) With matchMedia mocked to prefers-reduced-motion: true (override window.matchMedia in the test to return { matches: true, addEventListener: vi.fn(), removeEventListener: vi.fn() }), assert the formatted value renders IMMEDIATELY (e.g. value=1234 with format default shows '1,234'). (b) Assert a custom \`format\` prop is applied. (c) axe-clean via expectNoAxeViolations from './axe-helper'.

2. ${LIB}/lib/__tests__/CommandPalette.spec.tsx — import { CommandPalette } from '../CommandPalette'. Cover: renders nothing when open=false; renders dialog+combobox input when open=true; typing filters the list; ArrowDown/ArrowUp move aria-selected (assert the option with aria-selected="true"); Enter calls onNav with the active item's path and onClose; Escape calls onClose; backdrop click calls onClose. Pass a small \`commands\` array. axe-clean.

3. ${LIB}/lib/__tests__/DataTable.spec.tsx — import { DataTable } from '../DataTable'. Use ~5 inline rows + 3-4 typed columns. Cover at least: (a) renders all rows; (b) global search input filters visible rows; (c) clicking a sortable header reorders rows (assert first cell order); (d) an enum column filter excludes unchecked values; (e) empty state shows when search matches nothing; (f) CSV export — you may assert the export button exists and is type=button (do not assert file download). Use vi.useFakeTimers() ONLY if needed for the 250ms search debounce, restoring real timers in afterEach. axe-clean on initial render.

4. Strengthen ${LIB}/theme/__tests__/ThemeProvider.spec.tsx — ADD one test for the fidelity dimension: a Controls button calling setFidelity('wireframe'); assert document.documentElement gets the 'wireframe' class. (Append; do not remove existing tests.)

5. Strengthen apps/platform-design-demo/src/app/app.spec.tsx — replace the two weak assertions: test 1 should assert a real landmark/role is present (e.g. screen.getByRole('navigation') or getByRole('banner')); keep the dashboard-heading test. (Do not weaken; make assertions meaningful.)

After writing, SELF-VERIFY by running exactly: \`npx nx run platform-ui:test --skip-nx-cache\` and \`npx nx run platform-design-demo:test --skip-nx-cache\`. Iterate until BOTH report success. Return the final pass/fail line for each. If a scenario proves impossible to make reliably green, note it and skip that single assertion rather than leaving the suite red.`,
  },
];

const SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    filesChanged: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
    verification: { type: 'string' },
  },
  required: ['filesChanged', 'summary'],
};

phase('Fix');
log(`Applying ${TASKS.length} review-fix tasks in parallel`);

const results = await parallel(
  TASKS.map((t) => () =>
    agent(`${t.prompt}\n\n${RULES}\n\nReturn the files you changed + a one-line summary (+ verification for the tests task).`, {
      label: `fix:${t.id}`,
      phase: 'Fix',
      schema: SCHEMA,
      agentType: 'general-purpose',
    }).then((r) => ({ task: t.id, ...(r || { filesChanged: [], summary: 'no result' }) }))
  )
);

log('Review-fix tasks complete');
return { results };
