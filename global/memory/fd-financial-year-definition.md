---
name: fd-financial-year-definition
description: '"Financial year" is a domain constant, not a calendar given — confirm the boundary and encode it in ONE helper both frontend and backend import'
type: feedback
---

Never assume "financial year" means the calendar year, the tax year, or anything else. It is a
per-organisation constant, it is frequently **not** January–December, and every report that slices
by it is wrong in a way that looks like a rounding bug until someone checks a boundary month.

**Why:** a stakeholder saying "last financial year" and an engineer reading "last year" agree on
the words and disagree on ten months of data. The disagreement surfaces as a reconciliation
mismatch, weeks later, in a period nobody was looking at.

**How to apply:** confirm the boundary explicitly, in writing, with a worked example
("FY 2024/25 = <start> to <end> — correct?"). Then encode it in exactly **one** helper
(`getFinancialYearStart()`), imported by both the frontend period helpers and the backend
queries. Two independent definitions of the boundary is the same bug with two places to fix.
See [[finance-stakeholder-communication]].
