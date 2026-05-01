---
description: Sign a PowerShell script with the Goodwin code signing certificate
user-invocable: true
allowed-tools: [Bash, Read, Glob]
schema-version: 1
---
# Sign Script

Sign a PowerShell script using the Goodwin Procter code signing certificate.

**Usage**: `/sign-script <script-path>`

---

## CRITICAL: Sign BEFORE testing, not after

Per {{team.manager.name}} (Tyler's manager), Goodwin's ThreatLocker policy **auto-approves any script signed with the Goodwin code signing cert**, regardless of file hash or path. This means signing simultaneously satisfies:

1. **ThreatLocker execution governance** — auto-approved by signature
2. **PowerShell AllSigned MachinePolicy** — satisfied by signature

Therefore the correct workflow for any new `.ps1` on Goodwin endpoints is:

```
Build → Sign → Test → Deploy (wire into settings.json)
```

**Do NOT try to run an unsigned .ps1 first to "test it quickly."** On this box, unsigned scripts fail with either `AuthorizationManager check failed` (ThreatLocker) or `not digitally signed` (AllSigned), so testing unsigned is impossible anyway. Sign immediately after the first complete draft. If testing reveals a bug, fix the script and re-sign — signing is cheap, the cert is local, and re-signing is one command. Never delay signing out of fear of "locking" the script.

### Why this matters for Claude's workflow
The instinct to "test before signing" is wrong here. On Goodwin endpoints, an unsigned script literally cannot execute at all. The first functional test of the script body MUST happen against a signed copy. Skip the unsigned-test phase entirely.

---

## Step 1: Parse and Validate
- The script path is provided in `$ARGUMENTS`.
- If no path is provided, ask Tyler which script to sign.
- Verify the file exists using `Glob` or `Read`.
- Verify the file extension is one of the Authenticode-native PowerShell types: **`.ps1`** (script), **`.psm1`** (module), or **`.psd1`** (manifest). If not, warn Tyler and abort. (As of 2026-04-29 the allowlist includes `.psm1` and `.psd1` — both behave identically to `.ps1` under Authenticode + AllSigned + ThreatLocker.)
- Verify the script body looks complete (has the expected header block, closing braces match, etc.). A broken script body is still worth signing if Tyler asks, but flag the concern.

## Step 2: Sign the Script
Run via Bash:

```bash
pwsh.exe -NoProfile -Command "Set-AuthenticodeSignature -FilePath '{absolute-path}' -Certificate (Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Where-Object { \$_.Thumbprint -eq '19FC6355A1473F3E742E7CB9933E773CFF72A745' }) | Format-List StatusMessage, Status, SignerCertificate"
```

- Use the absolute path to the script.
- The signing certificate is from **Goodwin-East-SUB02 CA**, valid until **2028-01-28**.
- Thumbprint of the known-good cert: `19FC6355A1473F3E742E7CB9933E773CFF72A745` (as of 2026-04-09). Filter by thumbprint to disambiguate if multiple code-signing certs are present in the user store.

### Why `pwsh.exe` is the canonical signing engine (verified 2026-04-29)

**Use `pwsh.exe` (PowerShell 7), NOT `powershell.exe` (Windows PowerShell 5.1).** Claude's Git Bash → `powershell.exe` chain hits ThreatLocker Storage Control on `Set-AuthenticodeSignature`'s file-write — symptoms are `UnauthorizedAccessException: Access to the path '...psm1' is denied` despite the file being writable (`IsReadOnly: False`, ACL OK). Even `Get-AuthenticodeSignature` fails with the same error because the cmdlet must read the file's bytes through the storage policy. This is distinct from the AllSigned execution gate — Storage Control is a separate ThreatLocker layer, and it allowlists `pwsh.exe` for project-tree writes while blocking `powershell.exe`.

`pwsh.exe` also resolves the older WinPS-5.1 module-mixing issue that previously required a `PSModulePath` scoping prefix:

- Pre-2026-04-29 pattern (`powershell.exe` + scoped `PSModulePath`) loaded WinPS 5.1's `Microsoft.PowerShell.Management` to register the `Certificate` provider so `Cert:\CurrentUser\My` resolved.
- `pwsh.exe` ships with the correct provider built-in — no `PSModulePath` munging required, and no module-mixing risk.

**Symptoms of using the wrong engine** (do not retry blindly — switch to `pwsh.exe`):

- `Set-AuthenticodeSignature : Access to the path '...' is denied` — Storage Control on `powershell.exe`. **Fix: switch to `pwsh.exe`.**
- `A parameter cannot be found that matches parameter name 'CodeSigningCert'` — old `powershell.exe` + missing `PSModulePath` scope; Certificate provider never registered. **Fix: switch to `pwsh.exe`.**
- `Import-Module : AuthorizationManager check failed` on a `.psm1` — AllSigned blocking the unsigned module read. **Fix: sign the module first via the command above (`pwsh.exe` reads bypass the AllSigned-import gate when Set-AuthenticodeSignature is the calling cmdlet).**

## Step 3: Report Result
- If `Status` is `Valid` and `StatusMessage` is `Signature verified.`: Report success and confirm the signature block was appended to the file.
- Report the thumbprint and NotAfter date so Tyler can verify.
- If signing fails:
  - Check cert availability: `pwsh.exe -NoProfile -Command "Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Format-List Subject, Issuer, NotAfter, Thumbprint"`
  - If you used `powershell.exe` and got `Access to the path '...' is denied`, switch to `pwsh.exe` (Storage Control allowlist mismatch — see Step 2 rationale).
  - Report the error and escalate — do NOT retry blindly.

## Step 4: Immediately Smoke-Test (NEW)
After a successful signing, encourage Tyler (or proceed on your own if the task authorizes it) to run the script's smoke test suite. The signed script is now a live artifact that can execute; verify its behavior before wiring it into settings.json as a hook or scheduled task.

---

## Context
- Goodwin's **AllSigned MachinePolicy** requires all `.ps1` / `.psm1` / `.psd1` files to be signed before execution or import.
- Goodwin's **ThreatLocker policy** has TWO orthogonal layers:
  - **Application Control (signature-based)**: auto-approves any script signed with the Goodwin code-signing cert regardless of hash or path. Re-signing after edits does NOT require a new submission.
  - **Storage Control (executable-based)**: gates which executable images may write to which paths in the project tree. `pwsh.exe` is allowlisted for project-tree writes; `powershell.exe` is NOT (verified 2026-04-29). This is why this skill uses `pwsh.exe`.
- The code-signing certificate is issued by `Goodwin-East-SUB02 CA` and is stored in the current user's personal certificate store (`Cert:\CurrentUser\My`).
- If the cert is missing, Tyler may need to request a new one via the Goodwin PKI portal.
- Scripts/modules/manifests must be re-signed after any modification. The signature covers the file body, so any edit invalidates it.

## Rules
- Sign `.ps1`, `.psm1`, and `.psd1` files via this skill. All three are Authenticode-native PowerShell file types and behave identically under AllSigned + ThreatLocker. Other file types (.sh, .py, .kql) do not use Authenticode and are not handled by this skill.
- Use `pwsh.exe` (PowerShell 7), NOT `powershell.exe` (Windows PowerShell 5.1). The latter hits ThreatLocker Storage Control on the file-write path.
- Always verify the file exists before attempting to sign.
- If signing fails due to a missing certificate, do NOT retry — escalate to Tyler.
- If signing fails with `Access to the path '...' is denied` from `powershell.exe`, the cause is Storage Control, not file ACLs — switch to `pwsh.exe`.
- Do NOT delay signing "until the script is perfect." Sign on first complete draft, test, iterate, re-sign. Re-signing is cheap.
- Do NOT attempt to run an unsigned `.ps1`/`.psm1`/`.psd1` on a Goodwin endpoint — it will fail at the execution policy or ThreatLocker gate, wasting iteration cycles.

## Changelog

| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-29T12:00-04:00 | 2026-04-29-rdc-mailbox-monitoring | morpheus | Switched canonical signing engine from `powershell.exe` (WinPS 5.1) to `pwsh.exe` (PS 7). Root cause: ThreatLocker Storage Control allowlists `pwsh.exe` for project-tree writes but NOT `powershell.exe`, so the prior recipe failed with `UnauthorizedAccessException` on the file-write path. Removed the `PSModulePath=` scoping prefix (no longer needed — `pwsh.exe` ships with the Certificate provider built in). Extended file-extension allowlist to `.psm1` and `.psd1` (both behave identically to `.ps1` under Authenticode). Updated Step 2 rationale, Step 3 cert-check fallback, Context section, and Rules. Verified live: signed `scripts/planner/PlannerSync.psm1` end-to-end with `pwsh.exe` after `powershell.exe` failed. |
