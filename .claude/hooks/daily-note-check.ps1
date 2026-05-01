# ============================================================
# Daily Note Documentation Check — BLOCKING Stop Hook
# Source: ishtylerc/claude-code-hooks-framework (adapted for Morpheus)
# Event: Stop
# Purpose: Blocks session end if meaningful work was done in the current
#          turn but today's daily note wasn't updated in that same turn.
# Dependencies: PowerShell 5+ (jq & python unavailable on Goodwin box)
# Changelog (max 10):
#   2026-04-09 | morpheus-foundation | orchestrator | Rewrote as PowerShell — jq and python are both unavailable on this locked-down Windows box (jq not installed; python is only MS Store stub). Previous bash+jq version silently no-op'd every turn because `jq ... 2>/dev/null || true` swallowed command-not-found errors. Scoped to current turn via last-user-message index; requires actual Edit/Write tool_use on the note path.
#   2026-04-08 | morpheus-foundation | orchestrator | Adapted from hooks framework for Morpheus note system
# ============================================================

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Skip($reason) {
    Write-Host "[HOOK:Stop:DailyNote] SKIPPED -- $reason"
    exit 0
}

# Read hook input from stdin
$raw = [Console]::In.ReadToEnd()

try {
    $hook = $raw | ConvertFrom-Json -ErrorAction Stop
} catch {
    Write-Skip "Could not parse hook input JSON"
}

# Prevent infinite loops
if ($hook.PSObject.Properties.Name -contains 'stop_hook_active' -and $hook.stop_hook_active) {
    Write-Skip "Already blocked once, allowing stop"
}

$transcriptPath = $null
if ($hook.PSObject.Properties.Name -contains 'transcript_path') {
    $transcriptPath = $hook.transcript_path
}

if (-not $transcriptPath -or -not (Test-Path -LiteralPath $transcriptPath)) {
    Write-Skip "No transcript available"
}

# Work tools that produce artifacts worth documenting.
# Excludes Read/Grep/Glob/WebSearch/WebFetch (read-only) and Bash (too noisy).
$workTools = @('Edit', 'Write', 'Agent', 'Task', 'NotebookEdit')
$noteRegex = 'notes/\d{4}/\d{2}/\d{4}-\d{2}-\d{2}\.md'

# Parse transcript as JSONL
$lines = @()
try {
    $rawLines = Get-Content -LiteralPath $transcriptPath -Encoding UTF8 -ErrorAction Stop
    foreach ($ln in $rawLines) {
        if ([string]::IsNullOrWhiteSpace($ln)) { continue }
        try {
            $lines += ,($ln | ConvertFrom-Json -ErrorAction Stop)
        } catch {
            # Skip malformed lines silently
        }
    }
} catch {
    Write-Skip "Could not read transcript: $($_.Exception.Message)"
}

if ($lines.Count -eq 0) {
    Write-Skip "Transcript empty"
}

# Find index of the last user message
$lastUser = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i].PSObject.Properties.Name -contains 'type' -and $lines[$i].type -eq 'user') {
        $lastUser = $i
    }
}

# Current turn = everything after the last user message
if ($lastUser -lt $lines.Count - 1) {
    $currentTurn = $lines[($lastUser + 1)..($lines.Count - 1)]
} else {
    $currentTurn = @()
}

$workDone = $false
$noteEdited = $false

foreach ($entry in $currentTurn) {
    if ($entry.PSObject.Properties.Name -notcontains 'type' -or $entry.type -ne 'assistant') { continue }
    if ($entry.PSObject.Properties.Name -notcontains 'message') { continue }
    $msg = $entry.message
    if (-not $msg -or $msg.PSObject.Properties.Name -notcontains 'content') { continue }
    $content = $msg.content
    if (-not $content) { continue }
    foreach ($block in $content) {
        if (-not $block -or $block.PSObject.Properties.Name -notcontains 'type') { continue }
        if ($block.type -ne 'tool_use') { continue }
        $name = $null
        if ($block.PSObject.Properties.Name -contains 'name') { $name = $block.name }
        if (-not $name) { continue }
        if ($workTools -contains $name) { $workDone = $true }
        if ($name -eq 'Edit' -or $name -eq 'Write') {
            if ($block.PSObject.Properties.Name -contains 'input' -and $block.input) {
                $fp = $null
                if ($block.input.PSObject.Properties.Name -contains 'file_path') {
                    $fp = $block.input.file_path
                }
                if ($fp) {
                    $normalized = $fp -replace '\\', '/'
                    if ($normalized -match $noteRegex) {
                        $noteEdited = $true
                    }
                }
            }
        }
    }
}

if (-not $workDone) {
    Write-Skip "No artifact-producing work tools in current turn"
}

if ($noteEdited) {
    Write-Skip "Daily note updated in current turn"
}

# BLOCK: emit JSON decision payload on stdout
$payload = @{
    decision = 'block'
    reason   = "STOP BLOCKED: Meaningful work was completed this turn (Edit/Write/Agent/Task) but today's daily note was not updated in the same turn. Append a rich timeline entry to notes/YYYY/MM/YYYY-MM-DD.md under the ## Notes section using the standard format (- **HH:MM** - **[Title]** #tags, [WORK TYPE]:, Files Modified:, Key Decisions:, Artifacts:, Strategic Value:), then you may stop. This hook can only be bypassed by actually updating the note."
}
$payload | ConvertTo-Json -Compress
exit 0
# SIG # Begin signature block
# MIIO5gYJKoZIhvcNAQcCoIIO1zCCDtMCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUaaGof3Wt2zR4xXOQ6UCkr+5o
# nT2gggxGMIIFXjCCA0agAwIBAgITEQAAShUf7tkAG2uFRwACAABKFTANBgkqhkiG
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
# ARUwIwYJKoZIhvcNAQkEMRYEFLhG6v0+SMBG4DBkrymH2Qyot9xFMA0GCSqGSIb3
# DQEBAQUABIIBAAnWnpijoRFwPMSDyV44ZOSm5gUUMFEWFJOhCr/tgvxbpvBGbRZi
# fL4VNNkIiIh6NoKvnX43tPxnm+A+2dSmTEY1OdiZnUS+etuPj0M7Xc41sCUZMHyq
# AAiGTRmiEf66ZcC2VB+lSVXmhSNf4SP3RhOaXjZpAl9g94Zf4y6jvrTu35C8Ergj
# XDc2X6eZl6xPfqPhbFY5IotAK/zxa/RU9A3qN1qoFFsKqUrAqusbrVxsOmFojF0G
# VI+0MKHWzceKfGSrZBBoci3L3DAYEWzFoZjvUBujfSsYunNJvTrXQeb1+sfDXOv9
# YM+nJKnA0P6kyVBkS1YepSk2Z+MtvnkSe+k=
# SIG # End signature block
