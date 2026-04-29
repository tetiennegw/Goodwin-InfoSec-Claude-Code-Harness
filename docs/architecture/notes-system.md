---
title: "Notes System"
last-updated: 2026-04-08
related-files: [hub/templates/daily-note.md, hub/templates/weekly-note.md, scripts/utils/ensure-note.sh, scripts/utils/note-summary-updater.ps1]
---

# Notes System

## Hierarchy

Notes follow a time-based hierarchy. Higher-level notes aggregate from lower-level ones.

```
notes/
  2026/
    2026.md                    # Yearly note
    2026-Q2.md                 # Quarterly note
    2026-W15.md                # Weekly note
    2026-04.md                 # Monthly note
    04/
      2026-04-08.md            # Daily note
      2026-04-09.md
```

| Level | File | Created By | Content |
|-------|------|------------|---------|
| **Daily** | `notes/YYYY/MM/YYYY-MM-DD.md` | ensure-note.sh (SessionStart hook) | Rich timeline entries, priority-tiered tasks with rollover, meetings, ideas, tomorrow's prep |
| **Weekly** | `notes/YYYY/YYYY-WNN.md` | ensure-note.sh | Links to daily notes, weekly summary |
| **Monthly** | `notes/YYYY/YYYY-MM.md` | ensure-note.sh | Links to weekly notes, monthly themes |
| **Quarterly** | `notes/YYYY/YYYY-QN.md` | ensure-note.sh | Links to monthly notes, quarterly goals |
| **Yearly** | `notes/YYYY/YYYY.md` | ensure-note.sh | Links to quarterly notes, annual objectives |

## Daily Note Structure

Each daily note contains these sections:

| Section | Purpose |
|---------|---------|
| **Summary** | Auto-updated by note-summary-updater.ps1 — do not manually edit |
| **Agenda & Tasks** | Priority-tiered tasks (Top/Secondary/Tertiary/Other) with rollover |
| **Notes** | Rich timeline entries from agents and Tyler (newest first) |
| **Meetings** | Meeting notes and action items |
| **Ideas & Insights** | Quick idea captures via /jot-idea |
| **Tomorrow's Prep** | Items to carry into next day's Top Priority |
| **End of Day** | Completed/carried forward/blockers — filled by /eod |

Navigation links at the top: `<< [[prev-date]] | Today | [[next-date]] >> | Week: [[week]]`

## Rich Timeline Entries

Daily note entries under `## Notes` use a rich format with optional sections:

```markdown
- **14:30** - **[Built phishing triage runbook]** #security #build #sentinel #medium

  **Implementation Work**: Created NIST 4-phase runbook with 5 KQL detection queries.

  **Files Modified**:
  - 📝 [[phishing-triage-runbook]] - Initial creation with 4 phases
  - 🔧 'scripts/kql/phishing-detect.kql' - 5 new detection queries

  **Key Decisions**:
  - 💡 Used NIST framework over SANS — better alignment with Goodwin compliance

  **Artifacts**:
  -> [[phishing-triage-runbook]](../../kb/runbooks/phishing-triage-runbook.md)
  -> [[STATE.md]](../../hub/staging/2026-04-08-phishing-runbook/STATE.md)

  **Strategic Value**: Reduces mean-time-to-respond for phishing incidents by standardizing triage.

---
```

### Entry Sections
- **Always include**: Timestamp + Title + tags, Work Type, Strategic Value
- **Include if applicable**: Files Modified, Key Decisions, Artifacts, Category
- **Include if encountered**: Roadblocks
- Entries are prepended (newest first). Separator `---` after each entry.

### File Reference Conventions
- Markdown files: `[[File Name]]` (double brackets, no .md extension)
- Other files: `'relative/path/to/file.ext'` (single quotes with path)

## Tag Taxonomy

Every timeline entry includes tags for filtering:

| Category | Tags |
|----------|------|
| **Domain** | #security #automation #api #compliance #infrastructure |
| **Action** | #research #plan #build #review #document #incident |
| **Tool** | #sentinel #defender #crowdstrike #python #powershell #kql |
| **Status** | #started #completed #blocked #flagged |
| **Scope** | #mini #small #medium #large #ultra |
| **Context** | #goodwin #personal #research #documentation #infrastructure #security |

Tags are flexible. New ones emerge naturally from work. The above seeds the standard vocabulary.

## Task Rollover

### Priority Tiers
Daily notes organize tasks into four priority tiers:
- **Top Priority**: Fresh each day (3 blank slots). Yesterday's "Tomorrow's Prep" items populate here.
- **Secondary Priority**: Rolled over from previous day's Secondary.
- **Tertiary Priority**: Rolled over from previous day's Tertiary.
- **Other Tasks**: Rolled over from previous day's Other.

### Stale Tagging
Tasks that remain incomplete accumulate stale markers based on their origin date:

| Age | Marker | Meaning |
|-----|--------|---------|
| 14+ days | ⏰ | Getting old — consider prioritizing |
| 30+ days | ⚠️ | Stale — evaluate if still relevant |
| 60+ days | 🔴 | Very stale — likely needs reclassification |
| 90+ days | 💀 | Ancient — remove or escalate |

Origin tracking uses invisible HTML comments: `<!-- origin: YYYY-MM-DD -->`

### Deduplication
Tasks are deduplicated by normalized text (stripping checkboxes, stale markers, and origin comments). The first occurrence is kept.

### Carry-Forward
- **Ideas & Insights**: Unchecked items carry forward to the next day's Ideas section.
- **Tomorrow's Prep**: Unchecked items carry into the next day's Top Priority.

## Auto-Creation via ensure-note.sh

The `scripts/utils/ensure-note.sh` script runs on every SessionStart hook. It:

1. Computes today's date and derives week/month/quarter/year values
2. Computes navigation dates (previous day, next day)
3. Checks if each note level exists
4. Copies from the corresponding template in `hub/templates/`
5. Fills date placeholders (including nav links and week references)
6. For daily notes: finds the most recent previous note (up to 7 days back)
7. Extracts incomplete tasks from each priority tier
8. Applies stale tagging based on origin date
9. Deduplicates and inserts rolled-over tasks
10. Carries forward unchecked ideas and tomorrow's prep items
11. Reports what was created, skipped, and how many tasks were rolled over

## Summary Updater

The `scripts/utils/note-summary-updater.ps1` PowerShell script runs every 15 minutes (or manually) to:

1. Read today's daily note
2. Parse the Notes section for new entries since last update
3. Regenerate the Summary section at the top
4. Update the `last-summary-update` and `summary-hash` fields in frontmatter

## Daily Note Commands

| Command | Purpose |
|---------|---------|
| `/daily-note-management` | Add rich timeline entries to today's note |
| `/read-today` | Load today's note into context with stats |
| `/create-daily-notes` | Create today's note or backfill N days with rollover |
| `/catch-up` | Summarize missed days since last session |
| `/jot-idea` | Quick idea capture to Ideas & Insights section |
| `/eod` | End of day wrap-up with priority-tier breakdown |

## How Agents Log to Daily Notes

The **documenter** agent is responsible for adding timeline entries to daily notes during the documentation wave. Other agents do not write to notes directly — they write artifacts, and the documenter creates the rich entries.

Entries are **prepended** (newest first) to the `## Notes` section.
