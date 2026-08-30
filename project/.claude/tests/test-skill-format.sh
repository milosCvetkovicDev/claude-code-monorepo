#!/usr/bin/env bash
# Test: skill-format validation
# Phase: RED — all tests should FAIL until skills are created/enhanced
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

echo "=== Skill format validation tests ==="

# Test 1: source-driven-dev SKILL.md exists with frontmatter
echo ""
echo "Test 1: source-driven-dev SKILL.md format"
SKILL=".claude/skills/source-driven-dev/SKILL.md"
if [ -f "$SKILL" ] && head -1 "$SKILL" | grep -q "^---"; then
  assert_eq "Has frontmatter delimiter" "0" "0"
else
  assert_eq "Has frontmatter delimiter" "0" "1"
fi

# Test 2: deprecation-lifecycle SKILL.md exists with frontmatter
echo ""
echo "Test 2: deprecation-lifecycle SKILL.md format"
SKILL=".claude/skills/deprecation-lifecycle/SKILL.md"
if [ -f "$SKILL" ] && head -1 "$SKILL" | grep -q "^---"; then
  assert_eq "Has frontmatter delimiter" "0" "0"
else
  assert_eq "Has frontmatter delimiter" "0" "1"
fi

# Test 3: Anti-rationalization tables present in at least one skill
echo ""
echo "Test 3: Anti-rationalization tables exist"
FOUND=0
for skill_dir in .claude/skills/*/; do
  if [ -f "${skill_dir}SKILL.md" ]; then
    if grep -qi "anti-rationalization\|If you're thinking\|rationalization" "${skill_dir}SKILL.md" 2>/dev/null; then
      FOUND=1
      break
    fi
  fi
done
assert_eq "At least one skill has anti-rationalization table" "1" "$FOUND"

# Test 4: Severity labels referenced in review-related skills/agents
echo ""
echo "Test 4: Severity labels in review agents"
FOUND=0
for skill_dir in .claude/skills/*/; do
  if [ -f "${skill_dir}SKILL.md" ]; then
    if grep -qi "Critical.*Important.*Suggestion.*Nit\|severity-labels" "${skill_dir}SKILL.md" 2>/dev/null; then
      FOUND=1
      break
    fi
  fi
done
assert_eq "At least one skill references severity labels" "1" "$FOUND"

# Summary
echo ""
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
