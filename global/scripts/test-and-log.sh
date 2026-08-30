#!/bin/bash
# Universal test execution wrapper for the test-runner agent
# Detects framework, runs tests, captures output to log file

set -euo pipefail

# Arguments
TARGET="${1:-}"
EXTRA_ARGS="${@:2}"

# Directories
LOG_DIR=".claude/test-results"
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date -u +"%Y%m%d-%H%M%S")
LOG_FILE="$LOG_DIR/test-$TIMESTAMP.log"

# Detect framework from testing-config.md or auto-detect
detect_framework() {
  # Check for CCPM testing config first
  if [ -f ".claude/testing-config.md" ]; then
    framework=$(grep -m1 "^framework:" .claude/testing-config.md 2>/dev/null | awk '{print $2}')
    test_cmd=$(grep -m1 "^test_command:" .claude/testing-config.md 2>/dev/null | cut -d: -f2- | xargs)
    if [ -n "$framework" ] && [ -n "$test_cmd" ]; then
      echo "$test_cmd"
      return 0
    fi
  fi

  # Auto-detect from project structure
  if [ -n "$TARGET" ]; then
    # Target-specific detection
    if [ -f "apps/$TARGET/jest.config.ts" ] || [ -f "apps/$TARGET/jest.config.js" ]; then
      echo "npx nx run $TARGET:test"
      return 0
    elif [ -f "apps/$TARGET/project.json" ] && grep -q "bun test" "apps/$TARGET/project.json" 2>/dev/null; then
      echo "bun test apps/$TARGET/test"
      return 0
    elif [ -f "apps/$TARGET/playwright.config.ts" ]; then
      echo "npx nx run $TARGET:e2e"
      return 0
    fi
  fi

  # Generic detection
  if [ -f "nx.json" ]; then
    echo "npx nx run-many -t test"
    return 0
  elif [ -f "jest.config.ts" ] || [ -f "jest.config.js" ]; then
    echo "npx jest"
    return 0
  elif [ -f "vitest.config.ts" ]; then
    echo "npx vitest run"
    return 0
  elif [ -f "package.json" ] && grep -q '"test"' package.json 2>/dev/null; then
    echo "npm test"
    return 0
  elif [ -f "Makefile" ] && grep -q "^test:" Makefile 2>/dev/null; then
    echo "make test"
    return 0
  fi

  echo ""
  return 1
}

# Main execution
echo "=== Test Execution ===" | tee "$LOG_FILE"
echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" | tee -a "$LOG_FILE"
echo "Target: ${TARGET:-all}" | tee -a "$LOG_FILE"
echo "Log: $LOG_FILE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Detect test command
TEST_CMD=$(detect_framework)
if [ -z "$TEST_CMD" ]; then
  echo "❌ Could not detect test framework" | tee -a "$LOG_FILE"
  echo "Create .claude/testing-config.md with framework and test_command fields" | tee -a "$LOG_FILE"
  echo "Or run: /testing:prime" | tee -a "$LOG_FILE"
  exit 1
fi

# Append extra args if provided
if [ -n "$EXTRA_ARGS" ]; then
  TEST_CMD="$TEST_CMD $EXTRA_ARGS"
fi

echo "Running: $TEST_CMD" | tee -a "$LOG_FILE"
echo "---" | tee -a "$LOG_FILE"

# Execute tests, capture output
EXIT_CODE=0
eval "$TEST_CMD" 2>&1 | tee -a "$LOG_FILE" || EXIT_CODE=$?

echo "" | tee -a "$LOG_FILE"
echo "---" | tee -a "$LOG_FILE"
echo "Exit code: $EXIT_CODE" | tee -a "$LOG_FILE"
echo "Log saved: $LOG_FILE" | tee -a "$LOG_FILE"

if [ $EXIT_CODE -eq 0 ]; then
  echo "✅ Tests passed" | tee -a "$LOG_FILE"
else
  echo "❌ Tests failed (exit code: $EXIT_CODE)" | tee -a "$LOG_FILE"
fi

exit $EXIT_CODE
