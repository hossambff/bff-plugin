#!/usr/bin/env bash
# BFF Brain — SessionEnd hook: stamp the end time so the nightly sync knows the
# session is finished. (The sync also works without this, e.g. after a crash.)
set -u
[ -n "${BFF_SYNC:-}" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0
BFF_HOME="${BFF_HOME:-$HOME/.bff}"
SID=$(jq -r '.session_id // empty')
[ -z "$SID" ] && exit 0
STATE="$BFF_HOME/state/$SID.json"
[ -f "$STATE" ] || exit 0
tmp=$(mktemp)
jq --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.ended_at = $now' "$STATE" > "$tmp" && mv "$tmp" "$STATE"
exit 0
