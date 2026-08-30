---
name: platform-ui-design-sync
description: '@acme/ui is synced to Claude Design ("Design System" project) via /design-sync — config, re-sync command, and the build gotchas'
metadata:
  node_type: memory
  type: reference
  originSessionId: 00000000-0000-0000-0000-000000000006
---

**`@acme/ui` (libs/platform/ui) → Claude Design** synced 2026-06-24 via `/design-sync`. Project: **"Design System"** `00000000-0000-0000-0000-000000000065` (https://claude.ai/design/p/00000000-0000-0000-0000-000000000065). All **57 components** verified (56 `match` + CommandPalette `close` — SB portal-capture limitation, preview is correct). Designs in claude.ai now build with the real kit (see [[platform-design-system-kit]]).

- **Durable config lives in the repo** at `.design-sync/{config.json, build.sh, conventions.md, NOTES.md}` (committed; `.ds-sync/`, `ds-bundle/`, `.design-sync/sb-reference|.cache|learnings` are gitignored). These ARE the re-sync source of truth.
- **Re-sync:** stage scripts (`mkdir -p .ds-sync && cp -r <skill>/{package-build,package-validate,resync}.mjs <skill>/{lib,storybook,non-storybook} .ds-sync/ && cd .ds-sync && npm i esbuild ts-morph @types/react playwright && npx playwright install chromium`), build the reference (`CI=1 npx storybook build -c libs/platform/ui/.storybook -o .design-sync/sb-reference`), then `node .ds-sync/resync.mjs --config .design-sync/config.json --node-modules node_modules --out ./ds-bundle` (add `--remote` with the prior `_ds_sync.json` once you have one). Upload via `DesignSync` (main session only).
- **Build gotchas (all encoded in `.design-sync/build.sh`):**
  1. `@nx/js:swc` build emits **no `.d.ts`** (`skipTypeCheck`) → the converter reads the public API from `.d.ts`, so build.sh runs `tsc -p libs/platform/ui/tsconfig.lib.json --emitDeclarationOnly --rootDir libs/platform/ui` (rootDir keeps the `src/` prefix matching the swc JS layout).
  2. Two barrels: `@acme/ui` + `@acme/ui/domain`. `cfg.extraEntries=["./src/domain/index.js"]` puts domain on `window.AcmeUI`; AND build.sh appends `export * from "./domain/index"` to the **built** `dist/.../src/index.d.ts` (source untouched) so the converter treats domain exports (TypeBadge, LifecycleStepper, charts) as public — else they drop as `[TITLE_UNMAPPED]`. Use `printf '\n...\n'` (a bare `echo >>` glues onto the no-trailing-newline sourceMappingURL comment).
  3. Tailwind v4 compiled CSS isn't `<link>`ed in `sb-reference/iframe.html` (Vite injects via JS) → build.sh copies `sb-reference/assets/preview-*.css` to `dist/.../_ds_compiled.css` and `cfg.cssEntry="_ds_compiled.css"` (cssEntry must be inside PKG_DIR=`dist/libs/platform/ui`).
  4. JetBrains Mono is referenced but unshipped → build.sh prepends a Google-Fonts `@import` to `_ds_compiled.css`; for grading-oracle parity inject the same `<link>` into `sb-reference/iframe.html` (lost on reference rebuild — re-inject each re-sync, or add a storybook `preview-head.html`).
  5. `cfg.overrides`: CommandPalette/Modal/RouteProgress `cardMode:"single"` (portal/fixed overlays overflow grid cells). Other overlays (Popover/Tooltip/ToastProvider) render closed by default → no override.
- **Install with npm** (`npm ci`), not bun (repo has both lockfiles; bun is a sub-service only). `DesignSync` MCP works **only in the main session**, not subagents (they grade via compare.mjs + sheets, orchestrator uploads).
