#!/bin/bash
# ============================================================
# Script: test-ingest-hook.sh
# Task: 2026-04-09-ingest-context-skill (P7.T2.b)
# Agent: morpheus
# Created: 2026-04-09T14:35
# Last-Updated: 2026-04-09T14:35
# Plan: {{paths.home}}\.claude\plans\partitioned-scribbling-eclipse.md
# Purpose: Regression test for prompt-context-loader.sh forced-YES overrides
#          (INGEST + APPROVAL) and daily-note-watch.sh hash-method parity.
#          Drops test fixtures, runs the hooks, asserts expected output,
#          cleans up, and asserts silence. Non-destructive — restores all
#          state before exit. Exits non-zero on any failure.
# Dependencies: bash, sed, sha256sum, awk, grep, date
# Changelog (max 10):
#   2026-04-09T14:35 | 2026-04-09-ingest-context-skill | morpheus | Created regression test covering 3 scenarios (ingest override, approval override, hash parity)
# ============================================================

set -u  # unset vars are errors; do not set -e (we manage errors per-assertion)

# --- Paths ---
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT" || { echo "FATAL: cannot cd to repo root $REPO_ROOT"; exit 2; }

HOOK="$REPO_ROOT/.claude/hooks/prompt-context-loader.sh"
WATCH="$REPO_ROOT/.claude/hooks/daily-note-watch.sh"
INGEST_DIR="$REPO_ROOT/ingest"
TODAY=$(date '+%Y-%m-%d')
TODAY_YEAR=$(date '+%Y')
TODAY_MONTH=$(date '+%m')
DAILY_NOTE="$REPO_ROOT/notes/$TODAY_YEAR/$TODAY_MONTH/$TODAY.md"
SNAPSHOT="$REPO_ROOT/hub/state/daily-note-snapshots/${TODAY}.approvals.sha"
DUMMY_FILE="$INGEST_DIR/__test-ingest-hook-dummy.txt"

# --- Test counters ---
PASS=0
FAIL=0
FAILURES=()

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    PASS=$((PASS + 1))
    echo "  [PASS] $label"
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("$label")
    echo "  [FAIL] $label — expected to find: $needle"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" label="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    FAIL=$((FAIL + 1))
    FAILURES+=("$label")
    echo "  [FAIL] $label — did NOT expect to find: $needle"
  else
    PASS=$((PASS + 1))
    echo "  [PASS] $label"
  fi
}

# --- Preflight ---
echo "=== Preflight ==="
if [ ! -x "$HOOK" ] && [ ! -f "$HOOK" ]; then
  echo "FATAL: $HOOK not found"
  exit 2
fi
if [ ! -f "$WATCH" ]; then
  echo "FATAL: $WATCH not found"
  exit 2
fi
if [ ! -f "$DAILY_NOTE" ]; then
  echo "FATAL: today's daily note missing: $DAILY_NOTE"
  exit 2
fi

# Refuse to run if user already has a pending file in ingest/ — don't clobber
EXISTING_INGEST=$(find "$INGEST_DIR" -maxdepth 1 -type f ! -name "README.md" 2>/dev/null | wc -l | tr -d ' ')
if [ "${EXISTING_INGEST:-0}" -gt 0 ]; then
  echo "FATAL: ingest/ has pre-existing files — refusing to run (would interfere). Clear ingest/ first."
  exit 2
fi

echo "  Preflight OK"
echo ""

# --- Baseline snapshot ---
ORIGINAL_SNAPSHOT=""
if [ -f "$SNAPSHOT" ]; then
  ORIGINAL_SNAPSHOT=$(cat "$SNAPSHOT")
fi

# --- Cleanup trap (always restore state) ---
cleanup() {
  rm -f "$DUMMY_FILE" 2>/dev/null
  if [ -n "$ORIGINAL_SNAPSHOT" ]; then
    printf '%s' "$ORIGINAL_SNAPSHOT" > "$SNAPSHOT" 2>/dev/null
  fi
}
trap cleanup EXIT

# ============================================================
# TEST 1: Baseline — empty ingest, unmodified approvals section
# Expected: neither override fires
# ============================================================
echo "=== TEST 1: Baseline (no triggers) ==="
OUTPUT=$(bash "$HOOK" 2>&1)
assert_not_contains "$OUTPUT" "FORCED ACTIVATION OVERRIDE — ingest-context" "no INGEST override at baseline"
assert_not_contains "$OUTPUT" "FORCED ACTIVATION OVERRIDE — approve-pending" "no APPROVAL override at baseline"
echo ""

# ============================================================
# TEST 2: INGEST override fires when a file is in ingest/
# ============================================================
echo "=== TEST 2: INGEST override ==="
echo "test-ingest-hook fixture" > "$DUMMY_FILE"
OUTPUT=$(bash "$HOOK" 2>&1)
assert_contains "$OUTPUT" "FORCED ACTIVATION OVERRIDE — ingest-context" "INGEST override fires with dummy file"
assert_contains "$OUTPUT" "__test-ingest-hook-dummy.txt" "dummy filename listed in override"
assert_contains "$OUTPUT" "Call Skill(\"ingest-context\")" "override instructs skill activation"
rm -f "$DUMMY_FILE"
OUTPUT=$(bash "$HOOK" 2>&1)
assert_not_contains "$OUTPUT" "FORCED ACTIVATION OVERRIDE — ingest-context" "INGEST override silent after cleanup"
echo ""

# ============================================================
# TEST 3: Hash parity between watch hook and context loader
# ============================================================
echo "=== TEST 3: Hash parity ==="
bash "$WATCH"
WATCH_HASH=$(cat "$SNAPSHOT" 2>/dev/null)
LOADER_HASH=$(sed -n '/^## Approvals Pending/,/^## /p' "$DAILY_NOTE" | sha256sum | awk '{print $1}')
if [ "$WATCH_HASH" = "$LOADER_HASH" ]; then
  PASS=$((PASS + 1))
  echo "  [PASS] watch hook and context loader compute identical hashes"
else
  FAIL=$((FAIL + 1))
  FAILURES+=("hash parity")
  echo "  [FAIL] watch=$WATCH_HASH loader=$LOADER_HASH"
fi
echo ""

# ============================================================
# TEST 4: APPROVAL override fires when a checked box is injected
# ============================================================
echo "=== TEST 4: APPROVAL override ==="
# Capture original daily-note state (just the approvals section)
ORIGINAL_NOTE_COPY=$(mktemp)
cp "$DAILY_NOTE" "$ORIGINAL_NOTE_COPY"

# Inject a checked test item inline (sed in-place requires platform care)
# Use a temp file rewrite to stay portable across GNU/BSD sed
python_inline='
import re, sys
src = sys.stdin.read()
marker = "## Approvals Pending"
block  = "\n- [x] **00:00** — **TEST: automated hook regression test** (task: test-ingest-hook)\n  **Proposed change**: ephemeral test — removed after verification\n  **Why**: verifying APPROVAL override firing path\n  **Source**: scripts/utils/test-ingest-hook.sh\n"
out = src.replace(marker + "\n", marker + "\n" + block, 1)
sys.stdout.write(out)
'
# No python → use awk instead
awk -v block="\n- [x] **00:00** — **TEST: automated hook regression test** (task: test-ingest-hook)\n  **Proposed change**: ephemeral test — removed after verification\n  **Why**: verifying APPROVAL override firing path\n  **Source**: scripts/utils/test-ingest-hook.sh\n" '
  /^## Approvals Pending$/ { print; print block; injected=1; next }
  { print }
' "$DAILY_NOTE" > "${DAILY_NOTE}.tmp" && mv "${DAILY_NOTE}.tmp" "$DAILY_NOTE"

# Run loader — should fire APPROVAL override (current hash differs AND has checked box)
OUTPUT=$(bash "$HOOK" 2>&1)
assert_contains "$OUTPUT" "FORCED ACTIVATION OVERRIDE — approve-pending" "APPROVAL override fires with checked box"
assert_contains "$OUTPUT" "Call Skill(\"approve-pending\")" "override instructs approve-pending activation"

# Restore daily note
cp "$ORIGINAL_NOTE_COPY" "$DAILY_NOTE"
rm -f "$ORIGINAL_NOTE_COPY"

# Refresh snapshot to match restored state
bash "$WATCH"

# Run loader again — should be silent
OUTPUT=$(bash "$HOOK" 2>&1)
assert_not_contains "$OUTPUT" "FORCED ACTIVATION OVERRIDE — approve-pending" "APPROVAL override silent after restore"
echo ""

# ============================================================
# Summary
# ============================================================
echo "============================================================"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "  Failures:"
  for f in "${FAILURES[@]}"; do
    echo "    - $f"
  done
  exit 1
fi
echo "============================================================"
echo "  ALL TESTS PASSED"
exit 0
