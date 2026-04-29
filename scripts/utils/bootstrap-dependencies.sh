#!/bin/bash
# ============================================================
# Script: bootstrap-dependencies.sh
# Task: 2026-04-28-morpheus-templatize-port (Phase 5 R4)
# Agent: builder
# Created: 2026-04-29
# Last-Updated: 2026-04-29
# Plan: hub/staging/2026-04-28-morpheus-templatize-port/wave-2/runtime-deps.md §/onboard Bootstrap Recommendations
# Purpose: Validate-or-install the 16-step dependency chain from runtime-deps.md.
#   Each dep is install-or-validate; optional deps prompt before install via ASK_USER_QUESTION_PLACEHOLDER
#   stdout markers (consumed by /onboard skill body which fires the AskUserQuestion).
# Usage:
#   bash scripts/utils/bootstrap-dependencies.sh [--substitutions <json>] [--dry-run]
# Dependencies: bash 4+, GNU coreutils, winget (Windows install path), pwsh (optional checks)
# Outputs: structured JSON summary to stdout (last line) for /onboard sentinel write-back.
# Changelog (max 10):
#   2026-04-29 | morpheus-templatize-port | builder (Phase 5 R4) | Created dep-bootstrap script (bash variant).
# ============================================================

set -uo pipefail

SUBS_JSON=""
DRY_RUN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --substitutions) SUBS_JSON="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# ---- helper: report a step status ----
INSTALLED=()
VALIDATED=()
SKIPPED=()
PROMPT=()

report_validated() { VALIDATED+=("$1"); echo "  [VALIDATED] $1"; }
report_installed() { INSTALLED+=("$1"); echo "  [INSTALLED] $1"; }
report_skipped() { SKIPPED+=("$1"); echo "  [SKIPPED] $1"; }
report_prompt() { PROMPT+=("$1"); echo "  [NEEDS-USER] $1"; }

# ---- helper: try to read ext.* flag from substitutions JSON ----
get_ext() {
  local name="$1"
  if [ -z "$SUBS_JSON" ] || [ ! -f "$SUBS_JSON" ]; then
    echo "false"; return
  fi
  if command -v jq >/dev/null 2>&1; then
    jq -r ".ext.$name // false" "$SUBS_JSON" 2>/dev/null || echo "false"
  else
    grep -E "\"$name\"" "$SUBS_JSON" | head -1 | grep -oE 'true|false' | head -1 || echo "false"
  fi
}

EXT_NEO=$(get_ext neo)
EXT_PLANNER=$(get_ext planner)
EXT_CODEX=$(get_ext codex)
EXT_SIGNING=$(get_ext signing)

echo "============================================================"
echo "[bootstrap-dependencies] Starting 16-step bootstrap"
echo "  Extensions: neo=$EXT_NEO planner=$EXT_PLANNER codex=$EXT_CODEX signing=$EXT_SIGNING"
echo "  Dry-run: $DRY_RUN"
echo "============================================================"

# ---- step 1: detect OS + Goodwin endpoint ----
echo ""
echo "[step 1] Detecting OS + endpoint type..."
OS_TYPE=""
IS_GOODWIN=0
case "${OS:-}" in
  Windows_NT) OS_TYPE="Windows_NT" ;;
  *) OS_TYPE="$(uname -s 2>/dev/null || echo unknown)" ;;
esac

# Goodwin endpoint signals: ThreatLocker installed OR AllSigned execution policy
if [ -d "/c/Program Files/ThreatLocker" ] || [ -d "C:/Program Files/ThreatLocker" ] 2>/dev/null; then
  IS_GOODWIN=1
fi
echo "  OS: $OS_TYPE | IsGoodwinEndpoint: $IS_GOODWIN"
if [ "$OS_TYPE" != "Windows_NT" ] && [ "$(uname -s 2>/dev/null)" != "MINGW64_NT" ]; then
  echo "  [WARN] non-Windows OS detected; harness is Windows-shaped. Continue with degradation."
fi
report_validated "step 1: os-detect ($OS_TYPE)"

# ---- step 2: verify Git + Git Bash ----
echo ""
echo "[step 2] Verifying Git + Git Bash..."
if command -v git >/dev/null 2>&1; then
  GIT_VER=$(git --version | head -1)
  report_validated "step 2: git ($GIT_VER)"
else
  report_prompt "step 2: git missing -- install Git for Windows"
fi

if command -v bash >/dev/null 2>&1; then
  BASH_PATH=$(command -v bash)
  report_validated "step 2: bash ($BASH_PATH)"
else
  report_prompt "step 2: bash missing"
fi

# ---- step 3: verify Claude Code CLI ----
echo ""
echo "[step 3] Verifying Claude Code CLI..."
if command -v claude >/dev/null 2>&1; then
  CLAUDE_VER=$(claude --version 2>/dev/null | head -1 || echo "unknown")
  report_validated "step 3: claude ($CLAUDE_VER)"
else
  report_prompt "step 3: claude missing -- run: winget install Anthropic.ClaudeCode"
fi

# ---- step 4: verify Node.js 18+ ----
echo ""
echo "[step 4] Verifying Node.js 18+..."
if command -v node >/dev/null 2>&1; then
  NODE_VER=$(node --version | sed 's/v//')
  NODE_MAJOR=$(echo "$NODE_VER" | cut -d. -f1)
  if [ "$NODE_MAJOR" -ge 18 ] 2>/dev/null; then
    report_validated "step 4: node $NODE_VER (>=18 OK)"
  else
    report_prompt "step 4: node $NODE_VER (<18; upgrade via winget install OpenJS.NodeJS.LTS)"
  fi
else
  report_prompt "step 4: node missing"
fi

# ---- step 5: verify PowerShell 7+ ----
echo ""
echo "[step 5] Verifying PowerShell 7+..."
if command -v pwsh >/dev/null 2>&1; then
  PWSH_VER=$(pwsh --version 2>/dev/null | head -1)
  report_validated "step 5: pwsh ($PWSH_VER)"
else
  report_prompt "step 5: pwsh missing -- run: winget install Microsoft.PowerShell"
fi

# ---- step 6: optional jq install ----
echo ""
echo "[step 6] Verifying jq..."
if command -v jq >/dev/null 2>&1; then
  report_validated "step 6: jq ($(jq --version))"
else
  report_skipped "step 6: jq missing (PS ConvertFrom-Json fallback works)"
fi

# ---- step 7: ANTHROPIC_API_KEY ----
echo ""
echo "[step 7] Checking ANTHROPIC_API_KEY..."
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  report_validated "step 7: ANTHROPIC_API_KEY env present"
elif command -v claude >/dev/null 2>&1 && claude auth status 2>/dev/null | grep -q "authenticated"; then
  report_validated "step 7: claude auth active"
else
  report_prompt "step 7: ANTHROPIC_API_KEY missing -- run 'claude auth login' or 'setx ANTHROPIC_API_KEY <key>'"
fi

# ---- step 8: corporate-proxy CA (Goodwin-detected only) ----
echo ""
echo "[step 8] Corporate-proxy CA check..."
if [ "$IS_GOODWIN" = "1" ]; then
  CA_PATH="$USERPROFILE/goodwin-root-ca.pem"
  if [ -f "$CA_PATH" ]; then
    if [ -n "${NODE_EXTRA_CA_CERTS:-}" ]; then
      report_validated "step 8: NODE_EXTRA_CA_CERTS already set"
    else
      report_prompt "step 8: NODE_EXTRA_CA_CERTS not set -- consider: setx NODE_EXTRA_CA_CERTS \"$CA_PATH\""
    fi
  else
    report_skipped "step 8: goodwin-root-ca.pem not found at $CA_PATH"
  fi
else
  report_skipped "step 8: not a Goodwin endpoint; skipping corporate-proxy CA"
fi

# ---- step 9: optional gh CLI ----
echo ""
echo "[step 9] Optional gh CLI..."
if command -v gh >/dev/null 2>&1; then
  report_validated "step 9: gh ($(gh --version | head -1))"
else
  report_prompt "step 9: gh missing (optional; install via 'winget install GitHub.cli --scope user')"
fi

# ---- step 10: Codex (if ext.codex=true) ----
echo ""
echo "[step 10] Codex CLI..."
if [ "$EXT_CODEX" = "true" ]; then
  if command -v codex >/dev/null 2>&1; then
    report_validated "step 10: codex enabled and installed"
  else
    report_prompt "step 10: codex missing -- run 'winget install OpenAI.Codex' + setx OPENAI_API_KEY"
  fi
else
  report_skipped "step 10: ext.codex=false; skipping"
fi

# ---- step 11: Neo (if ext.neo=true AND Goodwin) ----
echo ""
echo "[step 11] Neo CLI..."
if [ "$EXT_NEO" = "true" ]; then
  if command -v neo >/dev/null 2>&1; then
    report_validated "step 11: neo enabled and installed"
  else
    report_prompt "step 11: neo missing -- Goodwin-distributed binary; ask {{team.manager.name}} / SOC team"
  fi
else
  report_skipped "step 11: ext.neo=false; skipping"
fi

# ---- step 12: Microsoft.Graph.Planner (if ext.planner=true) ----
echo ""
echo "[step 12] Microsoft.Graph.Planner module..."
if [ "$EXT_PLANNER" = "true" ]; then
  if command -v pwsh >/dev/null 2>&1; then
    if pwsh -NoProfile -Command "Get-Module -ListAvailable Microsoft.Graph.Planner" 2>/dev/null | grep -q "Microsoft.Graph.Planner"; then
      report_validated "step 12: Microsoft.Graph.Planner installed"
    else
      report_prompt "step 12: install via 'pwsh -Command Install-Module Microsoft.Graph.Planner -Scope CurrentUser'"
    fi
  else
    report_skipped "step 12: pwsh missing; cannot check Planner module"
  fi
else
  report_skipped "step 12: ext.planner=false; skipping"
fi

# ---- step 13: optional Pester ----
echo ""
echo "[step 13] Optional Pester..."
if command -v pwsh >/dev/null 2>&1; then
  if pwsh -NoProfile -Command "Get-Module -ListAvailable Pester" 2>/dev/null | grep -q "Pester"; then
    report_validated "step 13: Pester installed"
  else
    report_skipped "step 13: Pester missing (testing-only; install with Install-Module Pester -Scope CurrentUser)"
  fi
else
  report_skipped "step 13: pwsh missing"
fi

# ---- step 14: code-signing cert (Goodwin OR BYO) ----
echo ""
echo "[step 14] Code-signing cert..."
if [ "$EXT_SIGNING" = "true" ]; then
  if command -v pwsh >/dev/null 2>&1; then
    CERT_COUNT=$(pwsh -NoProfile -Command "(Get-ChildItem Cert:\\CurrentUser\\My -CodeSigningCert -ErrorAction SilentlyContinue).Count" 2>/dev/null || echo "0")
    if [ "$CERT_COUNT" != "0" ] && [ -n "$CERT_COUNT" ]; then
      report_validated "step 14: code-signing cert present ($CERT_COUNT in CurrentUser\\My)"
    else
      report_prompt "step 14: no code-signing cert found in CurrentUser\\My (BYO required)"
    fi
  else
    report_skipped "step 14: pwsh missing; cannot inspect cert store"
  fi
else
  report_skipped "step 14: ext.signing=false (will use ExecutionPolicy=Bypass for hooks)"
fi

# ---- step 15: hub state init (handled by /onboard step 5; verify here) ----
echo ""
echo "[step 15] Hub state files..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LEDGER="$REPO_ROOT/hub/state/harness-audit-ledger.md"
if [ -f "$LEDGER" ]; then
  if grep -q "LEDGER-APPEND-ANCHOR" "$LEDGER"; then
    report_validated "step 15: harness-audit-ledger.md present with anchor"
  else
    report_prompt "step 15: harness-audit-ledger.md missing LEDGER-APPEND-ANCHOR"
  fi
else
  report_prompt "step 15: harness-audit-ledger.md not found"
fi

# ---- step 16: hook signing (Goodwin AllSigned only) ----
echo ""
echo "[step 16] Hook signing..."
if [ "$EXT_SIGNING" = "true" ] && [ "$IS_GOODWIN" = "1" ]; then
  report_prompt "step 16: run /sign-script over .claude/hooks/*.ps1 (Goodwin AllSigned policy)"
else
  report_skipped "step 16: signing not required (BYO mode or non-Goodwin endpoint)"
fi

# ---- structured JSON summary (final stdout line for /onboard consumption) ----
echo ""
echo "============================================================"
echo "[bootstrap-dependencies] DONE"
echo "  Validated: ${#VALIDATED[@]}"
echo "  Installed: ${#INSTALLED[@]}"
echo "  Skipped: ${#SKIPPED[@]}"
echo "  Needs user action: ${#PROMPT[@]}"
echo "============================================================"

# Final JSON line for sentinel feed
JSON_VALIDATED=$(printf '"%s",' "${VALIDATED[@]}" | sed 's/,$//')
JSON_PROMPT=$(printf '"%s",' "${PROMPT[@]}" | sed 's/,$//')
JSON_SKIPPED=$(printf '"%s",' "${SKIPPED[@]}" | sed 's/,$//')
echo "BOOTSTRAP_SUMMARY_JSON: {\"validated\":[$JSON_VALIDATED],\"prompts\":[$JSON_PROMPT],\"skipped\":[$JSON_SKIPPED],\"is_goodwin\":$IS_GOODWIN}"

exit 0
