# Sanitization log

Everything in this repo was exported from a real working setup. Business identifiers were
renamed to consistent fictional ones — the same input always maps to the same output, so
cross-references still resolve and the examples still read like real work.

**No real company, colleague, customer, credential, hostname or trade survives here.**
This export is _de-identified for third parties_, not anonymous: it is deliberately
attributable to its author, whose own name is kept throughout.

## Rename dictionary

| Category                      | Real →               | Fictional                                                             |
| ----------------------------- | -------------------- | --------------------------------------------------------------------- |
| Company                       | _(employer)_         | `Initech` / `initech`                                                 |
| GitHub org                    | _(org)_              | `initech-trading-platform`, `github.com/example-org/acme`             |
| Product                       | _(product)_          | `Acme` / `acme`                                                       |
| Domain                        | _(company domain)_   | `acme-example.co.uk`                                                  |
| Intended-Platform zone        | _(DNS zone)_         | `acme-example.net`                                                    |
| Legacy externally-hosted zone | _(DNS zone)_         | `acme-legacy.co.uk`                                                   |
| Platform codename             | _(codename)_         | `Platform` / `platform`                                               |
| Legacy backend                | _(app name)_         | `legacy-api`                                                          |
| Legacy frontend               | _(app name)_         | `legacy-web`                                                          |
| Business-domain service       | _(app name)_         | `domain-api`                                                          |
| Design system                 | _(scoped pkg)_       | `@acme/ui`                                                            |
| Custom MCP server             | _(app name)_         | `acme-mcp`                                                            |
| Worktree helper               | _(script name)_      | `acme-worktree`                                                       |
| ERP vendor                    | _(vendor + version)_ | `ERP` / `erp` (agent `erp-integration-specialist`, skill `erp-issue`) |
| Partner entity                | _(customer group)_   | `Partner` / `partner`, `partner-portal.example`                       |
| Prod environment prefix       | _(env prefix)_       | `prod`                                                                |
| Stakeholders                  | _(names)_            | role placeholders — `the FD`, `the delivery lead`, `Trader A`/`B`/…   |
| Company codes                 | _(codes)_            | `CO-A`, `CO-B`, …                                                     |
| Trading entities              | _(legal names)_      | `Freshco Produce Limited`, `Beta Produce Ltd`, …                      |
| Seeded tenant                 | _(name)_             | `FreshCo` / `freshco`                                                 |
| Emails                        | _(addresses)_        | `fd@initech.example`, `me@initech.example`                            |
| Home paths                    | `/Users/<me>/…`      | `~/…`, `$PROJECT_ROOT`                                                |

## Identifiers replaced

- **79 GUIDs** — Azure subscription, tenant, workspace and resource IDs → sequential
  `00000000-0000-0000-0000-0000000000NN`. Five truncated 8-hex prefixes were caught
  separately.
- **3 public IPs** — real load-balancer addresses → `203.0.113.x` (RFC 5737 documentation
  range).
- **7 money figures** — real GBP amounts in the memory tree → deterministic plausible
  fakes.
- **2 entity row-ids** — real business-record primary keys → generic 4-digit ids.

Issue and PR numbers (`#1623`, `#1774`, …) were **kept**. They are load-bearing in the
memory tree's cross-references, and they dereference to nothing outside the original
private repo.

## Files removed, not renamed

21 memory files were deleted rather than sanitized — they were business-domain knowledge
with no transferable engineering lesson underneath, so there was nothing a rename could
have preserved. Where an index pointed at one, the link is replaced by
`_(removed — business-only)_` where the marker still reads as a sentence, and rewritten into
prose where it would have left a dangling clause instead.

There is a second, unrelated mark, and the two are easy to confuse. A file deleted outright
gets the marker above; **a passage excised from a file that is otherwise kept** gets a short
note in the running prose, usually the parenthetical form _(… is business policy and is not
part of this export)_. It appears only where the omission would otherwise read as an
oversight — a heading with nothing under it, or a rule referred to but never stated. Most
excised passages carry no note at all, because the generalised sentence that replaced them
stands on its own, and a disclaimer repeated at every omission stops reading as scope and
starts reading as throat-clearing.

Also excluded from the export: 52 of 53 epics, 58 of 59 PRDs, two large epic execution
prompts, and all session/runtime state (transcripts, worktrees, caches,
`settings.local.json`, plugin binaries).

## Verification performed

Sanitization ran in six stages. **The first stage was not sufficient** — this section
records that honestly, because the failure is the most useful thing here.

### Stage 1 — scripted rename, then grep verification

A dictionary-driven rename pass plus a 17-term denylist sweep, a GUID sweep, an IP sweep,
`gitleaks`, and a link-integrity check. All reported clean.

### Stage 2 — adversarial multi-agent audit

Six independent agents then audited the export, each with a different lens (people, org,
infrastructure, financial, filenames/paths, narrative prose), with every candidate finding
re-checked by a separate skeptical verifier. **Verdict: DO NOT PUBLISH.** It found leaks
that stage 1's greps had missed entirely:

| Cluster                          | What stage 1 missed                                                                                              | Why the greps missed it                                                                                  |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| Real colleague names             | Three full names in a "Key Users (Production)" table; a surname left bolted to a role placeholder in four places | The denylist only contained names I already knew to look for                                             |
| Business identifiers             | Real identifiers still bound to the rate data they parameterised                                                 | **The scrub for that category only ran inside `global/memory/` — the entire `project/` tree was never swept** |
| Live Azure hostnames             | 8 globally-unique generated labels (`*.azurestaticapps.net`, `*.azurecontainerapps.io`), still resolvable        | Hostnames were never a category in the dictionary at all                                                 |
| Working credentials              | A valid TOTP seed, four passwords including one recorded as a CI secret's literal value                          | No credential scrubbing was attempted; `gitleaks` does not flag prose                                    |
| Vendor case detail               | A named third-party engineer and a real 16-digit Azure support-request ID                                        | Not in any denylist                                                                                      |
| Real money figures               | Three originals left beside the seven that were replaced — arithmetic self-consistency exposed them              | The money regex matched only `£N,NNN.NN`, not `£NN,NNN`                                                  |
| Truncated Azure IDs              | 8 more 8-hex prefixes, including a real Entra tenant                                                             | The GUID regex required the full 36-char form                                                            |
| Employer initialism              | `<employer initialism>` surviving in a filename, frontmatter and two links                                       | The rename pass edited content before paths, and this token was not in the dictionary                    |

All ten clusters were then remediated and re-verified. The lesson generalises well beyond
this repo: **a denylist can only find what you already thought of.** An adversarial reader
with a different lens finds the rest.

### Stage 3 — remediation, then a confirmation re-audit

The ten clusters were fixed and a second four-lens audit re-checked the result. It found
**two more live credentials** that stage 2 had not looked for (an ArgoCD admin password
and a password _template_ whose derivation rule survived intact), six lower-grade
identifier residues, and eleven places where the renaming itself had mangled prose. All
were fixed. Final state: 37/37 denylist terms zero, `gitleaks` clean, all links resolve.

Three rounds, and each one found something the previous round's method could not see.
Take that as the actual lesson of this file.

### Stage 4 — the architecture set

25 architecture documents (148 mermaid diagrams) were later authored by agents reading the
real source and writing sanitized output directly. A fourth adversarial audit — identifiers,
infrastructure, technical accuracy, and diagram renderability — found:

- **Two identifier leaks**, both real Terraform environment directory names that no previous
  denylist had ever contained. Once added, they turned out to survive in **26 files elsewhere
  in the repo** that three earlier rounds had passed as clean. A real external tax authority's
  name was also still present.
- **Four mermaid blocks that would not render on GitHub.** A semicolon inside a
  `sequenceDiagram` `Note` terminates the statement, so the remaining text is parsed as a new
  one and the whole diagram becomes a red error box. A hand-written structural validator
  missed all four; only running the real mermaid parser found them. Every one of the 148
  diagrams is now confirmed to render by `@mermaid-js/mermaid-cli` under headless Chrome.
- **Nine accuracy defects**, including two that misdescribed security posture (claiming
  local JWTs were HMAC-signed when the service is RS256-only in every environment, and
  claiming a message broker was cluster-operator managed when it is a plain StatefulSet).
  Several were self-contradictions between documents in the same set.

Four rounds now. Each one found a class the previous round's method could not see.

### Stage 5 — the deep-dive set, and the class no denylist can hold

Fifteen further documents (91 diagrams) went one level below the architecture set, into the
event backbone, the broker and multi-tenant isolation. A fifth adversarial audit ran five
lenses — identifiers, technical accuracy, diagrams and links, reader usefulness, and one new
one — with every finding re-checked by a separate skeptic. It found:

- **The platform codename was never renamed.** The dictionary maps it to `platform`, and the
  architecture set applied that; the deep-dive authors applied it only partially. The proof was
  internal inconsistency rather than any denylist: the _same_ chart appeared in one document as
  `charts/platform-rmq-bootstrap` and in another as its real name. 134 occurrences across source
  paths, chart names, namespaces, Kubernetes label values, workflow filenames, metric prefixes
  and an ADR filename. A field identifier carrying the ERP vendor's name survived twice in the
  same way — beside three documents using the sanitized twin.
- **One document was not text.** A raw NUL byte, written as a literal separator in a code
  excerpt, made the file register as binary — so `grep` skipped it silently and every
  text-based check had been passing it by inspection of nothing.
- **A diagram that rendered was still wrong.** Rendering proves syntax, not meaning: a
  four-layer defence diagram drew a serial chain through two conditional hops and one control
  that is not deployed. Several counts contradicted their own enumerations — a sentence saying
  "nine headers" immediately above a list of ten.
- **My own sweep had three false negatives**, found by testing it against injected canaries
  rather than trusting a clean result: a `\bword\b` rule for the employer name never matched the
  digit-suffixed form of it, because a digit is a word character and the trailing boundary never
  fires; the money rule knew `£` but not the three-letter currency code; and a "that's a version
  number, not an IP" heuristic was silently swallowing real public addresses. A clean report
  from an untested tool is not evidence.

  A sixth thing surfaced only on the final repo-wide run: **this file had itself become a leak
  vector.** Writing "term X was removed" puts term X back in the tree. Three identifiers were
  reintroduced by the very paragraphs documenting their removal. Describe the _class_ — "the
  digit-suffixed form of the employer name", "the Terraform environment directory names" — never
  the token.

**And the finding that was not about identifiers at all.** A new lens asked a question no
earlier round had: is this transferable engineering craft, or the employer's confidential
knowledge wearing a rename? It confirmed 21 passages that were neither — they were a precise,
verified, _currently unremediated_ defect inventory of a live production system: which services
lack a network control and which do not, which routes accept an identity header nobody signs,
which controllers enforce nothing despite documenting otherwise, and a ranked list of what to
fix first, which reads equally well as a ranked list of what to attack first.

No amount of renaming addresses that. This export is deliberately attributable to its author,
so "Acme" protects nothing. Every such passage was rewritten to the pattern level — the
mechanism, why it arises, and how to close it, with the service names, the tallies and the
present tense removed. In several places the generalisation is the better sentence: _"where
authorisation is opt-in per controller, a deliberate omission and a forgotten one look
identical, so no audit of the source can say which is which"_ teaches more than the list of
which controllers it applied to ever did.

The lesson to carry forward: **sanitization asks "can a reader tell whose system this is?" —
it does not ask "does this help someone attack it?"** Those are different questions, and four
rounds of the first never once raised the second.

### Stage 6 — pre-publication re-audit

One last adversarial pass before the repository went public, with six lenses — identity,
secrets, infrastructure and attack utility, business knowledge, portfolio accuracy, personal
data — and every candidate finding re-checked by a skeptic. 33 findings confirmed, 12 rejected.
The classes, described at class level only (see the stage-5 lesson above):

1. **The attack-utility rewrite never reached the memory tree.** Stage 5 applied it to
   `docs/architecture` and stopped there; three memory files still carried a dated,
   present-tense inventory of which services lacked a control. Rewritten to the mechanism.
2. **A business calculation rule survived under fictional identifiers.** No rename dictionary
   can catch that class: a percentage is not an identifier, so the scrub had nothing to match
   on and the rule read as ordinary configuration. Rewritten to drop the rule itself _(the
   rules are business policy and are not part of this export)_.
3. **A behavioural profile of a role-unique real person survived the name rename.** A job
   title that only one person at an employer holds in a given year identifies that person as
   surely as a name does. Rewritten to role level — the rules and templates stay, the
   characterisation does not.
4. **Two real DNS zones survived with only the product token swapped.** Caught by dictionary
   consistency, not by any denylist: the same zone appeared elsewhere under its sanitized name.
5. **A second document containing a raw NUL byte**, invisible to every text-based sweep for the
   same reason as the first.
6. **Claude Code's dash-encoded project slug form of the home path**, which the home-path rule
   never matched because the slashes were gone.
7. **A well-known example TOTP seed and one structure-preserving dev password literal**, both
   replaced with structure-free placeholders.
8. **The git reflog and dangling objects still held pre-sanitization blobs and the author's
   work e-mail.** Unreachable from any ref, so never pushed — but purged with a reflog expire
   and `gc` before publishing, because "unreachable" is not "absent".

The lesson, six rounds in: every round's method was blind to the class the next round found;
the only sweep that found the rename residues was consistency between documents, not any
denylist.

## Credentials: the originals, not the copy

**Sanitizing an export does nothing for the systems it was exported from.** Renaming a value in a
copy leaves the original working exactly as it did before, and a reader who only reviews the
diff will not notice — the copy looks clean, which is the point, and that is precisely what makes
this easy to skip.

So the export produced a rotation list: every credential class that appeared in real config at
export time, each one rotated at the source. Ten classes came out of it, spanning cluster admin
consoles left on vendor defaults, a shared operator password and its TOTP seeds (a second factor
cannot be expired — those need re-enrolment, not a reset), seed and fixture password *generators*
rather than the individual passwords they produce, literals duplicated into CI secret stores where
a source-only fix leaves them live, a signing key whose replacement also has to be pushed to the
secret store consuming it, and registry and OIDC client secrets rotated for hygiene because their
acquisition path was documented even though no value leaked.

**That list is not published here, and this is the reason.** An itemised, present-tense inventory of
which credentials on which systems are still unrotated is a to-do list for its owner and a target
list for everybody else — the same asymmetry as stage 5's finding about defect inventories. The
transferable part is the *procedure*, and it is this: when you export anything from a real system,
generate the rotation list as a deliberate step, keep it wherever your secrets already live, and
close it out there. Publishing it converts an act of good hygiene into a disclosure.

## Deliberate retentions

- **The author's own name.** This is his repository; it is meant to be attributable.
- **A public OSS maintainer's GitHub handle**, quoting his own public comments on a public
  upstream issue. That is a citation, not a disclosure, and anonymising it would break a
  load-bearing technical attribution.
- **GitHub issue and PR numbers**, and Claude Code `wf_*` run IDs — not dereferenceable by
  a third party, and load-bearing in the memory tree's cross-references.
- **Relative links pointing outside this export** (`../../projects/...`) — they referenced
  the original repository's docs and cannot resolve here. Left as-is rather than faked.

## Known imperfections

- Prose occasionally reads slightly oddly where a rename landed mid-sentence
  (e.g. a legacy app name inside a parenthetical). Meaning is preserved; phrasing may be
  stilted.
- The vendored `kubernetes-skill` arrived as a **nested git clone**; its `.git` directory
  was removed so it ships as plain files rather than an empty gitlink. Provenance is
  recorded in that directory's `VENDORED.md`.
- The vendored `kubernetes-skill` retains upstream OSS metadata, including third-party
  author emails in its `LICENSE` and lockfile. That is legitimate attribution and was left
  untouched.
- Memory files were sanitized by scripted rules plus targeted review of every file flagged
  for money, entity ids, company codes or stakeholder narrative — not by reading all 172
  end to end. If you spot a residue, it is an oversight, not a deliberate inclusion.
