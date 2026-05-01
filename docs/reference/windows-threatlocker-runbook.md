---
type: reference
title: Windows / ThreatLocker Execution Strategy Runbook
audience: Goodwin InfoSec teammates forking this template
created: 2026-04-29
last-updated: 2026-04-29
---

# Windows / ThreatLocker Execution Strategy

This runbook explains how the Morpheus harness handles Windows-specific execution constraints — particularly Goodwin endpoints with ThreatLocker Application Control + Storage Control. It covers (1) the BYO-cert signing flow, (2) the bash-fallback writer pattern in PowerShell hooks, (3) how to test signed-PS hook execution, (4) ThreatLocker integration with graceful degradation, and (5) cross-OS notes.

The harness is **Windows-first**. macOS and Linux support is future-work (see §5).

---

## 1. Signing Flow (BYO-Cert per D8)

PowerShell hooks (`SessionStart`, `PreToolUse`, `PostToolUse`, `Stop`, `UserPromptSubmit`) must be signed before they will execute under Windows AllSigned policy. On Goodwin endpoints, AllSigned is enforced via ThreatLocker Application Control. On non-Goodwin endpoints with the default `RemoteSigned` policy, signing is recommended but not required for hooks loaded from the local repo.

The `/onboard` skill captures your signing preference at first run (Step 7 — dependency bootstrap). Three options:

### Option A — BYO-Cert (Recommended for Goodwin endpoints)
You provide an existing code-signing certificate. `/onboard` writes the cert path + thumbprint to `.harness-onboarded.json` under `ext.signing` and sets `signing.byo: true`. The `/sign-script` skill then uses your cert via `Set-AuthenticodeSignature`.

Required: your cert is in the local certificate store (`Cert:\CurrentUser\My`) and chains to a CA trusted by the machine. On Goodwin endpoints, the Goodwin Internal CA chain is pre-installed; teammates obtain a personal signing cert via the standard internal request process.

### Option B — Self-signed cert generated at `/onboard`
`/onboard` runs `New-SelfSignedCertificate` and adds the resulting cert to `Cert:\CurrentUser\Trusted Publishers`. Requires UAC elevation; **not recommended on locked-down enterprise machines** because some Group Policies block self-signed Trusted Publishers entries.

### Option C — Skip signing (set `ExecutionPolicy=Bypass`)
`/onboard` sets `signing.skip: true` and the hook commands in `.claude/settings.json` use `pwsh.exe -ExecutionPolicy Bypass`. Simplest baseline; no signing infrastructure required. **NOT viable on Goodwin endpoints** because ThreatLocker AC enforces signature-based application policy regardless of `ExecutionPolicy`.

### Decision matrix

| Environment | Recommendation |
|-------------|----------------|
| Goodwin laptop with personal signing cert | **A — BYO-Cert** |
| Goodwin laptop without personal cert | Get one via internal request, then **A**. Until then, work cannot fire signed hooks; use `/onboard --skip-signing` to defer. |
| Personal/non-Goodwin Windows box | **C — Skip** (ExecutionPolicy=Bypass) is fine for personal use; **A** if you happen to have a personal cert |
| Shared lab machine | **C — Skip** unless lab policy mandates signing |

---

## 2. Bash-Fallback Writer Pattern

ThreatLocker Storage Control on Goodwin endpoints **denies** `powershell.exe` writes to the project tree, even when the .ps1 script itself is signed and approved by Application Control. This is by design: Storage Control gates write authority by the *executable image* doing the write, not by the script's identity.

### What this breaks

Naïve PS hooks that write to `hub/state/`, `notes/`, or any project-tree path via `Add-Content` / `Set-Content` / `[IO.File]::WriteAllText` will hit `System.UnauthorizedAccessException` on Goodwin endpoints — even though the same code works fine on non-Goodwin Windows.

### The fix: `Write-FileViaBashFallback`

Every PS hook that writes to the project tree includes a helper that shells out to `bash.exe` (which Storage Control allows) for the actual file write:

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
    } catch { return $false }
}
```

Wrap every `Add-Content` / `Set-Content` / `[IO.File]::WriteAllText` call:

```powershell
try {
    Add-Content -LiteralPath $target -Value $row -Encoding UTF8 -ErrorAction Stop
} catch [System.UnauthorizedAccessException] {
    $null = Write-FileViaBashFallback -Path $target -Content ($row + "`n") -Append
} catch {
    # Informational hook — swallow other errors
}
```

The harness's existing PS hooks (`protocol-execution-audit.ps1`, `task-discipline-audit.ps1`, `state-frontmatter-validator.ps1`, `plan-compliance-audit.ps1`) all include this helper.

### When the fallback is unnecessary

On non-Goodwin Windows machines without ThreatLocker Storage Control, the try-catch falls through to the normal write. The fallback adds ~50 ms latency only on the failure path, so leaving it in for portable hooks is cost-free.

---

## 3. Testing Signed PS Hook Execution

The template ships test scaffolding in `scripts/utils/test-onboard.ps1` (Pester) — but full hook execution tests require:
- A trusted signing cert (your BYO cert or a self-signed one in `Trusted Publishers`)
- Hooks signed via `/sign-script` after any modification

### Manual smoke test

```powershell
# After /onboard with BYO-cert, sign all hooks:
Get-ChildItem .claude/hooks/*.ps1 | ForEach-Object {
    Set-AuthenticodeSignature -FilePath $_.FullName -Certificate $cert
}

# Trigger a SessionStart event by opening Claude Code in this dir
# Verify hook fires by checking hub/state/harness-audit-ledger.md for a new row
```

### Pester test (idempotency)

```powershell
Describe 'PS Hook Signing' {
    It 'all hooks have a valid signature post-onboard' {
        Get-ChildItem .claude/hooks/*.ps1 | ForEach-Object {
            $sig = Get-AuthenticodeSignature -FilePath $_.FullName
            $sig.Status | Should -Be 'Valid'
        }
    }
}
```

Run via `Invoke-Pester scripts/utils/test-onboard.ps1`.

### CI/Automated testing

Out of scope for this template. Goodwin-internal teammates with infrastructure access can wire signed-hook tests into a CI pipeline; non-Goodwin users typically test manually.

---

## 4. ThreatLocker Integration

ThreatLocker is a Goodwin-endpoint-only constraint (Application Control + Storage Control). The harness graceful-degrades when ThreatLocker is absent:

- Application Control absent → hooks run regardless of signature; signing is optional
- Storage Control absent → PS hooks write directly via `Add-Content`; bash-fallback never fires (try-block succeeds)
- Both absent → harness behaves like a vanilla Windows install

### Detecting ThreatLocker presence

`/onboard` Step 4 (path scaffolding) probes for ThreatLocker by checking for the tray-app process or registry key:

```powershell
$tlPresent = Get-Process -Name 'ThreatLockerService' -ErrorAction SilentlyContinue -ne $null
```

If present, `/onboard` enforces BYO-cert (signing.skip becomes invalid). If absent, all 3 signing options remain available.

### When ThreatLocker tray prompts fire

First-time signing of any new .ps1 (e.g., a new hook authored mid-session) may trigger a ThreatLocker tray approval request. The tray request must be approved by the user; the harness does not bypass this. Goodwin teammates: approve the request when it appears, then re-run the operation.

This is documented in `feedback_threatlocker_inline_powershell.md` (memory) and `feedback_sign_script_must_be_tyler_session.md` (memory).

---

## 5. Cross-OS Notes

The Morpheus harness is **Windows-first**. The following are confirmed broken on non-Windows; future-work to address:

| Component | Windows | macOS | Linux | Notes |
|-----------|---------|-------|-------|-------|
| Bash hooks (`*.sh`) | ✅ via Git Bash | ✅ native | ✅ native | Cross-platform OK |
| PowerShell hooks (`*.ps1`) | ✅ pwsh 7+ or WinPS 5.1 | ⚠️ pwsh 7+ only | ⚠️ pwsh 7+ only | WinPS 5.1 features (Set-AuthenticodeSignature, Get-Process tray) Windows-only |
| Bash-fallback writer | ✅ Windows-only need | ❌ Not applicable | ❌ Not applicable | macOS/Linux don't have ThreatLocker; remove or no-op |
| Hardcoded `{{paths.home}}\AppData\Local\Programs\Git\bin\bash.exe` | ✅ standard | ❌ different bash path | ❌ different bash path | macOS/Linux: `bash --version` is on `$PATH`; substitution engine sets `bash.exe-path` placeholder per-OS |
| `winget install` for dep bootstrap | ✅ native | ❌ `brew install` | ❌ `apt`/`dnf`/etc. | `bootstrap-dependencies.sh` would need OS-specific branching |
| Trusted Publishers (signing) | ✅ Windows store | ⚠️ macOS Keychain | ⚠️ Linux: depends | Signing flow Windows-only |

### Future-work tracker

`hub/state/roadmap.md` has a "Cross-OS support" entry tracking the work needed to make the harness portable to macOS and Linux. Out of scope for the initial template release.

---

## Cross-References

- `feedback_threatlocker_storage_policy_powershell.md` — original Storage Control investigation (memory)
- `feedback_threatlocker_inline_powershell.md` — AllSigned inline-PS bypass (memory)
- `feedback_sign_before_test.md` — Build → Sign → Test → Deploy pattern (memory)
- `feedback_pwsh_for_signing.md` — pwsh.exe (not powershell.exe) for Set-AuthenticodeSignature (memory)
- `.claude/rules/scripts.md` — script header + bash-fallback writer rule
- `.claude/commands/sign-script.md` — `/sign-script` skill (BYO-cert workflow)

---

## Changelog

| ts | project | agent | change |
| 2026-04-29T14:55 | 2026-04-28-morpheus-templatize-port | orchestrator (Morpheus, inline P8) | Phase 8 runbook: 5 sections covering BYO-cert (D8), bash-fallback writer pattern, PS hook tests, ThreatLocker graceful-degrade, cross-OS notes. |
