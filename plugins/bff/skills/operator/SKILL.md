---
name: operator
description: Check in, switch operator, or change logging for this session in the BFF Brain. Use when the user says who they are ("it's <name>", "<name> here"), wants to switch operator, says "off the record", "don't log this", "privileged", "log this session", or asks whether the session is being logged.
---

# Operator & logging

The BFF plugin's session-start note gives you this session's id and the path to the `bff` helper. Use them; never guess a session id.

| User says | Run |
|---|---|
| Who's operating / "it's <name>" | `bff session <SESSION_ID> --operator <id>` |
| "Log this" / "save this to my memory" | `bff session <SESSION_ID> --log yes` |
| "Off the record" / "don't log this" | `bff session <SESSION_ID> --log no` |
| "Privileged" / legal advice from counsel | `bff session <SESSION_ID> --privileged` (never synced, cannot be re-enabled by the sync) |
| "Am I being logged?" | `bff session <SESSION_ID>` (prints current status) |

Operator ids: the team list in the session-start note (it comes from `firm/team.json` in the Brain).

After switching operator, read the memory the command prints and use it as background from then on; drop the previous operator's memory.

Confirm every change in one short line, e.g. "Logging off — this session stays off the record."

How logging works (to explain if asked): nothing leaves the machine during the session. At 23:30 each night, a background job summarises each logged session into `people/<id>/sessions/` in the BFF Brain repo, updates that person's `MEMORY.md` with durable facts, and records firm-level decisions under `firm/decisions/`. Raw transcripts are never uploaded.
