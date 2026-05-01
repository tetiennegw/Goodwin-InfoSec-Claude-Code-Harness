---
title: "Changelog Standard"
last-updated: 2026-04-08
related-files: [.claude/rules/hub.md]
---

# Changelog Standard

Every artifact in `hub/**` and every deliverable must include a changelog. Maximum 10 entries, newest first.

## Format for Markdown Artifacts

Include a `## Changelog` section at the bottom of the file:

```markdown
## Changelog

| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-08T16:00 | phishing-runbook | SME: SecOps | Assessment round 2 — verdict ADVANCE |
| 2026-04-08T15:45 | phishing-runbook | builder | Added detection logic per assessment feedback |
| 2026-04-08T15:30 | phishing-runbook | builder | Created initial runbook draft |
```

### Column Definitions

| Column | Content |
|--------|---------|
| **Timestamp** | ISO 8601 format: `YYYY-MM-DDTHH:MM` |
| **Project** | Task ID (matches the staging directory name) |
| **Agent** | Agent type that made the change (e.g., `builder`, `SME: SecOps + KQL Specialist`, `gatherer`) |
| **Change** | One-line description of what changed |

## Format for Code Files

Place a changelog in the comment header block at the top of the file:

```python
# ============================================================
# Task: 2026-04-08-phishing-runbook
# Agent: builder
# Created: 2026-04-08T15:30
# Last-Updated: 2026-04-08T16:00
# Plan: hub/staging/2026-04-08-phishing-runbook/plan-phishing-runbook.md
# Purpose: KQL detection queries for phishing triage
# Changelog (max 10):
#   2026-04-08T16:00 | phishing-runbook | builder | Fixed Query 3 threshold per SME feedback
#   2026-04-08T15:30 | phishing-runbook | builder | Created initial 5 KQL detection queries
# ============================================================
```

For KQL files, use `//` comments:

```kql
// Changelog (max 10):
//   2026-04-08T16:00 | phishing-runbook | builder | Fixed domain age threshold
//   2026-04-08T15:30 | phishing-runbook | builder | Initial 5 detection queries
```

## Rules

1. **Maximum 10 entries** — when a new entry would exceed 10, remove the oldest
2. **Newest first** — most recent entry at the top
3. **One line per change** — keep descriptions concise
4. **Every modification** — add an entry for every substantive change to the file
5. **Agent attribution** — always identify which agent made the change

## Enforcement

SME assessors check changelog presence and accuracy as part of their validation:
- Missing changelog: `CONTINUE` verdict (not `ADVANCE`)
- Stale changelog (file modified but no new entry): `CONTINUE` verdict
- Inaccurate changelog (claims changes that did not happen): `CONTINUE` with specific correction needed

## YAML Frontmatter

In addition to the changelog section, markdown artifacts require frontmatter with timestamps:

```yaml
---
type: research
task-id: 2026-04-08-phishing-runbook
agent: gatherer
created: 2026-04-08T14:30
last-updated: 2026-04-08T15:00
inputs:
  - memory/company_context.md
  - kb/security/email-gateway-config.md
---
```

The `last-updated` field must match the newest changelog entry timestamp.
