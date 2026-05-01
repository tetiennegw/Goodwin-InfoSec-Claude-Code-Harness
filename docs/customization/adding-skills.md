---
title: "Adding Skills (Slash Commands)"
last-updated: 2026-04-08
related-files: [.claude/hooks/skill-assessor.sh]
---

# Adding Skills (Slash Commands)

Skills are slash commands that users can invoke directly (e.g., `/summarize`, `/triage`). They are markdown files in `.claude/commands/` that Claude Code discovers automatically.

## File Location

```
.claude/commands/
  summarize.md
  triage.md
  weekly-report.md
```

Subdirectories are supported for organization:
```
.claude/commands/
  security/
    triage.md
    hunt.md
  reporting/
    daily.md
    weekly.md
```

## Frontmatter Format

```yaml
---
description: {One-line description shown in skill list}
---
```

The description is extracted by the `skill-assessor.sh` hook and shown to the user when skills are listed.

## File Content

The body of the skill file is a prompt template. When the user invokes the slash command, this content is used as the instruction.

```markdown
---
description: Generate a weekly security summary from daily notes
---

Read the daily notes for this week (notes/{{YYYY}}/{{MM}}/) and produce a
summary covering:

1. Tasks completed (with scope and key deliverables)
2. Open items and blockers
3. Key decisions made
4. Items carrying forward to next week

Write the summary to the current weekly note. Keep it concise — one
paragraph per day maximum.
```

## Example: Creating a /triage Skill

Create `.claude/commands/triage.md`:

```markdown
---
description: Triage a reported phishing email using the SOC runbook
---

A phishing email has been reported. Follow the phishing triage runbook
at kb/runbooks/phishing-triage-runbook.md:

1. Assess the reported email using the triage decision tree
2. Run relevant KQL detection queries from kb/security/kql-phishing-queries.md
3. Determine severity and recommended action
4. Log the triage result to today's daily note with #incident #security tags

User will provide the email details in their follow-up message.
```

Usage: Type `/triage` in the Claude Code session.

## How the Skill Assessor Hook Works

The `UserPromptSubmit` hook (`skill-assessor.sh`) runs on every prompt:

1. Scans `.claude/commands/` for `.md` files
2. Extracts the `description` from each file's YAML frontmatter
3. Performs keyword matching between the description and the user's prompt
4. Outputs the full skill list and any recommendations

This means newly created skills are discoverable immediately — no restart needed.

## Tips

- **Keep descriptions searchable** — include key domain terms for better keyword matching
- **Use placeholders** — `{{YYYY}}`, `{{MM}}`, etc. for date-dependent skills
- **Reference existing files** — point to KB articles, runbooks, or templates rather than duplicating instructions
- **Test invocation** — run the slash command and verify it behaves as expected
