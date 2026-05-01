---
description: Manage Claude Code task list — create, update, and track tasks for the current session per .claude/rules/task-handling.md (naming + urgency + non-cancellation invariant + meta-task principle).
user-invocable: true
allowed-tools: [TaskCreate, TaskUpdate, TaskList, TaskGet, Read, Write, Edit, Glob]
schema-version: 2
last-updated: 2026-04-23
---
# Task List Management

You are managing the Claude Code task list for the current session. This skill is the *procedure*; the authoritative rule is `.claude/rules/task-handling.md` (the *doctrine*); `.claude/hooks/task-discipline-audit.ps1` is the *enforcement*.

**Before any TaskCreate or TaskUpdate call, consult `.claude/rules/task-handling.md`** for the naming standard, the 3-level urgency model, dependency inference heuristics, and the non-cancellation invariant. All rules in that file apply here; this skill codifies the procedural steps.

---

## Step 1: Check Existing State
- Run `TaskList` to see any existing tasks in this session.
- Use `Glob` to check for `hub/staging/*/STATE.md` files to find active task contexts.
- If a specific task is in progress, read its `STATE.md` for current status.
- **Never duplicate a task** — if TaskList already contains a task for the work item, update its status instead of creating a new one.

## Step 2: Create Tasks (if starting new work)
- Decompose the current work into discrete, trackable items.
- For each item, call `TaskCreate` with:
  - **Subject** — imperative verb + object + optional scope tag per `.claude/rules/task-handling.md` § Naming Standard. Examples: `Write .claude/rules/task-handling.md`, `VERIFY Phase 1`, `META: scaffold (Step 7 + 7.5)`.
  - **Description** — what needs to be done, expected output, acceptance criterion (concrete enough to verify).
  - **activeForm** (optional) — present-continuous form for the in-progress spinner (e.g., `Writing task-handling rule`).
- Tasks should map to waves/rounds from the orchestration plan when applicable (plan section 8a is authoritative for plan-time hierarchy; Step 0.5 of `/the-protocol` adds 3 meta-tasks per invocation for harness work).

## Step 3: Assign Urgency (3-level model)

Every task carries an urgency assignment. The authoritative definition is `.claude/rules/task-handling.md` § Urgency Model. Summary:

| Urgency | Default for | Dependency behavior |
|---------|-------------|---------------------|
| `immediate` | Work in the current session's active phase. | No extra `blockedBy` — starts when plan's blockedBy chain clears. |
| `sequenced` | Dependent work identified by plan section 8b OR verbal signal ("after X"). | `blockedBy` set to the named prior task. |
| `deferred` | Tyler verbally defers ("hold off", "later", "not urgent") OR low-priority capture. | Added for visibility but NOT on the current session's critical path. |

There are exactly **three** levels. Do NOT invent `someday`, `P0`/`P1`/`P2`, or other tiers.

Urgency is stored via `metadata.urgency` when supported, OR inlined in the subject as a parenthetical `(deferred)` tag when metadata is unavailable.

## Step 4: Update Tasks (as work progresses)
- After completing a work item, call `TaskUpdate` with the task ID and new status.
- Valid statuses: `pending`, `in_progress`, `completed`, `deleted`.
- Mark tasks `in_progress` **when starting**, `completed` **immediately when done** — never batch updates to the end of a phase or session.
- Include a brief status message describing what was accomplished or what's blocking.

## Non-Cancellation Invariant

Tasks are immutable by default. `TaskUpdate status=cancelled` or `status=deleted` is a **restricted operation** per `.claude/rules/task-handling.md` § Non-Cancellation Invariant.

### The rule

> `TaskUpdate status=cancelled` or `status=deleted` requires Tyler's same-turn authorization via keywords: `cancel`, `drop`, `abandon`, `nevermind`, `skip`, `remove`, `kill`, `scrap`, `don't do that`.

### What counts as authorization

- **Same-turn** — the user message immediately before the TaskUpdate must contain at least one authorization keyword.
- **Task-identifying** — the user's turn should unambiguously identify which task is being cancelled (explicit task name, ID, or clear referential context).
- **Prior-turn or multi-turn-ago authorization does NOT carry forward.**

### What does NOT count

- **Session-end cleanup** — pending tasks at `/eod` stay pending and roll forward. Auto-cancelling them is a VIOLATION.
- **"Obviously redundant"** — Morpheus deciding a task is no longer needed without Tyler saying so.
- **Batch consolidation** — cancelling three tasks because they were "already done by other tasks".

### Enforcement

Violations are logged by `.claude/hooks/task-discipline-audit.ps1` (Stop-event PowerShell hook) to `hub/state/harness-audit-ledger.md` as `TASKDISC:FAIL` rows, and prepended to today's daily note. The cancellation is NOT blocked — the hook is audit-only — but the ledger entry is visible at next SessionStart and during `/weekly-review`, creating durable public accountability.

## Step 5: Sync with Durable State
- Task list entries are session-ephemeral. The durable state lives in:
  - `hub/state/active-tasks.md` — auto-generated from STATE.md frontmatter (PostToolUse hook regenerates on every Write/Edit)
  - `hub/staging/{task-id}/STATE.md` — per-task living document (authoritative)
- If tasks were completed, confirm `active-tasks.md` reflects the current state (it regenerates automatically; manually verify the entry if behavior seems off).
- Update STATE.md `## Progress Summary` with timestamped entries as phases complete.

---

## Rules

- **Every Medium+ scope task MUST have task list entries before work begins.** (Mini/Small follow meta-task gating per `/the-protocol` Step 0.5.)
- **Meta-work is task-worthy.** Protocol pre-flight, scaffolding, and handoff are visible entries (M0/M1/M2), not invisible overhead. See `.claude/rules/task-handling.md` § Meta-Task Principle.
- **Task subjects follow the Naming Standard** (imperative verb + object + scope tag).
- **Update tasks as waves progress** — never batch all updates to the end. An `in_progress` task that sits for an hour without status change is a signal to pause and TaskUpdate.
- **TaskCreate is ephemeral; STATE.md + active-tasks.md are the durable records.** Sub-agents see STATE.md; the main session sees both.
- **Never cancel a task without Tyler's same-turn authorization.** See Non-Cancellation Invariant above.
- **Never duplicate a task.** Check TaskList first.

## Cross-References

- Rule (doctrine): `.claude/rules/task-handling.md`
- Rule (auto-gen): `.claude/rules/active-tasks.md`
- Plan-time spec: `.claude/rules/implementation-plan-standard.md` § 8a/8b
- Protocol entry point: `.claude/commands/the-protocol.md` Step 0.5 (meta-tasks) + Step 7d (plan hierarchy append)
- Hook (enforcement): `.claude/hooks/task-discipline-audit.ps1`
- Audit ledger: `hub/state/harness-audit-ledger.md`

## Changelog

| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-23T18:55 | 2026-04-23-task-discipline-primitive | morpheus | Major revision: added Urgency model (3 levels), Non-Cancellation Invariant section, meta-task principle reference, cross-references to task-handling rule + audit hook. Schema bumped to v2. Prior v1 content preserved in the 5-step structure. |
