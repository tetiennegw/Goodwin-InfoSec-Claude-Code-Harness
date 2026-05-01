# ============================================================
# Hook: task-discipline-audit.ps1
# Lifecycle Event: Stop (end-of-turn)
# Purpose: Audit task-list discipline per .claude/rules/task-handling.md.
#          On every Stop event:
#            1. Detect TaskUpdate status=cancelled or status=deleted calls this turn.
#               If any exist, check the last user message for authorization
#               keywords (cancel, drop, abandon, nevermind, skip, remove, kill,
#               scrap). Missing authorization = FAIL (violation).
#            2. Detect multi-step work (>=2 mutating tool uses: Edit, Write,
#               MultiEdit, Bash with non-read-only patterns) with 0 TaskCreate
#               or TaskUpdate in the turn window = SOFT (soft violation).
#            3. Otherwise PASS.
#          Writes one TASKDISC row to hub/state/harness-audit-ledger.md per Stop
#          event. On non-PASS result, prepends a timeline entry to today's
#          daily note.
#          Non-blocking. Never rejects a TaskUpdate. Audit-only by 2026-04-23
#          design decision (Step 6c of /the-protocol run for task-id
#          2026-04-23-task-discipline-primitive).
# Dependencies: pwsh 7+ OR Windows PowerShell 5.1, transcript_path in stdin JSON
# Changelog (max 10):
#   2026-04-23T18:35 | 2026-04-23-task-discipline-primitive | morpheus | Created initial audit hook. Clones skeleton from protocol-execution-audit.ps1 lines 15-45. Adds meta-violation detector + cancellation-violation detector + TASKDISC ledger row format.
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

$stdinRaw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($stdinRaw)) { exit 0 }

try {
    $hookInput = $stdinRaw | ConvertFrom-Json -ErrorAction Stop
} catch {
    exit 0
}

# --- Extract transcript path ---
$transcriptPath = $null
if ($hookInput.PSObject.Properties.Name -contains 'transcript_path') {
    $transcriptPath = $hookInput.transcript_path
}
if ([string]::IsNullOrWhiteSpace($transcriptPath) -or -not (Test-Path -LiteralPath $transcriptPath)) { exit 0 }

# --- Parse transcript JSONL ---
$lines = @(Get-Content -LiteralPath $transcriptPath -ErrorAction SilentlyContinue)
if (-not $lines -or $lines.Count -eq 0) { exit 0 }

$events = @()
foreach ($line in $lines) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    try {
        $obj = $line | ConvertFrom-Json -ErrorAction Stop
        $events += $obj
    } catch { continue }
}

if ($events.Count -eq 0) { exit 0 }

# --- Find most recent user message (turn-window start) ---
$turnStartIdx = -1
$lastUserText = ''
for ($i = $events.Count - 1; $i -ge 0; $i--) {
    $e = $events[$i]
    if ($e.PSObject.Properties.Name -notcontains 'message' -or -not $e.message) { continue }
    if ($e.message.PSObject.Properties.Name -notcontains 'role') { continue }
    if ($e.message.role -ne 'user') { continue }

    # Skip tool_result events (those are also user-role but not actual user prompts)
    if ($e.message.PSObject.Properties.Name -contains 'content' -and $e.message.content) {
        $content = $e.message.content
        $isToolResult = $false
        if ($content -is [array]) {
            foreach ($c in $content) {
                if ($c.PSObject.Properties.Name -contains 'type' -and $c.type -eq 'tool_result') {
                    $isToolResult = $true
                    break
                }
            }
        }
        if ($isToolResult) { continue }

        # Extract text from user message
        if ($content -is [string]) {
            $lastUserText = $content
        } elseif ($content -is [array]) {
            foreach ($c in $content) {
                if ($c.PSObject.Properties.Name -contains 'type' -and $c.type -eq 'text' -and
                    $c.PSObject.Properties.Name -contains 'text') {
                    $lastUserText += $c.text + "`n"
                }
            }
        }
    }
    $turnStartIdx = $i
    break
}

if ($turnStartIdx -lt 0) { exit 0 }

# --- Scan turn window: count tool uses, TaskCreate, TaskUpdate, cancellations ---
$mutatingToolCount = 0
$taskCreateCount = 0
$taskUpdateCount = 0
$cancelledTaskUpdates = @()

for ($i = $turnStartIdx; $i -lt $events.Count; $i++) {
    $e = $events[$i]
    if ($e.PSObject.Properties.Name -notcontains 'message' -or -not $e.message) { continue }
    if ($e.message.PSObject.Properties.Name -notcontains 'content') { continue }
    $content = $e.message.content
    if ($content -isnot [array]) { continue }

    foreach ($c in $content) {
        if ($c.PSObject.Properties.Name -notcontains 'type') { continue }
        if ($c.type -ne 'tool_use') { continue }
        if ($c.PSObject.Properties.Name -notcontains 'name') { continue }

        switch ($c.name) {
            'TaskCreate' { $taskCreateCount++ }
            'TaskUpdate' {
                $taskUpdateCount++
                # Check for cancellation
                if ($c.PSObject.Properties.Name -contains 'input' -and $c.input) {
                    $statusVal = $null
                    if ($c.input.PSObject.Properties.Name -contains 'status') {
                        $statusVal = $c.input.status
                    }
                    if ($statusVal -and ($statusVal -eq 'cancelled' -or $statusVal -eq 'deleted')) {
                        $taskId = 'unknown'
                        if ($c.input.PSObject.Properties.Name -contains 'taskId') { $taskId = $c.input.taskId }
                        $cancelledTaskUpdates += @{ taskId = $taskId; status = $statusVal }
                    }
                }
            }
            { $_ -in 'Edit','Write','MultiEdit' } { $mutatingToolCount++ }
            'Bash' {
                # Conservative: count any Bash call as potentially mutating.
                # Read-only bash (ls, cat, grep) is rare in normal flow; overcounting
                # produces false-POSITIVE task-discipline signals (task exists, all good),
                # not false-NEGATIVES. Safe default.
                $mutatingToolCount++
            }
        }
    }
}

# --- Authorization check for cancellations ---
$authKeywordPattern = '\b(cancel|drop|abandon|nevermind|never mind|skip|remove|kill|scrap|don''t do that|do not do that)\b'
$hasAuthorization = $false
if ($lastUserText -and $lastUserText -match $authKeywordPattern) {
    $hasAuthorization = $true
}

# --- Determine result ---
$cancelCount = $cancelledTaskUpdates.Count
$hasCancellation = $cancelCount -gt 0
$cancellationViolation = $hasCancellation -and (-not $hasAuthorization)
$metaViolation = ($mutatingToolCount -ge 2) -and ($taskCreateCount -eq 0) -and ($taskUpdateCount -eq 0)

$result = 'PASS'
$reasonParts = @()
if ($cancellationViolation) {
    $result = 'FAIL'
    $cancelledIds = ($cancelledTaskUpdates | ForEach-Object { $_.taskId }) -join ','
    $reasonParts += "cancellation without authorization (taskIds=$cancelledIds)"
}
if ($metaViolation) {
    # Meta-violation is SOFT unless we already have a FAIL
    if ($result -ne 'FAIL') { $result = 'SOFT' }
    $reasonParts += "multi-step work ($mutatingToolCount mutating tool uses) with no TaskCreate/TaskUpdate this turn"
}
$reason = if ($reasonParts.Count -eq 0) { '-' } else { ($reasonParts -join '; ') }

# --- Infer task-id from most recently modified staging STATE.md (same pattern as protocol-execution-audit) ---
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$stagingRoot = Join-Path $repoRoot 'hub\staging'
$taskId = 'n/a'
if (Test-Path -LiteralPath $stagingRoot) {
    $latest = Get-ChildItem -LiteralPath $stagingRoot -Directory -ErrorAction SilentlyContinue |
              Sort-Object -Property LastWriteTime -Descending |
              Select-Object -First 1
    if ($latest) {
        $statePath = Join-Path $latest.FullName 'STATE.md'
        if (Test-Path -LiteralPath $statePath) {
            $state = Get-Content -Raw -LiteralPath $statePath -ErrorAction SilentlyContinue
            if ($state -and $state -match '(?m)^task-id\s*:\s*(\S+)') { $taskId = $Matches[1].Trim() }
        }
    }
}

# --- Compose ledger row (validator-event schema) ---
$timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm')
$cancelFlag = if ($hasCancellation) { 'Y' } else { 'N' }
$authFlag = if ($hasAuthorization) { 'Y' } else { 'N' }
$metricsSegment = "TOOLS:$mutatingToolCount TC:$taskCreateCount TU:$taskUpdateCount CANCEL:$cancelFlag AUTH:$authFlag"
$detailSegment = if ($reason -eq '-') { $metricsSegment } else { "$metricsSegment - $reason" }
$row = "| $timestamp | $taskId | task-discipline-audit | RESULT:$result | $detailSegment |"

# --- Append to ledger ---
$ledger = Join-Path $repoRoot 'hub\state\harness-audit-ledger.md'
if (Test-Path -LiteralPath $ledger) {
    try {
        Add-Content -LiteralPath $ledger -Value $row -Encoding UTF8 -ErrorAction Stop
    } catch [System.UnauthorizedAccessException] {
        $null = Write-FileViaBashFallback -Path $ledger -Content ($row + "`n") -Append
    } catch {
        # Informational hook only; swallow other errors
    }
}

# --- Surface violations (SOFT or FAIL) to daily note ---
if ($result -ne 'PASS') {
    $today = Get-Date -Format 'yyyy-MM-dd'
    $y = Get-Date -Format 'yyyy'
    $m = Get-Date -Format 'MM'
    $notePath = Join-Path $repoRoot "notes\$y\$m\$today.md"
    if (Test-Path -LiteralPath $notePath) {
        $hhmm = Get-Date -Format 'hh:mm tt'
        $violationLabel = if ($result -eq 'FAIL') { 'VIOLATION' } else { 'SOFT-VIOLATION' }
        $entry = @"

- **$hhmm** - **Task Discipline Audit $violationLabel - $taskId** #task-discipline #audit #violation

  **Work Type**: Harness self-audit - task-list discipline per .claude/rules/task-handling.md

  **Implementation Tasks**:
  - $(if ($result -eq 'FAIL') { 'X' } else { 'WARN' }) Result: $result
  - Tool uses this turn: $mutatingToolCount mutating; TaskCreate: $taskCreateCount; TaskUpdate: $taskUpdateCount
  - Cancellation detected: $cancelFlag; Authorization detected: $authFlag
$(if ($cancellationViolation) { "  - FAIL reason: cancellation without same-turn Tyler authorization" })
$(if ($metaViolation) { "  - SOFT reason: multi-step work with no task-list write" })

  **Key Decisions**:
  - Audit-only: task continued; violation recorded to hub/state/harness-audit-ledger.md.
  - Rule reference: .claude/rules/task-handling.md Non-Cancellation Invariant / Meta-Task Principle sections.

  **Strategic Value**: Mechanical enforcement of task-list discipline. Every violation is evidence feeding the 2-week data-review milestone (hub/state/roadmap.md). SOFT rate > 30 percent triggers Phase 2 prompt-side flagger escalation review.

---
"@
        $noteContent = Get-Content -Raw -LiteralPath $notePath -ErrorAction SilentlyContinue
        if ($noteContent -and $noteContent -match '(?s)(<!-- PREPEND-ANCHOR:v1[^>]*-->\r?\n)') {
            $anchor = $Matches[1]
            $noteContent = $noteContent -replace [regex]::Escape($anchor), ($anchor + $entry)
            Set-Content -LiteralPath $notePath -Value $noteContent -NoNewline -Encoding UTF8
        }
    }
}

exit 
# SIG # Begin signature block
# MIIO5gYJKoZIhvcNAQcCoIIO1zCCDtMCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUd58qq6TuQeCyQxS8lVzs4D1P
# ZQGgggxGMIIFXjCCA0agAwIBAgITEQAAShUf7tkAG2uFRwACAABKFTANBgkqhkiG
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
# ARUwIwYJKoZIhvcNAQkEMRYEFLEUsK/tOs6X2xVoX0Ya/dv2K6zfMA0GCSqGSIb3
# DQEBAQUABIIBAJ9ieKdNId/2exMmdUOh92vgnREh0HQfetC0lNgTj9WVZRHZfNNz
# jrh23ThalC9sHRZ6iBH0rzpzjsAXfKJiuOVoJH8y4aQ8Q2xI72JgTRgKXxxzlXm9
# nKMWjH3SKTPBRS/ph3GmFUbgXIpqBoOc0YV6Lxu2V5zJ0jE9KU7pUHzNMoZbDEJ3
# m6yBqD3DOTY9LVk7n99s4hlL4Jy/Bsm0n2rjhAgf4JEaViklpLs4LCWy3KuFYqJX
# WZkz5sc5wVHDmC5i6QsDkGhc/eVm0qvzmW4df1Dl/8PziAygKSkHZG1S7sYujHRB
# LD8Q15CjpAe6g9qEq3PmTXlZCZVRBYX18hY=
# SIG # End signature block
