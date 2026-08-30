---
name: cleanup
description: "Deep cleanup of development environment: free disk space, reclaim memory, kill orphaned processes, and remove stale Docker resources. Use when the system is slow, disk is full, or orphaned processes are consuming resources. Do not use for code refactoring (use refactor) or dependency updates (use update-deps)."
model: haiku
---

# Deep Cleanup Workflow

Run aggressive cleanup to free disk space and memory.

## What Gets Cleaned

1. **Processes** - Stop Nx daemon, orphaned Node processes, Jest workers, esbuild
2. **Nx Cache** - Clear `.nx/cache/`
3. **Node Cache** - Clear `node_modules/.cache/`
4. **Build Caches** - Vite cache, TypeScript build info, Jest cache
5. **Test Artifacts** - coverage/, test-results/, playwright-report/
6. **Temp Files** - .tmp/, tmp/, old logs
7. **Docker** - Prune dangling images
8. **npm Cache** - Clean npm cache

## Commands to Run

```bash
# Stop Nx daemon
npx nx daemon --stop
npx nx reset

# Clean Nx cache
rm -rf .nx/cache/*

# Clean node_modules cache
rm -rf node_modules/.cache/*

# Clean Vite cache
find . -type d -name ".vite" -exec rm -rf {} + 2>/dev/null || true

# Clean TypeScript build info
find . -name "*.tsbuildinfo" -delete 2>/dev/null || true

# Clean test artifacts
rm -rf coverage test-results playwright-report .nyc_output

# Clean temp files
rm -rf .tmp tmp
find . -name "*.log" -type f -mtime +7 -delete 2>/dev/null || true

# Docker cleanup (if available)
docker image prune -f

# npm cache
npm cache clean --force
```

## Usage

Run this skill when:

- Disk space is low
- Memory usage is high
- After long development sessions
- Before switching to a different project

## Output

Report what was cleaned and disk space available after cleanup.
