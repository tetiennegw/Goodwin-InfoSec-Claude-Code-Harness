# Active Tasks Standard

`hub/state/active-tasks.md` is **AUTO-GENERATED** from `hub/staging/*/STATE.md` frontmatter.

**DO NOT edit it manually.** Manual edits will be overwritten on the next Edit/Write call (PostToolUse hook regenerates automatically).

---

## Source of Truth

Each task's data lives in its `hub/staging/{task-id}/STATE.md`. To change what appears in `active-tasks.md`:

- Update wave, round, status, or timestamp → update `STATE.md` frontmatter fields
- Update next action → update the `## Next Action` section in `STATE.md`
- Archive a completed task → run `/eod` (moves entry to `hub/state/completed-tasks.md`)

The generator reads these fields from STATE.md YAML frontmatter:
- `scope`, `status`, `current-wave`, `current-round`, `created`, `last-updated`

And the first non-empty bullet/line from:
- `## Next Action` or `## Next Actions` (any heading starting with "Next Action")

---

## Regeneration

- **Trigger**: PostToolUse hook fires on every Edit/Write Claude tool call
- **Generator**: `scripts/utils/generate-active-tasks.sh`
- **On-demand refresh**: `bash scripts/utils/generate-active-tasks.sh` directly, or use `/catch-up`
- **Session start**: SessionStart hook cats the file automatically once per session

The generator runs in ~100ms and is idempotent — safe to call repeatedly.

---

## Completed Tasks

Tasks with `status: completed` or `status: complete` in STATE.md are **shown with a ⚠️ marker**, NOT silently removed.

This prevents data loss if `/eod` hasn't been run yet. When you see ⚠️:
1. Run `/eod` to archive the task to `hub/state/completed-tasks.md`
2. `/eod` moves the STATE.md row and removes it from the active view

**Important**: Archive MUST happen before or simultaneously with setting `status: completed` in STATE.md. Setting status first causes the ⚠️ flag to appear until `/eod` runs.

---

## Ordering

Tasks are sorted by `last-updated` timestamp (newest first). If `last-updated` is missing from a STATE.md, `created` is used as the fallback sort key.

---

## Fallback Values

When STATE.md fields are missing or non-standard, the generator uses safe defaults:
- Missing `scope` → `unknown`
- Missing `status` → `unknown`
- Missing `current-wave` / `current-round` → `0`
- Missing `last-updated` → `(not set)` (sort falls back to `created`)
- Missing `## Next Action` section → `(not set — see STATE.md)`
- Non-numeric wave values (e.g. `wave-1-research`) → output as-is, no arithmetic

---

## Changelog

| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-13T16:19 | active-tasks-standard | builder | Created rule file governing auto-generated active-tasks.md |
