#!/bin/bash
# ============================================================
# Hook: prompt-context-loader.sh
# Lifecycle Event: UserPromptSubmit
# Purpose: Loads TIME + ENVIRONMENT context into every user prompt.
#          1. Time context (HH:MM · YYYY-MM-DD · Day) — fresh on every message
#          2. Daily note existence check — creates today's note if missing (mid-session date rollover)
#          3. Forced-YES overrides for filesystem-driven skills (ingest-context, approve-pending)
#          4. Planner push-queue notice (informational, non-blocking)
#
# NOT in this hook (as of v2 overhaul, 2026-04-22):
#          - Scope assessment          (owned by /the-protocol Step 3)
#          - Skill evaluation          (owned by /the-protocol Step 5)
#          - Pre-flight gate enforcement (owned by /the-protocol Step 6)
#          These were moved out because two orchestration engines (hook + skill) fighting
#          for the same decisions produced the 2026-04-21 Azure-kickoff rubber-stamp failure
#          (see thoughts/second-opinions/2026-04-22-harness-overhaul-codex.md + plan
#          {{paths.home}}\.claude\plans\lovely-hatching-dongarra.md Phase A). /the-protocol is
#          now the sole pre-flight engine. This hook is ENVIRONMENT-ONLY — it loads time +
#          state-driven overrides, nothing more.
#
# Dependencies: bash, date, find, sed, ensure-note.sh
# Changelog (max 10):
#   2026-04-22 | 2026-04-22-harness-intake-improvements | morpheus | Phase A1: stripped Steps 0-4 orchestration logic; retained time context + ingest/approval overrides + planner notice. /the-protocol is now the sole pre-flight engine.
#   2026-04-09 | morpheus-foundation | orchestrator | Renamed from skill-forced-eval-hook.sh + added daily note check + time context
#   2026-04-08 | morpheus-foundation | orchestrator | Added dynamic skill discovery from .claude/commands/
#   2026-04-08 | morpheus-foundation | orchestrator | Original from ishtylerc/claude-code-hooks-framework
# ============================================================

# --- Daily note existence check ---
# Catches mid-session date rollover (SessionStart hook only fires once at session start)
TODAY=$(date '+%Y-%m-%d')
TODAY_YEAR=$(date '+%Y')
TODAY_MONTH=$(date '+%m')
DAILY_NOTE_PATH="notes/${TODAY_YEAR}/${TODAY_MONTH}/${TODAY}.md"
if [ ! -f "$DAILY_NOTE_PATH" ] && [ -f "scripts/utils/ensure-note.sh" ]; then
  bash scripts/utils/ensure-note.sh >/dev/null 2>&1 || true
fi

# --- Ingest folder auto-detection (forced skill activation) ---
# If files are present in ingest/, force ingest-context to run before the user's message is addressed.
# Rationale: this is FILESYSTEM-DRIVEN, not user-intent-driven — orthogonal to /the-protocol's scope/skill-eval job.
INGEST_OVERRIDE=""
if [ -d "ingest" ]; then
  INGEST_COUNT=$(find ingest -maxdepth 1 -type f ! -name "README.md" 2>/dev/null | wc -l | tr -d ' ')
  if [ "${INGEST_COUNT:-0}" -gt 0 ]; then
    INGEST_FILES=$(find ingest -maxdepth 1 -type f ! -name "README.md" -exec basename {} \; 2>/dev/null | head -5 | sed 's/^/    - /')
    INGEST_OVERRIDE=$(cat <<OVRD

---

FORCED ACTIVATION OVERRIDE — ingest-context

The ingest/ folder contains ${INGEST_COUNT} unprocessed file(s):
${INGEST_FILES}

For this turn, you MUST:
1. Call Skill("ingest-context") BEFORE addressing the user's actual message
2. Only after ingest-context has completed (including any AskUserQuestion approval prompts) may you respond to the user's original message

This override exists because the ingest/ folder is a trusted drop zone — any files present represent pending context that must be absorbed before Claude can reliably answer Tyler's question (the file may contain context relevant to what he is asking).

OVRD
)
  fi
fi

# --- Deferred approvals detection (forced skill activation) ---
# If the ## Approvals Pending section changed since last snapshot AND contains newly checked boxes, force approve-pending.
# Rationale: filesystem-driven signal (daily note state change); orthogonal to /the-protocol.
APPROVAL_OVERRIDE=""
SNAPSHOT_DIR="hub/state/daily-note-snapshots"
SNAPSHOT_FILE="${SNAPSHOT_DIR}/${TODAY}.approvals.sha"
if [ -f "$DAILY_NOTE_PATH" ] && [ -d "$SNAPSHOT_DIR" ]; then
  CURRENT_HASH=$(sed -n '/^## Approvals Pending/,/^## /p' "$DAILY_NOTE_PATH" 2>/dev/null | sha256sum 2>/dev/null | awk '{print $1}')
  STORED_HASH=""
  [ -f "$SNAPSHOT_FILE" ] && STORED_HASH=$(cat "$SNAPSHOT_FILE" 2>/dev/null)
  if [ -n "$CURRENT_HASH" ] && [ "$CURRENT_HASH" != "$STORED_HASH" ]; then
    # Check for newly checked boxes inside the Approvals Pending section
    NEW_CHECKS=$(sed -n '/^## Approvals Pending/,/^## /p' "$DAILY_NOTE_PATH" 2>/dev/null | grep -c '^- \[x\]' || true)
    if [ "${NEW_CHECKS:-0}" -gt 0 ]; then
      APPROVAL_OVERRIDE=$(cat <<OVRD2

---

FORCED ACTIVATION OVERRIDE — approve-pending

Today's daily note has ${NEW_CHECKS} approval item(s) with checked boxes in ## Approvals Pending.
Tyler has signaled intent to apply these items since the last snapshot.

For this turn, you MUST:
1. Call Skill("approve-pending") BEFORE addressing the user's actual message
2. /approve-pending will re-prompt Tyler via AskUserQuestion to confirm each checked item (safety rail) before applying

OVRD2
)
    fi
  fi
fi

# --- Planner push queue detection (informational NOTICE) ---
PLANNER_OVERRIDE=""
PUSH_QUEUE="hub/state/planner-push-queue.json"
if [ -f "$PUSH_QUEUE" ]; then
  # Count unpushed entries — use grep to avoid spawning PowerShell for speed
  UNPUSHED=$(grep -c '"pushed"[[:space:]]*:[[:space:]]*false' "$PUSH_QUEUE" 2>/dev/null || true)
  if [ "${UNPUSHED:-0}" -gt 0 ]; then
    PLANNER_OVERRIDE=$(cat <<OVRD3

---

NOTICE — planner-push-queue has ${UNPUSHED} pending push(es)

hub/state/planner-push-queue.json contains ${UNPUSHED} STATE.md change(s) awaiting sync to Microsoft Planner.
Run /sync-planner push to review and approve them, or /sync-planner to do a full pull+push.

This is a NOTICE, not a forced override — Tyler decides when to push.

OVRD3
)
  fi
fi

# --- Neo auth presence check (non-blocking) ---
# Canonical path (post 2026-04-28): Entra ID token at ~/.neo/config.json
# Fallback path: NEO_API_KEY env var (service-account use)
# Warn only if NEITHER is configured.
if [ ! -f "$HOME/.neo/config.json" ] && [ -z "${NEO_API_KEY:-}" ]; then
  echo "[HOOK:UserPromptSubmit] WARN -- Neo not configured. Run \`neo auth login\` (recommended) or set NEO_API_KEY env var. See docs/morpheus-features/neo-integration.md"
fi

CURRENT_DATETIME=$(date '+%I:%M %p · %Y-%m-%d · %A')

cat <<EOF
Time: ${CURRENT_DATETIME}
INSTRUCTION: You MUST echo the Time line above as the FIRST line of your chat response, formatted as: 🟧  **Time: ${CURRENT_DATETIME}**  🟧 (note: two spaces between each 🟧 and the bold text for breathing room; the orange squares are a visual stand-in for orange background — true terminal background colors cannot be set via this hook output channel)
${INGEST_OVERRIDE}${APPROVAL_OVERRIDE}${PLANNER_OVERRIDE}
EOF
