# Review Triage Pipeline

Structured process for running information-isolated code reviews and classifying findings into actionable buckets.

## Review Layers

Three layers run IN PARALLEL during `/pm:epic-review`:

### Layer 1: Blind Adversarial Review
- **Agent**: `adversarial-reviewer`
- **Input**: Diff text ONLY (no project files, no architecture, no spec)
- **Rule**: MUST find ≥10 issues. Zero findings → re-analyze.
- **Purpose**: Catch issues that context-aware reviewers rationalize away
- **Output**: Markdown bulleted list with severity tags

### Layer 2: Context-Aware Edge Case Analysis
- **Agent**: `edge-case-hunter`
- **Input**: Changed file list + full project read access
- **Purpose**: Mechanically trace every branching path for missing guards
- **Output**: JSON array of edge case findings

### Layer 3: Existing Review Agents (unchanged)
- **Agents**: `code-analyzer` + `code-reviewer`
- **Input**: Full diff + project access
- **Output**: Bug Hunt Summary + Code Quality Review

### Why Information Isolation Matters
Layer 1 sees ONLY the diff. It cannot rationalize "that's fine because the architecture says..." — it judges code purely on what it sees. This catches issues context-aware reviewers miss.

## Triage Pipeline

After all layers complete:

### Step 1: Normalize
Convert all findings to common format:
```markdown
| ID | Source | Severity | Location | Description |
|----|--------|----------|----------|-------------|
| 1 | blind | HIGH | auth.ts:42 | Missing null check |
| 2 | edge | — | auth.ts:45 | Unguarded expired token path |
| 3 | analyzer | CRITICAL | db.ts:89 | SQL injection risk |
```

### Step 2: Deduplicate
Merge findings from different layers pointing to same file:line with same root issue:
- Keep most specific description as base
- Combine sources: `blind+edge`
- Prefer higher severity when agents disagree
- Multi-layer findings get higher confidence

### Step 3: Classify
Each unique finding → exactly ONE bucket:

| Bucket | Criteria | Example |
|--------|----------|---------|
| `patch` | Unambiguous fix, clear resolution | "Missing null check on line 42" |
| `decision_needed` | Ambiguous, multiple valid approaches | "Soft-delete vs hard-delete" |
| `defer` | Pre-existing issue, not from this change | "Legacy function has no error handling" |
| `dismiss` | Noise, false positive, handled elsewhere | "Missing logging" (in middleware) |

**Rules:**
- Code existing BEFORE diff and unmodified → `defer`
- Single obvious fix → `patch`
- 2+ valid approaches → `decision_needed`
- Handled by another layer (middleware, parent function) → `dismiss`
- When in doubt between `patch` and `decision_needed` → `decision_needed`

### Step 4: Present
Group by bucket:

```
Triage: {P} patches, {D} decisions, {W} deferred, {X} dismissed

DECISIONS NEEDED (resolve first):
#1 [blind+edge] file.ts:89 — {issue} → Choose: [A] / [B] / [D]efer

PATCHES (apply automatically?):
#3 file.ts:23 — {fix description}
#4 file.ts:112 — {fix description}
→ Apply all? [Y/n/select]

DEFERRED ({count}) — [D to expand]
DISMISSED ({count}) — [X to expand]
```

## Enhanced Review Report

Additional frontmatter fields:
```yaml
triage_complete: true
patches: 4
decisions_pending: 2
deferred: 8
dismissed: 4
```

Additional sections: Triage Summary, Findings by Bucket (Patches, Decisions Needed, Deferred, Dismissed).

## Batch Operations

**Apply Patches**: Agent applies fixes, commits with "Review fix: {description}".
**Resolve Decisions**: Present context and options, user chooses, reclassify as `patch` or `defer`.
**Create Follow-Up Issues**: Offer to create GitHub issues for deferred findings.
