---
name: commit
description: Create a quality-checked git commit with pre-commit validation (prettier, typecheck, lint, git identity)
model: haiku
---

# Commit Workflow

Create a well-formed commit after running all quality checks. This prevents commit failures and ensures code quality.

## Step 1: Verify Git Identity

```bash
git config user.name
git config user.email
```

If either is empty, **stop and ask the user** to configure their git identity before proceeding.

## Step 2: Check Staged Changes

```bash
git status
git diff --cached --stat
```

If there are no staged changes, check for unstaged changes and ask the user what to stage.

## Step 3: Run Prettier on Staged Files

```bash
# Get list of staged files that prettier can format
git diff --cached --name-only --diff-filter=ACMR | grep -E '\.(ts|tsx|js|jsx|json|css|scss|html|md)$' | xargs -r npx prettier --write
```

Re-stage any files that prettier modified:

```bash
git diff --cached --name-only --diff-filter=ACMR | grep -E '\.(ts|tsx|js|jsx|json|css|scss|html|md)$' | xargs -r git add
```

## Step 4: Run Affected Typecheck

```bash
npx nx affected -t typecheck --base=HEAD 2>&1 | head -30
```

If typecheck fails, **fix the type errors** before proceeding. Never use `--transpileOnly` or `skipLibCheck` as workarounds.

## Step 5: Run Affected Lint

```bash
npx nx affected -t lint --base=HEAD 2>&1 | head -30
```

If lint fails, fix the lint errors before proceeding.

## Step 6: Create Commit

Use conventional commit format: `type(scope): description`

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`

Always include `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>` in the commit message.

Use a HEREDOC for the commit message:

```bash
git commit -m "$(cat <<'EOF'
type(scope): brief description

Longer explanation if needed.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

## Step 7: Verify

```bash
git log --oneline -1
git status
```

Report the commit hash and any remaining unstaged changes.

## Important

- If ANY check fails, fix the issue and re-run — do not skip checks
- Do not push unless the user explicitly asks
- Do not use `--no-verify` or skip hooks unless the user explicitly asks
