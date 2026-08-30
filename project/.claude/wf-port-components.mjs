export const meta = {
  name: 'platform-ui-port-components',
  description: 'Port Platform v2 prototype components into @acme/ui as typed TSX + stories',
  phases: [{ title: 'Port', detail: 'one agent per coherent component group' }],
};

// ---- Shared brief fragments -------------------------------------------------

const CONVENTIONS = `
LIB CONVENTIONS (match the existing ported components EXACTLY):
- Every file starts with a one-line block comment: /* Name — short description. Ported from the Platform v2 prototype. */
- Strict TypeScript. NO 'any'. NO '@ts-ignore'. NO default exports — use NAMED exports.
- Export a typed props interface per component (e.g. 'export interface FooProps { ... }') and the component as 'export function Foo(props: FooProps) {...}'. For ref-forwarding inputs use 'forwardRef'.
- Tailwind v4 classes copied VERBATIM from the prototype. The brand accent is the 'brand-*' utility scale (e.g. bg-brand-600, text-brand-600, outline-brand-500) — KEEP these; they are the themeable tokens. Do NOT replace brand-* with indigo-*/blue-* or raw hex. Status colours (emerald/rose/amber/sky/slate/teal/violet) stay as-is.
- Keep dark: variants exactly as in the prototype.
- React import style: import named hooks from 'react' (e.g. import { useState, useEffect, type ReactNode } from 'react'). The prototype uses React.useState etc. — convert to named imports.
- Replace prototype globals with imports (see IMPORTS below). The prototype's fmtGBP/fmtNum/etc, Icon, Button, Card, Badge, Popover, motion hooks are NOT globals here — import them.

STORY CONVENTIONS (match src/lib/Button.stories.tsx):
  import type { Meta, StoryObj } from '@storybook/react-vite';
  import { Foo } from './Foo';
  const meta = { component: Foo, title: 'Foo' } satisfies Meta<typeof Foo>;
  export default meta;
  type Story = StoryObj<typeof Foo>;
  export const Default = { args: { /* minimal representative props that RENDER */ } } satisfies Story;
- For components that need sample data (charts, tables), put small inline sample data in 'args' that matches the component's prop shapes so the story renders without errors.
- For components that take render-prop children or complex children, use 'render: () => <Foo ...>...</Foo>' instead of args.
`;

const HARD_RULES = `
HARD RULES (violating any = task FAILED):
1. Write ONLY the files listed in YOUR TASK. One ComponentName.tsx and one ComponentName.stories.tsx per component. NO .spec files (the orchestrator writes tests).
2. Do NOT edit, create, or delete ANY other file. Specifically NEVER touch: src/index.ts, src/domain/index.ts, any styles/*.css, any tsconfig/eslint/nx/package file, or any other component's files.
3. Do NOT run git, nx, npm, bun, tsc, eslint, or any build/test command. Do NOT commit. Author files only.
4. Read the prototype source for YOUR components from the given file + line range. Port faithfully — same DOM, same classes, same behaviour. Type every prop and callback; infer sensible types from usage.
5. Return the manifest (files written, exports per file). Do not summarise prose beyond the 'notes' field.
`;

// ---- Group definitions ------------------------------------------------------

const SRC = 'libs/platform/ui/src';
const PROTO = 'docs/platform/design/platform-v2-prototype/project';

const GROUPS = [
  {
    id: 'motion',
    targetDir: `${SRC}/lib`,
    source: `${PROTO}/ui.jsx`,
    lines: '460-503, 601',
    components: 'CountUp, Reveal, RouteFade, RouteProgress',
    imports: `Within ${SRC}/lib, import motion hooks from './motion' (usePrefersReducedMotion, useEntrance), and fmtNum from '../domain/formatters'. CountUp's default 'format' prop should be (n: number) => fmtNum(Math.round(n)). Reveal renders a configurable element 'as' (default 'div') — type it as React.ElementType; it sets a CSS custom property '--i' (cast style as React.CSSProperties).`,
  },
  {
    id: 'loading',
    targetDir: `${SRC}/lib`,
    source: `${PROTO}/ui.jsx`,
    lines: '504-589',
    components: 'BrandSpinner, LoadingPanel, Skeleton, SkeletonText, SkeletonKPI, SkeletonChart, SkeletonTable',
    imports: `Within ${SRC}/lib, import usePrefersReducedMotion from './motion'. BrandSpinner is imported by LoadingPanel — put both in their own files and have LoadingPanel import BrandSpinner from './BrandSpinner'. Skeleton is imported by SkeletonText/KPI/Chart/Table — put Skeleton in Skeleton.tsx and import it where needed (e.g. './Skeleton'). LOADING_LINES is the default for LoadingPanel.lines (export it). Spinner styles use inline CSS custom props like '--cc-thick' — cast style objects as React.CSSProperties.`,
  },
  {
    id: 'primitives-1',
    targetDir: `${SRC}/lib`,
    source: `${PROTO}/ui.jsx`,
    lines: '267-328',
    components: 'Sparkline, PageHeader, Tabs',
    imports: `Within ${SRC}/lib. Tabs takes 'tabs' (array of {id,label,count?,icon?}), 'value', 'onChange'. PageHeader takes title/subtitle/breadcrumbs/action. Sparkline takes data:number[] plus width/height/stroke/fill. Import Icon from './Icon' only if the prototype source uses it.`,
  },
  {
    id: 'primitives-2',
    targetDir: `${SRC}/lib`,
    source: `${PROTO}/ui.jsx`,
    lines: '329-357 (KPITile), 437-445 (TypeToConfirm), 604-614 (EmptyState)',
    components: 'KPITile, TypeToConfirm, EmptyState',
    imports: `Within ${SRC}/lib. KPITile: import useEntrance from './motion' and CountUp from './CountUp' (it renders a CountUp for numeric £ values) and Sparkline from './Sparkline' and fmtGBP from '../domain/formatters'. Keep KPITile's prop surface (label, value, delta, spark, unit, muted, i). EmptyState: import Icon from './Icon'. TypeToConfirm: import Icon from './Icon' if used; it takes word/value/onChange/disabled.`,
  },
  {
    id: 'commandpalette',
    targetDir: `${SRC}/lib`,
    source: `${PROTO}/shell.jsx`,
    lines: '334-375',
    components: 'CommandPalette',
    imports: `Within ${SRC}/lib, import Icon from './Icon'. CommandPalette props: open:boolean, onClose:()=>void, onNav:(path:string)=>void. It is a generic command menu — the NAV/command list it searches should be accepted as a prop 'commands' (array of { label:string; path:string; icon?:string; group?:string }) with a sensible default of [] so it stays generic (do NOT hardcode the prototype's domain NAV inside the component). Keep keyboard handling (Escape closes, arrow nav, Enter selects, autofocus). Backdrop click closes.`,
  },
  {
    id: 'datatable',
    targetDir: `${SRC}/lib`,
    source: `${PROTO}/table.jsx`,
    lines: '1-657 (whole file EXCEPT the Popover definition at 215-233, which already exists as ../Popover)',
    components: 'DataTable (+ its internal helpers)',
    imports: `Within ${SRC}/lib. Popover ALREADY EXISTS at './Popover' — import it, do NOT redefine it. Put DataTable in DataTable.tsx. Internal helpers (useDebounce, Highlight, ColumnFilter, filterRow, FilterChip, ColumnSettings) may live in the SAME DataTable.tsx file or in a co-located 'datatable/' folder — your choice — but only 'DataTable' (and optionally 'Highlight') need to be exported; keep the rest module-internal. Import Icon from './Icon', Button from './Button', Badge from './Badge' as needed. Define a generic 'Column' type and 'DataTableProps' with a row generic <T>. NOTE: column drag-reorder may be left as a no-op/TODO (no drag lib) — keep show/hide, pin, sort (incl. shift multi-sort), per-column filters, global search, CSV export, selection, sticky header/footer totals, empty/loading/error states. Write ONE story with ~5 inline sample rows and 4 columns.`,
  },
  {
    id: 'domain-badges',
    targetDir: `${SRC}/domain`,
    source: `${PROTO}/ui.jsx`,
    lines: '149-162 (TypeBadge), 416-436 (LifecycleStepper), 616-625 (SpecGap), 627-640 (SourceCite)',
    components: 'TypeBadge, LifecycleStepper, SpecGap, SourceCite',
    imports: `Target dir is ${SRC}/domain (NOT lib). Import Icon from '../lib/Icon'. LIFECYCLE_STEPS is a const map used by LifecycleStepper — export it. TypeBadge takes 'type' and maps to a label+style. These are DOMAIN components (deal lifecycle, spec-gap ribbons, source citations).`,
  },
  {
    id: 'charts-1',
    targetDir: `${SRC}/domain/charts`,
    source: `${PROTO}/charts.jsx`,
    lines: '100-285',
    components: 'RevenueLineChart, CommissionStackedBar, DonutChart, FunnelChart',
    imports: `Target dir ${SRC}/domain/charts. ChartFrame ALREADY EXISTS at './ChartFrame' — import it (do NOT redefine). CHART_PALETTE and SEMANTIC ALREADY EXIST at './palette' — import them (do NOT redefine). Import fmtGBP/fmtNum from '../formatters' if used, Icon from '../../lib/Icon' if used. Each chart is hand-built SVG wrapped in ChartFrame. Type the 'data' prop precisely from how the source destructures it. Story: inline minimal sample data matching the data shape.`,
  },
  {
    id: 'charts-2',
    targetDir: `${SRC}/domain/charts`,
    source: `${PROTO}/charts.jsx`,
    lines: '286-470',
    components: 'Heatmap, Waterfall, AgeingBar, StockArea',
    imports: `Target dir ${SRC}/domain/charts. Import ChartFrame from './ChartFrame', CHART_PALETTE/SEMANTIC from './palette' (already exist — do NOT redefine), fmt* from '../formatters', Icon from '../../lib/Icon' as used. Type each chart's props from the source. Story: inline minimal sample data.`,
  },
  {
    id: 'charts-3',
    targetDir: `${SRC}/domain/charts`,
    source: `${PROTO}/charts.jsx`,
    lines: '471-559',
    components: 'ErpStatusPie, FailureTrend, BulletChart',
    imports: `Target dir ${SRC}/domain/charts. Import ChartFrame from './ChartFrame', CHART_PALETTE/SEMANTIC from './palette' (already exist — do NOT redefine), fmt* from '../formatters', Icon from '../../lib/Icon' as used. Type each chart's props from the source. Story: inline minimal sample data.`,
  },
];

const MANIFEST_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    files: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        properties: {
          path: { type: 'string' },
          kind: { type: 'string', enum: ['component', 'story'] },
          exports: { type: 'array', items: { type: 'string' } },
          lines: { type: 'number' },
        },
        required: ['path', 'kind', 'exports', 'lines'],
      },
    },
    notes: { type: 'string' },
    deviations: { type: 'string' },
  },
  required: ['files', 'notes'],
};

function buildPrompt(g) {
  return `You are porting a coherent group of components from the Platform v2 prototype into the @acme/ui Nx library. The workspace root is the current working directory.

YOUR TASK — port these components: ${g.components}
SOURCE: read ${g.source} lines ${g.lines}. (Read surrounding lines too for context.)
TARGET DIRECTORY: ${g.targetDir}  (write ComponentName.tsx + ComponentName.stories.tsx there; for charts the .stories.tsx is co-located in the same dir.)

IMPORTS / WIRING:
${g.imports}

Reference an already-ported example for exact style: read ${SRC}/lib/Button.tsx, ${SRC}/lib/Card.tsx, and ${SRC}/lib/Button.stories.tsx before you start.

${CONVENTIONS}

${HARD_RULES}

When done, return the manifest of files you wrote. 'notes' = one line on anything non-obvious. 'deviations' = any intentional divergence from the prototype (e.g. CommandPalette taking commands as a prop, DataTable drag-reorder left as TODO).`;
}

// ---- Run --------------------------------------------------------------------

phase('Port');
log(`Porting ${GROUPS.length} component groups into @acme/ui (parallel)`);

const results = await parallel(
  GROUPS.map((g) => () =>
    agent(buildPrompt(g), {
      label: `port:${g.id}`,
      phase: 'Port',
      schema: MANIFEST_SCHEMA,
      agentType: 'general-purpose',
    }).then((r) => ({ id: g.id, components: g.components, result: r }))
  )
);

const ok = results.filter((r) => r && r.result && Array.isArray(r.result.files));
const fileCount = ok.reduce((n, r) => n + r.result.files.length, 0);
log(`Port complete: ${ok.length}/${GROUPS.length} groups returned manifests, ${fileCount} files written`);

return {
  groups: results.map((r) =>
    r
      ? {
          id: r.id,
          components: r.components,
          files: (r.result && r.result.files) || null,
          deviations: (r.result && r.result.deviations) || '',
          notes: (r.result && r.result.notes) || '',
        }
      : null
  ),
};
