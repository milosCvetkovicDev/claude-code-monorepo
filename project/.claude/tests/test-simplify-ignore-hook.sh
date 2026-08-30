#!/usr/bin/env bash
# Test: simplify-ignore hook
# Phase: RED — all tests should FAIL until hook is implemented
set -uo pipefail

HOOK=".claude/hooks/simplify-ignore.sh"
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

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  TOTAL=$((TOTAL + 1))
  if echo "$haystack" | grep -q "$needle"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected to contain '$needle')"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Simplify-ignore hook tests ==="

# Setup
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR; rm -rf .claude/.simplify-ignore-cache/ 2>/dev/null" EXIT

# Create test file with protected block
cat > "$TMPDIR/protected-block.ts" << 'TSEOF'
export function calculate() {
  const base = 100;
  /* simplify-ignore-start: business-rule — mirrors a signed-off worked example */
  const amount = Big(input).times(Big(factor));
  /* simplify-ignore-end */
  return amount;
}
TSEOF

# Create test file with bare annotation (no reason)
cat > "$TMPDIR/bare.ts" << 'TSEOF'
export function process() {
  /* simplify-ignore-start */
  const x = 1;
  /* simplify-ignore-end */
}
TSEOF

# Create test file with multiple comment styles
cat > "$TMPDIR/multi-style.py" << 'PYEOF'
def calculate():
    # simplify-ignore-start: perf-critical — vectorized loop
    result = [x * 2 for x in range(1000)]
    # simplify-ignore-end
    return result
PYEOF

# Test 1: Hook script exists
echo ""
echo "Test 1: Hook script exists"
if test -f "$HOOK"; then
  assert_eq "Hook file exists at $HOOK" "0" "0"
else
  assert_eq "Hook file exists at $HOOK" "0" "1"
fi

# Test 2: Protected block replaced with placeholder during Read
echo ""
echo "Test 2: Hides block during read (PreToolUse Read)"
if [ -f "$HOOK" ]; then
  OUTPUT=$(echo '{"tool_name":"Read","tool_input":{"file_path":"'"$TMPDIR/protected-block.ts"'"},"event":"PreToolUse"}' | bash "$HOOK" 2>/dev/null)
  CONTENT=$(cat "$TMPDIR/protected-block.ts")
  assert_contains "File contains BLOCK_ placeholder" "BLOCK_" "$CONTENT"
else
  assert_contains "File contains BLOCK_ placeholder" "BLOCK_" "FILE_NOT_FOUND"
fi

# Test 3: Protected block restored after Edit
echo ""
echo "Test 3: Restores block after edit (PostToolUse Edit)"
if [ -f "$HOOK" ]; then
  OUTPUT=$(echo '{"tool_name":"Edit","tool_input":{"file_path":"'"$TMPDIR/protected-block.ts"'"},"event":"PostToolUse"}' | bash "$HOOK" 2>/dev/null)
  CONTENT=$(cat "$TMPDIR/protected-block.ts")
  assert_contains "File contains original protected code" "Big(input)" "$CONTENT"
else
  assert_contains "File contains original protected code" "Big(input)" "FILE_NOT_FOUND"
fi

# Test 4: Crash recovery restores from backup (Stop)
echo ""
echo "Test 4: Stop hook restores backup"
if [ -f "$HOOK" ]; then
  # Simulate crash: backup exists but file has placeholders
  mkdir -p .claude/.simplify-ignore-cache/
  # Compute path hash the same way the hook does (md5 of full path, first 16 chars)
  BNAME=$(echo -n "$TMPDIR/protected-block.ts" | md5 -q 2>/dev/null || echo -n "$TMPDIR/protected-block.ts" | md5sum | head -c 16)
  BNAME=$(echo "$BNAME" | head -c 16)
  cp "$TMPDIR/protected-block.ts" ".claude/.simplify-ignore-cache/${BNAME}.bak"
  echo "$TMPDIR/protected-block.ts" > ".claude/.simplify-ignore-cache/${BNAME}.path"
  # Corrupt the file with placeholder
  echo "BLOCK_abc12345" > "$TMPDIR/protected-block.ts"
  OUTPUT=$(echo '{"event":"Stop"}' | bash "$HOOK" 2>/dev/null)
  CONTENT=$(cat "$TMPDIR/protected-block.ts")
  assert_contains "File restored from backup" "Big(input)" "$CONTENT"
else
  assert_contains "File restored from backup" "Big(input)" "FILE_NOT_FOUND"
fi

# Test 5: Bare annotation without reason triggers warning
echo ""
echo "Test 5: Warns on bare annotation"
if [ -f "$HOOK" ]; then
  OUTPUT=$(echo '{"tool_name":"Read","tool_input":{"file_path":"'"$TMPDIR/bare.ts"'"},"event":"PreToolUse"}' | bash "$HOOK" 2>&1)
  assert_contains "Warning about missing reason" "missing reason" "$OUTPUT"
else
  assert_contains "Warning about missing reason" "missing reason" "FILE_NOT_FOUND"
fi

# Test 6: Python comment style supported
echo ""
echo "Test 6: Python comment style (#) supported"
if [ -f "$HOOK" ]; then
  OUTPUT=$(echo '{"tool_name":"Read","tool_input":{"file_path":"'"$TMPDIR/multi-style.py"'"},"event":"PreToolUse"}' | bash "$HOOK" 2>/dev/null)
  CONTENT=$(cat "$TMPDIR/multi-style.py")
  assert_contains "Python block replaced with placeholder" "BLOCK_" "$CONTENT"
else
  assert_contains "Python block replaced with placeholder" "BLOCK_" "FILE_NOT_FOUND"
fi

# Summary
echo ""
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
