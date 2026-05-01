---
description: Two-way sync between Microsoft Planner and Morpheus task state. Pull tasks from 9+ boards, push STATE.md changes with approval, or create a brand-new task on the personal board.
user-invocable: true
argument-hint: (optional) pull | push | create | (no arg = both)
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion, Agent]
schema-version: 1
---
# /sync-planner

Two-way sync between Microsoft Planner and Morpheus local task state. Pull reads tasks from all mapped boards into `hub/state/planner-pull-cache.json` and reconciles conflicts interactively. Push reads `hub/state/planner-push-queue.json`, coalesces same-task entries, presents each to Tyler for approval, then dual-writes approved entries to both the personal board and the relevant project board.

## When to invoke

- **Manual**: Tyler types `/sync-planner`, `/sync-planner pull`, or `/sync-planner push`.
- **Session start**: `prompt-context-loader.sh` triggers a pull-only run at the start of each session if the pull cache is stale (older than 5 minutes).
- **Push queue non-empty**: `prompt-context-loader.sh` injects a notice whenever `hub/state/planner-push-queue.json` contains un-pushed entries. Tyler then decides whether to `/sync-planner push` now.

## Prerequisites

- `pwsh` (PowerShell 7+) available in PATH
- `scripts/planner/PlannerSync.psm1` and `PlannerSync.psd1` exist and are signed Valid
- `hub/state/planner-mapping.json` exists (built by T1.3 board inventory)
- `hub/state/planner-ids.json` exists (created on first push; may be absent on fresh install)
- Microsoft.Graph.Planner module installed: `Get-Module -ListAvailable Microsoft.Graph.Planner`
- Active Graph session (WAM browser login -- NOT -UseDeviceCode, blocked by CA policy 530033)

## Module path convention

**ALWAYS prefix the module path with `./` in `pwsh -Command` blocks.**

When `pwsh -Command "Import-Module ./scripts/planner/PlannerSync.psm1"` is invoked from the Bash tool, PowerShell's Import-Module sometimes fails with "no valid module file was found in any module directory" — it treats ambiguous relative paths as module-name lookups against `$env:PSModulePath`. Observed failure 2026-04-21 14:19 during `/sync-planner create`; recovered by switching to the absolute Windows path on retry.

The robust fix is to prefix `./` so Import-Module unambiguously resolves the path against the current working directory (which is always the repo root under the Bash tool):

```powershell
Import-Module ./scripts/planner/PlannerSync.psm1
```

If `./` still fails in a given context (e.g., a non-repo-root CWD), fall back to the absolute path:

```powershell
Import-Module '{{paths.home}}\Documents\TE GW Brain\scripts\planner\PlannerSync.psm1'
```

Every `pwsh -Command` example in this skill uses the `./scripts/planner/PlannerSync.psm1` form. Do not strip the `./` when copying these into new blocks.

## Module availability check

Before any step, verify the module is importable:

```bash
pwsh -Command "Import-Module ./scripts/planner/PlannerSync.psm1 -ErrorAction Stop; Write-Output OK"
```

If this fails:
- Output: `PlannerSync module not importable. Check scripts/planner/PlannerSync.psm1 exists and is signed.`
- Verify signature: `pwsh -Command "Get-AuthenticodeSignature scripts/planner/PlannerSync.psm1 | Select-Object -ExpandProperty Status"`
- If not Valid: direct Tyler to run `/sign-script` for both `PlannerSync.psm1` and `PlannerSync.psd1`.
- Do not proceed until the module loads cleanly.

## Mode routing

| Invocation | Behaviour |
|---|---|
| `/sync-planner` | Run pull first, then check push queue; if queue non-empty, run push flow |
| `/sync-planner pull` | Pull only |
| `/sync-planner push` | Push only |
| `/sync-planner create` | Create a new task on the personal board ("{{user.name}}'s Work"). Interactive flow — fields collected via AskUserQuestion. Auto-logs to today's daily note. |

Parse the argument from the first word following `/sync-planner`. Anything other than `pull`, `push`, or `create` (including no argument) is treated as pull+push.

---

## Pull steps

### Pull Step 1 -- Ensure auth

```bash
pwsh -Command "Import-Module ./scripts/planner/PlannerSync.psm1; Connect-PlannerGraph | Out-Null"
```

**Auth failure handling (401 or null context)**:

1. Present via AskUserQuestion:
   - Question: "Graph session expired or missing. A browser login window will open. Proceed?"
   - Options: "Open browser now" / "Cancel sync"
2. If "Cancel sync": output `Sync cancelled -- auth not established.` and exit.
3. If "Open browser now": re-run `Connect-PlannerGraph`. On second failure, output: `Auth failed after retry. Check VPN/network and try again.` and exit.

**Network failure** (cannot reach `graph.microsoft.com`):
- Output: `Cannot reach Microsoft Graph API. Are you on the Goodwin network or VPN? Resolve connectivity and retry.`
- Exit gracefully without continuing.

### Pull Step 2 -- Pull all tasks

```bash
pwsh -Command "Import-Module ./scripts/planner/PlannerSync.psm1; `$null = Connect-PlannerGraph; Invoke-PlannerPull -MappingPath hub/state/planner-mapping.json -All | Out-Null"
```

This writes `hub/state/planner-pull-cache.json`. Verify the file exists and taskCount is greater than 0:

```bash
pwsh -Command "(Get-Content -Raw hub/state/planner-pull-cache.json | ConvertFrom-Json).taskCount"
```

If taskCount is 0 or the file is absent: output `Pull returned 0 tasks. Verify planner-mapping.json is populated and the Graph session has Tasks.ReadWrite scope.`

### Pull Step 3 -- Detect conflicts

```bash
pwsh -Command "
  Import-Module ./scripts/planner/PlannerSync.psm1
  `$cacheObj = Get-Content -Raw hub/state/planner-pull-cache.json | ConvertFrom-Json -AsHashtable
  `$plannerTasks = `$cacheObj.tasks
  `$localTasks = @{}
  Compare-PlannerState -PlannerTasks `$plannerTasks -LocalTasks `$localTasks `
    -PushQueuePath hub/state/planner-push-queue.json | ConvertTo-Json -Depth 5
"
```

`Compare-PlannerState` is push-queue-aware (AC20): fields already in the push queue are automatically skipped to prevent overwriting pending local changes.

If no conflicts are returned: output `Pull complete -- no conflicts detected.` and proceed to Pull Step 5.

### Pull Step 4 -- Resolve conflicts via AskUserQuestion

For each conflict object, present one question. Process conflicts sequentially -- never batch:

```
Question: "Conflict on task '{taskId}' field '{field}':
  Planner says: '{plannerValue}'
  Morpheus says: '{localValue}'
  Which wins?"
Options:
  - "Planner wins"  -- description: "Accept Planner value, overwrite local"
  - "Morpheus wins"  -- description: "Keep local value; push it back on next sync"
  - "Skip"          -- description: "Leave both unchanged for now"
```

- **Planner wins**: update the local representation in `planner-pull-cache.json` and, if the task maps to an active STATE.md, update the relevant field there.
- **Morpheus wins**: no local change. Add this field to the push queue so the local value will be sent to Planner on the next approved push.
- **Skip**: no action.

### Pull Step 5 -- Log pull to daily note

Prepend a timeline entry following `.claude/rules/daily-note.md` Prepend Protocol:

```markdown
- **HH:MM AM/PM** - **Planner Pull Complete** #planner #sync

  **Work Type**: Planner Sync -- Pull

  **Implementation Results**:
  - N tasks pulled across M boards
  - K conflicts detected; breakdown: X Planner-wins / Y Morpheus-wins / Z skipped

  **Strategic Value**: Keeps Morpheus local task state aligned with Planner board reality. Push-queue-aware reconciliation ensures pending local changes are never silently overwritten during pull.
```

---

## Push steps

### Push Step 1 -- Read the push queue

```bash
pwsh -Command "Import-Module ./scripts/planner/PlannerSync.psm1; Read-PlannerPushQueue -Path hub/state/planner-push-queue.json | ConvertTo-Json -Depth 5"
```

If the queue file does not exist or returns an empty array:
- Output: `No pending pushes.`
- Exit the push flow (or finish cleanly if in both-mode).

### Push Step 2 -- Coalesce same-task entries

```bash
pwsh -Command "Import-Module ./scripts/planner/PlannerSync.psm1; Merge-PlannerPushQueue -Path hub/state/planner-push-queue.json | ConvertTo-Json -Depth 10"
```

`Merge-PlannerPushQueue` groups multiple field-level changes for the same task into a single compound entry, reducing API round-trips and approval prompts (AC19). Work from the returned coalesced array for the rest of the push flow.

### Push Step 3 -- Approval loop

For each coalesced entry, build a human-readable change summary before presenting AskUserQuestion. Never batch approvals -- present one prompt per entry.

**Single-field entry**: `{field}: '{oldValue}' -> '{newValue}'`

**Compound entry** (multiple fields): iterate `entry.fields` and list one line per field.

Present:

```
Question: "Push to Planner?
Task: {taskId}
Planner task ID: {plannerTaskId}
Changes:
{field-list}"
Options:
  - "Push now"            -- description: "Dual-write to personal board + project board (personal only if no route match)"
  - "Skip"                -- description: "Leave this entry in queue; advance to next"
  - "Skip all remaining"  -- description: "Exit push flow now; all remaining entries stay queued"
```

- **"Skip all remaining"**: break the loop immediately. Output a summary of what was pushed and what remains.
- **"Skip"**: advance to the next entry without pushing.
- **"Push now"**: execute Push Step 4 for this entry.

**DryRun gate**: Check `hub/state/planner-ids.json` for `productionApproved: true`. If absent or false, append `-DryRun` to `Invoke-PlannerPush` and output: `DryRun mode active -- no writes sent to Planner. Set productionApproved: true in planner-ids.json to enable live pushes.`

### Push Step 4 -- Execute push

Serialize the coalesced entry to JSON and pass it to `Invoke-PlannerPush`. Always import the module fresh in each `pwsh -Command` invocation -- module state does not persist between calls:

```bash
pwsh -Command "
  Import-Module ./scripts/planner/PlannerSync.psm1
  `$null = Connect-PlannerGraph
  `$entryJson = '<entry-json-string>'
  `$entry = `$entryJson | ConvertFrom-Json -AsHashtable
  `$result = Invoke-PlannerPush -QueueEntry `$entry `
    -IdsPath hub/state/planner-ids.json `
    -MappingPath hub/state/planner-mapping.json
  `$result | ConvertTo-Json -Depth 5
"
```

**On success** (`result.success -eq $true`):
1. Remove entry from queue:
   ```bash
   pwsh -Command "Import-Module ./scripts/planner/PlannerSync.psm1; Remove-PlannerPushQueueEntry -Path hub/state/planner-push-queue.json -EntryId '{entry.entryId}'"
   ```
2. Record in Push Step 5.

**On 412 (ETag conflict)**:
- `Invoke-PlannerPush` handles three-way merge and retry internally (AC17). A successful retry returns `success: true, retries > 0`. No skill-level action needed.
- If `result.success -eq $false` after internal retries: present via AskUserQuestion -- "Push failed for task '{taskId}' after ETag retry. Retry once more or skip?" Options: "Retry once more" / "Skip and keep in queue".

**On 404 (task deleted from Planner)**:
- `result.success -eq $false` with a 404 indicator in the error message.
- Present via AskUserQuestion: "Task '{taskId}' no longer exists in Planner (404). What should we do?"
  - Options: "Remove from queue" / "Skip for now"
  - "Remove from queue": call `Remove-PlannerPushQueueEntry` and continue.
  - "Skip for now": leave in queue and continue.
  - Note: Recreating a Planner task requires `/task-list-management` -- out of scope for this skill.

**On any other error**:
- Output the error message and the result JSON.
- Leave the entry in the queue.
- Continue to the next entry.

### Push Step 5 -- Log push to daily note

Prepend a timeline entry following `.claude/rules/daily-note.md` Prepend Protocol:

```markdown
- **HH:MM AM/PM** - **Planner Push Complete** #planner #sync

  **Work Type**: Planner Sync -- Push

  **Implementation Results**:
  - N entries pushed (dual-write: personal board + project board)
  - M entries skipped or remaining in queue
  - K 412 retries handled internally; J 404s resolved

  **Strategic Value**: Propagates approved STATE.md changes to Planner boards, keeping team-visible task state current. Approval gate ensures no unreviewed local changes reach production Planner boards.
```

---

## Create steps

Used when Tyler invokes `/sync-planner create`. Creates a brand-new task on his personal Planner board ("{{user.name}}'s Work") via `New-PlannerTask` — a first-class harness function that handles auth, field validation, task creation, details patching (description + checklist), board-card preview setup, sectioned-markdown summary rendering, and auto-logging to today's daily note.

### Create Step 1 -- Ensure auth

Same as Pull Step 1. Run `Connect-PlannerGraph`. Do not proceed without an active session.

### Create Step 2 -- Collect fields via AskUserQuestion

Tyler will never type fields as positional args in v1 — the skill is AskUserQuestion-driven end-to-end. Collect the following, in order (one `AskUserQuestion` call per field, or batch 2-4 per call where the question types allow):

| Field | Question | Options |
|-------|----------|---------|
| Title | "What's the task title?" | Free-text via "Other" option (or skip the question chip by phrasing as "enter a title") |
| Bucket | "Which PMBOK bucket?" | Initiating / Planning / Executing / Monitoring and controlling / Closing (read names + IDs from `mapping.personal.buckets`) |
| Priority | "Priority?" | Urgent (1) / Important (3) / Medium (5) / Low (9) |
| Percent complete | "Starting percent complete?" | 0% (Not started) / 25% / 50% / 100% (Done) |
| Due date | "Due date?" | Today / Tomorrow / Monday / No due date / Custom (Other) |
| Checklist | "Checklist items (one per line)?" | Free-text via "Other"; empty means no checklist |
| Pre-check checklist | Skip this question entirely if checklist is empty. Otherwise: "Are all checklist items already done (retrospective task)?" | Yes, pre-check all / No, leave unchecked (default for forward-looking) |
| Description | "Add a description?" | Yes (enter via Other) / No, skip |

Store the collected values in a hashtable. Do NOT execute the create yet.

### Create Step 3 -- Confirm preview

Build a preview using the canonical summary template (reuse `Format-PlannerTaskCreatedSummary` if importable, otherwise render inline). Present via a single `AskUserQuestion`:

```
Question: "Create this task on {{user.name}}'s Work?"
<preview block>
Options:
  - "Create now"     -- description: "Create the task and log to daily note"
  - "Edit fields"    -- description: "Restart Create Step 2 with current values as defaults"
  - "Cancel"         -- description: "Abort — nothing is written"
```

### Create Step 4 -- Execute

Call `New-PlannerTask` with the collected parameters. Do NOT add a separate daily-note logging step — `New-PlannerTask` auto-logs to today's daily note via its internal `Write-PlannerTaskCreatedLogEntry` helper. Adding a second log step would produce duplicate entries. The ONLY time to skip the function's auto-log is during internal tests with `-SkipDailyNoteLog`; never skip during user-initiated create flows.

```bash
pwsh -Command "
  Import-Module ./scripts/planner/PlannerSync.psm1
  \$null = Connect-PlannerGraph
  \$params = @{
    Title           = '<title>'
    BucketId        = '<bucket-guid>'
    Priority        = <int>
    PercentComplete = <int>
    # DueDateTime omitted if user chose 'No due date'
    # Description / Checklist added if collected
    # PreCheckChecklist = \$true if retrospective
  }
  \$result = New-PlannerTask @params
  \$result.summaryMarkdown
"
```

On success, report `$result.summaryMarkdown` back to Tyler verbatim. On failure (`$result.success -eq $false`), report `$result.reason` + any `orphanTaskId` for manual cleanup investigation.

### Create Step 5 -- Summary output line

Include the task-creation row in the final Summary output (see next section). Do NOT re-log to the daily note — Create Step 4 already did.

---

## Summary output

At the end of any run, output:

```
SYNC SUMMARY (YYYY-MM-DD HH:MM)
================================
Mode:              pull | push | create | both
Pull:              N tasks pulled / K conflicts (X Planner-wins / Y Morpheus-wins / Z skipped)
Push:              N pushed / M skipped / K remaining in queue
Task:              created | failed | cancelled    (create mode only)
Task URL:          <url or n/a>                    (create mode only)
DryRun:            yes | no
```

For `create` mode, also emit the canonical sectioned-markdown block verbatim — this is the Tyler-approved template rendered by `Format-PlannerTaskCreatedSummary`:

```markdown
### Planner Task Created
**Board:** {board title}

**Configuration**
- Bucket: {bucket name}
- Priority: {priority label} ({priority int})
- % Complete: {percentComplete}
- Due: {YYYY-MM-DD or "none"}

**Content**
- Title: {title}
- Description: {N chars or "(none)"}
- Checklist: {N items (K pre-checked) or "(none)"}

**Link**
- {task URL}
```

This block is produced automatically by `$result.summaryMarkdown` — just emit it as-is.

---

## API vs UI capability matrix (personal board)

Confirmed via systematic probe run 2026-04-20 against "{{user.name}}'s Work" (17 operations tested, test task created + deleted). Scope: personal board; group/project boards may differ and haven't been probed yet.

### ✅ API writable — harness can drive directly

| Field / operation | Confirmed via |
|-------------------|---------------|
| Task CRUD (title, priority, percentComplete, bucketId, dueDateTime) | Standard `Update-MgPlannerTask` with If-Match |
| Priority out-of-band ints (e.g., 7) | Graph persists any 1–10 int; UI rounds display to 1/3/5/9 |
| `appliedCategories` (label flags category1..category25) | Raw PATCH or Update-MgPlannerTask |
| `assignments` (assignees by userId) | PATCH with `{ userId: { '@odata.type': '#microsoft.graph.plannerAssignment'; orderHint: ' !' } }` |
| `references` (external URL attachments) | Details PATCH with URL-encoded key + `plannerExternalReference` schema |
| PercentComplete=100 auto-completion | Server fills `completedDateTime` + `completedBy` automatically; reversing with <100 clears them |
| **Plan `categoryDescriptions` (label names)** | GET/PATCH `/planner/plans/{planId}/details`; personal-board writable — Tyler's `category13='Incident Response'` already set this way |
| Create new bucket | `POST /planner/buckets` with `{ planId, name, orderHint }` |
| Delete bucket | DELETE with If-Match |
| Checklist items (add, title, isChecked, orderHint) | Details PATCH; **orderHint MUST start with whitespace** (e.g., `' 0001!'`, not `'0001!'`) |

### ❌ API rejected on personal board — UI-only

| Field / operation | Service response |
|-------------------|------------------|
| **`previewType` PATCH** (on CREATE or UPDATE) | 400 "This field cannot be modified" — confirmed 4× across sessions, including raw PATCH. UI path (Show on card toggle) works. |
| Direct `completedDateTime` write | 400 — server-managed; use PercentComplete=100 instead |
| Create new plannerPlan without groupId | 400 — personal plans require a Microsoft 365 Group owner |

### 📄 UI-only (no meaningful API surface)

- Templates, Copilot summaries, Schedule/Timeline/Chart views, "My Tasks" personal filters — all client-side rendering
- File attachment upload (the SharePoint half). The `reference` write half IS API-capable; the upload half needs Graph Files API separately
- Task comments thread — personal plans have no `conversationThreadId` (confirmed null); group plans route to Teams/Groups channel API (separate scope)

---

## Rules

- **NEVER push without a "Push now" answer from AskUserQuestion.** Auto-pushing is a protocol violation regardless of queue state.
- **Never use `-UseDeviceCode`** -- blocked by Goodwin CA policy 530033. WAM browser auth only.
- **Always import the module fresh** in each `pwsh -Command` invocation -- module state does not persist between calls.
- **Use `pwsh` not `powershell.exe`** -- module and Pester v5 require PowerShell 7+.
- **DryRun by default** until `productionApproved: true` is present in `planner-ids.json`.
- **Log every run to the daily note** -- both pull and push produce required timeline entries.
- **Conflicts resolved sequentially** -- never present more than one AskUserQuestion at a time.
- **Push-queue-aware pull** -- `Compare-PlannerState` skips fields covered by pending push entries; do not replicate this logic manually.
- **NEVER create without a "Create now" answer from AskUserQuestion.** Same approval gate as push. The preview shown in Create Step 3 is the gate; acting on any other answer is a protocol violation.
- **Checklists always attempt `previewType='checklist'`.** Any task created via `New-PlannerTask` with a non-empty `Checklist` attempts to PATCH `previewType='checklist'` post-create so items render on the board card. **Known API limitation:** Graph rejects this on personal boards with "This field cannot be modified (Parameter 'PreviewType')" — confirmed via raw `Invoke-MgGraphRequest` probe 2026-04-18, so it's a service-layer restriction, not an SDK quirk. Planner's `'automatic'` fallback usually renders the checklist preview on the card anyway. The attempt remains mandatory so the harness intent is explicit; a future service update or non-personal board may make it stick.
- **Single source of truth for Create-mode logging.** `New-PlannerTask` auto-logs to today's daily note via its internal `Write-PlannerTaskCreatedLogEntry` helper. Create Step 4 MUST NOT add a separate log step. Only use `-SkipDailyNoteLog` during internal tests, never during a user-initiated create.
- **Default board is personal.** If Tyler does not pass `-PlanId`, `New-PlannerTask` uses `mapping.personal.planId` ("{{user.name}}'s Work"). When Tyler says "my plan", that's the board — never disambiguate.
- **Always use `./scripts/planner/PlannerSync.psm1` in `pwsh -Command` imports.** The bare relative path `scripts/planner/PlannerSync.psm1` sometimes triggers Import-Module's module-name lookup against `$env:PSModulePath` and fails with "no valid module file was found." See § Module path convention.
- **Bucket ≠ PercentComplete.** Buckets on the personal board represent PMBOK lifecycle stages (Initiating / Planning / Executing / Monitoring and controlling / Closing) — not completion state. A task in *Closing* can legitimately be at 60% while the closing work (writeup, handoff, retrospective) is in progress. When creating or updating a task, **never implicitly set `PercentComplete=100` just because the target bucket is `Closing`**, and never infer a bucket transition just because PercentComplete crossed a threshold. Always ask Tyler explicitly, or take the two values from separate user signals. The `create` flow's preview must show bucket and PercentComplete as independent fields and never auto-derive one from the other. For completed ad-hoc logging tasks (like an already-finished Q&A), the correct configuration is typically *Closing + 100%*, but that must be a deliberate choice captured in the field collection, not a default side-effect of selecting *Closing*.

---

## Changelog

| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-21T14:25 | 2026-04-21-sync-planner-path-fix | main-session | Added `## Module path convention` section + Rules entry after observed Import-Module failure during `/sync-planner create` (relative `scripts/planner/PlannerSync.psm1` fell through to PSModulePath lookup). Updated all 9 `pwsh -Command` examples to use `./scripts/planner/PlannerSync.psm1`. |
| 2026-04-20T16:52 | 2026-04-20-planner-api-probe | main-session | Added `## API vs UI capability matrix` section reflecting 2026-04-20 probe run (17 operations tested). New ✅ writable rows: appliedCategories, assignments, references, plan.categoryDescriptions, create/delete bucket, PercentComplete auto-complete. New ❌ rejected rows: previewType (re-confirmed), completedDateTime direct, create plan without groupId. Documented checklist orderHint whitespace requirement after catching a silent-failure bug in New-PlannerTask. |
| 2026-04-18T00:35 | 2026-04-17-planner-task-create-harness | main-session | Added `## Create steps` section (5 substeps) + `create` mode routing row + TASK CREATED lines to Summary output (including sectioned-markdown template) + 4 new Rules (approval gate for create, checklist-on-card harness default, single-source logging, personal-board default). |
| 2026-04-15T21:35 | 2026-04-15-planner-integration | builder | Created /sync-planner skill definition (T4.1) |
