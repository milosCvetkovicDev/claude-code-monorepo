#!/usr/bin/env bash
# Test: block-dangerous-commands PR merge/approval guard (loop-engineering "never merge").
# Run from repo root: bash .claude/tests/test-merge-guard-hook.sh
set -euo pipefail

HOOK=".claude/hooks/block-dangerous-commands.sh"
PASS=0
FAIL=0
TOTAL=0

# expect <want-exit> <command-string>
expect() {
  local want="$1" cmd="$2"
  TOTAL=$((TOTAL + 1))
  local got=0
  printf '%s' "$(jq -nc --arg c "$cmd" '{tool_input:{command:$c}}')" | bash "$HOOK" >/dev/null 2>&1 || got=$?
  if [ "$got" = "$want" ]; then
    PASS=$((PASS + 1)); echo "  PASS (exit $got): $cmd"
  else
    FAIL=$((FAIL + 1)); echo "  FAIL (want $want, got $got): $cmd"
  fi
}

echo "=== PR merge-guard hook tests ==="

echo ""
echo "Must BLOCK (exit 2) — real merge / approve / auto-merge paths:"
expect 2 'gh pr merge 1352 --squash'
expect 2 'gh pr enable-auto --squash 1352'
expect 2 'gh pr review 1352 --approve'
expect 2 'gh pr review 1352 --dismiss --body x'
expect 2 'gh api -X PUT repos/o/v/pulls/1352/merge'
expect 2 "gh api graphql -f query='mutation{mergePullRequest(input:{pullRequestId:\"PRI_x\"}){pullRequest{merged}}}'"
expect 2 'gh pr checks 1352 && gh pr merge 1352'
expect 2 'FOO=bar gh pr merge 1352'

echo ""
echo "Must BLOCK — escape-hatch bypass attempts (suffix / over-match):"
expect 2 'gh pr merge 1352 # ALLOW_PR_MERGE=1'
expect 2 'ALLOW_PR_MERGE=10 gh pr merge 1352'

echo ""
echo "Must PASS (exit 0) — escape hatch + false-positive-safe (comments/echoes/reads):"
expect 0 'ALLOW_PR_MERGE=1 gh pr merge 1352 --squash'
expect 0 'echo "to merge run: gh pr merge 1352 --approve"'
expect 0 '# reminder: gh pr enable-auto is blocked by the hook'
expect 0 'cat SKILL.md | grep "gh pr merge"'
expect 0 'gh pr list --state open'
expect 0 'gh pr view 1352 --json mergeable'
expect 0 'gh pr create --title t --body "ALLOW_PR_MERGE=1 is the escape hatch"'
expect 0 'gh pr review 1352 --comment --body lgtm'

echo ""
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
