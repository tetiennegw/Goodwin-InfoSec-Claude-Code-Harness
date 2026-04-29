#!/bin/bash
# ============================================================
# Hook: onboarding-trigger.sh
# Event: SessionStart
# Purpose: detect missing .harness-onboarded sentinel and prepend an /onboard banner.
# Created: 2026-04-29
# Last-Updated: 2026-04-29
# Plan: hub/staging/2026-04-28-morpheus-templatize-port/wave-3/repo-architecture.md §3.1
# Dependencies: bash 4+, GNU coreutils
# Changelog (max 10):
#   2026-04-29 | morpheus-templatize-port | builder (Phase 5 R2) | Created SessionStart trigger.
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SENTINEL="$REPO_ROOT/.harness-onboarded"

# Idempotent: if sentinel exists, skip silently with hook header.
if [ -f "$SENTINEL" ]; then
  echo "[HOOK:SessionStart] SKIPPED — .harness-onboarded present; harness already onboarded."
  exit 0
fi

# Sentinel missing — prepend onboarding banner to stdout (Claude Code captures stdout as added context).
cat <<'BANNER'
[HOOK:SessionStart] FIRED — sentinel missing; prepending /onboard banner.

============================================================
[ONBOARDING REQUIRED]

This appears to be a fresh clone of the Morpheus harness. Run /onboard to
configure identity, paths, and optional extensions before doing real work.

Skip with: touch .harness-onboarded
(But expect substituted-with-placeholders state in CLAUDE.md, etc.)
============================================================
BANNER

exit 0
