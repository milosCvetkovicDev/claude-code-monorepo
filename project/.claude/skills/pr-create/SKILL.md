---
name: pr-create
description: 'Create a pull request with a well-structured description, linked issues, and review checklist. Use when the user is ready to open a PR for their changes. Do not use for committing code (use commit) or reviewing existing PRs (use code-review).'
model: sonnet
---

# PR Creation Workflow

You are creating a pull request following project conventions.

## Workflow Steps

### Step 1: Pre-PR Checks

Before creating the PR, verify:

```bash
# Check for uncommitted changes
git status

# Run affected tests
nx affected -t test

# Run linting
nx affected -t lint

# Check for type errors
nx affected -t build
```

**Do not create PR if any checks fail.**

### Step 2: Review Your Changes

```bash
# See what will be in the PR
git log main..HEAD --oneline
git diff main --stat
```

Verify:

- [ ] All changes are intentional
- [ ] No debug code left in
- [ ] No console.log statements (use logger)
- [ ] No commented-out code
- [ ] No secrets or credentials

### Step 3: Commit Organization

Ensure commits are well-organized:

- Each commit should be a logical unit
- Commit messages should be clear
- Use conventional commits format:
  - `feat:` - New feature
  - `fix:` - Bug fix
  - `refactor:` - Code refactoring
  - `test:` - Adding tests
  - `docs:` - Documentation
  - `chore:` - Maintenance

### Step 4: Create PR

```bash
gh pr create --title "type: brief description" --body "$(cat <<'EOF'
## Summary
Brief description of what this PR does.

## Changes
- Change 1
- Change 2
- Change 3

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows project conventions
- [ ] No `any` types without justification
- [ ] Multi-tenancy considered
- [ ] Big.js used for decimals
- [ ] Tests actually assert behavior

## Screenshots (if UI changes)
[Add screenshots here]

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

### Step 5: PR Title Format

```
type(scope): brief description

Examples:
feat(invoices): add bulk approval functionality
fix(customers): handle null credit limit correctly
refactor(api): extract validation to middleware
test(deals): add integration tests for deal creation
docs(readme): update deployment instructions
```

### Step 6: PR Description

Include:

1. **Summary**: What does this PR do? (1-2 sentences)
2. **Changes**: Bullet list of specific changes
3. **Testing**: How was this tested?
4. **Checklist**: Project-specific requirements
5. **Screenshots**: If there are UI changes

### Step 7: Request Reviewers

Based on changes:

- Backend changes → Backend team
- Frontend changes → Frontend team
- Infrastructure → DevOps team
- Security-sensitive → Security reviewer

```bash
# Add reviewers
gh pr edit --add-reviewer username1,username2
```

### Step 8: Link Issues

If fixing an issue:

```bash
# In PR description, add:
Fixes #123
Closes #456
```

## PR Size Guidelines

| Size | Lines Changed | Review Time |
| ---- | ------------- | ------------ |
| XS   | < 50          | Minutes |
| S    | 50-200        | < 1 hour |
| M    | 200-400       | 1-2 hours |
| L    | 400-800       | Half day |
| XL   | > 800         | Split it up! |

**If your PR is XL, consider splitting it into smaller PRs.**

## Common Issues to Avoid

- ❌ PR too large (> 400 lines without justification)
- ❌ Mixing unrelated changes
- ❌ Missing tests for new functionality
- ❌ Vague PR title ("fixes stuff", "updates")
- ❌ No description
- ❌ Breaking changes without migration path

## Output

Provide:

- PR URL
- Summary of changes
- Reviewers assigned
- Any notes for reviewers
