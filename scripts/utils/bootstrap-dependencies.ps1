# ============================================================
# Script: bootstrap-dependencies.ps1
# Task: 2026-04-28-morpheus-templatize-port (Phase 5 R4)
# Agent: builder
# Created: 2026-04-29
# Last-Updated: 2026-04-29
# Plan: hub/staging/2026-04-28-morpheus-templatize-port/wave-2/runtime-deps.md
# Purpose: PowerShell variant of bootstrap-dependencies.sh.
#   16-step validate-or-install chain; emits BOOTSTRAP_SUMMARY_JSON for /onboard sentinel.
# Dependencies: WinPS 5.1+ or pwsh 7+
# Changelog (max 10):
#   2026-04-29 | morpheus-templatize-port | builder (Phase 5 R4) | Created PS variant of dep-bootstrap.
# ============================================================

[CmdletBinding()]
param(
    [string]$SubstitutionsPath = '',
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

# ---- load extension flags from substitutions JSON ----
$extNeo = $false; $extPlanner = $false; $extCodex = $false; $extSigning = $false
if ($SubstitutionsPath -and (Test-Path -LiteralPath $SubstitutionsPath)) {
    try {
        $subs = Get-Content -LiteralPath $SubstitutionsPath -Raw | ConvertFrom-Json
        if ($subs.PSObject.Properties.Name -contains 'ext') {
            if ($subs.ext.PSObject.Properties.Name -contains 'neo') { $extNeo = [bool]$subs.ext.neo }
            if ($subs.ext.PSObject.Properties.Name -contains 'planner') { $extPlanner = [bool]$subs.ext.planner }
            if ($subs.ext.PSObject.Properties.Name -contains 'codex') { $extCodex = [bool]$subs.ext.codex }
            if ($subs.ext.PSObject.Properties.Name -contains 'signing') { $extSigning = [bool]$subs.ext.signing }
        }
    } catch {
        Write-Host "[bootstrap-dependencies] WARN: could not parse $SubstitutionsPath ($_)"
    }
}

# ---- result buckets ----
$validated = @()
$installed = @()
$skipped = @()
$prompts = @()

function Report-Validated([string]$msg) { $script:validated += $msg; Write-Host "  [VALIDATED] $msg" }
function Report-Installed([string]$msg) { $script:installed += $msg; Write-Host "  [INSTALLED] $msg" }
function Report-Skipped([string]$msg) { $script:skipped += $msg; Write-Host "  [SKIPPED] $msg" }
function Report-Prompt([string]$msg) { $script:prompts += $msg; Write-Host "  [NEEDS-USER] $msg" }

function Test-Command([string]$name) {
    return $null -ne (Get-Command $name -ErrorAction SilentlyContinue)
}

Write-Host '============================================================'
Write-Host '[bootstrap-dependencies] Starting 16-step bootstrap'
Write-Host "  Extensions: neo=$extNeo planner=$extPlanner codex=$extCodex signing=$extSigning"
Write-Host "  DryRun: $DryRun"
Write-Host '============================================================'

# ---- step 1: detect OS + Goodwin endpoint ----
Write-Host ''; Write-Host '[step 1] Detecting OS + endpoint type...'
$osType = if ($IsWindows -or $env:OS -eq 'Windows_NT') { 'Windows_NT' } else { 'unknown' }
$isGoodwin = $false
if (Test-Path 'C:\Program Files\ThreatLocker') { $isGoodwin = $true }
try {
    $execPolicy = Get-ExecutionPolicy -Scope LocalMachine -ErrorAction SilentlyContinue
    if ($execPolicy -eq 'AllSigned') { $isGoodwin = $true }
} catch {}
Write-Host "  OS: $osType | IsGoodwinEndpoint: $isGoodwin"
Report-Validated "step 1: os-detect ($osType)"

# ---- step 2: Git + Git Bash ----
Write-Host ''; Write-Host '[step 2] Verifying Git + Git Bash...'
if (Test-Command 'git') { Report-Validated "step 2: git ($(git --version))" } else { Report-Prompt 'step 2: git missing' }
if (Test-Command 'bash') { Report-Validated "step 2: bash present" } else { Report-Prompt 'step 2: bash missing' }

# ---- step 3: Claude Code CLI ----
Write-Host ''; Write-Host '[step 3] Verifying Claude Code CLI...'
if (Test-Command 'claude') {
    $claudeVer = (claude --version 2>&1 | Out-String).Trim()
    Report-Validated "step 3: claude ($claudeVer)"
} else {
    Report-Prompt 'step 3: claude missing -- run: winget install Anthropic.ClaudeCode'
}

# ---- step 4: Node.js 18+ ----
Write-Host ''; Write-Host '[step 4] Verifying Node.js 18+...'
if (Test-Command 'node') {
    $nodeVer = (node --version 2>&1 | Out-String).Trim() -replace '^v', ''
    $nodeMajor = [int]($nodeVer.Split('.')[0])
    if ($nodeMajor -ge 18) {
        Report-Validated "step 4: node $nodeVer (>=18 OK)"
    } else {
        Report-Prompt "step 4: node $nodeVer (<18; upgrade)"
    }
} else {
    Report-Prompt 'step 4: node missing -- winget install OpenJS.NodeJS.LTS'
}

# ---- step 5: pwsh 7+ ----
Write-Host ''; Write-Host '[step 5] Verifying PowerShell 7+...'
if (Test-Command 'pwsh') {
    Report-Validated "step 5: pwsh ($(pwsh --version))"
} else {
    Report-Prompt 'step 5: pwsh missing -- winget install Microsoft.PowerShell'
}

# ---- step 6: jq ----
Write-Host ''; Write-Host '[step 6] Verifying jq (optional)...'
if (Test-Command 'jq') { Report-Validated "step 6: jq present" } else { Report-Skipped 'step 6: jq missing (PS ConvertFrom-Json fallback OK)' }

# ---- step 7: ANTHROPIC_API_KEY ----
Write-Host ''; Write-Host '[step 7] Checking ANTHROPIC_API_KEY...'
if ($env:ANTHROPIC_API_KEY) {
    Report-Validated 'step 7: ANTHROPIC_API_KEY env present'
} else {
    Report-Prompt 'step 7: ANTHROPIC_API_KEY missing -- run claude auth login'
}

# ---- step 8: corporate-proxy CA ----
Write-Host ''; Write-Host '[step 8] Corporate-proxy CA check...'
if ($isGoodwin) {
    $caPath = Join-Path $env:USERPROFILE 'goodwin-root-ca.pem'
    if (Test-Path -LiteralPath $caPath) {
        if ($env:NODE_EXTRA_CA_CERTS) {
            Report-Validated 'step 8: NODE_EXTRA_CA_CERTS already set'
        } else {
            Report-Prompt "step 8: NODE_EXTRA_CA_CERTS not set -- setx NODE_EXTRA_CA_CERTS `"$caPath`""
        }
    } else {
        Report-Skipped "step 8: goodwin-root-ca.pem not found at $caPath"
    }
} else {
    Report-Skipped 'step 8: not a Goodwin endpoint; skipping'
}

# ---- step 9: gh CLI (optional) ----
Write-Host ''; Write-Host '[step 9] Optional gh CLI...'
if (Test-Command 'gh') { Report-Validated 'step 9: gh present' } else { Report-Prompt 'step 9: gh missing (optional)' }

# ---- step 10: Codex ----
Write-Host ''; Write-Host '[step 10] Codex CLI...'
if ($extCodex) {
    if (Test-Command 'codex') { Report-Validated 'step 10: codex enabled and installed' }
    else { Report-Prompt 'step 10: codex missing -- winget install OpenAI.Codex' }
} else { Report-Skipped 'step 10: ext.codex=false; skipping' }

# ---- step 11: Neo ----
Write-Host ''; Write-Host '[step 11] Neo CLI...'
if ($extNeo) {
    if (Test-Command 'neo') { Report-Validated 'step 11: neo enabled and installed' }
    else { Report-Prompt 'step 11: neo missing -- Goodwin internal binary' }
} else { Report-Skipped 'step 11: ext.neo=false; skipping' }

# ---- step 12: Microsoft.Graph.Planner ----
Write-Host ''; Write-Host '[step 12] Microsoft.Graph.Planner...'
if ($extPlanner) {
    if (Get-Module -ListAvailable Microsoft.Graph.Planner -ErrorAction SilentlyContinue) {
        Report-Validated 'step 12: Microsoft.Graph.Planner installed'
    } else {
        Report-Prompt 'step 12: Install-Module Microsoft.Graph.Planner -Scope CurrentUser'
    }
} else { Report-Skipped 'step 12: ext.planner=false; skipping' }

# ---- step 13: Pester ----
Write-Host ''; Write-Host '[step 13] Optional Pester...'
if (Get-Module -ListAvailable Pester -ErrorAction SilentlyContinue) {
    Report-Validated 'step 13: Pester installed'
} else {
    Report-Skipped 'step 13: Pester missing (testing-only)'
}

# ---- step 14: signing cert ----
Write-Host ''; Write-Host '[step 14] Code-signing cert...'
if ($extSigning) {
    $certs = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert -ErrorAction SilentlyContinue
    if ($certs.Count -gt 0) {
        Report-Validated "step 14: $($certs.Count) code-signing cert(s) in CurrentUser\My"
    } else {
        Report-Prompt 'step 14: no code-signing cert found (BYO required)'
    }
} else {
    Report-Skipped 'step 14: ext.signing=false (ExecutionPolicy=Bypass for hooks)'
}

# ---- step 15: hub state ----
Write-Host ''; Write-Host '[step 15] Hub state files...'
$repoRoot = (Get-Item (Join-Path $PSScriptRoot '..\..')).FullName
$ledger = Join-Path $repoRoot 'hub\state\harness-audit-ledger.md'
if (Test-Path -LiteralPath $ledger) {
    $ledgerContent = Get-Content -LiteralPath $ledger -Raw -ErrorAction SilentlyContinue
    if ($ledgerContent -match 'LEDGER-APPEND-ANCHOR') {
        Report-Validated 'step 15: harness-audit-ledger.md present with anchor'
    } else {
        Report-Prompt 'step 15: harness-audit-ledger.md missing LEDGER-APPEND-ANCHOR'
    }
} else {
    Report-Prompt 'step 15: harness-audit-ledger.md not found'
}

# ---- step 16: hook signing ----
Write-Host ''; Write-Host '[step 16] Hook signing...'
if ($extSigning -and $isGoodwin) {
    Report-Prompt 'step 16: run /sign-script over .claude/hooks/*.ps1'
} else {
    Report-Skipped 'step 16: signing not required'
}

# ---- summary ----
Write-Host ''
Write-Host '============================================================'
Write-Host '[bootstrap-dependencies] DONE'
Write-Host "  Validated: $($validated.Count)"
Write-Host "  Installed: $($installed.Count)"
Write-Host "  Skipped: $($skipped.Count)"
Write-Host "  Needs user action: $($prompts.Count)"
Write-Host '============================================================'

# JSON summary line
$summary = @{
    validated = $validated
    prompts = $prompts
    skipped = $skipped
    installed = $installed
    is_goodwin = $isGoodwin
} | ConvertTo-Json -Compress
Write-Host "BOOTSTRAP_SUMMARY_JSON: $summary"

exit 0
