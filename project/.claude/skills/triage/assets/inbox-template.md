# 🔁 Triage inbox

<!--
  This is the loop's memory between runs — "the agent forgets, the repo doesn't."
  The triage skill OVERWRITES this file each run from this template. Copy this structure exactly.
  Location: .claude/triage/inbox.md (git-ignored). Keep entries newest-run-first.
  A finding stays here until a human (or a follow-up run) resolves it; carry unresolved
  findings forward into the next run so nothing is silently dropped.
-->

run_utc: <ISO-8601, e.g. 2026-06-20T07:03:00Z>
branch_scanned: main
mode: <read-only | auto-pr>
summary: <N findings — X auto-PR'd, Y in inbox, Z carried over>

---

## ⛔ Needs you (INBOX)

> Findings the loop will not touch: hard-NO paths, business logic, anything the checker
> rejected, or anything over the per-run budget. Ranked highest-impact first.

### 1. <short title>

- **Source**: <main-red | bug-issue #N | PR #N | regression-hunt>
- **Signal**: <the failing check / error / failing test that proves it>
- **Why INBOX**: <hard-NO path | checker rejected (reason) | business logic | budget>
- **Recommended action**: <the specific next step a human should take>
- **Link**: <url>

---

## 🤖 Loop handled (AUTO)

> Findings the loop drafted + a separate checker verified + opened as a PR. Nothing merged.

### 1. <short title>

- **Source**: <…> • **Category**: <lint | deps | docs | flaky-quarantine | one-liner>
- **Maker**: <one line — what changed, files touched>
- **Checker verdict**: <PASS | PASS-with-notes> — <checker agent, one-line reasoning>
- **PR**: <#N url, draft? y/n, label: triage-loop>

---

## 🔭 Carried over

> Unresolved INBOX findings from previous runs, with first-seen date. Escalate stale ones.

- [ ] <title> — first seen <date> — <link>
