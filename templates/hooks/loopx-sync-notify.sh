#!/bin/bash
# loopx-sync-notify.sh — write banner + desktop notify + JSONL event
# Usage: loopx-sync-notify.sh <state.json> <conflicts.json> <state_dir>
# Exit: 0 always (notify failure is non-blocking)

set -e
STATE_PATH="$1"
CONFLICTS_PATH="$2"
STATE_DIR="$3"

if [ -z "$STATE_PATH" ] || [ -z "$CONFLICTS_PATH" ] || [ -z "$STATE_DIR" ]; then
  echo "ERROR: 3 args required" >&2
  exit 2
fi

LOCK_REASON=$(jq -r '.lock_reason // "unknown"' "$STATE_PATH")
LOOPX_FROM=$(jq -r '.loopx_version_before // "unknown"' "$STATE_PATH")
LOOPX_TO=$(jq -r '.loopx_version_after // "unknown"' "$STATE_PATH")
CONFLICT_COUNT=$(jq -r '.conflict_count // 0' "$STATE_PATH")
LAST_SYNC=$(jq -r '.last_sync_iso // "unknown"' "$STATE_PATH")

# 写 banner.txt(3 行固定格式)
cat > "$STATE_DIR/sync-banner.txt" <<BANNER
[LoopX 上游] ⚠️ 已检出${CONFLICT_COUNT} 项冲突(${LAST_SYNC},loopx ${LOOPX_FROM}→${LOOPX_TO})
[LoopX 上游] 跑 \`bash templates/hooks/loopx-sync-doctor.sh\` 查看详情
[LoopX 上游] 或 \`bash templates/hooks/loopx-sync-restore.sh\` 一键回滚
BANNER

# JSONL 事件
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "{\"ts\":\"$NOW\",\"event\":\"conflict_detected\",\"reason\":\"$LOCK_REASON\",\"conflicts\":$CONFLICT_COUNT}" >> "$STATE_DIR/sync-events.jsonl"

# 桌面通知(失败不阻断)
if command -v notify-send > /dev/null 2>&1; then
  notify-send "LoopX sync 冲突" "检出 $CONFLICT_COUNT 项冲突,跑 loopx-sync-doctor.sh 查看" 2>/dev/null || true
elif command -v osascript > /dev/null 2>&1; then
  osascript -e "display notification \"检出 $CONFLICT_COUNT 项冲突\" with title \"LoopX sync\"" 2>/dev/null || true
elif command -v powershell.exe > /dev/null 2>&1; then
  powershell.exe -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('LoopX sync: $CONFLICT_COUNT 项冲突', 'LoopX 上游')" 2>/dev/null || true
fi

echo "notified: banner + jsonl + desktop (if available)"
