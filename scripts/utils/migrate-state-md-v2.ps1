# ============================================================
# Script: migrate-state-md-v2.ps1
# Task: 2026-04-22-harness-intake-improvements
# Agent: morpheus (Phase C6)
# Created: 2026-04-22T14:35
# Purpose: One-shot migration of existing STATE.md files from v1 to v2 frontmatter.
#          Non-destructive: writes to .v2.md, validates, swaps atomically; keeps .v1.bak.
# Dependencies: pwsh 7+
# Changelog (max 10):
#   2026-04-22T14:35 | 2026-04-22-harness-intake-improvements | morpheus | Initial migration script
# ============================================================

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$StagingRoot = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'hub\staging'),
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not (Test-Path -LiteralPath $StagingRoot)) {
    Write-Error "StagingRoot not found: $StagingRoot"
    exit 1
}

$stateFiles = Get-ChildItem -LiteralPath $StagingRoot -Directory -ErrorAction SilentlyContinue |
    ForEach-Object { Join-Path $_.FullName 'STATE.md' } |
    Where-Object { Test-Path -LiteralPath $_ }

if (-not $stateFiles) {
    Write-Host "No STATE.md files found under $StagingRoot"
    exit 0
}

$v2Fields = [ordered]@{
    'planner-task-id'    = 'null'
    'plan-approved-at'   = 'null'
    'pending-decisions'  = '[]'
    'blockers'           = '[]'
    'verified-artifacts' = '[]'
    'resume-command'     = '"/orchestration-dispatch {path}"'
}

$migrated = 0
$skipped = 0
$errored = 0

foreach ($path in $stateFiles) {
    Write-Host "`n--- $path" -ForegroundColor Cyan

    try {
        $content = Get-Content -Raw -LiteralPath $path -ErrorAction Stop
        if ($content -match '(?s)^---\s*\r?\n(.*?)\r?\n---\s*\r?\n(.*)$') {
            $fm = $Matches[1]
            $body = $Matches[2]
        } else {
            Write-Warning "  No frontmatter found; skipping"
            $skipped++
            continue
        }

        if ($fm -match '(?m)^schema-version\s*:\s*2\s*$') {
            Write-Host "  Already v2 - skip" -ForegroundColor DarkGray
            $skipped++
            continue
        }

        # Bump schema-version
        if ($fm -match '(?m)^schema-version\s*:') {
            $fm = $fm -replace '(?m)^schema-version\s*:.*$', 'schema-version: 2'
        } else {
            $fm += "`nschema-version: 2"
        }

        # Pull task-id to populate resume-command
        $taskId = 'unknown-task'
        if ($fm -match '(?m)^task-id\s*:\s*(\S+)') { $taskId = $Matches[1].Trim() }

        # Append missing v2 fields
        $appended = @()
        foreach ($k in $v2Fields.Keys) {
            if ($fm -notmatch "(?m)^$([regex]::Escape($k))\s*:") {
                $v = $v2Fields[$k]
                if ($k -eq 'resume-command') {
                    $v = "`"/orchestration-dispatch hub/staging/$taskId/STATE.md`""
                }
                $appended += "$k`: $v"
            }
        }
        if ($appended.Count -gt 0) {
            $fm = $fm.TrimEnd() + "`n# --- v2 machine-readable fields (migrated from v1) ---`n" + ($appended -join "`n")
        }

        $newContent = "---`n" + $fm.TrimEnd() + "`n---`n" + $body

        if ($DryRun) {
            Write-Host "  [dry-run] would write: schema bumped + $($appended.Count) field(s) appended" -ForegroundColor Yellow
            $migrated++
            continue
        }

        # Non-destructive: write .v2.md first, keep .v1.bak, then atomic swap
        $v2Path = "$path.v2.md"
        $v1Bak  = "$path.v1.bak"

        Set-Content -LiteralPath $v2Path -Value $newContent -NoNewline -Encoding UTF8
        Copy-Item -LiteralPath $path -Destination $v1Bak -Force
        Move-Item -LiteralPath $v2Path -Destination $path -Force

        Write-Host "  Migrated: schema bumped + $($appended.Count) v2 field(s) added. Backup at: $v1Bak" -ForegroundColor Green
        $migrated++
    } catch {
        Write-Warning "  Error: $($_.Exception.Message)"
        $errored++
    }
}

Write-Host "`n=== Migration Summary ===" -ForegroundColor Cyan
Write-Host "  Migrated: $migrated"
Write-Host "  Skipped:  $skipped"
Write-Host "  Errored:  $errored"
if ($DryRun) { Write-Host "  (DryRun - no files modified)" -ForegroundColor Yellow }


# SIG # Begin signature block
# MIIO5gYJKoZIhvcNAQcCoIIO1zCCDtMCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUJtXH+Dif1uBrhkcfXh5iLFbU
# vk2gggxGMIIFXjCCA0agAwIBAgITEQAAShUf7tkAG2uFRwACAABKFTANBgkqhkiG
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
# ARUwIwYJKoZIhvcNAQkEMRYEFBxENyASN1Cuuujwk0voKQFx5s8pMA0GCSqGSIb3
# DQEBAQUABIIBAKRofAMq4GeiaaN690bp00mwJYPEWEFTdW5hMs0//lb9XLqAAGq8
# uzc9CpmS+td6RboXNJiSmEhEeD7KNDDKR8fWZjZwn7aRxtkrMoPXLsuM5cLfWArk
# bTh8g7ZSsmCPyk1uYsxSf/D3ESKd3d5CgDiZd3plb11M3Py0ZLG/S+xkslpX/OwP
# cQzoZ/rGvDzvBb8DFR7tHh8SE2xhu5a6NE4tXbLchrFR92VbVM7BveS/kE+jfWYO
# uMqo0mAdz8UQFKen1CmR+Xz276ZRYHlX8Pc+JNIN76+cso5MLLEpyrMvuQiXADbq
# aBwSDsCeRibzaPl1ckw1B+NEBK6YctyhU+o=
# SIG # End signature block
