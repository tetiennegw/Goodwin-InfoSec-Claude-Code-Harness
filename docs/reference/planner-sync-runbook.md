---
title: Planner Sync Troubleshooting Runbook
category: tools
tags: [planner, sync, troubleshooting, microsoft-graph]
created: 2026-04-16
last-updated: 2026-04-16
last-verified: 2026-04-16
review-interval: 90d
status: active
author: Morpheus
---

# Planner Sync Troubleshooting Runbook

## Summary

Troubleshooting guide for the `/sync-planner` two-way integration between Microsoft Planner and Morpheus's task state. Covers auth failures, pull/push issues, hook problems, and common error codes.

## Quick Diagnostics

### Check module health

```powershell
pwsh -Command "Import-Module scripts/planner/PlannerSync.psm1 -ErrorAction Stop; Write-Output 'OK'"
```

If this fails, verify the signature:

```powershell
pwsh -Command "Get-AuthenticodeSignature scripts/planner/PlannerSync.psm1 | Select-Object Status"
```

If not `Valid`, re-sign with `/sign-script scripts/planner/PlannerSync.psm1`.

### Check auth

```powershell
pwsh -Command "Import-Module scripts/planner/PlannerSync.psm1; Connect-PlannerGraph | Out-Null; Get-MgContext | Select-Object Account, TenantId, Scopes"
```

Expected: `{{user.email}}`, tenant `8bf42f52-...`, scopes include `Tasks.ReadWrite`.

### Check push queue

```bash
cat hub/state/planner-push-queue.json 2>/dev/null || echo "No pending pushes"
```

### Check pull cache freshness

```powershell
pwsh -Command "(Get-Content -Raw hub/state/planner-pull-cache.json | ConvertFrom-Json).generatedAt"
```

## Common Issues

### Auth: "Cannot connect to Microsoft Graph"

**Symptoms**: `Connect-PlannerGraph` throws or returns null context.

**Causes**:
1. Not on Goodwin network/VPN
2. Token expired (>24h since last interactive login)
3. Conditional access policy blocking

**Fix**: Ensure VPN is connected, then run `/sync-planner pull`. It will prompt for browser login. **Never use `-UseDeviceCode`** — blocked by Goodwin CA policy 530033.

### Auth: HTTP 401 during push

**Symptoms**: Push fails with 401 Unauthorized mid-queue-processing.

**Fix**: The module automatically calls `Connect-PlannerGraph` on 401, which re-prompts browser login. If this fails, manually disconnect and reconnect:

```powershell
pwsh -Command "Disconnect-MgGraph; Import-Module scripts/planner/PlannerSync.psm1; Connect-PlannerGraph"
```

### Pull: "0 tasks pulled"

**Symptoms**: `Invoke-PlannerPull` returns 0 tasks.

**Causes**:
1. `planner-mapping.json` has no valid planIds
2. Token lacks `Tasks.ReadWrite` scope
3. Network issue reaching Graph API

**Fix**:
```powershell
# Verify mapping has plans
pwsh -Command "(Get-Content -Raw hub/state/planner-mapping.json | ConvertFrom-Json).personal.planId"
# Should return a non-empty string like "_9ydI8b6bEi6IRynKFXILWUAEx_5"

# Test direct API call
pwsh -Command "Import-Module scripts/planner/PlannerSync.psm1; Connect-PlannerGraph | Out-Null; Invoke-MgGraphRequest -Method GET -Uri '/v1.0/me/planner/tasks' | Select-Object -ExpandProperty value | Measure-Object | Select-Object Count"
```

### Push: HTTP 412 Precondition Failed

**Symptoms**: Push returns 412 error.

**Explanation**: The task was modified in Planner since the last pull (stale ETag). The module handles this automatically with semantic 412 retry (AC17):
1. Re-GETs the task for fresh state + ETag
2. Three-way compares: oldValue (queue) vs remote vs newValue (queue)
3. If no same-field conflict, retries silently with new ETag
4. If same-field conflict detected, surfaces via AskUserQuestion

**If retry fails after 3 attempts**: Run `/sync-planner pull` first to refresh local state, then retry the push.

### Push: HTTP 404 Not Found

**Symptoms**: Push returns 404 for a specific task.

**Explanation**: The task was deleted from Planner. The skill surfaces this via AskUserQuestion with options to "Remove from queue" or "Skip for now". Recreating a task requires `/task-list-management`.

### Push queue: Entries keep accumulating

**Symptoms**: `planner-push-queue.json` grows large.

**Fix**: Run `/sync-planner push` to review and approve/skip entries. To clear the entire queue:

```powershell
pwsh -Command "Import-Module scripts/planner/PlannerSync.psm1; Clear-PlannerPushQueue -Path hub/state/planner-push-queue.json"
```

### Hook: Push-queue writer not firing

**Symptoms**: Editing STATE.md doesn't create queue entries.

**Causes**:
1. Hook added mid-session (hooks from `settings.local.json` load at session start only)
2. Frontmatter hash unchanged (no actual field value changes)

**Fix**: Start a new Claude Code session. The hook will be active from session start. For testing, run manually:

```bash
echo '{"tool_name":"Edit","tool_input":{"file_path":"hub/staging/{task-id}/STATE.md"}}' | bash .claude/hooks/planner-push-queue-writer.sh
```

### Hook: PowerShell errors in push-queue writer

**Symptoms**: Queue file not written, no error visible (hook is fail-open).

**Debug**: Run with bash trace:

```bash
echo '{"tool_name":"Edit","tool_input":{"file_path":"hub/staging/{task-id}/STATE.md"}}' | bash -x .claude/hooks/planner-push-queue-writer.sh 2>&1
```

**Common cause**: ThreatLocker blocks `powershell.exe` from writing to project paths. The hook uses PowerShell only for JSON generation (stdout), then bash writes the file. If this pattern breaks, check ThreatLocker approval status.

### Signature: "Module not loaded because no valid module file was found"

**Symptoms**: `Import-Module` fails with AllSigned policy violation.

**Fix**: Re-sign the module:

```bash
# Copy to temp, sign, copy back (ThreatLocker workflow)
cp scripts/planner/PlannerSync.psm1 {{paths.home}}/AppData/Local/Temp/planner-sign/
pwsh -Command "Set-AuthenticodeSignature -FilePath '{{paths.home}}\AppData\Local\Temp\planner-sign\PlannerSync.psm1' -Certificate (Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Select-Object -First 1)"
cp {{paths.home}}/AppData/Local/Temp/planner-sign/PlannerSync.psm1 scripts/planner/
```

Or use `/sign-script scripts/planner/PlannerSync.psm1`.

### DryRun: Pushes report success but nothing reaches Planner

**Symptoms**: Push "succeeds" but Planner boards don't update.

**Explanation**: DryRun mode is active by default. Check `hub/state/planner-ids.json` for `productionApproved: true`. If absent or false, all pushes are simulated.

**To enable live pushes**: Edit `hub/state/planner-ids.json` and set `"productionApproved": true`. This is a safety gate — never enable on production boards during development.

### First-Time Push: `planner-ids.json` bootstrap

**Symptoms**: File `hub/state/planner-ids.json` does not exist. `Invoke-PlannerPush` can't find the `personalPlannerTaskId` mapping and skips with no effect.

**Explanation**: `planner-ids.json` is created lazily — `Set-PlannerIdMapping` only writes it after the first successful PATCH records an ETag. For the first push against a brand-new task, there is no pre-existing mapping, so you must seed it manually.

**Minimum seed file**:
```json
{
  "productionApproved": false,
  "mappings": {
    "<your-morpheus-task-id>": {
      "plannerTaskId": "",
      "personalPlannerTaskId": "<plannerTaskId-from-pull-cache>",
      "lastEtag": "",
      "personalLastEtag": "",
      "lastSynced": ""
    }
  }
}
```

The `taskId` key must match the `taskId` field in the push queue entry. Flip `productionApproved: true` only when ready for live writes.

### 412 on every first push (expected, not a bug)

**Symptoms**: First live PATCH returns HTTP 412, then attempt 2 succeeds. `retries: 1` in the result.

**Explanation**: Microsoft Graph Planner requires an `If-Match` header with the task's ETag on every PATCH. On the very first push the ETag is empty (pull cache does not store ETags), so the server returns 412. The retry handler in `Invoke-PlannerPatchWithRetry` re-GETs to fetch the fresh ETag and retries with it — that second attempt succeeds. This is working as designed.

**How to tell it's the "expected 412"**: `result.success = $true`, `result.retries = 1`, `result.conflicts.Count = 0`. If conflicts is non-zero, it's a real merge conflict, not this bootstrap path.

### Verifying a push landed on Planner

Three options, pick whichever is fastest:

1. **Web UI**: https://tasks.office.com/ → relevant plan → find the task; status dot/percentage should reflect the change.
2. **Microsoft 365 Planner**: https://planner.cloud.microsoft/webui/plan/{planId}
3. **pwsh GET**:
   ```powershell
   pwsh -Command "Import-Module ./scripts/planner/PlannerSync.psm1; `$null = Connect-PlannerGraph; `$r = Invoke-MgGraphRequest -Method GET -Uri '/v1.0/planner/tasks/{plannerTaskId}'; Write-Host ('percentComplete: ' + `$r['percentComplete'])"
   ```

## Architecture Quick Reference

| Component | Path | Purpose |
|-----------|------|---------|
| Core module | `scripts/planner/PlannerSync.psm1` | Auth, routing, pull, push, conflict, queue |
| Module manifest | `scripts/planner/PlannerSync.psd1` | Module metadata |
| Mapping | `hub/state/planner-mapping.json` | Plan/group/bucket/routing config |
| ID registry | `hub/state/planner-ids.json` | Task ID mapping + ETags |
| Pull cache | `hub/state/planner-pull-cache.json` | Last-pulled Planner state |
| Push queue | `hub/state/planner-push-queue.json` | Pending pushes awaiting approval |
| Skill | `.claude/commands/sync-planner.md` | Interactive /sync-planner command |
| Hook | `.claude/hooks/planner-push-queue-writer.sh` | Auto-detects STATE.md changes |
| Tests | `tests/planner/Test-*.Tests.ps1` | 7 Pester v5 test files (53 tests) |

## References

- [ref:tools:planner-sync-module](../../scripts/planner/PlannerSync.psm1)
- Microsoft Graph Planner API: `/v1.0/planner/tasks/{id}`
- Goodwin CA policy 530033: blocks `-UseDeviceCode` flow

## Changelog

| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-17T09:45 | 2026-04-17-planner-push-test | morpheus | Added first-time push bootstrap section, expected-412 guidance, and verification steps after E2E live push test |
| 2026-04-16T06:46 | 2026-04-15-planner-integration | orchestrator | Created initial runbook (T5.2) |
