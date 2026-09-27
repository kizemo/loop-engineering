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
  # Reviewer round 1 fix (Important 1): bash suspends `set -e` across command
  # substitutions, and pipefail is not enabled, so a jq failure inside a
  # `local x=$(jq ... | tr | sort)` pipeline is silently swallowed (sort
  # succeeds on empty input). Check jq's exit code explicitly BEFORE piping
  # its stdout through tr/sort, and return 2 to signal detector failure to
  # the dispatcher.
  local old_fields new_fields jq_out
  if ! jq_out=$(jq -r '. as $doc | paths(scalars) as $p | $p | join(".") + ":" + ($doc | getpath($p) | type)' "$old" 2>/dev/null); then
    return 2
  fi
  old_fields=$(printf '%s\n' "$jq_out" | tr -d '\r' | sort)
  if ! jq_out=$(jq -r '. as $doc | paths(scalars) as $p | $p | join(".") + ":" + ($doc | getpath($p) | type)' "$new" 2>/dev/null); then
    return 2
  fi
  new_fields=$(printf '%s\n' "$jq_out" | tr -d '\r' | sort)

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

  # Strip CR: grep on Windows Git Bash emits CRLF; sort -u preserves CR per
  # line, then `grep -qF "$cmd"` (CR-stripped) never matches → spurious
  # "new command" / "removed command" errors. Same Windows CR trap as
  # interface_detect.
  local old_cmds=$(grep -oE 'loopx [a-z][a-z-]+' "$old" 2>/dev/null | tr -d '\r' | sort -u)
  local new_cmds=$(grep -oE 'loopx [a-z][a-z-]+' "$new" 2>/dev/null | tr -d '\r' | sort -u)

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

  # Strip CR: grep on Windows Git Bash emits CRLF; cut keeps the trailing \r
  # in the value, so [ "$old_exit" != "$new_exit" ] always fires → spurious
  # "exit_code changed" / "JSONL fields missing" errors. Normalize BEFORE cut.
  local old_exit=$(grep '^exit_code=' "$old" | tr -d '\r' | cut -d= -f2)
  local new_exit=$(grep '^exit_code=' "$new" | tr -d '\r' | cut -d= -f2)
  local old_jsonl_keys=$(grep '^jsonl=' "$old" | tr -d '\r' | sed 's/.*"hook_name"[^,]*,"tool_name"[^,]*,"block_reason"[^,]*,"exit_code".*/full_fields/' || echo "missing")
  local new_jsonl_keys=$(grep '^jsonl=' "$new" | tr -d '\r' | sed 's/.*"hook_name"[^,]*,"tool_name"[^,]*,"block_reason"[^,]*,"exit_code".*/full_fields/' || echo "missing")

  local errors=()
  local warnings=()

  if [ "$old_exit" != "$new_exit" ]; then
    errors+=("hook:exit_code changed $old_exit→$new_exit")
  fi

  if [ "$old_jsonl_keys" != "$new_jsonl_keys" ]; then
    errors+=("hook:JSONL fields missing")
  fi

  # stderr 文案变 = warning
  # Strip CR same as exit_code/jsonl above (Windows Git Bash CRLF trap).
  local old_stderr=$(grep '^stderr=' "$old" | tr -d '\r' | cut -d= -f2-)
  local new_stderr=$(grep '^stderr=' "$new" | tr -d '\r' | cut -d= -f2-)
  if [ "$old_stderr" != "$new_stderr" ]; then
    warnings+=("hook:stderr text changed")
  fi

  printf '{"errors":%s,"warnings":%s}' \
    "$(to_json_array "${errors[@]}")" \
    "$(to_json_array "${warnings[@]}")"
}

# ---------- 主调度 ----------
# Reviewer round 1 fix (Important 1): bash suspends `set -e` across command
# substitutions, so a detector that aborts mid-flight (e.g. jq on malformed
# JSON) would silently produce empty/truncated stdout while exit code stays 0.
# Check each detector's return code explicitly and exit 2 on detector failure
# to keep the fail-closed contract: 0 = detectors ran (may have conflicts),
# 2 = detector itself failed.
INTERFACE_RESULT=$(run_interface_detect) || { echo "ERROR: interface detector failed" >&2; exit 2; }
SKILL_RESULT=$(run_skill_detect) || { echo "ERROR: skill detector failed" >&2; exit 2; }
HOOK_RESULT=$(run_hook_detect) || { echo "ERROR: hook detector failed" >&2; exit 2; }

echo "{\"interface\":$INTERFACE_RESULT,\"skill\":$SKILL_RESULT,\"hook\":$HOOK_RESULT}"