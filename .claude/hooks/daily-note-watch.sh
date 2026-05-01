#!/bin/bash
# ============================================================
# Hook: daily-note-watch.sh
# Lifecycle Event: PostToolUse (matcher: Edit|Write)
# Purpose: Update the approvals-section snapshot hash for today's daily note.
#          The prompt-context-loader.sh hook compares the CURRENT hash against
#          this snapshot to detect when a user has checked an approval box,
#          and injects a forced-YES override for /approve-pending.
#          This hook's ONLY job is to keep the snapshot fresh.
# Dependencies: bash, sed, sha256sum, awk, date
# Fail-closed: any error → exit 0 silently, never block tool use
# Changelog (max 10):
#   2026-04-09 | 2026-04-09-ingest-context-skill | morpheus | Created initial snapshot updater
# ============================================================

# Self-orient to project root (defensive — works regardless of caller's cwd or env vars)
__HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || exit 0
__PROJECT_ROOT="$(cd "${__HOOK_DIR}/../.." 2>/dev/null && pwd)" || exit 0
cd "${__PROJECT_ROOT}" || exit 0

set +e  # never fail the tool call

TODAY=$(date '+%Y-%m-%d' 2>/dev/null) || exit 0
TODAY_YEAR=$(date '+%Y' 2>/dev/null) || exit 0
TODAY_MONTH=$(date '+%m' 2>/dev/null) || exit 0
DAILY_NOTE="notes/${TODAY_YEAR}/${TODAY_MONTH}/${TODAY}.md"
SNAPSHOT_DIR="hub/state/daily-note-snapshots"
SNAPSHOT_FILE="${SNAPSHOT_DIR}/${TODAY}.approvals.sha"

# Only act if today's daily note exists
[ -f "$DAILY_NOTE" ] || exit 0

# Ensure snapshot dir exists
mkdir -p "$SNAPSHOT_DIR" 2>/dev/null || exit 0

# Compute sha256 of the ## Approvals Pending section.
# IMPORTANT: this pipeline MUST match prompt-context-loader.sh exactly — any difference
# in hash method (e.g. bash command substitution stripping trailing newlines, or
# printf %s omitting them) will cause false-positive override firings. Keep them identical.
HASH=$(sed -n '/^## Approvals Pending/,/^## /p' "$DAILY_NOTE" 2>/dev/null | sha256sum 2>/dev/null | awk '{print $1}')

# Write the hash (silent on success)
if [ -n "$HASH" ]; then
  printf '%s' "$HASH" > "$SNAPSHOT_FILE" 2>/dev/null
fi

# Always exit 0 — never block tool use
exit 0
