#!/bin/bash

# Show random tips at session start (rare, 1 in 5 chance)
# SessionStart hook

set -e

# Only show tip 1 in 5 times to minimize context overhead
if [[ $((RANDOM % 5)) -ne 0 ]]; then
  exit 0
fi

TIPS=(
  "Tip: '/hooks' to see all registered hooks"
  "Tip: Protected files (.env, keys) are blocked from editing"
  "Tip: Tests run automatically before Claude finishes (quality gate)"
  "Tip: Prettier auto-formats files after edits"
)

RANDOM_INDEX=$((RANDOM % ${#TIPS[@]}))
echo "${TIPS[$RANDOM_INDEX]}"
exit 0
