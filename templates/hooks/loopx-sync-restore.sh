#!/bin/bash
# loopx-sync-restore.sh — rollback from snapshot
# Usage: loopx-sync-restore.sh [snapshot_path]
# If no arg, use latest snapshot from state.json

set -e
# Fix Round 1: derive absolute script dir + use $HOME for cross-CWD robustness
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

SNAP_ARG="$1"
STATE_FILE="$HOME/.loopx/sync-state.json"
HOOKS_DIR="$HOME/.claude/hooks"

if [ -n "$SNAP_ARG" ]; then
  SNAP_PATH="$SNAP_ARG"
elif [ -f "$STATE_FILE" ]; then
  SNAP_PATH=$(jq -r '.snapshot_path // empty' "$STATE_FILE")
else
  echo "ERROR: 无 snapshot path(请提供第一个参数,或先跑过 sync)" >&2
  exit 2
fi

if [ -z "$SNAP_PATH" ] || [ ! -d "$SNAP_PATH" ]; then
  echo "ERROR: snapshot 不存在: $SNAP_PATH" >&2
  exit 2
fi

echo "→ 还原 $SNAP_PATH → $HOOKS_DIR + $HOME/.loopx"
RESULT=$(bash "$SCRIPT_DIR/loopx-sync-snapshot.sh" restore "$SNAP_PATH" "$HOOKS_DIR" "$HOME/.loopx")
echo "$RESULT"

# Fix Round 1: assert restore actually populated loopx files (fail-closed if not)
RESTORED_DIR="$HOME/.loopx"
if [ ! -d "$RESTORED_DIR/loopx-state" ] && [ ! -f "$RESTORED_DIR/registry.json" ] && [ ! -d "$RESTORED_DIR/codex-goals" ]; then
  echo "ERROR: restore ran but no loopx files present in $RESTORED_DIR" >&2
  exit 2
fi

# 更新 state
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
if [ -f "$STATE_FILE" ]; then
  TMP=$(mktemp)
  jq --arg ts "$NOW" --arg snap "$SNAP_PATH" \
    '.last_sync_iso=$ts | .last_status="ok" | .lock_reason=null | .snapshot_path=$snap | .conflict_count=0' \
    "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
fi

# 删 banner(若存在)
[ -f "$HOME/.loopx/sync-banner.txt" ] && rm "$HOME/.loopx/sync-banner.txt"

# 追加 JSONL
echo "{\"ts\":\"$NOW\",\"event\":\"rollback_executed\",\"snapshot_path\":\"$SNAP_PATH\"}" >> "$HOME/.loopx/sync-events.jsonl"

echo "✓ 回滚完成。下次 SessionStart banner 会清掉。"