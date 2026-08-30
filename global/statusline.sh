#!/bin/bash
# ============================================================================
#  Claude Code Status Line — Catppuccin Macchiato Theme
#  Matches iTerm2/tmux color scheme
# ============================================================================

input=$(cat)

# ── Extract Data ─────────────────────────────────────────────────────────────
MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
LINES_ADDED=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
LINES_REMOVED=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
VERSION=$(echo "$input" | jq -r '.version // ""')
OUTPUT_STYLE=$(echo "$input" | jq -r '.output_style.name // ""')

# ── Catppuccin Macchiato Colors (256-color approximations) ───────────────────
# Using true 24-bit color since your tmux config enables it
ROSEWATER='\033[38;2;244;219;214m'
FLAMINGO='\033[38;2;240;198;198m'
PINK='\033[38;2;245;189;230m'
MAUVE='\033[38;2;198;160;246m'
RED='\033[38;2;237;135;150m'
MAROON='\033[38;2;238;153;160m'
PEACH='\033[38;2;245;169;127m'
YELLOW='\033[38;2;238;212;159m'
GREEN='\033[38;2;166;218;149m'
TEAL='\033[38;2;139;213;202m'
SKY='\033[38;2;145;215;227m'
SAPPHIRE='\033[38;2;125;196;228m'
BLUE='\033[38;2;138;173;244m'
LAVENDER='\033[38;2;183;189;248m'
SUBTEXT0='\033[38;2;165;173;203m'
OVERLAY0='\033[38;2;110;115;141m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Context Bar (color changes with usage) ───────────────────────────────────
if [ "$PCT" -ge 90 ]; then
    BAR_COLOR="$RED"
    BAR_ICON=""
elif [ "$PCT" -ge 70 ]; then
    BAR_COLOR="$PEACH"
    BAR_ICON=""
elif [ "$PCT" -ge 50 ]; then
    BAR_COLOR="$YELLOW"
    BAR_ICON=""
else
    BAR_COLOR="$GREEN"
    BAR_ICON=""
fi

BAR_WIDTH=15
FILLED=$((PCT * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))
BAR=""
[ "$FILLED" -gt 0 ] && BAR=$(printf "%${FILLED}s" | tr ' ' '━')
[ "$EMPTY" -gt 0 ] && BAR="${BAR}$(printf "%${EMPTY}s" | tr ' ' '╌')"

# ── Duration ─────────────────────────────────────────────────────────────────
MINS=$((DURATION_MS / 60000))
SECS=$(((DURATION_MS % 60000) / 1000))

# ── Cost ─────────────────────────────────────────────────────────────────────
COST_FMT=$(printf '%.2f' "$COST")

# ── Git Info (cached for performance) ────────────────────────────────────────
CACHE_FILE="/tmp/claude-statusline-git-cache"
CACHE_MAX_AGE=5

cache_is_stale() {
    [ ! -f "$CACHE_FILE" ] || \
    [ $(($(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0))) -gt $CACHE_MAX_AGE ]
}

BRANCH=""
GIT_STATUS=""
if cache_is_stale; then
    if git rev-parse --git-dir > /dev/null 2>&1; then
        BRANCH=$(git branch --show-current 2>/dev/null)
        STAGED=$(git diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
        MODIFIED=$(git diff --numstat 2>/dev/null | wc -l | tr -d ' ')
        UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
        echo "$BRANCH|$STAGED|$MODIFIED|$UNTRACKED" > "$CACHE_FILE"
    else
        echo "|||" > "$CACHE_FILE"
    fi
fi
IFS='|' read -r BRANCH STAGED MODIFIED UNTRACKED < "$CACHE_FILE"

if [ -n "$BRANCH" ]; then
    GIT_PARTS=""
    [ "$STAGED" -gt 0 ] && GIT_PARTS="${GREEN}+${STAGED}${RESET}"
    [ "$MODIFIED" -gt 0 ] && GIT_PARTS="${GIT_PARTS} ${PEACH}~${MODIFIED}${RESET}"
    [ "$UNTRACKED" -gt 0 ] && GIT_PARTS="${GIT_PARTS} ${OVERLAY0}?${UNTRACKED}${RESET}"
    GIT_STATUS=" ${OVERLAY0}│${RESET} ${MAUVE} ${BRANCH}${RESET} ${GIT_PARTS}"
fi

# ── Lines Changed ────────────────────────────────────────────────────────────
LINES_INFO=""
if [ "$LINES_ADDED" -gt 0 ] || [ "$LINES_REMOVED" -gt 0 ]; then
    LINES_INFO=" ${OVERLAY0}│${RESET} ${GREEN}+${LINES_ADDED}${RESET} ${RED}-${LINES_REMOVED}${RESET}"
fi

# ── Model Badge ──────────────────────────────────────────────────────────────
case "$MODEL" in
    *Opus*|*opus*)   MODEL_COLOR="$MAUVE"; MODEL_ICON="" ;;
    *Sonnet*|*sonnet*) MODEL_COLOR="$BLUE"; MODEL_ICON="" ;;
    *Haiku*|*haiku*) MODEL_COLOR="$TEAL"; MODEL_ICON="" ;;
    *)               MODEL_COLOR="$LAVENDER"; MODEL_ICON="" ;;
esac

# ── Line 1: Model + Directory + Git ─────────────────────────────────────────
printf '%b' "${MODEL_COLOR}${BOLD}${MODEL_ICON} ${MODEL}${RESET} ${OVERLAY0}│${RESET} ${SKY} ${DIR##*/}${RESET}${GIT_STATUS}${LINES_INFO}\n"

# ── Line 2: Context Bar + Cost + Duration ────────────────────────────────────
printf '%b' "${BAR_COLOR}${BAR_ICON} ${BAR}${RESET} ${SUBTEXT0}${PCT}%${RESET} ${OVERLAY0}│${RESET} ${YELLOW} \$${COST_FMT}${RESET} ${OVERLAY0}│${RESET} ${FLAMINGO} ${MINS}m ${SECS}s${RESET}\n"
