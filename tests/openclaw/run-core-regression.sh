#!/usr/bin/env bash
# tests/openclaw/run-core-regression.sh
# Regression test for Task 1 (Core logic extraction).
# Mirrors templates/hooks/guard-rails-test.sh exactly: same fixtures,
# runs BOTH the original hook AND the new TS core, asserts both match
# the expected exit code.
#
# Gate (per plan Task 1): 39/39 cases must pass for BOTH old and new implementations.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUN_CHECK="$SCRIPT_DIR/run-check.ts"

PASS=0
FAIL=0

red()    { printf '\033[31m%s\033[0m' "$1"; }
green()  { printf '\033[32m%s\033[0m' "$1"; }

make_input() {
    local tool_name="$1"
    local tool_input_json="$2"
    printf '{"tool_name":"%s","tool_input":%s}' "$tool_name" "$tool_input_json"
}

# run_case <name> <expected_exit> <old_hook_cmd> <input>
run_case() {
    local name="$1"
    local expected="$2"
    local old_cmd="$3"
    local input="$4"

    # 1. Run OLD hook
    local old_exit=0
    eval "$old_cmd" >/dev/null 2>/dev/null <<<"$input" || old_exit=$?

    # 2. Run NEW TS core
    local new_exit=0
    node "$RUN_CHECK" >/dev/null 2>/dev/null <<<"$input" || new_exit=$?

    # 3. Assert both match expected
    if [ "$old_exit" -eq "$expected" ] && [ "$new_exit" -eq "$expected" ]; then
        green "  PASS"; printf ' %s (old=%d new=%d)\n' "$name" "$old_exit" "$new_exit"
        PASS=$((PASS + 1))
    else
        red "  FAIL"; printf ' %s\n    expected=%d old=%d new=%d\n' "$name" "$expected" "$old_exit" "$new_exit"
        FAIL=$((FAIL + 1))
    fi
}

echo "== guard-secret-files =="
run_case "allow: regular .md file" 0 \
    "node '$REPO_ROOT/templates/hooks/guard-secret-files.js'" \
    "$(make_input Edit '{"file_path":"docs/notes.md"}')"
run_case "block: .env file" 2 \
    "node '$REPO_ROOT/templates/hooks/guard-secret-files.js'" \
    "$(make_input Write '{"file_path":"src/.env"}')"
run_case "block: .pem file" 2 \
    "node '$REPO_ROOT/templates/hooks/guard-secret-files.js'" \
    "$(make_input Edit '{"file_path":"certs/server.pem"}')"
run_case "block: sqlite3 file" 2 \
    "node '$REPO_ROOT/templates/hooks/guard-secret-files.js'" \
    "$(make_input Write '{"file_path":"data/app.sqlite3"}')"
run_case "block: Windows path with backslash" 2 \
    "node '$REPO_ROOT/templates/hooks/guard-secret-files.js'" \
    "$(make_input Write '{"file_path":"C:\\\\Users\\\\foo\\\\credentials.json"}')"
run_case "allow: file_path empty (skip)" 0 \
    "node '$REPO_ROOT/templates/hooks/guard-secret-files.js'" \
    "$(make_input Write '{}')"

echo
echo "== guard-main-branch-push =="
run_case "allow: git push origin feature-branch" 0 \
    "python '$REPO_ROOT/templates/hooks/guard-main-branch-push.py'" \
    "$(make_input Bash '{"command":"git push origin feature-x"}')"
run_case "block: git push origin main" 2 \
    "python '$REPO_ROOT/templates/hooks/guard-main-branch-push.py'" \
    "$(make_input Bash '{"command":"git push origin main"}')"
run_case "block: git push origin master" 2 \
    "python '$REPO_ROOT/templates/hooks/guard-main-branch-push.py'" \
    "$(make_input Bash '{"command":"git push origin master"}')"
run_case "block: git push -f" 2 \
    "python '$REPO_ROOT/templates/hooks/guard-main-branch-push.py'" \
    "$(make_input Bash '{"command":"git push -f origin dev"}')"
run_case "allow: --dry-run push" 0 \
    "python '$REPO_ROOT/templates/hooks/guard-main-branch-push.py'" \
    "$(make_input Bash '{"command":"git push --dry-run origin main"}')"
run_case "allow: non-git command" 0 \
    "python '$REPO_ROOT/templates/hooks/guard-main-branch-push.py'" \
    "$(make_input Bash '{"command":"echo hello"}')"

echo
echo "== guard-db-migration =="
run_case "allow: alembic upgrade --sql dry-run" 0 \
    "bash '$REPO_ROOT/templates/hooks/guard-db-migration.sh'" \
    "$(make_input Bash '{"command":"alembic upgrade head --sql"}')"
run_case "block: alembic upgrade head" 2 \
    "bash '$REPO_ROOT/templates/hooks/guard-db-migration.sh'" \
    "$(make_input Bash '{"command":"alembic upgrade head"}')"
run_case "block: manage.py migrate" 2 \
    "bash '$REPO_ROOT/templates/hooks/guard-db-migration.sh'" \
    "$(make_input Bash '{"command":"python manage.py migrate"}')"
run_case "allow: manage.py migrate --plan" 0 \
    "bash '$REPO_ROOT/templates/hooks/guard-db-migration.sh'" \
    "$(make_input Bash '{"command":"python manage.py migrate --plan"}')"
run_case "block: prisma migrate deploy" 2 \
    "bash '$REPO_ROOT/templates/hooks/guard-db-migration.sh'" \
    "$(make_input Bash '{"command":"prisma migrate deploy"}')"
run_case "block: dbt run tag:prod" 2 \
    "bash '$REPO_ROOT/templates/hooks/guard-db-migration.sh'" \
    "$(make_input Bash '{"command":"dbt run --select tag:prod"}')"
run_case "allow: dbt run tag:dev" 0 \
    "bash '$REPO_ROOT/templates/hooks/guard-db-migration.sh'" \
    "$(make_input Bash '{"command":"dbt run --select tag:dev"}')"
run_case "block: DROP TABLE" 2 \
    "bash '$REPO_ROOT/templates/hooks/guard-db-migration.sh'" \
    "$(make_input Bash "$(printf '%s' '{"command":"psql -c \"DROP TABLE users;\""}')")"
run_case "allow: SELECT query" 0 \
    "bash '$REPO_ROOT/templates/hooks/guard-db-migration.sh'" \
    "$(make_input Bash "$(printf '%s' '{"command":"psql -c \"SELECT * FROM users;\""}')")"

echo
echo "== guard-package-publish =="
run_case "allow: npm publish --dry-run" 0 \
    "bash '$REPO_ROOT/templates/hooks/guard-package-publish.sh'" \
    "$(make_input Bash '{"command":"npm publish --dry-run"}')"
run_case "block: npm publish" 2 \
    "bash '$REPO_ROOT/templates/hooks/guard-package-publish.sh'" \
    "$(make_input Bash '{"command":"npm publish"}')"
run_case "allow: npm publish --tag next" 0 \
    "bash '$REPO_ROOT/templates/hooks/guard-package-publish.sh'" \
    "$(make_input Bash '{"command":"npm publish --tag next"}')"
run_case "block: twine upload" 2 \
    "bash '$REPO_ROOT/templates/hooks/guard-package-publish.sh'" \
    "$(make_input Bash '{"command":"twine upload dist/*"}')"
run_case "allow: twine upload --repository testpypi" 0 \
    "bash '$REPO_ROOT/templates/hooks/guard-package-publish.sh'" \
    "$(make_input Bash '{"command":"twine upload --repository testpypi dist/*"}')"
run_case "block: vsce publish" 2 \
    "bash '$REPO_ROOT/templates/hooks/guard-package-publish.sh'" \
    "$(make_input Bash '{"command":"vsce publish"}')"
run_case "block: gh release create" 2 \
    "bash '$REPO_ROOT/templates/hooks/guard-package-publish.sh'" \
    "$(make_input Bash '{"command":"gh release create v1.0.0"}')"
run_case "allow: gh release create --draft" 0 \
    "bash '$REPO_ROOT/templates/hooks/guard-package-publish.sh'" \
    "$(make_input Bash '{"command":"gh release create v1.0.0 --draft"}')"
run_case "block: cargo publish" 2 \
    "bash '$REPO_ROOT/templates/hooks/guard-package-publish.sh'" \
    "$(make_input Bash '{"command":"cargo publish"}')"
run_case "allow: cargo publish --dry-run" 0 \
    "bash '$REPO_ROOT/templates/hooks/guard-package-publish.sh'" \
    "$(make_input Bash '{"command":"cargo publish --dry-run"}')"

echo
echo "== guard-installer-path =="
run_case "allow: write to target/release/bundle/" 0 \
    "bash '$REPO_ROOT/templates/hooks/guard-installer-path.sh'" \
    "$(make_input Write '{"file_path":"target/release/bundle/installer.exe"}')"
run_case "allow: write to release/installer.exe" 0 \
    "bash '$REPO_ROOT/templates/hooks/guard-installer-path.sh'" \
    "$(make_input Write '{"file_path":"release/installer.exe"}')"
run_case "block: write to /usr/bin/installer.exe" 2 \
    "bash '$REPO_ROOT/templates/hooks/guard-installer-path.sh'" \
    "$(make_input Write '{"file_path":"/usr/bin/installer.exe"}')"
run_case "block: write to C:\\Windows\\installer.exe" 2 \
    "bash '$REPO_ROOT/templates/hooks/guard-installer-path.sh'" \
    "$(make_input Write '{"file_path":"C:\\\\Windows\\\\installer.exe"}')"
run_case "block: Bash command writing to root" 2 \
    "bash '$REPO_ROOT/templates/hooks/guard-installer-path.sh'" \
    "$(make_input Bash '{"command":"curl -o /usr/local/bin/installer.exe https://example.com/installer.exe"}')"
run_case "allow: write .md file" 0 \
    "bash '$REPO_ROOT/templates/hooks/guard-installer-path.sh'" \
    "$(make_input Write '{"file_path":"docs/readme.md"}')"
run_case "allow: no installer files in input" 0 \
    "bash '$REPO_ROOT/templates/hooks/guard-installer-path.sh'" \
    "$(make_input Bash '{"command":"echo hello"}')"

echo
TOTAL=$((PASS + FAIL))
if [ "$FAIL" -eq 0 ]; then
    green "  $PASS / $TOTAL passed (both old + new TS core match expected behavior)"
    exit 0
else
    red "  $PASS passed, $FAIL failed (total $TOTAL)"
    exit 1
fi
