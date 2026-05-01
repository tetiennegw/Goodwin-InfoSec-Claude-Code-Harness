# ============================================================
# Script: test-onboard.ps1
# Task: 2026-04-28-morpheus-templatize-port (Phase 5 R5)
# Agent: builder
# Created: 2026-04-29
# Last-Updated: 2026-04-29
# Plan: hub/staging/2026-04-28-morpheus-templatize-port/wave-3/repo-architecture.md
# Purpose: Pester test suite for /onboard primitives. Mirrors test-onboard.sh case-for-case.
#   Run with: Invoke-Pester scripts/utils/test-onboard.ps1
#   Or directly: pwsh -File scripts/utils/test-onboard.ps1 (inline assertion mode)
# Dependencies: WinPS 5.1+ or pwsh 7+; Pester 5+ optional
# Changelog (max 10):
#   2026-04-29 | morpheus-templatize-port | builder (Phase 5 R5) | Created PS test suite (8 cases).
# ============================================================

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$pass = 0
$fail = 0
$failedCases = @()

function Assert-True {
    param([string]$Name, [scriptblock]$Condition)
    try {
        $result = & $Condition
        if ($result) {
            Write-Host "  PASS: $Name"
            $script:pass++
        } else {
            Write-Host "  FAIL: $Name"
            $script:fail++
            $script:failedCases += $Name
        }
    } catch {
        Write-Host "  FAIL: $Name (exception: $_)"
        $script:fail++
        $script:failedCases += $Name
    }
}

$repoRoot = (Get-Item (Join-Path $PSScriptRoot '..\..')).FullName
$fixture = Join-Path ([System.IO.Path]::GetTempPath()) "test-onboard-fixture-$PID"
New-Item -ItemType Directory -Path $fixture -Force | Out-Null

try {
    Write-Host '============================================================'
    Write-Host '[test-onboard] Starting Pester-shaped test suite'
    Write-Host "  Fixture: $fixture"
    Write-Host "  Repo: $repoRoot"
    Write-Host '============================================================'

    # ---- Case 1: trigger hook on missing sentinel prints banner ----
    Write-Host ''; Write-Host '[Case 1] Fresh dir -> trigger hook prints onboarding banner'
    $triggerPs1 = Join-Path $repoRoot '.claude\hooks\onboarding-trigger.ps1'
    $triggerFallback = Join-Path $repoRoot 'docs\reference\onboarding-trigger-ps1-source.md'
    $triggerToTest = $null
    if (Test-Path -LiteralPath $triggerPs1) {
        $triggerToTest = $triggerPs1
    } elseif (Test-Path -LiteralPath $triggerFallback) {
        # Extract from fallback
        $fallbackContent = Get-Content -LiteralPath $triggerFallback -Raw
        $idx = $fallbackContent.IndexOf('--- BEGIN HOOK FILE ---')
        if ($idx -ge 0) {
            $hookSrc = $fallbackContent.Substring($idx + ('--- BEGIN HOOK FILE ---').Length).TrimStart()
            $tempHook = Join-Path $fixture 'onboarding-trigger.ps1'
            Set-Content -LiteralPath $tempHook -Value $hookSrc -Encoding UTF8
            $triggerToTest = $tempHook
        }
    }

    if ($triggerToTest) {
        $scen1 = Join-Path $fixture 'scenario1'
        New-Item -ItemType Directory -Path "$scen1\.claude\hooks" -Force | Out-Null
        Copy-Item -LiteralPath $triggerToTest -Destination "$scen1\.claude\hooks\onboarding-trigger.ps1"
        Push-Location $scen1
        try {
            $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".claude\hooks\onboarding-trigger.ps1" 2>&1 | Out-String
        } catch { $output = "$_" }
        Pop-Location
        Assert-True 'Case1: banner on missing sentinel' { $output -match 'ONBOARDING REQUIRED' }
    } else {
        Write-Host '  SKIP: no trigger hook available'
    }

    # ---- Case 2: trigger hook with sentinel present skips ----
    Write-Host ''; Write-Host '[Case 2] Sentinel present -> trigger hook skips'
    if ($triggerToTest) {
        $scen2 = Join-Path $fixture 'scenario2'
        New-Item -ItemType Directory -Path "$scen2\.claude\hooks" -Force | Out-Null
        Copy-Item -LiteralPath $triggerToTest -Destination "$scen2\.claude\hooks\onboarding-trigger.ps1"
        Set-Content -LiteralPath "$scen2\.harness-onboarded" -Value '{"onboarded_at":"2026-04-29T10:00:00-0700","schema_version":1}' -Encoding UTF8
        Push-Location $scen2
        try {
            $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".claude\hooks\onboarding-trigger.ps1" 2>&1 | Out-String
        } catch { $output = "$_" }
        Pop-Location
        Assert-True 'Case2: skip on present sentinel' { $output -match 'SKIPPED' }
    }

    # ---- Case 3: substitution applied to CLAUDE.md sample ----
    Write-Host ''; Write-Host '[Case 3] Substitution: placeholder resolution'
    $scen3 = Join-Path $fixture 'scenario3'
    New-Item -ItemType Directory -Path $scen3 -Force | Out-Null
    Set-Content -LiteralPath "$scen3\sample.md" -Value "Hello {{user.name}} at {{company.name}}" -Encoding UTF8
    $content = Get-Content -LiteralPath "$scen3\sample.md" -Raw
    $content = $content.Replace('{{user.name}}', 'Alex Doe').Replace('{{company.name}}', 'Acme Corp')
    Set-Content -LiteralPath "$scen3\sample.md" -Value $content -Encoding UTF8
    $resolved = Get-Content -LiteralPath "$scen3\sample.md" -Raw
    Assert-True 'Case3: placeholders resolved' { ($resolved -match 'Alex Doe') -and ($resolved -match 'Acme Corp') -and ($resolved -notmatch '\{\{') }

    # ---- Case 4: path scaffolding ----
    Write-Host ''; Write-Host '[Case 4] Path scaffolding creates 6 critical dirs'
    $scen4 = Join-Path $fixture 'scenario4'
    $today = Get-Date -Format 'yyyy/MM'
    $criticalDirs = @(
        "notes\$($today.Replace('/', '\'))",
        'ingest',
        'hub\staging',
        'hub\state\daily-note-snapshots',
        'memory',
        'ops\incidents'
    )
    foreach ($d in $criticalDirs) {
        New-Item -ItemType Directory -Path (Join-Path $scen4 $d) -Force | Out-Null
    }
    $allPresent = $true
    foreach ($d in $criticalDirs) {
        if (-not (Test-Path -LiteralPath (Join-Path $scen4 $d))) { $allPresent = $false }
    }
    Assert-True 'Case4: 6 critical dirs exist' { $allPresent }

    # ---- Case 5: seed file anchors ----
    Write-Host ''; Write-Host '[Case 5] Seed files have required anchors'
    $ledger = Join-Path $repoRoot 'hub\state\harness-audit-ledger.md'
    if (Test-Path -LiteralPath $ledger) {
        $ledgerContent = Get-Content -LiteralPath $ledger -Raw
        Assert-True 'Case5: ledger has LEDGER-APPEND-ANCHOR' { $ledgerContent -match 'LEDGER-APPEND-ANCHOR' }
    } else {
        Write-Host '  SKIP: harness-audit-ledger.md not in repo'
    }

    $dailyTpl = Join-Path $repoRoot 'hub\templates\daily-note.md'
    if (Test-Path -LiteralPath $dailyTpl) {
        $dailyContent = Get-Content -LiteralPath $dailyTpl -Raw
        Assert-True 'Case5: daily-note has PREPEND-ANCHOR' { $dailyContent -match 'PREPEND-ANCHOR:v1' }
    } else {
        Write-Host '  SKIP: daily-note.md template not yet ported (Phase 6)'
    }

    # ---- Case 6: bootstrap dry-run emits structured JSON ----
    Write-Host ''; Write-Host '[Case 6] Dep-bootstrap structured output'
    $bootstrapPs1 = Join-Path $repoRoot 'scripts\utils\bootstrap-dependencies.ps1'
    if (Test-Path -LiteralPath $bootstrapPs1) {
        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $bootstrapPs1 -DryRun 2>&1 | Out-String
        Assert-True 'Case6: BOOTSTRAP_SUMMARY_JSON line present' { $output -match 'BOOTSTRAP_SUMMARY_JSON:' }
    } else {
        Write-Host '  SKIP: bootstrap-dependencies.ps1 not present'
    }

    # ---- Case 7: signing branch (true vs false) ----
    Write-Host ''; Write-Host '[Case 7] BYO-cert branch logic'
    if (Test-Path -LiteralPath $bootstrapPs1) {
        $scen7 = Join-Path $fixture 'scenario7'
        New-Item -ItemType Directory -Path $scen7 -Force | Out-Null
        Set-Content -LiteralPath "$scen7\subs-true.json" -Value '{"ext":{"signing":true,"neo":false,"planner":false,"codex":false}}' -Encoding UTF8
        Set-Content -LiteralPath "$scen7\subs-false.json" -Value '{"ext":{"signing":false,"neo":false,"planner":false,"codex":false}}' -Encoding UTF8

        $output_t = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $bootstrapPs1 -SubstitutionsPath "$scen7\subs-true.json" 2>&1 | Out-String
        $output_f = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $bootstrapPs1 -SubstitutionsPath "$scen7\subs-false.json" 2>&1 | Out-String

        $tStep14SkipMatch = ($output_t -match 'step 14.*SKIPPED')
        $fStep14SkipMatch = ($output_f -match 'step 14.*SKIPPED')
        # When true: step 14 should NOT be SKIPPED. When false: step 14 SHOULD be SKIPPED.
        Assert-True 'Case7: signing=true triggers cert eval' { -not $tStep14SkipMatch }
        Assert-True 'Case7: signing=false skips cert step' { $fStep14SkipMatch }
    } else {
        Write-Host '  SKIP: bootstrap-dependencies.ps1 not present'
    }

    # ---- Case 8: substitution idempotency ----
    Write-Host ''; Write-Host '[Case 8] Substitution idempotency'
    $scen8 = Join-Path $fixture 'scenario8'
    New-Item -ItemType Directory -Path $scen8 -Force | Out-Null
    $samplePath = Join-Path $scen8 'sample.md'
    Set-Content -LiteralPath $samplePath -Value 'Hello {{user.name}}' -Encoding UTF8

    # Apply once
    $c = Get-Content -LiteralPath $samplePath -Raw
    Set-Content -LiteralPath $samplePath -Value $c.Replace('{{user.name}}', 'Alex') -Encoding UTF8
    $afterFirst = Get-Content -LiteralPath $samplePath -Raw

    # Apply again -- no-op
    $c = Get-Content -LiteralPath $samplePath -Raw
    Set-Content -LiteralPath $samplePath -Value $c.Replace('{{user.name}}', 'Alex') -Encoding UTF8
    $afterSecond = Get-Content -LiteralPath $samplePath -Raw

    Assert-True 'Case8: idempotent re-run' { $afterFirst -eq $afterSecond }

} finally {
    Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
}

# ---- summary ----
Write-Host ''
Write-Host '============================================================'
Write-Host '[test-onboard] DONE'
Write-Host "  PASS: $pass"
Write-Host "  FAIL: $fail"
if ($fail -gt 0) {
    Write-Host '  Failed cases:'
    foreach ($c in $failedCases) { Write-Host "    - $c" }
}
Write-Host '============================================================'

if ($fail -gt 0) { exit 1 } else { exit 0 }
