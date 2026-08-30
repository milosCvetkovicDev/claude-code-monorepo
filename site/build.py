#!/usr/bin/env python3
"""Stage the two volumes into a mkdocs docs_dir, without moving anything in the repo.

THE CONSTRAINT THAT SHAPES THIS FILE. mkdocs wants one `docs_dir` containing every page.
This repository cannot provide one: `book/` and `docs/architecture/` are where they are
for reasons the book itself argues (the config trees are frozen at their original paths,
and the reading experience on GitHub has to keep working for someone who never visits the
site). So nothing moves. This script COPIES the authored pages into a build directory,
rewrites the links that would dangle there, and mkdocs builds from that.

The link rewriting is the interesting part. A chapter says
`[`project/.claude/skills/`](../project/.claude/skills/)` — correct on GitHub, broken on
a site that does not publish the config trees. Rather than dropping those links (they are
half the point of the book — every chapter ends at the real files), they are rewritten to
absolute github.com URLs. The reader stays one click from the primary source either way.

Run:
    python3 site/build.py            # stage into site/_build/docs
    python3 site/build.py --check    # stage, then report any link that still dangles
"""

import os
import re
import shutil
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(REPO, "site", "_build")
DOCS = os.path.join(BUILD, "docs")

GH = "https://github.com/milosCvetkovicDev/claude-code-monorepo/blob/main/"

# Trees that are published as site pages. Everything else stays on GitHub only.
STAGED = {
    "book": "book",
    "docs/architecture": "architecture",
    "examples": "examples",
}

# Repo-root files that become site pages.
ROOT_PAGES = {
    "README.md": "index.md",
    "SANITIZATION.md": "sanitization.md",
}

# Paths that exist in the repo but NOT on the site — links into them get rewritten to
# GitHub. Order matters: longest prefix first.
NOT_PUBLISHED = ("project/", "global/", "scripts/", ".github/", "LICENSE", "NOTICE")

# Two link forms. The plain one, and the badge form `[![alt](img.svg)](target)` — where
# the link TEXT contains its own brackets and parens, so the plain pattern stops early and
# silently leaves the badge pointing at a repo path. That is exactly how the cover page's
# "sanitized" badge survived the first staging run.
LINK_RE = re.compile(r"(\[(?:!\[[^\]]*\]\([^)\s]+\)|[^\]]*)\]\()([^)\s]+)(\))")


def rel_to_repo(page_rel, href):
    """Resolve a link relative to its source page, as a repo-relative path."""
    base = os.path.dirname(page_rel)
    return os.path.normpath(os.path.join(base, href)).replace(os.sep, "/")


def repo_to_site(repo_path):
    """Map a repo-relative path to its path within the staged site, or None if the
    target is not published there (→ the caller rewrites it to a GitHub URL)."""
    if repo_path in ROOT_PAGES:
        return ROOT_PAGES[repo_path]
    for src_dir, dst_dir in sorted(STAGED.items(), key=lambda kv: -len(kv[0])):
        if repo_path == src_dir:
            return dst_dir
        if repo_path.startswith(src_dir + "/"):
            return dst_dir + repo_path[len(src_dir):]
    return None


def rewrite_links(text, page_rel, page_site_rel):
    """page_rel is the source path in the repo; page_site_rel is where it lands on the
    site. Links are resolved in repo space, then re-expressed in site space."""
    page_site_dir = os.path.dirname(page_site_rel)

    def sub(m):
        prefix, href, suffix = m.groups()
        if href.startswith(("http://", "https://", "mailto:", "#")):
            return m.group(0)

        target, _, anchor = href.partition("#")
        if not target:
            return m.group(0)  # pure anchor

        resolved = rel_to_repo(page_rel, target)
        frag = ("#" + anchor) if anchor else ""

        site_target = repo_to_site(resolved)
        if site_target is None:
            # Not published on the site — send the reader to the real file on GitHub,
            # because these links ARE the point: every chapter ends at its primary source.
            return f"{prefix}{GH}{resolved}{frag}{suffix}"

        # A link to a DIRECTORY has no page on the site; point it at that directory's
        # index (README.md) when one exists, and at GitHub when it does not — a bare
        # directory href 404s on a static site while working fine on GitHub.
        if os.path.isdir(os.path.join(REPO, resolved)):
            if os.path.isfile(os.path.join(REPO, resolved, "README.md")):
                site_target = site_target.rstrip("/") + "/README.md"
            else:
                return f"{prefix}{GH}{resolved}{frag}{suffix}"

        new_href = os.path.relpath(site_target, page_site_dir or ".").replace(os.sep, "/")
        return f"{prefix}{new_href}{frag}{suffix}"

    return LINK_RE.sub(sub, text)


def stage_file(src_abs, page_rel, page_site_rel, dst_abs):
    os.makedirs(os.path.dirname(dst_abs), exist_ok=True)
    if src_abs.endswith(".md"):
        with open(src_abs, encoding="utf-8") as fh:
            text = fh.read()
        text = rewrite_links(text, page_rel, page_site_rel)
        with open(dst_abs, "w", encoding="utf-8") as fh:
            fh.write(text)
    else:
        shutil.copy2(src_abs, dst_abs)


# Pinned by version AND checksum — see site/mermaid-init.js for why the site does not
# use the framework's floating CDN default. Update both together, from the registry.
MERMAID_VERSION = "11.17.2"
MERMAID_SHA256 = "581ed7d74bd9048d0e3a91363927d72ef22942d7722546b27f7cc29e35390eb8"
MERMAID_URL = f"https://cdn.jsdelivr.net/npm/mermaid@{MERMAID_VERSION}/dist/mermaid.min.js"


def vendor_mermaid():
    """Fetch the pinned mermaid build into the site assets, verifying its checksum.

    Cached in site/_vendor so repeated local builds do not re-download it. A checksum
    mismatch is fatal: an unverified 3.5 MB script running in every reader's browser is
    exactly the supply-chain shape this repo's guardrails exist to refuse."""
    import hashlib
    import urllib.request

    cache_dir = os.path.join(REPO, "site", "_vendor")
    os.makedirs(cache_dir, exist_ok=True)
    cached = os.path.join(cache_dir, f"mermaid-{MERMAID_VERSION}.min.js")

    if not os.path.isfile(cached):
        with urllib.request.urlopen(MERMAID_URL, timeout=60) as resp:
            data = resp.read()
        digest = hashlib.sha256(data).hexdigest()
        if digest != MERMAID_SHA256:
            raise SystemExit(
                f"mermaid checksum mismatch\n  expected {MERMAID_SHA256}\n  got      {digest}\n"
                f"  url      {MERMAID_URL}"
            )
        with open(cached, "wb") as fh:
            fh.write(data)

    digest = hashlib.sha256(open(cached, "rb").read()).hexdigest()
    if digest != MERMAID_SHA256:
        raise SystemExit(f"cached mermaid failed verification: {cached}")

    shutil.copy2(cached, os.path.join(DOCS, "assets", "mermaid.min.js"))
    return 1


def build():
    if os.path.isdir(BUILD):
        shutil.rmtree(BUILD)
    os.makedirs(DOCS, exist_ok=True)

    staged = 0

    for src_dir, dst_dir in STAGED.items():
        src_root = os.path.join(REPO, src_dir)
        for root, _dirs, files in os.walk(src_root):
            for f in files:
                if not f.endswith((".md", ".png", ".jpg", ".svg")):
                    continue
                src_abs = os.path.join(root, f)
                page_rel = os.path.relpath(src_abs, REPO).replace(os.sep, "/")
                sub = os.path.relpath(src_abs, src_root)
                site_rel = os.path.join(dst_dir, sub).replace(os.sep, "/")
                dst_abs = os.path.join(DOCS, site_rel)
                stage_file(src_abs, page_rel, site_rel, dst_abs)
                staged += 1

    for src_name, dst_name in ROOT_PAGES.items():
        src_abs = os.path.join(REPO, src_name)
        if os.path.isfile(src_abs):
            stage_file(src_abs, src_name, dst_name, os.path.join(DOCS, dst_name))
            staged += 1

    # Site assets: the social card (doubles as og:image) and the stylesheet.
    os.makedirs(os.path.join(DOCS, "assets"), exist_ok=True)
    card = os.path.join(REPO, "docs", "images", "social-preview.png")
    if os.path.isfile(card):
        shutil.copy2(card, os.path.join(DOCS, "assets", "social-preview.png"))
        staged += 1
    css = os.path.join(REPO, "site", "extra.css")
    if os.path.isfile(css):
        shutil.copy2(css, os.path.join(DOCS, "assets", "extra.css"))
        staged += 1
    init = os.path.join(REPO, "site", "mermaid-init.js")
    if os.path.isfile(init):
        shutil.copy2(init, os.path.join(DOCS, "assets", "mermaid-init.js"))
        staged += 1
    staged += vendor_mermaid()

    print(f"staged {staged} files into {os.path.relpath(DOCS, REPO)}")
    return staged


def check():
    """Report links that dangle *within the staged site*."""
    broken = []
    for root, _dirs, files in os.walk(DOCS):
        for f in files:
            if not f.endswith(".md"):
                continue
            path = os.path.join(root, f)
            rel = os.path.relpath(path, DOCS)
            with open(path, encoding="utf-8") as fh:
                text = fh.read()
            for m in LINK_RE.finditer(text):
                href = m.group(2)
                if href.startswith(("http://", "https://", "mailto:", "#")):
                    continue
                target = href.split("#")[0]
                if not target:
                    continue
                resolved = os.path.normpath(os.path.join(os.path.dirname(path), target))
                if not os.path.exists(resolved):
                    line = text[: m.start()].count("\n") + 1
                    broken.append((rel, line, href))

    for rel, line, href in broken:
        print(f"::error::staged site link dangles: {rel}:{line} -> {href}")
    if broken:
        print(f"\n❌ {len(broken)} dangling link(s) in the staged site.")
        return 1
    print("✅ every relative link in the staged site resolves.")
    return 0


if __name__ == "__main__":
    build()
    sys.exit(check() if "--check" in sys.argv else 0)
