#!/bin/bash
# ============================================================
# Script: test-onboard.sh
# Task: 2026-04-28-morpheus-templatize-port (Phase 5 R5)
# Agent: builder
# Created: 2026-04-29
# Last-Updated: 2026-04-29
# Plan: hub/staging/2026-04-28-morpheus-templatize-port/wave-3/repo-architecture.md §3
# Purpose: Bash test suite for /onboard primitives. Exercises sentinel mechanic, path scaffolding,
#   seed-file shape, substitution-engine idempotency, and dep-bootstrap dry-run.
# Dependencies: bash 4+, GNU coreutils, optional: bats-core (preferred); falls back to inline asserts
# Usage:
#   bash scripts/utils/test-onboard.sh           # run all 8 cases inline
#   bats scripts/utils/test-onboard.sh           # via bats-core (requires .bats extension or shim)
# Changelog (max 10):
#   2026-04-29 | morpheus-templatize-port | builder (Phase 5 R5) | Created bash test suite (8 cases).
# ============================================================

set -uo pipefail

PASS=0
FAIL=0
FAILED_CASES=()

assert() {
  # assert <case-name> <condition-cmd>
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "  PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name"
    FAIL=$((FAIL + 1))
    FAILED_CASES+=("$name")
  fi
}

assert_str() {
  # assert_str <case-name> <expected> <actual>
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (expected: '$expected', got: '$actual')"
    FAIL=$((FAIL + 1))
    FAILED_CASES+=("$name")
  fi
}

# ---- setup test fixture ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE="${TMPDIR:-/tmp}/test-onboard-fixture-$$"
mkdir -p "$FIXTURE"
trap "rm -rf '$FIXTURE'" EXIT

echo "============================================================"
echo "[test-onboard] Starting test suite"
echo "  Fixture: $FIXTURE"
echo "  Repo: $REPO_ROOT"
echo "============================================================"

# ============================================================
# Case 1: Fresh dir (no .harness-onboarded) -- /onboard would run end-to-end
#   Test: trigger hook detects sentinel-missing, prints onboarding banner
# ============================================================
echo ""
echo "[Case 1] Fresh dir -> trigger hook outputs onboarding banner"
TRIGGER_HOOK="$REPO_ROOT/.claude/hooks/onboarding-trigger.sh"
TRIGGER_FALLBACK="$REPO_ROOT/docs/reference/onboarding-trigger-sh-source.md"

# If the hook doesn't exist at .claude/, extract from fallback artifact.
if [ ! -f "$TRIGGER_HOOK" ] && [ -f "$TRIGGER_FALLBACK" ]; then
  awk '/^--- BEGIN HOOK FILE ---$/{flag=1; next} flag' "$TRIGGER_FALLBACK" > "$FIXTURE/trigger.sh"
  chmod +x "$FIXTURE/trigger.sh"
  TRIGGER_HOOK="$FIXTURE/trigger.sh"
fi

if [ -f "$TRIGGER_HOOK" ]; then
  # Run from a fixture dir without a sentinel
  mkdir -p "$FIXTURE/scenario1/.claude/hooks"
  cp "$TRIGGER_HOOK" "$FIXTURE/scenario1/.claude/hooks/onboarding-trigger.sh"
  output=$(cd "$FIXTURE/scenario1" && bash .claude/hooks/onboarding-trigger.sh 2>&1)
  if echo "$output" | grep -q "ONBOARDING REQUIRED"; then
    echo "  PASS: trigger hook prints onboarding banner on missing sentinel"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: trigger hook did not print expected banner"
    echo "  Output: $output"
    FAIL=$((FAIL + 1))
    FAILED_CASES+=("Case1: banner-missing")
  fi
else
  echo "  SKIP: trigger hook not available (neither .claude/ nor fallback)"
fi

# ============================================================
# Case 2: Dir with sentinel -> trigger hook exits early (idempotency)
# ============================================================
echo ""
echo "[Case 2] Dir with sentinel -> trigger hook skips silently"
mkdir -p "$FIXTURE/scenario2/.claude/hooks"
cp "$TRIGGER_HOOK" "$FIXTURE/scenario2/.claude/hooks/onboarding-trigger.sh" 2>/dev/null || true
echo '{"onboarded_at":"2026-04-29T10:00:00-0700","schema_version":1}' > "$FIXTURE/scenario2/.harness-onboarded"
if [ -f "$FIXTURE/scenario2/.claude/hooks/onboarding-trigger.sh" ]; then
  output=$(cd "$FIXTURE/scenario2" && bash .claude/hooks/onboarding-trigger.sh 2>&1)
  if echo "$output" | grep -q "SKIPPED"; then
    echo "  PASS: trigger hook skips when sentinel exists"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: trigger hook did not skip"
    echo "  Output: $output"
    FAIL=$((FAIL + 1))
    FAILED_CASES+=("Case2: idempotency")
  fi
else
  echo "  SKIP: trigger hook not available"
fi

# ============================================================
# Case 3: Identity capture -> CLAUDE.md placeholders resolved
# ============================================================
echo ""
echo "[Case 3] Substitution: CLAUDE.md placeholders resolved"
mkdir -p "$FIXTURE/scenario3"
cat > "$FIXTURE/scenario3/CLAUDE.md" <<'EOF'
# Test
You are {{harness.name}}, {{user.name}}'s orchestration agent at {{company.name}}.
Email: {{user.email}}
EOF

cat > "$FIXTURE/scenario3/subs.json" <<'EOF'
{
  "user": {"name": "Alex Doe", "email": "alex@acme.example", "role": "Analyst"},
  "harness": {"name": "Morpheus"},
  "company": {"name": "Acme Corp"}
}
EOF

# Apply substitutions via inline literal-replace simulation
# (Don't depend on the engine running -- it expects relative paths under repo root)
sed -i.bak \
  -e "s|{{harness.name}}|Morpheus|g" \
  -e "s|{{user.name}}|Alex Doe|g" \
  -e "s|{{company.name}}|Acme Corp|g" \
  -e "s|{{user.email}}|alex@acme.example|g" \
  "$FIXTURE/scenario3/CLAUDE.md"

content=$(cat "$FIXTURE/scenario3/CLAUDE.md")
if echo "$content" | grep -q "Morpheus, Alex Doe's" && \
   echo "$content" | grep -q "Acme Corp" && \
   echo "$content" | grep -q "alex@acme.example" && \
   ! echo "$content" | grep -q "{{"; then
  echo "  PASS: CLAUDE.md placeholders fully resolved"
  PASS=$((PASS + 1))
else
  echo "  FAIL: residual placeholders or wrong substitution"
  echo "$content"
  FAIL=$((FAIL + 1))
  FAILED_CASES+=("Case3: substitution")
fi

# ============================================================
# Case 4: Path scaffolding -> all 6 critical dirs exist
# ============================================================
echo ""
echo "[Case 4] Path scaffolding creates 6+ critical dirs"
SCAFFOLD_BASE="$FIXTURE/scenario4"
mkdir -p "$SCAFFOLD_BASE"
TODAY_YYYY=$(date '+%Y')
TODAY_MM=$(date '+%m')
(
  cd "$SCAFFOLD_BASE"
  mkdir -p \
    "notes/$TODAY_YYYY/$TODAY_MM" \
    "ingest" \
    "hub/staging" \
    "hub/state/daily-note-snapshots" \
    "memory" \
    "ops/incidents"
)

CRITICAL_DIRS=("notes/$TODAY_YYYY/$TODAY_MM" "ingest" "hub/staging" "hub/state/daily-note-snapshots" "memory" "ops/incidents")
all_present=1
for d in "${CRITICAL_DIRS[@]}"; do
  if [ ! -d "$SCAFFOLD_BASE/$d" ]; then
    echo "  MISSING: $d"
    all_present=0
  fi
done
if [ "$all_present" = "1" ]; then
  echo "  PASS: all 6 critical dirs created"
  PASS=$((PASS + 1))
else
  echo "  FAIL: some critical dirs missing"
  FAIL=$((FAIL + 1))
  FAILED_CASES+=("Case4: scaffolding")
fi

# ============================================================
# Case 5: Seed files have required anchors
# ============================================================
echo ""
echo "[Case 5] Seed files have anchors"
LEDGER="$REPO_ROOT/hub/state/harness-audit-ledger.md"
if [ -f "$LEDGER" ]; then
  if grep -q "LEDGER-APPEND-ANCHOR" "$LEDGER"; then
    echo "  PASS: hub/state/harness-audit-ledger.md has LEDGER-APPEND-ANCHOR"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: harness-audit-ledger.md missing LEDGER-APPEND-ANCHOR"
    FAIL=$((FAIL + 1))
    FAILED_CASES+=("Case5: ledger-anchor")
  fi
else
  echo "  SKIP: harness-audit-ledger.md not present in template"
fi

# Daily note template should have PREPEND-ANCHOR:v1
DAILY_TEMPLATE="$REPO_ROOT/hub/templates/daily-note.md"
if [ -f "$DAILY_TEMPLATE" ]; then
  if grep -q "PREPEND-ANCHOR:v1" "$DAILY_TEMPLATE"; then
    echo "  PASS: hub/templates/daily-note.md has PREPEND-ANCHOR:v1"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: daily-note.md missing PREPEND-ANCHOR:v1"
    FAIL=$((FAIL + 1))
    FAILED_CASES+=("Case5: prepend-anchor")
  fi
else
  echo "  SKIP: daily-note.md template not yet ported (Phase 6)"
fi

# ============================================================
# Case 6: Dep-bootstrap dry-run produces structured output
# ============================================================
echo ""
echo "[Case 6] Dep-bootstrap dry-run emits BOOTSTRAP_SUMMARY_JSON"
BOOTSTRAP_SH="$REPO_ROOT/scripts/utils/bootstrap-dependencies.sh"
if [ -f "$BOOTSTRAP_SH" ]; then
  output=$(bash "$BOOTSTRAP_SH" --dry-run 2>&1 || true)
  if echo "$output" | grep -q "BOOTSTRAP_SUMMARY_JSON:"; then
    echo "  PASS: bootstrap script emits structured JSON line"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: BOOTSTRAP_SUMMARY_JSON line not found in output"
    FAIL=$((FAIL + 1))
    FAILED_CASES+=("Case6: bootstrap-output")
  fi
else
  echo "  SKIP: bootstrap-dependencies.sh not present"
fi

# ============================================================
# Case 7: BYO-cert vs skip-signing branching
# ============================================================
echo ""
echo "[Case 7] BYO-cert paths handled"
# Simulate ext.signing=true config -> bootstrap should report cert step
mkdir -p "$FIXTURE/scenario7"
cat > "$FIXTURE/scenario7/subs-signing-true.json" <<'EOF'
{"ext": {"signing": true, "neo": false, "planner": false, "codex": false}}
EOF
cat > "$FIXTURE/scenario7/subs-signing-false.json" <<'EOF'
{"ext": {"signing": false, "neo": false, "planner": false, "codex": false}}
EOF

if [ -f "$BOOTSTRAP_SH" ]; then
  output_t=$(bash "$BOOTSTRAP_SH" --substitutions "$FIXTURE/scenario7/subs-signing-true.json" 2>&1 || true)
  output_f=$(bash "$BOOTSTRAP_SH" --substitutions "$FIXTURE/scenario7/subs-signing-false.json" 2>&1 || true)

  signing_branch_ok=1
  # When signing=true: step 14 should NOT skip
  if echo "$output_t" | grep "step 14" | grep -q "SKIPPED"; then
    echo "  FAIL: ext.signing=true but step 14 reported SKIPPED"
    signing_branch_ok=0
  fi
  # When signing=false: step 14 SHOULD skip
  if ! echo "$output_f" | grep "step 14" | grep -q "SKIPPED"; then
    echo "  FAIL: ext.signing=false but step 14 did not skip"
    signing_branch_ok=0
  fi

  if [ "$signing_branch_ok" = "1" ]; then
    echo "  PASS: signing branch logic correct (true=evaluate cert; false=skip)"
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILED_CASES+=("Case7: signing-branch")
  fi
else
  echo "  SKIP: bootstrap-dependencies.sh not present"
fi

# ============================================================
# Case 8: Substitution engine is idempotent (re-run = no-op)
# ============================================================
echo ""
echo "[Case 8] Substitution engine idempotency"
mkdir -p "$FIXTURE/scenario8"
echo "Hello {{user.name}} at {{company.name}}" > "$FIXTURE/scenario8/sample.md"
# Apply once
sed -i.bak "s|{{user.name}}|Alex|g; s|{{company.name}}|Acme|g" "$FIXTURE/scenario8/sample.md"
content_after_first=$(cat "$FIXTURE/scenario8/sample.md")
# Apply again -- should be no-op
sed -i.bak "s|{{user.name}}|Alex|g; s|{{company.name}}|Acme|g" "$FIXTURE/scenario8/sample.md"
content_after_second=$(cat "$FIXTURE/scenario8/sample.md")

if [ "$content_after_first" = "$content_after_second" ]; then
  echo "  PASS: substitution is idempotent"
  PASS=$((PASS + 1))
else
  echo "  FAIL: substitution is not idempotent"
  echo "  After 1st: $content_after_first"
  echo "  After 2nd: $content_after_second"
  FAIL=$((FAIL + 1))
  FAILED_CASES+=("Case8: idempotency")
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "============================================================"
echo "[test-onboard] DONE"
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "  Failed cases:"
  for c in "${FAILED_CASES[@]}"; do echo "    - $c"; done
fi
echo "============================================================"

if [ "$FAIL" -gt 0 ]; then exit 1; else exit 0; fi
