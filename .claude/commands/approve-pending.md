---
description: Re-prompt for deferred approval items from today's (or a prior) daily note — fires AskUserQuestion for each pending item and applies/defers/denies based on the answer. Auto-activated by prompt-context-loader when a user checks an approval box in today's daily note.
user-invocable: true
argument-hint: (optional) date YYYY-MM-DD to process, defaults to today
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, TaskCreate, TaskUpdate, TaskList, AskUserQuestion]
schema-version: 1
---
# /approve-pending

Re-prompt Tyler for deferred approval items so they can be applied, denied, or kept deferred. The skill is the "revisit later" path for items that weren't ready for immediate decision during `/ingest-context`.

## When to invoke

- **Automatic (primary)**: the `prompt-context-loader.sh` hook detects a change in the `## Approvals Pending` section of today's daily note (hashes don't match the stored snapshot AND new checked boxes are present) and injects a forced-YES override for this skill.
- **Manual**: Tyler types `/approve-pending` or `/approve-pending 2026-04-08` to revisit deferred items from a specific day.
- **Session start**: the SessionStart hook scans today + last 3 days for open pending items and surfaces them; if Tyler says "yes, let's process them", this skill runs.

## Prerequisites

- Target daily note exists
- The note has a `## Approvals Pending` section
- `AskUserQuestion` tool is available (this skill has no headless fallback — defer again if unavailable)

## Steps

### Step 1 — Load the target daily note

1. Determine target date: argument or today.
2. Compute path: `notes/YYYY/MM/YYYY-MM-DD.md`
3. Read the file. If missing, report and exit.

### Step 2 — Parse `## Approvals Pending`

1. Extract the section between `^## Approvals Pending` and the next `^## ` heading.
2. Parse each item as a multi-line block. Fields to extract per item:
   - Checkbox state (`[ ]` open, `[x]` checked)
   - Timestamp (from the bold `HH:MM` marker)
   - Title (from the bold title after the dash)
   - Task ID (from the `(task: <id>)` suffix)
   - Proposed change (from the `**Proposed change**:` line)
   - Why (from the `**Why**:` line)
   - Source context-log link (from the `**Source**:` line)
3. Separate items into two groups:
   - **Group A**: open `[ ]` items — re-prompt
   - **Group B**: checked `[x]` items — these were flipped manually by Tyler since the last run; they need confirmation before apply

### Step 3 — Group B: checkbox-flipped items

For each Group B item, treat as equivalent to "Tyler wants to apply now" but confirm via a safety-rail prompt:

1. Fire `AskUserQuestion`:
   - `question: "You checked the box for: <title>. Apply this change now?"`
   - `header: "Confirm"`
   - Options:
     - `"Yes, apply now"`
     - `"Actually defer"` — re-open the checkbox, leave pending
     - `"Deny instead"` — log denial
2. Branch:
   - **Yes, apply now**: execute the change (see Apply flow in Step 5), remove the item from `## Approvals Pending`, append to `## Approvals Log` with `(originally raised HH:MM, confirmed via checkbox HH:MM)` note.
   - **Actually defer**: rewrite the item's checkbox back to `[ ]`, leave in place.
   - **Deny instead**: log denial (see Deny flow in Step 5), remove from `## Approvals Pending`, append to `## Approvals Log`.

### Step 4 — Group A: open pending items

For each Group A item, fire `AskUserQuestion`:
- `question: "Apply this change now? — <title>"`
- `header: "Approval"`
- Options: `"Apply now"` / `"Defer"` / `"Deny"` (same as `/ingest-context` Step 6)

Branch identically to `/ingest-context` Step 6 Apply/Defer/Deny/Other handling, with one difference: when applying a deferred item, the `## Approvals Log` entry MUST include the `(originally raised HH:MM on YYYY-MM-DD)` note so the audit trail preserves the original raise timestamp.

### Step 5 — Apply/Deny flows

**Apply flow**:
1. Execute the proposed change via Write/Edit.
2. `TaskUpdate <task-id> status=completed`
3. Remove the item from `## Approvals Pending` (delete the entire multi-line block)
4. Append to `## Approvals Log`:
   ```markdown
   - **HH:MM** ✓ **<title>** — applied to `<target-file>` (task: <task-id>) (originally raised HH:MM on YYYY-MM-DD)
     **Source**: [context-log entry](<path>)
   ```

**Deny flow**:
1. `TaskUpdate <task-id> status=completed` with `metadata: {denied: true, denied-at: HH:MM}`
2. Remove from `## Approvals Pending`
3. Append to `## Approvals Log`:
   ```markdown
   - **HH:MM** ✗ **<title>** — denied (task: <task-id>) (originally raised HH:MM on YYYY-MM-DD)
     **Source**: [context-log entry](<path>)
   ```

### Step 6 — Update snapshot

After all items are processed, recompute the sha256 of the current `## Approvals Pending` section and write to `hub/state/daily-note-snapshots/YYYY-MM-DD.approvals.sha` so the watcher doesn't re-fire.

### Step 7 — Report

```
APPROVE-PENDING SUMMARY (date: YYYY-MM-DD)
==========================================
Open items processed: N
  Applied:  X
  Deferred: Y
  Denied:   Z

Checkbox-flipped items: M
  Confirmed:  A
  Re-deferred: B
  Denied:      C

Items remaining pending: K
```

## Rules

- **Always re-prompt via AskUserQuestion** — never trust the daily note file alone as a command surface. A checked box is an intent signal, not an execution trigger.
- **Never delete from `## Approvals Log`** — append-only.
- **Target-file existence check**: before applying, verify the target file/directory exists. If not, fire a follow-up AskUserQuestion asking whether to create it or skip.
- **Prior-day processing**: if the argument date is not today, write applied/denied receipts to the SAME day's note (the one where the pending item lived), not today's note. Do not modify today's note when processing a prior day.
- **Lock respect**: if `hub/state/.ingest.lock` is held and fresh (<10 min), abort with "Ingest is running, try again in a moment" — don't race against the ingest skill.
- **No cascades from cascades**: approving an item that itself contains high-risk references does NOT recursively prompt. Apply what's in the proposed-change field verbatim. If the user deferred with a "⚠️ needs-clarification" suffix, they should clarify verbally or edit the item before running this skill.
