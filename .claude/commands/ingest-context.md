---
description: Process files in the ingest/ drop zone — dedup, classify via context-curator, rename, archive, log to hub/context-log, update daily note, and fire AskUserQuestion for high-risk cascades. Auto-activated by prompt-context-loader hook whenever ingest/ has unprocessed files.
user-invocable: true
argument-hint: (optional) path to a specific file, else processes all new files in ingest/
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, TaskCreate, TaskUpdate, TaskList, AskUserQuestion, Agent]
schema-version: 1
---
# /ingest-context

Process one or more files that have been dropped in the `ingest/` drop zone. This skill is the primary automation surface for absorbing arbitrary context into the Brain.

## When to invoke

- **Automatic (primary)**: the `prompt-context-loader.sh` hook injects a forced-YES override whenever `ingest/` has files, so this skill runs before Claude addresses the user's actual message.
- **Manual (fallback)**: Tyler types `/ingest-context` to force a re-run, or `/ingest-context <path>` to process a specific file.
- **Scheduled**: a cron trigger via `/schedule` runs this skill every 20 minutes in a headless session (see headless branch in Step 6).

## Prerequisites

- `ingest/` directory exists (created in Phase 0 of the initial build)
- `hub/state/context-categories.md` exists (seeded taxonomy)
- `hub/state/ingest-hashes.log` exists (dedup log, create if missing)
- `.claude/agents/context-curator.md` exists (reusable classifier)
- Today's daily note exists (the prompt-context-loader ensures this)

## Steps

### Step 1 — Scan

1. List files in `ingest/`, **excluding**: `processed/`, `duplicates/`, `README.md`, and any dotfiles.
2. If an argument path was passed, narrow the scan to just that file (must exist inside `ingest/`).
3. If no files to process, output `Nothing to ingest.` and exit cleanly.
4. Acquire a lock: `touch hub/state/.ingest.lock` — if the lock already exists and is less than 10 minutes old, abort with `Ingest already running (lock held).`. If older, treat as stale and overwrite.

### Step 2 — Per-file loop (in order of filename)

For each file, execute steps 2a–2h in sequence. Do NOT parallelize — taxonomy writes must be serialized.

**Step 2a — Dedup check**

1. Compute sha256: `sha256sum "$FILE" | awk '{print $1}'`
2. Grep `hub/state/ingest-hashes.log` for the hash.
3. If found:
   - Move source to `ingest/duplicates/<original-filename>` (create dir if needed, keep original filename)
   - Append a note to today's `hub/context-log/YYYY/MM/YYYY-MM-DD.md`:
     ```
     ### HH:MM — DUPLICATE
     **File**: <original-name>
     **Hash**: <sha256>
     **Original entry**: <grep result — processed-path and timestamp>
     **Action**: Moved to ingest/duplicates/
     ---
     ```
   - Skip to next file. Do NOT invoke curator, do NOT create taxonomy entries.
4. If not found, continue.

**Step 2b — Read the file**

Type detection via `file` command. Branch by type:
- **Image (png/jpg/jpeg/webp/gif)**: use Read tool with the absolute path (Claude native vision)
- **PDF**: use Read tool (native PDF support) — for PDFs > 10 pages, read the first 5 pages only for classification
- **.eml**: use Bash to extract headers — `grep -iE "^(From|To|Cc|Subject|Date|Message-ID):" "$FILE" | head -20`, then `sed '1,/^$/d' "$FILE" | head -50` for the first bit of body; pass both to the curator and the cascade analysis
- **.msg**: unsupported. Move directly to `ingest/processed/YYYY/MM/<original-name>_unparsed.msg` and log a "needs manual review" entry to context-log. Skip classification and skip taxonomy update. Report in final summary.
- **.md / .txt**: Read tool
- **Other**: best-effort Read; if unreadable, move to `processed/` with `_unparsed` suffix and log "unparseable, needs manual review"

**Step 2c — Extract signal**

Identify and note:
- **Source**: who sent / who authored / where it came from (e.g., "email from Thor Kakar", "screenshot from Outlook web")
- **Title/subject**: the best short description
- **Key facts**: dates, numbers, scope, impact
- **People mentioned**: by name
- **Projects implied**: existing or new
- **Cascade candidates**: things that would change files in `hub/state/`, `hub/staging/`, `memory/`, etc.

Write this to a temporary variable or scratch note — it feeds the curator (Step 2d) and the cascade logic (Step 5).

**Step 2d — Dispatch context-curator**

Use the `Agent` tool with `subagent_type: general-purpose` (since named custom subagents are dispatched via the generic Agent tool per the project conventions — pass the agent file as context).

Actually, dispatch via Agent tool citing the `context-curator` definition. Prompt template:

```
Classify the following input file(s).

INPUT_FILES:
- <absolute-path>

TAXONOMY_FILE: <absolute path to hub/state/context-categories.md>

CONTEXT: <Step 2c signal summary, 2-4 sentences>

OUTPUT_SUMMARY: hub/staging/2026-04-09-ingest-context-skill/classification-<timestamp>.md (or other task-relevant path)

Follow the context-curator agent definition at .claude/agents/context-curator.md.
```

Receive back: inline summary including assigned categories, new categories created, downstream signals.

**Step 2e — Generate slug**

- Take the title/subject from Step 2c
- Kebab-case, strip punctuation, limit to 40 chars
- If multiple files from the same source, append `-N` disambiguation
- Example: "Scheduling Your Cyber Incident Response Intro" → `kakar-ir-migration` (shortened, keeping entities)

**Step 2f — Determine type slug**

One of:
- `email` — .eml file
- `screenshot-email` — image clearly showing an email UI
- `screenshot-chat` — image showing Teams/Slack/SMS
- `screenshot-doc` — image of a document/web page
- `note` — plain text written by Tyler
- `doc` — markdown or document file
- `image` — generic image with no clear category
- `transcript` — meeting/call transcript
- `pdf` — PDF document
- `other` — fallback

**Step 2g — Compute new filename + archive**

- Timestamp source priority: (1) timestamp parsed from original filename (e.g., `Screenshot 2026-04-09 090105.png` → `2026-04-09_0901`), (2) file mtime, (3) now
- New filename: `YYYY-MM-DD_HHMM_<type>_<slug>.<ext>`
- Destination: `ingest/processed/YYYY/MM/<new-filename>` (mkdir -p first)
- Move via `mv` (not cp+rm)
- Verify the new file exists and is readable

**Step 2h — Append to ingest-hashes.log**

```
<sha256> | <original-filename> | ingest/processed/YYYY/MM/<new-filename> | <ISO timestamp>
```

### Step 3 — Append to running log

Write to `hub/context-log/YYYY/MM/YYYY-MM-DD.md` (create if missing, with frontmatter `type: context-log, date: YYYY-MM-DD`). Newest entries at TOP of the ## Entries section.

**Timestamp convention (CRITICAL)**: The `HH:MM` in the entry heading MUST be the **ingest-run timestamp** — the wall-clock time at which `/ingest-context` executed — NOT the source file's original capture time. Rationale: the context-log is an audit trail of when the Brain absorbed each piece of content, not when the content was created. If the source file carries a meaningful original timestamp (email received time, screenshot capture time, meeting date), put it in the `**Summary**:` field prose instead. For example: heading `### 10:15 — Kakar: IR migration email` with summary text `"Email received at 09:00; ingested at 10:15"`. This convention is enforced so daily-note cross-reference anchors (e.g., `#1015--...`) always match the ingest run and are independent of source drift.

Entry format:
```markdown
### HH:MM — <title>
**Source**: <who/where>
**Type**: <type slug>
**Categories**: `category1`, `category2`
**Archived**: [<new-filename>](../../../../ingest/processed/YYYY/MM/<new-filename>)
**Summary**: 2–4 sentence summary capturing the signal. Include source-original timestamp here if relevant (e.g., "Email received at 09:00; ingested at 10:15").
**Cascade candidates**:
- <candidate 1> → `<target file or directory>`
- <candidate 2> → `<target file or directory>`
---
```

### Step 4 — Update today's daily note (LOW-RISK, auto-applied)

This step MUST follow the Prepend Protocol and Timeline Entry Format defined in `.claude/rules/daily-note.md`. Key invariants:
- **12-hour AM/PM** timestamps (`**03:30 PM**`, not `**15:30**`)
- **Natural title-case Work Type** (`**Work Type**: Context Ingest`), NOT bracketed all-caps
- **Vertical bullet lists** for multi-item fields (one bullet per file/category), NOT inline pipe-separated
- **Blank lines between every `**Field**:` line** (required for renderers to parse correctly)
- **Prepend** via the canonical anchor `<!-- PREPEND-ANCHOR:v1 -->` (see `.claude/rules/daily-note.md § Prepend Protocol` for Edit tool anchor patterns)
- **Strategic Value** is a required prose paragraph

Protocol:

1. Get the ingest-run timestamp in 12-hour format: `date '+%I:%M %p'`.
2. Read today's note at `notes/YYYY/MM/YYYY-MM-DD.md` (mandatory — do not trust stale state).
3. Locate the `<!-- PREPEND-ANCHOR:v1 -->` immediately under `## Notes`.
4. Use Edit to prepend the entry directly below the anchor. Never use Write (it clobbers the whole file).
5. Re-read the Notes section to verify the entry sits above all prior entries with separators intact.

Canonical entry template for ingest runs:

```markdown
- **HH:MM AM/PM** - **Context Ingested: <short title>** #ingest #context-log <category-tags>

  **Work Type**: Context Ingest — <one-sentence description of what was absorbed>

  **Files Archived**:
  - 📝 [[<new-filename-without-ext>]] - <what it is>
  <!-- one bullet per file, repeat as needed -->

  **Key Decisions**:
  - 🔍 <classification confidence + any notable signal>
  - ⚠️ <cascade candidates flagged if any, or "No cascade candidates" if none>

  **Implementation Results**:
  - N file(s) processed, M duplicates, K unparsed
  - Archived to `ingest/processed/YYYY/MM/`
  - Logged to `hub/context-log/YYYY/MM/YYYY-MM-DD.md`
  - Categorized as <category list>

  **Deliverables Created**:
  - [[<title> context-log entry]] - see `hub/context-log/YYYY/MM/YYYY-MM-DD.md#HHMM` (use the ingest-run timestamp slug from Step 3)

  **Strategic Value**: Prose paragraph explaining how this ingest advances Tyler's objectives. For low-signal content, note that it exercises the pipeline and validates the dedup/taxonomy paths. For high-signal content, note the downstream project/state changes it enabled.
```

Notes on tags:
- Always include `#ingest` and `#context-log` as baseline.
- Add one tag per high-signal category (e.g., `#project:server-migration-ir`, `#person:thor-kakar`).
- Tags are space-separated on the header line.

### Step 5 — Classify cascades by risk

Iterate through cascade candidates from all files processed in this run. Categorize each:

**Low-risk (auto-applied, no approval)**:
- Adding entries to today's daily note (other sections)
- Adding ideas to `## Ideas & Insights`
- Appending to `hub/context-log/` entries
- Taxonomy updates (already handled by curator in Step 2d)
- Appending new entries to INDEX.md (handled by PostToolUse hook on Write)

**High-risk (approval required)**:
- Creating new project staging directories (`hub/staging/<slug>/`)
- Modifying any existing `STATE.md`
- Modifying `memory/priorities.md`
- Modifying any `hub/staging/**/plan-*.md`
- Modifying `CLAUDE.md` or any file in `.claude/rules/`
- Creating or modifying incident records in `ops/incidents/`
- Creating or modifying playbooks in `ops/runbooks/`
- **Judgment call rule**: if the change would require a colleague's sign-off in a real workplace, treat it as high-risk.

Apply all low-risk cascades immediately. Queue high-risk cascades for Step 6.

### Step 6 — Approval prompts for high-risk cascades

For each high-risk cascade, in order of discovery:

**Step 6a — Headless mode detection**

Check if running headless (env var `CLAUDE_HEADLESS=1`, or if `AskUserQuestion` tool is unavailable, or if the session was started by a schedule trigger). If headless:
- Auto-defer this cascade to `## Approvals Pending` in today's daily note
- TaskCreate the approval task (subject and description)
- Skip to next cascade (do NOT call AskUserQuestion)

**Step 6b — Interactive mode**

1. Call `TaskCreate`:
   - `subject: "[APPROVAL] <short title>"`
   - `description: <proposed change> | source: <context-log entry path> | rationale: <why>`
2. Capture the returned task ID.
3. Call `AskUserQuestion` with ONE question and 3 options (implicit "Other" is added):
   - `question: "Apply this change now? — <short title>"`
   - `header: "Approval"`
   - Options:
     - `"Apply now"` — description: `"Execute the change immediately and log as completed in today's daily note"`
     - `"Defer"` — description: `"Leave task open, add to Approvals Pending with the original raise timestamp"`
     - `"Deny"` — description: `"Reject this change, log to Approvals Log as denied"`
4. Branch on the answer:

**Apply now**:
1. Execute the proposed change via Write/Edit. Common patterns:
   - New staging directory: `mkdir -p hub/staging/<slug>/` and write a STATE.md from the plan-artifact template
   - Note: `hub/state/active-tasks.md` is auto-generated — do NOT write to it directly. It will regenerate via PostToolUse hook when STATE.md is created.
   - Modify `memory/priorities.md`: add a new entry under the relevant section
2. `TaskUpdate <task-id> status=completed`
3. Append to today's daily note `## Approvals Log` (newest first):
   ```markdown
   - **HH:MM** ✓ **<short title>** — applied to `<target-file>` (task: <task-id>)
     **Source**: [context-log entry](<path>)
   ```

**Defer**:
1. Leave the task `pending`.
2. Append to today's daily note `## Approvals Pending` (newest first):
   ```markdown
   - [ ] **HH:MM** — **<short title>** (task: <task-id>)
     **Proposed change**: <target file + specific change>
     **Why**: <rationale>
     **Source**: [context-log entry](<path>)
   ```
3. Continue to next cascade.

**Deny**:
1. `TaskUpdate <task-id> status=completed` with `metadata: {denied: true, denied-at: HH:MM}`
2. Append to `## Approvals Log`:
   ```markdown
   - **HH:MM** ✗ **<short title>** — denied (task: <task-id>)
     **Source**: [context-log entry](<path>)
   ```

**Other (custom text)**:
1. If the text is a clear scope override (e.g., "apply but only to file X"), fire a follow-up AskUserQuestion to confirm a revised scope, then branch as one of the above.
2. If ambiguous, log the text as a comment on the task via TaskUpdate description, then Defer with a "⚠️ needs-clarification" suffix on the daily note entry.

**Step 6c — Fallback**

If `AskUserQuestion` errors for any reason, auto-Defer. Never auto-apply without a clean "Apply now" answer.

### Step 7 — INDEX.md update

- Newly created files (context-log entries, classification reports) are automatically added by the `update-index.sh` PostToolUse hook.
- For `mv` operations, manually patch INDEX.md via Edit.
- Verify at the end: `grep -c "ingest/processed" INDEX.md` should reflect new entries if new month/year subdirs were created.

### Step 8 — Release lock and report

1. Remove `hub/state/.ingest.lock`.
2. Update the daily-note approvals snapshot: recompute sha256 of today's `## Approvals Pending` section and write to `hub/state/daily-note-snapshots/YYYY-MM-DD.approvals.sha` (so the watcher doesn't incorrectly flag the new additions as user-driven changes).
3. Print a summary table:
   ```
   INGEST SUMMARY (2026-04-09 HH:MM)
   ================================
   Files processed:  N
   Duplicates:       M
   Unparsed:         K
   New categories:   P
   Low-risk applied: X
   Approvals: Y applied / Z deferred / W denied
   ```

## Rules

- **Never auto-apply high-risk cascades** without a clean "Apply now" answer.
- **Never delete source files** — always archive to `processed/` or `duplicates/`.
- **Never modify `## Approvals Log` retroactively** — it is append-only audit history.
- **Never check an approval box on Tyler's behalf** — only Tyler checks boxes.
- **Preserve original timestamps** through state transitions — a deferred item acted on tomorrow still shows its original-raised HH:MM.
- **Release the lock** even on errors (use trap or explicit cleanup at end of run).
- **Serialize taxonomy writes** — one curator dispatch at a time, never parallel.
- **Report everything** — the summary at the end is the receipt Tyler uses to verify nothing was missed.
