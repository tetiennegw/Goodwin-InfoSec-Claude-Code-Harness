---
description: Save current progress — update STATE.md, task list, and daily note at a natural breakpoint
user-invocable: true
allowed-tools: [Read, Write, Edit, Glob, TaskUpdate, TaskList]
schema-version: 1
---
# Checkpoint

Save current progress at a natural breakpoint. Updates STATE.md, task list, and daily note.

## Step 1: Identify Active Task
- Read `hub/state/active-tasks.md` to find the current active task.
- If multiple tasks are active, checkpoint the one most recently worked on (or ask Tyler which one).
- Read the task's `STATE.md` at `hub/staging/{task-id}/STATE.md`.

## Step 2: Update STATE.md
Back up STATE.md to STATE.md.bak first, then update the following sections:

### Progress Summary
- Append what was accomplished since the last checkpoint.
- Include wave/round labels and timestamps.
- Example: `- Wave 2 (Plan): Round 1 COMPLETE — planner produced runbook plan with 5 build tasks. [YYYY-MM-DDTHH:MM]`

### Artifacts Produced
- Add paths to any new files created since last checkpoint.

### Current Position
- Update `current-wave` and `current-round` fields.

### Open Items
- Update with any new blockers, questions, or unresolved issues.
- Remove items that have been resolved.

### Next Action
- Set to the next concrete step that should happen when work resumes.

### Changelog
- Add entry: `YYYY-MM-DDTHH:MM | {task-id} | morpheus | Checkpoint: {brief summary}`

## Step 2b: Capture Active Neo Sessions (Neo-Aware)
After updating STATE.md progress fields, check for active Neo sessions:
- Read the STATE.md `neo-session-ids:` field (YAML frontmatter). If the list is non-empty, include a `**Neo Sessions Active**` field in the daily-note checkpoint timeline entry (Step 4) listing each session id.
- Format: `**Neo Sessions Active**: conv_abc123, conv_def456`
- This ensures cross-session resume can find open Neo investigations without re-reading logs.

## Step 3: Update Task List
- Run `TaskList` to see current session tasks.
- Call `TaskUpdate` for any items that completed since last checkpoint.
- Ensure task statuses match STATE.md reality.

## Step 4: Update Daily Note
- Add a timeline entry to today's daily note:
  ```
  ### HH:MM | morpheus | [{task-id}] | #checkpoint
  Checkpoint: {brief summary of progress since last checkpoint}
  -> [STATE.md](hub/staging/{task-id}/STATE.md)
  ```
- If Step 2b found active Neo sessions, append the `**Neo Sessions Active**` field to this entry.

## Step 5: Archive if complete
- `hub/state/active-tasks.md` is auto-generated from STATE.md — no manual update needed. It regenerates automatically when STATE.md is updated in Step 2.
- If the task is now complete, run `/eod` to archive it to `hub/state/completed-tasks.md`. Do not set `status: completed` in STATE.md until the archival is done — doing so first causes a warning flag in active-tasks.md until /eod runs.

## Rules
- Always back up STATE.md before modifying it.
- Checkpoints should be quick — do not re-read artifact contents, just update metadata.
- If STATE.md seems stale (timestamps don't match recent work), flag this to Tyler.
- A checkpoint is NOT a verdict — it does not determine ADVANCE/CONTINUE/FLAG/FAIL.
