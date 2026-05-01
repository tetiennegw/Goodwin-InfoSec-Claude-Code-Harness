---
description: "Canonical 16-section standard for all Morpheus implementation plans. Loaded on-demand by planner agent."
schema-version: 1
---

# Implementation Plan Standard

> Reference card for plan authors. Applies to plans created after 2026-04-08. Existing plans in `hub/staging/` are not retroactively affected.

---

## Scope Gating

| Section | Small | Medium | Large/Ultra |
|---------|-------|--------|-------------|
| 1. Frontmatter | REQ | REQ | REQ |
| 2. Intent | Optional (1-2 lines) | REQ | REQ |
| 3. Objective | REQ | REQ | REQ |
| 4. Pre-existing Artifact Inventory | SKIP | REQ | REQ |
| 5. Research References | If research done | REQ | REQ |
| 6. Existing Codebase References | If applicable | REQ | REQ |
| 6.5 Integration-Depth Sanity Check | Optional (1 line) | REQ | REQ |
| 7. Acceptance Criteria (EODIC) | REQ (3-5 items) | REQ | REQ |
| 8. Task List w/ Dependencies | REQ (simplified) | REQ | REQ |
| 9. Three-Tier Verification Gates | SKIP | Optional | REQ |
| 10. Test Strategy / TDD | If code task | REQ | REQ |
| 11. Build Path | REQ | REQ | REQ |
| 12. Forward-Reference Markers | SKIP | If circular deps | REQ |
| 13. DIAGNOSE-FIX-RETRY | SKIP | REQ | REQ |
| 14. Agent Return Protocol | SKIP | REQ | REQ |
| 15. Risks & Mitigations | Optional | REQ | REQ |
| 16. Output Files + Changelog | REQ | REQ | REQ |

---

## Section Definitions

### 1. Frontmatter
YAML block at file top. No `globs:` field.
```yaml
---
type: plan
task-id: {task-id}
agent: planner
created: {ISO timestamp}
last-updated: {ISO timestamp}
inputs: [{paths of research/artifacts consumed}]
scope: small|medium|large|ultra
---
```

### 2. Intent
WHY this task exists. Four named fields:
- **Motivation** — why it matters to Tyler/Goodwin
- **Desired Experience** — what success feels like end-to-end
- **Preservation Requirements** — what must NOT break
- **Success Criteria** — concrete outcome from Tyler's perspective

### 3. Objective
WHAT is being built. 2-3 sentences. Relayed to Tyler for confirmation before work begins.

### 4. Pre-existing Artifact Inventory
Table of relevant artifacts already on disk.

| # | Artifact | Path | Disposition |
|---|----------|------|-------------|
| 1 | Name | /abs/path | SKIP / REUSE / PRESERVE+extend / GENERATE |

### 5. Research References
Table of research artifacts consumed during planning.

| # | Artifact | Key Insight | Path |
|---|----------|-------------|------|
| 1 | Name | One-line takeaway | /abs/path |

### 6. Existing Codebase References
Files/modules the build will depend on or extend.

| # | File/Module | Relevance | Path |
|---|-------------|-----------|------|
| 1 | Name | Why it matters | /abs/path |

### 6.5 Integration-Depth Sanity Check

This section is the planner-side counterpart to `.claude/commands/the-protocol.md` Step 6c.i. While Step 6c.i fires the Depth/Surface-Area/Assumption-Surfacing battery live — inside plan mode, before plan drafting — §6.5 is the post-hoc validator the planner agent consults when authoring or reviewing a plan. If Step 6c.i missed firing the 3-question battery (or if a plan is being authored outside the plan-mode flow), §6.5 catches the gap before plan approval.

**Trigger:** Every Medium+ plan. Component-shaped tasks ("fix one hook", "update one rule") may pass through quickly with thin defaults. Integration-shaped tasks ("onboard {tool}", "make X first-class", "add peer system") require broad defaults — all three checks below are mandatory before plan drafting proceeds.

#### Check 1 — Depth question fired?

Has Tyler been asked the **Depth** question with concrete option labels and one-line consequences?

- Options offered: **Thin** (one component + minimal wiring) / **Broad** (ripple through harness primitives) / **Ground-up** (new protocol profile + agent type + cross-cutting doctrine)
- Default-recommended option must match trigger keywords — "fully integrated" / "first-class" / "tool at my disposal" / "add system X" → Broad or Ground-up

If this question was not fired during Step 6c.i, fire it now before drafting the plan.

#### Check 2 — Surface Area confirmed?

Has Tyler been asked the **Surface Area** question via multiSelect, enumerating which primitives could plausibly be affected?

Primitives to enumerate: hooks / rules / templates / agents / protocols / CLAUDE.md doctrine / docs/morpheus-features/ / hub/state/ files

Tyler must confirm or veto each. The confirmed list drives which sections the plan must cover. If this question was not fired during Step 6c.i, fire it now.

#### Check 3 — Assumptions surfaced?

Has the planner explicitly named the **2-3 assumptions** about to be baked into the plan and asked Tyler to override BEFORE drafting?

Examples: "reader role is enough — no new agent type needed" / "/incident-triage stays untouched" / "no new audit hook — rule + memory enforcement only." If this question was not fired during Step 6c.i, fire it now.

**Anti-rule (planner-facing):** If you find yourself thinking "the plan can always be expanded later" or "let's start narrow and grow," that IS the violation. Default broad on integration tasks; let Tyler narrow. Narrowing requires one AskUserQuestion; expanding requires a full re-plan.

**Self-trigger heuristic (verbatim — same phrasing as Step 6c.i):** For every build/integration task ask: "Could this ripple into hooks, rules, templates, agents, protocols, daily-notes, doctrine, or the orchestration loop?" If "plausibly yes" for ≥2, that IS the clarifying question — ask before plan drafting, not after Tyler rejects a thin plan.

**Failure mode if §6.5 fails:** Planner agent surfaces missing-question evidence to the orchestrator. Orchestrator returns to Step 6c.i — re-fires AskUserQuestion with the missing question type. Plan drafting blocks until all three checks are satisfied.

**Note on enforcement:** This is a doctrine→rule layer codification only. The audit hook `protocol-execution-audit.ps1` continues binary AUQ-fired detection — no content inspection is added now. A 2-week observation period (mirroring the task-discipline pattern) precedes any decision to deepen the hook.

**Cross-references:**
- Live-firing counterpart: `.claude/commands/the-protocol.md` Step 6c.i
- Memory source: `feedback_integration_depth_clarification.md`
- Doctrine layer: `CLAUDE.md` § Integration-Depth Discipline (forward reference — authored in Wave 3 of task `2026-04-24-integration-depth-clarification-rule`)

### 7. Acceptance Criteria (EODIC)
Checkboxes. Each criterion must be:
- **E**xecutable — can be tested with a tool or command
- **O**bservable — pass/fail is unambiguous
- **D**eterministic — same result every run
- **I**ndependent — no ordering dependency on other criteria
- **C**umulative — prior criteria remain true

```
- [ ] {Criterion}: verified by `{command or tool}`
```

### 8. Task List with Dependencies

This section has TWO mandatory parts. Both must appear in every Medium+ plan.

#### 8a. Session Task List Preview (MANDATORY)

A visual preview of exactly what Tyler will see in his Claude Code task list the moment the plan is launched. This is a literal rendering — copy-paste ready — showing the phase/wave structure with all subtasks and sub-sub-tasks nested beneath. Use `◻` for unchecked tasks. Indent with 4 spaces per level.

```
◻ Phase 0: {phase title}
    ◻ {subtask 1}
    ◻ {subtask 2}
        ◻ {sub-sub-task 2a}
        ◻ {sub-sub-task 2b}
    ◻ VERIFY Phase 0
    ◻ CHECKPOINT Phase 0
◻ Phase 1: {phase title}
    ◻ {subtask 1}
    ◻ {subtask 2}
    ◻ VERIFY Phase 1
    ◻ CHECKPOINT Phase 1
◻ Phase 2: {phase title}
    ...
```

**Rules:**
- Every phase/wave in the plan MUST appear as a top-level line
- Every subtask referenced in the Build Path (section 11) MUST appear nested under its phase
- Sub-sub-tasks are required when a subtask has internal steps Tyler would want to track separately
- VERIFY and CHECKPOINT entries appear at the end of each phase as explicit subtasks
- This preview is authoritative — when the plan is launched, the orchestrator MUST create the Claude Code task list to match this structure exactly, then wire in the dependencies from section 8b

#### 8b. Task Dependency Table (MANDATORY)

Flat table backing the preview in 8a. Every task/subtask/sub-sub-task from 8a MUST have a row here with its explicit `blockedBy` relationships. Pattern: BUILD → VERIFY (blocking) → CHECKPOINT → next phase.

| Task ID | Description | Phase/Wave | Parent | blockedBy | Type |
|---------|-------------|-----------|--------|-----------|------|
| T1 | ... | Phase 1 | — | — | BUILD |
| T1.1 | ... | Phase 1 | T1 | — | BUILD |
| T1.2 | ... | Phase 1 | T1 | T1.1 | BUILD |
| T2 | Verify T1 output | Phase 1 | — | T1 | VERIFY |
| T3 | Checkpoint | Phase 1 | — | T2 | CHECKPOINT |
| T4 | ... | Phase 2 | — | T3 | BUILD |

**Rules:**
- Task IDs use dot notation for nesting (T1, T1.1, T1.1.a)
- `Parent` column links sub-sub-tasks back to their subtask; top-level phase tasks have `—`
- `blockedBy` lists every task that must complete before this one starts (dependency edges)
- Every ID in 8a must exist here; every ID here must appear in 8a

#### 8c. Mandatory Phase 0: Scaffold (ALL scopes, POST-APPROVAL for Medium+)

Every plan at every scope MUST begin with a Phase 0 that handles project scaffolding. This phase is not optional — it ensures STATE.md exists, TaskCreate entries are wired, and the system is ready for tracked execution.

**IMPORTANT (post-v2 overhaul, 2026-04-22):** For Medium, Large, and Ultra scope, **Phase 0 runs AFTER Tyler approves the orchestration plan via `ExitPlanMode`**. Creating the staging dir, STATE.md, TaskCreate entries, or daily-note entry before plan approval is a protocol violation (see `.claude/commands/the-protocol.md` rule #10 and `docs/morpheus-features/north-star-standard.md` §2.1 invariant #2). For Mini and Small, Phase 0 runs directly after Step 6 clarifications (no plan-mode gate).

Phase 0 subtasks (adapt to scope; all artifacts include `schema-version: 2` frontmatter where applicable):

```
◻ Phase 0: Scaffold (post-approval for Medium+)
    ◻ Create staging directory: hub/staging/{task-id}/
    ◻ Create STATE.md from hub/templates/state.md (schema-version: 2 frontmatter with plan-approved-at, planner-task-id, pending-decisions, blockers, verified-artifacts, resume-command)
    ◻ Register TaskCreate entries matching section 8a preview
    ◻ Create HANDOFF.md from hub/templates/handoff.md (Ultra only — Wave 0 prerequisite)
    ◻ Create Planner task (Large/Ultra — idempotent by task-id slug; AskUserQuestion for Medium; skip for Small/Mini)
    ◻ Prepend daily-note timeline entry documenting task initialization
    ◻ VERIFY Phase 0: staging dir + STATE.md + HANDOFF.md (Ultra) exist, frontmatter has schema-version: 2, TaskCreate entries match 8a, Planner task recorded in STATE.md (Large/Ultra)
```

For Small scope, Phase 0 may be condensed to a single subtask ("Create STATE.md + TaskCreate entries"). For Medium+, all subtasks are required.

**Failure to execute Phase 0 in the correct position (post-approval for Medium+; before work for Mini/Small) is a protocol violation.** Both pre-approval scaffolding and missing scaffolding are detected by the audit hook (`.claude/hooks/protocol-execution-audit.ps1`) and surface to `hub/state/harness-audit-ledger.md` as `SCAF:N` and `RESULT:FAIL` rows.

#### 8d. VERIFY and CHECKPOINT Definitions

VERIFY and CHECKPOINT are not decoration — they are **blocking tasks** with explicit execution steps.

**VERIFY** (appears after every phase's BUILD tasks):
1. Check that all output files from this phase exist (Glob/test -f)
2. Run phase-specific validation (from section 9 gates or section 7 acceptance criteria)
3. If code: run tests, check syntax, verify imports
4. If docs/config: check structure, cross-refs, frontmatter validity
5. Record pass/fail in STATE.md Progress Summary
6. If FAIL → trigger DIAGNOSE-FIX-RETRY (section 13), do NOT advance

**CHECKPOINT** (appears after every VERIFY):
1. Update STATE.md:
   - Progress Summary: append this phase's outcome with timestamp
   - `current-wave` / `current-round`: increment
   - `last-updated`: set to now
   - Open Items: add/remove as needed
   - Next Action: set to next phase's first task
2. Update TaskUpdate: mark this phase's tasks as `completed`
3. Confirm active-tasks.md regenerated (PostToolUse hook handles this automatically)

**A CHECKPOINT that does not update STATE.md is a no-op and a protocol violation.**

#### 8e. Launch Protocol

When the plan is launched (after Tyler approval), the orchestrator MUST:
1. Execute Phase 0: Scaffold (create staging dir, STATE.md, TaskCreate entries)
2. Read section 8a verbatim
3. Create the Claude Code task list via TaskCreate, preserving the exact hierarchy
4. Apply the `blockedBy` dependencies from 8b to each task
5. Confirm the created task list matches the preview before dispatching the first work agent
6. After EACH phase: execute VERIFY then CHECKPOINT before advancing

### 9. Three-Tier Verification Gates
Per-phase, all-or-nothing. Cumulative across phases.

**Code tasks:**
- Tier 1 (Build/Lint): files exist, syntax valid, imports resolve
- Tier 2 (Unit): this phase's tests + ALL prior unit tests pass
- Tier 3 (E2E/Integration): cumulative integration tests pass

**Non-code tasks (docs/plans/runbooks):**
- Tier 1: structure check (all sections present, frontmatter valid)
- Tier 2: content validation (accuracy, completeness, cross-refs exist)
- Tier 3: cross-reference integrity (all `ref:` links resolve via Glob)

### 10. Test Strategy / TDD
Tests defined BEFORE implementation. Specify:
- Framework (pytest / Pester / bats-core / manual KQL)
- Test location (`tests/` mirroring source structure)
- How to run (`pytest tests/` / `Invoke-Pester` / etc.)
- Link to Tier 2 gate in section 9

### 11. Build Path
Ordered task execution with inputs, outputs, per-task validation, and STATE.md checkpoint instructions. Each task references its Task ID from section 8. Every task block MUST include all five fields below — no field may be omitted.

```
#### T1 — {Task Description}
- Input: {file or artifact}
- Output: {file path}
- Validation: {command or check that proves it worked}
- TaskUpdate: Mark T1 as `completed` in session task list
- STATE.md checkpoint: Update Progress Summary with "{task description}: DONE [{timestamp}]"
```

**Rules:**
- `Validation:` must be a concrete, executable check (file exists, grep for string, test runs, etc.) — not "verify it looks correct"
- `TaskUpdate:` is mandatory — the session task list MUST reflect reality at every step
- `STATE.md checkpoint:` is mandatory for every task that produces output. For trivial subtasks within a phase, a single checkpoint at the phase's CHECKPOINT task is acceptable, but the checkpoint task itself is non-negotiable.
- VERIFY and CHECKPOINT tasks use the definitions from section 8d — do not redefine them per task

### 12. Forward-Reference Markers
For circular dependencies where section A needs info from section B, not yet written. Use the marker pattern inline:

```
[PENDING <TOPIC> -- will be updated after <Phase/Task ID>]
```

Schedule consistency passes after the dependency resolves. Limit markers to genuine circular deps — not missing work.

### 13. DIAGNOSE-FIX-RETRY Escalation

Two distinct iteration categories with separate limits. This distinction aligns with industry practice (SWE-agent, AutoCodeRover, Aider use 3 for Category A; AgentCoder, CrewAI, Cursor use 5-20 for Category B). See `hub/staging/2026-04-15-research-agentic-retry-limits/wave-1/round-1/research-agentic-retry-limits.md` for the 14-harness comparison.

#### Category A — Diagnostic Retry Ladder (same fault, broader context each attempt)

3-attempt circuit breaker for when an action fails and the agent retries the same action with escalating context. Maps to SME assessor verdicts.

- **Attempt 1**: Diagnose root cause → apply targeted fix → retry. SME verdict: CONTINUE.
- **Attempt 2**: Broaden context (read adjacent files, check env) → apply different fix → retry. SME verdict: CONTINUE.
- **Attempt 3**: Escalate to Tyler with full diagnostic log (what failed, what was tried, hypothesis). SME verdict: FLAG.

Never proceed past 3 diagnostic attempts without Tyler's input.

#### Category B — Build-Test Loop Limit (iterative code+test cycle)

For code tasks, the outer build-test loop (write code → run tests → diagnose → fix → repeat) scales by scope. Each failed test run that produces a new implementation attempt counts as one iteration. This is separate from Category A — a single iteration of Category B may internally use up to 3 Category A diagnostic attempts.

| Scope | Max Build-Test Iterations | Escalation after exhaustion |
|-------|---------------------------|-----------------------------|
| Small | 5 | FLAG to Tyler with failing test output + attempted fixes |
| Medium | 10 | FLAG to Tyler + SME review of approach |
| Large | 15 | FLAG to Tyler + consider scope re-evaluation |
| Ultra | 15 per phase | Per-phase gate; cumulative re-plan if two phases exhaust |

Rules:
- The limit applies **per build target** (e.g., per function under test, per component), not per task overall.
- An SME verdict of CONTINUE after a failed test run consumes one iteration.
- Partial progress (e.g., 3 of 5 tests passing, up from 2) resets the iteration counter ONLY if the SME explicitly notes meaningful convergence; otherwise count continues.
- Reaching the cap with no convergence signal is a FAIL verdict, not a CONTINUE — surface to Tyler before more effort is spent.

#### Category C — Session/Wave Budgets

The wave/round limits in CLAUDE.md scope table (1-5 rounds per wave) govern high-level session budget. A wave that exhausts its round budget without the SME issuing ADVANCE triggers FLAG to Tyler, independent of Category A/B counters.

### 14. Agent Return Protocol
Every agent completing a task MUST return this structured block:

```
AGENT COMPLETE: [what was the focus]
OUTPUT FILE: [absolute path]
SUMMARY: [2-3 key findings or decisions made]
KEY FINDING: [single most important insight]
INTENT ALIGNMENT: [how this output serves the Intent from section 2]
STATUS: COMPLETE | PARTIAL | BLOCKED
GAPS: [anything not completed and why]
```

### 15. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| {description} | Low/Med/High | Low/Med/High | {action} |

### 16. Output Files + Changelog
Table of all files this plan produces or modifies, followed by the standard changelog.

| # | File | Description | Agent |
|---|------|-------------|-------|
| 1 | /abs/path | What it is | builder |

```markdown
## Changelog
| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| {ISO} | {task-id} | planner | Created initial plan |
```
Max 10 entries, newest first.

## Changelog
| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-24T16:30 | 2026-04-24-integration-depth-clarification-rule | builder | Inserted §6.5 Integration-Depth Sanity Check between §6 and §7; added §6.5 row to Scope Gating table |
