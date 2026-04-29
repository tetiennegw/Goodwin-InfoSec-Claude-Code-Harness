# ============================================================
# Script: apply-onboard-substitutions.ps1
# Task: 2026-04-28-morpheus-templatize-port (Phase 5 R3)
# Agent: builder
# Created: 2026-04-29
# Last-Updated: 2026-04-29
# Plan: hub/staging/2026-04-28-morpheus-templatize-port/wave-3/repo-architecture.md
# Purpose: Walk SANITIZE files and apply {{namespace.field}} -> captured-value substitutions.
#   Idempotent: re-running on already-substituted files is a no-op.
# Dependencies: WinPS 5.1+ or pwsh 7+
# Usage:
#   pwsh -File scripts/utils/apply-onboard-substitutions.ps1 -SubstitutionsPath <path> [-DryRun]
# Exit codes:
#   0 = success
#   1 = bad args / missing inputs
#   2 = post-substitution validation failed
# Changelog (max 10):
#   2026-04-29 | morpheus-templatize-port | builder (Phase 5 R3) | Created PowerShell variant of substitution engine.
# ============================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$SubstitutionsPath,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $SubstitutionsPath)) {
    Write-Error "[apply-onboard-substitutions] Substitutions JSON not found: $SubstitutionsPath"
    exit 1
}

$repoRoot = (Get-Item (Join-Path $PSScriptRoot '..\..')).FullName

# ---- SANITIZE file list (mirrors apply-onboard-substitutions.sh) ----
$sanitizeFiles = @(
    'CLAUDE.md',
    '.claude/rules/scripts.md',
    '.claude/rules/neo.md',
    '.claude/protocols/security.md',
    '.claude/commands/the-protocol.md',
    '.claude/commands/script-scaffold.md',
    '.claude/commands/sign-script.md',
    '.claude/commands/second-opinion.md',
    '.claude/commands/incident-triage.md',
    '.claude/commands/daily-note-management.md',
    '.claude/commands/create-daily-notes.md',
    '.claude/hooks/protocol-execution-audit.ps1',
    '.claude/hooks/plan-compliance-audit.ps1',
    '.claude/hooks/task-discipline-audit.ps1',
    '.claude/hooks/state-frontmatter-validator.ps1',
    '.claude/hooks/prompt-context-loader.sh',
    'hub/templates/build-artifact.md',
    'hub/templates/handoff.md',
    'hub/templates/daily-note.md',
    'knowledge/security/execution-trust-per-file-type.md',
    'scripts/utils/statusline.sh',
    'scripts/utils/test-ingest-hook.sh',
    'docs/getting-started/01-prerequisites.md',
    'docs/getting-started/02-fork-and-customize.md',
    'docs/getting-started/03-first-session.md',
    'docs/getting-started/04-your-first-task.md',
    'docs/README.md',
    'docs/SECOND-OPINION-SETUP.md',
    'docs/reference/dispatch-templates.md',
    'docs/architecture/notes-system.md',
    'docs/customization/adding-rules.md'
)

# ---- load substitutions ----
$subsRaw = Get-Content -LiteralPath $SubstitutionsPath -Raw -Encoding UTF8
$subsObj = $subsRaw | ConvertFrom-Json

# Flatten nested object to {{namespace.field}} -> value
function Flatten-Object {
    param($obj, [string]$prefix = '')
    $result = @{}
    if ($obj -is [System.Management.Automation.PSCustomObject]) {
        foreach ($prop in $obj.PSObject.Properties) {
            $newKey = if ($prefix) { "$prefix.$($prop.Name)" } else { $prop.Name }
            $val = $prop.Value
            if ($val -is [System.Management.Automation.PSCustomObject]) {
                $nested = Flatten-Object -obj $val -prefix $newKey
                foreach ($k in $nested.Keys) { $result[$k] = $nested[$k] }
            } elseif ($val -is [Array]) {
                # Skip arrays (e.g., team.members[]); they need different handling
                continue
            } else {
                if ($null -ne $val -and "$val" -ne '') {
                    $result["{{$newKey}}"] = "$val"
                }
            }
        }
    }
    return $result
}

$subs = Flatten-Object -obj $subsObj
Write-Host "[apply-onboard-substitutions] Loaded $($subs.Count) substitutions from $SubstitutionsPath"

$appliedCount = 0
$filesTouched = 0
$skippedCount = 0

foreach ($relPath in $sanitizeFiles) {
    $absPath = Join-Path $repoRoot $relPath
    if (-not (Test-Path -LiteralPath $absPath)) {
        $skippedCount++
        continue
    }

    $beforeContent = [IO.File]::ReadAllText($absPath, [System.Text.Encoding]::UTF8)
    $afterContent = $beforeContent

    foreach ($placeholder in $subs.Keys) {
        $val = $subs[$placeholder]
        # Literal-string replace (PS String.Replace is literal, not regex)
        $afterContent = $afterContent.Replace($placeholder, $val)
        $appliedCount++
    }

    if ($beforeContent -ne $afterContent) {
        if ($DryRun) {
            Write-Host "[dry-run] $relPath -> placeholders would be substituted"
        } else {
            # Use [IO.File]::WriteAllText to bypass ThreatLocker write restrictions
            # per .claude/rules/scripts.md
            [IO.File]::WriteAllText($absPath, $afterContent, [System.Text.UTF8Encoding]::new($false))
        }
        $filesTouched++
    }
}

# ---- post-substitution validation ----
$residual = 0
Write-Host ""
Write-Host "[apply-onboard-substitutions] Validating no residual {{ tokens..."
foreach ($relPath in $sanitizeFiles) {
    $absPath = Join-Path $repoRoot $relPath
    if (-not (Test-Path -LiteralPath $absPath)) { continue }
    $content = [IO.File]::ReadAllText($absPath, [System.Text.Encoding]::UTF8)
    if ($content -match '\{\{[a-zA-Z]') {
        Write-Host "  [WARN] residual placeholder in $relPath"
        $residual++
    }
}

# ---- summary ----
Write-Host ''
Write-Host '============================================================'
Write-Host '[apply-onboard-substitutions] SUMMARY'
Write-Host "  Substitution map size: $($subs.Count)"
Write-Host "  Applied (cumulative): $appliedCount"
Write-Host "  Files touched: $filesTouched"
Write-Host "  Files skipped (not present): $skippedCount"
Write-Host "  Residual {{ tokens: $residual"
Write-Host '============================================================'

if ($residual -gt 0) {
    Write-Error "[apply-onboard-substitutions] FAIL: $residual file(s) have residual placeholders."
    exit 2
}

Write-Host '[apply-onboard-substitutions] PASS'
exit 0
