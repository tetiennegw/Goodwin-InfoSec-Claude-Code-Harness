# ============================================================
# Script: replay-harness-case.ps1
# Task: 2026-04-22-harness-intake-improvements (Phase F4)
# Created: 2026-04-22T15:07
# Purpose: Assert that a canonical failure case would no longer reproduce
#          under the current harness. Reads replay-corpus/{case}/delta.md
#          "Replay pass criteria" section and runs each check against
#          current harness files. Returns PASS/FAIL + gap list.
# Dependencies: pwsh 7+
# Changelog (max 10):
#   2026-04-22T15:07 | 2026-04-22-harness-intake-improvements | morpheus | Initial replay runner. Static-check pattern per Codex recommendation.
# ============================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Case,
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$casePath = Join-Path $RepoRoot "hub\state\replay-corpus\$Case"
if (-not (Test-Path -LiteralPath $casePath)) {
    Write-Error "Case not found: $casePath"
    exit 1
}

$deltaPath = Join-Path $casePath 'delta.md'
if (-not (Test-Path -LiteralPath $deltaPath)) {
    Write-Error "delta.md not found in case: $deltaPath"
    exit 1
}

Write-Host "=== Replay: $Case ===" -ForegroundColor Cyan
Write-Host ""

# --- Hardcoded canonical checks per case (switch on $Case) ---
# Future: extract machine-readable check specs from delta.md.

$protocolPath = Join-Path $RepoRoot '.claude\commands\the-protocol.md'
$statePath    = Join-Path $RepoRoot 'hub\templates\state.md'
$handoffPath  = Join-Path $RepoRoot 'hub\templates\handoff.md'
$settingsPath = Join-Path $RepoRoot '.claude\settings.local.json'
$auditHook    = Join-Path $RepoRoot '.claude\hooks\protocol-execution-audit.ps1'
$ploader      = Join-Path $RepoRoot '.claude\hooks\prompt-context-loader.sh'

function Test-FileContains($path, $pattern, $description) {
    if (-not (Test-Path -LiteralPath $path)) {
        return [pscustomobject]@{ Pass = $false; Check = $description; Detail = "File missing: $path" }
    }
    $c = Get-Content -Raw -LiteralPath $path -ErrorAction SilentlyContinue
    if ($c -match $pattern) {
        return [pscustomobject]@{ Pass = $true; Check = $description; Detail = '' }
    } else {
        return [pscustomobject]@{ Pass = $false; Check = $description; Detail = "Pattern not matched in $path" }
    }
}

$checks = @()

switch ($Case) {
    '2026-04-21-azure-kickoff-rubber-stamp' {
        # 1. Step 6 order - 6a EnterPlanMode, 6c AskUserQuestion
        $checks += Test-FileContains $protocolPath '(?s)### 6a\. Enter Plan Mode.*### 6b\. Context Gathering.*### 6c\. Clarifying Questions.*### 6d\. Present Orchestration Plan' `
            'Step 6 ordering: 6a EnterPlanMode -> 6b Context -> 6c Clarify -> 6d Present+Exit'

        # 2. Rules 9-12 present
        $checks += Test-FileContains $protocolPath '(?m)^9\. \*\*Clarifications fire inside the protocol' 'Rule 9 - clarifications inside protocol'
        $checks += Test-FileContains $protocolPath '(?m)^10\. \*\*Scaffolding is post-approval' 'Rule 10 - scaffolding post-approval'
        $checks += Test-FileContains $protocolPath '(?m)^11\. \*\*Planner creation is idempotent' 'Rule 11 - idempotent Planner'
        $checks += Test-FileContains $protocolPath '(?m)^12\. \*\*No self-justified skips' 'Rule 12 - no self-justified skips'

        # 3. Step 7.5 Planner create block
        $checks += Test-FileContains $protocolPath '## Step 7\.5: PLANNER TASK CREATION' 'Step 7.5 Planner task creation block'

        # 4. Step 8 pre-handoff gate + audit ledger
        $checks += Test-FileContains $protocolPath '## Step 8: PRE-HANDOFF GATE' 'Step 8 pre-handoff gate'
        $checks += Test-FileContains $protocolPath 'harness-audit-ledger\.md' 'Step 8 writes to audit ledger'

        # 5. Audit hook exists + wired
        $checks += Test-FileContains $auditHook 'protocol-execution-audit' 'Audit hook file present'
        $checks += Test-FileContains $settingsPath 'protocol-execution-audit\.ps1' 'Audit hook wired in settings.local.json'

        # 6. STATE.md v2 schema
        $checks += Test-FileContains $statePath 'schema-version: 2' 'STATE.md template schema-version: 2'
        $checks += Test-FileContains $statePath 'plan-approved-at' 'STATE.md v2 field: plan-approved-at'
        $checks += Test-FileContains $statePath 'planner-task-id' 'STATE.md v2 field: planner-task-id'

        # 7. HANDOFF schema exists with 7 required sections
        $checks += Test-FileContains $handoffPath '## Intent' 'HANDOFF template: Intent'
        $checks += Test-FileContains $handoffPath '## Pending Decisions' 'HANDOFF template: Pending Decisions'
        $checks += Test-FileContains $handoffPath '## Active Blockers' 'HANDOFF template: Active Blockers'
        $checks += Test-FileContains $handoffPath '## Verified Artifacts' 'HANDOFF template: Verified Artifacts'
        $checks += Test-FileContains $handoffPath '## Next Command' 'HANDOFF template: Next Command'
        $checks += Test-FileContains $handoffPath '## Planner Links' 'HANDOFF template: Planner Links'
        $checks += Test-FileContains $handoffPath '## Resume Checklist' 'HANDOFF template: Resume Checklist'

        # 8. prompt-context-loader stripped of Steps 0-4
        $ploaderContent = if (Test-Path -LiteralPath $ploader) { Get-Content -Raw -LiteralPath $ploader } else { '' }
        $stepPattern = 'Step 0 - ORCHESTRATION SCOPE'
        $stripped = -not ($ploaderContent -match $stepPattern)
        $checks += [pscustomobject]@{
            Pass = $stripped
            Check = 'prompt-context-loader.sh stripped of Steps 0-4'
            Detail = if ($stripped) { '' } else { 'Pre-flight scope logic still present - Phase A not applied' }
        }
    }
    default {
        Write-Error "No replay check spec defined for case: $Case"
        exit 2
    }
}

# --- Emit results ---
$pass = @($checks | Where-Object { $_.Pass }).Count
$fail = @($checks | Where-Object { -not $_.Pass }).Count
$total = $checks.Count

foreach ($c in $checks) {
    $mark = if ($c.Pass) { '  ✅' } else { '  ❌' }
    Write-Host "$mark $($c.Check)"
    if (-not $c.Pass -and $c.Detail) {
        Write-Host ("      -> {0}" -f $c.Detail) -ForegroundColor DarkYellow
    }
}

Write-Host ""
if ($fail -eq 0) {
    Write-Host "REPLAY PASS - all $total checks succeeded. Case would not reproduce under current harness." -ForegroundColor Green
    exit 0
} else {
    Write-Host "REPLAY FAIL - $fail of $total checks failed. Harness has regressed; fix gaps above." -ForegroundColor Red
    exit 1
}


# SIG # Begin signature block
# MIIO5gYJKoZIhvcNAQcCoIIO1zCCDtMCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU7y+kUtpsz4hGQDlNqVVMnbR9
# ry6gggxGMIIFXjCCA0agAwIBAgITEQAAShUf7tkAG2uFRwACAABKFTANBgkqhkiG
# 9w0BAQsFADBSMRMwEQYKCZImiZPyLGQBGRYDY29tMR4wHAYKCZImiZPyLGQBGRYO
# Z29vZHdpbnByb2N0ZXIxGzAZBgNVBAMTEkdvb2R3aW4tRWFzdC1TVUIwMjAeFw0y
# NjAxMjgxMzU1MzJaFw0yODAxMjgxMzU1MzJaMCQxIjAgBgoJkiaJk/IsZAEZFhJn
# b29kd2lucHJvY3Rlci5jb20wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDQhACDjnrHbbx8bfq+PUVjPb1Aq8tiLMhOOWX3c8gm6b+ozB0ntt5UChJn1YST
# yke2KipH1BEr9OqJfaXvmQiAZjm82kWiFUP6PgIYqFwfxowkLEg4HY+0QKqsQHVE
# TcjOC1KkbQRvyLxyHtf9QHZ9GplYYHDEPYWv8O3yUKvwIYZvcpsVFuikc105Un5M
# /SYzU95o64uW4TO7KDRqVIq8dTiRTQarpEpmCU3mEJHBPOhjIqYxi2i7U5i3PR5/
# jnoLgIxu5nOYxFaUc9oWmN1OeHyTiQ4c5hVdX7/rY68SDZzU+b/s84CCIS2zinEr
# ZPe7bZLtVtdXXhnUau3cFJW9AgMBAAGjggFZMIIBVTA8BgkrBgEEAYI3FQcELzAt
# BiUrBgEEAYI3FQiK0ECGrexuh+GFIoerv0qCsfkRSoWqlACDm/xFAgFkAgEXMBMG
# A1UdJQQMMAoGCCsGAQUFBwMDMA4GA1UdDwEB/wQEAwIHgDAbBgkrBgEEAYI3FQoE
# DjAMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBQOTAT518affivyhmdCWzS9FxI9JDAf
# BgNVHSMEGDAWgBS1NFvRdpV8EhWEv0zMSt2cUmxEuTBTBgNVHR8ETDBKMEigRqBE
# hkJodHRwOi8vY3JsLmdvb2R3aW5wcm9jdGVyLmNvbS9DZXJ0RW5yb2xsL0dvb2R3
# aW4tRWFzdC1TVUIwMigxKS5jcmwwPgYIKwYBBQUHAQEEMjAwMC4GCCsGAQUFBzAB
# hiJodHRwOi8vY3JsLmdvb2R3aW5wcm9jdGVyLmNvbS9vY3NwMA0GCSqGSIb3DQEB
# CwUAA4ICAQBdKMiiDXX3XXbevHJjc/BiTLzL8eVsiciioNCLonKrSl5F+eNu31qm
# v6JCYvlN+aCI51PdQn885BSEA3NWK7ALSK4p87+Il/YO+ozBSVQ2YKDuMglLl4t4
# zngZf6LP38k3HPOkCgfHuHbcA6HY8J0rj33Vpcwo9I4HBMCGdOAxybdRv+INy/5V
# HUYdsfYzi1wwapf2ckEvTFxh5+R3RWG/6+yPpdH8twMHRYJ0qGv5apeUGGeqOsTX
# IaH3OKDVQDRlaaePJe6ZFEdioGmmyXXZf0vTYp831hFLmMVmES0GrCoG4A3Ye7fz
# 0hhIaHXaEtDx2GF5JMZExl8SgJgILEFS7PpOzYCQDi0BGTgO9Hm6gJWx6y7F9LPn
# F+rebUkRZEmQbObr1jrH+bhkQI79tIH0+CpspTkKZBfnG/5KqmWu9lvjVQNWpaVT
# sUFi1UWXA8yhixWQmGrt2MF1G7JbYUN2sC4qkNvrbbvnGVEt6t8/NmHdNyqrove0
# a+rjJHzaL9a1fAipRNEr0FU6El/DNpEgN8d57RXrwu4vg6rPxB5fF4fOXoGom6XI
# 1L2hqRB9iHDGzfpIQxldLdN/dPjcfJYf03tbH/vrO7n+P/CwpfAqn9TvhxlmVYJ/
# GOJD9rLPnKycXpdwTEWpwMIa5Hohft39emkgppF0QS+gJvh8pqWM6zCCBuAwggTI
# oAMCAQICEx8AAAAOJn/BWwkiVAgAAAAAAA4wDQYJKoZIhvcNAQELBQAwGjEYMBYG
# A1UEAxMPR29vZHdpbi1Sb290LUNBMB4XDTI0MDQwMzIwMDYyNloXDTI5MDQwMzIw
# MTYyNlowUjETMBEGCgmSJomT8ixkARkWA2NvbTEeMBwGCgmSJomT8ixkARkWDmdv
# b2R3aW5wcm9jdGVyMRswGQYDVQQDExJHb29kd2luLUVhc3QtU1VCMDIwggIiMA0G
# CSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCj86cfbXNeYg91ZRqsTCbrG14IFaYF
# uLb622j5N2zPa2ES88xmD/Z7iwuIaR188yal6y20MV6UMFPElKDALtCLJngyHLFC
# M0kncp0jwX8oDbjFcKjEfX0cZPXhqdTSeEc7g+xSkOmiOtMn/o1scbtDkM3KXoXK
# t7K3bvF3ge/Ebtl+fK8ToSGixP+2UdIeqDV5LDnRcgwtJr3UeZLPC1J92Jtaambt
# GvgnEwInn+zzcD0Zx+3qt6iS5df6fJS0UVPiihOihsO1wW7Iwht9DDneLqncdy1s
# f3LtwXRfzkwK9gk58xYhWVh9tFtNb5vBZ1hXKypJmX29RILQT4o1ucEbNRJD9Bgw
# huWRPAmchvGsG0m+Dh5/ipX6d7FAHGCzZ4oseclUKs0M8MmkWFIwCsZnOieGUJHD
# QSUS/VZy/i0BF+n1pCrv17GZAW4jRuz9UH1aPKNoNGP0+TFg3RHNkFHEtxLpnyda
# GePq4Ep/a5j/dvE/aGCfySNgUhhR6JkHjjD6FzsJ1Te2iMGzRcNAl1NLy4b0Pdqz
# le2pankCvkcYKGY7e5xL2qIzdB3c7NB3kC1LgbVgk7p0uXAwB4WZ0FnkH/+H7Dsp
# HtmDQaQsjOFOngxDhkN2SdOiFyZWFFREx6HQmCPgBPnrSviDvIJGq0b2Gqf9kxkO
# +6kAds3g24uoyQIDAQABo4IB5TCCAeEwEgYJKwYBBAGCNxUBBAUCAwEAAjAjBgkr
# BgEEAYI3FQIEFgQUMT2RrxMAmObvsnycg/XR9O4igIAwHQYDVR0OBBYEFLU0W9F2
# lXwSFYS/TMxK3ZxSbES5MBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1Ud
# DwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFAcxsf32+u1QnKtd
# MAn+MUw20r5UMIGCBgNVHR8EezB5MHegdaBzhjNmaWxlOi8vLy93YXRjYXJvb3Qw
# MS9DZXJ0RW5yb2xsL0dvb2R3aW4tUm9vdC1DQS5jcmyGPGh0dHA6Ly9jcmwuZ29v
# ZHdpbnByb2N0ZXIuY29tL0NlcnRFbnJvbGwvR29vZHdpbi1Sb290LUNBLmNybDCB
# pwYIKwYBBQUHAQEEgZowgZcwSwYIKwYBBQUHMAKGP2ZpbGU6Ly8vL3dhdGNhcm9v
# dDAxL0NlcnRFbnJvbGwvd2F0Y2Fyb290MDFfR29vZHdpbi1Sb290LUNBLmNydDBI
# BggrBgEFBQcwAoY8aHR0cDovL2NybC5nb29kd2lucHJvY3Rlci5jb20vQ2VydEVu
# cm9sbC9Hb29kd2luLVJvb3QtQ0EuY3J0MA0GCSqGSIb3DQEBCwUAA4ICAQBHuLGF
# bYE+wmKTgLsng3TLsk0NUuHx6SqWi4eD4iuatyroKV0QLzkZgZm2UmYn5wejtgE/
# jhg8T9GpbEv7ADb5q4BMjs5QcnBXitXMT1lZtzMKe7H80HC2z1cJ51ki9tK1N2sL
# 96KFDRORV+OuNzQwqp4vfQ3aVvAN1lDT1lqpEYhVbEslPxpwBK3VIiFwyzVGuklS
# TxsFuhVmwXbmtumBQGrvu5wZvdWYf/cF66McDtjx3pRWR2hAa+8MXJy2WvZQV3HP
# AnhZ5KOjVvYLXS7kJCPg8aUwuzWuyzANpmvxRzteJB1dZ7euhxmQQUC7Mvf9+SRp
# /++kY9X9MGVVFVnPND715WmO+dr6Cgl1hDJy+kplESkTVAxyE6PFwpeZ5eK7Qg9M
# gFemSy4O1/paEd2PzABBaEw8bXx4B4CSz3Kwu5MQY0LED/rGg6oo3S72aeFICwDg
# FwjqKHMgpKhJzBxseUfMu/fOZ5J7AWjZiB6UXd5mmnSq0HGwCvrI3bUXh6bv2O/I
# zrFhKSjXLwB4GFpZYjUyJ8C0Oyw6zkvGtvs1rUk5rt4NkRq0EpaOs968THuZ664H
# egqbUyVW88DyWZvyVXipsF2GWXXWC0QWw7U9TxuDVUmrqxxYfZP/mWiEvzvBwAFW
# U6MRaxQdw2EnN3AtrtuOx+fIc9cujlA3Ju2jcTGCAgowggIGAgEBMGkwUjETMBEG
# CgmSJomT8ixkARkWA2NvbTEeMBwGCgmSJomT8ixkARkWDmdvb2R3aW5wcm9jdGVy
# MRswGQYDVQQDExJHb29kd2luLUVhc3QtU1VCMDICExEAAEoVH+7ZABtrhUcAAgAA
# ShUwCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZI
# hvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcC
# ARUwIwYJKoZIhvcNAQkEMRYEFOyx3QbM60qJAHWnJ/TPEreEE3OYMA0GCSqGSIb3
# DQEBAQUABIIBAA47WfgtJBLSierPj+VbJQCIw+zZly3DM+/slxk/MVCY3D2e/z+K
# t9RsS6ChGJG1sYTXn9MKojoUedCOa8SYaw+5RJCt7EJkdhgb4luuIkw+1Va/NvCY
# 5aiHfQpLa7doWMtlINXoozMEDJqC8dCXgEDvyy5+a4mTRHqRn+HmNXhjRJBPo6Kf
# y+hGeA11SBoVa6HGy2EGnM2XcycrHlIfMdWkM4PTfdewOaxZ+7csDag6S3E5oEnD
# AGqg5H2KztiJQw4R3jlt9MYorTV/m/OD5CnGmzuF9B7pcfYo1PqtGTs9e+MvCxbo
# xCjnR5w6aZ9uhAIigt+4Ti1HIBKK/VGAuLo=
# SIG # End signature block
