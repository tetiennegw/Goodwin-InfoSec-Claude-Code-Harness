#!/bin/bash
# ============================================================
# System Health Check — Stop Hook
# Source: ishtylerc/claude-code-hooks-framework (adapted for Morpheus)
# Event: Stop
# Purpose: Scans for stale files and token bloat on session end.
#          Logs results and surfaces issues to Claude.
# Changelog (max 10):
#   2026-04-08 | morpheus-foundation | orchestrator | Adapted from hooks framework for Morpheus project structure
# ============================================================

set -euo pipefail

HOOK_NAME="HOOK:Stop:HealthCheck"

# === CONFIGURATION ===
PROJECT_DIR="$(pwd)"
SCAN_DIRS=("$PROJECT_DIR/.claude/agents" "$PROJECT_DIR/.claude/rules" "$PROJECT_DIR/.claude/hooks" "$PROJECT_DIR/hub/templates" "$PROJECT_DIR/hub/patterns")
LOG_DIR="$PROJECT_DIR/.claude/logs"
MAX_LINES=500
MAX_AGE_DAYS=90
# =====================

mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/health-check-$(date '+%Y-%m-%d').log"

echo "=== Morpheus Health Check ===" > "$LOG_FILE"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

ISSUES_FOUND=0

# 1. Stale placeholder files
echo "## Stale Files (>${MAX_AGE_DAYS} days without update)" >> "$LOG_FILE"
for dir in "${SCAN_DIRS[@]}"; do
  [[ ! -d "$dir" ]] && continue
  while IFS= read -r file; do
    [[ ! -f "$file" ]] && continue
    # Check modification time
    MTIME=$(stat -c %Y "$file" 2>/dev/null || date -r "$file" +%s 2>/dev/null || echo 0)
    NOW=$(date +%s)
    AGE_DAYS=$(( (NOW - MTIME) / 86400 ))
    if [ "$AGE_DAYS" -gt "$MAX_AGE_DAYS" ]; then
      echo "  - $file ($AGE_DAYS days old)" >> "$LOG_FILE"
      ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
  done < <(find "$dir" -name "*.md" -type f 2>/dev/null)
done
echo "" >> "$LOG_FILE"

# 2. Token bloat (files > MAX_LINES)
echo "## Token Bloat (>${MAX_LINES} lines)" >> "$LOG_FILE"
for dir in "${SCAN_DIRS[@]}"; do
  [[ ! -d "$dir" ]] && continue
  while IFS= read -r file; do
    [[ ! -f "$file" ]] && continue
    LINES=$(wc -l < "$file" 2>/dev/null | tr -d ' ')
    if [ "$LINES" -gt "$MAX_LINES" ]; then
      echo "  - $file ($LINES lines)" >> "$LOG_FILE"
      ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
  done < <(find "$dir" -name "*.md" -type f 2>/dev/null)
done
echo "" >> "$LOG_FILE"

# Summary
echo "## Summary: $ISSUES_FOUND issues found" >> "$LOG_FILE"

# Output to Claude
if [ "$ISSUES_FOUND" -gt 0 ]; then
  echo "[$HOOK_NAME] FIRED -- $ISSUES_FOUND health issues found:"
  cat "$LOG_FILE"
else
  echo "[$HOOK_NAME] SKIPPED -- No health issues detected"
fi

exit 0
