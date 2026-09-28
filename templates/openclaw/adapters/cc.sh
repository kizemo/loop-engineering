#!/usr/bin/env bash
# templates/openclaw/adapters/cc.sh
# Claude Code hook adapter (Linux/macOS Git Bash).
# Behavior: read stdin → IPC call to server → fallback spawn server + retry.
#
# stdin:  JSON {"tool_name": "Bash", "tool_input": {...}, "cwd": "..."}
# stdout: (none expected)
# stderr: blocker reason on exit=2, ipc-failed on exit=1
# exit:   0 = allow, 2 = block, 1 = infra error (CC surfaces stderr to user)
#
# Env:
#   LOOPX_GUARD_SOCK  override Unix socket path (default from ipc/platform.ts)
#   LOOPX_GUARD_PID   override PID file path (default /tmp/loopx-guard.pid)

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Convert to forward-slash style. Avoids two issues:
#   1. MSYS '/f/soft/...' gets mangled by Node ESM into 'F:\f\soft\...'
#      (the backslashes after F: are interpreted as \f form-feed escape).
#   2. JS strict mode forbids octal-style escapes ('\s', '\0', '\a') in
#      string literals, so 'F:\soft\...' inside a JS '...' breaks parsing.
# cygpath -m emits drive-letter + forward slashes (e.g. F:/soft/...), which
# Node ESM accepts on all platforms.
if command -v cygpath >/dev/null 2>&1; then
  SCRIPT_DIR="$(cygpath -m "$SCRIPT_DIR")"
fi
SERVER="$SCRIPT_DIR/../ipc/server.ts"
PID_FILE="${LOOPX_GUARD_PID:-/tmp/loopx-guard.pid}"

input="$(cat)"

# Parse stdin: CC sends {tool_name, tool_input, cwd}; IPC needs {toolName, params, cwd}.
# Fail-soft allow on parse failure (don't block legitimate commands on hook error).
parsed="$(printf '%s' "$input" | python -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print('PARSE_FAIL')
    sys.exit(0)
print(json.dumps({
    'toolName': d.get('tool_name') or d.get('toolName') or 'unknown',
    'params': d.get('tool_input') or d.get('params') or {},
    'cwd': d.get('cwd'),
}))
" 2>/dev/null)" || parsed="PARSE_FAIL"

if [ -z "$parsed" ] || [ "$parsed" = "PARSE_FAIL" ]; then
  exit 0
fi

# IPC call. Heredoc (unquoted) expands $SCRIPT_DIR.
# Pass SCRIPT_DIR via env so the Node script can build a file:// URL via
# pathToFileURL() — required on Windows where absolute paths must be file:// URLs
# (e.g. file:///F:/soft/.../client.ts), and on Linux/macOS it handles spaces
# and unicode characters in paths.
call_ipc() {
  local payload="$1"
  # `-` placeholder tells node to read script source from stdin (the heredoc).
  # The JSON payload is passed as argv[2]; `-` consumes argv[1].
  CC_SCRIPT_DIR="$SCRIPT_DIR" node --input-type=module - "$payload" <<'NODE_EOF'
import { pathToFileURL } from 'node:url';

const clientUrl = pathToFileURL(process.env.CC_SCRIPT_DIR + '/../ipc/client.ts').href;
const { ipcCheck } = await import(clientUrl);

let req;
try { req = JSON.parse(process.argv[2]); }
catch (e) {
  process.stderr.write('cc.sh: ipc-payload-parse-failed: ' + e.message + '\n');
  process.exit(1);
}
try {
  const r = await ipcCheck(req);
  const blocker = r.results && r.results.find(x => x.block);
  if (blocker) {
    process.stderr.write(blocker.reason || '[' + blocker.check + '] BLOCKED\n');
    process.exit(2);
  }
  process.exit(0);
} catch (e) {
  process.stderr.write('ipc-failed: ' + e.message + '\n');
  process.exit(1);
}
NODE_EOF
}

call_ipc "$parsed"
exit_code=$?

# Fallback: IPC failed → spawn server (if not running) + retry once.
if [ $exit_code -eq 1 ]; then
  need_start=1
  if [ -f "$PID_FILE" ]; then
    old_pid="$(cat "$PID_FILE" 2>/dev/null || echo '')"
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
      need_start=0
    fi
  fi
  if [ $need_start -eq 1 ]; then
    nohup node "$SERVER" >/dev/null 2>&1 &
    echo $! > "$PID_FILE" 2>/dev/null || true
    sleep 2
  fi
  call_ipc "$parsed"
  exit_code=$?
fi

exit $exit_code