# Nx & Build Patterns

## Library Scaffolding
- `nx generate @nx/react:library` creates package name from directory path (e.g., `commission/feature-legacy-web` -> `@acme/feature-legacy-web`)
- Must manually rename in `package.json` if desired name differs
- Always add path alias to `tsconfig.base.json` after creating a library
- Prefer dedicated `project.json` over `package.json` `nx` key (workspace convention)
- Generated `.eslintrc.json` has `"ignorePatterns": ["!**/*"]` — add `"dist/**"` to fix ESLint linting dist/

## Buildable Library ESLint
- `@nx/rollup/plugin` infers `build` target from `rollup.config.cjs` -> library becomes "buildable"
- Can't import non-buildable libs -> override `enforceBuildableLibDependency: false` in `.eslintrc.json`
- Set `package.json` exports to `./src/index.ts` (not `./dist/`) to prevent `@nx/js/typescript` inferring build

## Nx v22.2.5 Native Hasher Crash (RESOLVED)
- `transformProjectGraphForRust()` passes `undefined` for target fields
- Fix: `npm install` restructured transitive `@nx/*` deps in lockfile
- If recurs: `patch-package` with `?? []` defaults to `transform-objects.js`

## Express Error Handling
- `asyncHandler` is from `express-async-handler` npm package, NOT a local helper
- `handleErrors` middleware only maps `ErrorWithStatus` subclasses to HTTP status codes
- `HttpRequestError` does NOT extend `ErrorWithStatus` — upstream 4xx become 500
- Pattern: Create `FooApiClientError extends ErrorWithStatus` per external service

## Proxy Patterns (legacy-api)
- Use `fetch` directly with `AbortController` for timeout (helpers don't support abort)
- `forwardGet` calls `response.json()` — breaks on CSV/binary. Use `forwardGetStream` for non-JSON
- Validate path params with `parseInt` + `isNaN`, filter `req.query` to strings only
- `encodeURIComponent` non-ASCII header values

## TypeScript
- Type guards: `.filter((x): x is T => !!x)` not `.filter((x) => !!x)` for narrowing
- tsconfig conflicts on merge: keep all project references from both sides (additive)
- `@rollup/plugin-url` required for `libs/commission/feature-legacy-web`
