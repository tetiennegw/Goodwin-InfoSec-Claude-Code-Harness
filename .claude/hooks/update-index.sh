#!/bin/bash
# ============================================================
# Task: 2026-04-06-morpheus-foundation
# Agent: builder
# Created: 2026-04-07T00:00:00
# Last-Updated: 2026-04-07T00:00:00
# Purpose: PostToolUse(Write) hook — appends newly written files to INDEX.md
# Dependencies: jq, bash
# Changelog (max 10):
#   2026-04-07T00:00 | morpheus-foundation | builder | Created initial hook script
# ============================================================
# chmod +x .claude/hooks/update-index.sh

# Self-orient to project root (defensive — works regardless of caller's cwd or env vars)
__HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || exit 0
__PROJECT_ROOT="$(cd "${__HOOK_DIR}/../.." 2>/dev/null && pwd)" || exit 0
cd "${__PROJECT_ROOT}" || exit 0

set -euo pipefail

HOOK_NAME="HOOK:PostToolUse:Write"
INDEX_FILE="INDEX.md"

# Read stdin JSON and extract file_path and cwd
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)

# If no file path extracted, skip
if [[ -z "$FILE_PATH" ]]; then
  echo "[$HOOK_NAME] SKIPPED — Could not extract file_path from input"
  exit 0
fi

# Use CWD if available, otherwise current directory
if [[ -z "$CWD" ]]; then
  CWD="$(pwd)"
fi

# Compute relative path from CWD
# Normalize paths: convert backslashes to forward slashes (Windows compat)
FILE_PATH_NORM=$(echo "$FILE_PATH" | sed 's|\\|/|g')
CWD_NORM=$(echo "$CWD" | sed 's|\\|/|g')

# Try to make relative path
if [[ "$FILE_PATH_NORM" == "$CWD_NORM"/* ]]; then
  REL_PATH="${FILE_PATH_NORM#"$CWD_NORM"/}"
else
  # If we can't compute relative, use the full path
  REL_PATH="$FILE_PATH_NORM"
fi

# Extract just the filename
FILENAME=$(basename "$REL_PATH")

# Skip if the file IS INDEX.md (avoid recursion)
if [[ "$FILENAME" == "INDEX.md" ]]; then
  echo "[$HOOK_NAME] SKIPPED — File is INDEX.md itself"
  exit 0
fi

# Skip files in .git/ or node_modules/
if [[ "$REL_PATH" == .git/* ]] || [[ "$REL_PATH" == node_modules/* ]]; then
  echo "[$HOOK_NAME] SKIPPED — File is in excluded directory ($REL_PATH)"
  exit 0
fi

# Check if INDEX.md exists; if not, create it with header
if [[ ! -f "$INDEX_FILE" ]]; then
  cat > "$INDEX_FILE" << 'HEADER'
# TE GW Brain — Index

## Uncategorized
HEADER
  echo "[$HOOK_NAME] FIRED — Created INDEX.md and added $REL_PATH"
fi

# Check if the relative path is already in INDEX.md
if grep -qF "$REL_PATH" "$INDEX_FILE" 2>/dev/null; then
  echo "[$HOOK_NAME] SKIPPED — $REL_PATH already in INDEX.md"
  exit 0
fi

# Determine section based on path prefix
SECTION="Uncategorized"
if [[ "$REL_PATH" == hub/* ]]; then
  SECTION="Hub"
elif [[ "$REL_PATH" == scripts/* ]]; then
  SECTION="Scripts"
elif [[ "$REL_PATH" == knowledge/* ]]; then
  SECTION="Knowledge Base"
elif [[ "$REL_PATH" == notes/* ]]; then
  SECTION="Operational"
elif [[ "$REL_PATH" == ops/* ]]; then
  SECTION="Operational"
elif [[ "$REL_PATH" == .claude/* ]]; then
  SECTION="Configuration"
elif [[ "$REL_PATH" == docs/* ]]; then
  SECTION="Documentation"
fi

# Check if the section heading exists in INDEX.md
if grep -q "^## $SECTION" "$INDEX_FILE" 2>/dev/null; then
  # Append under the existing section (after the heading line)
  sed -i "/^## $SECTION/a - [$FILENAME]($REL_PATH)" "$INDEX_FILE"
else
  # Append at the end under a new section
  echo "" >> "$INDEX_FILE"
  echo "## $SECTION" >> "$INDEX_FILE"
  echo "- [$FILENAME]($REL_PATH)" >> "$INDEX_FILE"
fi

echo "[$HOOK_NAME] FIRED — Added $REL_PATH to INDEX.md under $SECTION"
