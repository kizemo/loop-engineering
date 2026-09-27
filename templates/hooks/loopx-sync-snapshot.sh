#!/bin/bash
# loopx-sync-snapshot.sh — make or restore pre-sync snapshot
# Usage:
#   loopx-sync-snapshot.sh make <state_dir>            — output: snapshot path
#   loopx-sync-snapshot.sh restore <snap_path> <hooks_dir> <state_dir>

set -e
ACTION="$1"
SNAP_PATH="$2"
HOOKS_DIR="$3"
STATE_DIR="$4"

if [ "$ACTION" = "make" ]; then
  STATE_DIR="$2"
  if [ -z "$STATE_DIR" ]; then
    echo "ERROR: state_dir required for make" >&2
    exit 2
  fi

  SNAP_NAME="$(date -u +%Y-%m-%d-%H%M%S)-pre-sync"
  TARGET="$STATE_DIR/snapshots/$SNAP_NAME"
  mkdir -p "$TARGET/loopx-state" "$TARGET/claude-hooks"

  # 复制 loopx state(若存在)
  if [ -d "$HOME/.loopx/state" ]; then
    cp -r "$HOME/.loopx/state/." "$TARGET/loopx-state/" 2>/dev/null || true
  fi

  # 复制 registry
  if [ -f "$HOME/.loopx/registry.json" ]; then
    cp "$HOME/.loopx/registry.json" "$TARGET/registry.json" 2>/dev/null || true
  fi

  # 复制 codex goals(若存在)
  if [ -d "$HOME/.codex/goals" ]; then
    mkdir -p "$TARGET/codex-goals"
    cp -r "$HOME/.codex/goals/." "$TARGET/codex-goals/" 2>/dev/null || true
  fi

  # 复制 hooks(从 $HOME/.claude/hooks)
  if [ -d "$HOME/.claude/hooks" ]; then
    cp -r "$HOME/.claude/hooks/." "$TARGET/claude-hooks/"
  fi
  if [ -f "$HOME/.claude/guard-rails.yaml" ]; then
    cp "$HOME/.claude/guard-rails.yaml" "$TARGET/claude-hooks/guard-rails.yaml"
  fi

  # 写 manifest.json
  TOTAL_SIZE=$(du -sm "$TARGET" 2>/dev/null | cut -f1)
  cat > "$TARGET/manifest.json" <<MANIFEST
{
  "snapshot_iso": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "loopx_version": "$(loopx --version 2>/dev/null || echo 'unknown')",
  "trigger": "weekly_sync",
  "files": $(find "$TARGET" -type f | sed 's|.*/||' | sort | jq -R . | jq -s .),
  "total_size_mb": ${TOTAL_SIZE:-0}
}
MANIFEST

  echo "$TARGET"

elif [ "$ACTION" = "restore" ]; then
  if [ -z "$SNAP_PATH" ] || [ ! -d "$SNAP_PATH" ]; then
    echo "ERROR: snapshot path missing or invalid: $SNAP_PATH" >&2
    exit 2
  fi
  if [ -z "$HOOKS_DIR" ] || [ -z "$STATE_DIR" ]; then
    echo "ERROR: hooks_dir and state_dir required for restore" >&2
    exit 2
  fi

  RESTORED=0

  # 还原 loopx state(可选源,但若源存在则 fail-closed)
  if [ -d "$SNAP_PATH/loopx-state" ]; then
    mkdir -p "$STATE_DIR/loopx-state"
    if cp -r "$SNAP_PATH/loopx-state/." "$STATE_DIR/loopx-state/"; then
      RESTORED=$((RESTORED + 1))
    else
      echo "ERROR: restore failed for loopx-state" >&2
      exit 2
    fi
  fi

  # 还原 registry(可选源,但若源存在则 fail-closed)
  if [ -f "$SNAP_PATH/registry.json" ]; then
    if cp "$SNAP_PATH/registry.json" "$STATE_DIR/registry.json"; then
      RESTORED=$((RESTORED + 1))
    else
      echo "ERROR: restore failed for registry.json" >&2
      exit 2
    fi
  fi

  # 还原 codex goals(可选源,但若源存在则 fail-closed)
  if [ -d "$SNAP_PATH/codex-goals" ]; then
    mkdir -p "$STATE_DIR/codex-goals"
    if cp -r "$SNAP_PATH/codex-goals/." "$STATE_DIR/codex-goals/"; then
      RESTORED=$((RESTORED + 1))
    else
      echo "ERROR: restore failed for codex-goals" >&2
      exit 2
    fi
  fi

  # 还原 hooks(可选源,但若源存在则 fail-closed)
  if [ -d "$SNAP_PATH/claude-hooks" ]; then
    mkdir -p "$HOOKS_DIR"
    if cp -r "$SNAP_PATH/claude-hooks/." "$HOOKS_DIR/"; then
      RESTORED=$((RESTORED + 1))
    else
      echo "ERROR: restore failed for claude-hooks" >&2
      exit 2
    fi
  fi

  echo "restored: $RESTORED"
  echo "snapshot: $SNAP_PATH"
else
  echo "ERROR: unknown action '$ACTION' (use make|restore)" >&2
  exit 2
fi
