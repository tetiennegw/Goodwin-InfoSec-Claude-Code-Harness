---
description: Detect patterns suggesting new skill creation or updates — watches for repeated manual steps, corrections, new tool usage
user-invocable: true
allowed-tools: [Read, Glob, Grep, TaskCreate, TaskList]
schema-version: 1
---
# Skill Opportunity Detector

Scan recent work patterns to identify opportunities for new skills or improvements to existing ones. Creates task entries asking Tyler for approval before any changes.

## Step 1: Gather Recent Activity
- Read the last 5-7 daily notes from `notes/YYYY/MM/`.
- Use Glob to find: `notes/YYYY/MM/*.md` and read each note's `## Notes` section.
- Also scan `hub/staging/*/STATE.md` for recent task patterns.

## Step 2: Detect Opportunity Patterns

### Pattern A: Repeated Manual Steps (Automation Candidate)
- Look for the same type of work appearing 3+ times across daily notes.
- Indicators: similar titles, same tags, same file paths modified.
- Example: "Configuration Update" entries for the same type of config appearing repeatedly.

### Pattern B: User Corrections (Skill Improvement Candidate)
- Look for entries mentioning "fix", "correct", "revert", "redo" following agent work.
- Also check for Roadblocks (🚧) that mention agent mistakes or wrong approaches.
- Example: Agent keeps producing output in wrong format → update the skill that drives it.

### Pattern C: New Domain Tags Without Matching Skills
- Extract all unique tags from recent daily notes.
- Compare against existing skills in `.claude/commands/`.
- If a domain tag (e.g., #terraform, #github-actions) appears 3+ times but no skill handles it → gap candidate.

### Pattern D: Repeated Roadblocks
- Look for the same type of roadblock appearing across multiple days.
- If the same blocker keeps recurring, a skill or hook could prevent it.
- Example: "forgot to update INDEX.md" appearing repeatedly → hook opportunity.

### Pattern E: High-Frequency Workflows
- Look for sequences of steps that always happen together.
- If agents consistently chain the same 3+ actions, those could be a single skill.
- Example: "read config → modify → test → commit" always in sequence → skill candidate.

## Step 3: Cross-Reference Existing Skills
- Read all files in `.claude/commands/` to understand current skill coverage.
- For each detected opportunity, check if an existing skill already covers it.
- If a skill exists but doesn't handle the pattern well → improvement candidate.
- If no skill exists → creation candidate.

## Step 4: Create Task Entries
For each detected opportunity, create a task using TaskCreate:

**For new skill candidates:**
```
Subject: "🆕 Skill opportunity: [proposed-skill-name]"
Description: "Pattern detected: [description of the repeated pattern].
Seen in: [dates/notes where pattern appeared].
Proposed skill: [what it would do].
Awaiting Tyler's approval to create."
```

**For skill improvement candidates:**
```
Subject: "🔧 Skill update: [existing-skill-name]"
Description: "Pattern detected: [description of the issue].
Current skill gaps: [what's missing or wrong].
Proposed change: [what to update].
Awaiting Tyler's approval to modify."
```

## Step 5: Report Findings
Present a summary:

```
🔍 Skill Opportunity Scan — [date range]

📊 Notes analyzed: N
🏷️ Unique tags found: N

Opportunities detected:
1. 🆕 [New skill name] — [reason] (seen N times)
2. 🔧 [Existing skill] — [improvement needed] (seen N times)
3. ...

Tasks created: N (pending Tyler's approval)

No action taken — all opportunities await approval.
```

## Rules
- NEVER create or modify skills automatically — only create tasks asking for approval.
- Each opportunity must have evidence (specific dates, notes, patterns cited).
- Minimum threshold: 3 occurrences before flagging as an opportunity.
- Skip patterns that are inherently one-off (incident response, unique investigations).
- This skill can be run manually (/skill-opportunity-detector) or triggered by /weekly-review.
