---
description: Initialize a new project with STATE.md, staging directory, and INDEX.md entry
user-invocable: true
allowed-tools: [Read, Write, Edit, Bash, Glob, TaskCreate, TaskUpdate]
schema-version: 1
---
# Project Init

Initialize a new project or major task with full orchestration scaffolding.

**Usage**: `/project-init <project-name> [description]`

## Step 1: Parse Arguments
- `$ARGUMENTS` format: `<project-name> [description]`
- First word (or hyphenated phrase): project name
- Remaining words: description (optional)
- If no arguments provided, ask Tyler for the project name and description.

## Step 2: Generate Task ID and Create Directory
- Task ID format: `YYYY-MM-DD-{slug}` (e.g., `2026-04-06-sentinel-phishing-runbook`)
- Create staging directory: `hub/staging/{task-id}/`
- Ensure parent directories exist.

## Step 3: Create STATE.md
Write `hub/staging/{task-id}/STATE.md` with this structure:

```markdown
---
type: state
task-id: "{task-id}"
status: planning
scope: TBD
created: "YYYY-MM-DDTHH:MM"
last-updated: "YYYY-MM-DDTHH:MM"
---
# STATE: {Project Name}

## Macro Goal
{description or "TBD — awaiting Tyler's input"}

## Validation Framework
### Acceptance Criteria
<!-- Tyler to confirm these criteria -->
- [ ] {criterion 1}

### SME Assessor Roles
| Wave | Domain SME | Subdomain SME |
|------|-----------|---------------|
| 1 - Research | TBD | TBD |
| 2 - Plan | TBD | TBD |
| 3 - Build | TBD | TBD |

### Per-Wave Validation
- Wave 1 (Research): Sources verified, claims cross-referenced
- Wave 2 (Plan): Acceptance criteria measurable, steps feasible
- Wave 3 (Build): Tests pass, deliverables match acceptance criteria

## Wave Plan
| Wave | Type | Status | Rounds |
|------|------|--------|--------|
| 1 | Research | pending | 0/2 |
| 2 | Plan | pending | 0/2 |
| 3 | Build | pending | 0/3 |
| 4 | Document | pending | 0/1 |

current-wave: 0
current-round: 0

## Progress Summary
Project initialized. Awaiting scope classification and acceptance criteria from Tyler.

## Artifacts Produced
None yet.

## Open Items
- [ ] Tyler to confirm acceptance criteria
- [ ] Classify scope (passthrough/mini/small/medium/large/ultra)
- [ ] Define SME assessor roles per wave

## Next Action
Ask Tyler for acceptance criteria and scope classification.

## Changelog
| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| YYYY-MM-DDTHH:MM | {task-id} | morpheus | Project initialized |
```

## Step 4: Register the Project
- `hub/state/active-tasks.md` is auto-generated — no manual entry required. The PostToolUse hook regenerates it automatically when STATE.md is written in Step 3.
- Update `INDEX.md` with the new staging directory.
- Create `TaskCreate` entries for:
  - Project setup (completed)
  - Define acceptance criteria (in-progress)
  - Research wave
  - Planning wave
  - Build wave
  - Documentation wave

## Step 5: Document
- Add a timeline entry to today's daily note:
  ```
  ### HH:MM | morpheus | [{task-id}] | #started #plan
  Project initialized: {project name}
  -> [STATE.md](hub/staging/{task-id}/STATE.md)
  ```

## Step 6: Prompt Tyler
Ask Tyler to:
1. Confirm or refine the macro goal
2. Provide acceptance criteria
3. Classify scope (suggest one based on description complexity)

## Rules
- Every project gets a STATE.md — no exceptions.
- The validation framework section MUST be filled in before Wave 1 starts.
- Do not begin orchestration dispatch until Tyler confirms acceptance criteria.
