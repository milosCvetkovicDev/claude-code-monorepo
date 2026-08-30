---
name: platform-spec-inconsistencies
description: Inconsistencies found between pages of the CTO docs site — flagged for resolution during architecture planning
type: reference
---

## Spec Inconsistencies (2026-03-24)

Found during DDD context mapping. Full list in `docs/platform/context-mapping/bounded-context-map.md` Appendix B.

Eight disagreements between the shared `data-model.md` page and the individual service pages, in four
shapes: the same entity given a different column set on each page; the same concept spelled under two
different names; a status enum carrying more values on one page than the other; and a service still
referenced as a consumer after it had been merged into another. Most resolve locally on a rule of
thumb — prefer the stronger type, the more complete enum, and the owning service's page for an entity
only it owns. The two that did not were genuine domain questions (what a period is keyed by, and who
may perform a privileged state change) and were escalated rather than guessed; those rules are
business policy and are not part of this export.

**Why:** The spec was written across multiple pages over weeks. Internal inconsistencies are normal but need resolution before implementation.

**How to apply:** When implementing an entity, always check BOTH `data-model.md` AND the owning service's page. If they disagree, flag it — don't assume either is correct.
