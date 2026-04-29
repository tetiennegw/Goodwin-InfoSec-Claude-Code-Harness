---
title: Execution Trust Per File Type -- Goodwin Endpoint Reference
category: security
tags:
  - code-signing
  - authenticode
  - threatlocker
  - powershell
  - endpoint-security
  - trust-workflow
created: 2026-04-17
last-updated: 2026-04-17
last-verified: 2026-04-17
review-interval: 90d
status: active
author: Morpheus
---
# Execution Trust Per File Type -- Goodwin Endpoint Reference

## Summary

Goodwin Procter endpoints operate two overlapping execution gates: **AllSigned** PowerShell execution policy (Group Policy MachinePolicy scope) and **ThreatLocker** application allowlisting with ringfencing. For Authenticode-native file types (.ps1, .psm1, .psd1, .exe, .dll, .msi, WSH types .js/.vbs/.wsf), trust can be established by signing with the Goodwin-East-SUB02 code-signing certificate using Set-AuthenticodeSignature (PowerShell and WSH types) or signtool.exe (PE and installer types). For interpreter-mediated file types (.py, .sh, Node .js, .bat/.cmd), no file-level signing mechanism exists -- trust lives in the interpreter binary itself. This article synthesizes W1 research and W2 PoC results from task 2026-04-17-trust-workflow-expansion.

---

## Content

### The Fundamental Split: Authenticode-Native vs. Interpreter-Mediated

Every file type on a Goodwin endpoint falls into one of two trust categories.

**Authenticode-Native**: Windows WinVerifyTrust API can inspect these files directly. Signing embeds a certificate-chained signature into the file, and Windows (and ThreatLocker) can verify it at runtime without relying on which interpreter launched the file.

**Interpreter-Mediated**: Plain text source files with no Authenticode mechanism. The runtime enforcement gate is on the interpreter binary (python.exe, bash.exe, node.exe), not the source file. Signing the source file either does nothing (.py, .sh) or is only meaningful if the interpreter is configured to enforce it (WSH types with TrustPolicy=2).

---

### Per-Type Cheat Sheet

Empirical PoC results from the Goodwin endpoint (Windows 11 26100, PowerShell 7.6.0, Goodwin-East-SUB02 cert).

| Extension | Category | Signing Tool | Validation Command | ThreatLocker Notes | PoC Status |
|-----------|----------|--------------|-------------------|--------------------|------------|
| .ps1 | Authenticode | Set-AuthenticodeSignature | Get-AuthenticodeSignature | Auto-approved by publisher rule (Patrick confirmed) | Implemented in /sign-script |
| .psm1 / .psd1 | Authenticode | Set-AuthenticodeSignature | Get-AuthenticodeSignature | Likely covered -- **Patrick Q2 pending** | PASS (PoC W2R1) |
| .ps1xml / .cdxml | Authenticode | Set-AuthenticodeSignature | Get-AuthenticodeSignature | Covered by AllSigned; ThreatLocker scope unconfirmed | Not tested (same mechanism) |
| .exe / .dll / .sys | Authenticode (PE) | signtool.exe | signtool verify /pa /v | **Patrick Q1 pending** -- auto-approve unknown for PE types | BLOCKED -- SDK absent |
| .msi / .msix / .appx | Authenticode (MSI) | signtool.exe | signtool verify /pa /v | **Patrick Q1 pending** | BLOCKED -- SDK + WiX absent |
| .js (WSH/JScript) | Authenticode (WSH) | Set-AuthenticodeSignature | Get-AuthenticodeSignature | WSH TrustPolicy=0 -- signing cosmetic only; ThreatLocker is sole gate | PASS signing / WSH enforcement absent |
| .vbs | Authenticode (WSH) | Set-AuthenticodeSignature | Get-AuthenticodeSignature | WSH TrustPolicy=0; VBScript deprecated Win11 24H2 -- **Patrick Q4 pending** | PASS signing / low priority |
| .wsf | Authenticode (WSH) | Set-AuthenticodeSignature | Get-AuthenticodeSignature | Same as .vbs; XML-structured; remains valid XML after signing | PASS signing / very low priority |
| .py | Interpreter-mediated | N/A | Check python.exe cert | ThreatLocker gate on python.exe (approved per company_context) | PASS -- interpreter trust documented |
| .sh | Interpreter-mediated | N/A | Check bash.exe cert | ThreatLocker gate on bash.exe (Git Bash) | PASS -- interpreter trust documented |
| .js (Node.js) | Interpreter-mediated | N/A | Check node.exe cert | ThreatLocker gate on node.exe; distinct from WSH context | PASS -- interpreter trust documented |
| .bat / .cmd | Dead end | None | None | Hash allowlist only; high re-approval friction per edit | N/A -- convert to .ps1 |
| .jar | Interpreter-mediated (JVM) | N/A | N/A | Gate on java.exe; Authenticode requires .exe wrapper | Out of scope |

---

### Signing Command Reference

#### PowerShell and WSH Types (no signtool needed)

The Goodwin cert thumbprint lives in memory/company_context.md -- do not hardcode in scripts or articles.

Signing command (works for .ps1, .psm1, .psd1, .ps1xml, .cdxml, .js WSH, .vbs, .wsf):

    $cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert |
        Where-Object { $_.Thumbprint -eq "<GOODWIN_THUMBPRINT>" }

    Set-AuthenticodeSignature -FilePath "<target-file>" -Certificate $cert

    Get-AuthenticodeSignature -FilePath "<target-file>" | Select-Object Status, StatusMessage

Signature block delimiter by file type:

| File Type | Delimiter |
|-----------|-----------|
| .ps1 / .psm1 / .psd1 | # SIG # Begin signature block |
| .js (WSH) | // SIG // Begin signature block |
| .vbs | VBScript apostrophe-comment delimiter |
| .wsf | ** SIG ** Begin signature block (remains valid XML) |

#### PE and Installer Types (signtool.exe from Windows SDK -- NOT installed as of 2026-04-17)

Install: winget install Microsoft.WindowsSDK.10.0.26100

Command (thumbprint from memory/company_context.md):

    signtool sign /fd SHA256 /tr https://timestamp.digicert.com /td SHA256 /sha1 <THUMBPRINT> <target-file>
    signtool verify /pa /v <target-file>

---

### Known Gotchas

#### WSH TrustPolicy = 0 at Goodwin

Registry key HKLM\Software\Microsoft\Windows Script Host\Settings\TrustPolicy is **absent** on the endpoint (confirmed PoC W2R1). Absent value defaults to 0: WSH does **not** enforce signed-only execution. Signing .js, .vbs, or .wsf with Set-AuthenticodeSignature produces Status: Valid, but wscript.exe/cscript.exe run unsigned scripts identically to signed ones.

**Implication**: For WSH types, ThreatLocker is the **sole runtime enforcement gate**. Signing is still recommended for provenance and forward compatibility, but provides no current enforcement benefit.

**Patrick Q3 pending**: Is TrustPolicy=0 a deliberate Goodwin GPO, or can it be raised to 2 to enforce signed-only WSH execution?

#### Interpreter Certificate Expirations (as of 2026-04-17)

Windows reports Status: Valid for all three interpreter binaries via RFC 3161 timestamp countersignature chain. However:

| Binary | Signing Cert NotAfter | Timestamp Cert NotAfter | Risk | Action |
|--------|-----------------------|------------------------|------|--------|
| bash.exe (Git) | **2026-05-05** (~18 days out) | 2035-04-14 | HIGH | Plan winget upgrade for Git for Windows before that date |
| node.exe (Node.js) | 2026-03-26 EXPIRED | 2026-10-22 | Medium | winget upgrade OpenJS.NodeJS |
| python.exe (Python 3.12) | 2025-04-10 EXPIRED | 2025-11-19 EXPIRED | Medium | winget upgrade Python.Python.3.12 |

**Note on hash changes**: Each winget upgrade replaces the interpreter binary. If ThreatLocker allowlists by hash (not directory path), each upgrade may require a new ThreatLocker allowlist entry. Confirm with Patrick.

**Patrick Q5 pending**: Does ThreatLocker perform independent cert chain verification for interpreter publisher rules, or trust Windows Status=Valid verdict for expired-cert interpreters?

#### Blocked-Pending-SDK Types

.exe, .dll, .sys, .msi, .msix, .appx signing requires signtool.exe. Not installed as of 2026-04-17. .msi also requires WiX Toolset (not installed) to create sample files.

Install to unblock: winget install Microsoft.WindowsSDK.10.0.26100

Even after SDK install, ThreatLocker auto-approve scope for PE types is **unconfirmed** (Patrick Q1). Test in isolated context before production reliance.

#### .bat / .cmd -- No Signing Path

cmd.exe has no signing enforcement mechanism; signtool.exe does not support batch files. Only path-based or hash-based ThreatLocker policies are available. Hash policies require re-submission on every edit. Convert batch scripts in security tooling to .ps1.

---

### Recommended /trust-artifact Skill Branches

Five-branch dispatch pseudocode from W2R1 PoC results:

    Branch 1 -- PowerShell native (.ps1, .psm1, .psd1, .ps1xml, .cdxml, .pssc, .psrc):
      Set-AuthenticodeSignature with Goodwin cert
      Return PASS/FAIL based on Status

    Branch 2 -- PE and installer (.exe, .dll, .sys, .msi, .msix, .appx, .cab):
      Find signtool.exe (PATH, then Windows Kits path)
      If absent: BLOCKED with install instructions
      signtool sign /fd SHA256 /tr <ts-url> /td SHA256 /sha1 <thumbprint> <file>
      Warn: ThreatLocker auto-approve scope pending Patrick Q1
      Return PASS if signtool verify passes

    Branch 3 -- WSH script types (.js, .vbs, .wsf):
      Check HKLM TrustPolicy value
      If TrustPolicy != 2: emit WARNING (signing cosmetic only)
      Set-AuthenticodeSignature with Goodwin cert
      Return PASS with caveat note

    Branch 4 -- Interpreter-mediated (.py, .sh, .js Node, .cjs, .mjs):
      Locate interpreter binary
      Get-AuthenticodeSignature on interpreter binary
      Return INFO: no file-level signing; interpreter trust path only
      Surface cert expiry warnings if applicable

    Branch 5 -- Dead ends (.bat, .cmd):
      Return INFO: no signing mechanism; convert to .ps1 or hash-allowlist ThreatLocker

---

### Open Questions for {{team.manager.name}}

Send before launching full /trust-artifact skill implementation:

| # | Question | Blocks |
|---|----------|--------|
| Q1 | Does ThreatLocker auto-approve publisher rule extend from .ps1 to .exe/.dll/.msi? | PE/installer signing plan |
| Q2 | Does auto-approve cover .psm1/.psd1 alongside .ps1? | Module signing plan |
| Q3 | Is WSH TrustPolicy=0 a deliberate GPO, or can it be set to 2? | WSH enforcement value |
| Q4 | VBScript/WSF availability under Win11 24H2 deprecation -- permitted or blocked by Goodwin GPO? | WSH type priority |
| Q5 | Does ThreatLocker perform independent cert chain verification on interpreter binaries, or trust Windows Status=Valid verdict? | python.exe / node.exe risk |

---

### Current /sign-script Skill Gap (Immediate Fix Available)

The existing /sign-script skill blocks non-.ps1 files with an explicit extension guard. Relaxing this guard to also accept .psm1, .psd1, .ps1xml, .cdxml, .pssc, .psrc is a one-line change. All use the identical Set-AuthenticodeSignature invocation. No new tools or cert config needed. ThreatLocker confirmation for module files pending Patrick Q2, but signing mechanics are confirmed identical (PoC W2R1 PASS).

This unblocks PowerShell module signing before the full /trust-artifact generalization is complete.

---

## References

- /sign-script skill: .claude/commands/sign-script.md -- current .ps1-only implementation
- Research artifact (W1R1): hub/staging/2026-04-17-trust-workflow-expansion/wave-1/round-1/research-trust-matrix.md
- PoC artifact (W2R1): hub/staging/2026-04-17-trust-workflow-expansion/wave-2/round-1/poc-sign-per-type.md
- Microsoft Learn: SignTool: https://learn.microsoft.com/en-us/windows/win32/seccrypto/signtool (accessed 2026-04-17)
- Microsoft Learn: about_Signing: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_signing (accessed 2026-04-17)
- ThreatLocker -- Trusting by Certificate: https://threatlocker.kb.help/trusting-an-application-by-a-certificate/ (accessed 2026-04-17)
- Microsoft Learn: WSH code signing: https://learn.microsoft.com/en-us/archive/msdn-magazine/2001/april/windows-script-host-new-code-signing-features-protect-against-malicious-scripts (accessed 2026-04-17)
- Memory: company_context.md -- Goodwin AllSigned + ThreatLocker stack, {{team.manager.name}} auto-approve confirmation
- Memory: feedback_sign_before_test.md -- Trust gate rule: Build --> Sign --> Test --> Deploy

---

## Changelog

| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-17T19:31 | 2026-04-17-trust-workflow-expansion | documenter | Created initial KB article synthesizing W1 research + W2 PoC; per-type cheat-sheet, 5-branch skill pseudocode, WSH TrustPolicy gotcha, interpreter cert risk table, Patrick Q list |
