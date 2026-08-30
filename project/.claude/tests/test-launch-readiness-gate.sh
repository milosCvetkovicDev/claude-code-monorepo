#!/usr/bin/env bash
# Test: launch-readiness-gate hook
# Phase: RED — all tests should FAIL until hook is implemented
set -uo pipefail

HOOK=".claude/hooks/launch-readiness-gate.sh"
PASS=0
FAIL=0
TOTAL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  TOTAL=$((TOTAL + 1))
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected=$expected, actual=$actual)"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Launch-readiness gate hook tests ==="

# Test 1: Hook script exists
echo ""
echo "Test 1: Hook script exists"
if test -f "$HOOK"; then
  assert_eq "Hook file exists at $HOOK" "0" "0"
else
  assert_eq "Hook file exists at $HOOK" "0" "1"
fi

# Test 2: Hook blocks deploy command without readiness pass
echo ""
echo "Test 2: Blocks deploy without readiness"
rm -f .claude/.launch-readiness-passed 2>/dev/null
if [ -f "$HOOK" ]; then
  EXIT_CODE=0
  echo '{"tool_name":"Bash","tool_input":{"command":"gh workflow run Deploy --ref main"}}' | bash "$HOOK" >/dev/null 2>&1 || EXIT_CODE=$?
  assert_eq "Hook exits with code 2 (block)" "2" "$EXIT_CODE"
else
  assert_eq "Hook exits with code 2 (block)" "2" "FILE_NOT_FOUND"
fi

# Test 3: Hook allows deploy after readiness pass
echo ""
echo "Test 3: Allows deploy after readiness"
mkdir -p .claude/ 2>/dev/null
touch .claude/.launch-readiness-passed
if [ -f "$HOOK" ]; then
  EXIT_CODE=0
  echo '{"tool_name":"Bash","tool_input":{"command":"gh workflow run Deploy --ref main"}}' | bash "$HOOK" >/dev/null 2>&1 || EXIT_CODE=$?
  assert_eq "Hook exits with code 0 (allow)" "0" "$EXIT_CODE"
else
  assert_eq "Hook exits with code 0 (allow)" "0" "FILE_NOT_FOUND"
fi
rm -f .claude/.launch-readiness-passed 2>/dev/null

# Summary
echo ""
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
