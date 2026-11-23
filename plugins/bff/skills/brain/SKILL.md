---
name: brain
description: Search or add to the BFF Brain — the firm's long-term memory, with one living page per portfolio company, founder and LP, plus decisions and each person's memory. Use whenever a portfolio company, founder, LP or past decision comes up, when the user asks "what do we know about X", "what did we decide", "who owns X", or says "remember that…" / "save this to the Brain".
---

# BFF Brain

Location: the `brain_dir` in `~/.bff/config.json` (default `~/.bff/brain`), a git repo refreshed at every session start. Page templates and rules: `firm/ENTITIES.md`.

```
companies/<slug>.md     one living page per portfolio company / fund investment / prospect
founders/<slug>.md      founders & execs
lps/<slug>.md           LP relationships (no amounts or contact details — those stay in Airtable)
people/<id>/MEMORY.md   each team member's long-term memory;  people/<id>/sessions/ = session notes
firm/INDEX.md           firm overview + recent decisions — start here
firm/team.json          team list, librarian, former members
firm/decisions/         firm-level decisions with rationale
firm/REVIEW.md          this week's contradictions / stale facts to confirm
evals/                  test questions the Brain must answer correctly
```

## Answering
1. `Grep -i` for the name across `companies/ founders/ lps/` (also matches `aliases:`). Read the page.
2. For decisions or history, also grep `firm/decisions/` and `people/*/sessions/`.
3. Snapshot numbers on company pages come from Airtable (refreshed nightly) — for anything time-sensitive, check Airtable/Notion live with the connectors.
4. Cite the page path and the source/date of each fact. Say plainly when the Brain has nothing.

## Adding during a session
- If logging is on, tonight's sync updates the relevant company/founder/LP pages from this session automatically — tell the user that.
- A specific fact for the operator's own memory: `bff remember "fact"`.
- A fact about a company/person when logging is off, or something urgent: edit the page directly following `firm/ENTITIES.md` (dated Timeline line with source), then `git -C <brain> add -A && git -C <brain> commit -m "…" && git -C <brain> push` — the pre-commit hook scans for secrets.
- Never store passwords, keys, seed phrases, wallet addresses, emails/phones, LP commitment amounts, or privileged legal advice.

If `firm/REVIEW.md` lists items owned by the current operator, mention them once at a natural moment.
