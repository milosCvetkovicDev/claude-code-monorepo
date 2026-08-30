---
name: webpack-workspace-externals-bug
description: npm workspaces creates node_modules/@acme/* which webpack-node-externals externalizes — staging crashes with Cannot find module
type: project
---

## Webpack Externalizes @acme Workspace Packages

**Discovered:** 2026-03-31 during deploy of PR #263.

**Symptom:** Staging container crashes: `Cannot find module '@acme/shared-constants'`

**Root cause chain:**
1. `package.json` has `"workspaces": ["libs/commission/*"]`
2. `npm ci` creates `node_modules/@acme/shared-constants` (workspace symlink)
3. NxAppWebpackPlugin uses `webpack-node-externals` which externalizes everything in `node_modules/`
4. The `allowlist` for workspace libs is empty (`[]`) because legacy-api doesn't use TS solution mode
5. Webpack outputs `require("@acme/shared-constants")` instead of bundling
6. At runtime on Azure, the workspace package doesn't exist in `node_modules`

**Fix (PR #265):** Added `rm -rf node_modules/@acme` step in `reusable-build-deploy-app.yml` after `npm ci` and before the webpack build.

**Cache gotcha (PR #266):** After merging the workflow fix, Nx remote cache still served the old (broken) build. Had to bump `.github/ci-cache-version.txt` (1 → 2) to invalidate cached artifacts.

**Why:** `NxAppWebpackPlugin` with `externalDependencies: 'all'` uses `nodeExternals({ allowlist: [] })`. Webpack's externals array processes each function — `callback()` means "I don't know, try next" not "bundle it". So custom externals functions can't override `nodeExternals`. The only reliable fix is removing the symlinks.

**How to apply:** If a new `@acme/*` workspace package is added to `libs/commission/*` and imported by legacy-api, the `rm -rf node_modules/@acme` step already handles it. No action needed. But be aware: any workspace package in `node_modules` WILL be externalized by webpack.
