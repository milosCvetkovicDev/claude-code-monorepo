export const meta = {
  name: 'platform-ui-expert-review',
  description: 'Expert-panel code review of PR #1353 (Platform design system kit)',
  phases: [{ title: 'Review' }, { title: 'Synthesize' }],
};

const DIFF = '/tmp/pr-1353-code.diff';
const LIB = 'libs/platform/ui/src';
const DEMO = 'apps/platform-design-demo';

const CONTEXT = `
PR #1353 — the Platform Design System Kit. It ports the "Platform v2" prototype
(docs/platform/design/platform-v2-prototype/project/{ui,charts,table,shell}.jsx) into:
- @acme/ui (${LIB}) — a Tailwind v4, runtime-themeable component library. Generic
  primitives/motion/DataTable/CommandPalette/theme-controls in the main barrel
  (${LIB}/index.ts); trading-domain (formatters, badges, lifecycle, 11 charts) behind
  the @acme/ui/domain entry (${LIB}/domain/index.ts).
- ${DEMO} — a Vite/React demo app consuming the kit.
Theming: --brand-* channel tokens + 6 data-theme presets (neutral "steel" default);
@theme inline maps --color-brand-* -> rgb(var(--brand-*)) for live recolour; no-preflight
so MUI CssBaseline (in the OTHER legacy app) keeps the reset. Status colours fixed; charts
use a fixed Okabe-Ito palette. ThemeProvider manages accent/mode/density/fidelity.

The full code diff is at ${DIFF}. You may READ any file under ${LIB} and ${DEMO} for full
context (the diff is mostly new files). Known/accepted deviations (do NOT re-flag as new):
CommandPalette takes commands via prop; DataTable column drag-reorder is a TODO; KPITile
value is number|string; nx typecheck was repointed tsconfig.json->tsconfig.lib.json on purpose.
`;

const RULES = `
HARD RULES:
- READ ONLY. Never edit/write/delete files. Never run git, nx build, npm/bun install, or any mutating/long command. Read files + targeted greps only.
- Ground every finding in a specific file (+ line if you can). No generic advice. Provide a concrete recommendation per finding.
- Be a demanding senior reviewer in your specialty, but precise: only real issues, with evidence. Distinguish severity honestly. It is fine — expected — to also record 1-2 "praise" items for genuinely good work.
- Stay in your lane (your specialty); don't pad with out-of-scope findings other reviewers own.
`;

const PANEL = [
  {
    id: 'tech-lead',
    agentType: 'review-tech-lead',
    charter: `Code quality & maintainability. Assess: naming, duplication, dead code, over/under-abstraction, consistency across the ported components, readability, comment quality, prop-API ergonomics, error handling, magic numbers. Is anything needlessly complex or copy-pasted that should be shared? Are the barrels (index.ts / domain/index.ts) coherent?`,
  },
  {
    id: 'ui-architecture',
    agentType: 'ui-expert',
    charter: `Design-system architecture. Assess the token system (theme.css / preset.css / @theme inline), the runtime-themeability mechanism (does every brand surface actually follow data-theme? any frozen colour?), component composability and API design, the generic-vs-domain split, Storybook setup, density/wireframe/dark layering, and whether the no-preflight choice is sound. Flag any token or utility that won't recolour.`,
  },
  {
    id: 'ux-a11y',
    agentType: 'ux-expert',
    charter: `Accessibility (WCAG 2.1 AA) and UX. Audit keyboard operability + focus management (Modal, CommandPalette, Popover, Tabs, DataTable, CodeInput), ARIA roles/names/state, prefers-reduced-motion coverage, focus-visible rings, colour-contrast risk across the 6 presets (esp. graphite/copper brand-on-white), live regions, and any motion that could harm usability. Note what is done well too.`,
  },
  {
    id: 'react',
    agentType: 'frontend-specialist',
    charter: `React correctness & performance. Hunt: useEffect dependency bugs, stale closures, missing/incorrect keys, event-listener leaks, unnecessary re-renders, derived-state anti-patterns, refs misuse, SSR guards, requestAnimationFrame/timer cleanup, cloneElement typing/runtime, and any component that recomputes heavy work each render (DataTable/charts). Are the hooks (useReveal/useEntrance/usePrefersReducedMotion/useSimulatedLoad) correct?`,
  },
  {
    id: 'tests',
    agentType: 'review-test-architect',
    charter: `Test strategy & coverage. The kit relies on: 3 existing auth specs + new behavioural specs for formatters/Popover/ThemeProvider + Storybook stories + tsc/build. Identify the HIGHEST-VALUE missing tests (DataTable sort/filter/export, CommandPalette keyboard nav, CountUp, chart role=img/shape-count, theme controls). Assess whether story-only coverage is acceptable for the rest, and whether the existing specs are meaningful or shallow.`,
  },
  {
    id: 'nx-build',
    agentType: 'nx-expert',
    charter: `Nx & build config. Review project.json targets (platform-ui + demo), the typecheck repoint to tsconfig.lib.json (is it correct/complete? are stories now unchecked?), tags/boundaries (scope/type/layer), tsconfig wiring (paths, lib dom, storybook tsconfig), the @nx/storybook plugin config, build-storybook exposure to nx affected, and the swc build (skipTypeCheck:true). Any target that could hang/OOM or be miscached?`,
  },
  {
    id: 'security',
    agentType: 'agent-skills:security-auditor',
    charter: `Security review (UI-appropriate). Look for: dangerouslySetInnerHTML, unsanitised CSV/SVG export (DataTable + ChartFrame: data: URIs, CSV injection via =/+/@/- prefixes, XMLSerializer of untrusted SVG), URL/hash state injection, target=_blank without rel=noopener, localStorage trust, regex/DoS in filters, and any reflected user input rendered without escaping (Highlight). Rate realistically for a frontend kit.`,
  },
  {
    id: 'architecture',
    agentType: 'review-enterprise-architect',
    charter: `Architecture & layering (Clean Architecture / SOLID / DDD-lite). Validate the generic(@acme/ui) vs domain(@acme/ui/domain) separation: does any generic primitive depend on the domain layer? Is the domain barrel cohesive? Are the public types well-designed (encapsulation, no leaky any)? Is the theming abstraction (ThemeProvider/tokens) the right seam for later re-skinning? Assess long-term evolvability.`,
  },
];

const SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    verdict: { type: 'string', enum: ['approve', 'approve-with-nits', 'request-changes'] },
    headline: { type: 'string' },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        properties: {
          severity: { type: 'string', enum: ['high', 'medium', 'low', 'nit', 'praise'] },
          file: { type: 'string' },
          line: { type: 'number' },
          title: { type: 'string' },
          detail: { type: 'string' },
          recommendation: { type: 'string' },
        },
        required: ['severity', 'file', 'title', 'detail'],
      },
    },
  },
  required: ['verdict', 'headline', 'findings'],
};

phase('Review');
log(`Expert panel: ${PANEL.length} reviewers on PR #1353`);

const reviews = await parallel(
  PANEL.map((p) => () =>
    agent(
      `${CONTEXT}\n\nYOUR REVIEW CHARTER (${p.id}): ${p.charter}\n\n${RULES}\n\nReturn your structured review (verdict + headline + findings).`,
      { label: `review:${p.id}`, phase: 'Review', schema: SCHEMA, agentType: p.agentType }
    ).then((r) => ({ panel: p.id, agentType: p.agentType, ...(r || { verdict: 'n/a', headline: 'no result', findings: [] }) }))
  )
);

const ok = reviews.filter(Boolean);
const flat = ok.flatMap((r) => (r.findings || []).map((f) => ({ panel: r.panel, ...f })));
const counts = ['high', 'medium', 'low', 'nit', 'praise'].reduce((m, s) => {
  m[s] = flat.filter((f) => f.severity === s).length;
  return m;
}, {});
log(`Collected: ${counts.high} high, ${counts.medium} medium, ${counts.low} low, ${counts.nit} nit, ${counts.praise} praise`);

return {
  verdicts: ok.map((r) => ({ panel: r.panel, agentType: r.agentType, verdict: r.verdict, headline: r.headline, findingCount: (r.findings || []).length })),
  counts,
  findings: flat,
};
