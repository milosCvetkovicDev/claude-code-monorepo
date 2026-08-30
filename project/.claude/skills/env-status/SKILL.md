---
name: env-status
description: "Check local development environment health: Docker status, database connectivity, Node.js version, dependency state, and service ports. Use for a quick overview of local setup. Do not use for fixing issues (use dev-troubleshoot) or starting services (use dev-servers)."
model: haiku
---

# Environment Status Check

Check the status of the development environment.

## What to Check

### 1. Docker Status

```bash
# Check if Docker is running
docker info &>/dev/null && echo "Docker: Running" || echo "Docker: Not running"

# Check Docker Compose containers
docker compose ps --format "table {{.Name}}\t{{.Status}}"
```

### 2. PostgreSQL Status

```bash
# Check if PostgreSQL is accessible
psql -h localhost -U postgres -c '\q' 2>/dev/null && echo "PostgreSQL: Connected" || echo "PostgreSQL: Not accessible"
```

### 3. Node.js Version

```bash
node --version
```

### 4. Dependencies Status

```bash
# Check if node_modules exists
[[ -d "node_modules" ]] && echo "Dependencies: Installed" || echo "Dependencies: Not installed - run 'npm install'"
```

### 5. Environment Files

```bash
# Check for .env file
[[ -f ".env" ]] && echo ".env: Present" || echo ".env: Missing - create symlink to apps/legacy-api/.env"
[[ -f "apps/legacy-api/.env" ]] && echo "Backend .env: Present" || echo "Backend .env: Missing - copy from .env.template"
```

### 6. Nx Daemon Status

```bash
# Check Nx daemon
npx nx daemon --status 2>/dev/null || echo "Nx daemon: Not running"
```

## Quick Fixes

| Issue | Fix |
| ------------------------- | ------------------------------------------- |
| Docker not running | Start Docker Desktop or run `dockerd`       |
| No containers | Run `docker compose up -d`                  |
| PostgreSQL not accessible | Check Docker containers or local PostgreSQL |
| Dependencies missing | Run `npm install`                           |
| .env missing | Run `ln -sf apps/legacy-api/.env .env`   |

## Output

Provide a status table showing:

- Component status (Running/Stopped/Missing)
- Any issues detected
- Recommended fixes
