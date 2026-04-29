# ============================================================
# Script: generate-harness-metrics.ps1
# Task: 2026-04-22-harness-intake-improvements (Phase F2)
# Created: 2026-04-22T15:05
# Purpose: Parse hub/state/harness-audit-ledger.md + hub/staging/*/STATE.md and emit
#          hub/state/harness-metrics.md - the 8-metric nightly snapshot
#          defined in docs/morpheus-features/north-star-standard.md §2.2.
# Dependencies: pwsh 7+
# Idempotency: safe to run repeatedly; only writes harness-metrics.md if content changed.
# Changelog (max 10):
#   2026-04-22T15:05 | 2026-04-22-harness-intake-improvements | morpheus | Initial - 8 metrics from §2.2
# ============================================================

[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ledgerPath   = Join-Path $RepoRoot 'hub\state\harness-audit-ledger.md'
$metricsPath  = Join-Path $RepoRoot 'hub\state\harness-metrics.md'
$stagingRoot  = Join-Path $RepoRoot 'hub\staging'

# --- Parse ledger rows ---
$rows = @()
if (Test-Path -LiteralPath $ledgerPath) {
    $lines = Get-Content -LiteralPath $ledgerPath
    foreach ($line in $lines) {
        # Protocol invocation row: 9+ fields with AUQ:/EPM:/XPM:/PLN:/SCAF:/RESULT:
        if ($line -match '^\|\s*(\S+)\s*\|\s*(\S+)\s*\|\s*(\S+)\s*\|\s*AUQ:(\S+)\s*\|\s*EPM:(\S+)\s*\|\s*XPM:(\S+)\s*\|\s*PLN:(\S+)\s*\|\s*SCAF:(\S+)\s*\|\s*RESULT:(\S+)\s*\|') {
            $rows += [pscustomobject]@{
                Type     = 'protocol'
                Ts       = $Matches[1]
                TaskId   = $Matches[2]
                Scope    = $Matches[3]
                AUQ      = $Matches[4]
                EPM      = $Matches[5]
                XPM      = $Matches[6]
                PLN      = $Matches[7]
                SCAF     = $Matches[8]
                Result   = $Matches[9]
            }
        }
        # Validator row: 5 fields with RESULT:
        elseif ($line -match '^\|\s*(\S+)\s*\|\s*(\S+)\s*\|\s*([^|]+?)\s*\|\s*RESULT:(\S+)\s*\|') {
            # Narrower pattern only for simpler validator rows
            if ($line -notmatch 'AUQ:') {
                $rows += [pscustomobject]@{
                    Type    = 'validator'
                    Ts      = $Matches[1]
                    TaskId  = $Matches[2]
                    Source  = $Matches[3].Trim()
                    Result  = $Matches[4]
                }
            }
        }
    }
}

$protocolRows = @($rows | Where-Object { $_.Type -eq 'protocol' })
$validatorRows = @($rows | Where-Object { $_.Type -eq 'validator' })

# --- Rolling window - 30 days ---
$cutoff = (Get-Date).AddDays(-30)
$recentProto = @($protocolRows | Where-Object {
    try { [datetime]::Parse($_.Ts) -ge $cutoff } catch { $false }
})

function Safe-Pct($num, $den) {
    if ($den -eq 0) { return 'n/a' }
    return ('{0:N1}%' -f ($num * 100.0 / $den))
}

# --- Metric 1: % Medium+ with plan-approval-before-scaffold ---
$mediumPlusRows = @($recentProto | Where-Object { $_.Scope -in @('medium','large','ultra') })
$mpWithApprovalFirst = @($mediumPlusRows | Where-Object { $_.XPM -eq 'Y' -and $_.SCAF -eq 'Y' })
$m1 = Safe-Pct $mpWithApprovalFirst.Count $mediumPlusRows.Count

# --- Metric 3: Protocol-skip incident count (FAIL rows in last 30 days) ---
$m3 = @($recentProto | Where-Object { $_.Result -eq 'FAIL' }).Count

# --- Metric 7: Audit pass rate by scope ---
$m7Parts = @()
foreach ($sc in @('passthrough','mini','small','medium','large','ultra')) {
    $sRows = @($recentProto | Where-Object { $_.Scope -eq $sc })
    if ($sRows.Count -eq 0) { continue }
    $pass = @($sRows | Where-Object { $_.Result -eq 'PASS' }).Count
    $m7Parts += "  - ${sc}: $(Safe-Pct $pass $sRows.Count) ($pass / $($sRows.Count))"
}
$m7 = if ($m7Parts.Count -gt 0) { $m7Parts -join "`n" } else { '  - (no data)' }

# --- Metric 5: Scope reclassification rate ---
# Detected via Progress Summary entries containing "Scope reclassified" or "Re-scope to"
$rescopeCount = 0
$totalTaskCount = 0
if (Test-Path -LiteralPath $stagingRoot) {
    foreach ($d in Get-ChildItem -LiteralPath $stagingRoot -Directory -ErrorAction SilentlyContinue) {
        $sp = Join-Path $d.FullName 'STATE.md'
        if (Test-Path -LiteralPath $sp) {
            $totalTaskCount++
            $c = Get-Content -Raw -LiteralPath $sp -ErrorAction SilentlyContinue
            if ($c -and ($c -match '(?i)scope reclassified|re-scoped|scope changed:')) {
                $rescopeCount++
            }
        }
    }
}
$m5 = Safe-Pct $rescopeCount $totalTaskCount

# --- Metric 2: Duplicate Planner task rate (needs Planner mapping; placeholder unless mapping present) ---
$plannerMappingPath = Join-Path $RepoRoot 'hub\state\planner-mapping.json'
$m2 = 'n/a (requires planner-mapping.json with morpheus-task-id custom field)'
if (Test-Path -LiteralPath $plannerMappingPath) {
    $m2 = 'n/a (scaffold for future implementation - needs Compare-PlannerState query)'
}

# --- Metric 4: Resume success rate (HANDOFF validator outcomes) ---
$handoffRows = @($validatorRows | Where-Object { $_.Source -match 'handoff' })
$m4 = if ($handoffRows.Count -eq 0) { 'n/a (no HANDOFF validator runs yet)' } else {
    $pass = @($handoffRows | Where-Object { $_.Result -eq 'PASS' }).Count
    Safe-Pct $pass $handoffRows.Count
}

# --- Metric 6: Hook failure / retry rate (placeholder - needs dedicated hook-exit log) ---
$m6 = 'n/a (scaffold for future - needs hook-exit-log)'

# --- Metric 8: Time-to-recover after interrupted Ultra session (placeholder) ---
$m8 = 'n/a (scaffold for future - needs HANDOFF-resume telemetry)'

# --- Render metrics table ---
$generatedAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm')
$content = @"
# Harness Metrics - Nightly Snapshot

> Auto-generated by ``scripts/utils/generate-harness-metrics.ps1`` (wired to Stop hook, runs nightly or on demand).
> Source targets defined in ``docs/morpheus-features/north-star-standard.md`` §2.2.

**Generated**: $generatedAt
**Rolling window**: last 30 days (from $($cutoff.ToString('yyyy-MM-dd')))
**Protocol invocations in window**: $($recentProto.Count)
**Validator events in window**: $(@($validatorRows | Where-Object { try { [datetime]::Parse($_.Ts) -ge $cutoff } catch { $false } }).Count)

---

## Metrics

| # | Metric | Target | Current | Status |
|---|--------|--------|---------|--------|
| 1 | % Medium+ tasks with plan-approval before scaffold | ≥ 95% | $m1 | $(if ($mediumPlusRows.Count -eq 0) { '-' } elseif ($m1 -eq 'n/a') { '-' } elseif (([double]($m1 -replace '%','')) -ge 95) { '✅' } else { '⚠️' }) |
| 2 | Duplicate Planner task rate | < 1% | $m2 | - |
| 3 | Protocol-skip incident count (30d) | 0 | $m3 | $(if ($m3 -eq 0) { '✅' } else { '⚠️' }) |
| 4 | Resume success rate after new session | ≥ 90% | $m4 | - |
| 5 | Scope reclassification rate | < 15% | $m5 | $(if ($m5 -eq 'n/a') { '-' } elseif (([double]($m5 -replace '%','')) -lt 15) { '✅' } else { '⚠️' }) |
| 6 | Hook failure / retry rate | < 5% | $m6 | - |
| 7 | Audit pass rate by scope (≥ 90% per scope) | ≥ 90% | see below | - |
| 8 | Time-to-recover after interrupted Ultra session | < 10 min | $m8 | - |

### Metric 7 breakdown (audit pass rate by scope, last 30 days)

$m7

---

## Replay Corpus

$( (Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'hub\state\replay-corpus') -Directory -ErrorAction SilentlyContinue | ForEach-Object { "- [$($_.Name)](replay-corpus/$($_.Name)/README.md)" }) -join "`n" )

---

## Notes

- Metrics marked ``-`` or ``n/a`` are either placeholders (scaffold for future telemetry) or lack sufficient data in the rolling window.
- ``/weekly-review`` consumes this file and proposes amendments when metrics slip below targets.
- Ledger source: ``hub/state/harness-audit-ledger.md``.
"@

# --- Idempotent write ---
$existing = if (Test-Path -LiteralPath $metricsPath) { Get-Content -Raw -LiteralPath $metricsPath -ErrorAction SilentlyContinue } else { $null }
if ($existing -ne $content) {
    Set-Content -LiteralPath $metricsPath -Value $content -NoNewline -Encoding UTF8
    Write-Host ("[generate-harness-metrics] Wrote {0} ({1} protocol rows, {2} validator rows in window)" -f $metricsPath, $recentProto.Count, @($validatorRows | Where-Object { try { [datetime]::Parse($_.Ts) -ge $cutoff } catch { $false } }).Count)
} else {
    Write-Host "[generate-harness-metrics] No changes"
}

exit 0


# SIG # Begin signature block
# MIIO5gYJKoZIhvcNAQcCoIIO1zCCDtMCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU7L62zTuoL2Fx15yPtu1qPSfo
# QsigggxGMIIFXjCCA0agAwIBAgITEQAAShUf7tkAG2uFRwACAABKFTANBgkqhkiG
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
# ARUwIwYJKoZIhvcNAQkEMRYEFIafUSDINt/LAWKKnKdgHklIEwjFMA0GCSqGSIb3
# DQEBAQUABIIBAE4LgHC4cMD8OXORikutpbefESmilysCtucUAq0wjIeYDG+Nuf7P
# 6JP0Is6KwDq20ZV44+7PVnGlEYRsixB4u1wTo9oEFlFT2QAjTrQqDTIKxhoMgn0c
# xZWnX2OKSmOZo2LXmORqrQpZSvsw8O0O1xHPgNRxIpD/VvJe2CmiGN6Dv0dmH2/9
# TbQGriUvnFSo1G0Ch6gyYG6+nE/P5rOIEj06iOhz7u/OJoiPxtK4H70AmkJzWLSu
# GTm/fl653BS1ffbmLFe1RKY+HQVOi5elaQWfTKBrMFaljUGgN6hG2Y7Cijemr/SM
# yB2BZJ97aaieduKG8C1oGtGgYCNQDw2574U=
# SIG # End signature block
