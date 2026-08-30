#!/usr/bin/env bash
# Triage discovery — READ-ONLY repo-health scan for the loop-engineering triage loop.
#
# Emits a structured, human + machine readable findings report to stdout. Writes NOTHING
# and mutates NOTHING (no branches, no PRs, no issues, no files). Safe to run standalone,
# headless (e.g. from a scheduled automation), or as the first step of the `triage` skill.
#
# Used by: .claude/skills/triage/SKILL.md
# Env knobs (all optional):
#   TRIAGE_LOOKBACK_HOURS   how far back to scan for risky commits / stale PRs (default 36)
#   TRIAGE_STALE_PR_HOURS   a PR untouched longer than this is flagged stale (default 72)
#
# Exit code is always 0 — discovery never fails the loop; missing data is reported, not fatal.

# `-u` for typo safety; every external call below uses `|| <fallback>` so the exit-0-always
# contract above holds even under `pipefail`. Don't add a raw command without a fallback.
set -uo pipefail

cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}" || exit 0

have() { command -v "$1" >/dev/null 2>&1; }
section() { printf '\n## %s\n' "$1"; }

LOOKBACK_HOURS="${TRIAGE_LOOKBACK_HOURS:-36}"
STALE_PR_HOURS="${TRIAGE_STALE_PR_HOURS:-72}"

# ISO timestamp for "now - N hours", portable across BSD (macOS) and GNU (Linux) date.
hours_ago_iso() {
  local h="$1"
  date -u -v-"${h}"H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
    || date -u -d "-${h} hours" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
    || echo ""
}
NOW_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)"
SINCE_ISO="$(hours_ago_iso "$LOOKBACK_HOURS")"
STALE_BEFORE_ISO="$(hours_ago_iso "$STALE_PR_HOURS")"

printf '# Triage discovery report\n'
printf 'generated_utc: %s\n'   "$NOW_ISO"
printf 'lookback_hours: %s\n'  "$LOOKBACK_HOURS"
printf 'branch: %s\n'          "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"

if ! have gh; then
  section "ERROR"
  echo "gh CLI not available — cannot run GitHub discovery. Install gh and re-run."
  exit 0
fi
if ! git remote -v 2>/dev/null | grep -q github; then
  section "ERROR"
  echo "No GitHub remote — discovery skipped."
  exit 0
fi

JQ=0; have jq && JQ=1

# ---------------------------------------------------------------------------
section "1. main branch CI health (is main red?)"
# Latest completed runs on main, regardless of workflow name. Failures here = highest priority.
if [ "$JQ" -eq 1 ]; then
  runs="$(gh run list --branch main --limit 12 \
            --json name,conclusion,status,event,headSha,url,createdAt 2>/dev/null || echo '[]')"
  echo "$runs" | jq -r '
    [ .[] | select(.status=="completed") ] as $done
    | ( [ $done[] | select(.conclusion=="failure" or .conclusion=="timed_out") ] ) as $fail
    | if ($fail|length)>0
      then "STATUS: RED — \($fail|length) failing workflow run(s) on main:\n"
           + ( [ $fail[] | "  - \(.name) [\(.conclusion)] \(.createdAt)\n    \(.url)" ] | join("\n") )
      else "STATUS: GREEN — latest completed main runs are passing."
      end' 2>/dev/null || echo "(could not parse run list)"
else
  echo "(jq not installed — raw run list:)"
  gh run list --branch main --limit 8 2>/dev/null || echo "  (unable to fetch runs)"
fi

# ---------------------------------------------------------------------------
section "2. open bug issues (oldest first)"
if [ "$JQ" -eq 1 ]; then
  gh issue list --label bug --state open --limit 30 \
     --json number,title,labels,createdAt,url 2>/dev/null \
   | jq -r 'map(select(([.labels[].name] | index("epic")) | not))   # drop epic tracking issues
            | sort_by(.createdAt) | .[]
            | "  - #\(.number) \(.title|.[0:120])\n labels: \([.labels[].name]|join(", "))  opened: \(.createdAt)\n    \(.url)"' \
     2>/dev/null || echo "  (none / unable to fetch)"
else
  gh issue list --label bug --state open --limit 25 2>/dev/null || echo "  (unable to fetch)"
fi

# ---------------------------------------------------------------------------
section "3. open PRs needing attention (failing checks / conflicts / stale)"
if [ "$JQ" -eq 1 ]; then
  prs="$(gh pr list --state open --limit 40 \
          --json number,title,isDraft,reviewDecision,mergeable,updatedAt,headRefName,url,statusCheckRollup \
          2>/dev/null || echo '[]')"
  echo "$prs" | jq -r --arg stale "$STALE_BEFORE_ISO" '
    def rollup: ([.statusCheckRollup[]? | .conclusion // .state]) ;
    .[]
    | . as $pr
    | (rollup) as $r
    | ([ $r[] | select(.=="FAILURE" or .=="TIMED_OUT" or .=="ERROR" or .=="CANCELLED") ] | length) as $failing
    | ( ($pr.mergeable=="CONFLICTING") ) as $conflict
    | ( ($stale!="" ) and ($pr.updatedAt < $stale) ) as $stale_flag
    | select($failing>0 or $conflict or $stale_flag)
    | "  - #\($pr.number) \($pr.title|.[0:120])"
      + (if $pr.isDraft then " [draft]" else "" end)
      + "\n branch: \($pr.headRefName)  updated: \($pr.updatedAt)  review: \($pr.reviewDecision // "none")"
      + "\n flags:"
      + (if $failing>0 then " FAILING-CHECKS(\($failing))" else "" end)
      + (if $conflict then " CONFLICTING" else "" end)
      + (if $stale_flag then " STALE" else "" end)
      + "\n    \($pr.url)"' 2>/dev/null || echo "  (none / unable to parse)"
else
  gh pr list --state open --limit 20 2>/dev/null || echo "  (unable to fetch)"
fi

# ---------------------------------------------------------------------------
section "4. recently merged commits on main (recently-introduced-bug hunting)"
# Informational: what landed in the lookback window. Use as candidates for regression hunts.
if [ -n "$SINCE_ISO" ]; then
  git log origin/main --since="$SINCE_ISO" --no-merges -n 20 \
      --pretty='  - %h %s (%an, %cr)' 2>/dev/null \
    || echo "  (no recent commits / origin/main unavailable)"
else
  git log origin/main --no-merges -n 10 --pretty='  - %h %s (%an, %cr)' 2>/dev/null \
    || git log main --no-merges -n 10 --pretty='  - %h %s (%an, %cr)' 2>/dev/null \
    || echo "  (unable to read git log)"
fi

# ---------------------------------------------------------------------------
section "5. discovery complete"
echo "Hand this report to the triage skill for classification (AUTO vs INBOX)."
echo "This script made no changes. All actions are decided by the skill under its autonomy policy."
exit 0
