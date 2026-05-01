#!/bin/bash
# ============================================================
# Daily Note Documentation Check — BLOCKING Stop Hook
# Source: ishtylerc/claude-code-hooks-framework (adapted for Morpheus)
# Event: Stop
# Purpose: Blocks session end if meaningful work was done in the current
#          turn but today's daily note wasn't updated in that same turn.
# Dependencies: python3 (jq not available on Goodwin locked-down Windows)
# Changelog (max 10):
#   2026-04-09 | morpheus-foundation | orchestrator | Rewrote in Python — jq isn't on PATH in this environment, so the previous jq-based version silently no-op'd every single turn (command-not-found swallowed by `2>/dev/null || true`). Now uses python3 to parse JSONL transcript, scope to current turn (since last user message), and require an actual Edit/Write tool_use on the daily note path.
#   2026-04-08 | morpheus-foundation | orchestrator | Adapted from hooks framework for Morpheus note system
# ============================================================

set -euo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Parse hook input with python
PARSED=$(printf '%s' "$INPUT" | python -c '
import json, sys
try:
    data = json.loads(sys.stdin.read() or "{}")
except Exception:
    data = {}
print(data.get("transcript_path", ""))
print("true" if data.get("stop_hook_active") else "false")
' 2>/dev/null || printf '\nfalse\n')

TRANSCRIPT_PATH=$(printf '%s\n' "$PARSED" | sed -n '1p')
STOP_HOOK_ACTIVE=$(printf '%s\n' "$PARSED" | sed -n '2p')

# Prevent infinite loops — if stop_hook_active is true, we already blocked once
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  echo "[HOOK:Stop:DailyNote] SKIPPED -- Already blocked once, allowing stop"
  exit 0
fi

# If no transcript path or file missing, allow stopping
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  echo "[HOOK:Stop:DailyNote] SKIPPED -- No transcript available"
  exit 0
fi

# Run the real analysis in python. Exit codes:
#   0 = allow stop (no work, or note was updated this turn)
#   1 = block stop (work done, note not updated)
#   2 = internal error (allow stop — fail-open)
RESULT=$(python - "$TRANSCRIPT_PATH" <<'PYEOF'
import json, re, sys

# Work tools that produce artifacts worth documenting.
# Excludes Read/Grep/Glob/WebSearch/WebFetch (read-only) and Bash (too noisy).
WORK_TOOLS = {"Edit", "Write", "Agent", "Task", "NotebookEdit"}
NOTE_PATH_RE = re.compile(r"notes/\d{4}/\d{2}/\d{4}-\d{2}-\d{2}\.md")

path = sys.argv[1]

try:
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        lines = [json.loads(ln) for ln in f if ln.strip()]
except Exception as e:
    print(f"ERR parse: {e}", file=sys.stderr)
    sys.exit(2)

# Find index of last user message
last_user_idx = -1
for i, msg in enumerate(lines):
    if msg.get("type") == "user":
        last_user_idx = i

# Current turn = everything after the last user message
current_turn = lines[last_user_idx + 1 :]

def iter_tool_uses(entries):
    """Yield (name, input_dict) for every tool_use block in assistant messages."""
    for entry in entries:
        if entry.get("type") != "assistant":
            continue
        msg = entry.get("message") or {}
        content = msg.get("content") or []
        if not isinstance(content, list):
            continue
        for block in content:
            if isinstance(block, dict) and block.get("type") == "tool_use":
                yield block.get("name", ""), block.get("input") or {}

work_done = False
note_edited = False

for name, inp in iter_tool_uses(current_turn):
    if name in WORK_TOOLS:
        work_done = True
    if name in ("Edit", "Write"):
        fp = inp.get("file_path", "") if isinstance(inp, dict) else ""
        if NOTE_PATH_RE.search(fp.replace("\\", "/")):
            note_edited = True

if not work_done:
    print("SKIP_NO_WORK")
    sys.exit(0)
if note_edited:
    print("SKIP_NOTE_EDITED")
    sys.exit(0)
print("BLOCK")
sys.exit(1)
PYEOF
) || RC=$? && RC=${RC:-0}

case "${RESULT:-}" in
  SKIP_NO_WORK)
    echo "[HOOK:Stop:DailyNote] SKIPPED -- No artifact-producing work tools in current turn"
    exit 0
    ;;
  SKIP_NOTE_EDITED)
    echo "[HOOK:Stop:DailyNote] SKIPPED -- Daily note updated in current turn"
    exit 0
    ;;
  BLOCK)
    cat <<'JSON'
{"decision":"block","reason":"STOP BLOCKED: Meaningful work was completed this turn (Edit/Write/Agent/Task) but today's daily note was not updated in the same turn. Append a rich timeline entry to notes/YYYY/MM/YYYY-MM-DD.md under the ## Notes section using the standard format (- **HH:MM** - **[Title]** #tags, [WORK TYPE]:, Files Modified:, Key Decisions:, Artifacts:, Strategic Value:), then you may stop. This hook can only be bypassed by actually updating the note."}
JSON
    exit 0
    ;;
  *)
    echo "[HOOK:Stop:DailyNote] SKIPPED -- Parser error (fail-open); rc=$RC result=${RESULT:-empty}"
    exit 0
    ;;
esac
