#!/usr/bin/env python3
"""Leak sweep — continuous sanitization, and the tool proves itself before it reports.

READ THIS BEFORE ADDING A RULE.

SANITIZATION.md's stage-5 finding was that this file's ancestors became a leak vector:
writing "term X was removed" puts term X back in the tree. So this script contains NO
real identifier — not the employer name, not a hostname, not a credential. Every rule
describes a *class* by shape: what a real GUID looks like versus the sanitized
`00000000-…-0000000000NN` form, what a routable IP looks like versus RFC 5737
documentation space, what a home path looks like in each of its encodings.

The second lesson it enforces is stage 5's other one: *"A clean report from an untested
tool is not evidence."* Three of the original sweep's rules had silent false negatives —
a `\\bword\\b` rule that never matched a digit-suffixed name (a digit is a word
character, so the trailing boundary never fires), a money rule that knew one currency
symbol but not the three-letter code, and a version-number heuristic that was swallowing
real public addresses. A clean run proved nothing because nobody had asked the tool to
prove it could fail.

So this script runs in two phases:

  1. SELF-TEST, in BOTH directions — every rule is run against `scripts/leak-canaries/`:
       * `<rule>.canary` holds correctly-shaped fake leaks. The rule MUST flag them.
         A rule that cannot fail cannot pass.
       * `<rule>.clean` holds the legitimate shapes it must ignore — the sanitized GUID
         forms, RFC 5737 addresses, the fictional estate's hostnames, `${VAR}`
         placeholders, service-account paths. The rule must find NOTHING here.
     The second direction matters as much as the first. A sweep that cries wolf on
     every hook's grep pattern gets muted within a week, and a muted gate protects
     nothing — the same failure mode the install guide warns about for slow hooks.
     Both directions were written after the first real run, where every one of the
     37 findings turned out to be a false positive.

  2. SWEEP — the same rules over the repository, canaries and this script excluded.

Exit 0 clean, 1 on a canary miss, a false-positive canary, or a real finding.
"""

import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CANARY_DIR = os.path.join(REPO, "scripts", "leak-canaries")

SKIP_DIRS = {".git", "leak-canaries", "site", "node_modules", ".venv"}
SKIP_FILES = {"check-leaks.py"}
TEXT_SUFFIXES = (
    ".md", ".json", ".sh", ".js", ".ts", ".py", ".yml", ".yaml", ".txt",
    ".html", ".css", ".toml", ".cfg", ".env", ".example",
)

# Money figures that are DELIBERATE fakes, per SANITIZATION.md. A new figure outside
# this allowlist is either a real number that survived, or a fake nobody recorded —
# both worth a human look. Keep sorted; add only after confirming the value is invented.
ALLOWED_MONEY = set()


def _rule_guid(text):
    """Real GUIDs. The sanitized estate uses all-zero GUIDs with a small trailing
    counter — both the plain `…-0000000000NN` form and the UUIDv4-shaped variant
    `00000000-0000-4000-8000-00000000000N`, which keeps the version/variant nibbles
    so it parses as a valid v4 wherever code insists on one."""
    out = []
    # The variant nibble is 8, 9, a or b per RFC 4122 — the first draft allowed only 8,
    # and the negative canary caught it on the very first run.
    sanitized = re.compile(
        r"0{8}-0{4}-[04]0{3}-[089ab]0{3}-0{8,11}[0-9a-f]{0,4}"
    )
    pat = re.compile(r"\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-"
                     r"[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b")
    for m in pat.finditer(text):
        g = m.group(0).lower()
        if sanitized.fullmatch(g):
            continue
        out.append((m.start(), f"GUID-shaped value outside the sanitized form: {g}"))
    return out


def _rule_truncated_guid(text):
    """8-hex prefixes: the form that survived because the GUID regex wanted all 36 chars."""
    out = []
    pat = re.compile(r"(?<![0-9a-zA-Z_/-])(?:tenant|subscription|client|workspace|app)"
                     r"[ _-]?id[\"'`:= ]+([0-9a-f]{8})(?![0-9a-zA-Z-])", re.I)
    for m in pat.finditer(text):
        if m.group(1) == "00000000":
            continue
        out.append((m.start(), f"8-hex id prefix bound to an id field: {m.group(1)}"))
    return out


def _rule_public_ip(text):
    """Routable IPv4 outside RFC 5737 documentation space and private/loopback ranges."""
    out = []
    pat = re.compile(r"(?<![\w.-])((?:\d{1,3}\.){3}\d{1,3})(?![\w.-])")
    for m in pat.finditer(text):
        ip = m.group(1)
        parts = [int(p) for p in ip.split(".") if p.isdigit()]
        if len(parts) != 4 or any(p > 255 for p in parts):
            continue  # version string, not an address
        a, b, c, _d = parts
        if (a, b, c) in {(192, 0, 2, ), (198, 51, 100), (203, 0, 113)}:
            continue
        if a == 192 and b == 0 and c == 2:
            continue
        if a in (0, 10, 127) or (a == 172 and 16 <= b <= 31) or (a == 192 and b == 168):
            continue
        if a == 169 and b == 254:
            continue
        if a >= 224:
            continue
        out.append((m.start(), f"routable IP outside RFC 5737 documentation space: {ip}"))
    return out


# Home-directory segments that name a SERVICE, not a person: container and CI paths
# like /home/argocd/ or /home/runner/ carry no identity and must not fire.
SERVICE_ACCOUNTS = {
    "argocd", "runner", "node", "app", "root", "ubuntu", "user", "vscode", "jenkins",
    "postgres", "redis", "rabbitmq", "nginx", "git", "docker", "linuxbrew", "me",
}


def _rule_home_path(text):
    """Home paths in every encoding — including the dash-encoded project-slug form
    that the slash-based rule could never match (the slashes are gone, so a
    slash-anchored rule sails straight past it)."""
    out = []
    for pat, why in (
        (re.compile(r"/Users/(?!<)([a-z][a-z0-9._-]{1,32})/", re.I), "unix home path with a username"),
        (re.compile(r"/home/(?!<)([a-z][a-z0-9._-]{1,32})/", re.I), "linux home path with a username"),
        (re.compile(r"C:\\\\Users\\\\(?!<)([A-Za-z][A-Za-z0-9._-]{1,32})", re.I), "windows home path with a username"),
        (re.compile(r"-Users-(?!<)([a-z][a-z0-9-]{1,32})-", re.I), "dash-encoded home path (project-slug form)"),
    ):
        for m in pat.finditer(text):
            if m.group(1).lower() in SERVICE_ACCOUNTS:
                continue
            out.append((m.start(), f"{why}: {m.group(0)}"))
    return out


def _rule_nul_byte(raw_bytes):
    """A raw NUL makes a file register as binary, so grep skips it SILENTLY and every
    text-based check passes it by inspecting nothing. Two documents shipped this way."""
    if b"\x00" in raw_bytes:
        return [(0, "raw NUL byte — this file is invisible to text-based sweeps")]
    return []


def _rule_generated_hostname(text):
    """Cloud-generated globally-unique hostnames.

    The signal is NOT "a hostname in a cloud domain" — the sanitized estate is full of
    those (`prod-acme-legacy-api.azurewebsites.net`), and flagging them all is how a
    gate gets muted. The signal is a label a *machine* produced: a long random hex run,
    or the adjective-noun-hex form these platforms mint. Those are the ones no rename
    dictionary ever contained, because nobody invents them — and the ones that stay
    resolvable long after an export."""
    out = []
    host_pat = re.compile(
        r"\b([a-z0-9][a-z0-9-]{2,60})\."
        r"(azurestaticapps\.net|azurecontainerapps\.io|azurewebsites\.net|"
        r"cloudapp\.azure\.com|blob\.core\.windows\.net)\b",
        re.I,
    )
    machine_generated = (
        re.compile(r"[0-9a-f]{8,}"),                       # long hex run
        re.compile(r"-[0-9a-f]{6,}$"),                     # trailing hex suffix
        re.compile(r"^[a-z]+-[a-z]+-[0-9a-f]{4,}$"),       # adjective-noun-hex
    )
    for m in host_pat.finditer(text):
        label = m.group(1).lower()
        if any(p.search(label) for p in machine_generated):
            out.append((
                m.start(),
                f"machine-generated cloud hostname (no dictionary ever contained it): "
                f"{m.group(0).lower()}",
            ))
    return out


def _rule_totp_or_password_literal(text):
    """Structure-preserving secrets: base32 TOTP seeds and literal password assignments.

    Deliberately narrow. The first draft matched a bare `password ` followed by any
    8+ characters, which fired on the sentence "a password _template_ whose derivation
    rule survived", on a hook's grep pattern `"password:|secret:|token:"`, and on half
    the architecture set. A rule that flags English prose about passwords teaches
    readers to ignore it. This one requires a real assignment (`=` or `:` with optional
    quoting) and a value with the shape of a credential rather than of a word."""
    out = []

    for m in re.finditer(
        r"\b(?:totp|otp)[ _-]?(?:seed|secret)\s*[:=]\s*[\"'`]?([A-Z2-7]{16,})", text, re.I
    ):
        out.append((m.start(), "TOTP seed literal"))

    assign = re.compile(
        r"\b(?:password|passwd|pwd|secret|api[_-]?key|access[_-]?token)"
        r"\s*[:=]\s*[\"'`]([^\"'`\n]{8,64})[\"'`]",
        re.I,
    )
    for m in assign.finditer(text):
        val = m.group(1).strip()
        # Placeholders, interpolations and references — not values.
        if re.match(r"^[<$*{]|^your[-_]|^change[-_]?me$|^redacted|^placeholder|^\.\.\.", val, re.I):
            continue
        if "${" in val or "$(" in val or "%s" in val or "{{" in val:
            continue
        if set(val) <= set("*xX.•●"):
            continue
        # A grep/regex pattern listing key names, e.g. "password:|secret:|token:"
        if "|" in val or val.endswith(":"):
            continue
        # Prose: words separated by spaces, no credential-ish characters.
        if " " in val and not re.search(r"[!@#$%^&*_+=\-/\\]", val):
            continue
        # Env-var NAMES rather than values.
        if re.fullmatch(r"[A-Z][A-Z0-9_]{3,}", val):
            continue
        out.append((m.start(), f"credential literal with a real-looking value: {val[:4]}…"))
    return out


TEXT_RULES = [
    ("guid", _rule_guid),
    ("truncated-guid", _rule_truncated_guid),
    ("public-ip", _rule_public_ip),
    ("home-path", _rule_home_path),
    ("generated-hostname", _rule_generated_hostname),
    ("secret-literal", _rule_totp_or_password_literal),
]


def scan_text(text):
    findings = []
    for name, rule in TEXT_RULES:
        for pos, why in rule(text):
            findings.append((name, pos, why))
    return findings


def line_of(text, pos):
    return text[:pos].count("\n") + 1


def self_test():
    """Every rule proves itself in both directions before the sweep is trusted:
    it must FIRE on `<rule>.canary` and stay SILENT on `<rule>.clean`."""
    if not os.path.isdir(CANARY_DIR):
        print(f"::error::canary directory missing: {CANARY_DIR}")
        return False

    problems = []
    names = [n for n, _ in TEXT_RULES] + ["nul-byte"]

    for name in names:
        pos_path = os.path.join(CANARY_DIR, f"{name}.canary")
        neg_path = os.path.join(CANARY_DIR, f"{name}.clean")

        if not os.path.isfile(pos_path):
            problems.append(f"{name}: no canary at scripts/leak-canaries/{name}.canary")
        else:
            raw = open(pos_path, "rb").read()
            if name == "nul-byte":
                fired = bool(_rule_nul_byte(raw))
            else:
                fired = any(f[0] == name for f in scan_text(raw.decode("utf-8", "replace")))
            if not fired:
                problems.append(
                    f"{name}: did NOT flag its own canary — the rule is broken, and a "
                    f"clean sweep with it would be meaningless"
                )

        if not os.path.isfile(neg_path):
            problems.append(f"{name}: no negative canary at scripts/leak-canaries/{name}.clean")
        else:
            raw = open(neg_path, "rb").read()
            if name == "nul-byte":
                hits = _rule_nul_byte(raw)
                detail = ["binary content in a text file"] if hits else []
            else:
                text = raw.decode("utf-8", "replace")
                detail = [why for n, _pos, why in scan_text(text) if n == name]
            if detail:
                problems.append(
                    f"{name}: FIRED on legitimate content ({len(detail)}x, first: "
                    f"{detail[0][:80]}) — a rule that cries wolf gets muted, and a muted "
                    f"gate protects nothing"
                )

    for p in problems:
        print(f"::error::self-test: {p}")
    if problems:
        print(f"\n❌ leak sweep SELF-TEST failed ({len(problems)} problem(s)). "
              f"Refusing to report on the real tree with an unproven tool.")
        return False

    print(f"✓ self-test: all {len(names)} rules fire on their canaries and stay silent "
          f"on legitimate content.")
    return True


def load_allowlist():
    """Reviewed (path, rule) exceptions — teaching examples and documented anti-patterns."""
    path = os.path.join(REPO, "scripts", "leak-allowlist.json")
    if not os.path.isfile(path):
        return set()
    import json
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
    return {(e["path"], e["rule"]) for e in data.get("allow", [])}


def sweep():
    findings = []
    scanned = 0
    allowlist = load_allowlist()
    used = set()
    for root, dirs, files in os.walk(REPO):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in files:
            if f in SKIP_FILES:
                continue
            path = os.path.join(root, f)
            rel = os.path.relpath(path, REPO)
            # The NUL rule exists to catch a TEXT document that silently reads as
            # binary. Applying it to actual binaries (the social-preview PNG) would
            # flag every image in the repo forever.
            if not f.endswith(TEXT_SUFFIXES):
                continue

            try:
                raw = open(path, "rb").read()
            except OSError:
                continue

            for _pos, why in _rule_nul_byte(raw):
                findings.append((rel, 0, "nul-byte", why))

            scanned += 1
            text = raw.decode("utf-8", errors="replace")
            for name, pos, why in scan_text(text):
                findings.append((rel, line_of(text, pos), name, why))

    kept = []
    for rel, line, name, why in findings:
        if (rel, name) in allowlist:
            used.add((rel, name))
            continue
        kept.append((rel, line, name, why))

    for rel, line, name, why in kept:
        print(f"::error file={rel},line={line}::[{name}] {why}")

    # A stale exception is a silent cap: the content it excused is gone, so it now sits
    # ready to excuse something else. The register must shrink on its own.
    stale = sorted(allowlist - used)
    for rel, name in stale:
        print(f"::error::stale allowlist entry — {rel} no longer produces a [{name}] "
              f"finding. Remove it from scripts/leak-allowlist.json.")

    if kept or stale:
        print(f"\n❌ leak sweep: {len(kept)} finding(s), {len(stale)} stale allowlist "
              f"entr(ies) across {scanned} text files.")
        return 1

    print(f"✅ leak sweep: {scanned} text files clean against {len(TEXT_RULES) + 1} "
          f"canary-proven rules ({len(used)} reviewed exception(s) applied).")
    return 0


def main():
    if not self_test():
        return 1
    return sweep()


if __name__ == "__main__":
    sys.exit(main())
