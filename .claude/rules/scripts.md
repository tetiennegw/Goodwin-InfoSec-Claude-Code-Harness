---
globs: "scripts/**,.claude/hooks/**"
schema-version: 1
---

# Script Standards

This rule is auto-loaded for `scripts/**` and `.claude/hooks/**` paths. It defines header requirements, language standards, TDD approach, security practices, and Goodwin-endpoint-specific patterns (signing, ThreatLocker, bash-fallback writer).

---

## Script Header Requirements

Every script file MUST include a comment header block with:

```
# ============================================================
# Task: {task-id}
# Agent: {agent-type}
# Created: {ISO timestamp}
# Last-Updated: {ISO timestamp}
# Plan: {plan file path or "N/A" for standalone scripts}
# Purpose: {one-line description of what this script does}
# Dependencies: {list of external tools, modules, or packages required}
# Changelog (max 10):
#   {timestamp} | {project} | {agent} | {change description}
# ============================================================
```

Adapt the comment character to the language (`#` for Python/Bash/PowerShell, `//` for KQL).

---

## Language Standards

### PowerShell (.ps1)

- Enable strict mode at the top of every script:
  ```powershell
  Set-StrictMode -Version Latest
  $ErrorActionPreference = 'Stop'
  ```
- Use approved verbs only (`Get-`, `Set-`, `New-`, `Remove-`, `Invoke-`, etc.). Run `Get-Verb` for the full list.
- Use `[CmdletBinding()]` and `param()` blocks for scripts that accept parameters.
- Include `-WhatIf` and `-Confirm` support for destructive operations.
- Write verbose output with `Write-Verbose`, not `Write-Host` (except for user-facing CLI output).

### PowerShell hooks (.ps1 in `.claude/hooks/`)

Hooks are PowerShell scripts invoked by the Claude Code harness at lifecycle events (SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, Stop, InstructionsLoaded). They run in the `bash.exe → powershell.exe` process chain on Goodwin endpoints, which has two policy layers:

- **Application Control** (signature-based) — gates which `.ps1` files can *execute*. Goodwin-signed scripts auto-pass.
- **Storage Control** (executable+path-based) — gates which *executable images* can *write* to which paths. **Storage Control DENIES `powershell.exe` writes to the project tree regardless of script signature.**

`/sign-script` only addresses Application Control. For ANY hook that writes to `hub/state/`, `hub/staging/`, `notes/`, or other project-tree paths, the hook MUST include a bash-fallback writer.

**Mandatory pattern** (every hook that writes — see `feedback_threatlocker_storage_policy_powershell.md` and proven instances in `protocol-execution-audit.ps1`, `plan-compliance-audit.ps1`, `task-discipline-audit.ps1`, `state-frontmatter-validator.ps1`):

```powershell
function Write-FileViaBashFallback {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$Content,
        [switch]$Append
    )
    $bashExe = '{{paths.home}}\AppData\Local\Programs\Git\bin\bash.exe'
    if (-not (Test-Path -LiteralPath $bashExe)) { return $false }
    $unixPath = $Path -replace '\\','/'
    if ($unixPath -match '^([A-Za-z]):(.*)$') { $unixPath = '/' + $Matches[1].ToLower() + $Matches[2] }
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
    } catch { return $false }
}
```

Then wrap every Add-Content / Set-Content / [IO.File]::Write call:

```powershell
try {
    Add-Content -LiteralPath $target -Value $row -Encoding UTF8 -ErrorAction Stop
} catch [System.UnauthorizedAccessException] {
    $null = Write-FileViaBashFallback -Path $target -Content ($row + "`n") -Append
} catch {
    # Informational hook only; swallow other errors so they don't surface as tool errors
}
```

**Hook-specific build rules:**

1. **Use `/script-scaffold powershell-hook <name>`** to generate a new hook — the scaffold ships with `Write-FileViaBashFallback` and the try/catch wrap baked in. Never copy a non-hook PS template into `.claude/hooks/`.
2. **Sign immediately after first complete draft** via `/sign-script` — testing unsigned `.ps1` on Goodwin endpoints is impossible (AllSigned blocks both execution and `Get-Content`). Build → Sign → Test → Deploy.
3. **Re-sign after every edit** — any modification invalidates the Authenticode signature. Re-signing is cheap (one `/sign-script` call); re-running ThreatLocker tray approvals is rare (signature is the trust anchor, not the hash).
4. **Read content via `tool_input.content`** when handling Write events — Storage Control also denies `Get-Content` reads of files Claude Code just wrote. Claude Code's hook payload includes the full content for Write tool uses; use that as the primary read path. 3-tier read pattern: `tool_input.content` → `[IO.File]::ReadAllText` → `Get-Content`.
5. **No literal em-dash (`—`) in hook source** — Windows PowerShell 5.1 invoked via `powershell.exe -File` interprets source files as cp1252 by default and chokes on em-dash. Use `\u2014` in regex strings; use ASCII `-` or `--` in messages. Any non-ASCII character in source code is a parse-risk.
6. **Hook output is informational, not authoritative** — design hooks to be non-blocking by default. Use `exit 0` for PASS, `exit 2` only when blocking feedback is genuinely warranted (e.g., plan-compliance-audit). Always swallow unexpected exceptions in catch blocks; the worst hook is a hook that crashes a tool call with no actionable error.
7. **Register in `.claude/settings.local.json`** with `powershell.exe -NoProfile -ExecutionPolicy Bypass -File` and a sane `timeout` (5000–10000 ms). Match on the appropriate event + matcher (e.g., `Edit|Write|MultiEdit` for PostToolUse).
8. **Append rows above `<!-- LEDGER-APPEND-ANCHOR -->`** in `hub/state/harness-audit-ledger.md` — that's the canonical append point. Validator-row format: `| {ISO} | {task-id} | {hook-tag} | RESULT:{PASS\|FAIL} | {details or -} |`.

### Python (.py)

- Use type hints on all function signatures and return types.
- Use `argparse` for CLI scripts (not `sys.argv` parsing).
- Include a `requirements.txt` or inline comment listing dependencies if any non-stdlib packages are used.
- Target Python 3.10+ (match/case is acceptable).
- Use `pathlib.Path` over `os.path` for file operations.
- Use `logging` module, not `print()`, for diagnostic output.

### KQL (.kql)

- Include commented section headers dividing logical query blocks:
  ```kql
  // === Parameters ===
  let timeRange = 7d;
  // === Data Source ===
  SecurityEvent
  // === Filters ===
  | where TimeGenerated > ago(timeRange)
  // === Output ===
  | project TimeGenerated, Account, Computer
  ```
- Parameterize time ranges and thresholds (use `let` statements at the top).
- Include a comment block at the top explaining what the query detects and expected output schema.

### Bash (.sh)

- Always start with `#!/bin/bash` and `set -euo pipefail`.
- Scripts must be shellcheck-clean (no SC warnings). Run `shellcheck` if available.
- Quote all variable expansions: `"$var"` not `$var`.
- Use `[[ ]]` for conditionals, not `[ ]`.
- Use `local` for function-scoped variables.
- Include a usage function for scripts that accept arguments.

---

## TDD Approach

### Write Tests Before Implementation
For any script that has testable logic:
1. Define the expected behavior as test cases FIRST
2. Write the test file (matching language test framework)
3. Run tests -- they should FAIL (red)
4. Implement the script
5. Run tests -- they should PASS (green)
6. Refactor if needed, re-run tests

### test_map.txt Pattern
Maintain a `test_map.txt` file in the scripts directory that maps functions to their test files:

```
# test_map.txt — Function-to-test mapping
# Format: source_file:function_name -> test_file:test_name
scripts/python/check_alerts.py:parse_alert -> tests/test_check_alerts.py:test_parse_alert
scripts/python/check_alerts.py:severity_score -> tests/test_check_alerts.py:test_severity_score
scripts/utils/ensure-note.sh:create_note -> tests/test_ensure_note.sh:test_create_note
```

This enables targeted test runs and regression detection. Update test_map.txt whenever adding new functions or tests.

### Test Frameworks by Language
| Language | Framework | Test Location |
|----------|-----------|---------------|
| Python | pytest | `tests/` mirror of source structure |
| PowerShell | Pester | `tests/` mirror of source structure |
| Bash | bats-core or inline assertions | `tests/` or inline |
| KQL | Manual validation via Sentinel | Documented in script header |

---

## Security Standards

1. **No hardcoded secrets** -- never embed API keys, passwords, tokens, or connection strings in script files. Use environment variables, Azure Key Vault references, or parameter files excluded from version control.

2. **Validate all inputs** -- check parameter types, ranges, and formats before processing. Reject unexpected input early.

3. **Log for audit trails** -- all scripts that perform actions (not just queries) must log what they did, when, and the outcome. Use structured logging where possible.

4. **Principle of least privilege** -- scripts should request only the permissions they need. Document required permissions in the header.

5. **Sanitize output** -- never echo raw secrets, tokens, or PII to stdout/logs. Mask sensitive fields.

**Good example:**
```python
import os
api_key = os.environ.get("SENTINEL_API_KEY")
if not api_key:
    raise EnvironmentError("SENTINEL_API_KEY environment variable not set")
```

**Bad example:**
```python
api_key = "sk-abc123def456"  # NEVER DO THIS
```
