#!/bin/bash
# ============================================================
# Task: 2026-04-17-morpheus-feature-docs
# Agent: morpheus
# Created: 2026-04-17T10:41
# Last-Updated: 2026-04-17T10:41
# Plan: hub/staging/2026-04-17-morpheus-feature-docs/STATE.md
# Purpose: Detect changes to Morpheus feature/architecture files and surface doc debt to today's daily note.
# Dependencies: bash, standard POSIX utilities. No jq/python needed (per Goodwin toolchain memory).
# Changelog (max 10):
#   2026-04-17T10:41 | 2026-04-17-morpheus-feature-docs | morpheus | Created passive-reminder hook that watches .claude/commands/**, .claude/hooks/**, scripts/** and appends doc-review todos to daily note under Tomorrow's Prep.
# ============================================================

set -euo pipefail

# PostToolUse hook payload is delivered via env vars set by Claude Code harness.
# We pattern-match on CLAUDE_TOOL_PARAMS_FILE_PATH (or fall back to reading stdin JSON
# via pwsh ConvertFrom-Json — that's the portable path on Goodwin endpoints).

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_ROOT"

# ---- Resolve target path from hook payload --------------------------------------

target_path=""
if [[ -n "${CLAUDE_TOOL_PARAMS_FILE_PATH:-}" ]]; then
  target_path="$CLAUDE_TOOL_PARAMS_FILE_PATH"
elif [[ -t 0 ]]; then
  # No stdin (interactive test). Nothing to do.
  echo "[HOOK:feature-change-detector] SKIPPED — no payload"
  exit 0
else
  # Read JSON from stdin and extract .tool_input.file_path via pwsh
  payload="$(cat || true)"
  if [[ -z "$payload" ]]; then
    echo "[HOOK:feature-change-detector] SKIPPED — empty payload"
    exit 0
  fi
  target_path="$(printf '%s' "$payload" | pwsh -NoProfile -Command '
    $j = [Console]::In.ReadToEnd() | ConvertFrom-Json -AsHashtable -ErrorAction SilentlyContinue
    if ($null -ne $j -and $j.ContainsKey("tool_input") -and $j.tool_input.ContainsKey("file_path")) {
      Write-Output $j.tool_input.file_path
    }
  ' 2>/dev/null || true)"
fi

if [[ -z "$target_path" ]]; then
  echo "[HOOK:feature-change-detector] SKIPPED — no target path"
  exit 0
fi

# Normalize to project-relative forward-slash path
rel_path="${target_path#$PROJECT_ROOT/}"
rel_path="${rel_path//\\//}"

# ---- Match against feature surfaces ----------------------------------------------

feature_slug=""
feature_kind=""

case "$rel_path" in
  .claude/commands/*.md)
    # Skill file — slug = filename without .md
    base="$(basename "$rel_path" .md)"
    # Skip stock Claude Code skills + scaffold skills
    case "$base" in
      init|review|security-review|frontend-design|doc|simplify|loop|schedule|claude-api|less-permission-prompts|keybindings-help|update-config)
        echo "[HOOK:feature-change-detector] SKIPPED — $base is a stock/scaffold skill"
        exit 0
        ;;
    esac
    feature_slug="$base"
    feature_kind="skill"
    ;;
  .claude/hooks/*.sh|.claude/hooks/*.ps1)
    base="$(basename "$rel_path")"
    base="${base%.sh}"
    base="${base%.ps1}"
    # Skip utility hooks that are not user-facing features
    case "$base" in
      prepend-reminder|update-index|generate-active-tasks|daily-note-check|daily-note-watch|task-compliance-check|plan-mode-context|prompt-context-loader|ensure-note)
        echo "[HOOK:feature-change-detector] SKIPPED — $base is a utility hook, not a feature"
        exit 0
        ;;
    esac
    feature_slug="$base"
    feature_kind="hook"
    ;;
  scripts/*/*.psm1|scripts/*/*.psd1)
    # Module file — slug = containing directory name
    dir="$(dirname "$rel_path")"
    feature_slug="$(basename "$dir")"
    feature_kind="module"
    ;;
  *)
    # Not a tracked feature surface
    exit 0
    ;;
esac

if [[ -z "$feature_slug" ]]; then
  echo "[HOOK:feature-change-detector] SKIPPED — no slug resolved"
  exit 0
fi

# ---- Check if a feature doc already exists for this slug -------------------------

# Candidates: exact slug, slug-prefix matches, or reference in docs/morpheus-features/README.md
doc_path="docs/morpheus-features/${feature_slug}.md"
doc_exists="false"
if [[ -f "$doc_path" ]]; then
  doc_exists="true"
fi

# Also check the README index for a reference (handles slug aliases)
if [[ "$doc_exists" != "true" && -f "docs/morpheus-features/README.md" ]]; then
  if grep -q "\`${feature_slug}\`" docs/morpheus-features/README.md 2>/dev/null; then
    doc_exists="true"
  fi
fi

# ---- Resolve today's daily note --------------------------------------------------

year="$(date '+%Y')"
month="$(date '+%m')"
today="$(date '+%Y-%m-%d')"
daily_note="notes/${year}/${month}/${today}.md"

if [[ ! -f "$daily_note" ]]; then
  echo "[HOOK:feature-change-detector] SKIPPED — today's daily note not found at $daily_note"
  exit 0
fi

# ---- Build the todo line ---------------------------------------------------------

if [[ "$doc_exists" == "true" ]]; then
  verb="update"
  note="changed in this session — run /document-feature update $feature_slug"
else
  verb="new"
  note="has no feature doc yet — run /document-feature new $feature_slug"
fi

todo_line="- [ ] Doc review: \`$feature_slug\` ($feature_kind) $note"

# ---- Idempotent append: skip if line already present -----------------------------

if grep -Fq "$todo_line" "$daily_note" 2>/dev/null; then
  echo "[HOOK:feature-change-detector] SKIPPED — todo already logged for $feature_slug"
  exit 0
fi

# ---- Append under Tomorrow's Prep ------------------------------------------------

# Find "## Tomorrow's Prep" line, insert todo after the first empty checkbox line there.
# Use a temp file to avoid partial writes.

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

awk -v todo="$todo_line" '
  BEGIN { inserted = 0; in_tomorrow = 0 }
  /^## Tomorrow.s Prep/ { in_tomorrow = 1; print; next }
  /^## / && in_tomorrow && !inserted {
    # Leaving the section without having inserted — insert before this heading
    print todo
    inserted = 1
    in_tomorrow = 0
    print
    next
  }
  in_tomorrow && !inserted && /^- \[ \] *$/ {
    # Replace the first empty checkbox line with our todo
    print todo
    inserted = 1
    next
  }
  { print }
  END {
    if (in_tomorrow && !inserted) {
      # File ended while still in Tomorrow Prep section -- append at end
      print todo
    }
  }
' "$daily_note" > "$tmp"

# Verify non-empty output before clobber
if [[ ! -s "$tmp" ]]; then
  echo "[HOOK:feature-change-detector] ERROR — awk produced empty output, aborting"
  exit 1
fi

mv "$tmp" "$daily_note"

echo "[HOOK:feature-change-detector] FIRED — logged doc-review todo for $feature_slug ($feature_kind, $verb)"
exit 0
