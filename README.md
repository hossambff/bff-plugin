# BFF Claude plugin

The Claude Code setup for the Blockchain Founders Fund team. Everyone gets the same skills, house style and connectors. Each session can also be logged to the firm's private long-term memory, the **BFF Brain**.

This repo contains no firm data. The team list, notes and pages all live in the private Brain repo, and the plugin downloads it on first use with a key file from your BFF admin.

## Install (once per person)

You need a Mac with Claude Code (the Claude desktop app's **Code** tab is fine).

1. **Install the plugin.** Paste this into Terminal:
   ```bash
   claude plugin marketplace add hossambff/bff-plugin && claude plugin install bff@bff
   ```
   Or type these two lines into Claude Code:
   ```
   /plugin marketplace add hossambff/bff-plugin
   /plugin install bff@bff
   ```
2. **Get the key file.** Accept the `bff-brain.key` file your BFF admin AirDrops you. It lands in Downloads; leave it there.
3. **Start a new Claude Code session.** Claude sets everything up: it downloads the Brain, asks who you are and whether to log the session, and schedules the nightly sync. It also moves the key file somewhere safe (`~/.bff`).

If Claude can't find the key, it asks you to drag the file into the chat.

## What it does

- **Check-in:** each new session asks who's operating and whether to log it. Shared Claude accounts are fine, because logs go to whoever checked in.
- **Memory:** logged sessions are summarised overnight into your long-term memory and into the Brain's company, founder and LP pages. Claude reads those pages whenever a company or person comes up.
- **Privacy:** say "off the record" or "privileged" and the session isn't logged. Secret scanning blocks passwords and keys from ever reaching the Brain.
- **Skills:** `/bff:operator`, `/bff:brain`, `/bff:bff-style`. **Connector:** Notion.

## Day to day

| Say to Claude | What happens |
|---|---|
| "what do we know about <company>?" | Reads that company's Brain page, plus related sessions and decisions |
| "off the record" / "privileged" | This session isn't logged; privileged sessions are never logged |
| "log this" | This session is logged after all |
| "it's <name> now" | Switches operator and loads that person's memory |
| "remember that <fact>" | Saved to your memory now |

Commands (`bff` = `~/.claude/plugins/cache/bff/bff/*/bin/bff`): `bff status` shows what's waiting to sync, and `bff scan` secret-scans the Brain. Logs go to `~/.bff/sync.log`.

## Limits
- **Claude Code only.** Logging and the check-in only work there; regular Claude chats use the "save to Brain" skill instead.
- **Mac only.** The nightly sync uses macOS scheduling. A sleeping Mac catches up when it wakes.
