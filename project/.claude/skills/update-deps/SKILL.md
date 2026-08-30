---
name: update-deps
description: 'Update npm dependencies: check for outdated packages, apply updates, verify compatibility, and run tests. Use when the user wants to update libraries or address vulnerability alerts. Do not use for adding new dependencies as part of a feature.'
model: sonnet
disable-model-invocation: true
---

# Dependency Update Workflow

You are orchestrating safe dependency updates with proper verification.

## Workflow Steps

### Step 1: Audit Current State

```bash
# Check for vulnerabilities
npm audit

# Check for outdated packages
npm outdated

# See what would be updated
npm outdated --long
```

### Step 2: Categorize Updates

| Category | Risk | Examples |
| ----------------- | ------ | --------------------------------- |
| **Patch** (x.x.X) | Low | Bug fixes, security patches |
| **Minor** (x.X.x) | Medium | New features, backward compatible |
| **Major** (X.x.x) | High | Breaking changes |

**Priority Order:**

1. Security vulnerabilities (immediate)
2. Patch updates (safe)
3. Minor updates (test carefully)
4. Major updates (plan and test extensively)

### Step 3: Security Updates (Immediate)

For packages with known vulnerabilities:

```bash
# Auto-fix what's safe
npm audit fix

# Check what couldn't be auto-fixed
npm audit

# For remaining issues, update manually
npm install package-name@latest
```

### Step 4: Patch Updates (Low Risk)

```bash
# Update all patch versions
npm update

# Or update specific package
npm install package-name@~1.2.0
```

### Step 5: Minor/Major Updates (Higher Risk)

Update one package at a time:

```bash
# Check changelog first!
# https://github.com/owner/repo/blob/main/CHANGELOG.md

# Update specific package
npm install package-name@^2.0.0

# Run tests immediately
nx run-many -t test
nx run-many -t build
```

### Step 6: Nx Updates

For Nx workspace updates, use the **nx-expert agent** to guide the migration:

The **nx-expert agent** will help with:

- Understanding migration impact
- Resolving migration conflicts
- Updating workspace configuration
- Verifying project graph after migration

```bash
# Check available migrations
nx migrate latest

# Review migration changes
cat migrations.json

# Run migrations
nx migrate --run-migrations

# Clean up
rm migrations.json
```

### Step 7: Framework Updates

For major framework updates (React, TypeScript, etc.):

1. **Read the migration guide** first
2. Create a dedicated branch
3. Update incrementally
4. Run full test suite after each step
5. Test manually in browser

### Step 8: Verification

After updates:

```bash
# Clean install
rm -rf node_modules
npm ci

# Full build
nx run-many -t build

# Full test suite
nx run-many -t test

# Lint check
nx run-many -t lint

# E2E tests (if available)
nx run legacy-web-e2e:e2e
```

### Step 9: Lock File

Ensure lock file is updated:

```bash
# Verify lock file is in sync
npm ci

# Commit lock file with the update
git add package.json package-lock.json
```

## Security Review

Use **security-auditor agent** to verify:

- No new vulnerabilities introduced
- Updated packages are from trusted sources
- No malicious package substitution

## Common Issues

### Peer Dependency Conflicts

```bash
# See the conflict
npm ls conflicting-package

# Options:
# 1. Update the conflicting packages together
# 2. Use --legacy-peer-deps (last resort)
npm install --legacy-peer-deps
```

### TypeScript Errors After Update

- Check if @types packages need updating
- Review breaking changes in changelog
- Update code to match new API

### Build Failures

- Clear caches: `nx reset`
- Clean install: `rm -rf node_modules && npm ci`
- Check for removed/renamed exports

## Update Checklist

- [ ] `npm audit` shows no high/critical vulnerabilities
- [ ] All tests pass
- [ ] Build succeeds
- [ ] Application runs locally
- [ ] No TypeScript errors
- [ ] Lock file committed

## Major Updates Requiring Extra Care

| Package | Notes |
| ---------- | ----------------------------------------- |
| React | Read migration guide, test all components |
| TypeScript | May need code changes |
| Nx | Use `nx migrate`, follow their guide |
| MUI        | Check breaking changes, theme updates |
| TypeORM    | Test all database operations |

## Output

Provide:

- Packages updated (with version changes)
- Vulnerabilities fixed
- Breaking changes addressed
- Test results
- Any manual steps required
