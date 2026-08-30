#!/usr/bin/env python3
"""Link gate — every relative link in AUTHORED content must resolve on disk.

Scope note, and it is the whole design of this script: only content written FOR this
export is swept. `project/` and `global/` are frozen at their original monorepo paths,
and they contain links that deliberately do not resolve here — `../../projects/...`,
`docs/platform/...`, `docs/runbooks/...`. SANITIZATION.md ("Deliberate retentions")
records that as a choice: faking those links would misrepresent what the real files
said. Sweeping them would turn documented authenticity into a permanently red gate,
and a gate that is always red is a gate nobody reads.

Anchors (`#section`) are not checked — only that the target FILE exists.

Exit 0 clean, 1 with a per-link report.
"""

import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Authored for this export → swept. Everything else is frozen or generated.
SWEPT_DIRS = ("book", "docs", "examples", "scripts", ".github", "site")
SWEPT_ROOT_FILES = ("README.md", "SANITIZATION.md", "NOTICE", "LICENSE")

# Generated, not authored. site/_build holds a STAGED copy of the book whose links have
# been deliberately rewritten for the website; sweeping it would double-count every link
# and check the output of the rewriter against the wrong rules.
SKIP_DIRS = {"_build", "_vendor", "node_modules", "leak-canaries"}

LINK_RE = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)", re.S)
SKIP_PREFIXES = ("http://", "https://", "mailto:", "#", "tel:")


def markdown_files():
    for d in SWEPT_DIRS:
        root_dir = os.path.join(REPO, d)
        if not os.path.isdir(root_dir):
            continue
        for root, dirs, files in os.walk(root_dir):
            dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
            for f in files:
                if f.endswith(".md"):
                    yield os.path.join(root, f)
    for f in SWEPT_ROOT_FILES:
        p = os.path.join(REPO, f)
        if os.path.isfile(p) and f.endswith(".md"):
            yield p


def main():
    broken = []
    checked = 0
    files = sorted(markdown_files())

    for path in files:
        base = os.path.dirname(path)
        with open(path, encoding="utf-8") as fh:
            content = fh.read()
        for m in LINK_RE.finditer(content):
            href = m.group(1)
            if href.startswith(SKIP_PREFIXES):
                continue
            target = href.split("#")[0]
            if not target:
                continue  # pure anchor
            checked += 1
            resolved = os.path.normpath(os.path.join(base, target))
            if not os.path.exists(resolved):
                line = content[: m.start()].count("\n") + 1
                broken.append((os.path.relpath(path, REPO), line, href))

    for rel, line, href in broken:
        print(f"::error file={rel},line={line}::broken link -> {href}")

    if broken:
        print(f"\n❌ link gate: {len(broken)} broken of {checked} relative links "
              f"across {len(files)} authored files.")
        return 1

    print(f"✅ link gate: {checked} relative links resolve across {len(files)} authored "
          f"files (frozen project/ + global/ trees excluded by design).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
