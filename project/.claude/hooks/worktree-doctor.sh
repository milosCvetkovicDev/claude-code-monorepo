#!/bin/bash

# Worktree registry self-heal hook for Claude Code sessions.
#
# Runs `acme-worktree doctor` at session start. Drift accumulates in two directions and the
# hook reports both:
#
#   orphaned instances  — registered, but the worktree directory is gone. Their slot stays
#                         reserved forever, so the allocator eventually refuses to create
#                         anything. `doctor` frees these automatically.
#   unmanaged worktrees — on disk, but never registered. Worse than untidy: their ports were
#                         never allocated, so `create` can hand the same instance number to a
#                         new worktree and two checkouts collide. `doctor` only REPORTS these;
#                         adopting them changes the registry, which is not a thing a session
#                         hook should do silently. The message tells you the command.
#
# Output is intentionally one line. This hook never blocks session start.

set -e

# Skip silently if the CLI isn't installed on this machine
command -v acme-worktree >/dev/null 2>&1 || exit 0

# Run doctor (auto-frees orphans), strip ANSI colour codes (hook context is non-TTY)
ESC=$(printf '\033')
OUT=$(acme-worktree doctor 2>/dev/null | sed "s/${ESC}\[[0-9;]*m//g" || true)

# Both directions clean is the common case, and the only one that needs no attention.
if echo "$OUT" | grep -q "No orphaned instances" && echo "$OUT" | grep -q "No unmanaged worktrees"; then
  echo "Worktree: registry in sync"
  exit 0
fi

PARTS=""

FREED=$(echo "$OUT" | grep -oE "Freed [0-9]+ instance" | grep -oE "[0-9]+" | head -1)
if [ -n "$FREED" ] && [ "$FREED" -gt 0 ]; then
  NAMES=$(echo "$OUT" | grep -oE "Unregistered instance '[^']+'" \
    | sed "s/Unregistered instance '//; s/'//" | paste -sd, - | sed 's/,/, /g')
  PARTS="freed ${FREED} orphaned slot(s) — ${NAMES}"
fi

UNMANAGED=$(echo "$OUT" | grep -oE "Found [0-9]+ unmanaged worktree" | grep -oE "[0-9]+" | head -1)
if [ -n "$UNMANAGED" ] && [ "$UNMANAGED" -gt 0 ]; then
  [ -n "$PARTS" ] && PARTS="${PARTS}; "
  PARTS="${PARTS}${UNMANAGED} unmanaged worktree(s) — ports unallocated, run 'acme-worktree doctor --adopt'"
fi

if [ -n "$PARTS" ]; then
  echo "Worktree: ${PARTS}"
else
  echo "Worktree: doctor ran"
fi

exit 0
