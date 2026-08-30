# site/ — the online edition

The book, rendered as a website: <https://miloscvetkovicdev.github.io/claude-code-monorepo/>

Built by [`.github/workflows/pages.yml`](../.github/workflows/pages.yml) on every push that
touches published content. Nothing here changes how the repository reads on GitHub — the
site is a second surface over the same files, not a replacement for them.

## The constraint that shapes this directory

mkdocs wants one `docs_dir` containing every page. This repository cannot offer one:
`book/` and `docs/architecture/` sit where they sit because the config trees are frozen at
their original monorepo paths, and because reading on GitHub has to keep working for
someone who never visits the site.

So nothing moves. [`build.py`](build.py) **stages** the two volumes into a scratch
directory and rewrites the links that would dangle there:

| Link in the repo | On the site |
| ---------------- | ----------- |
| `../project/.claude/skills/` | an absolute `github.com` URL — the config trees are not published here |
| `../docs/architecture/00-system-context.md` | `../architecture/00-system-context.md` |
| `SANITIZATION.md` | `sanitization.md` |
| a directory link | that directory's `README.md`, or GitHub if it has none |

Those links into the frozen trees are half the point of the book — every chapter ends at
its primary source — so they are redirected rather than dropped. The reader stays one
click from the real file either way.

`build.py --check` fails if any link still dangles inside the staged site, and the
workflow runs it in that mode.

## Diagrams are self-hosted, pinned, and checksum-verified

mkdocs-material's own mermaid integration fetches the library from unpkg at a **floating**
major version and runs it in every reader's browser. This repository's CI/CD guardrails say
to pin supply-chain links by version and checksum, and shipping a floating CDN dependency
inside the page that argues for pinning would be a poor advertisement for the rule.

So the fences are emitted with the class `diagram` — which Material does not claim — and
rendered by [`mermaid-init.js`](mermaid-init.js) using a build that `build.py` vendors at a
pinned version and verifies by SHA-256. A mismatch is fatal.

One thing worth recording because it was established by experiment rather than assumption:
**a preloaded `window.mermaid` does not make Material stand down.** It empties the element
and renders with its own fetched copy, so when that fetch fails you get a blank box rather
than a fallback. Hence the different class, rather than trying to win a race.

The result: the published site makes **no third-party request** to draw its diagrams —
verified with a headless browser that recorded zero failed external requests.

## Running it locally

```bash
pip install mkdocs-material==9.7.7
python3 site/build.py --check     # stage + verify links
cd site && mkdocs serve           # http://127.0.0.1:8000
```

`site/_build/` and `site/_vendor/` are generated and git-ignored.
