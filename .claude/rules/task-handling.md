---
name: Task Handling Standard
globs: "**"
description: Harness-wide task-list discipline — naming, urgency, dependency inference, non-cancellation invariant, meta-task principle. Cross-cutting standard that supersedes inline reminders.
created: 2026-04-23
last-updated: 2026-04-23
schema-version: 1
---

# Task Handling Standard

Authoritative rule for every TaskCreate / TaskUpdate call made by Morpheus or any sub-agent. Auto-loads for all paths (`globs: **`). Complements — does not replace — `.claude/rules/active-tasks.md` (which governs auto-generation of `hub/state/active-tasks.md`) and `.claude/commands/task-list-management.md` (which owns the TaskCreate/TaskUpdate skill mechanics). This rule is the *doctrine*; the skill is the *procedure*; `task-discipline-audit.ps1` is the *enforcement*.

---

## Why This Rule Exists

Tyler has corrected task-list discipline three times via memory (`feedback_taskcreate_timing.md`, `feedback_task_list_always_active.md`, `feedback_state_taskcreate_enforcement.md`). Each correction produced a prose reminder; each reminder became white noise. The behavior drift pattern:

1. Morpheus responds to a new prompt BEFORE creating a task for the work it implies.
2. Meta-level work (protocol steps, scaffolding, context gathering) never enters the task list at all.
3. Tasks are silently cancelled mid-session without Tyler's same-turn authorization.

Doctrine alone has been insufficient. This rule collapses the three memories into one durable standard, and a Stop-event audit hook (`task-discipline-audit.ps1`) writes violation evidence to `hub/state/harness-audit-ledger.md` — a public, cross-session consequence that the inline reminders lacked.

---

## Meta-Task Principle

**Tasks are not just build-time artifacts.** Every instruction that produces actionable work — including the protocol's own pre-flight steps, scaffolding, context gathering, and handoff — must appear in the session task list.

At the start of every `/the-protocol` invocation (scope Mini and above), TaskCreate three phase-level meta-tasks:

| Meta-task ID | Subject | Scope gating |
|--------------|---------|--------------|
| M0 | META: pre-flight (`/the-protocol` Steps 1-6) | Mini+ |
| M1 | META: scaffold (Step 7 + 7.5) | Mini+ |
| M2 | META: handoff (Step 8) | Mini+ |

For **Passthrough**, no meta-tasks are created (preserves the `/the-protocol` Phase A1 boundary — Passthrough is a pure-answer exit, not instrumented work).

For **Mini / Small**, meta-tasks are created but plan-mode gating is skipped; M1 scaffold is minimal (staging dir + STATE.md + daily-note only — no Planner task, no plan artifact).

For **Medium+**, full meta-tasks fire; M1 includes Planner task creation (idempotent by task-id slug per Step 7.5).

The 3-level collapse was chosen over 8 step-level tasks (one per `/the-protocol` step) to keep the session task list scannable. If noise is still an issue after 2 weeks of data, consider collapsing to a single `META: harness pre-flight` task. Do NOT expand to 8 step-level tasks — the plan pressure-test explicitly rejected this.

---

## Naming Standard

Every TaskCreate subject follows this shape:

```
{Imperative verb} {Object} ({scope tag})
```

**Required elements**:
- **Imperative verb** (Write / Edit / Fix / Research / Plan / Verify / Delete / Sign / Create / Refactor / Document / Archive)
- **Object** — what the verb acts on (file path, concept, deliverable)
- **Scope tag in parentheses** where ambiguous — one of: `(meta)`, `(build)`, `(verify)`, `(doc)`, `(fix)`, `(investigate)`

**Examples (good)**:
- `Write .claude/rules/task-handling.md`
- `Sign task-discipline-audit.ps1 via /sign-script`
- `VERIFY Phase 1`
- `Fix em-dash parse error in state-frontmatter-validator.ps1`
- `META: scaffold (Step 7 + 7.5)`

**Examples (bad)**:
- `Task-handling` — noun only, no verb
- `Work on rule` — vague verb + vague object
- `Do the thing` — no information
- `TODO: rule file` — not imperative; "TODO" is not a verb

Phase-level tasks (`Phase 1: Author rule + hook`) use a colon-separated form where the phase name serves as the verb-object phrase. This is permitted for top-level wave tasks only.

---

## Urgency Model (3 Levels)

Every task carries an urgency assignment. The three levels are:

| Urgency | When to use | Dependency behavior |
|---------|-------------|---------------------|
| `immediate` | Work that should start as soon as prior tasks allow. Default for build-phase tasks driven by the current session's plan. | No additional blockedBy — work begins as soon as blockedBy tasks from the plan resolve. |
| `sequenced` | Work that has an explicit dependency chain from the plan (section 8b dependencies) or from inferred "X must happen before Y" language. | Inherits `blockedBy` from the plan's dependency table or from inferred signal ("after we finish X, do Y"). |
| `deferred` | Work that Tyler has explicitly said to defer ("let's hold off on X", "do this later", "after next week"), OR work flagged as low-priority capture. | Added to task list for visibility but NOT in the current session's blockedBy chain. Tyler re-prioritizes manually or a future session activates it. |

There are exactly **three** levels. `someday` is NOT a valid urgency — it invites backlog rot. If a task is too distant to warrant `deferred`, it doesn't belong on the task list; it belongs in `hub/state/roadmap.md` or an `episodic-log` memory entry.

Urgency is stored in task metadata as `metadata.urgency` when supported by the harness, OR inlined into the subject line via a parenthetical tag (e.g., `(deferred)`) when metadata is unavailable.

---

## Dependency Inference

When creating a task mid-session (not from a pre-written plan), infer dependencies from these signals — in order of precedence:

1. **Explicit verbal dependency** ("after X", "once Y is done", "when we've finished Z") → set `blockedBy` to the named task.
2. **Sequential language** ("then do", "next step", "now that we have") → `blockedBy` = immediately preceding task in the session task list.
3. **Topical overlap** — new task targets files already being modified by an in-flight task → set `blockedBy` to the in-flight task to prevent concurrent edit conflicts.
4. **No signal** → no `blockedBy`, `urgency = immediate`. Work can start immediately.

Verbal deferral keywords that trigger `urgency = deferred` (not `sequenced`):
- "hold off", "defer", "table this", "later", "not urgent", "when you have time", "someday-maybe-no-actually-not-someday", "after {vague future event}"

Verbal authorization keywords that permit task cancellation (see below):
- "cancel", "drop", "abandon", "nevermind", "skip", "remove", "kill", "scrap that", "actually don't do that"

---

## Non-Cancellation Invariant

**Tasks are immutable by default.** Once created, a task may be updated (status transitions, subject refinement, metadata additions) but it may NOT be silently cancelled, deleted, or marked-completed-without-execution unless Tyler has explicitly authorized the cancellation **in the same turn**.

### The Invariant

> `TaskUpdate status=cancelled` OR `TaskUpdate status=deleted` requires Tyler's same-turn authorization.

**Same-turn authorization** = the user message immediately preceding the TaskUpdate contains one or more verbal authorization keywords (see list above). Prior-turn authorization does NOT carry over — authorization from a conversation three turns ago is stale.

**Session-end does NOT authorize cancellation.** Tasks left pending at `/eod` are carried forward via STATE.md + active-tasks.md regeneration. Auto-cancelling pending tasks to "clean up" is a protocol violation.

### Enforcement

The audit hook `.claude/hooks/task-discipline-audit.ps1` fires on every Stop event. It scans the turn's tool-use sequence for TaskUpdate calls with `status=cancelled` or `status=deleted`, checks the last user message for authorization keywords, and writes:

- `RESULT:PASS` if no cancellation, or cancellation with valid authorization
- `RESULT:FAIL` if cancellation without authorization (logged as VIOLATION)

Violations are written to `hub/state/harness-audit-ledger.md` and prepended as a timeline entry to today's daily note. The cancellation is NOT rolled back — the hook is audit-only, non-blocking. The consequence is public accountability: the violation is visible at next SessionStart and during `/weekly-review`.

### Valid Same-Turn Authorization Examples

- Tyler: "actually cancel the Phase 5 docs task, I'll do them manually later" → authorized (contains "cancel", names the task).
- Tyler: "nevermind, drop the hook-signing task" → authorized.
- Tyler: "skip Phase 4, we don't need the E2E smoke" → authorized.

### Invalid (would trigger VIOLATION)

- Morpheus, unprompted: "the Phase 5 docs task is redundant, marking cancelled" → VIOLATION (no Tyler authorization).
- Morpheus, at `/eod`: "cleaning up 4 pending tasks" → VIOLATION if ≥1 is status=cancelled without Tyler keyword in last user turn.

---

## Audit-Only Enforcement (2026-04-23 design decision)

The audit hook is **non-blocking**. It does NOT reject TaskUpdate calls. It logs violations to the ledger and daily note. The rationale:

- Blocking hooks on widely-used tool calls risk false positives that break legitimate flows.
- The proven pattern (`protocol-execution-audit.ps1` for plan-first enforcement) is audit-only and has successfully shifted behavior via ledger visibility.
- Tyler chose audit-only at Step 6c of the 2026-04-23 `/the-protocol` run (plan `.claude/plans/happy-scribbling-cerf.md`).

Escalation to blocking is deferred indefinitely. A Phase 2 prompt-side flagger is deferred pending a 2-week audit-ledger data review (milestone in `hub/state/roadmap.md`).

---

## Cross-References

- **Skill (procedure)**: `.claude/commands/task-list-management.md` — TaskCreate/TaskUpdate mechanics, how to add urgency metadata, the session-vs-durable task distinction
- **Rule (auto-gen)**: `.claude/rules/active-tasks.md` — how `hub/state/active-tasks.md` is regenerated from STATE.md frontmatter
- **Rule (plan-time)**: `.claude/rules/implementation-plan-standard.md` §8 — plan-section-8a (task preview) and §8b (dependency table) are the design-time source for TaskCreate hierarchy
- **Hook (enforcement)**: `.claude/hooks/task-discipline-audit.ps1` — signed PS Stop-event audit hook; writes TASKDISC rows to the ledger
- **Hub (orchestration)**: `.claude/rules/hub.md` — the orchestration loop that consumes/produces tasks
- **Doctrine**: `CLAUDE.md` — `## Task Discipline` section includes meta-task + non-cancellation invariant under Doctrine
- **Audit ledger**: `hub/state/harness-audit-ledger.md` — target for `TASKDISC:{PASS|SOFT|FAIL}` rows
- **2-week review milestone**: `hub/state/roadmap.md` — decision point for Phase 2 escalation

---

## Changelog

| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-23T18:30 | 2026-04-23-task-discipline-primitive | morpheus | Created initial rule: meta-task principle (3 phase-level tasks per /the-protocol), naming standard, 3-level urgency model (immediate/sequenced/deferred), dependency inference heuristics, non-cancellation invariant (same-turn authorization required), audit-only enforcement design. Aligns with Step 6c decisions locked 2026-04-23T16:40 via AskUserQuestion. |
