---
description: Create daily notes for today and/or previous days with proper task rollover
user-invocable: true
argument-hint: (optional) number of days to backfill or specific date YYYY-MM-DD
allowed-tools: [Read, Write, Bash, Glob]
schema-version: 1
---
# Create Daily Notes

Create daily notes for today and any missing previous days with full task rollover.

## Arguments
- **No arguments**: Create today's daily note only
- **A number** (e.g., "3"): Create daily notes for today and the previous N days
- **A date** (e.g., "2026-04-05"): Create daily note for that specific date

## Step 1: Run ensure-note.sh
- Run via Bash:
  ```bash
  bash "{{paths.home}}/Documents/TE GW Brain/scripts/utils/ensure-note.sh"
  ```
- This creates today's note with task rollover from the most recent previous note.

## Step 2: Handle Backfill (if arguments provided)
If a number N is given:
1. Loop from N days ago to yesterday
2. For each date, check if `notes/YYYY/MM/YYYY-MM-DD.md` exists
3. If it does NOT exist, create it from the template at `hub/templates/daily-note.md`
4. Fill in all placeholders (date, day-of-week, navigation links, week number)
5. Apply task rollover from the previous existing note

If a specific date is given:
1. Check if `notes/YYYY/MM/YYYY-MM-DD.md` exists for that date
2. If not, create it with proper placeholders filled in
3. Apply task rollover from the nearest previous note

## Step 3: Report
Provide a summary:
```
✅ Created daily notes:
  - 2026-04-05 (Saturday) — 0 tasks rolled over
  - 2026-04-06 (Sunday) — 2 tasks rolled over
  - 2026-04-07 (Monday) — 3 tasks rolled over
  - 2026-04-08 (Tuesday) — already existed
```

## Rules
- Never overwrite an existing daily note.
- Task rollover must chain correctly: day N rolls into day N+1, which rolls into N+2, etc.
- Use YYYY-MM-DD format for all dates.
- Fill ALL template placeholders including navigation links and week numbers.
