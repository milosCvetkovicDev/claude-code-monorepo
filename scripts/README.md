# scripts/ — the gates

The book makes claims about the tree it describes. These make those claims checkable, and
[`.github/workflows/book-guard.yml`](../.github/workflows/book-guard.yml) runs them on
every push and pull request with **no path filter** — a guard that only runs on predicted
paths is absent exactly when something unpredicted happens.

Run any of them locally; each needs only Python 3 (mermaid additionally needs `mmdc`):

```bash
python3 scripts/check-links.py     # cross-references resolve
python3 scripts/check-counts.py    # every number in the prose matches the tree
python3 scripts/check-leaks.py     # canary-proven sanitization sweep
python3 scripts/check-mermaid.py   # every diagram renders (real parser)
```

| Script | Proves | Paid for by |
| ------ | ------ | ----------- |
| [`check-links.py`](check-links.py) | Every relative link in authored content resolves. The frozen `project/`+`global/` trees are excluded: their dangling original-path links are documented authenticity, not rot. | The book restructure, where three links broke silently in one commit. |
| [`check-counts.py`](check-counts.py) | 70 claimed numbers — skills, hooks, agents, memories, chapters, diagrams — still match the filesystem. Prose stays natural English; a pattern that matches *nothing* also fails, because a silently-reworded claim is drift too. | The in-repo quick-references that predate the book and still say "~50 skills" and "15 active agents". |
| [`check-leaks.py`](check-leaks.py) | Class-level sanitization rules, each proven **in both directions** on [`leak-canaries/`](leak-canaries/) before it is allowed to report. | [`SANITIZATION.md`](../SANITIZATION.md) stage 5 — three rules with silent false negatives, and the finding that a sweep which cries wolf gets muted. |
| [`check-mermaid.py`](check-mermaid.py) | All 249 mermaid blocks render through the real parser. | Stage 4 — a hand-written structural validator passed four diagrams that GitHub shows as red error boxes. |

## Two design rules worth stealing

**A gate must be seen to fail.** Each of these was mutation-tested before it was trusted:
change a number in the prose, add a skill directory, break a link, plant a
correctly-shaped fake identifier, put a semicolon inside a mermaid `Note` — each mutation
was confirmed to turn the gate red, and the tree confirmed green afterwards. A gate that
has only ever passed is a gate with no evidence behind it.

**The rules never name the thing they protect.** `check-leaks.py` contains no employer
name, hostname or credential — only shapes. Stage 5's hardest lesson was that the
*document describing removals* reintroduced three identifiers by quoting them. Describe
the class; never the token.

## The allowlist is a debt register

[`leak-allowlist.json`](leak-allowlist.json) holds reviewed exceptions — teaching
examples that deliberately contain a bad shape (a checklist showing a hardcoded key, the
path rule quoting the form it forbids). Each entry carries a reason. A **stale** entry —
one that no longer matches anything — fails the sweep, so the register shrinks on its own
rather than quietly widening to excuse something new.
