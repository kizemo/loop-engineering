#!/usr/bin/env bash
# tests/openclaw/adapter-cc-test.sh
# Smoke tests for templates/openclaw/adapters/cc.sh
# Covers: happy allow, block paths, stdin parse failures, server fallback.
# Run with: bash tests/openclaw/adapter-cc-test.sh
# Exit: number of failures (0 = all pass)

set -u

CC_SH="$(cd "$(dirname "$0")/../../templates/openclaw/adapters" && pwd)/cc.sh"
PASS=0
FAIL=0
FAIL_MSGS=()

if [ ! -f "$CC_SH" ]; then
  echo "FAIL: cc.sh not found at $CC_SH"
  exit 99
fi

run_case() {
  local name="$1"
  local input="$2"
  local expected_exit="$3"
  local expect_stderr_substring="${5:-}"

  local out err ec
  out="$(printf '%s' "$input" | bash "$CC_SH" 2>/tmp/cc-test-err.$$ 1>/tmp/cc-test-out.$$)"
  ec=$?
  err="$(cat /tmp/cc-test-err.$$ 2>/dev/null || true)"

  if [ "$ec" != "$expected_exit" ]; then
    FAIL=$((FAIL + 1))
    FAIL_MSGS+=("$name: exit=$ec expected=$expected_exit | stderr=$err")
    echo "  FAIL: $name (exit=$ec, expected=$expected_exit)"
  elif [ -n "$expect_stderr_substring" ] && ! [[ "$err" == *"$expect_stderr_substring"* ]]; then
    FAIL=$((FAIL + 1))
    FAIL_MSGS+=("$name: stderr missing '$expect_stderr_substring' | got=$err")
    echo "  FAIL: $name (stderr missing '$expect_stderr_substring')"
  else
    PASS=$((PASS + 1))
    echo "  PASS: $name (exit=$ec)"
  fi
  rm -f /tmp/cc-test-err.$$ /tmp/cc-test-out.$$
}

# Ensure a fresh server state for fallback test: kill any existing + clear pid file.
# Uses PowerShell because MSYS-bash mangles cmd /FI arguments.
kill_server() {
  local pids
  pids="$(powershell -NoProfile -Command \
    "Get-CimInstance Win32_Process -Filter \"Name='node.exe'\" | Where-Object { \$_.CommandLine -like '*ipc/server.ts*' } | ForEach-Object { \$_.ProcessId }" \
    2>/dev/null | grep -E '^[0-9]+$' || true)"
  for pid in $pids; do
    powershell -NoProfile -Command "Stop-Process -Id $pid -Force" >/dev/null 2>&1 || true
  done
  rm -f /tmp/loopx-guard.pid /tmp/loopx-guard.sock
  sleep 1
}

echo "=== cc.sh adapter smoke tests ==="

# Case 1: happy allow (echo hello)
run_case "allow: echo hello" \
  '{"tool_name":"Bash","tool_input":{"command":"echo hello"}}' \
  "0"

# Case 2: block npm publish
run_case "block: npm publish" \
  '{"tool_name":"Bash","tool_input":{"command":"npm publish"}}' \
  "2" \
  "" \
  "BLOCKED"

# Case 3: block git push origin main
run_case "block: git push origin main" \
  '{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}' \
  "2" \
  "" \
  "BLOCKED"

# Case 4: stdin empty → fail-soft allow
run_case "stdin: empty" \
  '' \
  "0"

# Case 5: stdin malformed JSON → fail-soft allow
run_case "stdin: malformed JSON" \
  'this is not json' \
  "0"

# Case 6: stdin with toolName/params (OpenClaw format) → rcmpats with CC format
run_case "stdin: toolName/params (alt field names)" \
  '{"toolName":"Bash","params":{"command":"echo hello"}}' \
  "0"

# Case 7: allow npm publish --dry-run
run_case "allow: npm publish --dry-run" \
  '{"tool_name":"Bash","tool_input":{"command":"npm publish --dry-run"}}' \
  "0"

# Case 8: server fallback spawn (kill server + run allow case → expect 0 after spawn)
echo "  --- server fallback test (will kill server first) ---"
kill_server
sleep 1
run_case "fallback: server not running → spawn + retry" \
  '{"tool_name":"Bash","tool_input":{"command":"echo fallback-test"}}' \
  "0"
if [ ! -f /tmp/loopx-guard.pid ]; then
  FAIL=$((FAIL + 1))
  FAIL_MSGS+=("fallback: pid file not written after spawn")
  echo "  FAIL: fallback: pid file missing"
else
  pid_value="$(cat /tmp/loopx-guard.pid)"
  PASS=$((PASS + 1))
  echo "  PASS: fallback: pid file written (pid=$pid_value)"
fi

echo ""
echo "=== Summary ==="
echo "  $PASS pass, $FAIL fail"

if [ $FAIL -gt 0 ]; then
  echo ""
  echo "Failures:"
  for m in "${FAIL_MSGS[@]}"; do
    echo "  - $m"
  done
fi

exit $FAIL