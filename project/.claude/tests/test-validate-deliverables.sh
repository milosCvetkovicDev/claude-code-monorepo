#!/usr/bin/env bash
# Test: validate-deliverables
# Phase: RED — all tests should FAIL until deliverables are created
set -uo pipefail

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

check_file() {
  local desc="$1" path="$2"
  if [ -f "$path" ]; then
    assert_eq "$desc" "0" "0"
  else
    assert_eq "$desc" "0" "1"
  fi
}

echo "=== Validate deliverables tests ==="

echo ""
echo "Test 1: Security checklist exists"
check_file "security-checklist.md exists" ".claude/references/review/security-checklist.md"

echo ""
echo "Test 2: Performance checklist exists"
check_file "performance-checklist.md exists" ".claude/references/review/performance-checklist.md"

echo ""
echo "Test 3: Accessibility checklist exists"
check_file "accessibility-checklist.md exists" ".claude/references/review/accessibility-checklist.md"

echo ""
echo "Test 4: Severity labels exists"
check_file "severity-labels.md exists" ".claude/references/review/severity-labels.md"

echo ""
echo "Test 5: ADR template exists"
check_file "adr-template.md exists" ".claude/references/adr-template.md"

echo ""
echo "Test 6: help-all command exists"
check_file "help-all.md exists" ".claude/commands/help-all.md"

echo ""
echo "Test 7: adr-create command exists"
check_file "adr-create.md exists" ".claude/commands/adr-create.md"

# Summary
echo ""
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
