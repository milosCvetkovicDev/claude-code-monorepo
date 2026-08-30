#!/bin/bash

# Cleanup resources that consume RAM/CPU when session ends
# SessionEnd hook

set -e

cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || exit 0

echo "=== Cleaning up resources ==="

# 1. Stop Nx daemon (can consume significant memory)
if command -v npx &> /dev/null; then
  echo "Stopping Nx daemon..."
  npx nx daemon --stop 2>/dev/null || true
fi

# 2. Kill orphaned Node.js dev servers started by this project
# Look for node processes running from this project directory
PROJECT_DIR="$CLAUDE_PROJECT_DIR"
if [[ -n "$PROJECT_DIR" ]]; then
  echo "Checking for orphaned Node processes..."
  # Kill vite, webpack, next dev servers, etc. running from this directory
  pgrep -f "node.*$PROJECT_DIR.*(vite|webpack|next|serve)" 2>/dev/null | while read pid; do
    echo "  Stopping process $pid"
    kill "$pid" 2>/dev/null || true
  done
fi

# 3. Kill orphaned TypeScript server processes
echo "Checking for orphaned TypeScript servers..."
pkill -f "tsserver" 2>/dev/null || true

# 4. Kill orphaned Jest workers
echo "Checking for orphaned Jest workers..."
pkill -f "jest-worker" 2>/dev/null || true

# 5. Kill orphaned esbuild processes
echo "Checking for orphaned esbuild processes..."
pkill -f "esbuild.*service" 2>/dev/null || true

# 6. Clean up Playwright browsers if not needed
if [[ -d "node_modules/.cache/ms-playwright" ]]; then
  # Only clean if no Playwright tests are running
  if ! pgrep -f "playwright" &>/dev/null; then
    echo "Playwright browsers available for cleanup (run 'npx playwright uninstall' to remove)"
  fi
fi

# 7. Clean session breadcrumb files
echo "Cleaning session breadcrumbs..."
rm -rf "$PROJECT_DIR"/.claude/.source-driven-dev 2>/dev/null || true
rm -f "$PROJECT_DIR"/.claude/.launch-readiness-passed 2>/dev/null || true
rm -rf "$PROJECT_DIR"/.claude/.simplify-ignore-cache 2>/dev/null || true

# 8. Clean temporary files
echo "Cleaning temporary files..."
# Clean common temp directories
rm -rf "$PROJECT_DIR"/.tmp 2>/dev/null || true
rm -rf "$PROJECT_DIR"/tmp 2>/dev/null || true
rm -rf "$PROJECT_DIR"/.cache/tmp 2>/dev/null || true

# Clean coverage reports (can be large)
rm -rf "$PROJECT_DIR"/coverage 2>/dev/null || true

# Clean test results
rm -rf "$PROJECT_DIR"/test-results 2>/dev/null || true
rm -rf "$PROJECT_DIR"/playwright-report 2>/dev/null || true

# 8. Clean Nx cache if it's too large (> 1GB)
NX_CACHE="$PROJECT_DIR/.nx/cache"
if [[ -d "$NX_CACHE" ]]; then
  CACHE_SIZE=$(du -sm "$NX_CACHE" 2>/dev/null | cut -f1 || echo "0")
  if [[ "$CACHE_SIZE" -gt 1024 ]]; then
    echo "Nx cache is ${CACHE_SIZE}MB, cleaning old entries..."
    # Remove cache entries older than 7 days
    find "$NX_CACHE" -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true
  fi
fi

# 9. Clean node_modules/.cache if too large (> 500MB)
NODE_CACHE="$PROJECT_DIR/node_modules/.cache"
if [[ -d "$NODE_CACHE" ]]; then
  CACHE_SIZE=$(du -sm "$NODE_CACHE" 2>/dev/null | cut -f1 || echo "0")
  if [[ "$CACHE_SIZE" -gt 500 ]]; then
    echo "node_modules/.cache is ${CACHE_SIZE}MB, cleaning..."
    rm -rf "$NODE_CACHE"/* 2>/dev/null || true
  fi
fi

# 10. Report Docker container status (don't auto-stop, user might want them)
if command -v docker &> /dev/null && docker info &>/dev/null; then
  RUNNING=$(docker ps -q 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$RUNNING" -gt 0 ]]; then
    echo "Note: $RUNNING Docker container(s) still running"
    echo "  Run 'docker compose down' to stop them if not needed"
  fi
fi

echo "=== Cleanup complete ==="

exit 0
