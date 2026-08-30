---
name: platform-swcrc-module-bug
description: SWC .swcrc module type must be "commonjs" not "nodenext" — causes ESM crash in Docker
type: reference
---

All 22 `.swcrc` files (4 apps + 18 libs) must have `"module": { "type": "commonjs" }`.

**Why:** `"nodenext"` preserves ESM `import`/`export` syntax in compiled output, but `@nx/js:swc` stamps `"type": "commonjs"` in the output `package.json`. Node.js sees CJS package.json + ESM syntax → `SyntaxError: Cannot use import statement outside a module`. Only manifests in Docker containers because Vitest has its own module resolution.

**How to apply:** When creating new Platform libs or apps, ensure `.swcrc` uses `"type": "commonjs"`. If you see ESM errors in Docker, check this first.
