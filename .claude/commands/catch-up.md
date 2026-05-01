---
description: Summarize missed days since last session — catch up on what happened
user-invocable: true
allowed-tools: [Read, Bash, Glob]
schema-version: 1
---
# Catch Up

Summarize what happened since you were last active. Useful after weekends, vacations, or multi-day gaps.

## Step 1: Find the Gap
- Get today's date.
- Search for the most recent daily note before today by scanning `notes/YYYY/MM/` backwards.
- Identify the date range of the gap.

## Step 2: Read All Notes in the Gap
- For each date from the last note to today, read the daily note if it exists.
- Extract from each note:
  - `## Summary` section (the auto-generated overview)
  - `## Notes` entries (what work was done)
  - `## Agenda & Tasks` — which tasks were completed (`- [x]`) vs. still pending (`- [ ]`)
  - `## End of Day` section (completed, carried forward, blockers)

## Step 2b: Surface Open Neo Sessions (Neo-Aware)
For each gap day daily note, scan for unclosed Neo sessions:
- Run: `grep -B0 -A2 '#neo' notes/YYYY/MM/YYYY-MM-DD.md` for each gap day (substituting the actual date path).
- If a Session ID line is present in a `#neo` entry without a downstream session-closed or response-event follow-up on the same or subsequent gap day, surface it in the catch-up briefing as:
  `Open Neo session from {date}: {session_id} -- resume with: neo --session <id>`
- Silently skip gap days with no `#neo` tags (no noise for non-Neo sessions).

## Step 3: Present Catch-Up Briefing
Format the output as a concise briefing:

```
Catch-Up: [start-date] -> [today]  (N days)

### [Date] ([Day])
- **Completed**: [summary of completed items]
- **Carried Forward**: [items still pending]
- **Key Notes**: [important entries from Notes section]
- **Blockers**: [any blockers noted]

### [Next Date]...

---
### Current State
- **Active Tasks**: [count] pending across all tiers
- **Top Priorities Today**: [list from today's note]
- **Carried-Forward Blockers**: [any unresolved]
```

## Step 4: Load Today's Note
- After presenting the catch-up, load today's note into context so work can continue.

## Rules
- If there are no previous notes (brand new system), say so and skip the briefing.
- Keep each day's summary to 3-5 lines max — this is a briefing, not a transcript.
- Highlight blockers and carried-forward items prominently.
