# Ideation Frameworks

4 structured frameworks for brainstorming and problem-solving. Choose based on the situation.

## When to Use Which

| Situation | Recommended Framework |
| -------------------------------- | ---------------------- |
| Improving an existing feature | SCAMPER                |
| Designing something from scratch | First Principles |
| User-facing feature design | Jobs to Be Done (JTBD) |
| Reframing a problem | How Might We (HMW)     |

## 1. SCAMPER

Best for: Improving existing features, finding enhancement opportunities.

### Steps

| Letter | Action | Prompt |
| ------ | ---------------- | ------------------------------------------------------- |
| **S**  | Substitute | What components, inputs, or processes could we replace? |
| **C**  | Combine | What features or data could we merge for more value?    |
| **A**  | Adapt | What existing patterns from elsewhere could we borrow?  |
| **M**  | Modify | What could we enlarge, shrink, or change the format of? |
| **P**  | Put to other use | Could this feature serve a different user or workflow?  |
| **E**  | Eliminate | What complexity, steps, or fields can we remove?        |
| **R**  | Reverse | What if we reversed the order, flow, or responsibility? |

### Example: A periodic report screen

- **S**: Substitute the manual spreadsheet export with a live dashboard
- **C**: Combine the report with the drill-down view users always open straight after it
- **A**: Adapt the period-closing pattern already used elsewhere in the system
- **M**: Modify it to show a running cumulative alongside the per-period figure
- **P**: Put the same aggregate to use in a second, read-only surface
- **E**: Eliminate the manual "close the period" step — close on a schedule instead
- **R**: Reverse the flow — push the finished report to its readers instead of making them pull it

## 2. First Principles

Best for: Novel architecture, system design, when existing patterns don't fit.

### Steps

1. **Identify the problem** — What exactly are we trying to solve?
2. **List assumptions** — What are we taking for granted?
3. **Challenge each assumption** — Is this actually true? What if it weren't?
4. **Break down to fundamentals** — What are the irreducible components?
5. **Rebuild from ground up** — Given only the fundamentals, what's the simplest solution?

### Example: Platform Migration

1. **Problem**: Legacy Express monolith can't scale; need bounded contexts
2. **Assumptions**: "We need to migrate everything at once", "Same database schema"
3. **Challenge**: Can we run both simultaneously? Can domains own their schemas?
4. **Fundamentals**: Each domain needs: data ownership, API contract, independent deploy
5. **Rebuild**: NestJS modules per bounded context, strangler fig pattern, shared event bus

## 3. Jobs to Be Done (JTBD)

Best for: User-facing features where understanding motivation matters.

### Format

> **When** [situation/trigger],
> **I want to** [motivation/action],
> **so I can** [expected outcome/benefit].

### Steps

1. **Identify the job** — What is the user actually trying to accomplish?
2. **Map the process** — What steps do they take today?
3. **Find friction** — Where do they struggle, wait, or work around?
4. **Design for the job** — Solve the friction, not just add features

### Example: Creating a record from an inbound request

> **When** an inbound request arrives,
> **I want to** create the record with its derived fields already filled in,
> **so I can** answer while the request is still current.

Friction: the current flow takes eight clicks and one hand-computed figure.
Design: a pre-filled template whose derived fields are computed from comparable recent records.

## 4. How Might We (HMW)

Best for: Reframing problems into opportunities, generating divergent ideas.

### Format

> **How might we** [verb] [user/stakeholder] [need/desire] [insight/constraint]?

### Rules

- Broad enough to allow multiple solutions
- Narrow enough to be actionable
- Never contains the solution in the question
- Always starts with "How might we"

### Steps

1. **Start with a problem statement** — "Users can't see the result of their work until the period closes"
2. **Reframe as HMW** — "How might we give users visibility into that result throughout the period?"
3. **Generate 5+ ideas** — Quantity over quality at this stage
4. **Group and prioritize** — Cluster similar ideas, vote on impact vs. effort

### Example: An outbound integration

- Problem: "Posting to the external system fails silently and nobody notices for days"
- HMW: "How might we make posting failures immediately visible to the team that owns them?"
- Ideas:
  1. Real-time chat notification on failure
  2. Dashboard showing posting status per record
  3. Daily digest of records that never posted
  4. Auto-retry with escalation after 3 failures
  5. Integration health check in the launch-readiness gate
