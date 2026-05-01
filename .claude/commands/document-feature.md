---
description: Create or update an Morpheus feature doc under docs/morpheus-features/. Proactively surfaces doc debt when features/architecture change.
user-invocable: true
argument-hint: (optional) new <slug> | update <slug> | list | audit
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion]
schema-version: 1
---
# /document-feature

Create, update, audit, and surface documentation for Morpheus features. This skill is the counterpart to the `feature-change-detector.sh` hook — the hook detects that a feature has changed and logs doc debt to the daily note; this skill is how Tyler works through that debt (or creates docs proactively).

## Philosophy

Morpheus grows feature-by-feature. Without discipline, documentation drifts silently: new skills land without entries in `CLAUDE.md`, hook changes land without updates to feature docs, architecture evolves without the README catching up. The cost isn't immediate — but when Tyler open-sources Morpheus to the Goodwin security team, every undocumented feature becomes a support ticket.

This skill (plus the detector hook) makes doc debt **visible at the moment it's incurred**, and gives Tyler a direct command to pay it down.

## Modes

| Invocation | Behaviour |
|---|---|
| `/document-feature new <slug>` | Create a new feature doc from `_template.md`. Prompt for title, tags, brief summary. Auto-update CLAUDE.md, INDEX.md, and the features README index. |
| `/document-feature update <slug>` | Revise an existing feature doc. Prompt Tyler for what changed. Update last-updated, append changelog entry, push reminder to CLAUDE.md/INDEX.md if needed. |
| `/document-feature list` | Print the feature index from `docs/morpheus-features/README.md` with last-updated dates and stale-check flags. |
| `/document-feature audit` | Deep scan: walk every `.claude/commands/*.md`, `.claude/hooks/*`, and `scripts/*/` directory; check each against `docs/morpheus-features/`; flag features that have source code but no feature doc. |
| `/document-feature` (no arg) | Default to `audit` if there are pending items from the detector hook; otherwise `list`. |

## Prerequisites

- `docs/morpheus-features/` directory exists (seeded by task `2026-04-17-morpheus-feature-docs`).
- `docs/morpheus-features/_template.md` exists (required for `new` mode).
- `docs/morpheus-features/README.md` exists (required for `list` and for updating index on `new`).

If any prerequisite is missing, output `docs/morpheus-features/ scaffold is incomplete — run /the-protocol "rebuild morpheus-features scaffold" first.` and exit.

---

## Mode: new

**Intent**: create a feature doc for a newly-added Morpheus feature.

### Step 1 — Parse slug

Accept slug as the argument after `new`. Validate: lowercase, hyphen-separated, no spaces. If missing, prompt via `AskUserQuestion`:

```
Question: "What is the feature slug? (lowercase-hyphen-separated, e.g. o365-planner-integration)"
Options: N/A — use the free-text fallback
```

### Step 2 — Check for conflicts

Before creating anything, check that `docs/morpheus-features/<slug>.md` does NOT already exist. If it does:

```
Question: "docs/morpheus-features/<slug>.md already exists. What should happen?"
Options:
  - "Switch to update mode"  -- description: "Run /document-feature update <slug> instead"
  - "Overwrite"              -- description: "Destroy existing doc and start fresh (NOT recommended)"
  - "Cancel"                 -- description: "Exit without changes"
```

### Step 3 — Gather metadata via AskUserQuestion (never inline)

Ask up to 4 questions in a single `AskUserQuestion` call:

1. **Feature title** (human-readable) — free-text
2. **Primary tags** — multiSelect from {orchestration, planner, hooks, notes, ingest, skills, scripts, security, integration, automation}
3. **Current status** — single-select from {draft, active, deprecated}
4. **Owner** — defaults to "{{user.name}}"

### Step 4 — Generate the file

Copy `docs/morpheus-features/_template.md` to `docs/morpheus-features/<slug>.md` via the Read+Write pattern (never Bash cp, so the PostToolUse hook fires and INDEX.md updates). Substitute every `{placeholder}` with the gathered metadata. Leave section bodies as hints for Tyler to fill in later — do NOT hallucinate feature details.

Record in the file frontmatter:
- `created: <today>`
- `last-updated: <today>`
- `last-verified: <today>`

### Step 5 — Update the features README index

Edit `docs/morpheus-features/README.md` — prepend a new row to the Index table. Row format:

```
| <N> | <Title> | [`<slug>`](<slug>.md) | <status> | ⬚ pending |
```

(Tyler flips the last column to ✅ when the doc is complete.)

### Step 6 — Update CLAUDE.md

If the feature corresponds to a skill registered in the skills table, verify the table row already references the feature doc. If not, prepend a new row:

```
| /<feature-command> | <short purpose> |
```

If the feature isn't a skill (it's a hook, a script module, or an architectural subsystem), skip CLAUDE.md update — but add a reference under an appropriate Key Files section if it's missing.

### Step 7 — Update INDEX.md

The PostToolUse hook should auto-add the new file, but verify by grepping INDEX.md for `morpheus-features/<slug>.md`. If missing, manually add under the **Documentation** section.

### Step 8 — Log to daily note

Prepend a timeline entry per `.claude/rules/daily-note.md` Prepend Protocol:

```markdown
- **HH:MM AM/PM** - **Feature Doc Created: <Title>** #docs #morpheus-features

  **Work Type**: Documentation — New Feature Doc

  **Files Created**:
  - 📝 [[<slug>]] - docs/morpheus-features/<slug>.md

  **Files Modified**:
  - 📝 [[README]] - docs/morpheus-features/README.md (added to index)
  - 📝 [[CLAUDE]] - skills table updated (if skill)
  - 📝 [[INDEX]] - artifact indexed

  **Strategic Value**: Feature doc skeleton in place. Tyler can now fill in the Architecture and User Flows sections without blocking on scaffolding.
```

### Step 9 — Output summary

```
Feature doc scaffolded: docs/morpheus-features/<slug>.md
Next steps:
  1. Fill in ## Architecture (Mermaid diagrams for non-trivial flows)
  2. Fill in ## User Flows (at least one concrete example)
  3. Verify ## Configuration table lists every config file
  4. Run /document-feature update <slug> when done to flip status to 'active'
```

---

## Mode: update

**Intent**: a feature has changed — update its doc to reflect the new reality.

### Step 1 — Parse slug + verify file exists

If `docs/morpheus-features/<slug>.md` does not exist, suggest `new` mode and exit.

### Step 2 — Gather change description via AskUserQuestion

```
Question: "What changed? (Used for changelog entry + last-updated bump)"
Options: N/A — free-text
```

### Step 3 — Preview the current frontmatter

Read the file. Show Tyler the current frontmatter + any section that has `<!-- TODO -->` or `{placeholder}` markers. Prompt:

```
Question: "Which sections need revision?"
Options (multiSelect):
  - "Overview"
  - "Architecture / diagrams"
  - "User flows"
  - "Configuration"
  - "Integration points"
  - "Troubleshooting"
  - "References"
```

### Step 4 — Guide Tyler through each selected section

For each chosen section, open the relevant block via `Read` + line offset, prompt Tyler for the revision, Edit the file in place. Preserve frontmatter structure; bump `last-updated` to today; append a changelog entry.

### Step 5 — Check for cascading updates

After the edit, check:
- Does `CLAUDE.md` reference this feature? If so, is the reference still accurate?
- Is there a related runbook under `docs/reference/`? If so, does it need a matching update?
- Is there a related ADR under `docs/decisions/`? If a major architectural change, propose writing a new ADR.

Surface any cascading updates via `AskUserQuestion`:

```
Question: "This change affects {N} other files. Update them now?"
Options:
  - "Update all now"
  - "Update critical only (CLAUDE.md, INDEX.md)"
  - "Defer cascading updates" -- description: "Add to daily note ## Approvals Pending"
```

### Step 6 — Log to daily note

Similar format as new mode; work type "Documentation — Feature Update".

---

## Mode: list

**Intent**: show all feature docs with freshness/status flags.

### Step 1 — Read the features README

Parse the index table from `docs/morpheus-features/README.md`.

### Step 2 — For each row, read the target doc frontmatter

Extract `last-verified` and `review-interval`. Flag stale if `(today - last-verified) > review-interval`.

### Step 3 — Output a flat table

```
Morpheus Feature Docs (as of <today>)
========================================
#  Slug                            Status    Last Verified    Freshness
1  o365-planner-integration        active    2026-04-17       fresh
2  orchestration-loop              draft     —                new
...
```

No file writes in list mode.

---

## Mode: audit

**Intent**: find Morpheus features (skills, hooks, modules) that have source code but no feature doc.

### Step 1 — Enumerate candidate features

Build three lists:
- Skills: every `.md` file under `.claude/commands/` (minus `init.md`, `review.md`, `security-review.md` which are stock Claude Code skills, and minus any file explicitly tagged `morpheus-internal: true`)
- Hooks: every file under `.claude/hooks/` (shell + powershell, minus utility hooks like `prepend-reminder.sh` which are scaffold not features)
- Modules: every subdirectory under `scripts/` that has a `.psm1` or a cluster of `.py`/`.sh` files

### Step 2 — Cross-check against docs/morpheus-features/

For each candidate, check if a file exists at `docs/morpheus-features/<derived-slug>.md` OR if the feature is referenced by slug in `docs/morpheus-features/README.md` index. Candidates with no match are **doc gaps**.

### Step 3 — Present gaps via AskUserQuestion

```
Question: "Audit found N doc gaps. What would you like to do?"
Options:
  - "Create all now (run /document-feature new <slug> for each)" -- description: "Will walk through each one sequentially"
  - "Pick which ones to create"
  - "Log all to daily note todo list" -- description: "Add each as a pending item under Tomorrow's Prep"
  - "Cancel" -- description: "Exit without changes"
```

### Step 4 — Execute the chosen path

Act on the selection. For "Log all", prepend entries to today's daily note under the appropriate section.

---

## Integration with feature-change-detector.sh

The hook at `.claude/hooks/feature-change-detector.sh` runs on PostToolUse (Edit|Write) for paths under `.claude/commands/**`, `.claude/hooks/**`, and `scripts/**`. When a match fires, it appends a line to today's daily note under a managed `## Tomorrow's Prep` subsection:

```
- [ ] Doc review: <feature-slug> changed in this session — run /document-feature update <slug>
```

Tyler can then batch-process these by running `/document-feature` (no arg) which defaults to `audit` when the detector has logged items.

**Do not auto-run this skill from the hook.** The hook only surfaces. Tyler always drives — that's the explicit separation of concerns.

---

## Rules

1. **Never auto-write documentation content.** This skill scaffolds + surfaces + asks questions. Tyler writes the prose. The only exception: frontmatter metadata gathered via AskUserQuestion.
2. **Always use AskUserQuestion for clarifications, never inline chat.** Same rule as every other skill.
3. **Every mode logs to the daily note.** Even `list` logs a timeline entry if it surfaced stale docs (so there's a trail of doc-health audits).
4. **CLAUDE.md skills table + docs/morpheus-features/README.md index + INDEX.md must stay in sync.** If one mode updates one, it updates the others.
5. **Detector hook only appends to Tomorrow's Prep.** Never modifies feature docs directly. This skill is the only thing that edits docs.
6. **`new` mode copies from `_template.md`**, never generates a doc from scratch — keeps all feature docs structurally consistent.
7. **`audit` mode is read-only by default.** It proposes actions via AskUserQuestion; Tyler must approve before any writes happen.

---

## Changelog

| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-17T10:40 | 2026-04-17-morpheus-feature-docs | morpheus | Created /document-feature skill with 4 modes (new, update, list, audit); wired to feature-change-detector.sh hook for proactive doc-debt surfacing |
