---
description: Weekly review — aggregate daily notes, extract patterns, detect automation candidates, update priorities
user-invocable: true
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep]
schema-version: 1
---
# Weekly Review

Aggregate the week's work, extract patterns, identify automation candidates, and set next week's priorities.

## Step 1: Gather Daily Notes
- Determine the date range for the review (past 5-7 days, Monday through Friday).
- Use `Glob` to find daily notes: `notes/YYYY/MM/YYYY-MM-DD.md` for each day in range.
- Read the Timeline and End of Day sections from each note.

## Step 2: Aggregate Tag Frequencies
- Extract all `#tags` from timeline entries across the week.
- Count occurrences of each tag.
- Report the top 10 tags as a frequency table.
- Identify recurring themes (e.g., if `#incident` appears 3+ times, flag a pattern).

## Step 3: Check Knowledge Base Staleness
- Use `Glob` to find knowledge articles: `kb/**/*.md`
- For articles with `last-verified` in frontmatter, check if the date is older than the article's `review-interval`.
- List any stale articles that need review.
- Check `procedures/**/*.md` for the same staleness pattern.

## Step 4: Review Feedback Log
- Read `memory/feedback_log.md` if it exists.
- Look for recurring feedback patterns (same issue flagged multiple times).
- Summarize any systemic issues that need process changes.

## Step 5: Identify Automation Candidates
- Review timeline entries for tasks performed 3+ times manually during the week.
- Flag these as automation candidates with a brief description of what could be automated.
- Examples: repeated KQL query generation, recurring report formatting, repeated incident triage patterns.

## Step 5a: Harness Metrics Review (Meta-Harness Self-Improvement Loop)

Read `hub/state/harness-metrics.md` (generated nightly by `scripts/utils/generate-harness-metrics.ps1`). For each of the 8 metrics:
- Compare current value to target from `docs/morpheus-features/north-star-standard.md` §2.2
- Flag any metric below target as a harness-health alert

Cross-reference alerts with `hub/state/replay-corpus/` — is any existing canonical failure case recurring? If yes, that's a regression; propose a specific amendment (rule edit, hook tune, new check). If no but audit ledger shows new `RESULT:FAIL` incidents, those are candidates for new replay-corpus cases.

Record in the weekly note under `## Harness Health`:

```markdown
## Harness Health
- Metrics slipping: {list with current-vs-target OR "none"}
- Replay-corpus regressions: {case name OR "none"}
- New failure candidates (ledger `FAIL` rows not yet canonicalized): {count + short summary}
- Proposed amendments: {specific action items tied to files/rules to change OR "none"}
```

If Proposed amendments is non-empty, open a new harness task via `/the-protocol` describing the amendments (scope: Medium unless scope cascade requires Large+).

## Step 5b: Roadmap Sweep (Project-Roadmap Self-Improvement Loop)

Read `hub/state/roadmap.md`. For each active entry:
- Verify `last-touched` is within the entry's `review-cadence`
- Check whether the project's STATE.md has advanced (wave/round changed) in the last week
- Flag stale entries (past review-cadence with no advance) as "stalled — re-prioritize?"

Record in the weekly note under `## Roadmap`:

```markdown
## Roadmap
- Stalled (past review-cadence): {list of project slugs OR "none"}
- Newly added this week: {list OR "none"}
- Suggested next week priorities (from roadmap intersecting with harness metrics + automation candidates): {1-3 items}
```

## Step 6: Generate Weekly Note
- Create the weekly note at `notes/YYYY/YYYY-WNN.md` (ISO week number).
- Structure:

```markdown
---
type: weekly-review
week: YYYY-WNN
date-range: "YYYY-MM-DD to YYYY-MM-DD"
created: "YYYY-MM-DDTHH:MM"
---
# Weekly Review — YYYY-WNN

## Week Summary
{3-5 sentence summary of the week's work}

## Metrics
- Tasks completed: {count}
- Tasks carried forward: {count}
- Incidents: {count}
- New KB articles: {count}

## Tag Frequency
| Tag | Count | Trend |
|-----|-------|-------|
| #security | N | |
| #automation | N | |

## Patterns Identified
- {pattern 1}
- {pattern 2}

## Automation Candidates
| Task | Frequency | Effort Estimate | Suggested Approach |
|------|-----------|-----------------|-------------------|
| | | | |

## Stale Knowledge Articles
| Article | Last Verified | Review Interval | Path |
|---------|--------------|-----------------|------|
| | | | |

## Next Week Priorities
1. {priority 1}
2. {priority 2}
3. {priority 3}
```

## Step 7: Update Priorities
- Update `memory/priorities.md` with next week's focus areas.
- Carry forward any unresolved blockers from this week.

## Rules
- Weekly reviews are analytical — identify patterns, do not just list events.
- Automation candidates should have concrete suggestions, not vague observations.
- If fewer than 3 daily notes exist for the week, note this as a gap and suggest better daily note discipline.
- The weekly note goes in `notes/YYYY/` (year directory), not the month subdirectory.
