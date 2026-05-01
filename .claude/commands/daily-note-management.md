---
description: Create or update today's daily note with rich timeline entries documenting work done
user-invocable: true
allowed-tools: [Read, Write, Edit, Bash, Glob]
schema-version: 1
---
# Daily Note Management

You are updating today's daily note to document work that was done. Follow these steps:

## Step 1: Determine Today's Date
- Today's date determines the note path: `notes/YYYY/MM/YYYY-MM-DD.md`
- Example: `notes/2026/04/2026-04-08.md`

## Step 2: Ensure the Daily Note Exists
- Check if the file exists using `Glob` for `notes/YYYY/MM/YYYY-MM-DD.md`.
- If it does NOT exist, run via Bash:
  ```bash
  bash "{{paths.home}}/Documents/TE GW Brain/scripts/utils/ensure-note.sh"
  ```
- If `ensure-note.sh` does not exist, create the note manually using the template at `hub/templates/daily-note.md`. Fill in all date placeholders.

## Step 3: Prepend a Rich Entry to the Notes Section
- Read the current daily note.
- Prepend a new entry BELOW the `## Notes` heading and ABOVE any existing entries (newest first).
- Use this format:

```markdown
- **HH:MM AM/PM** - **Descriptive Title** #tag1 #tag2 #tag3

  **Work Type**: Natural title-case description of the work category

  **Implementation Tasks**:
  - ✅ Concrete completed task
  - ✅ Another task

  **Files Created**:
  - 📝 [[NewFile]] - purpose (~NNN lines)

  **Files Modified**:
  - 📝 [[SomeFile]] - what changed and why
  - 🔧 `path/to/config.ext` - what changed

  **Key Decisions**:
  - 💡 Discovery or insight + rationale
  - 🎯 Strategic choice + why
  - ⚠️ Trade-off or warning + mitigation
  - 🔍 Investigation finding + implication

  **Implementation Results**:
  - Quantitative result (e.g., "reduced 200 lines, 36% reduction")
  - Qualitative outcome or downstream benefit

  **Deliverables Created**:
  - [[Deliverable Name]] - short description

  **Roadblocks**:
  - 🚧 Obstacle encountered and how it was resolved

  **Strategic Value**: Prose paragraph explaining how this advances objectives.

---
```

**Canonical format rules (strictly enforced)**:
1. **12-hour AM/PM clock** (`**03:30 PM**`, `**11:05 AM**`) — NOT 24-hour
2. **Work Type** is natural title-case (`**Implementation Work**`) — NOT bracketed all-caps (`**[WORK TYPE]**` is DEPRECATED)
3. **Blank lines between every `**Field**:` line** are mandatory
4. **Vertical bullet lists** for Files/Tasks/Decisions (one item per bullet, one bullet per line) — NOT inline pipe-separated
5. **Varied emojis in Key Decisions**: 💡 discovery, 🎯 strategy, ⚠️ warning, 🔍 investigation
6. **`---` separator at column 0** (not indented), preceded by a blank line

### Edit Tool Anchor Patterns

New entries are **prepended** (newest first) via the Edit tool — never Write. See `.claude/rules/daily-note.md § Prepend Protocol` for the full 7-step protocol and exhaustive Case A/B/C examples. Quick summary:

- **Case A (fresh note from current template, anchor present, no entries yet):** match the canonical anchor `<!-- PREPEND-ANCHOR:v1 -->` line plus the `<!-- === ENTRY FORMAT ===` boundary. Insert your new entry + blank line between them.
- **Case B (note with existing entries):** match the `<!-- PREPEND-ANCHOR:v1 -->` line plus the existing top entry's `- **HH:MM AM/PM** - **Title**` bullet header. Insert your new entry + `---` separator + blank line immediately after the anchor, leaving the old top entry intact below it.
- **Case C (legacy note without anchor, pre-2026-04-09):** match the `## Notes` heading plus the existing top entry directly. Do **not** backfill the anchor into legacy notes — retrofit protocol governs that.

**Mandatory re-read rule**: when prepending a second entry in the same turn, re-read the file first. Stale `old_string` values (from the previous Edit's echo or your in-context memory) fail Edit loudly and risk duplicate or out-of-order entries.

**Never use Write** — it overwrites the whole file and destroys unrelated sections (Approvals Log, Agenda, etc.).

### Entry Sections — Include Only What's Relevant
Not every entry needs every section. Use your judgment:
- **Always include**: Timestamp + Title + tags, Work Type, Strategic Value
- **Include if applicable**: Files Modified, Key Decisions, Artifacts, Category
- **Include if encountered**: Roadblocks
- A simple config change might only need 4 lines. A major research effort needs the full format.

### File Reference Conventions
- **Markdown files**: `[[File Name]]` (double brackets, no .md extension)
- **Other files**: `'relative/path/to/file.ext'` (single quotes with path)

### Work Type Examples
- Research Completed, Implementation Work, Documentation Created
- Bug Fix Applied, Configuration Update, Investigation Completed
- Analysis Performed, Orchestration Work, Infrastructure Changes
- Security Assessment, Script Development, Skill Creation

### Emoji Guide
**Files**: 📝 markdown, ✏️ edits, 🔧 config, 📊 data, 🐍 Python, 📜 scripts, 🏗️ infrastructure
**Insights**: 💡 discovery, 🎯 strategy, ⚠️ challenge, 🔍 investigation, 🔒 security
**Issues**: 🚧 obstacle, 🔄 retry, ⏳ blocker, ⚡ quick fix, 🔥 critical

### Tag Taxonomy
- **Domain**: #security #automation #api #compliance #infrastructure
- **Action**: #research #plan #build #review #document #incident
- **Tool**: #sentinel #defender #crowdstrike #python #powershell #kql
- **Status**: #started #completed #blocked #flagged
- **Scope**: #mini #small #medium #large #ultra
- **Context**: #goodwin #personal #research #documentation #infrastructure #security

## Step 4: Verify
- Confirm the entry was written correctly by reading back the Notes section.
- Ensure entries remain in reverse chronological order (newest first).

## Rules
- Document work BEFORE responding to the user.
- Keep each entry comprehensive but proportional to the work done.
- Use the **12-hour clock with AM/PM** for timestamps (e.g., `**02:30 PM**`, `**11:05 AM**`), zero-padded hour.
- Always include at least one domain tag and one action tag.
- The `## Summary` section is auto-updated by a separate process — do not edit it.
- Append `---` separator after each entry.
- Tables in entries must start at column 0 (no leading spaces). Add blank lines before and after tables.
