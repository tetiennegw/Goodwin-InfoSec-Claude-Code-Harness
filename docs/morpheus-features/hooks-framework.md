---
title: Hooks Framework
category: morpheus-feature
tags: [hooks, architecture, automation]
created: 2026-04-17
last-updated: 2026-04-17
last-verified: 2026-04-17
review-interval: 90d
status: active
audience: Tyler (current), Goodwin security team (future open-source)
owner: {{user.name}}
related-runbook: none
related-state: none
absorbs-hooks: [prompt-context-loader.sh, update-index.sh, task-compliance-check.sh, plan-mode-context.sh, daily-note-check.*, daily-note-watch.sh, prepend-reminder.sh, ensure-note.sh, planner-push-queue-writer.sh, feature-change-detector.sh, skill-assessor.sh, health-check.sh]
---

# Hooks Framework

> **Event-driven automation layer — Claude Code harness fires hooks at lifecycle events (SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, Stop); Morpheus uses hooks for auto-indexing, note management, queue writers, and detectors.**

## Overview

**What it is**: The passive automation layer that keeps derived state (INDEX.md, active-tasks.md), notes (daily note), and signals (Planner push queue, feature doc debt) in sync without requiring the main Morpheus session to remember any of it. Mechanically, hooks are shell or PowerShell scripts that the Claude Code harness invokes at six lifecycle events: `InstructionsLoaded`, `SessionStart`, `UserPromptSubmit`, `PreToolUse` (with matchers for specific tools), `PostToolUse` (likewise), and `Stop`. Morpheus ships twelve hooks covering note scaffolding, skill evaluation, approval reactions, derived-state regeneration, signal injection, and gate enforcement.

**Why it exists**: Derived state drifts without automation. INDEX.md, `hub/state/active-tasks.md`, daily note anchors, and the Planner push queue would all diverge from reality within minutes if their updates depended on the LLM remembering to refresh them. Hooks eliminate that class of drift by running mechanically at every tool call and lifecycle event. They also enforce Execution Gates (Gate 1: scaffold before work, Gate 4: daily note logging is immediate) more reliably than prose rules — `task-compliance-check.sh` on Stop will surface an orphaned task even when the main session forgot; `daily-note-check.ps1` on Stop flags missing EOD entries.

**Who uses it**: Every Morpheus session — hooks fire invisibly on every tool use. Skill authors add new hooks by writing a script (`.claude/hooks/`), registering it in `.claude/settings.local.json`, and signing the script if it's PowerShell. Tyler directly edits `settings.local.json` to change matchers or timeouts. The Claude Code harness invokes hooks; Morpheus never invokes them directly.

**Status**: `active` — 12 hooks in production; framework stable since initial Morpheus build (2026-03-30).

## Architecture

Claude Code fires hooks at specific lifecycle events; Morpheus uses them as the passive automation layer that keeps derived state (INDEX.md, active-tasks.md), notes (daily note), and signals (push queue, feature doc debt) in sync without asking the main session to remember. All hook registrations live in `.claude/settings.local.json`. Scripts live under `.claude/hooks/` (bash `.sh` preferred; PowerShell `.ps1` when native tooling requires it — notably `daily-note-check.ps1`, which needs PS to walk the notes dir natively on Windows).

### Hook event taxonomy

```mermaid
flowchart TB
  subgraph Events["Claude Code lifecycle events"]
    IL[InstructionsLoaded]
    SS[SessionStart]
    UPS[UserPromptSubmit]
    PRE[PreToolUse<br/>matcher: EnterPlanMode / Edit|Write|MultiEdit]
    POST[PostToolUse<br/>matcher: Write / Edit|Write]
    STOP[Stop]
  end

  subgraph Morpheus["Morpheus hooks"]
    IL --> IL_HOOK[INDEX.md cat]
    SS --> SS1[ensure-note.sh<br/>daily+weekly+monthly notes]
    SS --> SS2[active-tasks.md cat]
    UPS --> UPS_HOOK[prompt-context-loader.sh<br/>skill eval + ingest auto-fire]
    PRE --> PLAN[plan-mode-context.sh<br/>loads implementation-plan-standard]
    PRE --> REMIND[prepend-reminder.sh<br/>daily note anchor sanity]
    POST --> IDX[update-index.sh]
    POST --> DN[daily-note-watch.sh]
    POST --> GAT[generate-active-tasks.sh]
    POST --> PLNQ[planner-push-queue-writer.sh]
    POST --> FCD[feature-change-detector.sh]
    STOP --> TCC[task-compliance-check.sh]
    STOP --> DNC[daily-note-check.ps1]
  end
```

**What happens**: Six event types carry twelve hook scripts. `InstructionsLoaded` fires at session bootstrap and prints INDEX.md so the orchestrator knows what files exist. `SessionStart` ensures today's daily note + weekly/monthly/quarterly/yearly notes exist (idempotent — skips if present) and surfaces `active-tasks.md` so cross-session resume works. `UserPromptSubmit` runs the prompt-context-loader on every user prompt — skill YES/NO evaluation + ingest auto-fire on new drops in `ingest/`. `PreToolUse` with matcher `EnterPlanMode` loads the plan standard into context; with matcher `Edit|Write|MultiEdit` it runs the prepend-reminder anchor sanity check. `PostToolUse` fans out five hooks on every Edit/Write: INDEX.md update, daily-note-watch (for approval box checks), active-tasks.md regen, Planner push-queue writer, and feature-change-detector. `Stop` closes the loop with task-compliance-check (surfaces orphaned tasks) and daily-note-check (flags missing EOD entries).

### Typical Edit/Write hook chain

```mermaid
flowchart LR
  A[Tyler/Morpheus<br/>Edit tool call] --> B[PreToolUse<br/>Edit\|Write\|MultiEdit]
  B --> C[prepend-reminder.sh<br/>3s timeout]
  C --> D[Edit tool executes]
  D --> E[PostToolUse<br/>Edit\|Write matcher]
  E --> F[update-index.sh<br/>adds to INDEX.md if new file]
  E --> G[daily-note-watch.sh<br/>reacts to approval checkbox toggles]
  E --> H[generate-active-tasks.sh<br/>regenerates hub/state/active-tasks.md]
  E --> I[planner-push-queue-writer.sh<br/>diffs STATE.md status/priority]
  E --> J[feature-change-detector.sh<br/>flags doc debt for .claude/commands/hooks/scripts]

  F --> K[Edit returns to session]
  G --> K
  H --> K
  I --> K
  J --> K
```

**What happens**: Every Edit/Write fires 1 pre-hook and 5 post-hooks. Pre-hook `prepend-reminder.sh` runs first (anchored at 3-second timeout so it never stalls the main flow). After the Edit lands, five post-hooks fan out — all wrapped with `|| true` where appropriate so a single hook failure never blocks the main session. The hooks have no coordination: they each read the file state independently, do their thing, and exit. This is deliberate — hooks are passive observers, not a pipeline. `update-index.sh` only matters for newly-created files (Write), but it's registered for both matchers for simplicity. `feature-change-detector.sh` specifically watches `.claude/commands/**`, `.claude/hooks/**`, and `scripts/**` — NOT `docs/**`, so editing a feature doc itself doesn't recursively trigger the detector.

### Toolchain constraints on Goodwin endpoints

```mermaid
flowchart TD
  A[Hook script] --> B{Language choice}
  B -->|Bash .sh| C[Default — portable across Mac/Linux/Git Bash]
  B -->|PowerShell .ps1| D[Needed when: walking Windows dirs natively,<br/>checking signed module status,<br/>interacting with COM/Graph SDK]

  C --> E[AVOID: jq]
  E --> E1[jq not available on Goodwin endpoints]
  E --> E2[Use: PowerShell ConvertFrom-Json inside bash:<br/>pwsh -NoProfile -Command 'Get-Content x.json \| ConvertFrom-Json']

  C --> F[AVOID: real python]
  F --> F1[System python may be absent or old]
  F --> F2[Use: bash / awk / sed / PowerShell for JSON + text]

  D --> G[AllSigned execution policy]
  G --> G1[Every .ps1 hook must be signed by Goodwin code cert]
  G --> G2[HashMismatch after any edit → re-sign via /sign-script]

  D --> H[ThreatLocker]
  H --> H1[Scripts in non-standard paths get blocked]
  H --> H2[Workaround: bash cp to TEMP → sign → cp back]

  C --> I[NEVER: \|\| true to swallow tool-not-found]
  I --> I1[Silently hides missing jq/python on Goodwin]
  I --> I2[Use: explicit `command -v tool \|\| { echo 'ERROR: tool missing'; exit 1; }`]
```

**What happens**: Goodwin endpoints run Windows with AllSigned PowerShell policy + ThreatLocker application control. Any `.ps1` hook must be signed by the Goodwin code signing certificate; editing an existing signed script invalidates the signature and the script stops running. The bash tooling available is Git Bash's subset — no jq, potentially no real python — so hooks default to `.sh` with PowerShell inline (`pwsh -NoProfile -Command ...`) for JSON parsing. The `|| true` pattern is a trap: it silently hides missing tools, which means a hook that silently stops firing on Goodwin can go unnoticed for weeks. The rule is: every hook must be explicit about its runtime requirements and fail loudly if they're missing.

## User flows

### Flow 1: Write and deploy a new hook

**Goal**: add a new PostToolUse hook that reacts to Edit/Write on a specific path pattern.

**Steps**:
1. Scaffold the script: `/script-scaffold bash .claude/hooks/my-new-hook.sh` — generates a header block with task-id, changelog, strict-mode boilerplate (`set -euo pipefail`).
2. Write the hook logic. Use `command -v tool || { echo "ERROR: tool missing"; exit 1; }` for every external tool dependency — NEVER silently swallow with `|| true`.
3. Add a FIRED/SKIPPED/ERROR stdout line: `echo "[HOOK:PostToolUse] FIRED — my-new-hook: {reason}"`. This makes the hook visible in session output.
4. Register in `.claude/settings.local.json` under the appropriate event → matcher:
   ```json
   { "matcher": "Edit|Write",
     "hooks": [{ "type": "command",
                 "command": "bash .claude/hooks/my-new-hook.sh",
                 "timeout": 5000 }] }
   ```
5. If PowerShell: sign via `/sign-script .claude/hooks/my-new-hook.ps1`. Use the TEMP workaround (bash cp → pwsh Set-AuthenticodeSignature → bash cp back) to avoid ThreatLocker blocks.
6. Test with an Edit that matches. Check session output for `[HOOK:PostToolUse] FIRED` marker.

**Example**:
```bash
/script-scaffold bash .claude/hooks/kb-staleness-check.sh
# → writes script with header + strict mode
# Edit settings.local.json to register under PostToolUse Edit|Write
# Save → next Edit/Write fires the new hook
```

**Expected result**: hook runs on every matching tool call; FIRED marker visible in session output; no regressions on existing hooks.

### Flow 2: Diagnose a failing hook (timeout is the usual suspect)

**Goal**: figure out why a hook registered in settings.local.json isn't doing what it should.

**Steps**:
1. Grep session output for the hook's marker: `grep "[HOOK:event] " <session-log>`. If no FIRED/SKIPPED/ERROR line appears, the hook didn't run at all.
2. Check timeout. The most common cause of silent failure: the hook ran but exceeded its timeout and was killed before its stdout flushed. Look for the hook's timeout in `settings.local.json`; bump it (e.g., 3000 → 10000) and retry.
3. Check the matcher. PreToolUse / PostToolUse matchers are ERE regex. `Edit|Write` matches both; `Edit` alone won't fire for Write calls.
4. Check signature (.ps1 only). `(Get-AuthenticodeSignature <script>).Status` — if not `Valid`, re-sign via `/sign-script`. AllSigned policy refuses to run unsigned or hash-mismatched scripts silently.
5. Check tool availability. If the hook uses `jq`, `python3`, or any other non-default tool, confirm with `command -v <tool>`. Goodwin endpoints don't have jq — use PowerShell `ConvertFrom-Json` instead.
6. If all above pass and the hook still doesn't fire: run it manually from bash (`bash .claude/hooks/my-hook.sh`) to confirm the script itself works, then check settings.local.json registration syntax with `python3 -m json.tool .claude/settings.local.json`.

**Example**:
```bash
grep "feature-change-detector" session.log
# → no output = hook not firing
# Check settings.local.json matcher — correct
# Check timeout — 3000ms, bump to 5000
# Run manually: bash .claude/hooks/feature-change-detector.sh — works
# Root cause: timeout. Fixed.
```

**Expected result**: hook resumes firing; diagnostic output identifies the specific layer (timeout / matcher / signature / tool / syntax) that broke.

### Flow 3: Trace the hook chain for a specific tool call

**Goal**: understand what fires on a given Edit or Write, in what order, to debug unexpected side effects or to learn the system.

**Steps**:
1. Identify the tool + matchers. An Edit triggers: PreToolUse `Edit|Write|MultiEdit` (→ prepend-reminder.sh), then the Edit itself, then PostToolUse `Edit|Write` (5 hooks in parallel: update-index, daily-note-watch, generate-active-tasks, planner-push-queue-writer, feature-change-detector).
2. Enable bash trace on the target hook: add `set -x` at the top of the `.sh` script temporarily. Tool output will show every command the hook runs.
3. Watch the session event stream. Each hook prints `[HOOK:event] FIRED — description` to stdout; ordering in the session output reflects completion order, not fire order (hooks fire in parallel within an event).
4. Reconstruct the chain: pre-hooks run before the tool; post-hooks run after. Within an event tier, assume parallel execution — do not rely on ordering for correctness.
5. Remove `set -x` after diagnosis.

**Example**:
```bash
# Tyler edits docs/morpheus-features/orchestration-loop.md
# Session output shows (in completion order):
# [HOOK:PreToolUse] FIRED — prepend-reminder.sh
# [HOOK:PostToolUse] FIRED — update-index.sh (no new file — skipped INDEX append)
# [HOOK:PostToolUse] FIRED — daily-note-watch.sh (no approval toggle — skipped)
# [HOOK:PostToolUse] FIRED — generate-active-tasks.sh (regenerated)
# [HOOK:PostToolUse] FIRED — planner-push-queue-writer.sh (not STATE.md — skipped)
# [HOOK:PostToolUse] FIRED — feature-change-detector.sh (docs/ path — skipped, only watches .claude/scripts)
```

**Expected result**: full chain reconstructed; unexpected side effects attributed to a specific hook; no hook silently eating errors.

## Configuration

| Path / Variable | Purpose | Default | Required? |
|-----------------|---------|---------|-----------|
| `.claude/settings.local.json` | Hook registration — event + matcher + command + timeout per hook | — | yes |
| `.claude/hooks/prompt-context-loader.sh` | UserPromptSubmit — skill evaluation + ingest auto-fire + time context | 5000ms timeout | yes |
| `.claude/hooks/prepend-reminder.sh` | PreToolUse Edit|Write|MultiEdit — daily note anchor sanity | 3000ms | yes |
| `.claude/hooks/update-index.sh` | PostToolUse Write — appends new files to INDEX.md | default timeout | yes |
| `.claude/hooks/daily-note-watch.sh` | PostToolUse Edit|Write — reacts to approval checkbox toggles | 3000ms | yes |
| `scripts/utils/generate-active-tasks.sh` | PostToolUse Edit|Write — regenerates hub/state/active-tasks.md | 5000ms (with `|| true` guard) | yes |
| `.claude/hooks/planner-push-queue-writer.sh` | PostToolUse Edit|Write — diffs STATE.md status/priority into push queue | 5000ms | optional (Planner integration only) |
| `.claude/hooks/feature-change-detector.sh` | PostToolUse Edit|Write — flags feature doc debt to daily note | 5000ms | yes |
| `.claude/hooks/plan-mode-context.sh` | PreToolUse EnterPlanMode — loads plan standard | 5000ms | yes |
| `.claude/hooks/task-compliance-check.sh` | Stop — surfaces orphaned session tasks | 5000ms | yes |
| `.claude/hooks/daily-note-check.ps1` | Stop — flags missing EOD entries (PowerShell for native Windows FS walk) | 10000ms | yes |
| `scripts/utils/ensure-note.sh` | SessionStart — creates daily/weekly/monthly/quarterly/yearly notes if missing | default | yes |

### Event → matcher → hook mapping

| Event | Matcher | Hook | Purpose |
|-------|---------|------|---------|
| InstructionsLoaded | — | inline `cat INDEX.md` | Load directory source-of-truth |
| SessionStart | — | `ensure-note.sh` | Idempotent note creation |
| SessionStart | — | inline `cat active-tasks.md` | Cross-session resume context |
| UserPromptSubmit | — | `prompt-context-loader.sh` | Skill eval + ingest + time |
| PreToolUse | `EnterPlanMode` | `plan-mode-context.sh` | Load plan standard |
| PreToolUse | `Edit\|Write\|MultiEdit` | `prepend-reminder.sh` | Daily note anchor sanity |
| PostToolUse | `Write` | `update-index.sh` | INDEX.md append |
| PostToolUse | `Edit\|Write` | `daily-note-watch.sh` | Approval checkbox reactions |
| PostToolUse | `Edit\|Write` | `generate-active-tasks.sh` | active-tasks.md regen |
| PostToolUse | `Edit\|Write` | `planner-push-queue-writer.sh` | Queue STATE.md field diffs |
| PostToolUse | `Edit\|Write` | `feature-change-detector.sh` | Flag doc debt |
| Stop | — | `task-compliance-check.sh` | Orphaned task surfacing |
| Stop | — | `daily-note-check.ps1` | EOD entry check |

## Integration points

| Touches | How | Files |
|---------|-----|-------|
| Every skill | Hooks fire as side effects of tool use during skill execution | — |
| STATE.md | PostToolUse hooks regenerate `active-tasks.md` from every STATE.md frontmatter change | `scripts/utils/generate-active-tasks.sh`, `hub/state/active-tasks.md` |
| INDEX.md | PostToolUse Write hook appends new files | `.claude/hooks/update-index.sh`, `INDEX.md` |
| Daily note | SessionStart ensures note; daily-note-watch reacts to approval checkbox toggles; Stop flags missing EOD | `.claude/hooks/{daily-note-watch,daily-note-check}.{sh,ps1}`, `scripts/utils/ensure-note.sh`, `.claude/rules/daily-note.md` |
| Planner sync | PostToolUse writer queues STATE.md status/priority field diffs | `.claude/hooks/planner-push-queue-writer.sh`, `hub/state/planner-push-queue.json` |
| Feature docs | PostToolUse detector logs doc debt to `## Tomorrow's Prep` when `.claude/commands/**`, `.claude/hooks/**`, or `scripts/**` change | `.claude/hooks/feature-change-detector.sh`, `notes/YYYY/MM/YYYY-MM-DD.md` |
| Orchestration loop | PreToolUse EnterPlanMode loads plan standard; Stop runs task-compliance-check | `.claude/hooks/plan-mode-context.sh`, `.claude/hooks/task-compliance-check.sh`, `.claude/rules/implementation-plan-standard.md` |
| Ingest pipeline | prompt-context-loader auto-fires `/ingest-context` when `ingest/` has unprocessed drops | `.claude/hooks/prompt-context-loader.sh`, `.claude/commands/ingest-context.md` |

## Troubleshooting

Failure modes in Morpheus's hooks have been rare post-build — most bugs land during initial hook authoring, not steady-state operation. The observed failure modes are signature-related (PS HashMismatch after edit) and quoting-related (apostrophe in single-quoted awk block). The theoretical failure modes are documented defensively so future hook authors know what to check first.

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `.ps1` hook stopped firing after an edit | HashMismatch — signature invalidated by edit (observed) | Re-sign via `/sign-script .claude/hooks/<hook>.ps1`. Use the TEMP workaround: bash cp to `$env:TEMP/sign-work/` → `pwsh Set-AuthenticodeSignature` → bash cp back. `(Get-AuthenticodeSignature <hook>).Status` should return `Valid`. |
| Bash hook errors with unexpected "syntax error near ... unexpected token" | Apostrophe inside single-quoted awk block (observed in feature-change-detector.sh "Tomorrow's Prep") | Avoid apostrophes inside `awk '...'` even when the apostrophe is in a comment. Rewrite the awk argument without the apostrophe, or use double quotes for awk and escape internal double quotes. |
| Hook silently not firing | Timeout exceeded, killed before stdout flushed (theoretical) | Bump timeout in `settings.local.json` (3000 → 10000ms). Grep session for `[HOOK:event] ERROR` or empty marker. Run the hook manually: `bash .claude/hooks/<hook>.sh` — if slow, optimize the hook or increase timeout. |
| Hook fires but produces no visible effect | `|| true` swallowed a tool-not-found error (theoretical) | Search the hook for `|| true`; replace with explicit tool checks: `command -v jq || { echo "[HOOK:PostToolUse] ERROR — jq missing"; exit 1; }`. Goodwin endpoints don't have jq — use PowerShell ConvertFrom-Json inside bash. |
| ThreatLocker blocks a new .ps1 | Script in non-standard path; cert unknown to ThreatLocker (theoretical for `.claude/hooks/`) | Sign the script first via TEMP workaround; if still blocked, Tyler coordinates with {{team.manager.name}} to allowlist the hook path. `.claude/hooks/*.ps1` should be auto-approved once signed with Goodwin cert. |
| PS execution policy refuses hook | Script not signed, or signed with unknown cert | Sign with Goodwin code signing certificate (`DC=goodwinprocter.com`). `/sign-script` handles cert selection automatically. |
| Unexpected hook ordering | Two hooks in the same event/matcher tier assumed to run sequentially but are parallel | Hooks within the same event-matcher tier run in undefined order. Do not chain hooks. If you need ordering, combine into a single hook script. |

## References

**Hook registration**:
- [`.claude/settings.local.json`](../../.claude/settings.local.json) — event/matcher/command/timeout registrations

**Hook scripts**:
- [`.claude/hooks/prompt-context-loader.sh`](../../.claude/hooks/prompt-context-loader.sh) — UserPromptSubmit
- [`.claude/hooks/prepend-reminder.sh`](../../.claude/hooks/prepend-reminder.sh) — PreToolUse Edit|Write
- [`.claude/hooks/update-index.sh`](../../.claude/hooks/update-index.sh) — PostToolUse Write
- [`.claude/hooks/daily-note-watch.sh`](../../.claude/hooks/daily-note-watch.sh) — PostToolUse
- [`.claude/hooks/planner-push-queue-writer.sh`](../../.claude/hooks/planner-push-queue-writer.sh) — PostToolUse
- [`.claude/hooks/feature-change-detector.sh`](../../.claude/hooks/feature-change-detector.sh) — PostToolUse
- [`.claude/hooks/plan-mode-context.sh`](../../.claude/hooks/plan-mode-context.sh) — PreToolUse EnterPlanMode
- [`.claude/hooks/task-compliance-check.sh`](../../.claude/hooks/task-compliance-check.sh) — Stop
- [`.claude/hooks/daily-note-check.ps1`](../../.claude/hooks/daily-note-check.ps1) — Stop (PowerShell)
- [`scripts/utils/ensure-note.sh`](../../scripts/utils/ensure-note.sh) — SessionStart
- [`scripts/utils/generate-active-tasks.sh`](../../scripts/utils/generate-active-tasks.sh) — PostToolUse

**Related rules**:
- [`.claude/rules/daily-note.md`](../../.claude/rules/daily-note.md) — daily note protocol enforced by hooks
- [`.claude/rules/active-tasks.md`](../../.claude/rules/active-tasks.md) — active-tasks.md regeneration contract
- [`.claude/rules/scripts.md`](../../.claude/rules/scripts.md) — hook script standards (headers, strict mode, TDD)

**Related feature docs**:
- [`docs/morpheus-features/orchestration-loop.md`](orchestration-loop.md) — consumer of plan-mode-context.sh + task-compliance-check.sh
- [`docs/morpheus-features/daily-notes-system.md`](daily-notes-system.md) — consumer of daily-note-watch.sh, ensure-note.sh, daily-note-check.ps1
- [`docs/morpheus-features/feature-documentation-system.md`](feature-documentation-system.md) — consumer of feature-change-detector.sh
- [`docs/morpheus-features/context-engineering.md`](context-engineering.md) — consumer of prompt-context-loader.sh ingest auto-fire path
- [`docs/morpheus-features/o365-planner-integration.md`](o365-planner-integration.md) — consumer of planner-push-queue-writer.sh

**External**:
- Claude Code harness hook event documentation (upstream, Anthropic)

## Changelog

| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-20 | 2026-04-17-feature-docs-prose-fill | morpheus | Filled skeleton to active: 3 Mermaid (event taxonomy, typical Edit/Write chain, Goodwin toolchain constraints), Configuration expanded to 12-row hook inventory + event/matcher/hook mapping table, Integration points to 8 rows, References split into 5 named subsections, 3 user flows (scaffold+deploy new hook, diagnose failure, trace chain) with full Goal/Steps/Example/Expected structure, 7-row troubleshooting table splitting observed vs theoretical failure modes. |
| 2026-04-17T11:00 | 2026-04-17-morpheus-feature-docs | morpheus | Skeleton created via /document-feature audit consolidation — prose TODO |
