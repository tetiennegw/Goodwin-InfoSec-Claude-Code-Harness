---
description: End of day wrap-up — checkpoint all active tasks, update daily note summary, update priorities, surface pending changes (no auto-commit)
user-invocable: true
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, TaskList, TaskUpdate]
schema-version: 1
---
# End of Day

Perform end-of-day wrap-up: checkpoint all tasks, summarize the day, set tomorrow's priorities.

## Step 1: Checkpoint All Active Tasks
- Read `hub/state/active-tasks.md` to find all in-progress tasks. (This file is auto-generated from STATE.md — do not edit it directly.)
- For each active task, perform a checkpoint:
  - Read its `STATE.md`
  - Update Progress Summary, Artifacts Produced, Open Items, Next Action
  - Update the Changelog with an EOD entry
  - Back up STATE.md to STATE.md.bak before modifying
- Update `TaskUpdate` for any session tasks that completed today.

## Step 1b: Archive Completed Tasks
For each task that is now complete:
1. Prepend an entry to `hub/state/completed-tasks.md` using the existing schema:
   ```markdown
   ## {task-id}
   - **Completed**: {ISO timestamp}
   - **Scope**: {scope}
   - **Summary**: {prose description of deliverables}
   - **STATE**: {path to STATE.md}
   - **Plan**: {path to plan file, or N/A}
   - **Key artifacts**:
     - {bullet list of artifact paths}
   ```
2. Set `status: completed` in the task's STATE.md frontmatter.
3. The generator will flag the task with a warning until it runs again; after the next Edit/Write, active-tasks.md regenerates and shows the completed marker.

**IMPORTANT**: Archive to completed-tasks.md MUST happen before or simultaneously with setting `status: completed` in STATE.md. Setting status first causes the warning flag to appear until the next regeneration.

## Step 1c: Surface Open Neo Sessions (Neo-Aware)
Before completing the daily wrap-up, scan today's daily note for unclosed Neo sessions:
- Grep today's note for `#neo` tags: `grep -n '#neo' notes/YYYY/MM/YYYY-MM-DD.md`
- For each `#neo` entry, check whether a "session closed", final `response` event log, or downstream follow-up entry exists in the same day's Notes.
- If any Neo session appears open (Session ID present, no closure signal), add it to the `Carry-over` section of `## End of Day` under a sub-heading:
  ```
  - Open Neo Sessions:
    - conv_abc123 (started HH:MM) — no closure recorded; resume with: neo --session conv_abc123
  ```
- If no unclosed Neo sessions found, skip this entry entirely (no noise).

## Step 2: Complete Today's Daily Note
- Read today's daily note at `notes/YYYY/MM/YYYY-MM-DD.md`.
- Fill in the `## End of Day` section:

```markdown
## End of Day
- Completed: {list of tasks/milestones completed today}
- Carried forward:
  - Top Priority: {incomplete top priority items}
  - Secondary: {incomplete secondary items}
  - Tertiary: {incomplete tertiary items}
  - Other: {incomplete other items}
  - Open Neo Sessions: {from Step 1c — omit if none}
- Blockers: {any items blocked and why, or "None"}
```

- Review the `## Notes` entries to ensure nothing significant was missed.
- Populate `## Tomorrow's Prep` with the most important items for the next session.

## Step 3: Update Priorities
- Read `memory/priorities.md` (create if it doesn't exist).
- Update with tomorrow's focus areas based on:
  - Carried-forward items from today
  - Next actions from active task STATE.md files
  - Any blockers that need resolution
  - Upcoming deadlines or scheduled work

## Step 4: Surface Pending Changes (Do NOT Auto-Commit)

**Rationale**: This repo is the Morpheus open-source harness intended for Tyler's security team. Its git history should reflect framework evolution (scoped feature/fix commits) — not daily journal noise. `/eod` is Tyler's personal wrap-up; it checkpoints local state but does NOT commit on his behalf. Framework changes get committed when they ship, with proper messages. Personal files (notes, memory, state caches) are gitignored and never committed.

**What to do instead**: Surface pending changes so Tyler can decide what, if anything, to commit — and help him scope it properly.

**Run via Bash**:

```bash
cd "{{paths.home}}/Documents/TE GW Brain"

echo ""
echo "=== Pending changes (nothing has been committed) ==="
git status --short
echo ""
echo "=== Change counts by category ==="
printf "  Framework code:   "
git status --short 2>/dev/null | grep -cE '^.. (\.claude/|scripts/|docs/(architecture|getting-started|reference|decisions)|CLAUDE\.md|INDEX\.md|README\.md|hub/templates/|hub/patterns/)' || true
printf "  Personal / local: "
git status --short 2>/dev/null | grep -cE '^.. (notes/|hub/state/|hub/staging/|memory/|ingest/|ops/)' || true
echo ""
echo "Suggestion: commit framework changes manually with a scoped message, e.g."
echo "  git add .claude/commands/eod.md && git commit -m 'fix(eod): scope commits to framework changes'"
echo ""
echo "Personal files (notes, state, memory) should be gitignored — see .gitignore."
echo "If any appear above under 'Personal / local', verify .gitignore coverage before pushing."
```

**Do NOT run** `git add -A`, `git commit`, or any commit-adjacent command as part of EOD. Those are manual, scoped actions Tyler performs consciously.

**If Tyler explicitly says "commit the EOD"**: treat that as an opt-in override. Use an allow-list (`notes/`, `hub/state/active-tasks.md`, `hub/state/completed-tasks.md`, `memory/`) only if those paths are NOT currently gitignored — never `git add -A`.

## Step 5: Report
Provide Tyler with a brief EOD summary:
- Tasks completed today (count and names)
- Tasks in progress (count, current wave/round)
- Blockers requiring attention
- Tomorrow's top priorities

## Rules
- EOD should be thorough but not slow — aim to complete in under 2 minutes.
- Do not start new work during EOD — this is wrap-up only.
- If a daily note does not exist yet, create it first using the template at `hub/templates/daily-note.md`.
- The git commit captures the day's state — ensure all files are saved before committing.
