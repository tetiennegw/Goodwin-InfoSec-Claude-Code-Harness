#!/bin/bash
# ============================================================
# Task: active-tasks-derived-view
# Agent: builder
# Created: 2026-04-13T16:19
# Last-Updated: 2026-04-13T16:19
# Plan: .claude/plans/whimsical-singing-lerdorf.md
# Purpose: Regenerate hub/state/active-tasks.md as a derived
#          view of all hub/staging/*/STATE.md frontmatter.
#          Triggered by PostToolUse hook on every Edit/Write.
#          DO NOT call this script from within a tool that would
#          itself trigger PostToolUse — it writes via shell
#          redirect, not Claude's Write tool, so no loop risk.
# Dependencies: bash, sed, sort, mv, find, grep
# Changelog (max 10):
#   2026-04-13T16:19 | active-tasks-standard | builder | Created
# ============================================================

# Self-orient to project root (defensive — works regardless of caller's cwd or env vars)
__HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || exit 0
__PROJECT_ROOT="$(cd "${__HOOK_DIR}/../.." 2>/dev/null && pwd)" || exit 0
cd "${__PROJECT_ROOT}" || exit 0

set -euo pipefail

STAGING_DIR="hub/staging"
OUTPUT="hub/state/active-tasks.md"
TMPFILE="${OUTPUT}.tmp"

# Trap to clean up tmpfile on unexpected exit
trap 'rm -f "$TMPFILE"' ERR EXIT

# --- extract a single field from YAML frontmatter ---
# Strips CRLF, matches the first occurrence in the --- ... --- block.
# Usage: extract_field <file> <field-name> [default]
extract_field() {
  local file="$1"
  local field="$2"
  local default="${3:-}"
  local value
  value=$(
    sed 's/\r//' "$file" \
      | sed -n '/^---$/,/^---$/{
          /^'"$field"':[[:space:]]*/{ s/^'"$field"':[[:space:]]*//; p; q; }
        }'
  )
  echo "${value:-$default}"
}

# --- extract the first meaningful line of the Next Action section ---
# Matches ## Next Action or ## Next Actions (any suffix after the word Action).
# Avoids nested single-quote issues by writing sed script to a variable first.
extract_next() {
  local file="$1"
  local result
  # Use awk to safely extract without nested quoting complexity
  result=$(
    sed 's/\r//' "$file" | awk '
      /^## Next Action/ { in_section=1; next }
      in_section && /^## / { exit }
      in_section && /^[[:space:]]*$/ { next }
      in_section {
        # Strip leading list markers (-, *, digits followed by . or ))
        gsub(/^[[:space:]]*[-*][ \t]*/, "")
        gsub(/^[[:space:]]*[0-9]+[.)][[:space:]]*/, "")
        print; exit
      }
    ' 2>/dev/null
  ) || true
  echo "${result:-}"
}

# --- collect all STATE.md files ---
declare -a task_entries=()
while IFS= read -r state_file; do
  [ -f "$state_file" ] || continue

  last=$(extract_field "$state_file" "last-updated" "")
  created=$(extract_field "$state_file" "created" "1970-01-01T00:00")
  # Use last-updated for sort key; fall back to created if missing
  sort_key="${last:-$created}"
  task_entries+=("${sort_key}|${state_file}")
done < <(find "$STAGING_DIR" -maxdepth 2 -name "STATE.md" -type f 2>/dev/null | sort)

# --- sort newest-first using process substitution (avoids subshell array loss) ---
declare -a sorted_entries=()
if [ ${#task_entries[@]} -gt 0 ]; then
  while IFS= read -r entry; do
    [ -n "$entry" ] && sorted_entries+=("$entry")
  done < <(printf '%s\n' "${task_entries[@]}" | sort -r)
fi

# --- write output to tmpfile, then atomically move ---
{
  cat <<'HEADER'
# Active Tasks

> Auto-generated from hub/staging/*/STATE.md — do NOT edit manually.
> Regenerated on every Edit/Write call via PostToolUse hook.
> To refresh mid-session: bash scripts/utils/generate-active-tasks.sh
> Governed by: .claude/rules/active-tasks.md

HEADER

  if [ ${#sorted_entries[@]} -eq 0 ]; then
    echo "_No active tasks found. staging/ is empty or all STATE.md files are missing._"
    echo ""
  else
    for entry in "${sorted_entries[@]}"; do
      state_file="${entry#*|}"
      [ -f "$state_file" ] || continue

      dir=$(dirname "$state_file")
      task_id=$(basename "$dir")

      scope=$(extract_field "$state_file" "scope" "unknown")
      status=$(extract_field "$state_file" "status" "unknown")
      wave=$(extract_field "$state_file" "current-wave" "0")
      round=$(extract_field "$state_file" "current-round" "0")
      created=$(extract_field "$state_file" "created" "unknown")
      last_updated=$(extract_field "$state_file" "last-updated" "(not set)")
      next_action=$(extract_next "$state_file")
      next_action="${next_action:-(not set — see STATE.md)}"

      # Flag completed tasks rather than silently dropping them
      # Run /eod to archive them to hub/state/completed-tasks.md
      status_note=""
      if [[ "$status" == "complete" || "$status" == "completed" ]]; then
        status_note=" ⚠️ — archive pending, run /eod"
      fi

      echo "## ${task_id}"
      echo "- **Scope**: ${scope}"
      echo "- **Status**: ${status}${status_note}"
      echo "- **Wave**: ${wave} / **Round**: ${round}"
      echo "- **Started**: ${created}"
      echo "- **Last**: ${last_updated}"
      echo "- **State**: ${state_file}"
      echo "- **Next**: ${next_action}"
      echo ""
      echo "---"
      echo ""
    done
  fi
} > "$TMPFILE"

mv "$TMPFILE" "$OUTPUT"

# Disarm the ERR/EXIT trap now that we've succeeded
trap - ERR EXIT

count=$(grep -c '^## ' "$OUTPUT" 2>/dev/null || echo 0)
echo "[generate-active-tasks] Regenerated $OUTPUT ($count tasks)"
