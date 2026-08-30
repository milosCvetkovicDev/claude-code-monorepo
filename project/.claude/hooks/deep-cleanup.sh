#!/bin/bash

# Deep cleanup - more aggressive resource cleanup
# Run manually or via Setup hook with --maintenance flag

set -e

cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || exit 0

echo "=== Deep Cleanup Starting ==="
echo "This will free up disk space and memory."
echo ""

# 1. Stop all Node processes from this project
PROJECT_DIR="$CLAUDE_PROJECT_DIR"
echo "1. Stopping all Node processes from this project..."
pgrep -f "node.*$PROJECT_DIR" 2>/dev/null | while read pid; do
  echo "   Stopping PID $pid"
  kill "$pid" 2>/dev/null || true
done

# 2. Stop Nx daemon
echo "2. Stopping Nx daemon..."
npx nx daemon --stop 2>/dev/null || true
npx nx reset 2>/dev/null || true

# 3. Clean all caches
echo "3. Cleaning caches..."

# Nx cache
if [[ -d ".nx/cache" ]]; then
  SIZE=$(du -sh ".nx/cache" 2>/dev/null | cut -f1 || echo "0")
  echo "   Cleaning Nx cache ($SIZE)..."
  rm -rf .nx/cache/* 2>/dev/null || true
fi

# node_modules/.cache
if [[ -d "node_modules/.cache" ]]; then
  SIZE=$(du -sh "node_modules/.cache" 2>/dev/null | cut -f1 || echo "0")
  echo "   Cleaning node_modules/.cache ($SIZE)..."
  rm -rf node_modules/.cache/* 2>/dev/null || true
fi

# Vite cache
find . -type d -name ".vite" -exec rm -rf {} + 2>/dev/null || true

# TypeScript build info
find . -name "*.tsbuildinfo" -delete 2>/dev/null || true

# Jest cache
find . -type d -name ".jest-cache" -exec rm -rf {} + 2>/dev/null || true

# 4. Clean test artifacts
echo "4. Cleaning test artifacts..."
rm -rf coverage 2>/dev/null || true
rm -rf test-results 2>/dev/null || true
rm -rf playwright-report 2>/dev/null || true
rm -rf .nyc_output 2>/dev/null || true

# 5. Clean build outputs (optional - commented out as it may require rebuild)
# echo "5. Cleaning build outputs..."
# rm -rf dist 2>/dev/null || true
# find . -type d -name "dist" -exec rm -rf {} + 2>/dev/null || true

# 6. Clean temporary files
echo "5. Cleaning temporary files..."
rm -rf .tmp tmp 2>/dev/null || true
find . -name "*.log" -type f -mtime +7 -delete 2>/dev/null || true
find . -name "*.tmp" -type f -delete 2>/dev/null || true

# 7. Docker cleanup (optional)
if command -v docker &> /dev/null && docker info &>/dev/null; then
  echo "6. Docker cleanup..."
  # Remove dangling images
  docker image prune -f 2>/dev/null || true
  # Remove unused volumes (be careful!)
  # docker volume prune -f 2>/dev/null || true
fi

# 8. npm cache cleanup
echo "7. Cleaning npm cache..."
npm cache clean --force 2>/dev/null || true

# 9. Report disk space freed
echo ""
echo "=== Deep Cleanup Complete ==="
df -h . | tail -1 | awk '{print "Disk space available: " $4}'

exit 0
