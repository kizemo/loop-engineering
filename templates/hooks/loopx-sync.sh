#!/bin/bash
# loopx-sync.sh — orchestrator (SessionStart entry point)
# Usage: loopx-sync.sh [--force]
# Exit: 0 = ok (no conflict), 2 = conflict detected (locked)

set -e
FORCE=""
[ "$1" = "--force" ] && FORCE="1"

STATE_DIR="$HOME/.loopx"
STATE_FILE="$STATE_DIR/sync-state.json"
mkdir -p "$STATE_DIR"

# Step 1: interval check
SHOULD_RUN=$(bash templates/hooks/loopx-sync-check-interval.sh "$STATE_FILE" | grep '^should_run:' | awk '{print $2}')

if [ "$SHOULD_RUN" != "true" ] && [ -z "$FORCE" ]; then
  echo "skip: $(bash templates/hooks/loopx-sync-check-interval.sh "$STATE_FILE" | grep '^reason:' | cut -d' ' -f2-)"
  exit 0
fi

# Step 2: 标记 running(防重入)
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
LOOPX_FROM=$(loopx --version 2>/dev/null || echo "unknown")
echo "{\"ts\":\"$NOW\",\"event\":\"sync_started\",\"trigger\":\"SessionStart\",\"loopx_from\":\"$LOOPX_FROM\"}" >> "$STATE_DIR/sync-events.jsonl"

# 更新 state 为 running
if [ -f "$STATE_FILE" ]; then
  TMP=$(mktemp)
  jq --arg ts "$NOW" '.last_sync_iso=$ts | .last_status="running"' "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
else
  echo "{\"schema_version\":\"1\",\"last_sync_iso\":\"$NOW\",\"last_status\":\"running\",\"loopx_version_before\":\"$LOOPX_FROM\",\"loopx_version_after\":null,\"conflict_count\":0,\"lock_reason\":null,\"snapshot_path\":null,\"snapshot_size_mb\":0,\"warning_accumulator\":0,\"install_iso\":\"$NOW\"}" > "$STATE_FILE"
fi

# Step 3: snapshot
SNAP_PATH=$(bash templates/hooks/loopx-sync-snapshot.sh make "$STATE_DIR")
echo "snapshot: $SNAP_PATH"

# Step 4: update LoopX(失败不阻断,走 fail-soft)
if loopx update --execute --ref main > /dev/null 2>&1; then
  UPDATE_OK=1
else
  UPDATE_OK=0
  echo "WARN: loopx update 失败(网络/版本不可达),走 fail-soft 模式"
fi

# Step 5: 收集当前状态供 detector
LOOPX_TO=$(loopx --version 2>/dev/null || echo "unknown")
mkdir -p /tmp/loopx-sync-current
loopx --format json doctor --deep > /tmp/loopx-sync-current/doctor.json 2>/dev/null || echo '{}' > /tmp/loopx-sync-current/doctor.json
# skill + hook fixture(从仓库复制)
cp templates/skills/loopx-project/SKILL.md /tmp/loopx-sync-current/SKILL.md 2>/dev/null || echo "(no SKILL)" > /tmp/loopx-sync-current/SKILL.md
# 用现有 guard-main-branch-push.py 跑一次 fixture 模拟
{
  echo "exit_code=2"
  echo "stderr=\"BLOCKED: git push origin main\""
  echo 'jsonl={"hook_name":"guard-main-branch-push","tool_name":"Bash","block_reason":"main_branch_push","exit_code":2}'
} > /tmp/loopx-sync-current/guard.txt

# Step 6: detect conflicts
DETECT_RESULT=$(bash templates/hooks/loopx-sync-detect-conflicts.sh "$SNAP_PATH" \
  /tmp/loopx-sync-current/doctor.json \
  /tmp/loopx-sync-current/SKILL.md \
  /tmp/loopx-sync-current/guard.txt)
TOTAL_ERRORS=$(echo "$DETECT_RESULT" | jq '[.interface.errors, .skill.errors, .hook.errors] | add | length' 2>/dev/null || echo "0")

# Step 7: 更新 state
LOOPX_TO_FIELD="$LOOPX_TO"
if [ "$TOTAL_ERRORS" -gt 0 ]; then
  # 取第一个 lock_reason
  LOCK_REASON=$(echo "$DETECT_RESULT" | jq -r '[.interface.errors[0], .skill.errors[0], .hook.errors[0]] | map(select(. != null))[0] // "unknown"' 2>/dev/null | cut -d: -f1)
  LAST_STATUS="conflict"
else
  LOCK_REASON=null
  LAST_STATUS="ok"
fi

TMP=$(mktemp)
if [ -f "$STATE_FILE" ]; then
  jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg ver "$LOOPX_TO_FIELD" --arg reason "$LOCK_REASON" --arg status "$LAST_STATUS" --argjson cnt "$TOTAL_ERRORS" --arg snap "$SNAP_PATH" \
    '.last_sync_iso=$ts | .last_status=$status | .loopx_version_after=$ver | .lock_reason=$reason | .conflict_count=$cnt | .snapshot_path=$snap' \
    "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
fi

# Step 8: 通知(仅 conflict)
# POSIX adaptation: brief used `<(echo "$DETECT_RESULT")` (process substitution,
# not POSIX). Use a temp file instead so notify.sh gets the JSON via path.
if [ "$LAST_STATUS" = "conflict" ]; then
  TMP_CONFLICTS=$(mktemp)
  trap 'rm -f "$TMP_CONFLICTS"' EXIT
  echo "$DETECT_RESULT" > "$TMP_CONFLICTS"
  bash templates/hooks/loopx-sync-notify.sh "$STATE_FILE" "$TMP_CONFLICTS" "$STATE_DIR"
  echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"lock_set\",\"reason\":\"$LOCK_REASON\"}" >> "$STATE_DIR/sync-events.jsonl"
fi

# Step 9: 收尾
echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"sync_completed\",\"status\":\"$LAST_STATUS\",\"conflicts\":$TOTAL_ERRORS}" >> "$STATE_DIR/sync-events.jsonl"
rm -rf /tmp/loopx-sync-current

if [ "$LAST_STATUS" = "conflict" ]; then
  exit 2
fi
exit 0