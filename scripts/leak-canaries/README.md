# Leak canaries

Synthetic samples, one per rule in [`../check-leaks.py`](../check-leaks.py). Every value here is
**invented** — a shape, not a secret. Nothing in this directory ever existed in a real system.

They exist because of SANITIZATION.md's stage-5 lesson: *"A clean report from an untested tool is
not evidence."* Three rules in the original sweep had silent false negatives and reported clean for
weeks. So before the sweep is allowed to look at the repository, each rule is run against its own
canary and must flag it. A rule that cannot fail does not get to pass.

This directory is excluded from the sweep itself — obviously, or it would report itself forever.

**Adding a rule?** Add its canary in the same commit, and confirm the self-test fails when you
temporarily break the rule. A canary that was never seen to fire proves nothing either.
