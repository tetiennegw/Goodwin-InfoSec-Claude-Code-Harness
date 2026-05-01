---
task-id: {task-id}
scope: {mini|small|medium|large|ultra}
status: {planning|in-progress|blocked|completed}
protocol: {domain protocol name, e.g. default|code|harness|security-ops}
sub-protocol: {sub-protocol name, e.g. simple-script|full-stack|architecture-overhaul}
schema-version: 2
created: {ISO timestamp}
last-updated: {ISO timestamp}
current-wave: {N}
current-round: {N}
# --- v2 machine-readable fields (see docs/morpheus-features/north-star-standard.md §2.4 Typed task state) ---
planner-task-id: null                   # Planner GUID from Step 7.5; null until created or for Small/Mini/Passthrough
plan-approved-at: null                  # ISO timestamp of ExitPlanMode for Medium+; null for Mini/Small
pending-decisions: []                   # list of {id, title, options, blocking} — unresolved ADRs
blockers: []                            # list of {id, description, owner, unblock-criterion, first-seen}
verified-artifacts: []                  # list of {path, verified-at, verified-by} — externally verified outputs
neo-session-ids: []                  # Active Neo session UUIDs (conversation_id) for tasks delegating SOC work to /neo; empty for non-security tasks
resume-command: "/orchestration-dispatch hub/staging/{task-id}/STATE.md"
---

# {Task Title}

## Macro Goal
{2-3 sentence description of what this task achieves and why it matters to Tyler and/or Goodwin.}

## Project Scaffold
<!-- Visual tree updated after every wave. Status markers: ✅ complete | 🔄 in progress | ⬚ not started | ❌ failed -->
<!-- Omit for Mini scope. For Small, a single-line file reference is sufficient. -->

```
hub/staging/{task-id}/
├── STATE.md                          ← this file
├── wave-1/
│   └── round-1/
│       └── research-{topic}.md       ⬚ not started
├── wave-2/
│   └── round-1/
│       └── plan-{deliverable}.md     ⬚ not started
├── wave-3/
│   └── round-1/
│       └── build-{output}.ext        ⬚ not started
└── wave-4/                           ⬚ not started
```

## Task Table
<!-- Single source of truth for all tasks. Claude Code TaskCreate is ephemeral; this table is durable. -->
<!-- For Mini/Small: include only the tasks in play (basic 7-column form). -->
<!-- For Medium+: include all tasks + sub-tasks. -->
<!-- For Large/Ultra: use the EXTENDED 11-column form with wave-ledger fields (required-inputs, required-outputs, blockers, verification-status). -->

**Basic form (Mini / Small / Medium):**

| ID | Task | Status | Wave | Agent | blockedBy | Output |
|----|------|--------|------|-------|-----------|--------|
| T1 | Research {topic} | ⬚ pending | W1 | gatherer | — | research-{topic}.md |
| T2 | Plan {deliverable} | ⬚ pending | W2 | planner | T1 | plan-{deliverable}.md |
| T3 | Build {output} | ⬚ pending | W3 | builder | T2 | build-{output}.ext |
| T3.1 | {sub-task} | ⬚ pending | W3 | builder | T2 | {file} |
| T3.2 | {sub-task} | ⬚ pending | W3 | builder | T3.1 | {file} |
| T4 | Verify + document | ⬚ pending | W4 | verifier+documenter | T3 | — |

**Extended form (Large / Ultra — machine-checkable wave ledger):**

<!-- Next wave cannot launch until prior wave's verification-status = PASS. Orchestration-dispatch enforces this. -->

| ID | Task | Status | Wave | Agent | blockedBy | Required Inputs | Required Outputs | Blockers | Verification Status | Output |
|----|------|--------|------|-------|-----------|-----------------|-------------------|----------|---------------------|--------|
| T1 | Research {topic} | ⬚ pending | W1 | gatherer | — | STATE.md | {path}.md w/ ≥N sources | — | ⬚ pending | research-{topic}.md |
| T2 | Plan {deliverable} | ⬚ pending | W2 | planner | T1 | T1 output path | 16-section plan | — | ⬚ pending | plan-{deliverable}.md |
| T3 | Build {output} | ⬚ pending | W3 | builder | T2 | T2 output path | {expected files} | — | ⬚ pending | build-{output}.ext |
| T4 | Verify + document | ⬚ pending | W4 | verifier+documenter | T3 | T3 artifacts | verification-w4.md | — | ⬚ pending | — |

## Context Inventory
<!-- Tells downstream agents WHERE to find context, not WHAT the context is. Agents read files on demand. -->
<!-- This prevents STATE.md from bloating. Do NOT paste file contents here — list paths only. -->
<!-- For Mini: omit this section. For Small: 1-3 rows max. -->

| Source | Path | Relevance | Loaded By |
|--------|------|-----------|-----------|
| Research: {topic} | wave-1/round-1/research-{topic}.md | {one-line takeaway} | Gatherer W1R1 |
| Plan: {deliverable} | wave-2/round-1/plan-{deliverable}.md | Build instructions | Planner W2R1 |
| Existing file: {name} | {absolute path in repo} | {extend/modify/reference} | — (pre-existing) |
| External: {source} | {URL or doc ref} | Reference only | Gatherer W1R1 |

## Validation Framework
<!-- Set at task inception by the orchestrator. Updated by SME assessors as criteria are verified. -->
<!-- For Mini: omit this section. For Small: acceptance criteria only (omit SME Roles + Verification Gates). -->

### Acceptance Criteria (EODIC)
<!-- Each criterion must be Executable, Observable, Deterministic, Independent, Cumulative. -->
<!-- Mark with [x] and ✅ WNRn when an SME assessor verifies it. -->
- [ ] AC1: {criterion} — verified by `{command or tool check}`
- [ ] AC2: {criterion} — verified by `{command or tool check}`
- [ ] AC3: {criterion} — verified by `{command or tool check}`

### SME Roles
<!-- Omit for Small. Required for Medium+. -->
- **Primary**: {title} — {domain expertise description}
- **Secondary**: {title} — {subdomain expertise description}

### Verification Gates
<!-- Omit for Small. Required for Medium+. -->
- **Tier 1** (Build/Lint): {files exist, syntax valid, frontmatter parses, imports resolve}
- **Tier 2** (Unit/Content): {tests pass, sections present, cross-references exist, accuracy spot-checked}
- **Tier 3** (E2E/Integration): {end-to-end scenario passes, cross-file references resolve, hook coexists cleanly}

## Progress Summary
<!-- Newest-first timestamped log of wave/round completions and SME verdicts. -->
<!-- COMPACTION RULE: After 3 completed waves, collapse older entries to one-line summaries: -->
<!--   "[{ISO}] Wave N complete — {agent}: {verdict}. {key artifact}." -->
<!-- Keep full detail only for the current wave and the immediately preceding one. -->

- [{ISO}] Wave 1, Round 1: {description of what happened. SME verdict: ADVANCE/CONTINUE/FLAG/FAIL.}

## Open Items
<!-- Questions, blockers, risks, gotchas discovered during work. -->
<!-- Pruned by SME assessors when resolved. Persistent blockers escalated to Tyler. -->

- ⚠️ {blocker or risk — describe impact and owner}
- ❓ {open question for Tyler — what decision is needed}

## Next Action
- {Exactly what should happen next — specific enough for any agent to pick up without reading the full file}


<!-- ═══════════════════════════════════════════════════════════════════════════════ -->
<!-- ULTRA-ONLY SECTIONS — omit for Large and below. Include for Ultra scope only. -->
<!-- ═══════════════════════════════════════════════════════════════════════════════ -->

## Subsystem Status Matrix
<!-- Ultra only — at-a-glance dashboard for multi-subsystem projects. -->
<!-- Delete this section for Large and below. -->

| Subsystem | Phase 1 | Phase 2 | Phase 3 | Integration | Hardening |
|-----------|---------|---------|---------|-------------|-----------|
| {name}    | ⬚ pending | ⬚ pending | ⬚ pending | ⬚ pending | ⬚ pending |

## Session History
<!-- Ultra only — never compacted, serves as cross-session audit trail. -->
<!-- Delete this section for Large and below. -->

| Session | Started | Ended | Waves Completed | Key Decisions |
|---------|---------|-------|-----------------|---------------|
| 1       | {ISO}   | {ISO} | {W1-W3}         | {decisions made this session} |

## Phase Gate Log
<!-- Ultra only — evidence-linked record of each phase gate pass/fail. -->
<!-- Delete this section for Large and below. -->

| Phase | Gate Result | Evidence | Timestamp |
|-------|-------------|----------|-----------|
| P1    | ⬚ pending   | —        | —         |

## Scope Changes
<!-- Ultra only — immutable log of Tyler's descoping or reprioritization decisions. -->
<!-- Delete this section for Large and below. -->

- [{ISO}] {what changed and why — descoped/reprioritized/expanded}
