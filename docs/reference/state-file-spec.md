---
title: "STATE.md File Specification"
last-updated: 2026-04-08
related-files: [.claude/rules/hub.md, hub/patterns/medium.md]
---

# STATE.md File Specification

STATE.md is the single source of truth for every task. It lives at `hub/staging/{task-id}/STATE.md` and is read/updated by all agents throughout the task lifecycle.

## Who Writes What

| Writer | What They Write |
|--------|----------------|
| **Morpheus** | Initial creation: macro goal, validation framework, wave plan |
| **SME Assessor** | Progress summary, artifacts produced, open items, next action, round estimates |
| **Documenter** | Final status update on task completion |

Work agents (gatherer, planner, builder) do **not** write to STATE.md. They write artifacts and return summaries. The SME assessor is the primary STATE.md updater.

## Backup Requirement

Before any update, the writer MUST copy STATE.md to STATE.md.bak:
```bash
cp STATE.md STATE.md.bak
```

This protects against corruption or bad updates.

## File Format

```markdown
---
type: state
task-id: {task-id}
status: {not-started | in-progress | blocked | flagged | completed}
scope: {passthrough | mini | small | medium | large | ultra}
created: {ISO timestamp}
last-updated: {ISO timestamp}
---

# Task: {Human-Readable Task Title}

## Macro Goal

{2-3 sentences describing what this task aims to accomplish and why.}

## Validation Framework

### Acceptance Criteria
- [ ] {Measurable criterion 1}
- [ ] {Measurable criterion 2}
- [ ] {Measurable criterion 3}

### Per-Wave Validation
| Wave | Validation Approach | SME Role |
|------|-------------------|----------|
| 1 (Research) | {what gets checked} | {domain + subdomain} |
| 2 (Planning) | {what gets checked} | {domain + subdomain} |
| 3 (Build) | {what gets checked} | {domain + subdomain} |
| 4 (Docs) | {what gets checked} | {domain + subdomain} |

### Test Strategy
{For code tasks: test framework, test location, test_map.txt path.
For docs: cross-ref verification, section completeness checks.}

## Wave Plan

| Wave | Agent | Purpose | Status |
|------|-------|---------|--------|
| 1 | gatherer | Research | {not-started | in-progress | complete} |
| 2 | planner | Planning | {status} |
| 3 | builder | Build | {status} |
| 4 | documenter | Documentation | {status} |

Current wave: {N}

## Progress Summary

{Timestamped, structured log of completed work. Updated by SME assessor after each round.}

- Wave 1 (Research): COMPLETE — Gatherer produced 3 research artifacts. SME verified all sources. [2026-04-08T14:30]
- Wave 2 (Planning): Round 1 — Planner produced plan. Awaiting assessment. [2026-04-08T15:00]

## Artifacts Produced

| Artifact | Path | Agent | Wave.Round |
|----------|------|-------|------------|
| research-phishing-frameworks.md | hub/staging/{task-id}/research-phishing-frameworks.md | gatherer | 1.1 |
| plan-phishing-runbook.md | hub/staging/{task-id}/plan-phishing-runbook.md | planner | 2.1 |
| assessment-w1r1.md | hub/staging/{task-id}/assessment-w1r1.md | SME: SecOps | 1.1 |

## Open Items

{Questions, blockers, and unresolved issues. Each item has a source and recommended action.}

- [ ] SOC shift structure unknown — affects escalation paths (source: research gap, action: ask Tyler)
- [x] Proofpoint TAP license tier confirmed as Enterprise (resolved by Tyler in Wave 1 checkpoint)

## Estimated Rounds Remaining

| Wave | Estimated | Actual So Far |
|------|-----------|---------------|
| 1 | 2 | 2 |
| 2 | 1 | 1 |
| 3 | 2-3 | 1 (in progress) |
| 4 | 1 | 0 |

## Next Action

{What should happen next. Updated by SME assessor after each verdict.}

Builder fix round: resolve broken escalation-matrix.md cross-reference and tune Query 3 domain age threshold from 30 days to 7 days.
```

## Update Mandate

STATE.md MUST be updated:

1. **After every work agent round** — SME assessor updates progress, artifacts, open items
2. **After every wave completion** — mark wave as done, update current-wave
3. **After every assessor verdict** — record verdict, update next-action
4. **On any status change** — in-progress, blocked, flagged, completed
5. **On cross-session resume** — verify STATE.md matches reality before continuing

## Good vs. Bad Progress Entries

**Good**:
```markdown
- Wave 1 (Research): COMPLETE — Gatherer produced 3 research artifacts covering
  KQL, Sentinel, and SOAR. SME verified all sources. [2026-04-07T14:30]
```

**Bad**:
```markdown
- Did some research
- Working on planning now
```

The bad example lacks timestamps, wave labels, artifact references, and status markers. SME assessors should never write vague progress entries.

## Cross-Session State Files

STATE.md works in concert with two other state files:

### hub/state/active-tasks.md

Auto-generated cross-session task view. **Do not edit manually** — it is regenerated from `hub/staging/*/STATE.md` frontmatter on every Edit/Write via PostToolUse hook (`scripts/utils/generate-active-tasks.sh`).

Each task appears as a section heading block:

```markdown
## {task-id}
- **Scope**: {scope}
- **Status**: {status}
- **Wave**: {current-wave} / **Round**: {current-round}
- **Started**: {created timestamp}
- **Last**: {last-updated timestamp}
- **State**: {relative path to STATE.md}
- **Next**: {first line of ## Next Action section}
```

To update a task's entry, update its `STATE.md` — the view regenerates automatically. Tasks with `status: completed` show a ⚠️ marker until archived via `/eod`.

### hub/state/completed-tasks.md

Archive of finished tasks:

```markdown
| Task ID | Completed | Summary | Key Artifacts |
|---------|-----------|---------|---------------|
| 2026-04-07-setup | 2026-04-07T12:00 | Initial system setup | hub/staging/2026-04-07-setup/STATE.md |
```

On task completion, the documenter moves the entry from active to completed.
