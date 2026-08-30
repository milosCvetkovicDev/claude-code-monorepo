#!/usr/bin/env bash
# Test: source-driven-dev hook
# Phase: RED — all tests should FAIL until hook is implemented
set -euo pipefail

HOOK=".claude/hooks/source-driven-dev.sh"
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

echo "=== Source-driven-dev hook tests ==="

# Setup temp directory
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Create mock files
cat > "$TMPDIR/nestjs-file.ts" << 'EOF'
import { Controller, Get } from '@nestjs/common';
export class AppController {}
EOF

cat > "$TMPDIR/plain-file.ts" << 'EOF'
export function add(a: number, b: number): number {
  return a + b;
}
EOF

# Test 1: Hook script exists
echo ""
echo "Test 1: Hook script exists"
if test -f "$HOOK"; then
  assert_eq "Hook file exists at $HOOK" "0" "0"
else
  assert_eq "Hook file exists at $HOOK" "0" "1"
fi

# Test 2: Hook blocks edit on NestJS file without breadcrumb
echo ""
echo "Test 2: Blocks NestJS edit without breadcrumb"
rm -rf .claude/.source-driven-dev/ 2>/dev/null
if [ -f "$HOOK" ]; then
  # Simulate hook input: tool_name=Write, file_path=nestjs-file.ts
  EXIT_CODE=0
  echo '{"tool_name":"Write","tool_input":{"file_path":"'"$TMPDIR/nestjs-file.ts"'"}}' | bash "$HOOK" >/dev/null 2>&1 || EXIT_CODE=$?
  assert_eq "Hook exits with code 2 (block)" "2" "$EXIT_CODE"
else
  assert_eq "Hook exits with code 2 (block)" "2" "FILE_NOT_FOUND"
fi

# Test 3: Hook allows edit on NestJS file with breadcrumb
echo ""
echo "Test 3: Allows NestJS edit with breadcrumb"
mkdir -p .claude/.source-driven-dev/
touch .claude/.source-driven-dev/nestjs.fetched
if [ -f "$HOOK" ]; then
  EXIT_CODE=0
  echo '{"tool_name":"Write","tool_input":{"file_path":"'"$TMPDIR/nestjs-file.ts"'"}}' | bash "$HOOK" >/dev/null 2>&1 || EXIT_CODE=$?
  assert_eq "Hook exits with code 0 (allow)" "0" "$EXIT_CODE"
else
  assert_eq "Hook exits with code 0 (allow)" "0" "FILE_NOT_FOUND"
fi
rm -rf .claude/.source-driven-dev/ 2>/dev/null

# Test 4: Hook allows edit on non-framework file
echo ""
echo "Test 4: Allows non-framework edit"
if [ -f "$HOOK" ]; then
  EXIT_CODE=0
  echo '{"tool_name":"Write","tool_input":{"file_path":"'"$TMPDIR/plain-file.ts"'"}}' | bash "$HOOK" >/dev/null 2>&1 || EXIT_CODE=$?
  assert_eq "Hook exits with code 0 (allow)" "0" "$EXIT_CODE"
else
  assert_eq "Hook exits with code 0 (allow)" "0" "FILE_NOT_FOUND"
fi

# Summary
echo ""
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
