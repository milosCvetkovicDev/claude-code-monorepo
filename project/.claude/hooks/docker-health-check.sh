#!/bin/bash

# Check if Docker and required services are running
# SessionStart hook

set -e

cd "$CLAUDE_PROJECT_DIR" || exit 0

echo "=== Dev Environment Status ==="

# Check Docker
if command -v docker &> /dev/null; then
  if docker info &> /dev/null; then
    echo "Docker: Running"

    # Check for project containers
    if [[ -f "docker-compose.yml" || -f "docker-compose.yaml" || -f "compose.yml" ]]; then
      RUNNING_CONTAINERS=$(docker compose ps --status running -q 2>/dev/null | wc -l | tr -d ' ')
      if [[ "$RUNNING_CONTAINERS" -gt 0 ]]; then
        echo "Docker Compose: $RUNNING_CONTAINERS container(s) running"
        docker compose ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null | head -6
      else
        echo "Docker Compose: No containers running"
        echo "  Hint: Run 'docker compose up -d' to start services"
      fi
    fi
  else
    echo "Docker: Not running"
    echo "  Hint: Start Docker Desktop or run 'dockerd'"
  fi
else
  echo "Docker: Not installed"
fi

# Check PostgreSQL connection (using pg_isready which doesn't require auth)
if command -v pg_isready &> /dev/null; then
  if pg_isready -h localhost -q 2>/dev/null; then
    echo "PostgreSQL: Running"
  else
    echo "PostgreSQL: Not accessible (this may be fine if using Docker)"
  fi
fi

# Check Node.js
if command -v node &> /dev/null; then
  echo "Node.js: $(node --version)"
fi

# Check if node_modules exists
if [[ -d "node_modules" ]]; then
  echo "Dependencies: Installed"
else
  echo "Dependencies: Not installed"
  echo "  Hint: Run 'npm install'"
fi

echo "=============================="

exit 0
