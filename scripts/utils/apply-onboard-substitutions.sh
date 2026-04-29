#!/bin/bash
# ============================================================
# Script: apply-onboard-substitutions.sh
# Task: 2026-04-28-morpheus-templatize-port (Phase 5 R3)
# Agent: builder
# Created: 2026-04-29
# Last-Updated: 2026-04-29
# Plan: hub/staging/2026-04-28-morpheus-templatize-port/wave-3/repo-architecture.md §2.3
# Purpose: Walk SANITIZE files and apply {{namespace.field}} -> captured-value substitutions.
#   Idempotent: re-running on already-substituted files is a no-op.
# Dependencies: bash 4+, jq (optional fallback to sed-based parsing), GNU sed
# Usage:
#   bash scripts/utils/apply-onboard-substitutions.sh <substitutions.json> [--dry-run]
# Exit codes:
#   0 = success (all substitutions applied + post-validation pass)
#   1 = bad args / missing inputs
#   2 = post-substitution validation failed (residual {{ tokens)
# Changelog (max 10):
#   2026-04-29 | morpheus-templatize-port | builder (Phase 5 R3) | Created cross-platform substitution engine (bash variant).
# ============================================================

set -euo pipefail

# ---- arg parsing ----
SUBS_JSON="${1:-}"
DRY_RUN=0
if [ "${2:-}" = "--dry-run" ]; then DRY_RUN=1; fi

if [ -z "$SUBS_JSON" ] || [ ! -f "$SUBS_JSON" ]; then
  echo "[apply-onboard-substitutions] ERROR: substitutions JSON path required as arg 1" >&2
  echo "Usage: $0 <substitutions.json> [--dry-run]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ---- SANITIZE file list (from manifest-draft.md SANITIZE rows) ----
# Note: paths relative to repo root. Files that may not exist on a fresh clone are filtered.
SANITIZE_FILES=(
  "CLAUDE.md"
  ".claude/rules/scripts.md"
  ".claude/rules/neo.md"
  ".claude/protocols/security.md"
  ".claude/commands/the-protocol.md"
  ".claude/commands/script-scaffold.md"
  ".claude/commands/sign-script.md"
  ".claude/commands/second-opinion.md"
  ".claude/commands/incident-triage.md"
  ".claude/commands/daily-note-management.md"
  ".claude/commands/create-daily-notes.md"
  ".claude/hooks/protocol-execution-audit.ps1"
  ".claude/hooks/plan-compliance-audit.ps1"
  ".claude/hooks/task-discipline-audit.ps1"
  ".claude/hooks/state-frontmatter-validator.ps1"
  ".claude/hooks/prompt-context-loader.sh"
  "hub/templates/build-artifact.md"
  "hub/templates/handoff.md"
  "hub/templates/daily-note.md"
  "knowledge/security/execution-trust-per-file-type.md"
  "scripts/utils/statusline.sh"
  "scripts/utils/test-ingest-hook.sh"
  "docs/getting-started/01-prerequisites.md"
  "docs/getting-started/02-fork-and-customize.md"
  "docs/getting-started/03-first-session.md"
  "docs/getting-started/04-your-first-task.md"
  "docs/README.md"
  "docs/SECOND-OPINION-SETUP.md"
  "docs/reference/dispatch-templates.md"
  "docs/architecture/notes-system.md"
  "docs/customization/adding-rules.md"
)

# ---- key extraction helper ----
# Reads a flat dotted key (e.g., user.name) from substitutions JSON.
# Tries jq first (preferred), falls back to grep+sed.
get_value() {
  local key="$1"
  local val=""
  if command -v jq >/dev/null 2>&1; then
    # jq: convert "user.name" -> ".user.name"
    local jq_path=".$key"
    val=$(jq -r "$jq_path // empty" "$SUBS_JSON" 2>/dev/null || echo "")
  else
    # Fallback: shell grep+sed for simple key:value pairs.
    # Only handles single-line "key": "value" pairs at top level of nested objects.
    # Format: walk the JSON for "<last_segment>": "<value>" within the matching parent object.
    local last_seg
    last_seg="${key##*.}"
    val=$(grep -E "\"$last_seg\"\s*:\s*\"" "$SUBS_JSON" | head -1 | sed -E 's/.*"'"$last_seg"'"\s*:\s*"([^"]*)".*/\1/')
  fi
  echo "$val"
}

# ---- substitution map ----
# Build a Bash assoc array of {{placeholder}} -> value.
declare -A SUBS

# Discover all top-level namespaces in the JSON, then walk fields.
# For simplicity, hardcode the canonical 9 namespaces from architecture spec §2.1.
for ns_field in \
  "user.name" "user.email" "user.role" "user.manager" \
  "company.name" "company.domain" "company.threat-profile" "company.industry" \
  "harness.name" "harness.tagline" "harness.repo-url" \
  "team.manager.name" "team.manager.email" "team.peer-tool-name" \
  "paths.home" "paths.repo_root" "paths.bash" "paths.notes_root" "paths.ingest_root" \
  "ext.neo" "ext.planner" "ext.codex" "ext.signing" \
  "planner.tenant_id" "planner.personal_board_name" \
  "neo.endpoint" "neo.api-base" \
  "signing.cert_subject" "signing.byo" "signing.cert_thumbprint"
do
  val=$(get_value "$ns_field" || echo "")
  if [ -n "$val" ]; then
    SUBS["{{$ns_field}}"]="$val"
  fi
done

echo "[apply-onboard-substitutions] Loaded ${#SUBS[@]} substitutions from $SUBS_JSON"

# ---- per-file substitution ----
APPLIED_COUNT=0
SKIPPED_COUNT=0
FILES_TOUCHED=0

for rel_path in "${SANITIZE_FILES[@]}"; do
  abs_path="$REPO_ROOT/$rel_path"
  if [ ! -f "$abs_path" ]; then
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    continue
  fi

  before_hash=$(sha256sum "$abs_path" 2>/dev/null | awk '{print $1}' || echo "")

  if [ "$DRY_RUN" -eq 1 ]; then
    # In dry-run, just report what would change
    file_changes=0
    for placeholder in "${!SUBS[@]}"; do
      if grep -qF "$placeholder" "$abs_path"; then
        file_changes=$((file_changes + 1))
      fi
    done
    if [ "$file_changes" -gt 0 ]; then
      echo "[dry-run] $rel_path -> $file_changes placeholder(s) would be substituted"
    fi
    continue
  fi

  # Live mode: apply substitutions. Use perl for safe literal-string replacement
  # (sed -i has portability + escape issues with arbitrary user values).
  for placeholder in "${!SUBS[@]}"; do
    val="${SUBS[$placeholder]}"
    # Escape forward slashes and special sed chars in the value:
    # use perl for literal replacement instead.
    if command -v perl >/dev/null 2>&1; then
      ph_esc=$(printf '%s' "$placeholder" | perl -pe 's/([\Q[](){}.+*?|^\$\\\E])/\\$1/g')
      val_esc=$(printf '%s' "$val" | perl -pe 's/(\$|\\|@)/\\$1/g')
      perl -i -pe "s/\\Q$placeholder\\E/$val_esc/g" "$abs_path" 2>/dev/null || true
    else
      # Fallback to sed; user values with `/` will need pre-escape
      val_esc=$(printf '%s' "$val" | sed 's/[\/&]/\\&/g')
      sed -i.bak "s|$placeholder|$val_esc|g" "$abs_path" && rm -f "$abs_path.bak"
    fi
    APPLIED_COUNT=$((APPLIED_COUNT + 1))
  done

  after_hash=$(sha256sum "$abs_path" 2>/dev/null | awk '{print $1}' || echo "")
  if [ "$before_hash" != "$after_hash" ]; then
    FILES_TOUCHED=$((FILES_TOUCHED + 1))
  fi
done

# ---- post-substitution validation ----
RESIDUAL=0
echo ""
echo "[apply-onboard-substitutions] Validating no residual {{ tokens..."
for rel_path in "${SANITIZE_FILES[@]}"; do
  abs_path="$REPO_ROOT/$rel_path"
  [ ! -f "$abs_path" ] && continue
  if grep -qE '\{\{[a-zA-Z]' "$abs_path"; then
    echo "  [WARN] residual placeholder in $rel_path"
    grep -nE '\{\{[a-zA-Z]' "$abs_path" | head -3
    RESIDUAL=$((RESIDUAL + 1))
  fi
done

# ---- summary ----
echo ""
echo "============================================================"
echo "[apply-onboard-substitutions] SUMMARY"
echo "  Substitution map size: ${#SUBS[@]}"
echo "  Applied (cumulative): $APPLIED_COUNT"
echo "  Files touched: $FILES_TOUCHED"
echo "  Files skipped (not present): $SKIPPED_COUNT"
echo "  Residual {{ tokens: $RESIDUAL"
echo "============================================================"

if [ "$RESIDUAL" -gt 0 ]; then
  echo "[apply-onboard-substitutions] FAIL: $RESIDUAL file(s) have residual placeholders. Review and add missing fields to substitutions JSON." >&2
  exit 2
fi

echo "[apply-onboard-substitutions] PASS"
exit 0
