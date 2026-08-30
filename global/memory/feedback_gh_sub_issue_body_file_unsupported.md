---
name: feedback-gh-sub-issue-body-file-unsupported
description: '`gh sub-issue create` does NOT support `--body-file` flag (unlike `gh issue create`). Use `--body "$content"` with shell-read file content instead. Discovered 2026-05-20 during /pm:epic-sync ci-arc-parallelisation.'
metadata:
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000008
---

The `gh sub-issue` extension (`yahsan2/gh-sub-issue`, v0.5.1) has a more limited flag surface than upstream `gh issue create`. Most notably: **no `--body-file` flag.** Attempting to use it fails silently — the command appears to invoke but returns "unknown flag: --body-file" on stderr and the issue is never created.

**Why:** the failure pattern in PR sync scripts is particularly nasty because `gh sub-issue create --parent ... --title "..." --body-file /tmp/x.md` produces no stdout (no URL), so a loop pattern like:

```bash
ISSUE_URL=$(gh sub-issue create --parent "$EPIC" --title "$name" --body-file /tmp/body.md)
ISSUE_NUM=$(echo "$ISSUE_URL" | grep -oE '[0-9]+$' | tail -1)
```

silently produces empty `ISSUE_NUM` for every loop iteration. You only notice when the post-loop validation prints "→ #" with no number.

**How to apply:**

Read the body into a shell variable and pass via `--body`:

```bash
for task_file in .claude/epics/EPIC/00{1..9}.md .claude/epics/EPIC/010.md; do
  task_name=$(grep '^name:' "$task_file" | head -1 | sed 's/^name: *//')
  body=$(sed '1,/^---$/d; 1,/^---$/d' "$task_file")
  ISSUE_URL=$(gh sub-issue create \
    --parent "$EPIC_NUMBER" \
    --title "$task_name" \
    --body "$body" \
    --label "task" \
    --label "epic:EPIC")
done
```

`--body "$body"` accepts arbitrarily-long content from the shell variable. The standard caveat: shell variable assignment via `$(...)` strips trailing newlines, which is fine for issue bodies but be aware if the task file has trailing whitespace that matters.

Tested + working in PR #858 sync (commit `194b0a88` / `8752f375`): 10 sub-issues created cleanly under epic #835 with parent-linking.

## Update 2026-06-25 (epic-sync platform-api-prefix-contract #1430) — bulk creation hangs

Even with the `--body "$content"` fix above, `gh sub-issue create` proved **unreliable for bulk creation**. Its parent-link step is a slow GitHub hierarchy GraphQL mutation, and a tight `for` loop creating 7 sub-issues back-to-back tripped GitHub's **secondary (abuse) rate limit** — `gh` then retries with long backoff and the call HANGS (consumed the full 2-min Bash-tool timeout, creating nothing). Primary rate limit was untouched (`gh api rate_limit` core = 4999/5000), so it's the secondary/burst limit, not quota.

**Robust pattern that worked:** skip `gh sub-issue` entirely; use plain `gh issue create` (supports `--body-file`, fast single API call) **one issue per Bash call** (spacing comes from separate tool calls / model think-time between them — a tight loop in ONE call still trips the burst limit). Group them via the `epic:<name>` label + a `## Tasks` checklist appended to the epic body (`gh issue edit <epic> --body-file`). This is the CCPM "fallback mode" and is more reliable than native sub-issue hierarchy.

Also: **macOS zsh has no `timeout` command** (`command not found: timeout`) — don't wrap gh in `timeout 50 ...`; use the Bash tool's own `timeout` parameter to bound a possibly-hanging call. And always **verify GitHub state (`gh issue list`) between retries** — a hung create may or may not have created the issue; here it created none, but check to avoid duplicates.
