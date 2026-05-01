---
feature: north-star-standard
status: active
created: 2026-04-22
last-updated: 2026-04-22
owner: morpheus
version: 1
---

# North-Star Standard — What a Mature Morpheus Harness Looks Like

> This is the spec a mature Morpheus harness meets. It serves three roles:
> 1. **Plan success criteria** — the 2026-04-22 orchestration-loop overhaul is measured against these invariants.
> 2. **Durable reference** — future harness work benchmarks itself against this doc.
> 3. **Self-improvement target** — the meta-harness improvement loop uses this as its measuring stick.

---

## Context

On 2026-04-21, Morpheus kicked off an Ultra-scope detection-engineering research project for Tyler and silently skipped multiple protocol steps (no Planner task, clarifications batched outside `/the-protocol`, `EnterPlanMode` rationalized away, STATE.md created before any plan was shown). Tyler correctly flagged the incident as a **standards-enforcement failure**, not an ordering bug.

Codex's multi-agent second opinion confirmed the diagnosis. The root causes were:
- Two competing orchestration engines (`prompt-context-loader.sh` and `/the-protocol`) making parallel scope/pre-flight decisions.
- Prose-level gates without executable enforcement.
- Under-specified cross-session state.
- A CLAUDE.md that contradicted its own intended sequence.
- No harness-health telemetry — failures weren't measurable.

This standard codifies what Morpheus should look like once those root causes are addressed, and how Morpheus measures itself against that target.

---

## 8 Invariants

These must hold at all times. Violations are protocol incidents and are logged to `hub/state/harness-audit-ledger.md`.

### 1. Single entry path
Every non-Passthrough task enters through `/the-protocol`. No parallel pre-flight engines in hooks or other skills.

**Today**: Pre-overhaul `prompt-context-loader.sh` duplicated scope/skill-eval logic. Phase A of the 2026-04-22 overhaul strips this.

### 2. Plan-first for Medium+
No durable side effect (staging dir, STATE.md, Planner task, TaskCreate entries, daily-note entry) is created before Tyler approves the orchestration plan via `ExitPlanMode`. Scope classification and context gathering are OK pre-approval; anything writable is not.

**Today**: Violated in the 2026-04-21 Azure kickoff. Phase B rewires `/the-protocol` Step 7 to run post-approval.

### 3. Executable gates, not prose gates
Required steps are validated by hooks or auditors with pass/fail evidence. Prose "mandatory" rules without enforcement are considered advisory.

**Today**: Rules files say "MUST" but nothing verifies. Phase D adds the audit hook + ledger.

### 4. Typed task state
Each task has a machine-readable STATE.md frontmatter (v2 schema) plus human-readable body. Ultra additionally has a validated HANDOFF packet with a 7-section schema.

**Today**: STATE.md frontmatter was freeform. Phase C tightens it and adds HANDOFF v1.

### 5. Idempotent external actions
Planner task creation, daily-note prepends, INDEX.md updates, and sync operations are deduplicated by stable task identity (task-id slug as the key).

**Today**: No dedup. Phase B Step 7.5 adds it for Planner; Phase F metrics surface duplicates.

### 6. Cross-session fidelity
A new session can resume any Ultra task with no missing intent, blockers, or next step. Resume is verified by the 10-point checklist in HANDOFF.md.

**Today**: HANDOFF.md is a stub convention. Phase C3 defines the schema; Phase C4 validates it on session start.

### 7. Three self-improvement loops

- **Meta-harness loop**: monthly review of the audit ledger → failures become replay-corpus cases → corpus drives protocol/rule amendments (via `/weekly-review` extension).
- **Project-roadmap loop**: Morpheus maintains `hub/state/roadmap.md` — rolling list of projects, priorities, dependencies. Session-start surfaces stale or new items in the daily note.
- **Task-execution loop**: each wave ends with a 2-line retrospective appended to STATE.md Progress Summary (what worked, what to change next wave). SME assessor is the enforcer.

**Today**: Only task-execution is partial (via SME feedback). Phases E/F/G introduce meta and roadmap loops.

### 8. Benchmark-driven governance
Every harness change is tested against a replay corpus of real failure cases (`hub/state/replay-corpus/`). New failures get canonicalized into the corpus. `replay-harness-case.ps1` produces a dry-run trace and asserts expected vs observed.

**Today**: Nonexistent. Phase F establishes the corpus (seeded with the 2026-04-21 Azure kickoff case).

---

## 8 Metrics

Measured continuously, published nightly to `hub/state/harness-metrics.md` via `scripts/utils/generate-harness-metrics.ps1` (wired to Stop hook).

| # | Metric | Target | Source |
|---|--------|--------|--------|
| 1 | % Medium+ tasks with plan-approval timestamp before scaffold creation | ≥ 95% | `harness-audit-ledger.md` — `XPM:Y` and `SCAF:Y` rows |
| 2 | Duplicate Planner task rate | < 1% | `Compare-PlannerState` — tasks with matching `morpheus-task-id` custom field |
| 3 | Protocol-skip incident count (rolling 30 days) | 0 | `harness-audit-ledger.md` — `RESULT:FAIL` rows |
| 4 | Resume success rate after compaction / new session | ≥ 90% | HANDOFF validator pass rate (hook exit codes + in-session reports) |
| 5 | Scope reclassification rate (post-first-classification) | < 15% | Scope-confidence log + audit ledger |
| 6 | Hook failure / retry rate | < 5% | Hook exit-code log (non-zero exits) |
| 7 | Audit pass rate by scope | ≥ 90% per scope | `harness-audit-ledger.md` — group by `scope` column |
| 8 | Time-to-recover after interrupted Ultra session | < 10 min | HANDOFF validator timestamp → first productive tool call in new session |

If any metric slips below target for two consecutive weeks, `/weekly-review` auto-surfaces it and proposes a harness amendment (via a new replay-corpus case if the failure is reproducible).

---

## Self-Improvement Loops — Cadence

| Loop | Owner | Cadence | Artifact produced | Consumed by |
|------|-------|---------|-------------------|-------------|
| Meta-harness | `/weekly-review` | Weekly | Harness amendment proposals (new corpus cases, rule edits) | Future Morpheus sessions |
| Project-roadmap | `hub/state/roadmap.md` + session-start hook | Continuous + weekly tidy | Rolling project list with priorities | Daily note surfacing |
| Task-execution | SME assessor, every wave | Per-wave | 2-line retrospective in STATE.md Progress Summary | Next wave planning |

---

## Measurement Against This Standard

Morpheus runs a **self-audit** monthly (mechanism: `/weekly-review` extended to roll up 4 weeks of audit-ledger + metrics + replay-corpus drift):

1. Compute each of the 8 metrics for the rolling 30 days.
2. Compare against targets above; flag misses.
3. Cross-reference with replay corpus — are any failures recurring?
4. Propose concrete amendments. If amendment is non-trivial, open a new harness-overhaul task (Large/Ultra per scope).
5. Tyler reviews the self-audit artifact once a month; any flagged miss requires an explicit decision (accept / amend / defer).

---

## Gap Analysis (as of 2026-04-22)

Before the current overhaul lands:

| Invariant | Gap | Resolving phase |
|-----------|-----|-----------------|
| 1. Single entry path | `prompt-context-loader.sh` duplicates pre-flight | Phase A |
| 2. Plan-first Medium+ | Scaffold happens before plan presentation | Phase B |
| 3. Executable gates | Gates are prose in rules files | Phase D (audit hook) + F (ledger) |
| 4. Typed state | STATE.md frontmatter is freeform | Phase C |
| 5. Idempotent external | No dedup on Planner create | Phase B (Step 7.5) |
| 6. Cross-session fidelity | HANDOFF.md is a stub | Phase C (schema + validator) |
| 7. Three loops | Only task-exec partial | Phases E/F/G |
| 8. Benchmark-driven governance | Nonexistent | Phase F |

---

## Changelog
| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-22T14:25 | 2026-04-22-harness-intake-improvements | morpheus | Initial north-star standard v1 — 8 invariants, 8 metrics, 3 improvement loops, gap analysis |
