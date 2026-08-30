#!/bin/bash

# Run affected tests before allowing Claude to stop
# Stop hook - ensures code quality

set -e

cd "$CLAUDE_PROJECT_DIR" || exit 0

# Parse input from stdin
INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')

# Prevent infinite loops
if [[ "$STOP_HOOK_ACTIVE" == "true" ]]; then
  exit 0
fi

# Check if there are any uncommitted changes
if git diff --quiet && git diff --cached --quiet; then
  # No changes, allow stop
  exit 0
fi

# Check if nx is available
if ! command -v npx &> /dev/null; then
  exit 0
fi

# Get list of affected projects
AFFECTED=$(npx nx show projects --affected --base=HEAD~1 2>/dev/null || true)

if [[ -z "$AFFECTED" ]]; then
  # No affected projects, allow stop
  exit 0
fi

echo "=== Quality Gate Check ==="
echo "Affected projects: $AFFECTED"
echo ""

# Run affected typecheck first (faster, catches type errors early)
echo "Running affected typecheck..."
if timeout 60 npx nx affected -t typecheck --base=HEAD~1 2>&1; then
  echo "Typecheck passed!"
else
  echo "WARNING: Typecheck failed — fix type errors before finishing."
fi
echo ""

# Run affected tests (with a timeout to avoid hanging)
echo "Running affected tests..."
if timeout 120 npx nx affected -t test --base=HEAD~1 2>&1; then
  echo ""
  echo "All tests passed!"
  echo "=========================="
  exit 0
else
  TEST_EXIT_CODE=$?
  echo ""
  echo "WARNING: Some tests may have failed (exit code: $TEST_EXIT_CODE)"
  echo "Consider fixing failing tests before finishing."
  echo "=========================="
  # Don't block, just warn - output goes to context
  exit 0
fi
