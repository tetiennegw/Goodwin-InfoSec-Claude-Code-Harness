#!/bin/bash
# ============================================================
# Hook: prepend-reminder
# Lifecycle Event: PreToolUse
# Matcher: Edit|Write|MultiEdit
# Purpose: Surface the Prepend Protocol into agent context when a daily note
#          is about to be edited. Non-blocking reminder only.
# Dependencies: bash, sed, grep, printf
# Changelog (max 10):
#   2026-04-09 | daily-note-prepend-standard | morpheus | Created
# ============================================================

# Self-orient to project root (defensive — works regardless of caller's cwd or env vars)
__HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || exit 0
__PROJECT_ROOT="$(cd "${__HOOK_DIR}/../.." 2>/dev/null && pwd)" || exit 0
cd "${__PROJECT_ROOT}" || exit 0

set +e  # fail-open — never block a tool call

# Read PreToolUse JSON payload from stdin
payload="$(cat)"

# Extract file_path from tool_input. Tolerant of:
#   - forward and backslash separators
#   - Windows drive letters
#   - spaces in path
#   - escaped quotes (best-effort; daily-note paths never contain literal " anyway)
file_path="$(printf '%s' "$payload" \
  | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
  | head -n1)"

# Silent no-op if no file_path key present (some tool variants)
if [[ -z "$file_path" ]]; then
  exit 0
fi

# Normalize backslashes to forward slashes for matching
normalized="${file_path//\\/\/}"

# Match ONLY daily notes: notes/YYYY/MM/YYYY-MM-DD.md at end of path.
# Anchored to the full notes/NNNN/NN/NNNN-NN-NN.md pattern to avoid false
# positives on other "notes/" paths (e.g. notes/ideas.md, hub/notes/foo.md).
if printf '%s' "$normalized" | grep -qE 'notes/[0-9]{4}/[0-9]{2}/[0-9]{4}-[0-9]{2}-[0-9]{2}\.md$'; then
  >&2 echo "[HOOK:PreToolUse:prepend-reminder] FIRED — daily note edit detected: ${normalized}"
  >&2 echo "REMINDER: ## Notes uses PREPEND (newest first). Match the canonical anchor <!-- PREPEND-ANCHOR:v1 --> in old_string and insert your new entry immediately below it."
  >&2 echo "Full protocol: .claude/rules/daily-note.md § Prepend Protocol (7 steps, Case A/B/C Edit patterns, common mistakes)."
  >&2 echo "If prepending multiple entries in the same turn: RE-READ the file between each Edit."
fi

exit 0
