#!/usr/bin/env python3
"""Counts gate — every number the prose claims is asserted against the live tree.

WHY THIS EXISTS. The book states counts constantly: "71 skills", "34 hook scripts",
"172 memories". Those were verified once, by hand, when the chapters were written —
and the in-repo quick-references that predate the book (project/.claude/README.md,
the hooks README) prove exactly how that decays: they still say "~50 skills" and
"15 active agents", numbers that were true once and silently stopped being true.

A book that describes a tree is a claim about that tree. This makes it a checkable
one. The prose stays natural English — no template markers, no generated snippets —
and the script goes looking for the claims where a reader would read them.

Each rule is: a live count from the filesystem, plus the patterns that assert it in
prose. Every occurrence found must match; a pattern matching NOTHING is also a
failure (a silently-renamed claim is drift too, and the loudest kind to miss).

Exit 0 clean, 1 with a per-claim report.
"""

import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


# ---------------------------------------------------------------- live counters

def _dirs_in(rel):
    p = os.path.join(REPO, rel)
    return [d for d in os.listdir(p) if os.path.isdir(os.path.join(p, d))]


def _files_in(rel, suffix=".md", exclude=()):
    p = os.path.join(REPO, rel)
    return [
        f for f in os.listdir(p)
        if os.path.isfile(os.path.join(p, f))
        and f.endswith(suffix)
        and f not in exclude
    ]


def count_skills():
    return len(_dirs_in("project/.claude/skills"))


def count_hook_scripts():
    p = os.path.join(REPO, "project/.claude/hooks")
    return len([f for f in os.listdir(p) if f.endswith((".sh", ".js"))])


def count_project_agents():
    return len(_files_in("project/.claude/agents", exclude=("README.md",)))


def count_global_agents():
    return len(_files_in("global/agents"))


def count_all_agents():
    return count_project_agents() + count_global_agents()


def count_memories():
    # "172 files" is the whole memory tree: every .md under global/memory/, the MEMORY.md
    # index and the archive/ tier included. Counting only top-level non-index files gives
    # 162 — which is what the first draft of this gate asserted, and it was the GATE that
    # was wrong, not the prose. Kept explicit so the definition can't drift back.
    n = 0
    for _root, _dirs, files in os.walk(os.path.join(REPO, "global/memory")):
        n += sum(1 for f in files if f.endswith(".md"))
    return n


def count_nested_claude_md():
    n = 0
    for root, _dirs, files in os.walk(os.path.join(REPO, "project")):
        n += sum(1 for f in files if f == "CLAUDE.md")
    return n


def count_pm_commands():
    return len(_files_in("global/commands/pm", exclude=("NOTICE.md",)))


def count_global_rules():
    return len(_files_in("global/rules"))


def count_global_references():
    n = 0
    for root, _dirs, files in os.walk(os.path.join(REPO, "global/references")):
        n += sum(1 for f in files if f.endswith(".md"))
    return n


def count_architecture_docs():
    n = 0
    for _root, _dirs, files in os.walk(os.path.join(REPO, "docs/architecture")):
        n += sum(1 for f in files if f.endswith(".md") and f != "README.md")
    return n


def count_architecture_diagrams():
    """Mermaid blocks under docs/architecture — the '239 diagrams' claim."""
    fence = re.compile(r"^([ \t]*)```mermaid[ \t]*\n.*?^\1```[ \t]*$", re.M | re.S)
    n = 0
    for root, _dirs, files in os.walk(os.path.join(REPO, "docs/architecture")):
        for f in files:
            if f.endswith(".md"):
                with open(os.path.join(root, f), encoding="utf-8") as fh:
                    n += len(fence.findall(fh.read()))
    return n


def count_book_chapters():
    return len([
        f for f in os.listdir(os.path.join(REPO, "book"))
        if re.match(r"^\d\d-.*\.md$", f)
    ])


def count_walkthrough_tasks():
    return len([
        f for f in os.listdir(os.path.join(REPO, "examples/epic-walkthrough"))
        if re.match(r"^\d+\.md$", f)
    ])


# ------------------------------------------------------------------- the rules
# (label, live counter, [(file, regex with the number as group 1)])
# The regex must capture the claimed number so it can be compared, and should be
# specific enough that it cannot drift onto an unrelated sentence.

RULES = [
    ("skills (project/.claude/skills/*/)", count_skills, [
        ("README.md", r"`project/\.claude/skills/` \((\d+)\)"),
        ("README.md", r"skills \((\d+)\) ·"),
        ("README.md", r"skills/\) — (\d+) of them"),
        ("book/03-the-six-layers.md", r"skills/\`\]\([^)]*\) \((\d+)\)"),
        ("book/03-the-six-layers.md", r"skills/\s+(\d+) skills"),
        ("book/05-skills.md", r"There are (\d+) of them"),
        ("book/05-skills.md", r"A taxonomy of (\d+)"),
        ("book/05-skills.md", r"don't port these (\d+)"),
        ("book/05-skills.md", r"With (\d+) skills, mis-routing"),
        ("book/05-skills.md", r"all (\d+), each a directory"),
        ("book/13-the-system-it-built.md", r"plus (\d+) skills"),
        ("book/appendix-a-install.md", r"and (\d+) skills"),
        ("book/appendix-a-install.md", r"port all (\d+)"),
        ("book/appendix-b-attribution-and-lineage.md", r"The (\d+) project skills"),
    ]),
    ("hook scripts (project/.claude/hooks/*.sh|*.js)", count_hook_scripts, [
        ("README.md", r"\((\d+) scripts, 28 wired"),
        ("README.md", r"hooks \((\d+)\)"),
        ("book/03-the-six-layers.md", r"\((\d+) scripts, 28 wired"),
        ("book/03-the-six-layers.md", r"hooks/\s+(\d+) hook scripts"),
        ("book/07-hooks.md", r"\*\*(\d+) scripts\*\*"),
        ("book/07-hooks.md", r"Distilled from the (\d+)"),
        ("book/07-hooks.md", r"all (\d+), plus the original"),
        ("book/13-the-system-it-built.md", r"(\d+) hooks,"),
        ("book/appendix-a-install.md", r"all (\d+) hook scripts"),
        ("book/appendix-b-attribution-and-lineage.md", r"The (\d+) hook scripts"),
    ]),
    ("project agents (project/.claude/agents/*.md)", count_project_agents, [
        ("README.md", r"`project/\.claude/agents/` \((\d+)\)"),
        ("README.md", r"agents \((\d+)\) ·"),
        ("book/03-the-six-layers.md", r"project/\.claude/agents/\`\]\([^)]*\) \((\d+)\)"),
        ("book/06-agents.md", r"fleet here is (\d+) active project agents"),
        ("book/appendix-b-attribution-and-lineage.md", r"(\d+) project agents"),
    ]),
    ("global agents (global/agents/*.md)", count_global_agents, [
        ("README.md", r"`global/agents/` \((\d+)\)"),
        ("book/03-the-six-layers.md", r"global/agents/\`\]\([^)]*\) \((\d+)\)"),
        ("book/06-agents.md", r"\(plus 8 archived\) and (\d+)"),
        ("book/appendix-b-attribution-and-lineage.md", r"the (\d+) machine-level checkers"),
    ]),
    ("all agents (project + global)", count_all_agents, [
        ("book/13-the-system-it-built.md", r"(\d+) agents,"),
    ]),
    ("memory files (every .md under global/memory/)", count_memories, [
        ("README.md", r"`global/memory/` \((\d+) files\)"),
        ("README.md", r"memory/ \((\d+) files\)"),
        ("book/03-the-six-layers.md", r"global/memory/\`\]\([^)]*\) \((\d+) files\)"),
        ("book/03-the-six-layers.md", r"memory/\s+(\d+) durable facts"),
        ("book/09-memory.md", r"is (\d+) files of\s*\ndurable"),
        ("book/09-memory.md", r"of (\d+) facts"),
        ("book/09-memory.md", r"the (\d+) facts are one"),
        ("book/13-the-system-it-built.md", r"(\d+) memories,"),
        ("book/appendix-b-attribution-and-lineage.md", r"the (\d+) files of content"),
    ]),
    ("nested CLAUDE.md under project/", count_nested_claude_md, [
        ("README.md", r"`project/\*\*/CLAUDE\.md` \((\d+) files\)"),
        ("README.md", r"CLAUDE\.md\s+(\d+) nested"),
        ("book/03-the-six-layers.md", r"CLAUDE\.md` \((\d+) files\)"),
        ("book/03-the-six-layers.md", r"CLAUDE\.md\s+(\d+) nested"),
        ("book/04-context.md", r"^(\w+) `CLAUDE\.md` files sit"),
    ]),
    ("PM commands (global/commands/pm/*.md, minus NOTICE)", count_pm_commands, [
        ("README.md", r"commands/pm/ agents/"),  # presence-only; see note below
        ("book/03-the-six-layers.md", r"commands/pm/\s+(\d+) PM ceremony"),
        ("book/05-skills.md", r"the (\d+) PM ceremony commands"),
        ("book/10-the-ceremony.md", r"the full set of (\d+)"),
        ("book/10-the-ceremony.md", r"all (\d+) commands"),
    ]),
    ("global rules (global/rules/*.md)", count_global_rules, [
        ("book/03-the-six-layers.md", r"rules/\s+(\d+) always-resident"),
        ("book/04-context.md", r"holds (\w+) files that travel"),
        ("book/04-context.md", r"the (\w+) resident rules"),
    ]),
    ("global references (global/references/**/*.md)", count_global_references, [
        ("book/03-the-six-layers.md", r"references/\s+(\d+) on-demand"),
        ("book/04-context.md", r"^(\w+) documents in"),
    ]),
    ("book chapters (book/NN-*.md)", count_book_chapters, [
        ("README.md", r"book/\s+← the guided reading: (\d+) chapters"),
        ("README.md", r"— (\w+)\s*\nchapters, high level to low level"),
        ("docs/images/social-preview.html", r"<b>(\d+)-chapter book</b>"),
    ]),
    ("walkthrough task files (examples/epic-walkthrough/NNNN.md)", count_walkthrough_tasks, [
        ("book/11-an-epic-start-to-finish.md", r"Ten tasks, T1–T(\d+)"),
    ]),
    ("architecture documents (docs/architecture/**/*.md, minus its index)",
     count_architecture_docs, [
        ("README.md", r"\((\d+) docs, 239 diagrams\)"),
        ("book/13-the-system-it-built.md", r"across all (\d+) documents"),
        ("book/13-the-system-it-built.md", r"how (\d+) documents about a real system"),
        ("book/README.md", r"the (\d+)-document architecture volume"),
        ("docs/architecture/README.md", r"\*\*(\d+) documents ·"),
     ]),
    ("architecture diagrams (mermaid blocks under docs/architecture/)",
     count_architecture_diagrams, [
        ("README.md", r"\(40 docs, (\d+) diagrams\)"),
        ("book/13-the-system-it-built.md", r"documents, (\d+) mermaid diagrams"),
        ("docs/architecture/README.md", r"· (\d+) diagrams ·"),
     ]),
]

# One presence-only pattern above: the README's compressed layout block lists
# `commands/pm/` without a count, so there is no number to assert — the pattern
# exists to fail if that line is deleted, keeping the layout block itself gated.
PRESENCE_ONLY = {(r"commands/pm/ agents/")}

# Numbers written as words in prose, mapped so the regexes above can compare them.
WORDS = {
    "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13,
    "fourteen": 14, "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18,
    "nineteen": 19, "twenty": 20,
}


def normalize(raw):
    raw = raw.strip().lower()
    if raw.isdigit():
        return int(raw)
    return WORDS.get(raw)


def main():
    failures = []
    asserted = 0

    for label, counter, patterns in RULES:
        try:
            actual = counter()
        except OSError as exc:
            failures.append(f"{label}: could not count — {exc}")
            continue

        for rel, pattern in patterns:
            path = os.path.join(REPO, rel)
            if not os.path.isfile(path):
                failures.append(f"{label}: source file missing — {rel}")
                continue
            with open(path, encoding="utf-8") as fh:
                content = fh.read()

            matches = list(re.finditer(pattern, content, re.M))
            if not matches:
                failures.append(
                    f"{label}: pattern found NOTHING in {rel} — the claim was reworded "
                    f"or removed, so it is no longer gated  [{pattern}]"
                )
                continue

            if pattern in PRESENCE_ONLY:
                asserted += 1
                continue

            for m in matches:
                claimed = normalize(m.group(1))
                asserted += 1
                if claimed is None:
                    line = content[: m.start()].count("\n") + 1
                    failures.append(
                        f"{label}: {rel}:{line} captured {m.group(1)!r}, which is not a "
                        f"number this gate can read — fix the pattern or spell the word "
                        f"out in WORDS"
                    )
                elif claimed != actual:
                    line = content[: m.start()].count("\n") + 1
                    failures.append(
                        f"{label}: {rel}:{line} claims {m.group(1)!r}, tree has {actual}"
                    )

    for f in failures:
        print(f"::error::{f}")

    if failures:
        print(f"\n❌ counts gate: {len(failures)} problem(s) across {asserted} asserted claims.")
        return 1

    print(f"✅ counts gate: {asserted} claims across {len(RULES)} counted facts all match the tree.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
