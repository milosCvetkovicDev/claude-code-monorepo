---
name: finance-stakeholder-communication
description: Rules and templates for getting unambiguous answers from non-technical finance stakeholders on business rules — prevent repeat misinterpretation of requirements
type: feedback
originSessionId: 00000000-0000-0000-0000-000000000014
---
## Finance Stakeholder Communication

Finance stakeholders think in business/accounting concepts, not technical implementation, and tend to answer briefly and abstractly. The burden is on engineering to eliminate ambiguity.

**Why:** a one-line ruling written in the stakeholder's own shorthand routinely admits two readings — the same phrase can name the date something happened or the period it belongs to — and engineering picks one without ever noticing there was a choice. Abstract questions produce abstract answers that need several rounds to pin down; concrete examples with numbers get correct answers on the first try. _(The rules being confirmed in these examples are business policy and are not part of this export — the placeholders below stand in for them.)_

**How to apply:** Every email to a stakeholder about business rules, calculations, or data must follow these rules.

### Rule 1: Never ask "how should X work?" — show numbers instead

Bad: "Should we use the earlier date or the later one to pick the rule?"
Good: "Record #41 currently shows a total of 120.00. After the fix it would show 135.00. Is 135.00 correct?"

### Rule 2: Always include a Current → Expected table using their own data

These stakeholders live in spreadsheets — reference their spreadsheet columns/rows, one row per affected record. Show:
```
Record | Current total | After fix | Input A  | Input B | Input C
#41    | 120.00        | 135.00    | 2,000.00 | 1,150.00 | 290.00
```

### Rule 3: Never give more than 3 options — each with NUMBER impact

Bad: "Option A: use rule X. Option B: use rule Y."
Good: "Option A: #41 total = 135.00. Option B: #41 total = 120.00." — each option carries the number it produces, so they choose an outcome rather than a rule name.

### Rule 4: Include a sign-off line

End every email with: "If anything looks off or you'd like any values adjusted, just let me know."

### Rule 5: Use their own data as examples

Pull the records from the stakeholder's own spreadsheet or from previous emails. People trust their own numbers. Never use hypothetical examples when real ones exist.

### Rule 6: One question per email when possible

Longer emails tend to get shorter answers. Separate complex topics into separate emails — two unrelated questions sent separately each got a fuller response than the combined email had.

### Rule 7: Send acceptance tests before implementing

Concrete test scenarios with Given/When/Then get sign-off (a full set of Gherkin scenarios was approved before implementation on PR #188). Send as PDF or clean HTML, not raw markdown.

### Rule 8: When re-opening a topic the stakeholder has answered, quote them back to themselves

When their previous answers create tension or don't fully cover a new case, structure the email so THEY can resolve it without us paraphrasing.

- Open with "Apologies for another [topic]-related question" — acknowledges we're going back on a topic.
- Use a section titled "WHERE I THINK I MAY HAVE MISREAD YOUR GUIDANCE" — softer than "your guidance was unclear".
- Quote each prior answer verbatim, with the date it was given (e.g. "From your reply on 20 March: …").
- State YOUR reading of each quote: "I read this as: …" — lets them correct YOUR reading rather than defend THEIR words.
- Acknowledge the gap: "Neither sentence explicitly covers [the new case]".

**Why:** validated on a case where two earlier verbatim rulings pulled in different directions for a situation neither one explicitly covered. Quoting them back let us ask cleanly without implying the stakeholder had contradicted themselves.

### Rule 9: Be transparent when the system has been operating on engineering's interpretation

If we built something on a reading of their guidance that's now debatable, SAY SO upfront. Don't hide it.

Phrases that work:
- "We built the system on [our reading]"
- "What the system has been quietly doing since [date]"
- "This is what the system does today"

Phrases to avoid:
- "We had to make a decision" — passive, sounds like blame deflection
- "Your guidance was ambiguous" — puts the failure on them
- "The spec wasn't clear" — same issue, indirect

**Why:** stakeholders reward transparency. Hiding that engineering chose an interpretation looks worse than admitting it; they would rather be told the system has been applying an interpretation for a while than discover it later.

### Rule 10: "MY SUGGESTION" is softer than "PROPOSED"

For genuinely uncertain choices, label the recommended option "MY SUGGESTION" or "← what I'd lean towards" — invites them to override.

"PROPOSED" reads as a fait accompli — save it for cases where engineering needs to push back firmly, i.e. where the constraint is not the stakeholder's to relax because something outside their remit depends on it.

### Rule 11: Connect new scenarios to confirmed envelopes

When a new scenario fits the same shape as one the stakeholder has previously confirmed, reference it explicitly — reduces cognitive load and offers a low-effort "use the same envelope" answer.

Example: "this matches the same envelope I asked you to confirm in my earlier email"

### Rule 12: Follow-ups are compressed recap, NOT re-explanation

A follow-up email is a memory jog, not a redo. They already have the original. Re-explaining the rationale signals you don't think they read it; that's worse than silence.

**Do:**
- One-line factual update on what (if anything) has changed since the original ("same alert fired again at 02:00, no new records affected").
- Compressed recap of the choice — each option as ONE LINE with the resulting value next to it. No rationale text.
- Pre-baked one-word replies they can fire from a phone — reduce each option to a single distinct word and say "a one-word reply is enough".
- Apology + escape hatch upfront ("no rush; please ignore if you've already replied and I've missed it").
- Optional non-email exit ("happy to jump on a 10-minute call instead if simpler").

**Don't:**
- Re-quote their prior answers (they're in the original; quoting again reads as nagging).
- Re-derive the worked example (the "Currently / After" table from the original is enough).
- Add new options the original didn't have (creates confusion; if you have new options, send a new email, not a follow-up).
- Add urgency words ("urgent", "blocking", "by EOD") unless something genuinely changed (e.g. a deadline the decision now sits behind).
- Repeat the rationale for your suggestion — the original said it; saying it again won't change their answer.

**Why:** Validated on a real follow-up (#895). Compressed format respects the reader's time and signals confidence in the original ask; re-explaining would have signalled doubt and made the third email harder to send.

### Formatting Rules (for Outlook readability)

Emails are pasted into Outlook as plain text. Structure them for easy scanning:

1. **Section headers:** ALL CAPS with a line of `─` underneath. One blank line before and after.
2. **One value per line** in examples — never side-by-side columns (wraps badly in Outlook).
3. **Use `←` arrows** to annotate what a value means inline.
4. **Indent with 4 spaces** for data blocks — keeps alignment in monospace.
5. **No markdown tables** — they break in Outlook. Use indented lists or one-per-line format instead.
6. **Number lists for decisions** — `1.` `2.` not bullets. Easier for the reader to reply "1 is correct."
7. **Keep sections short** — if a section exceeds 10 lines, split it into two sections.
8. **Bold via CAPS only** — no `**bold**` markdown, Outlook renders it literally.

### Formatting: "Currently vs After Fix" pattern

When showing before/after for one record, use this vertical layout — one value per line, an arrow on every line whose value moves:

```
Currently on the page (WRONG):

    Input A          2,000.00
    Input B          1,200.00   ← picked up at read time
    Input C            300.00
    Total              120.00   ← does not agree with its own inputs

After the fix (CORRECT):

    Input A          2,000.00
    Input B          1,150.00   ← recomputed on the correct basis
    Input C            290.00
    Total              135.00   ← agrees with its inputs
```

### Formatting: Multi-record impact list

When listing affected records, one per line with inline context:

```
    #41:  two inputs recomputed   → total 120.00 → 135.00
    #57:  one input recomputed    → total  88.00 →  91.50
```

Never use markdown tables for this — they wrap and break alignment.

### Email Template

```
Subject: [Feature] — Confirming expected values before implementation

Hi <first name>,

[1-2 sentence context. Apologise if previous email was unclear.]


THE RULE I'M IMPLEMENTING
─────────────────────────

[2-3 bullet points describing the rule in plain English]

- [Rule 1]
- [Rule 2]


WORKED EXAMPLE: <record ref>
───────────────────────────

[1-2 sentence setup: which record, which inputs are in question]

Currently on the page (WRONG):

    Input A         XX,XXX.XX
    Input B         XX,XXX.XX   ← explanation
    Input C          X,XXX.XX
    Total            X,XXX.XX   ← does NOT agree with its inputs

After the fix (CORRECT):

    Input A         XX,XXX.XX
    Input B        ~XX,XXX      ← recomputed on the correct basis
    Input C         ~X,XXX      ← recomputed on the correct basis
    Total            X,XXX.XX   ← agrees with its inputs


[OPTIONAL: ADDITIONAL IMPACT section if other records change]


PLEASE CONFIRM
──────────────

1. The expected values above are correct
2. [Second specific question if needed]

If anything looks off or you'd like any values adjusted, just let me know.

Best regards,
Milos
```
