#!/bin/bash
# loopx-sync-check-interval.sh — decide if weekly sync should run
# Usage: loopx-sync-check-interval.sh <state.json path>
# Output: "should_run: true|false" + JSON fields to stdout
# Exit: 0 = ok, 2 = state corrupted

set -e
STATE_PATH="$1"
INTERVAL_DAYS=7

if [ -z "$STATE_PATH" ]; then
  echo "ERROR: state path required" >&2
  exit 2
fi

# Case 1: state.json 不存在 → 首次安装,跑
if [ ! -f "$STATE_PATH" ]; then
  echo "should_run: true"
  echo "reason: state_missing"
  exit 0
fi

# 读关键字段(用 jq,要求已装)
LAST_SYNC=$(jq -r '.last_sync_iso // empty' "$STATE_PATH")
LAST_STATUS=$(jq -r '.last_status // empty' "$STATE_PATH")

# 损坏检测
if [ -z "$LAST_SYNC" ] || [ -z "$LAST_STATUS" ]; then
  echo "ERROR: state corrupted (missing last_sync_iso or last_status)" >&2
  exit 2
fi

# Case 4: running 锁 → 跳过(防重入)
if [ "$LAST_STATUS" = "running" ]; then
  echo "should_run: false"
  echo "reason: already_running"
  exit 0
fi

# Case 2/3: 比较时间
LAST_EPOCH=$(date -u -d "$LAST_SYNC" +%s 2>/dev/null || echo "0")
NOW_EPOCH=$(date -u +%s)
INTERVAL_SEC=$((INTERVAL_DAYS * 86400))

if [ "$((NOW_EPOCH - LAST_EPOCH))" -ge "$INTERVAL_SEC" ]; then
  echo "should_run: true"
  echo "reason: interval_exceeded"
else
  echo "should_run: false"
  echo "reason: interval_not_exceeded"
fi
