#!/bin/bash
# ============================================================
# Hook: PreToolUse(EnterPlanMode) — Plan Standard Context Loader
# Event: PreToolUse
# Matcher: EnterPlanMode
# Purpose: Loads 16-section plan standard + active task context when plan mode begins
# Dependencies: bash, cat
# Changelog (max 10):
#   2026-04-08 | plan-standard-integration | builder | Created initial hook
# ============================================================

# Self-orient to project root (defensive — works regardless of caller's cwd or env vars)
__HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || exit 0
__PROJECT_ROOT="$(cd "${__HOOK_DIR}/../.." 2>/dev/null && pwd)" || exit 0
cd "${__PROJECT_ROOT}" || exit 0

set -euo pipefail

HOOK_NAME="HOOK:PreToolUse:EnterPlanMode"

# Drain stdin — required for all hooks (input JSON not parsed for this hook)
INPUT=$(cat)

PLAN_STANDARD=".claude/rules/implementation-plan-standard.md"
ACTIVE_TASKS="hub/state/active-tasks.md"

# --- Load implementation plan standard ---
if [[ -f "$PLAN_STANDARD" ]]; then
  echo "[$HOOK_NAME] FIRED — Loading implementation plan standard + task context"
  echo ""
  echo "=== IMPLEMENTATION PLAN STANDARD (16-SECTION) ==="
  cat "$PLAN_STANDARD"
  echo ""
else
  echo "[$HOOK_NAME] ERROR — Plan standard not found at $PLAN_STANDARD"
fi

# --- Load active tasks ---
if [[ -f "$ACTIVE_TASKS" ]]; then
  echo "=== ACTIVE TASKS ==="
  cat "$ACTIVE_TASKS"
  echo ""
else
  echo "[$HOOK_NAME] INFO — No active-tasks.md found (no tasks in progress)"
fi

exit 0
