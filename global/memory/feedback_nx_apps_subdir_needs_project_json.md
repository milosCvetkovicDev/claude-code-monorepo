---
name: feedback-nx-apps-subdir-needs-project-json
description: Nx auto-discovers every directory under apps/ as a workspace project. Any subdir without project.json (or package.json with `name`) breaks `nx graph` processing with "no name provided" — fails affected-test runs, production-safety lint, ESLint Security Rules, etc.
metadata:
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000008
---

Nx (24.x in this repo) auto-discovers projects under `apps/*` and `libs/*`. If any subdir under `apps/` is missing both `project.json` AND `package.json` with a `name` field, Nx errors at project graph processing time:

```
NX  Failed to process project graph.
The projects in the following directories have no name provided:
  - apps/<subdir>
```

This breaks ANY workflow that calls `nx` against the workspace — production-safety lint, ESLint Security Rules, affected-test runs, etc. PR #863 hit this when I added `apps/runner-image/` (Docker build context only — no JS code) without a `project.json`.

**Why:** The auto-discovery isn't optional — there's no `.nxignore`-style escape hatch under apps/. The minimum viable project.json declares a name + optional tags:

```json
{
  "name": "runner-image",
  "$schema": "../../node_modules/nx/schemas/project-schema.json",
  "projectType": "application",
  "sourceRoot": "apps/runner-image",
  "tags": ["scope:ci", "type:image", "epic:<epic-name>"],
  "implicitDependencies": [],
  "targets": {
    "build": {
      "executor": "nx:run-commands",
      "options": {
        "command": "docker buildx build --load -t arc-runner:test apps/runner-image/",
        "cwd": "{workspaceRoot}"
      }
    }
  }
}
```

**How to apply:**

Whenever you create a NEW directory under `apps/` (even for Docker build contexts, scripts, assets, etc.), add a `project.json` with at minimum a name. Pick `projectType: "application"` for buildable artifacts, `"library"` for code consumed by others. Use `nx:run-commands` executor for non-Nx tooling like Docker, scripts, etc.

**Verification:** After adding the project, `nx graph` or `nx list` should pick up the new project without errors. CI workflows that call `nx run-many` or `nx affected` should run cleanly.

Fixed in: PR #863 commit `cc898501` — added `apps/runner-image/project.json`.

Related anti-pattern: putting non-Nx directories under `apps/`. Some teams use `infra/`, `scripts/`, or `tools/` at workspace root for content that isn't an Nx project — those paths don't trip auto-discovery.
