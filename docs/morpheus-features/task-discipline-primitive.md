---
feature: task-discipline-primitive
shipped: 2026-04-23
scope: large
plan: .claude/plans/happy-scribbling-cerf.md
state: hub/staging/2026-04-23-task-discipline-primitive/STATE.md
planner-task-id: EpX2ewNjHkm4rdDSdT_xwWUAKyuY
status: shipped
---

# Task Discipline as a Harness-Wide Primitive

Harness feature that promotes task-list discipline from a doctrine reminder to hook-enforced primitive. Three-layer MVP shipped 2026-04-23.

## Problem

Tyler corrected task-list discipline three times via memory (`feedback_taskcreate_timing.md`, `feedback_task_list_always_active.md`, `feedback_state_taskcreate_enforcement.md`) with no behavioral shift. Drift pattern: Morpheus responded to new prompts before creating tasks; meta-level work (protocol steps, scaffolding, context gathering) never entered the task list; tasks could be silently cancelled mid-session without authorization. Doctrine alone was insufficient — each correction produced a prose reminder that became white noise.

## Solution (3 layers)

### Layer 1: Rule (doctrine)
`.claude/rules/task-handling.md` — auto-loads via `globs: **`. Owns:

- **Meta-Task Principle**: `/the-protocol` Step 0.5 creates 3 phase-level meta-tasks (M0 pre-flight / M1 scaffold / M2 handoff) for Medium+, 2 for Mini/Small, 0 for Passthrough. Harness work is task-worthy.
- **Naming Standard**: imperative verb + object + optional scope tag (`(meta)`, `(build)`, `(verify)`, `(doc)`, `(fix)`, `(investigate)`).
- **Urgency Model** (3 levels): `immediate` / `sequenced` / `deferred`. No `someday` tier.
- **Dependency Inference**: explicit verbal → sequential language → topical overlap → default immediate.
- **Non-Cancellation Invariant**: `TaskUpdate status=cancelled` or `status=deleted` requires Tyler's same-turn authorization (keywords: cancel / drop / abandon / nevermind / skip / remove / kill / scrap / don't do that). Session-end is NOT authorization.

### Layer 2: Hook (enforcement)
`.claude/hooks/task-discipline-audit.ps1` — signed PowerShell, Stop-event, non-blocking. Clones the proven `protocol-execution-audit.ps1` pattern:

- **Cancellation detector**: finds TaskUpdate with `status=cancelled`/`deleted` in the turn window; checks last user message for authorization keywords; logs `RESULT:FAIL` on violation.
- **Meta-violation detector**: finds turns with ≥2 mutating tool uses (Edit/Write/MultiEdit/Bash) and 0 TaskCreate/TaskUpdate calls; logs `RESULT:SOFT`.
- **Otherwise**: `RESULT:PASS`.

Output: `TASKDISC:{PASS|SOFT|FAIL}` row to `hub/state/harness-audit-ledger.md` per Stop event; on non-PASS, prepends a timeline entry to today's daily note.

### Layer 3: Targeted Edits (integration)
- `.claude/commands/the-protocol.md` — Step 0.5 added (meta-task TaskCreate); Step 7d edited to APPEND plan tasks to meta-tasks; Rules 13 + 14 added.
- `.claude/commands/task-list-management.md` — schema v2; Urgency section, Non-Cancellation Invariant section, cross-reference to rule.
- `.claude/commands/orchestration-dispatch.md` — task-handling cross-reference at top.
- `CLAUDE.md` — Task Discipline section under Doctrine (3 invariants + audit-only enforcement note).
- `.claude/rules/hub.md` — Interaction Mandate #4 (task-handling reference).
- `.claude/protocols/{default,harness,code}.md` — 1-line cross-reference in Sub-Protocols section.
- `.claude/settings.local.json` — Stop hook registered; `task-compliance-check.sh` removed.
- `.claude/hooks/task-compliance-check.sh` — DELETED (replaced by audit hook).

## Decisions Locked (Step 6c AskUserQuestion, 2026-04-23T16:40)

| Axis | Chosen | Alternatives considered |
|------|--------|-------------------------|
| Meta-task granularity | 3 phase-level (pre-flight / scaffold / handoff) | 8 step-level; 1 single-task |
| Urgency levels | 3 (immediate / sequenced / deferred) | 4 with `someday`; 2 (now / later) |
| Cancellation enforcement | Audit-only (log, don't block) | Blocking hook; doctrine-only |
| Passthrough policy | Stays pure (no meta-task) | Always gets 1 meta-task; auto-escalate to Mini |

## Architecture Choice: Why Audit-Only, Non-Blocking

Prior doctrine corrections (3 memories + `task-compliance-check.sh` unconditional Stop reminder) failed because they were inline and consequence-free. What moves models: post-hoc public accountability with specific violations named. The proven pattern is `protocol-execution-audit.ps1` — its ledger rows visible at next SessionStart have successfully shifted protocol-execution behavior. This feature clones that pattern for the task-list domain.

Blocking mode was rejected because it risks false-blocks when Tyler phrases authorization differently than the keyword list. Audit-only keeps the flow intact while surfacing every violation for review.

## 2-Week Data Review Milestone

`hub/state/roadmap.md` includes a 2-week checkpoint (scheduled **2026-05-07**) to review ledger data:

- If **SOFT-VIOLATION rate > 30%** → tune detection thresholds or escalate to Phase 2 prompt-side flagger.
- If **FAIL rate > 0** → review each cancellation-violation for pattern; tighten authorization keyword list or trigger blocking mode for repeat offenders.
- If **SOFT < 10% and FAIL = 0** → close ticket, deprecate milestone.

## Files

| File | Role | Change type |
|------|------|-------------|
| `.claude/rules/task-handling.md` | Rule (doctrine) | NEW |
| `.claude/hooks/task-discipline-audit.ps1` | Hook (enforcement) | NEW (signed) |
| `.claude/commands/the-protocol.md` | Protocol skill | EDITED (Step 0.5 + 7d + Rules 13-14) |
| `.claude/commands/task-list-management.md` | Task skill | REWRITTEN (v2) |
| `.claude/commands/orchestration-dispatch.md` | Dispatch skill | EDITED (cross-ref) |
| `CLAUDE.md` | Doctrine | EDITED (Task Discipline section) |
| `.claude/rules/hub.md` | Hub rule | EDITED (Mandate #4) |
| `.claude/protocols/{default,harness,code}.md` | Profiles | EDITED (1-line xref each) |
| `.claude/settings.local.json` | Hook wiring | EDITED (Stop reg + compliance-check removed) |
| `.claude/hooks/task-compliance-check.sh` | Old reminder hook | DELETED |
| `hub/state/replay-corpus/task-discipline/*.jsonl` | Regression fixtures | NEW (3 scenarios) |

## Known Gaps (as of ship)

1. **Manual E2E smoke from bash was blocked by ThreatLocker** — PS process invoked from bash lacks Add-Content permission to `hub/state/`. The live hook runs in Claude Code's hook sandbox with proper permissions (same as `protocol-execution-audit.ps1` which successfully writes). **Full E2E verification lands when next session's Stop events fire** — any failure will surface as silent ledger absence, which is itself diagnostic.
2. **Urgency field storage**: the Claude Code TaskCreate tool does not expose a native `urgency` field. Current implementation relies on `metadata.urgency` where supported OR inline parenthetical tag in the subject. Sub-agents may not propagate urgency consistently; the audit hook doesn't currently verify presence.
3. **2-week data review** is a roadmap milestone, not an automated check. Tyler schedules the review manually or via `/weekly-review`.

## Changelog

| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-23T19:10 | 2026-04-23-task-discipline-primitive | morpheus | Feature shipped. 3-layer MVP: rule + hook + targeted edits. Step 6c decisions locked. 2-week data review scheduled 2026-05-07. |
