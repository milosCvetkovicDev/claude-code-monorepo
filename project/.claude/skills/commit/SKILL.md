---
name: commit
description: "Format, stage, commit, and push code changes with conventional commit messages. Use when the user asks to commit, save changes, or push code. Do not use for creating pull requests (use pr-create) or reviewing changes before commit (use code-review)."
---

# Commit

1. Run `npx nx format:write` to format all files.
2. Run `git diff --cached --stat` to review staged changes.
3. If nothing staged, run `git add -A`.
4. Generate a conventional commit message based on the changes.
5. Run `git commit` with the message.
6. Attempt `git push`. If it times out, retry with `git push --no-verify`.


## Change Sizing Advisory

Before committing, check the size of staged changes:
```bash
git diff --cached --stat | tail -1
```

Guidelines:
- **< 400 lines**: Normal — proceed with commit
- **400-800 lines**: Flag: "This change is {N} lines. Consider splitting into smaller commits."
- **> 800 lines**: Strongly recommend splitting before commit
- Exclude generated files (migrations, lock files, snapshots) from the count
- If splitting is not practical, note the reason in the commit message
