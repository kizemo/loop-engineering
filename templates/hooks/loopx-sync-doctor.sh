#!/bin/bash
# loopx-sync-doctor.sh — manual diagnosis report
# Usage: loopx-sync-doctor.sh [--verbose]
# Exit: 0 = clean / 2 = conflict / 4 = state error

set -e
VERBOSE=""
[ "$1" = "--verbose" ] && VERBOSE="1"

# 默认 state path
HOME_LOOPX="$HOME/.loopx"
STATE_FILE="$HOME_LOOPX/sync-state.json"
# Spec §4.2.1: emit doctor_run event at invocation (captures manual trigger).
mkdir -p "$HOME_LOOPX"
echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"doctor_run\",\"verbose\":\"${VERBOSE:-0}\"}" >> "$HOME_LOOPX/sync-events.jsonl" 2>/dev/null || true

if [ ! -f "$STATE_FILE" ]; then
  echo "## LoopX Sync Doctor"
  echo ""
  echo "⚠️ state.json 不存在 → 从未跑过 sync(或未启用 --with-loopx-sync)"
  echo ""
  echo "建议:跑 \`bash templates/hooks/loopx-sync.sh --force\` 触发首次 sync"
  exit 0
fi

LAST_SYNC=$(jq -r '.last_sync_iso' "$STATE_FILE")
LAST_STATUS=$(jq -r '.last_status' "$STATE_FILE")
LOOPX_FROM=$(jq -r '.loopx_version_before // "?"' "$STATE_FILE")
LOOPX_TO=$(jq -r '.loopx_version_after // "?"' "$STATE_FILE")
LOCK_REASON=$(jq -r '.lock_reason // null' "$STATE_FILE")
CONFLICT_COUNT=$(jq -r '.conflict_count // 0' "$STATE_FILE")
SNAP_PATH=$(jq -r '.snapshot_path // null' "$STATE_FILE")

echo "## LoopX Sync Doctor 报告"
echo ""
echo "| 字段 | 值 |"
echo "|---|---|"
echo "| last_sync_iso | $LAST_SYNC |"
echo "| last_status | $LAST_STATUS |"
echo "| loopx 版本 | $LOOPX_FROM → $LOOPX_TO |"
echo "| conflict_count | $CONFLICT_COUNT |"
echo "| lock_reason | ${LOCK_REASON:-无} |"
echo "| snapshot | ${SNAP_PATH:-无} |"
echo ""

if [ "$LAST_STATUS" = "conflict" ]; then
  echo "### ⚠️ 检测到冲突"
  echo ""
  echo "**lock_reason**: $LOCK_REASON"
  echo ""
  echo "### 决策选项"
  echo ""
  echo "- **回滚**(\`bash templates/hooks/loopx-sync-restore.sh\`):还原到 snapshot 版本,适合不熟悉新版本"
  echo "- **接受**(\`bash templates/hooks/loopx-sync-clear-lock.sh\`):已读 changelog,自愿升级"
  echo "- **手动 reconfigure**:修 .claude/guard-rails.yaml 等"
  echo ""
  exit 2
elif [ "$LAST_STATUS" = "error" ]; then
  echo "### ⚠️ 上次 sync 自身失败"
  echo ""
  echo "建议:看 sync-events.jsonl 末 10 行"
  exit 4
else
  echo "### ✓ 当前状态正常"
  echo ""
  echo "无冲突,无需操作。"
fi

# Note: brief's verbose block was below the if/elif/else chain but unreachable
# (else already exits 0). Hoisted above to actually run when --verbose is set.
if [ -n "$VERBOSE" ]; then
  echo ""
  echo "### JSONL 末 10 行"
  if [ -f "$HOME_LOOPX/sync-events.jsonl" ]; then
    tail -10 "$HOME_LOOPX/sync-events.jsonl"
  else
    echo "(no events.jsonl)"
  fi
fi

exit 0