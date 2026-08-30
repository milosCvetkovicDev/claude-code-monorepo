#!/bin/bash

# Block dangerous bash commands
# PreToolUse hook for Bash operations

set -e

# Parse input from stdin
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Skip if no command
if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# List of dangerous patterns to block
DANGEROUS_PATTERNS=(
  "git push.*--force.*main"
  "git push.*--force.*master"
  "git push -f.*main"
  "git push -f.*master"
  "git reset --hard.*origin/main"
  "git reset --hard.*origin/master"
  "git clean -fd"
  "rm -rf /"
  "rm -rf /\*"
  "rm -rf ~"
  "rm -rf \$HOME"
  "rm -rf \."
  "> /dev/sda"
  "mkfs\."
  "dd if=.*/dev/"
  ":(){:|:&};:"
  "chmod -R 777 /"
  "chown -R.*/"
)

# Check each dangerous pattern
for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    echo "BLOCKED: Dangerous command detected matching pattern: $pattern" >&2
    echo "Command was: $COMMAND" >&2
    exit 2
  fi
done

# Block force push to any protected branch
if echo "$COMMAND" | grep -qE "git push.*(--force|-f)"; then
  echo "WARNING: Force push detected. Please confirm this is intentional." >&2
fi

# ---------------------------------------------------------------------------
# PR merge / approval guard — loop-engineering "never merge" made mechanical.
# Autonomous loops (e.g. the triage skill) must OPEN PRs but never merge,
# self-approve, dismiss reviews, or arm auto-merge; the human gate (review +
# required checks + the FD's prod sign-off) is the point. A deliberate HUMAN
# merge is still fine — PREFIX the command: ALLOW_PR_MERGE=1 gh pr merge ...
#
# Best-effort guard, NOT a sandbox. Triggers are anchored to a command start
# (line-start, after a ; && || | separator, or after env-var assignments) so
# comments/echoes that merely *mention* these commands don't false-block, while
# real invocations — including env-prefixed ones — are still caught. Covered:
# `gh pr merge`, `gh pr enable-auto` (arms auto-merge), `gh pr review --approve|--dismiss`,
# the REST `gh api .../pulls/<ref>/merge`, and the GraphQL `mergePullRequest` mutation.
# ALLOW_PR_MERGE=1 is a string at the command's front, not proof of human
# provenance; BRANCH PROTECTION (required reviews + checks on main) is the real
# merge guarantee — this hook only stops the well-behaved loop from merging.
# ---------------------------------------------------------------------------
# command-start := line-start | after a shell separator | after env-var assignments
PRE='(^|[;&|][[:space:]]*)([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*'
if echo "$COMMAND" | grep -qE "${PRE}gh[[:space:]]+pr[[:space:]]+(merge|enable-auto)\b" \
   || echo "$COMMAND" | grep -qiE "${PRE}gh[[:space:]]+pr[[:space:]]+review\b.*(--approve|--dismiss)" \
   || echo "$COMMAND" | grep -qiE "${PRE}gh[[:space:]]+api\b.*pulls/[0-9A-Za-z._-]+/merge" \
   || echo "$COMMAND" | grep -qiE "${PRE}gh[[:space:]]+api[[:space:]]+graphql.*mergePullRequest"; then
  # Bypass must be an env-var assignment at the FRONT of the command (not embedded
  # in a comment, string arg, or a value like =10) — position-anchored on purpose.
  if ! echo "$COMMAND" | grep -qE '^[[:space:]]*ALLOW_PR_MERGE=1[[:space:]]'; then
    echo "BLOCKED: PR merge / approval is gated (loop-engineering 'never merge')." >&2
    echo "Command was: $COMMAND" >&2
    echo "" >&2
    echo "Autonomous loops must never merge, self-approve, or arm auto-merge. For a" >&2
    echo "deliberate human merge, confirm with the user, then PREFIX the command:" >&2
    echo "  ALLOW_PR_MERGE=1 gh pr merge ..." >&2
    exit 2
  fi
fi

# ---------------------------------------------------------------------------
# Production write guard
# Prod read+write is allow-listed, but destructive SQL against the production
# databases must be deliberate. Reads (SELECT/\dt/etc.) flow freely; mutating
# statements are hard-blocked unless the command is prefixed ALLOW_PROD_WRITE=1
# (same escape-hatch convention as SKIP_HOOKS=1).
# ---------------------------------------------------------------------------
if echo "$COMMAND" | grep -qiE '\bpsql\b'; then
  if echo "$COMMAND" | grep -qiE 'prod-acme-postgres|-d[[:space:]]+(legacy_production|commission_production)|dbname=(legacy_production|commission_production)'; then
    if echo "$COMMAND" | grep -qiE '\b(DELETE|UPDATE|INSERT|DROP|TRUNCATE|ALTER|CREATE|GRANT|REVOKE|MERGE)\b'; then
      if ! echo "$COMMAND" | grep -qE 'ALLOW_PROD_WRITE=1'; then
        echo "BLOCKED: Destructive SQL against PRODUCTION detected." >&2
        echo "Command was: $COMMAND" >&2
        echo "" >&2
        echo "Reads (SELECT) are allowed freely. For a deliberate prod write, confirm" >&2
        echo "with the user, then prefix the command with: ALLOW_PROD_WRITE=1" >&2
        exit 2
      fi
    fi
  fi
fi

exit 0
