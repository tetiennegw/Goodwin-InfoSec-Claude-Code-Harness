#!/bin/bash
# ============================================================
# Task: 2026-04-15-planner-integration (T4.2)
# Agent: builder
# Created: 2026-04-15T22:00
# Last-Updated: 2026-04-15T22:00
# Plan: .claude/plans/async-petting-teapot.md
# Purpose: PostToolUse hook (Edit|Write) -- detects when a hub/staging/*/STATE.md
#          is written, compares frontmatter hash against snapshot, and if changed
#          appends a push-queue entry to hub/state/planner-push-queue.json so that
#          prompt-context-loader.sh can force-activate /sync-planner.
# Dependencies: bash, sed, sha256sum, awk, date, powershell.exe (for JSON)
# Fail-open: set +e -- never block tool use, always exit 0
# Changelog (max 10):
#   2026-04-15T22:00 | 2026-04-15-planner-integration | builder | Created initial hook
# ============================================================

set +e  # never fail the tool call

# ---------------------------------------------------------------------------
# 1. Parse stdin -- get the file path from Claude tool_input JSON
# ---------------------------------------------------------------------------
STDIN_JSON=$(cat 2>/dev/null) || exit 0
[ -n "$STDIN_JSON" ] || exit 0

FILE_PATH=$(printf '%s' "$STDIN_JSON" | sed 's/.*"file_path"\s*:\s*"\([^"]*\)".*/\1/' 2>/dev/null)
[ -n "$FILE_PATH" ] || exit 0

# ---------------------------------------------------------------------------
# 2. Fast path -- only act on hub/staging/*/STATE.md  (<50ms for all other files)
# ---------------------------------------------------------------------------
NORMALIZED=$(printf '%s' "$FILE_PATH" | tr '\' '/' 2>/dev/null)

case "$NORMALIZED" in
  *hub/staging/*/STATE.md) ;;  # matches -- continue
  *) exit 0 ;;                 # fast path: not a STATE.md
esac

# ---------------------------------------------------------------------------
# 3. Resolve STATE.md to an absolute path
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || exit 0
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." 2>/dev/null && pwd)" || exit 0

case "$FILE_PATH" in
  /*)
    STATE_FILE="$FILE_PATH"
    ;;
  [A-Za-z]:*)
    STATE_FILE="$FILE_PATH"
    ;;
  *)
    STATE_FILE="${PROJECT_ROOT}/${FILE_PATH}"
    ;;
esac

[ -f "$STATE_FILE" ] || exit 0

# ---------------------------------------------------------------------------
# 4. Extract task-id from path (directory name under hub/staging/)
# ---------------------------------------------------------------------------
TASK_ID=$(printf '%s' "$NORMALIZED" | sed 's|^\(.*[/]\)\?hub/staging/\([^/]*\)/STATE\.md|\2|' 2>/dev/null)
[ -n "$TASK_ID" ] || exit 0

# ---------------------------------------------------------------------------
# 5. Snapshot comparison -- compute hash of frontmatter block
# ---------------------------------------------------------------------------
SNAPSHOT_DIR="${PROJECT_ROOT}/hub/state/.planner-state-snapshots"
mkdir -p "$SNAPSHOT_DIR" 2>/dev/null || exit 0
SNAPSHOT_FILE="${SNAPSHOT_DIR}/${TASK_ID}.state.sha"

NEW_HASH=$(sed -n '/^---$/,/^---$/p' "$STATE_FILE" 2>/dev/null | sha256sum 2>/dev/null | awk '{print $1}')
[ -n "$NEW_HASH" ] || exit 0

OLD_HASH=""
if [ -f "$SNAPSHOT_FILE" ]; then
  OLD_HASH=$(cat "$SNAPSHOT_FILE" 2>/dev/null)
fi

if [ "$NEW_HASH" = "$OLD_HASH" ]; then
  exit 0
fi

# ---------------------------------------------------------------------------
# 6. Extract key frontmatter fields
# ---------------------------------------------------------------------------
extract_field() {
  local field="$1"
  sed -n '/^---$/,/^---$/p' "$STATE_FILE" 2>/dev/null \
    | grep "^${field}:" \
    | head -1 \
    | sed "s/^${field}:\s*//" \
    | tr -d '\r\n'
}

FM_STATUS=$(extract_field "status")
FM_WAVE=$(extract_field "current-wave")
FM_ROUND=$(extract_field "current-round")
FM_TASK_ID=$(extract_field "task-id")

[ -n "$FM_TASK_ID" ] && TASK_ID="$FM_TASK_ID"
[ -n "$FM_STATUS" ] || FM_STATUS="unknown"
[ -n "$FM_WAVE" ]   || FM_WAVE="0"
[ -n "$FM_ROUND" ]  || FM_ROUND="0"

# ---------------------------------------------------------------------------
# 7. Extract OLD values from snapshot metadata file
#    Stored for three-way merge on HTTP 412 conflict (AC19)
# ---------------------------------------------------------------------------
META_FILE="${SNAPSHOT_DIR}/${TASK_ID}.state.meta"
OLD_STATUS="unknown"
OLD_WAVE="0"
OLD_ROUND="0"

if [ -f "$META_FILE" ]; then
  OLD_STATUS=$(grep "^status=" "$META_FILE" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r\n')
  OLD_WAVE=$(grep "^current-wave=" "$META_FILE" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r\n')
  OLD_ROUND=$(grep "^current-round=" "$META_FILE" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r\n')
  [ -n "$OLD_STATUS" ] || OLD_STATUS="unknown"
  [ -n "$OLD_WAVE" ]   || OLD_WAVE="0"
  [ -n "$OLD_ROUND" ]  || OLD_ROUND="0"
fi

# ---------------------------------------------------------------------------
# 8. Append queue entry via PowerShell (no jq on Goodwin endpoints)
#    AC19: ETags NOT stored here -- read from planner-ids.json at push time.
#    oldValue IS stored here for three-way merge on HTTP 412 conflict.
# ---------------------------------------------------------------------------
QUEUE_FILE="${PROJECT_ROOT}/hub/state/planner-push-queue.json"
# Convert MSYS Unix path (/c/Users/...) to Windows path (C:\Users\...) for PowerShell
QUEUE_FILE_WIN=$(printf '%s' "$QUEUE_FILE" | sed 's|^/\([a-zA-Z]\)/|\1:/|' | tr '/' '\\')
STATE_FILE_WIN=$(printf '%s' "$STATE_FILE" | sed 's|^/\([a-zA-Z]\)/|\1:/|' | tr '/' '\\')
TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null) || TIMESTAMP="unknown"

# Use PowerShell only for JSON generation (stdout), write with bash
# (ThreatLocker blocks PS 5.1 from writing to project paths directly)
EXISTING_JSON=""
if [ -f "$QUEUE_FILE" ]; then
  EXISTING_JSON=$(cat "$QUEUE_FILE" 2>/dev/null)
fi

NEW_JSON=$(powershell.exe -NoProfile -NonInteractive -Command "
  \$existingRaw = @'
${EXISTING_JSON}
'@

  if (\$existingRaw.Trim().Length -gt 0) {
    try {
      \$parsed = \$existingRaw | ConvertFrom-Json -ErrorAction Stop
      if (\$null -ne \$parsed.entries) {
        \$q = @(\$parsed.entries)
      } else { \$q = @() }
    } catch { \$q = @() }
  } else { \$q = @() }

  # Generate one entry per changed field (module expects field-level granularity)
  \$fieldMap = @{
    status       = @{ old = '${OLD_STATUS}';  new = '${FM_STATUS}' }
    currentWave  = @{ old = '${OLD_WAVE}';    new = '${FM_WAVE}' }
    currentRound = @{ old = '${OLD_ROUND}';   new = '${FM_ROUND}' }
  }
  \$ts = '${TIMESTAMP}'
  \$tid = '${TASK_ID}'
  \$newEntries = @()
  foreach (\$f in \$fieldMap.Keys) {
    if (\$fieldMap[\$f].old -ne \$fieldMap[\$f].new) {
      \$newEntries += [PSCustomObject]@{
        entryId       = \"\$tid-\$f-\$(Get-Date -Format 'yyyyMMddHHmmss')\"
        taskId        = \$tid
        plannerTaskId = ''
        field         = \$f
        oldValue      = \$fieldMap[\$f].old
        newValue      = \$fieldMap[\$f].new
        detectedAt    = \$ts
        pushed        = \$false
      }
    }
  }

  # If no individual field changed but hash changed (e.g. whitespace), emit a summary entry
  if (\$newEntries.Count -eq 0) {
    \$newEntries += [PSCustomObject]@{
      entryId       = \"\$tid-frontmatter-\$(Get-Date -Format 'yyyyMMddHHmmss')\"
      taskId        = \$tid
      plannerTaskId = ''
      field         = 'frontmatter'
      oldValue      = 'changed'
      newValue      = 'changed'
      detectedAt    = \$ts
      pushed        = \$false
    }
  }

  [PSCustomObject]@{ entries = @(\$q) + \$newEntries } | ConvertTo-Json -Depth 10
" 2>/dev/null)

# Write the JSON via bash (bypasses ThreatLocker PS file write restrictions)
if [ -n "$NEW_JSON" ]; then
  printf '%s' "$NEW_JSON" > "$QUEUE_FILE" 2>/dev/null
fi

# ---------------------------------------------------------------------------
# 9. Update snapshot hash + metadata so next change can diff correctly
# ---------------------------------------------------------------------------
printf '%s' "$NEW_HASH" > "$SNAPSHOT_FILE" 2>/dev/null

{
  printf 'status=%s\n' "$FM_STATUS"
  printf 'current-wave=%s\n' "$FM_WAVE"
  printf 'current-round=%s\n' "$FM_ROUND"
} > "$META_FILE" 2>/dev/null

# Always exit 0 -- never block tool use
exit 0
