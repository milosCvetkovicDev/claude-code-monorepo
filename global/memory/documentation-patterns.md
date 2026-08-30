# Documentation Patterns

## Decision Log
- One log per bounded context, at `docs/<context>/domain/decision-log.md`
- Format: Date, Status, Context, Options, Decision, Rationale, Source, Impact
- Status badges: Decided, Pending, Superseded
- **Always read the existing log before assuming an ID is free** — IDs are allocated
  sequentially by hand and two parallel sessions will otherwise collide on the same one
- A superseded decision is marked, never deleted: the reversal and its reason are the
  most useful thing in the log a year later

## Context Docs Structure
```
docs/<context>/
  CLAUDE.md              # Status + links (the entry point Claude reads)
  architecture/
    overview.md          # High-level + a table linking every major doc
    <topic>.md           # One per significant technical decision or migration
  domain/
    decision-log.md
```

## Cross-Reference Convention
- Docs link to each other via relative paths, never absolute
- Everything references the decision log via `../domain/decision-log.md`
- `overview.md` carries the index table; `CLAUDE.md` links only the major docs
- **Why it matters:** the index is what stops a doc set becoming a pile of orphans —
  a doc nothing links to is a doc nobody reads and nobody updates

## When Adding New Docs
1. Create it in `docs/<context>/architecture/`
2. Add a link in `overview.md`'s index table
3. Add a link in `CLAUDE.md` if it is a major doc
4. Update the decision log if it records a new decision

## Code Review as Quality Gate
- Running a code reviewer after implementation catches real issues and is worth the couple
  of minutes it costs
- A full parallel multi-expert review reliably surfaces findings across severity bands in
  a few minutes — the cost is low enough that skipping it is rarely the right call
