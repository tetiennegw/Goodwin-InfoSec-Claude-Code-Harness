---
description: Load today's daily note into context with visual feedback and stats
user-invocable: true
allowed-tools: [Read, Bash, Glob]
schema-version: 1
---
# Read Today

Load the current day's daily note into context, providing visual feedback about the operation.

## Step 1: Get Current Date
- Run `date '+%Y-%m-%d'` to get current date in YYYY-MM-DD format.

## Step 2: Calculate Daily Note Path
- Path pattern: `notes/YYYY/MM/YYYY-MM-DD.md`
- Example: `notes/2026/04/2026-04-08.md`

## Step 3: Find Today's Daily Note
- First try the calculated path directly.
- If not found, use Glob to search: `notes/**/*YYYY-MM-DD.md`
- This handles cases where notes may be in different locations due to date calculation variations.

## Step 4: Read and Validate Note
- Use Read tool to load the note content.
- Count tasks and note entries for statistics:
  - Pending tasks per tier: count `- [ ]` lines under each `### Priority` section
  - Completed tasks: count `- [x]` lines
  - Note entries: count `- **HH:MM**` lines under `## Notes`
  - Blockers: check `## End of Day` for blocker entries

## Step 5: Provide Visual Feedback

**Success:**
```
✅ Loaded daily note for YYYY-MM-DD
   📋 Tasks: X pending (T top, S secondary, R tertiary, O other) | Y completed
   📝 Notes: Z entries
```

**Not Found:**
```
❌ Daily note for YYYY-MM-DD not found. Use /create-daily-notes to create it.
```

**Empty/Minimal:**
```
⚠️ Daily note for YYYY-MM-DD loaded but appears empty. Consider adding tasks or notes.
```

## Rules
- Always check if the note file exists before attempting to read.
- The note content should be available in context for subsequent commands.
- If arguments are provided (e.g., a specific date), load that date's note instead.
