---
globs: notes/**
schema-version: 1
---

# Daily Note Rules

This rule is auto-loaded for all `notes/**` paths. It defines the approval workflow, section invariants, and rules that agents (including the main Claude session) MUST follow when touching daily notes.

---

## Section Invariants

Every daily note created from the template has these sections, in this order:

1. **Summary** — auto-updated, never manually edited by agents
2. **Agenda & Tasks** — Top/Secondary/Tertiary/Other priority buckets
3. **Notes** — rich timeline entries (newest first), manually edited
4. **Approvals Pending** — deferred high-risk cascades awaiting Tyler's decision
5. **Approvals Log** — append-only audit trail of applied/denied decisions
6. **Meetings** — meeting notes
7. **Ideas & Insights** — freeform idea capture
8. **Tomorrow's Prep** — carryover items
9. **End of Day** — completed / carried forward / blockers

Do NOT reorder, rename, or merge these sections. If a section is missing (e.g., retrofitting an older note), insert it in its canonical position.

---

## Approval Lifecycle

High-risk cascades from `/ingest-context` (or other skills needing approval) follow this lifecycle:

```
Raised
  │
  ├── (Apply now answer)   → Applied   → logged in ## Approvals Log with ✓
  ├── (Defer answer)       → Deferred  → entry in ## Approvals Pending
  │                                      ↓
  │                                    /approve-pending or box-check
  │                                      ↓
  │                                    Apply / Defer / Deny re-prompt
  └── (Deny answer)        → Denied    → logged in ## Approvals Log with ✗
```

### Rules

1. **All approval decisions must go through `AskUserQuestion`**. The daily note is a log surface, not a command surface. Checking a box does NOT execute the change — it triggers a confirmation re-prompt.
2. **Claude must NEVER auto-check an approval checkbox.** Only Tyler checks boxes. Agents writing to `## Approvals Pending` always write `- [ ]` (unchecked).
3. **Claude must NEVER modify existing entries in `## Approvals Log`.** New decisions are **prepended** to the top of the log (newest first), but prior entries are **immutable audit history** — never edit them. Insertion uses prepend semantics (new entries on top); the "append-only" label refers to the immutability of existing rows, not the insertion position.
4. **Original timestamps are preserved across state transitions.** A cascade raised at 09:15 today and deferred, then applied tomorrow at 14:30, shows as: raised 09:15 in the original `## Approvals Pending` entry (which is then deleted), and logged in `## Approvals Log` with both timestamps: "14:30 ✓ ... (originally raised 09:15 on 2026-04-09)".
5. **Deferred items live in the day they were raised**, not the day they get acted on. When `/approve-pending` processes a prior day's note, it writes receipts to that prior day's note, not today's.
6. **Missing task IDs are a red flag.** Every `## Approvals Pending` entry must reference a session task via `(task: <id>)`. If Claude sees an entry without a task ID, flag it as orphaned and ask Tyler before acting.

---

## Session Start Scan

At session start (via SessionStart hook or the first user prompt of a session), Claude MUST:

1. Read today's daily note and the last 3 days' notes.
2. Extract any open `## Approvals Pending` entries (checkbox `- [ ]`).
3. Surface them in the first response as a summary:
   ```
   You have N deferred approval(s):
   - [HH:MM YYYY-MM-DD] <title>
   - [HH:MM YYYY-MM-DD] <title>
   Run /approve-pending to revisit them.
   ```
4. Do NOT auto-invoke `/approve-pending` — let Tyler decide whether to act on them now.

---

## Timeline Entry Format (Notes section)

Rich timeline entries go under `## Notes` (newest first). The canonical format uses natural title-case field names, 12-hour AM/PM timestamps, and vertical bullet lists for multi-item fields.

**Canonical example:**

```markdown
- **HH:MM AM/PM** - **Descriptive Title** #tag1 #tag2 #tag3

  **Work Type**: One-sentence natural description of what kind of work this is

  **Implementation Tasks**:
  - ✅ Concrete task completed
  - ✅ Another concrete task
  - ✅ Third task

  **Files Created**:
  - 📝 [[FileName]] - what it is (~NNN lines)
  - 📝 [[AnotherFile]] - purpose

  **Files Modified**:
  - 📝 [[SomeFile]] - what changed and why
  - 🔧 `relative/path/to/config.ext` - what changed

  **Key Decisions**:
  - 💡 Discovery or insight + rationale
  - 🎯 Strategic choice + why
  - ⚠️ Trade-off or warning + mitigation
  - 🔍 Investigation finding + implication

  **Implementation Results**:
  - Quantitative result (e.g., "CLAUDE.md reduced by ~200 lines, 36% reduction")
  - Qualitative outcome
  - Reusability or downstream benefit

  **Deliverables Created**:
  - [[Deliverable Name]] - short description
  - External artifact reference

  **Strategic Value**: One-paragraph prose explanation of how this advances Tyler's objectives, the project, or the orchestration system. This field is required on every entry.

---
```

### Field Rules

**Required fields** (every entry):
- Header line: `- **HH:MM AM/PM** - **Title** #tags`
- `**Work Type**`: natural title-case description of the work category
- `**Strategic Value**`: prose paragraph explaining why this matters

**Optional fields** (include when relevant, omit otherwise):
- `**Implementation Tasks**` — bulleted ✅ list of concrete completed tasks
- `**Files Created**` — bulleted 📝 list, one file per bullet
- `**Files Modified**` — bulleted 📝 / 🔧 list, one file per bullet
- `**Key Decisions**` — bulleted list with varied emojis per decision type (💡 discovery, 🎯 strategy, ⚠️ warning, 🔍 investigation)
- `**Implementation Results**` — bulleted list of measurable/observable outcomes
- `**Deliverables Created**` — bulleted list of named outputs with wiki-links
- `**Artifacts**` — bulleted list of pointers to hub/staging/ or external artifacts
- `**Roadblocks**` — bulleted 🚧 list of obstacles encountered + resolution

### Formatting Rules (strictly enforced)

1. **Time format**: 12-hour clock with AM/PM, zero-padded hour (`**03:30 PM**`, `**11:05 AM**`). Not 24-hour.
2. **Work type**: Natural title-case (`**Implementation Work**`, `**Bug Fix**`, `**Standards Work**`). **NOT** bracketed all-caps (`**[WORK TYPE]**` is DEPRECATED).
3. **Blank lines between fields are MANDATORY.** Without a blank line between each `**Field**:` line, markdown renderers (Obsidian, GitHub, most preview tools) collapse the entire entry into a single run-on paragraph. The 2-space indentation on each field preserves the bullet's visual grouping while the blank lines create rendered paragraph breaks.
4. **Vertical bullet lists**: Files, tasks, decisions, and results use one bullet per item on its own line — **NOT** inline pipe-separated (`📝 file1 | 📝 file2` is DEPRECATED).
5. **Bullet indentation**: Field-level bullets (under `**Files Modified**:`) indent 2 spaces past the bullet marker to stay inside the entry.
6. **Wiki-links for markdown files**: `[[FileName]]` without extension. Single-quoted path for non-markdown: `` `config.json` ``.
7. **Separator**: `---` at column 0 (NOT indented) between entries, preceded by a blank line. An indented `---` stays inside the bullet and doesn't render as a horizontal rule.
8. **Tags**: space-separated, kebab-case, at least one domain tag and one action tag (e.g., `#security #investigation`).
9. **Neo tag**: Timeline entries logging Neo invocations MUST include `#neo` tag and the Neo session id (if known) in the entry body for cross-session resume.

---

## Prepend Protocol

Entries in `## Notes` are strictly **newest-first**. New entries are **prepended** (inserted at the top), never appended. This section defines the exact mechanic agents must follow.

### 7-Step Protocol

1. **Get timestamp** — `date '+%H:%M'` (24-hour, project convention)
2. **Locate today's note** — `notes/YYYY/MM/YYYY-MM-DD.md`. Glob is safe here (no `[W]##` brackets in this project's paths)
3. **Read the current `## Notes` section** to identify the top entry or confirm empty. **Mandatory even when prepending a second entry in the same turn** — the previous Edit's echo is not a reliable source of truth; file state can drift
4. **Construct the entry** per `## Timeline Entry Format` above
5. **Use the Edit tool to prepend** — match the canonical anchor (see Edit Anchor Patterns below). Never use Write (it overwrites the whole file)
6. **Verify** — re-read the Notes section. Confirm: new entry sits above all prior entries; `---` separators intact; 2-space indentation on sub-content preserved; no duplicate entries
7. **Respond to the user only after steps 1–6 are complete**

### Canonical Anchor

The project-wide anchor string is exactly:

```
<!-- PREPEND-ANCHOR:v1 — insert new entries immediately below this line. See .claude/rules/daily-note.md § Prepend Protocol. -->
```

It appears exactly once per daily note, on its own line, directly below the `## Notes` heading. It is placed there automatically when a new note is created from `hub/templates/daily-note.md`. The entire anchor (including instructional text) is wrapped inside the HTML comment so nothing renders visibly in Obsidian. Edit-tool `old_string` matches are uniquely resolvable by this anchor.

### Edit Anchor Patterns

**Case A — Fresh note from current template (anchor present, no entries yet)**

```
old_string:
## Notes
<!-- PREPEND-ANCHOR:v1 — insert new entries immediately below this line. See .claude/rules/daily-note.md § Prepend Protocol. -->
<!-- === ENTRY FORMAT ===

new_string:
## Notes
<!-- PREPEND-ANCHOR:v1 — insert new entries immediately below this line. See .claude/rules/daily-note.md § Prepend Protocol. -->

- **HH:MM AM/PM** - **Descriptive Title** #tag1 #tag2

  **Work Type**: natural title-case description

  **Files Modified**:
  - 📝 [[FileName]] - what changed

  **Key Decisions**:
  - 💡 discovery + rationale

  **Strategic Value**: how this advances objectives

---

<!-- === ENTRY FORMAT ===
```

**Case B — Note from current template with existing entries**

```
old_string:
<!-- PREPEND-ANCHOR:v1 — insert new entries immediately below this line. See .claude/rules/daily-note.md § Prepend Protocol. -->

- **EXISTING_HH:MM** - **[Existing Top Entry Title]**

new_string:
<!-- PREPEND-ANCHOR:v1 — insert new entries immediately below this line. See .claude/rules/daily-note.md § Prepend Protocol. -->

- **NEW_HH:MM AM/PM** - **NEW Title** #tag

  **Work Type**: natural description

  **Strategic Value**: ...

---

- **EXISTING_HH:MM AM/PM** - **Existing Top Entry Title**
```

Replace `EXISTING_HH:MM` and `[Existing Top Entry Title]` with the actual top entry you read in Step 3. The Edit tool requires `old_string` to be unique; matching the anchor + the first bullet line of the top entry is sufficient.

**Case C — Legacy note without anchor** (pre-2026-04-09 or any note predating the anchor rollout)

Legacy notes lack the `<!-- PREPEND-ANCHOR:v1 ... -->` comment. In that case:

- Match directly against `## Notes` + an adjacent HTML comment line or the existing top entry's bullet header, and insert your new entry between the heading area and the old top entry
- **Do NOT backfill the anchor into legacy notes** — the Retrofit Protocol governs structural changes to old notes; leave anchor rollout to new notes and full retrofits
- If the legacy note also uses old section names (`## Timeline` instead of `## Notes`, `## Priorities` instead of `## Agenda & Tasks`), **flag to Tyler before editing** and apply Retrofit Protocol first

### Common Mistakes

1. ❌ Appending to the bottom of `## Notes` instead of the top
2. ❌ Forgetting the `---` separator between entries
3. ❌ Losing 2-space indentation on sub-content (breaks rendered bullet grouping)
4. ❌ Responding to the user before documenting
5. ❌ Treating `## Approvals Log` like `## Notes` — both are newest-first, but existing Log entries are **immutable** (see Approval Lifecycle item 3)
6. ❌ Using Write instead of Edit (overwrites the whole file)
7. ❌ Putting dynamic content (current timestamp, tags, title) in `old_string` — match the static anchor, not values you just generated
8. ❌ Prepending a second entry in the same turn without re-reading the file first (Step 3 is mandatory every time)
9. ❌ Using Glob when `find` is required (not applicable to this project — our paths have no `[W]##` brackets — but worth noting for cross-project awareness)

### Approvals Log vs Notes — the "newest first" distinction

Both sections put new entries at the top. The difference:

- `## Notes` entries **may be edited later** to add details, correct mistakes, or refine descriptions
- `## Approvals Log` entries are **append-only history** — new decisions are prepended to the top of the log, but existing decisions are never modified

Both surfaces use prepend semantics for insertion; only `## Notes` allows retroactive edits to existing entries.

---

## Retrofit Protocol

When adding the `## Approvals Pending` / `## Approvals Log` sections to an existing daily note (pre-2026-04-09 notes):

1. Read the note.
2. Insert both sections between `## Notes` (and its trailing `---`) and `## Meetings`.
3. Leave both sections empty (no entries) unless retrofitting a specific deferred item.
4. Do not modify any other section.

---

## Changelog

| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-09T12:30 | daily-note-format-upgrade | morpheus | Major format revision: switched to 12-hour AM/PM clock, natural title-case Work Type (deprecated bracketed all-caps), vertical bullet lists for Files/Tasks/Decisions (deprecated inline pipe-separated), varied emojis for Key Decisions (💡🎯⚠️🔍), added optional Implementation Tasks / Implementation Results / Deliverables Created / Roadblocks fields. Rule + template + skill aligned. All 9 entries in 2026-04-09.md retrofitted to match reference format from Tyler. |
| 2026-04-09T12:20 | daily-note-prepend-standard | morpheus | Fixed field-separation rendering bug: Timeline Entry Format + Prepend Protocol Case A/B examples now show MANDATORY blank lines between each `**Field**:` line, `---` separator at column 0 (not indented). Prior compact form collapsed entries into run-on paragraphs in Obsidian/GitHub. Template updated to match; all 8 entries in 2026-04-09.md retrofitted. |
| 2026-04-09T11:32 | daily-note-prepend-standard | morpheus | Added `globs: notes/**` frontmatter, inserted Prepend Protocol section (7-step + Case A/B/C anchor patterns + common mistakes), clarified Approval Lifecycle item 3 append-vs-prepend wording |
| 2026-04-09T09:40 | 2026-04-09-ingest-context-skill | morpheus | Created daily note rule with approval lifecycle, session scan, retrofit protocol |
