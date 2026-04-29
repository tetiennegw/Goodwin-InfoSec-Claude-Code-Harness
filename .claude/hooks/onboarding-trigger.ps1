# ============================================================
# Hook: onboarding-trigger.ps1
# Event: SessionStart
# Purpose: detect missing .harness-onboarded sentinel and prepend an /onboard banner.
# Created: 2026-04-29
# Last-Updated: 2026-04-29
# Plan: hub/staging/2026-04-28-morpheus-templatize-port/wave-3/repo-architecture.md
# Dependencies: WinPS 5.1+ or pwsh 7+
# Changelog (max 10):
#   2026-04-29 | morpheus-templatize-port | builder (Phase 5 R2) | Created SessionStart trigger (PS variant).
# ============================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$sentinel = Join-Path $repoRoot '.harness-onboarded'

if (Test-Path -LiteralPath $sentinel) {
    Write-Host '[HOOK:SessionStart] SKIPPED -- .harness-onboarded present; harness already onboarded.'
    exit 0
}

$banner = @'
[HOOK:SessionStart] FIRED -- sentinel missing; prepending /onboard banner.

============================================================
[ONBOARDING REQUIRED]

This appears to be a fresh clone of the Morpheus harness. Run /onboard to
configure identity, paths, and optional extensions before doing real work.

Skip with: New-Item -ItemType File .harness-onboarded
(But expect substituted-with-placeholders state in CLAUDE.md, etc.)
============================================================
'@

Write-Host $banner
exit 0
