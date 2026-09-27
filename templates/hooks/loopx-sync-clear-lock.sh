#!/bin/bash
# loopx-sync-clear-lock.sh — accept new version, clear lock
# Usage: loopx-sync-clear-lock.sh

set -e
STATE_FILE="$HOME/.loopx/sync-state.json"

if [ ! -f "$STATE_FILE" ]; then
  echo "ERROR: state.json 不存在,无需 clear-lock" >&2
  exit 2
fi

LOCK_REASON=$(jq -r '.lock_reason // null' "$STATE_FILE")
if [ "$LOCK_REASON" = "null" ] || [ -z "$LOCK_REASON" ]; then
  echo "INFO: 当前无 lock,无需 clear"
  exit 0
fi

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
LOOPX_TO=$(jq -r '.loopx_version_after' "$STATE_FILE")

TMP=$(mktemp)
jq --arg ts "$NOW" '.last_sync_iso=$ts | .last_status="ok" | .lock_reason=null | .conflict_count=0' \
  "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"

[ -f "$HOME/.loopx/sync-banner.txt" ] && rm "$HOME/.loopx/sync-banner.txt"

echo "{\"ts\":\"$NOW\",\"event\":\"clear_lock_executed\",\"accepted_version\":\"$LOOPX_TO\"}" >> "$HOME/.loopx/sync-events.jsonl"

echo "✓ Lock cleared,accepted version: $LOOPX_TO"