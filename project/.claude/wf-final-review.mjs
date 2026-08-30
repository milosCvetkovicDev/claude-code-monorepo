export const meta = {
  name: 'platform-ui-final-review',
  description: 'Adversarial multi-lens review of the ported @acme/ui design kit',
  phases: [{ title: 'Review' }],
};

const LIB = 'libs/platform/ui/src';
const PROTO = 'docs/platform/design/platform-v2-prototype/project';

const RULES = `
HARD RULES:
- READ ONLY. Do NOT edit, write, or delete any file. Do NOT run git, nx build/commit, or any mutating command. You may read files and run read-only greps.
- Report concrete, actionable findings tied to a specific file (and line where possible). No vague advice.
- Be adversarial but precise: only report things that are actually wrong or missing, with evidence. If a thing is fine, do not invent a problem.
- Severity: high = breaks correctness/theming/a11y or a missing export; medium = fidelity drift or a real but non-breaking issue; low = polish.
`;

const LENSES = [
  {
    id: 'theming',
    prompt: `Lens: THEMEABILITY. The kit must recolor live via the --brand-* tokens. Audit every ported component in ${LIB}/lib and ${LIB}/domain for hardcoded brand colours that should be themeable: grep for 'indigo-', 'violet-' used as a brand accent, and raw hex colours in className strings. Brand surfaces must use 'brand-*' utilities. EXCEPTIONS that are correct and must NOT be flagged: fixed status colours (emerald/rose/amber/sky/slate/teal), the Okabe-Ito CHART_PALETTE in domain/charts/palette.ts, and SEMANTIC chart colours. Also confirm theme/ThemeProvider applies accent/mode/density/fidelity and that AccentPicker/ThemeToggle/DensityToggle call useTheme. Report any brand colour that won't follow data-theme.`,
  },
  {
    id: 'fidelity',
    prompt: `Lens: PROTOTYPE FIDELITY. Compare the ported components against the prototype source. Read ${PROTO}/ui.jsx, ${PROTO}/charts.jsx, ${PROTO}/table.jsx and spot-check the matching files in ${LIB}/lib and ${LIB}/domain. Look for: dropped props/behaviour, changed DOM structure or Tailwind classes, charts that render the wrong SVG shape count vs their data, KPITile/CountUp/DataTable behaviour drift. Documented intentional deviations that are FINE: CommandPalette takes commands via prop; DataTable column drag-reorder is a TODO; KPITile value typed number|string; SkeletonKPI has an empty props type. Report real fidelity regressions only.`,
  },
  {
    id: 'a11y',
    prompt: `Lens: ACCESSIBILITY. Review ${LIB}/lib and ${LIB}/domain components for a11y defects: missing button type, icon-only controls without aria-label, modal/dialog focus + role, charts must expose role="img"+aria-label (ChartFrame), form controls labelled, listbox/option roles on pickers, keyboard handling (Escape/arrows) on CommandPalette/Popover/Modal/CodeInput. Report missing or incorrect a11y semantics with the file and element.`,
  },
  {
    id: 'completeness',
    prompt: `Lens: COMPLETENESS. Determine what is MISSING. (1) Enumerate the components/exports defined in ${PROTO}/ui.jsx, ${PROTO}/charts.jsx, ${PROTO}/table.jsx (the window.Object.assign export lists + chart/table consts). (2) Check each is exported from either ${LIB}/index.ts (generic) or ${LIB}/domain/index.ts (domain). List any prototype component NOT ported or NOT exported. (3) Flag any component file in ${LIB} that lacks a co-located .stories.tsx. (4) Note any export name in a barrel that does not resolve to a real file/symbol. Evidence required per gap.`,
  },
  {
    id: 'types-boundaries',
    prompt: `Lens: TYPES + NX BOUNDARIES. Review ${LIB} for: use of 'any' or '@ts-ignore'; default exports (should be named); props interfaces that are too loose (e.g. accepting any); cross-layer import violations (lib importing from domain, or domain reaching outside the lib); the @acme/ui/domain separation (generic lib must NOT import trading vocabulary from domain). Also check src/index.ts does not re-export domain-only symbols (those belong to the domain barrel). Report concrete violations with file + line.`,
  },
];

const SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        properties: {
          severity: { type: 'string', enum: ['high', 'medium', 'low'] },
          file: { type: 'string' },
          line: { type: 'number' },
          title: { type: 'string' },
          detail: { type: 'string' },
          suggestedFix: { type: 'string' },
        },
        required: ['severity', 'file', 'title', 'detail'],
      },
    },
    summary: { type: 'string' },
  },
  required: ['findings', 'summary'],
};

phase('Review');
log(`Final review across ${LENSES.length} lenses (read-only)`);

const results = await parallel(
  LENSES.map((l) => () =>
    agent(`${l.prompt}\n\n${RULES}\n\nReturn structured findings.`, {
      label: `review:${l.id}`,
      phase: 'Review',
      schema: SCHEMA,
      agentType: 'general-purpose',
    }).then((r) => ({ lens: l.id, ...(r || { findings: [], summary: 'no result' }) }))
  )
);

const all = results.flatMap((r) => (r.findings || []).map((f) => ({ lens: r.lens, ...f })));
const high = all.filter((f) => f.severity === 'high');
const medium = all.filter((f) => f.severity === 'medium');
log(`Findings: ${high.length} high, ${medium.length} medium, ${all.length - high.length - medium.length} low`);

return {
  byLens: results.map((r) => ({ lens: r.lens, summary: r.summary, count: (r.findings || []).length })),
  high,
  medium,
  low: all.filter((f) => f.severity === 'low'),
};
