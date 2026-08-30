---
name: user-finance-stakeholder
description: Working with a domain owner in a money domain — a "this number is wrong" report is a rule question before it is a bug report
type: user
---

In a money domain the rules the software implements are owned by someone who is not an engineer, and
their reports are domain truth rather than bug reports.

**How to apply:** when the domain owner says a number is wrong, treat it as a **domain-rule question
first and a code defect second** — the usual cause is that the implemented rule and the intended rule
differ, not that the code fails to do what it says. Get the rule pinned down with a worked example
before writing a fix; see [[finance-stakeholder-communication]].
