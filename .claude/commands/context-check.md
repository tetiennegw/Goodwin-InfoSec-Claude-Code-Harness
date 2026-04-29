---
description: Assess current context health — what's loaded, what's stale, suggest cleanup
user-invocable: true
allowed-tools: [Read, Glob, Grep, TaskList]
schema-version: 1
---
# Context Check

Assess the current session's context health and suggest actions.

## Step 1: Session State Inventory
Report on the following:

### Active Task
- Check `hub/state/active-tasks.md` for in-progress tasks.
- If a task is active, read its `STATE.md` and report:
  - Task ID and macro goal
  - Current wave/round
  - Last updated timestamp
  - Next action

### Task List
- Run `TaskList` to show any session-ephemeral tasks.
- Note how many are completed vs in-progress vs blocked.

### Daily Note
- Check if today's daily note exists at `notes/YYYY/MM/YYYY-MM-DD.md`.
- If it exists, count the number of timeline entries today.
- If it does not exist, flag this and suggest running `/daily-note-management`.

## Step 2: Context Utilization Estimate
Estimate current context load based on observable signals:

| Level | Indicators |
|-------|-----------|
| **Light** | Few files read, 0-1 active tasks, early in session |
| **Moderate** | Several files read, 1-2 active tasks, mid-session |
| **Heavy** | Many files read, 3+ completed waves, long-running session |

Report: `Context utilization: {LIGHT|MODERATE|HEAVY}`

## Step 3: Staleness Check
- If `STATE.md` exists, check if `last-updated` is from a previous day — flag as potentially stale.
- Check if `INDEX.md` has been updated recently.
- Use `Glob` to check for files in `hub/staging/` that may not be tracked in `INDEX.md`.

## Step 4: Recommendations
Based on findings, suggest applicable actions:

- **Heavy context**: Suggest `/compact` to free up context window.
- **No tasks**: Suggest creating tasks with `/task-list-management`.
- **No daily note**: Suggest `/daily-note-management`.
- **Stale STATE.md**: Suggest re-reading STATE.md or running `/checkpoint`.
- **Untracked files**: Suggest updating `INDEX.md`.
- **Active task from previous day**: Suggest reviewing and resuming or closing.

## Rules
- This is a READ-ONLY diagnostic skill — it does not modify any files.
- Keep the report concise: status table + 2-4 recommendations.
- Do not load file contents into context unnecessarily — check existence and metadata only.
