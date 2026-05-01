# ============================================================
# Hook: state-frontmatter-validator.ps1
# Lifecycle Event: PostToolUse (matcher: Edit|Write on hub/staging/*/STATE.md)
# Purpose: Validates STATE.md v2 frontmatter schema on every write.
#          Checks required fields, types, and sentinel values.
#          Does NOT block - writes pass/fail to harness-audit-ledger.md and daily note.
# Dependencies: pwsh 7+, ConvertFrom-StringData (builtin), no jq 
# Changelog (max 10):
#   2026-04-22T14:32 | 2026-04-22-harness-intake-improvements | morpheus | Phase C2: initial validator for schema-version: 2 frontmatter. Required + nullable field checks, daily-note surfacing on FAIL.
# ============================================================

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# --- bash-fallback writer: ThreatLocker storage control denies powershell.exe writes to repo paths.
# bash.exe writes through, so on UnauthorizedAccessException we pipe bytes to `cat > $path` (or `>>`).
# Pattern from protocol-execution-audit.ps1 / plan-compliance-audit.ps1 (2026-04-24+).
function Write-FileViaBashFallback {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$Content,
        [switch]$Append
    )
    $bashExe = '{{paths.home}}\AppData\Local\Programs\Git\bin\bash.exe'
    if (-not (Test-Path -LiteralPath $bashExe)) { return $false }
    $unixPath = $Path -replace '\\','/'
    if ($unixPath -match '^([A-Za-z]):(.*)$') {
        $unixPath = '/' + $Matches[1].ToLower() + $Matches[2]
    }
    $escapedPath = $unixPath -replace "'", "'\''"
    $redirect = if ($Append) { '>>' } else { '>' }
    $cmd = "cat $redirect '$escapedPath'"
    try {
        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo.FileName = $bashExe
        $proc.StartInfo.Arguments = "-c `"$cmd`""
        $proc.StartInfo.UseShellExecute = $false
        $proc.StartInfo.RedirectStandardInput = $true
        $proc.StartInfo.CreateNoWindow = $true
        $null = $proc.Start()
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Content)
        $proc.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
        $proc.StandardInput.BaseStream.Flush()
        $proc.StandardInput.Close()
        $proc.WaitForExit()
        return ($proc.ExitCode -eq 0)
    } catch {
        return $false
    }
}

# --- Read hook stdin JSON ---
$stdinRaw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($stdinRaw)) { exit 0 }

try {
    $hookInput = $stdinRaw | ConvertFrom-Json -ErrorAction Stop
} catch {
    # Malformed JSON - nothing to do
    exit 0
}

# --- Extract file path from tool_input (Edit/Write payload) ---
$filePath = $null
if ($hookInput.PSObject.Properties.Name -contains 'tool_input') {
    $ti = $hookInput.tool_input
    if ($ti.PSObject.Properties.Name -contains 'file_path') {
        $filePath = $ti.file_path
    }
}
if ([string]::IsNullOrWhiteSpace($filePath)) { exit 0 }

# --- Scope: only hub/staging/*/STATE.md ---
if ($filePath -notmatch '[/\\]hub[/\\]staging[/\\][^/\\]+[/\\]STATE\.md$') { exit 0 }
if (-not (Test-Path -LiteralPath $filePath)) { exit 0 }

# --- Parse frontmatter ---
$content = Get-Content -Raw -LiteralPath $filePath -ErrorAction SilentlyContinue
if (-not $content) { exit 0 }
if ($content -notmatch '(?s)^---\s*\r?\n(.*?)\r?\n---') { exit 0 }
$frontmatterRaw = $Matches[1]

# --- Validate required v2 fields ---
$requiredFields = @(
    'task-id',
    'scope',
    'status',
    'protocol',
    'sub-protocol',
    'schema-version',
    'created',
    'last-updated',
    'current-wave',
    'current-round',
    'planner-task-id',
    'plan-approved-at',
    'pending-decisions',
    'blockers',
    'verified-artifacts',
    'resume-command'
)

$violations = @()

foreach ($field in $requiredFields) {
    if ($frontmatterRaw -notmatch "(?m)^$([regex]::Escape($field))\s*:") {
        $violations += "missing field: $field"
    }
}

# --- Schema version sentinel ---
if ($frontmatterRaw -match '(?m)^schema-version\s*:\s*(\S+)') {
    $sv = $Matches[1].Trim()
    if ($sv -ne '2') {
        $violations += "schema-version must be 2 (found: $sv). Run scripts/utils/migrate-state-md-v2.ps1."
    }
}

# --- Scope sanity ---
if ($frontmatterRaw -match '(?m)^scope\s*:\s*(\S+)') {
    $sc = $Matches[1].Trim().ToLower()
    if ($sc -notin @('mini','small','medium','large','ultra')) {
        $violations += "scope invalid: $sc (expected mini|small|medium|large|ultra)"
    }
}

# --- task-id slug format ---
if ($frontmatterRaw -match '(?m)^task-id\s*:\s*(\S+)') {
    $tid = $Matches[1].Trim()
    if ($tid -notmatch '^\d{4}-\d{2}-\d{2}-[a-z0-9-]+$' -and $tid -notmatch '^\{task-id\}$') {
        $violations += "task-id slug format invalid: $tid (expected YYYY-MM-DD-lowercase-slug)"
    }
}

# --- Log result to harness-audit-ledger.md ---
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$ledger   = Join-Path $repoRoot 'hub\state\harness-audit-ledger.md'
$timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm')
$taskId = if ($frontmatterRaw -match '(?m)^task-id\s*:\s*(\S+)') { $Matches[1].Trim() } else { 'unknown' }

if ($violations.Count -eq 0) {
    $row = "| $timestamp | $taskId | state-validator | RESULT:PASS | - |"
} else {
    $detail = ($violations -join '; ')
    $row = "| $timestamp | $taskId | state-validator | RESULT:FAIL | $detail |"
}

if (Test-Path -LiteralPath $ledger) {
    try {
        Add-Content -LiteralPath $ledger -Value $row -Encoding UTF8 -ErrorAction Stop
    } catch [System.UnauthorizedAccessException] {
        $null = Write-FileViaBashFallback -Path $ledger -Content ($row + "`n") -Append
    } catch {
        # Informational hook only; swallow other errors
    }
}

# --- Surface failures in today's daily note (informational, non-blocking) ---
if ($violations.Count -gt 0) {
    $today = Get-Date -Format 'yyyy-MM-dd'
    $y = Get-Date -Format 'yyyy'
    $m = Get-Date -Format 'MM'
    $notePath = Join-Path $repoRoot "notes\$y\$m\$today.md"
    if (Test-Path -LiteralPath $notePath) {
        $hhmm = Get-Date -Format 'hh:mm tt'
        $entry = @"

- **$hhmm** - **STATE.md Frontmatter Validation FAIL - $taskId** #protocol-audit #violation #state-validator

  **Work Type**: Harness self-audit - STATE.md schema v2 validation

  **Key Decisions**:
  - ⚠️ File: $filePath
  - ⚠️ Violations: $($violations -join '; ')

  **Strategic Value**: Surfaces schema drift immediately so downstream agents don't consume malformed state. Non-blocking - task continues; violation is logged to hub/state/harness-audit-ledger.md for metrics.

---
"@
        $noteContent = Get-Content -Raw -LiteralPath $notePath -ErrorAction SilentlyContinue
        if ($noteContent -and $noteContent -match '(?s)(<!-- PREPEND-ANCHOR:v1[^>]*-->\r?\n)') {
            $anchor = $Matches[1]
            $noteContent = $noteContent -replace [regex]::Escape($anchor), ($anchor + $entry)
            try {
                Set-Content -LiteralPath $notePath -Value $noteContent -NoNewline -Encoding UTF8 -ErrorAction Stop
            } catch [System.UnauthorizedAccessException] {
                $null = Write-FileViaBashFallback -Path $notePath -Content $noteContent
            } catch {
                # Informational hook only
            }
        }
    }
}

exit 
# SIG # Begin signature block
# MIIO5gYJKoZIhvcNAQcCoIIO1zCCDtMCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUki3xZLXPnfUgCqOrkEzO6OoR
# 6pagggxGMIIFXjCCA0agAwIBAgITEQAAShUf7tkAG2uFRwACAABKFTANBgkqhkiG
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
# ARUwIwYJKoZIhvcNAQkEMRYEFPlGk1d2zZiTIEHcFpz+H8DdYcg+MA0GCSqGSIb3
# DQEBAQUABIIBADtulPrQDthPxb8IMEa6Tp5SD9x+xtzzBtd//EkvHACrU/cpWQaB
# Ec3lQ6stfKcKbGmplrHTQap/S2bLgjJFkcMA5bQx6KUgCggm819YPB//qL5X82Vv
# QjbYag7RUPSJfueNVSMjHd8+c9wIjjCUtYa72zlQ4wJCJvpzLRtiCvira3TeaBsU
# enU/ZrIs67KWLQ+m58qjGMxqkGjYvTFT7wqp+bXdpF5X3BzuWH80prrc2SwZs7m3
# qWd3lWanNpIBMviVTmR9R4/MSityOulXr+868aV0uZ2Crim1Y5WJFH1ZlMzpGVAk
# 74lwiZTdxUpSpMVOBHCqIFbbes+uoAftCRk=
# SIG # End signature block
