#!/bin/bash
# loopx-sync-test.sh — integration test for Sub-project D
# Usage: bash templates/hooks/loopx-sync-test.sh
# Exit: 0 = all pass, 2 = some fail

# Note: Brief adaptation (Task 3 carry-forward). The brief's literal detect
# tests pass "/tmp/fake" as snapshot path, so all 3 detectors return
# `fixture_missing` and both cases produce errors — making the brief's
# "clean case no errors" assertion impossible. Adapted: build a REAL
# snapshot dir from the *-old.* fixtures before invoking the detector.

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURE_DIR="$SCRIPT_DIR/_sync-fixtures"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# === Unit: interval ===
# Bash locale warning (LC_ALL: cannot change locale zh-CN) pollutes $()
# capture on this Windows env. Filter via 2>/dev/null or grep -v.
result=$(bash "$SCRIPT_DIR/loopx-sync-check-interval.sh" "/tmp/nonexistent.json" 2>/dev/null) || true
echo "$result" | grep -q "should_run: true" && pass "interval: missing state -> run" || fail "interval: missing state"

# Round 2 fix: /dev/null is a char device on POSIX (not a regular file),
# so `[ -f /dev/null ]` is FALSE and the script falls into Case 1
# (state_missing) — no ERROR. Retarget to an empty regular file (mktemp):
# `[ -f "$EMPTY_FILE" ]` is TRUE, but jq reads nothing from it so both
# LAST_SYNC and LAST_STATUS are empty, triggering the "state corrupted"
# ERROR path (exit 2). This makes the strict branch fire on Linux/macOS
# CI with jq installed, and SKIP honestly on bare envs without jq.
EMPTY_FILE=$(mktemp)
touch "$EMPTY_FILE"
result=$(bash "$SCRIPT_DIR/loopx-sync-check-interval.sh" "$EMPTY_FILE" 2>&1) || true
rm -f "$EMPTY_FILE"
if echo "$result" | grep -q "ERROR"; then
  pass "interval: corrupted state -> error"
elif command -v jq >/dev/null 2>&1; then
  fail "interval: corrupted state did not error (got: $result)"
else
  echo "SKIP: interval: corrupted state -- jq unavailable on this env"
fi

# === Unit: snapshot ===
TESTDIR=$(mktemp -d)
SNAP=$(bash "$SCRIPT_DIR/loopx-sync-snapshot.sh" make "$TESTDIR" 2>&1) || true
# 注:此测试需要真实 .claude/hooks 才能完整跑,这里只验证不会崩
[ -n "$SNAP" ] && pass "snapshot: make returns path" || fail "snapshot: make returns nothing"

bash "$SCRIPT_DIR/loopx-sync-snapshot.sh" restore /tmp/nonexistent-snap "$TESTDIR" "$TESTDIR" > /dev/null 2>&1 && fail "snapshot: bad path accepted" || pass "snapshot: bad path rejected"
rm -rf "$TESTDIR"

# === Unit: detect (with REAL snapshot dir built from -old.* fixtures) ===
# Brief adaptation: instead of "/tmp/fake", build a real snapshot dir so the
# detector's 3 sub-detectors can actually read their old fixtures and perform
# a meaningful diff. Snapshot dir layout expected by the detector:
#   $SNAP/loopx-state/loopx-doctor-old.json
#   $SNAP/claude-hooks/loopx-skill-fixture/SKILL-old.md
#   $SNAP/claude-hooks/hook-fixture/guard-main-branch-push-old.txt
SNAPDIR=$(mktemp -d)
mkdir -p "$SNAPDIR/loopx-state" "$SNAPDIR/claude-hooks/loopx-skill-fixture" "$SNAPDIR/claude-hooks/hook-fixture"
cp "$FIXTURE_DIR/interface/doctor-deep-old.json" "$SNAPDIR/loopx-state/loopx-doctor-old.json"
cp "$FIXTURE_DIR/skill/SKILL-old.md" "$SNAPDIR/claude-hooks/loopx-skill-fixture/SKILL-old.md"
cp "$FIXTURE_DIR/hook/guard-main-branch-push-old.txt" "$SNAPDIR/claude-hooks/hook-fixture/guard-main-branch-push-old.txt"

# jq is a hard requirement for the detect tests — the detector itself
# uses jq internally (paths(scalars) etc.), and the test's job is to
# verify the JSON structure it emits. Earlier grep-on-JSON fallback was
# brittle (sensitive to token vocabulary / quoting) and could silently
# miscount. CI installs jq (see .github/workflows/loopx-sync-test.yml
# install step), so this should never fire in practice. If jq is missing
# the test fails loudly so CI catches the missing dependency.
detect_err_count() {
  # $1 = raw detect output
  local raw="$1"
  # Filter bash locale warnings (Windows Git Bash: "LC_ALL: cannot change
  # locale (zh-CN)") that pollute $() capture with 2>&1.
  local clean
  clean=$(echo "$raw" | grep -v "warning: setlocale")
  if ! command -v jq >/dev/null 2>&1; then
    return 1  # signal caller: jq missing -> caller hard-fails
  fi
  echo "$clean" | jq '[.interface.errors, .skill.errors, .hook.errors] | add | length' 2>/dev/null
}

# --- conflict case ---
set +e
result=$(bash "$SCRIPT_DIR/loopx-sync-detect-conflicts.sh" "$SNAPDIR" \
  "$FIXTURE_DIR/interface/doctor-deep-new-conflict.json" \
  "$FIXTURE_DIR/skill/SKILL-new-conflict.md" \
  "$FIXTURE_DIR/hook/guard-main-branch-push-new-conflict.txt" 2>&1)
set -e
jq_missing=0
err_count=$(detect_err_count "$result") || jq_missing=1
if [ "$jq_missing" = "1" ]; then
  fail "detect: conflict case -- jq not installed (CI workflow should have installed it)"
elif [ "$err_count" -gt "0" ]; then
  pass "detect: conflict case has errors ($err_count)"
else
  fail "detect: conflict case no errors"
fi

# --- clean case ---
set +e
result=$(bash "$SCRIPT_DIR/loopx-sync-detect-conflicts.sh" "$SNAPDIR" \
  "$FIXTURE_DIR/interface/doctor-deep-new-ok.json" \
  "$FIXTURE_DIR/skill/SKILL-new-ok.md" \
  "$FIXTURE_DIR/hook/guard-main-branch-push-new-ok.txt" 2>&1)
set -e
jq_missing=0
err_count=$(detect_err_count "$result") || jq_missing=1
if [ "$jq_missing" = "1" ]; then
  fail "detect: clean case -- jq not installed (CI workflow should have installed it)"
elif [ "$err_count" = "0" ]; then
  pass "detect: clean case no errors"
else
  fail "detect: clean case has $err_count errors"
fi

rm -rf "$SNAPDIR"

# === Summary ===
echo ""
echo "=== Total: $PASS pass / $FAIL fail ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 2