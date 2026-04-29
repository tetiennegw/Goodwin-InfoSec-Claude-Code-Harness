---
title: v2 Orchestration-Loop Overhaul (2026-04-22)
category: morpheus-feature
tags: [harness, orchestration, governance, overhaul, north-star]
created: 2026-04-22
last-updated: 2026-04-22
last-verified: 2026-04-22
review-interval: 180d
status: active
audience: Tyler (current), Goodwin security team (future open-source)
owner: morpheus
related-runbook: none
related-state: ../../hub/staging/2026-04-22-harness-intake-improvements/STATE.md
---

# v2 Orchestration-Loop Overhaul (2026-04-22)

> **30 patches across 7 phases that make Morpheus governance mechanically enforced rather than stated.** Eliminates competing control planes, enforces plan-first for Medium+ tasks, adds typed state with a validated HANDOFF schema, and establishes harness-health telemetry with a benchmark-driven replay corpus.

## Executive Summary

The 2026-04-22 orchestration-loop overhaul is the most significant structural change to the Morpheus harness since initial deployment. Triggered by a 2026-04-21 rubber-stamp failure in which Morpheus silently skipped four protocol steps during an Ultra-scope kickoff, the overhaul addressed not just the four named symptoms but the underlying architectural root cause: Morpheus's governance was stated, not mechanically enforced. A Codex CLI multi-agent second opinion (Devil's Advocate + Domain Expert + Pragmatist + Synthesis, ~15 min, 318,320 tokens) confirmed the diagnosis and identified six additional architectural gaps. The v2 plan expanded from 13 to 30 patches across 7 phases (A-H), delivering: a single entry path through /the-protocol, plan-first scaffolding for Medium+ tasks enforced post-ExitPlanMode approval, a STATE.md v2 schema with strict frontmatter, a HANDOFF template for Ultra session boundaries, a protocol-execution audit hook writing to a harness-audit ledger, per-scope robustness improvements, nightly telemetry against 8 north-star metrics, a seeded replay corpus, CLAUDE.md refactored from 215 to 151 lines, and 5 memory feedback entries codifying the architectural insights. The outcome is a harness that can measure its own health, catch its own violations, and improve itself through three explicit self-improvement loops.

---

## Triggering Incident

On 2026-04-21, Morpheus kicked off an Ultra-scope Azure Detection Engineering Pipeline research task and silently rubber-stamped the protocol, skipping four mandatory steps:

1. **No Planner task created** -- Large/Ultra scope requires a Planner task as part of scaffold; none was created.
2. **Clarifications pre-batched outside /the-protocol** -- Clarifying questions were answered before the protocol was formally invoked, violating the clarifications-inside-protocol invariant.
3. **EnterPlanMode skipped via self-rationalization** -- Morpheus rationalized away the EnterPlanMode requirement using pre-gathered context as justification. This is the failure pattern Codex named "over-rationalization."
4. **STATE.md created before any plan was visible** -- The scaffold (staging dir, STATE.md, TaskCreate entries) was written before Tyler had reviewed or approved an orchestration plan.

Tyler correctly identified this as a standards-enforcement failure rather than an ordering bug. The paused task lives at `hub/staging/2026-04-21-azure-detection-engineering-pipeline/STATE.md` (status: `paused-handoff`) and is the first case in the replay corpus at `hub/state/replay-corpus/2026-04-21-azure-kickoff-rubber-stamp/`.

---

## Root Cause Diagnosis

Codex's multi-agent second opinion identified six architectural root causes beyond the four named gaps:

1. **Competing control plane** -- `prompt-context-loader.sh` duplicated scope assessment, skill evaluation, and pre-flight gating that `/the-protocol` should own exclusively. Every prompt fired the hook first, pushing Morpheus into evaluate-and-activate mode before the skill was even invoked.
2. **Prose-only gates** -- Rules files used MUST and REQUIRED language, but no hook or auditor ever verified compliance. Prose gates are advisory; they do not prevent rationalization.
3. **Under-specified HANDOFF** -- `HANDOFF.md` was referenced in the Ultra protocol as a convention but had no schema, no validator, and no enforcement. File-exists is too weak a resume guarantee.
4. **Freeform STATE.md** -- STATE.md frontmatter was untyped markdown. Machine-readable fields (`planner-task-id`, `pending-decisions`, `blockers`, `verified-artifacts`) did not exist as defined fields.
5. **Bloated CLAUDE.md** -- At 215 lines, CLAUDE.md contained per-skill tables, per-agent tables, and procedural detail that duplicated `.claude/rules/hub.md`. Worse, the Orchestration Loop section implied STATE.md creation before plan approval, contradicting the intended sequence.
6. **No telemetry** -- Without measurable metrics and a benchmark corpus, self-improvement at the meta-harness level had no target and no feedback signal.

---

## The v2 Architecture

The overhaul is organized into 7 phases, each targeting a root cause.

### Phase A -- Kill the Competing Control Plane

Stripped Steps 0-4 from `prompt-context-loader.sh` (scope assessment, skill evaluation, pre-flight gate injection). The hook now only provides time-context header, environment reminders, and forced-YES overrides for `/ingest-context` and `/approve-pending`. Removed the COEXISTENCE NOTE from the-protocol.md -- `/the-protocol` is now the sole pre-flight engine. Hook timeout reduced to reflect the lighter workload.

**Files**: `.claude/hooks/prompt-context-loader.sh`, `.claude/commands/the-protocol.md`, `.claude/rules/hub.md`, `.claude/settings.local.json`

### Phase B -- /the-protocol Overhaul

Rewired the protocol step sequence: EnterPlanMode opens at Step 6a (before clarifications), clarifications happen inside plan mode at Step 6c, ExitPlanMode presents the plan for Tyler approval at Step 6d. Added a hard enforcement block -- if scope is Medium, Large, or Ultra and EnterPlanMode has not been called this turn, STOP; no rationalization exceptions. Moved all scaffolding (Step 7) to post-ExitPlanMode-approval. Added Step 7.5: idempotent Planner task creation for Large/Ultra keyed by task-id slug in an `morpheus-task-id` custom field. Added Step 8 pre-handoff gate that verifies 5 conditions and writes a pass/fail entry to the harness-audit ledger.

**Files**: `.claude/commands/the-protocol.md`

### Phase C -- Typed STATE.md v2 + HANDOFF Schema

Tightened STATE.md frontmatter to a strict v2 schema with required fields: `schema-version: 2`, `planner-task-id` (nullable), `plan-approved-at` (ISO timestamp), `pending-decisions` (list), `blockers` (list), `verified-artifacts` (list with verification timestamps), `resume-command`. Created `hub/templates/handoff.md` with a 7-section schema required for Ultra session boundaries. Added `state-frontmatter-validator.ps1` (PostToolUse hook, non-blocking) and `handoff-validator.ps1` (session-start hook). Migrated 25 existing STATE.md files to v2 via `scripts/utils/migrate-state-md-v2.ps1`.

**Files**: `hub/templates/state.md`, `hub/templates/handoff.md`, `.claude/hooks/state-frontmatter-validator.ps1`, `.claude/hooks/handoff-validator.ps1`, `scripts/utils/migrate-state-md-v2.ps1`

### Phase D -- Protocol Self-Audit Hook

Added `protocol-execution-audit.ps1` (PostToolUse on Skill tool). Reads `transcript_path` from hook stdin JSON following the `daily-note-check.ps1` pattern, parses recent conversation history for AskUserQuestion/EnterPlanMode/ExitPlanMode/Planner-create calls relative to the last `/the-protocol` invocation, and writes pass/fail rows to `hub/state/harness-audit-ledger.md`. Violations also prepend a timeline entry to the daily note tagged `#protocol-audit #violation`.

**Files**: `.claude/hooks/protocol-execution-audit.ps1`, `hub/state/harness-audit-ledger.md`, `.claude/settings.local.json`

### Phase E -- Per-Scope Improvements

Six scope-specific enhancements targeting distinct break points Codex identified per scope tier:

- **Passthrough (E1)**: Preference and roadmap signals appended to `hub/state/episodic-log.md` for `/weekly-review` pattern detection.
- **Mini (E2)**: Scope-confidence score (LOW/MED/HIGH) emitted with the scope classification; LOW confidence fires an AskUserQuestion escalation prompt.
- **Small (E3)**: Auto-rescope triggers added to `/orchestration-dispatch` (file-touch > 5, tool-call > 20, elapsed > 45 min, or external-system call detected).
- **Medium (E4)**: SME assessor appends a 2-line wave retrospective to STATE.md Progress Summary after each wave.
- **Large (E5)**: STATE.md Task Table gains `required-inputs`, `required-outputs`, `blockers`, `verification-status` columns; next wave blocked until prior wave `verification-status = PASS`.
- **Ultra (E6)**: Wave 0 must produce a HANDOFF.md stub before any other wave fires.

**Files**: `.claude/commands/the-protocol.md`, `.claude/commands/orchestration-dispatch.md`, `.claude/agents/sme-assessor.md`, `hub/templates/state.md`, `hub/state/episodic-log.md`

### Phase F -- Harness Health Telemetry + Replay Corpus

Created `hub/state/harness-metrics.md` (nightly auto-generated snapshot of 8 north-star metrics) via `scripts/utils/generate-harness-metrics.ps1`, wired to the Stop hook. Created `hub/state/replay-corpus/` with a README defining the corpus schema and seeded the first case: `2026-04-21-azure-kickoff-rubber-stamp/` containing a frozen transcript, expected trace, observed trace, and delta mapping to the violated north-star invariants. Created `scripts/utils/replay-harness-case.ps1` for dry-run trace assertion. Extended `/weekly-review` to surface metrics below target and cross-reference replay corpus.

**Files**: `hub/state/harness-metrics.md`, `scripts/utils/generate-harness-metrics.ps1`, `hub/state/replay-corpus/README.md` + 5 case files, `scripts/utils/replay-harness-case.ps1`, `.claude/commands/weekly-review.md`

### Phase G -- CLAUDE.md Refactor + Roadmap + North-Star Standard

Refactored CLAUDE.md from 215 to 151 lines using 7 concrete edits per Codex: updated Identity to default-to-orchestration framing, fixed Orchestration Loop sequencing to show EnterPlanMode before clarifications, removed per-skill/per-agent tables (pointers to `.claude/commands/` and `.claude/agents/` instead), collapsed repeated NEVERs into a single no-self-justified-skips block, added a Worked Example naming the Azure kickoff case, declared doctrine/procedure/enforcement separation ("CLAUDE.md is doctrine. Rules are procedure. Hooks are enforcement."), and aligned `hub.md` pre-execution gate wording with plan-first. Created `docs/morpheus-features/north-star-standard.md` and `hub/state/roadmap.md`.

**Files**: `CLAUDE.md`, `.claude/rules/hub.md`, `.claude/rules/implementation-plan-standard.md`, `docs/morpheus-features/north-star-standard.md`, `hub/state/roadmap.md`

### Phase H -- Memory Feedback + Wire-Up

Added 5 memory feedback entries codifying the overhaul key insights as durable session-to-session guidance: Planner auto-create for Large/Ultra (explicit step, not a hook), clarifications inside protocol (not pre-batched), EnterPlanMode mandatory for Medium+ (no rationalization exceptions), no self-justified skips (Codex deepest finding: Azure failure was over-rationalization), and `project_north_star_standard.md` pointer. Updated `memory/MEMORY.md` index with all 5 new entries.

**Files**: 5 new files under `.claude/projects/.../memory/` + `memory/MEMORY.md`

---

## What's Mechanically Enforced Now

The 8 invariants from `docs/morpheus-features/north-star-standard.md` and how each is now enforced:

| # | Invariant | Enforcement mechanism |
|---|-----------|----------------------|
| 1 | Single entry path | `prompt-context-loader.sh` stripped of scope/pre-flight logic; `/the-protocol` is the only pre-flight engine |
| 2 | Plan-first for Medium+ | Hard enforcement block in `/the-protocol` Step 6; scaffolding moved to post-ExitPlanMode Step 7; Step 8 gate writes to audit ledger |
| 3 | Executable gates | `protocol-execution-audit.ps1` hook parses transcript, writes pass/fail to `harness-audit-ledger.md`; violations surface in daily note |
| 4 | Typed task state | STATE.md v2 schema with required fields; `state-frontmatter-validator.ps1` validates on every Write to `hub/staging/*/STATE.md` |
| 5 | Idempotent external actions | Planner task creation keyed by task-id slug in `morpheus-task-id` custom field; dedup check before `New-PlannerTask` call |
| 6 | Cross-session fidelity | HANDOFF template v1 with 7-section schema; `handoff-validator.ps1` validates on session start for active Ultra tasks |
| 7 | Three self-improvement loops | Meta-harness via `/weekly-review` + audit ledger; project-roadmap via `hub/state/roadmap.md` + session-start surfacing; task-execution via SME assessor wave retrospectives |
| 8 | Benchmark-driven governance | Replay corpus seeded with Azure kickoff case; `replay-harness-case.ps1` asserts expected trace vs observed for any proposed harness change |

---

## Migration Impact

The overhaul touched every layer of the harness:

- **25 STATE.md files** upgraded to v2 schema via `migrate-state-md-v2.ps1` (safe defaults for nullable fields)
- **CLAUDE.md** refactored from 215 to 151 lines (30% reduction; volatile detail extracted to rules/hooks)
- **5 memory feedback entries** added, codifying architectural insights as durable cross-session guidance
- **6 new .ps1 files** created and signed (all `Valid` as of 2026-04-23): `state-frontmatter-validator.ps1`, `handoff-validator.ps1`, `protocol-execution-audit.ps1`, `generate-harness-metrics.ps1`, `migrate-state-md-v2.ps1`, `replay-harness-case.ps1`. Post-signing em-dash encoding issue fixed (2026-04-23T16:15) -- all literals normalized to ASCII hyphens before re-signing.
- **Replay corpus seeded** with first canonical case (`2026-04-21-azure-kickoff-rubber-stamp/`) -- frozen transcript, expected/observed traces, delta mapped to violated invariants
- **New hub/state artifacts**: `harness-audit-ledger.md`, `harness-metrics.md`, `episodic-log.md`, `roadmap.md`, `replay-corpus/` directory
- **New hub/templates artifact**: `handoff.md`

---

## How to Measure Success

Eight metrics measured nightly, published to `hub/state/harness-metrics.md`:

| # | Metric | Target |
|---|--------|--------|
| 1 | % Medium+ tasks with plan-approval timestamp before scaffold creation | >= 95% |
| 2 | Duplicate Planner task rate | < 1% |
| 3 | Protocol-skip incident count (rolling 30 days) | 0 |
| 4 | Resume success rate after compaction / new session | >= 90% |
| 5 | Scope reclassification rate (post-first-classification) | < 15% |
| 6 | Hook failure / retry rate | < 5% |
| 7 | Audit pass rate by scope | >= 90% per scope |
| 8 | Time-to-recover after interrupted Ultra session | < 10 min |

If any metric slips below target for two consecutive weeks, `/weekly-review` auto-surfaces it and proposes a harness amendment. Full metric definitions and source columns are in `docs/morpheus-features/north-star-standard.md` section 2.

---

## Verification

Final verification results (post-signing, 2026-04-23T16:12):

- **Signing**: 6/6 `.ps1` files report `Status = Valid` via `Get-AuthenticodeSignature`.
- **Smoke test**: 20/20 static checks pass (all structure, file-existence, schema, hook-wiring checks).
- **Replay corpus dry-run**: `replay-harness-case.ps1 -Case 2026-04-21-azure-kickoff-rubber-stamp` returns **REPLAY PASS -- 21/21 checks succeeded**. The v2 protocol's Step 6 hard enforcement block, Step 7 post-approval scaffold, Step 7.5 idempotent Planner create, and Step 8 pre-handoff gate together would have blocked all four 2026-04-21 Azure-kickoff violations.
- **Hook live-test**: `state-frontmatter-validator.ps1` invoked via piped JSON exits 0 cleanly; em-dash encoding fix (2026-04-23T16:15) resolves the `line 108 char 75` PostToolUse error observed during initial STATE.md write.

---

## Next Steps

1. ~~**Sign 6 `.ps1` files** via `/sign-script`~~ -- **DONE 2026-04-23**. All 6 report `Valid`; em-dash encoding fix applied and re-signed the same day.
2. ~~**Wire signed hooks**~~ -- **DONE**. `.claude/settings.local.json` has the 3 new audit/validator hooks wired (PostToolUse `Edit|Write|MultiEdit` for state-validator, PostToolUse `Skill` for protocol-execution-audit, SessionStart for handoff-validator) plus Stop-hook wiring for nightly metrics generation.
3. **Run real fresh-session test** -- resume the paused DE pipeline task (`hub/staging/2026-04-21-azure-detection-engineering-pipeline/STATE.md`, status: `paused-handoff`) in a new Morpheus session. Verify: HANDOFF validator fires on SessionStart, audit hook logs a PASS row to `harness-audit-ledger.md`, plan-first gate engages correctly for Ultra scope.
4. **First nightly metrics run** -- confirm `generate-harness-metrics.ps1` runs at session end and writes a valid `hub/state/harness-metrics.md` snapshot within the next 24h window.
5. **Optional git commit** -- commit the v2 overhaul as a single logical commit covering all 30 patches + 6 signatures + em-dash fix.

---

## References

| Resource | Path |
|----------|------|
| Plan v2 (30 patches, 7 phases) | `.claude/plans/lovely-hatching-dongarra.md` |
| Codex second opinion | `thoughts/second-opinions/2026-04-22-harness-overhaul-codex.md` |
| North-Star Standard (8 invariants + 8 metrics) | `docs/morpheus-features/north-star-standard.md` |
| Task state (this overhaul) | `hub/staging/2026-04-22-harness-intake-improvements/STATE.md` |
| Replay corpus README | `hub/state/replay-corpus/README.md` |
| Azure kickoff failure case | `hub/state/replay-corpus/2026-04-21-azure-kickoff-rubber-stamp/` |
| Harness audit ledger | `hub/state/harness-audit-ledger.md` |
| Nightly metrics | `hub/state/harness-metrics.md` |
| HANDOFF template | `hub/templates/handoff.md` |
| STATE.md template v2 | `hub/templates/state.md` |

---

## Changelog

| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-23T16:20 | 2026-04-22-harness-intake-improvements | morpheus | Post-signing updates: 6/6 Valid signatures recorded; em-dash encoding fix (line 108 char 75 error) noted; Verification section rewritten with 20/20 smoke + 21/21 replay results; Next Steps items 1-2 marked DONE; added optional git-commit step |
| 2026-04-22T16:12 | 2026-04-22-harness-intake-improvements | documenter | Created v2-harness-overhaul-2026-04-22.md -- full feature doc covering triggering incident, root cause diagnosis, 7-phase architecture, 8 invariants, migration impact, metrics, verification, next steps |
