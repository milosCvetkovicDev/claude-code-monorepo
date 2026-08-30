#!/bin/bash

# Simplify-ignore hook: protects annotated code blocks from simplification/refactoring
# Handles PreToolUse Read (hide blocks), PostToolUse Edit/Write (restore blocks), Stop (crash recovery)

set -e

INPUT=$(cat)

EVENT=$(echo "$INPUT" | jq -r '.event // empty')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

CACHE_DIR=".claude/.simplify-ignore-cache"

# Portable md5: macOS uses md5 -q, Linux uses md5sum
hash_block() {
  local content="$1"
  if command -v md5 &>/dev/null; then
    echo -n "$content" | md5 -q | head -c 8
  else
    echo -n "$content" | md5sum | head -c 8
  fi
}

# Get unique key for backup storage (path hash to avoid basename collisions)
backup_name() {
  local fpath="$1"
  if command -v md5 &>/dev/null; then
    echo -n "$fpath" | md5 -q | head -c 16
  else
    echo -n "$fpath" | md5sum | head -c 16
  fi
}

# Restore BLOCK_ placeholders in a file using backup
restore_blocks() {
  local target_file="$1"
  local backup_file="$2"

  # Extract blocks from backup and store in individual temp files keyed by hash
  local block_dir
  block_dir=$(mktemp -d)

  local in_block=false
  local block_content=""
  local current_hash=""

  while IFS= read -r line || [[ -n "$line" ]]; do
    if echo "$line" | grep -qE '(\/\*|\/\/|#|<!--)[[:space:]]*simplify-ignore-start'; then
      in_block=true
      block_content="$line"
      continue
    fi

    if [[ "$in_block" == true ]] && echo "$line" | grep -qE '(\/\*|\/\/|#|<!--)[[:space:]]*simplify-ignore-end'; then
      block_content="${block_content}
${line}"
      current_hash=$(hash_block "$block_content")
      # Write block to file named by hash
      printf '%s\n' "$block_content" > "$block_dir/$current_hash"
      in_block=false
      block_content=""
      continue
    fi

    if [[ "$in_block" == true ]]; then
      block_content="${block_content}
${line}"
    fi
  done < "$backup_file"

  # Now rebuild target file replacing BLOCK_ placeholders
  local result_file
  result_file=$(mktemp)
  local replaced=false

  while IFS= read -r line || [[ -n "$line" ]]; do
    if echo "$line" | grep -qE 'BLOCK_[0-9a-f]{8}'; then
      # Extract hash from placeholder
      local ph_hash
      ph_hash=$(echo "$line" | sed -E 's/.*BLOCK_([0-9a-f]{8}).*/\1/')
      if [[ -f "$block_dir/$ph_hash" ]]; then
        cat "$block_dir/$ph_hash" >> "$result_file"
        replaced=true
      else
        echo "$line" >> "$result_file"
      fi
    else
      echo "$line" >> "$result_file"
    fi
  done < "$target_file"

  cp "$result_file" "$target_file"
  rm -rf "$result_file" "$block_dir"
}

# === A) PreToolUse Read ===
if [[ "$EVENT" == "PreToolUse" && "$TOOL_NAME" == "Read" ]]; then
  # Skip if no file path or file doesn't exist
  if [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]]; then
    exit 0
  fi

  mkdir -p "$CACHE_DIR"

  BNAME=$(backup_name "$FILE_PATH")

  # Back up original file
  cp "$FILE_PATH" "$CACHE_DIR/${BNAME}.bak"

  # Store original path mapping (persists across PostToolUse for crash recovery)
  echo "$FILE_PATH" > "$CACHE_DIR/${BNAME}.path"

  # Scan for simplify-ignore-start/end pairs and replace with placeholders
  TMPFILE=$(mktemp)
  IN_BLOCK=false
  BLOCK_CONTENT=""
  BLOCK_START_LINE=0
  BLOCK_CATEGORY=""
  BLOCK_REASON=""
  LINE_NUM=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    LINE_NUM=$((LINE_NUM + 1))

    # Check for simplify-ignore-start with all comment styles
    if echo "$line" | grep -qE '(\/\*|\/\/|#|<!--)[[:space:]]*simplify-ignore-start'; then
      IN_BLOCK=true
      BLOCK_CONTENT="$line"
      BLOCK_START_LINE=$LINE_NUM

      # Extract category and reason if present
      if echo "$line" | grep -qE 'simplify-ignore-start[[:space:]]*:'; then
        BLOCK_CATEGORY=$(echo "$line" | sed -E 's/.*simplify-ignore-start[[:space:]]*:[[:space:]]*([a-z-]+).*/\1/')
        BLOCK_REASON=$(echo "$line" | sed -E 's/.*simplify-ignore-start[[:space:]]*:[[:space:]]*[a-z-]+[[:space:]]*[—–-]+[[:space:]]*//')
        # Clean up trailing comment markers
        BLOCK_REASON=$(echo "$BLOCK_REASON" | sed -E 's/[[:space:]]*(\*\/|-->)[[:space:]]*$//')
      else
        # Bare annotation - no reason
        BLOCK_CATEGORY=""
        BLOCK_REASON=""
        echo "Warning: simplify-ignore block missing reason in ${FILE_PATH}:${LINE_NUM}" >&2
      fi
      continue
    fi

    # Check for simplify-ignore-end
    if [[ "$IN_BLOCK" == true ]] && echo "$line" | grep -qE '(\/\*|\/\/|#|<!--)[[:space:]]*simplify-ignore-end'; then
      BLOCK_CONTENT="${BLOCK_CONTENT}
${line}"

      # Generate deterministic hash from block content
      HASH=$(hash_block "$BLOCK_CONTENT")

      # Build placeholder
      if [[ -n "$BLOCK_CATEGORY" && -n "$BLOCK_REASON" ]]; then
        PLACEHOLDER="/* BLOCK_${HASH} -- protected (${BLOCK_CATEGORY}: ${BLOCK_REASON}) */"
      elif [[ -n "$BLOCK_CATEGORY" ]]; then
        PLACEHOLDER="/* BLOCK_${HASH} -- protected (${BLOCK_CATEGORY}) */"
      else
        PLACEHOLDER="/* BLOCK_${HASH} -- protected */"
      fi

      echo "$PLACEHOLDER" >> "$TMPFILE"
      IN_BLOCK=false
      BLOCK_CONTENT=""
      continue
    fi

    if [[ "$IN_BLOCK" == true ]]; then
      BLOCK_CONTENT="${BLOCK_CONTENT}
${line}"
    else
      echo "$line" >> "$TMPFILE"
    fi
  done < "$FILE_PATH"

  # Write modified file back
  cp "$TMPFILE" "$FILE_PATH"
  rm -f "$TMPFILE"

  exit 0
fi

# === B) PostToolUse Edit/Write ===
if [[ "$EVENT" == "PostToolUse" && ( "$TOOL_NAME" == "Edit" || "$TOOL_NAME" == "Write" ) ]]; then
  if [[ -z "$FILE_PATH" ]]; then
    exit 0
  fi

  BNAME=$(backup_name "$FILE_PATH")
  BACKUP="$CACHE_DIR/${BNAME}.bak"

  # Check if backup exists
  if [[ ! -f "$BACKUP" ]]; then
    exit 0
  fi

  # Check if the current file contains BLOCK_ placeholders
  if ! grep -q 'BLOCK_' "$FILE_PATH" 2>/dev/null; then
    rm -f "$BACKUP"
    exit 0
  fi

  # Restore blocks from backup
  restore_blocks "$FILE_PATH" "$BACKUP"

  # Clean up backup file (keep .path for crash recovery)
  rm -f "$BACKUP"

  exit 0
fi

# === C) Stop event ===
if [[ "$EVENT" == "Stop" ]]; then
  # Check if cache directory exists
  if [[ ! -d "$CACHE_DIR" ]]; then
    exit 0
  fi

  # Iterate all .bak files in cache
  for bakfile in "$CACHE_DIR"/*.bak; do
    [[ -f "$bakfile" ]] || continue

    BNAME=$(basename "$bakfile" .bak)
    PATHFILE="$CACHE_DIR/${BNAME}.path"

    # Get original file path from .path mapping
    if [[ -f "$PATHFILE" ]]; then
      ORIGINAL_PATH=$(cat "$PATHFILE")
    else
      continue
    fi

    # Check if source file contains BLOCK_ placeholders
    if [[ -f "$ORIGINAL_PATH" ]] && grep -q 'BLOCK_' "$ORIGINAL_PATH" 2>/dev/null; then
      # Restore from backup
      cp "$bakfile" "$ORIGINAL_PATH"
    fi

    # Clean up
    rm -f "$bakfile" "$PATHFILE"
  done

  # Clean up any remaining .path files
  rm -f "$CACHE_DIR"/*.path 2>/dev/null

  # Remove cache directory if empty
  rmdir "$CACHE_DIR" 2>/dev/null || true

  exit 0
fi

# Unknown event - pass through
exit 0
