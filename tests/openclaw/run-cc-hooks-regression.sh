#!/usr/bin/env bash
# tests/openclaw/run-cc-hooks-regression.sh
# Regression test for Task 2 (CC hook thin wrappers via IPC).
# Starts the IPC server, runs all 38 test cases from guard-rails-test.sh
# through the NEW .ts wrappers, asserts exit codes match the expected values
# from the original test suite.
#
# Gate (per plan §3 Task 2): 38/38 cases must pass via IPC path.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SERVER="$REPO_ROOT/templates/openclaw/ipc/server.ts"

# Pick platform-appropriate default paths
if [[ "$OS" == "Windows_NT" ]] || [[ "$(uname -s 2>/dev/null)" == MINGW* ]] || [[ "$(uname -s 2>/dev/null)" == CYGWIN* ]]; then
  TMPDIR_FOR_TEST="$TEMP"
  if [ -z "$TMPDIR_FOR_TEST" ]; then TMPDIR_FOR_TEST="$USERPROFILE/AppData/Local/Temp"; fi
  SOCK_DEFAULT="\\\\.\\pipe\\loopx-guard-test"
  PID_FILE_DEFAULT="$(echo "$TMPDIR_FOR_TEST" | tr -d '\r')/loopx-guard-test.pid"
else
  SOCK_DEFAULT="/tmp/loopx-guard-test.sock"
  PID_FILE_DEFAULT="/tmp/loopx-guard-test.pid"
fi

SOCK="${LOOPX_GUARD_SOCK:-$SOCK_DEFAULT}"
PID_FILE="${LOOPX_GUARD_PID:-$PID_FILE_DEFAULT}"

PASS=0
FAIL=0

red()    { printf '\033[31m%s\033[0m' "$1"; }
green()  { printf '\033[32m%s\033[0m' "$1"; }

# ---- Start IPC server ----
echo "Starting IPC server at $SOCK..."
# Override socket path for test isolation
SOCK_OVERRIDE="--override-sock=$SOCK"  # noop flag, server reads env var
export LOOPX_GUARD_SOCK="$SOCK"
export LOOPX_GUARD_PID="$PID_FILE"

node "$SERVER" >/tmp/ipc-server-test.log 2>&1 &
SERVER_PID=$!
echo "  Server PID: $SERVER_PID"

# Wait for server (poll for socket existence on Unix; sleep on Windows)
if [ "$(uname -s)" = "MINGW64_NT-*" ] || [[ "$(uname -s)" == MINGW* ]] || [[ "$OS" == "Windows_NT" ]]; then
  sleep 2
else
  for i in 1 2 3 4 5 6 7 8 9 10; do
    [ -S "$SOCK" ] && break
    sleep 0.5
  done
fi

if ! kill -0 "$SERVER_PID" 2>/dev/null; then
  red "  FAIL: server died at startup. See /tmp/ipc-server-test.log\n"
  cat /tmp/ipc-server-test.log
  exit 1
fi

cleanup() {
  kill "$SERVER_PID" 2>/dev/null
  wait "$SERVER_PID" 2>/dev/null
  [ -S "$SOCK" ] && rm -f "$SOCK" 2>/dev/null
  [ -f "$PID_FILE" ] && rm -f "$PID_FILE" 2>/dev/null
}
trap cleanup EXIT

echo

# ---- Helper: make input JSON (matches Claude Code format) ----
make_input() {
    local tool_name="$1"
    local tool_input_json="$2"
    printf '{"tool_name":"%s","tool_input":%s}' "$tool_name" "$tool_input_json"
}

# ---- run_case: assert exit code matches expected ----
run_case() {
    local name="$1"
    local expected="$2"
    local hook_path="$3"
    local input="$4"

    local actual=0
    node "$hook_path" >/dev/null 2>/dev/null <<<"$input" || actual=$?

    if [ "$actual" -eq "$expected" ]; then
        green "  PASS"; printf ' %s (exit=%d)\n' "$name" "$actual"
        PASS=$((PASS + 1))
    else
        red "  FAIL"; printf ' %s (expected=%d actual=%d)\n' "$name" "$expected" "$actual"
        FAIL=$((FAIL + 1))
    fi
}

HOOKS="$REPO_ROOT/templates/hooks"

echo "== guard-secret-files =="
run_case "allow: regular .md file" 0 \
    "$HOOKS/guard-secret-files.ts" \
    "$(make_input Edit '{"file_path":"docs/notes.md"}')"
run_case "block: .env file" 2 \
    "$HOOKS/guard-secret-files.ts" \
    "$(make_input Write '{"file_path":"src/.env"}')"
run_case "block: .pem file" 2 \
    "$HOOKS/guard-secret-files.ts" \
    "$(make_input Edit '{"file_path":"certs/server.pem"}')"
run_case "block: sqlite3 file" 2 \
    "$HOOKS/guard-secret-files.ts" \
    "$(make_input Write '{"file_path":"data/app.sqlite3"}')"
run_case "block: Windows path with backslash" 2 \
    "$HOOKS/guard-secret-files.ts" \
    "$(make_input Write '{"file_path":"C:\\\\Users\\\\foo\\\\credentials.json"}')"
run_case "allow: file_path empty (skip)" 0 \
    "$HOOKS/guard-secret-files.ts" \
    "$(make_input Write '{}')"

echo
echo "== guard-main-branch-push =="
run_case "allow: git push origin feature-branch" 0 \
    "$HOOKS/guard-main-branch-push.ts" \
    "$(make_input Bash '{"command":"git push origin feature-x"}')"
run_case "block: git push origin main" 2 \
    "$HOOKS/guard-main-branch-push.ts" \
    "$(make_input Bash '{"command":"git push origin main"}')"
run_case "block: git push origin master" 2 \
    "$HOOKS/guard-main-branch-push.ts" \
    "$(make_input Bash '{"command":"git push origin master"}')"
run_case "block: git push -f" 2 \
    "$HOOKS/guard-main-branch-push.ts" \
    "$(make_input Bash '{"command":"git push -f origin dev"}')"
run_case "allow: --dry-run push" 0 \
    "$HOOKS/guard-main-branch-push.ts" \
    "$(make_input Bash '{"command":"git push --dry-run origin main"}')"
run_case "allow: non-git command" 0 \
    "$HOOKS/guard-main-branch-push.ts" \
    "$(make_input Bash '{"command":"echo hello"}')"

echo
echo "== guard-db-migration =="
run_case "allow: alembic upgrade --sql dry-run" 0 \
    "$HOOKS/guard-db-migration.ts" \
    "$(make_input Bash '{"command":"alembic upgrade head --sql"}')"
run_case "block: alembic upgrade head" 2 \
    "$HOOKS/guard-db-migration.ts" \
    "$(make_input Bash '{"command":"alembic upgrade head"}')"
run_case "block: manage.py migrate" 2 \
    "$HOOKS/guard-db-migration.ts" \
    "$(make_input Bash '{"command":"python manage.py migrate"}')"
run_case "allow: manage.py migrate --plan" 0 \
    "$HOOKS/guard-db-migration.ts" \
    "$(make_input Bash '{"command":"python manage.py migrate --plan"}')"
run_case "block: prisma migrate deploy" 2 \
    "$HOOKS/guard-db-migration.ts" \
    "$(make_input Bash '{"command":"prisma migrate deploy"}')"
run_case "block: dbt run tag:prod" 2 \
    "$HOOKS/guard-db-migration.ts" \
    "$(make_input Bash '{"command":"dbt run --select tag:prod"}')"
run_case "allow: dbt run tag:dev" 0 \
    "$HOOKS/guard-db-migration.ts" \
    "$(make_input Bash '{"command":"dbt run --select tag:dev"}')"
run_case "block: DROP TABLE" 2 \
    "$HOOKS/guard-db-migration.ts" \
    "$(make_input Bash "$(printf '%s' '{"command":"psql -c \"DROP TABLE users;\""}')")"
run_case "allow: SELECT query" 0 \
    "$HOOKS/guard-db-migration.ts" \
    "$(make_input Bash "$(printf '%s' '{"command":"psql -c \"SELECT * FROM users;\""}')")"

echo
echo "== guard-package-publish =="
run_case "allow: npm publish --dry-run" 0 \
    "$HOOKS/guard-package-publish.ts" \
    "$(make_input Bash '{"command":"npm publish --dry-run"}')"
run_case "block: npm publish" 2 \
    "$HOOKS/guard-package-publish.ts" \
    "$(make_input Bash '{"command":"npm publish"}')"
run_case "allow: npm publish --tag next" 0 \
    "$HOOKS/guard-package-publish.ts" \
    "$(make_input Bash '{"command":"npm publish --tag next"}')"
run_case "block: twine upload" 2 \
    "$HOOKS/guard-package-publish.ts" \
    "$(make_input Bash '{"command":"twine upload dist/*"}')"
run_case "allow: twine upload --repository testpypi" 0 \
    "$HOOKS/guard-package-publish.ts" \
    "$(make_input Bash '{"command":"twine upload --repository testpypi dist/*"}')"
run_case "block: vsce publish" 2 \
    "$HOOKS/guard-package-publish.ts" \
    "$(make_input Bash '{"command":"vsce publish"}')"
run_case "block: gh release create" 2 \
    "$HOOKS/guard-package-publish.ts" \
    "$(make_input Bash '{"command":"gh release create v1.0.0"}')"
run_case "allow: gh release create --draft" 0 \
    "$HOOKS/guard-package-publish.ts" \
    "$(make_input Bash '{"command":"gh release create v1.0.0 --draft"}')"
run_case "block: cargo publish" 2 \
    "$HOOKS/guard-package-publish.ts" \
    "$(make_input Bash '{"command":"cargo publish"}')"
run_case "allow: cargo publish --dry-run" 0 \
    "$HOOKS/guard-package-publish.ts" \
    "$(make_input Bash '{"command":"cargo publish --dry-run"}')"

echo
echo "== guard-installer-path =="
run_case "allow: write to target/release/bundle/" 0 \
    "$HOOKS/guard-installer-path.ts" \
    "$(make_input Write '{"file_path":"target/release/bundle/installer.exe"}')"
run_case "allow: write to release/installer.exe" 0 \
    "$HOOKS/guard-installer-path.ts" \
    "$(make_input Write '{"file_path":"release/installer.exe"}')"
run_case "block: write to /usr/bin/installer.exe" 2 \
    "$HOOKS/guard-installer-path.ts" \
    "$(make_input Write '{"file_path":"/usr/bin/installer.exe"}')"
run_case "block: write to C:\\Windows\\installer.exe" 2 \
    "$HOOKS/guard-installer-path.ts" \
    "$(make_input Write '{"file_path":"C:\\\\Windows\\\\installer.exe"}')"
run_case "block: Bash command writing to root" 2 \
    "$HOOKS/guard-installer-path.ts" \
    "$(make_input Bash '{"command":"curl -o /usr/local/bin/installer.exe https://example.com/installer.exe"}')"
run_case "allow: write .md file" 0 \
    "$HOOKS/guard-installer-path.ts" \
    "$(make_input Write '{"file_path":"docs/readme.md"}')"
run_case "allow: no installer files in input" 0 \
    "$HOOKS/guard-installer-path.ts" \
    "$(make_input Bash '{"command":"echo hello"}')"

echo
TOTAL=$((PASS + FAIL))
if [ "$FAIL" -eq 0 ]; then
    green "  $PASS / $TOTAL passed (new .ts wrappers via IPC match expected behavior)"
    exit 0
else
    red "  $PASS passed, $FAIL failed (total $TOTAL)"
    exit 1
fi
