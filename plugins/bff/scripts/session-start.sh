#!/usr/bin/env bash
# BFF Brain — SessionStart hook.
# Records the session, loads the operator's long-term memory + the firm index,
# and tells Claude to run the operator check-in before its first piece of work.
set -u

# The nightly summariser runs Claude headless; it must not check in or log itself.
[ -n "${BFF_SYNC:-}" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
BFF_HOME="${BFF_HOME:-$HOME/.bff}"
CONFIG="$BFF_HOME/config.json"
STATE_DIR="$BFF_HOME/state"
BFF="$ROOT/bin/bff"
mkdir -p "$STATE_DIR"
# Remember where the current plugin version lives, for the nightly job.
printf '%s\n' "$ROOT" > "$BFF_HOME/plugin_root"

INPUT="$(cat)"
SID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty')
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty')
SOURCE=$(printf '%s' "$INPUT" | jq -r '.source // "startup"')
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
[ -z "$SID" ] && exit 0
STATE="$STATE_DIR/$SID.json"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# --- create / refresh this session's state file -----------------------------
if [ -f "$STATE" ]; then
  tmp=$(mktemp)
  jq --arg tp "$TRANSCRIPT" --arg now "$NOW" \
     '.transcript_path = (if $tp == "" then .transcript_path else $tp end) | .last_start = $now' \
     "$STATE" > "$tmp" && mv "$tmp" "$STATE"
else
  jq -n --arg sid "$SID" --arg tp "$TRANSCRIPT" --arg cwd "$CWD" --arg now "$NOW" \
     '{session_id:$sid, transcript_path:$tp, cwd:$cwd, started_at:$now, last_start:$now,
       operator:null, log:null, privileged:false, synced_mtime:0}' > "$STATE"
fi

# --- machine config ----------------------------------------------------------
DEFAULT_OP=""; BRAIN=""; CFG_LOG=""
if [ -f "$CONFIG" ]; then
  DEFAULT_OP=$(jq -r '.operator // empty' "$CONFIG")
  BRAIN=$(jq -r '.brain_dir // empty' "$CONFIG")
  CFG_LOG=$(jq -r '.log_default // empty' "$CONFIG")
fi
BRAIN="${BRAIN:-$BFF_HOME/brain}"
BRAIN="${BRAIN/#\~/$HOME}"
TEAM="$BRAIN/firm/team.json"   # the team list lives in the private Brain

# A new key file was AirDropped (first install or after a key change): install it before pulling.
if [ -d "$BRAIN/.git" ] && [ -n "$(ls "$HOME/Downloads"/bff-brain*.key "$HOME/Desktop"/bff-brain*.key 2>/dev/null)" ]; then
  "$BFF" setup >/dev/null 2>&1 || true
fi

# Refresh the local copy of the Brain in the background (never block startup).
if [ -d "$BRAIN/.git" ]; then
  ( git -C "$BRAIN" pull -q --rebase --autostash >/dev/null 2>&1 & ) 2>/dev/null
fi

S_OP=$(jq -r '.operator // empty' "$STATE")
S_LOG=$(jq -r 'if .log == null then "" else (.log|tostring) end' "$STATE")
S_PRIV=$(jq -r '.privileged // false' "$STATE")

ROSTER=$(jq -r '.operators[] | "- \(.id): \(.name) — \(.role)"' "$TEAM" 2>/dev/null)
NAMES=$(jq -r '[.operators[].name | split(" ")[0]] | join(", ")' "$TEAM" 2>/dev/null)
NEVER=$(jq -r '[.operators[] | select(.log_default=="never") | "\(.name | split(" ")[0]) (\(.role))"] | join(", ")' "$TEAM" 2>/dev/null)
op_field() { jq -r --arg id "$1" --arg f "$2" '.operators[] | select(.id==$id) | .[$f] // empty' "$TEAM" 2>/dev/null; }

load_file() { # path, max bytes
  [ -f "$1" ] || return 0
  head -c "${2:-12000}" "$1"
}

CTX="# BFF Brain (plugin)
You are working for Blockchain Founders Fund (BFF). This session's id is: $SID
BFF command-line helper — wherever these instructions say \`bff\`, run it as: \"$BFF\"

Team (operator ids):
${ROSTER:-(not available until the Brain is downloaded; see below)}
"

if [ ! -d "$BRAIN/.git" ]; then
  CTX="$CTX
FIRST SESSION ON THIS MAC: the BFF Brain isn't downloaded yet. Before the check-in, tell the user in one line \"First time on this Mac: setting up the BFF Brain.\", then run: bff setup
- It finds the bff-brain.key file their BFF admin sent (AirDrop puts it in Downloads), downloads the Brain and prints the team list. Use that list for the check-in below, and show the user the ✓ lines.
- If it says no key was found: ask the user to drag the bff-brain.key file into this chat, then run: bff setup --key \"<that path>\". If they don't have it yet, tell them to ask their BFF admin, skip the check-in, and carry on with their request (the next session retries).
- Never print, read out or copy the key file's contents.
"
fi

if [ -n "$S_OP" ] && [ -n "$S_LOG" ]; then
  # Resumed / compacted session: check-in already done.
  NAME=$(op_field "$S_OP" name)
  if [ "$S_LOG" = "true" ]; then LOGTXT="ON (this session will be summarised into $NAME's long-term memory tonight)"; else LOGTXT="OFF (off the record)"; fi
  [ "$S_PRIV" = "true" ] && LOGTXT="OFF — marked privileged, never synced"
  CTX="$CTX
## Check-in already done for this session
Operator: $NAME ($S_OP). Logging: $LOGTXT. Do NOT ask again.
"
  MEM_OP="$S_OP"
else
  # New session: tell Claude to run the check-in.
  if [ -n "$DEFAULT_OP" ]; then
    DNAME=$(op_field "$DEFAULT_OP" name)
    OP_HINT="This machine's usual operator is $DNAME ($DEFAULT_OP); offer them as the first option, marked (Recommended)."
    POLICY="${CFG_LOG:-$(op_field "$DEFAULT_OP" log_default)}"
  else
    OP_HINT="No usual operator is configured on this machine."
    POLICY=""
  fi
  CTX="$CTX
## Operator check-in (do this FIRST, once per session)
Before you start on the user's first request, ask the check-in with the AskUserQuestion tool in ONE call with two questions (if that tool is unavailable, ask in one short line of text):
1. \"Who's operating this session?\" — options: the team members (${NAMES:-from the team list}; the tool caps options at 4, so list the 3 most likely plus rely on 'Other' for the rest). $OP_HINT
2. \"Log this session to your long-term memory in the BFF Brain?\" — options: \"Yes, log it\" (tonight's sync summarises it into your memory) and \"No, off the record\". If the operator is likely ${NEVER:-someone whose logging default is \"never\"}, put \"No, off the record\" first: legal/privileged work must not be logged by default.
Then record the answers by running:
  bff session $SID --operator <id> --log <yes|no>
That command prints the operator's long-term memory: read it and use it as background for the rest of the session. Then carry on with the user's request in the same turn.
Machine logging policy for the usual operator: ${POLICY:-ask}. If it is \"always\", skip question 2, set --log yes and say in one line \"Logging this session to <name>'s memory — say 'off the record' to stop.\" If it is \"never\", skip question 2 and set --log no unless they ask to log.
"
  MEM_OP="$DEFAULT_OP"
fi

CTX="$CTX
## During the session
- If the operator says \"off the record\", \"don't log this\" or \"privileged\", run: bff session $SID --log no  (add --privileged for legal/privileged matters) and confirm in one line.
- If they say \"log this\" / \"actually, log it\", run: bff session $SID --log yes
- If they switch operator mid-session, run: bff session $SID --operator <id>
- If they ask you to remember something specific (\"remember that…\"), run: bff remember \"<the fact, one line>\"
- Never put passwords, private keys, seed phrases or API keys in anything you log or remember.
- The BFF Brain lives in: $BRAIN — companies/<slug>.md (one living page per portfolio company/prospect), founders/, lps/, people/<id>/MEMORY.md + sessions/, firm/ (INDEX, decisions, REVIEW). Whenever a company, founder or LP comes up, Grep for it there FIRST and use its page as background (cite it). For live numbers, Airtable/Notion are the source of truth.
"

if [ -n "$MEM_OP" ] && [ -d "$BRAIN" ]; then
  MEM=$(load_file "$BRAIN/people/$MEM_OP/MEMORY.md" 12000)
  [ -n "$MEM" ] && CTX="$CTX
## Long-term memory — $(op_field "$MEM_OP" name) (loaded because they are the session's or machine's operator; if someone else is operating, ignore this and use what the session command prints)
$MEM
"
fi
if [ -d "$BRAIN" ]; then
  IDX=$(load_file "$BRAIN/firm/INDEX.md" 8000)
  [ -n "$IDX" ] && CTX="$CTX
## Firm memory index (BFF Brain)
$IDX
"
fi

jq -n --arg ctx "$CTX" '{hookSpecificOutput:{hookEventName:"SessionStart", additionalContext:$ctx}}'
exit 0
