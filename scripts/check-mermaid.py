#!/usr/bin/env python3
"""Mermaid gate — every diagram in the repo must actually render.

WHY THE REAL PARSER, AND NOTHING ELSE. SANITIZATION.md stage 4 tried this with a
hand-written structural validator. It passed four diagrams that GitHub renders as red
error boxes: a semicolon inside a `sequenceDiagram` `Note` terminates the statement, so
the remaining text parses as a new one and the whole diagram dies. Nothing short of the
real parser finds that class, so this script extracts every fenced block and runs it
through `@mermaid-js/mermaid-cli`.

Stage 5 added the other half of the lesson: rendering proves SYNTAX, not MEANING. A
four-layer defence diagram once rendered perfectly while drawing a serial chain through
two conditional hops and one control that was not deployed. This gate cannot check that
— no gate can. It checks that no reader is served a red box.

Usage:
    check-mermaid.py            # extract + render every block
    check-mermaid.py --list     # just count them (no node/puppeteer needed)

Exit 0 clean, 1 with the failing block's file, line and parser error.
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKIP_DIRS = {".git", "node_modules", "site", ".venv", "leak-canaries"}

FENCE_RE = re.compile(r"^([ \t]*)```mermaid[ \t]*\n(.*?)^\1```[ \t]*$", re.M | re.S)


def blocks():
    """Yield (relpath, line_number, source) for every fenced mermaid block."""
    for root, dirs, files in os.walk(REPO):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in sorted(files):
            if not f.endswith(".md"):
                continue
            path = os.path.join(root, f)
            rel = os.path.relpath(path, REPO)
            try:
                text = open(path, encoding="utf-8").read()
            except OSError:
                continue
            for m in FENCE_RE.finditer(text):
                indent, body = m.group(1), m.group(2)
                if indent:  # un-indent nested blocks (lists, quotes)
                    body = "\n".join(
                        ln[len(indent):] if ln.startswith(indent) else ln
                        for ln in body.split("\n")
                    )
                line = text[: m.start()].count("\n") + 1
                yield rel, line, body


def main():
    found = list(blocks())
    files = len({rel for rel, _l, _b in found})

    if "--list" in sys.argv:
        print(f"{len(found)} mermaid blocks across {files} files")
        return 0

    mmdc = shutil.which("mmdc")
    if not mmdc:
        print("::error::mmdc not found — install @mermaid-js/mermaid-cli")
        return 1

    failures = []
    with tempfile.TemporaryDirectory() as tmp:
        # A puppeteer config that works on CI's sandbox-less container.
        pptr = os.path.join(tmp, "puppeteer.json")
        with open(pptr, "w") as fh:
            fh.write('{"args":["--no-sandbox","--disable-setuid-sandbox"]}')

        for i, (rel, line, body) in enumerate(found):
            src = os.path.join(tmp, f"d{i}.mmd")
            out = os.path.join(tmp, f"d{i}.svg")
            with open(src, "w", encoding="utf-8") as fh:
                fh.write(body)
            proc = subprocess.run(
                [mmdc, "-i", src, "-o", out, "-p", pptr, "-q"],
                capture_output=True, text=True, timeout=120,
            )
            if proc.returncode != 0 or not os.path.exists(out):
                err = (proc.stderr or proc.stdout or "unknown error").strip()
                err = " ".join(err.split())[:400]
                failures.append((rel, line, err))
                print(f"::error file={rel},line={line}::mermaid block does not render: {err}")

    if failures:
        print(f"\n❌ mermaid gate: {len(failures)} of {len(found)} blocks fail to render.")
        return 1

    print(f"✅ mermaid gate: all {len(found)} blocks across {files} files render "
          f"(real parser, not a structural approximation).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
