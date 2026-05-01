---
description: Quick idea capture — append a timestamped idea to today's daily note
user-invocable: true
argument-hint: Your idea text here
allowed-tools: [Read, Edit, Bash, Glob]
schema-version: 1
---
# Jot Idea

Quickly capture an idea in today's daily note without disrupting workflow.

## Step 1: Get the Idea
- The user's argument text IS the idea. If no argument provided, ask what the idea is.

## Step 2: Ensure Today's Note Exists
- Check if `notes/YYYY/MM/YYYY-MM-DD.md` exists.
- If not, run: `bash "{{paths.home}}/Documents/TE GW Brain/scripts/utils/ensure-note.sh"`

## Step 3: Append Idea to Ideas & Insights Section
- Read today's daily note.
- Find the `## Ideas & Insights` section.
- Append the idea with a timestamp:

```markdown
- **HH:MM** — [idea text]
```

- If the `## Ideas & Insights` section doesn't exist, create it before `## Tomorrow's Prep` or `## End of Day`.

## Step 4: Confirm
- Output: `💡 Idea captured at HH:MM`

## Rules
- This is a quick-capture command — no analysis, no elaboration, just save and confirm.
- Use 24-hour clock format.
- Do not modify any other section of the note.
- Ideas are freeform text — do not impose structure on what the user writes.
