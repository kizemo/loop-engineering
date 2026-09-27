#!/bin/bash
# loopx-sync-detect-conflicts.sh — run 3 detectors and combine results
# Usage: loopx-sync-detect-conflicts.sh <snapshot_path> <current_doctor_json> <current_skill_md> <current_hook_txt>
# Output: JSON {interface:{errors,warnings},skill:...,hook:...}
# Exit: 0 = detectors ran (may have conflicts), 2 = detector itself failed

set -e
SNAP_PATH="$1"
CUR_DOCTOR="$2"
CUR_SKILL="$3"
CUR_HOOK="$4"

if [ -z "$SNAP_PATH" ] || [ -z "$CUR_DOCTOR" ] || [ -z "$CUR_SKILL" ] || [ -z "$CUR_HOOK" ]; then
  echo "ERROR: 4 args required" >&2
  exit 2
fi

# ---------- helper: bash array → JSON array string ----------
# Brief's pattern (printf | jq -R . | jq -s .) emits [""] on empty input (one
# empty-string element) and breaks with literal newlines when piped through sed.
# This helper produces a clean "[]" for empty and proper "[...]" otherwise.
to_json_array() {
  if [ "$#" -eq 0 ]; then
    printf '[]'
  else
    printf '%s\n' "$@" | jq -R . | jq -s .
  fi
}

# ---------- interface_detect ----------
run_interface_detect() {
  local old="$SNAP_PATH/loopx-state/loopx-doctor-old.json"
  local new="$CUR_DOCTOR"

  if [ ! -f "$old" ] || [ ! -f "$new" ]; then
    echo '{"errors":["fixture_missing"],"warnings":[]}'
    return
  fi

  # Note: brief's literal '.\($p)' form errors with "Cannot index object with array".
  # Correct lookup uses getpath($p), hoisted via $doc so $p is not shadowed.
  # Brief used '.\($p)' inside string interpolation, which errors on Windows
  # with "Cannot index object with array". Hoist via $doc + getpath($p).
  # Also strip trailing CR: jq on Windows emits CRLF, and grep -F strips CR
  # from lines before matching, so a "$line" with \r never matches.
  local old_fields=$(jq -r '. as $doc | paths(scalars) as $p | $p | join(".") + ":" + ($doc | getpath($p) | type)' "$old" 2>/dev/null | tr -d '\r' | sort)
  local new_fields=$(jq -r '. as $doc | paths(scalars) as $p | $p | join(".") + ":" + ($doc | getpath($p) | type)' "$new" 2>/dev/null | tr -d '\r' | sort)

  local errors=()
  local warnings=()

  # 新增字段 = error
  while IFS= read -r line; do
    if ! echo "$old_fields" | grep -qF "$line"; then
      errors+=("interface:new field '$line'")
    fi
  done <<< "$new_fields"

  # 缺失字段 = error
  while IFS= read -r line; do
    if ! echo "$new_fields" | grep -qF "$line"; then
      errors+=("interface:missing field '$line'")
    fi
  done <<< "$old_fields"

  # 同字段值不同 = warning
  while IFS= read -r line; do
    key="${line%%:*}"
    if echo "$new_fields" | grep -qF "$key:"; then
      old_val=$(jq -r ".$key" "$old" 2>/dev/null)
      new_val=$(jq -r ".$key" "$new" 2>/dev/null)
      if [ "$old_val" != "$new_val" ]; then
        warnings+=("interface:value changed for '$key'")
      fi
    fi
  done <<< "$old_fields"

  printf '{"errors":%s,"warnings":%s}' \
    "$(to_json_array "${errors[@]}")" \
    "$(to_json_array "${warnings[@]}")"
}

# ---------- skill_detect ----------
run_skill_detect() {
  local old="$SNAP_PATH/claude-hooks/loopx-skill-fixture/SKILL-old.md"
  local new="$CUR_SKILL"

  if [ ! -f "$old" ] || [ ! -f "$new" ]; then
    echo '{"errors":["fixture_missing"],"warnings":[]}'
    return
  fi

  local old_cmds=$(grep -oE 'loopx [a-z][a-z-]+' "$old" 2>/dev/null | sort -u)
  local new_cmds=$(grep -oE 'loopx [a-z][a-z-]+' "$new" 2>/dev/null | sort -u)

  local errors=()

  while IFS= read -r cmd; do
    [ -z "$cmd" ] && continue
    if ! echo "$new_cmds" | grep -qF "$cmd"; then
      errors+=("skill:removed command '$cmd'")
    fi
  done <<< "$old_cmds"

  while IFS= read -r cmd; do
    [ -z "$cmd" ] && continue
    if ! echo "$old_cmds" | grep -qF "$cmd"; then
      errors+=("skill:new command '$cmd'")
    fi
  done <<< "$new_cmds"

  printf '{"errors":%s,"warnings":[]}' "$(to_json_array "${errors[@]}")"
}

# ---------- hook_detect ----------
run_hook_detect() {
  local old="$SNAP_PATH/claude-hooks/hook-fixture/guard-main-branch-push-old.txt"
  local new="$CUR_HOOK"

  if [ ! -f "$old" ] || [ ! -f "$new" ]; then
    echo '{"errors":["fixture_missing"],"warnings":[]}'
    return
  fi

  local old_exit=$(grep '^exit_code=' "$old" | cut -d= -f2)
  local new_exit=$(grep '^exit_code=' "$new" | cut -d= -f2)
  local old_jsonl_keys=$(grep '^jsonl=' "$old" | sed 's/.*"hook_name"[^,]*,"tool_name"[^,]*,"block_reason"[^,]*,"exit_code".*/full_fields/' || echo "missing")
  local new_jsonl_keys=$(grep '^jsonl=' "$new" | sed 's/.*"hook_name"[^,]*,"tool_name"[^,]*,"block_reason"[^,]*,"exit_code".*/full_fields/' || echo "missing")

  local errors=()
  local warnings=()

  if [ "$old_exit" != "$new_exit" ]; then
    errors+=("hook:exit_code changed $old_exit→$new_exit")
  fi

  if [ "$old_jsonl_keys" != "$new_jsonl_keys" ]; then
    errors+=("hook:JSONL fields missing")
  fi

  # stderr 文案变 = warning
  local old_stderr=$(grep '^stderr=' "$old" | cut -d= -f2-)
  local new_stderr=$(grep '^stderr=' "$new" | cut -d= -f2-)
  if [ "$old_stderr" != "$new_stderr" ]; then
    warnings+=("hook:stderr text changed")
  fi

  printf '{"errors":%s,"warnings":%s}' \
    "$(to_json_array "${errors[@]}")" \
    "$(to_json_array "${warnings[@]}")"
}

# ---------- 主调度 ----------
INTERFACE_RESULT=$(run_interface_detect)
SKILL_RESULT=$(run_skill_detect)
HOOK_RESULT=$(run_hook_detect)

echo "{\"interface\":$INTERFACE_RESULT,\"skill\":$SKILL_RESULT,\"hook\":$HOOK_RESULT}"