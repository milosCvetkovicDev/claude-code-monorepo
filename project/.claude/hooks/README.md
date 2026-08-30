# Claude Code Hooks - Tips & Tricks

Quick reference for all configured hooks in this workspace.

> **See also**: the Skills Guide (`docs/runbooks/claude-code/skills-guide.md`, not in this export) for workflow automation with `/skill-name` commands.

## Automatic Hooks (No Action Needed)

These run automatically:

| When | What Happens |
| ---------------------- | ------------------------------------------------------------------ |
| **Session starts**     | Node.js version checked, Git syncs, Docker/env checked, PRs loaded |
| **You edit a file**    | Prettier auto-formats it |
| **Deploy succeeds**    | Reminds to run local database seeding for the dev instance |
| **Session ends**       | Nx daemon stopped, orphaned processes killed, temp files cleaned |
| **Claude needs input** | Desktop notification sent |

## Commands to Remember

```bash
# Deep cleanup (frees disk space, clears all caches)
claude --maintenance

# Check registered hooks
/hooks

# Run hooks manually (for testing)
.claude/hooks/cleanup-resources.sh
.claude/hooks/deep-cleanup.sh
```

## What's Protected

These files/commands are **blocked** for safety:

**Protected Files:**

- `.env`, `.env.*` (environment files)
- `*.pem`, `*.key`, `id_rsa` (keys/certs)
- `credentials.json`, `secrets.json`
- Files in `.ssh/`, `.aws/`, `.azure/`

**Blocked Commands:**

- `git push --force` to main/master
- `rm -rf /`, `rm -rf ~`
- `git reset --hard origin/main`
- Other destructive operations

## Tips

### 1. Node.js Version

This project requires **Node.js 22 LTS**. If you see a version mismatch alert:

```bash
# Switch to Node 22
nvm use 22

# Or install if needed
nvm install 22 && nvm use 22
```

The `.nvmrc` file specifies version 22, so `nvm use` without arguments works too.

### 2. Nx Commands

If you use `jest` or `tsc` directly, you'll get a reminder to use Nx:

```bash
# Instead of:
jest apps/legacy-api

# Use:
nx test legacy-api
```

### 3. Session Start Info

At session start, you'll see:

- Current git branch status
- Docker container status
- Open GitHub PRs and issues

### 4. Quality Gate

Before Claude finishes, affected tests run automatically. If tests fail, you'll see a warning.

### 5. Desktop Notifications

When Claude waits for permission or input, you get a macOS notification with sound.

### 6. Resource Cleanup

**Automatic** (session end):

- Stops Nx daemon (~200-500MB RAM saved)
- Kills orphaned Node processes
- Cleans temp files, coverage reports

**Manual** (deep cleanup):

```bash
claude --maintenance
```

This clears:

- All Nx cache
- node_modules/.cache
- npm cache
- Docker dangling images

### 7. Git Sync

At session start:

- On `main`: pulls latest
- On feature branch: merges latest main

## Hook Files

```
.claude/hooks/
├── check-node-version.sh    # SessionStart - verify Node.js v22
├── git-sync.sh              # SessionStart - git pull/merge
├── docker-health-check.sh   # SessionStart - env status
├── load-github-context.sh   # SessionStart - PRs/issues
├── block-dangerous-commands.sh  # PreToolUse - safety
├── enforce-nx-commands.sh   # PreToolUse - nx reminder
├── protect-sensitive-files.sh   # PreToolUse - block .env etc
├── auto-format.sh           # PostToolUse - prettier
├── seed-after-deploy.sh     # PostToolUse - seed dev instance after deploy
├── desktop-notification.sh  # Notification - alerts
├── quality-gate-tests.sh    # Stop - run tests
├── cleanup-resources.sh     # SessionEnd - free resources
├── cleanup-on-idle.sh       # Utility - light cleanup
└── deep-cleanup.sh          # Setup - aggressive cleanup
```

## Related Skills

Some hooks have corresponding skills for on-demand use:

| Hook | Skill | Use Case |
| ------------------------ | ----------------- | ------------------------------ |
| `deep-cleanup.sh`        | `/cleanup`        | Manual deep cleanup |
| `docker-health-check.sh` | `/env-status`     | Check environment mid-session |
| `quality-gate-tests.sh`  | `/test-affected`  | Run affected tests on-demand |
| `load-github-context.sh` | `/github-refresh` | Refresh PRs/issues mid-session |

See the Skills Guide (`docs/runbooks/claude-code/skills-guide.md`, not in this export) for all available skills.

## Troubleshooting

**Hook not running?**

```bash
/hooks  # Check if registered
```

**Too slow at session start?**

- GitHub context fetch has 30s timeout
- Docker check has 15s timeout

**Want to skip hooks temporarily?**

- Edit `.claude/settings.json`
- Comment out the hook entry

**Memory issues?**

```bash
# Run manual cleanup
.claude/hooks/cleanup-resources.sh

# Or deep cleanup
claude --maintenance

# Or use the skill
/cleanup
```
