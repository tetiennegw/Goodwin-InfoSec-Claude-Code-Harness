---
description: Scaffold a new script with proper headers, structure, and changelog — powershell, python, kql, or bash
user-invocable: true
allowed-tools: [Read, Write, Edit, Bash, Glob]
schema-version: 1
---
# Script Scaffold

Create a new script file with proper headers, boilerplate, and changelog.

**Usage**: `/script-scaffold <language> <script-name> [description]`

## Step 1: Parse Arguments
- `$ARGUMENTS` format: `<language> <script-name> [description]`
- First word: language — must be one of: `powershell`, `python`, `kql`, `bash`, `powershell-hook`
- Second word: script name (no extension)
- Remaining words: description (optional, defaults to "TBD")
- If arguments are missing, ask Tyler for language and script name.
- **Hook detection**: if the user request mentions "hook" or names a Claude Code lifecycle event (SessionStart / UserPromptSubmit / PreToolUse / PostToolUse / Stop / InstructionsLoaded), default language to `powershell-hook` and ask Tyler to confirm before generating.

## Step 2: Determine File Path and Extension
| Language | Extension | Directory |
|----------|-----------|-----------|
| powershell | .ps1 | scripts/powershell/ |
| powershell-hook | .ps1 | .claude/hooks/ |
| python | .py | scripts/python/ |
| kql | .kql | scripts/kql/ |
| bash | .sh | scripts/bash/ |

- Full path: `scripts/{language}/{script-name}.{ext}` (or `.claude/hooks/{script-name}.ps1` for hooks)
- Ensure the directory exists (create if needed).

## Step 3: Generate Script with Header and Boilerplate

### PowerShell (.ps1)
```powershell
# ============================================================
# Task: {task-id or "standalone"}
# Author: {{user.name}} ({{user.email}})
# Created: YYYY-MM-DD
# Purpose: {description}
# Dependencies: None
# Changelog (max 10):
#   YYYY-MM-DDTHH:MM | {project} | builder | Initial scaffold
# ============================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

[CmdletBinding()]
param(
    # Add parameters here
)

begin {
    # Initialization
}

process {
    # Main logic
}

end {
    # Cleanup
}
```

### PowerShell hook (.ps1 in `.claude/hooks/`)

Use this template for any new validator/audit/handler hook registered in `.claude/settings.local.json`. It includes the `Write-FileViaBashFallback` helper that EVERY hook touching repo files needs (ThreatLocker Storage Control denies `powershell.exe` writes to the repo tree on Goodwin endpoints; `bash.exe` writes succeed). This pattern is non-negotiable for hooks — see `feedback_threatlocker_storage_policy_powershell.md`.

```powershell
# ============================================================
# Hook: {script-name}.ps1
# Lifecycle Event: {SessionStart|UserPromptSubmit|PreToolUse|PostToolUse|Stop|InstructionsLoaded}
# Matcher: {tool-name regex if applicable, e.g. Edit|Write|MultiEdit; or "(none)"}
# Purpose: {description}
# Task: {task-id or "standalone"}
# Created: YYYY-MM-DD
# Dependencies: pwsh 5.1+ or 7+, ConvertFrom-Json (builtin)
# Changelog (max 10):
#   YYYY-MM-DDTHH:MM | {project} | builder | Initial scaffold (includes bash-fallback writer)
# ============================================================

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# --- bash-fallback writer: ThreatLocker storage control denies powershell.exe writes to repo paths.
# bash.exe writes through, so on UnauthorizedAccessException we pipe bytes to `cat > $path` (or `>>`).
# Pattern from protocol-execution-audit.ps1 / plan-compliance-audit.ps1 (2026-04-24+).
# Mandatory for any hook that writes to hub/state, hub/staging, notes/, or .claude/ paths.
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

# --- Read stdin JSON payload (for PreToolUse / PostToolUse / Stop events) ---
$stdinRaw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($stdinRaw)) { exit 0 }
try {
    $hookInput = $stdinRaw | ConvertFrom-Json -ErrorAction Stop
} catch {
    exit 0
}

# --- Extract relevant fields (PostToolUse / PreToolUse have tool_input.file_path; Stop has transcript_path) ---
# Customize for your event type.

# --- Main hook logic ---
# {Replace this block with your audit / validation / reaction logic}

# --- Append result row to ledger (use bash fallback on UnauthorizedAccessException) ---
$repoRoot  = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$ledger    = Join-Path $repoRoot 'hub\state\harness-audit-ledger.md'
$timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm')
$taskId    = 'unknown'  # parse from frontmatter or hookInput when applicable
$result    = 'PASS'     # 'PASS' | 'FAIL'
$detail    = '-'        # or violation summary
$row       = "| $timestamp | $taskId | {hook-tag} | RESULT:$result | $detail |"

if (Test-Path -LiteralPath $ledger) {
    try {
        Add-Content -LiteralPath $ledger -Value $row -Encoding UTF8 -ErrorAction Stop
    } catch [System.UnauthorizedAccessException] {
        $null = Write-FileViaBashFallback -Path $ledger -Content ($row + "`n") -Append
    } catch {
        # Informational hook only; swallow other errors
    }
}

exit 0
```

**Required next steps after scaffolding a hook:**
1. `/sign-script .claude/hooks/{script-name}.ps1` — Goodwin Authenticode signature (covers AllSigned + ThreatLocker Application Control).
2. Register the hook in `.claude/settings.local.json` under the appropriate event + matcher.
3. End-to-end smoke test by triggering the lifecycle event from a real tool use; verify a row appears in `hub/state/harness-audit-ledger.md`. **Do NOT skip the bash-fallback wrap** — even if Add-Content "works" the first time, it can fail under different process trees and the failure is silent.

### PowerShell utility (.ps1 in `scripts/powershell/`)
*Non-hook PowerShell utilities don't fire as lifecycle hooks; they're invoked by Tyler or by other scripts. The bash fallback is still recommended if the script writes to repo files.*

### Python (.py)
```python
#!/usr/bin/env python3
# ============================================================
# Task: {task-id or "standalone"}
# Author: {{user.name}} ({{user.email}})
# Created: YYYY-MM-DD
# Purpose: {description}
# Dependencies: None
# Changelog (max 10):
#   YYYY-MM-DDTHH:MM | {project} | builder | Initial scaffold
# ============================================================

"""
{description}
"""

import argparse
import logging
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)


def main(args: argparse.Namespace) -> None:
    """Main entry point."""
    pass


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="{description}")
    # Add arguments here
    parsed_args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    main(parsed_args)
```

### KQL (.kql)
```kql
// ============================================================
// Task: {task-id or "standalone"}
// Author: {{user.name}} ({{user.email}})
// Created: YYYY-MM-DD
// Purpose: {description}
// Parameters:
//   @timeRange: datetime — lookback period (default: 24h)
// Changelog (max 10):
//   YYYY-MM-DDTHH:MM | {project} | builder | Initial scaffold
// ============================================================

// let timeRange = ago(24h);
// Query starts here
```

### Bash (.sh)
```bash
#!/usr/bin/env bash
# ============================================================
# Task: {task-id or "standalone"}
# Author: {{user.name}} ({{user.email}})
# Created: YYYY-MM-DD
# Purpose: {description}
# Dependencies: None
# Changelog (max 10):
#   YYYY-MM-DDTHH:MM | {project} | builder | Initial scaffold
# ============================================================

set -euo pipefail

# --- Configuration ---

# --- Functions ---

# --- Main ---
main() {
    echo "Not yet implemented"
}

main "$@"
```

## Step 4: Register
- Update `INDEX.md` with the new script entry.
- Add a timeline entry to today's daily note with `#build` and the language tag (e.g., `#powershell`).

## Rules
- All scripts at Goodwin MUST have the standard header block with task-id, author, date, purpose, and changelog.
- PowerShell scripts will need to be signed before execution — remind Tyler to run `/sign-script` if it's a .ps1 file.
- Never overwrite an existing script without Tyler's confirmation.
