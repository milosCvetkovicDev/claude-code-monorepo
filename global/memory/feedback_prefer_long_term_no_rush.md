---
name: feedback_prefer_long_term_no_rush
description: "User mandate — always choose long-term, best-practice solutions; never rush or ship expedient shortcuts"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000006
---

On the Platform finance epic the user said (CRITICAL): "focus only on long term solutions and best practices we don't want to rush."

**Why:** this is production financial software, where a broken feature is not a cosmetic defect. Expedient shortcuts (client-only enforcement of security-sensitive scoping, fragile response-shape assumptions, silent caps, "ship-with-a-comment" gaps) accrue risk and tech debt. The user values a correct, durable result over speed.

**How to apply:**

- Prefer the robust implementation over the convenient one: defensive parsing of API response shapes (don't assume single vs double envelope), real pagination over "first N", server-authoritative enforcement for anything security/privacy-sensitive (never rely on client-side scoping as the boundary).
- Turn every documented gap/limitation into a TRACKED follow-up issue (like [[platform-finance-ui-epic]] #1491/#1472), not just an inline code comment. A code comment is not a plan.
- Do not skip the maker≠checker review or its fixes to move faster; the review IS the not-rushing discipline.
- When a contract diverges (e.g. consumer pact vs implemented backend), build to what works AND file a reconciliation issue — don't silently ship a half-met AC.
- It's fine to take more turns/tokens to get it right. Surface conflicts and let the user decide rather than guessing to save a round-trip.

Applies across the whole [[platform-finance-ui-epic]] and future Platform work.
