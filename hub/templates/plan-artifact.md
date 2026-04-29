---
type: plan
task-id: "{TASK_ID}"
agent: planner
created: "{YYYY-MM-DDThh:mm}"
last-updated: "{YYYY-MM-DDThh:mm}"
inputs:
  - "{/abs/path/to/research-artifact.md}"
  - "{/abs/path/to/STATE.md}"
scope: "{small|medium|large|ultra}"
---

# Plan: {Deliverable Title}

---
## 1. Intent

<!-- Required: medium+ | Optional: small (1-2 lines) | Skip: mini -->

- **Motivation** — {Why this task exists and why it matters to Tyler/Goodwin.}
- **Desired Experience** — {What success looks and feels like end-to-end from Tyler's perspective.}
- **Preservation Requirements** — {What must NOT break or change as a result of this work.}
- **Success Criteria** — {Concrete, observable outcome confirming Tyler's goal is met.}

---

## 2. Objective

<!-- Required: all scopes -->

> **Relayed to Tyler for confirmation before work begins.**

{2-3 sentences describing exactly what is being built. Be specific about deliverable type, scope, and target location.}

---

## 3. Pre-existing Artifact Inventory

<!-- Required: medium+ | Skip: small/mini -->

| # | Artifact | Path | Disposition |
|---|----------|------|-------------|
| 1 | {Name} | {/abs/path} | {SKIP / REUSE / PRESERVE+extend / GENERATE} |
| 2 | {Name} | {/abs/path} | {SKIP / REUSE / PRESERVE+extend / GENERATE} |

---

## 4. Research References

<!-- Required: medium+ | Include if research done: small | Skip: mini -->

| # | Artifact | Key Insight | Path |
|---|----------|-------------|------|
| 1 | {Artifact name} | {One-line takeaway from this artifact} | {/abs/path} |
| 2 | {Artifact name} | {One-line takeaway from this artifact} | {/abs/path} |

---

## 5. Existing Codebase References

<!-- Required: medium+ | Include if applicable: small | Skip: mini -->

| # | File / Module | Relevance | Path |
|---|---------------|-----------|------|
| 1 | {File or module name} | {Why this file matters to the build} | {/abs/path} |
| 2 | {File or module name} | {Why this file matters to the build} | {/abs/path} |

---

## 6. Acceptance Criteria (EODIC)

<!-- Required: all scopes. Small: 3-5 items. Medium+: exhaustive. -->
<!-- Each criterion must be: Executable, Observable, Deterministic, Independent, Cumulative -->

- [ ] {Criterion}: verified by `{command or tool that produces pass/fail}`
- [ ] {Criterion}: verified by `{command or tool that produces pass/fail}`
- [ ] {Criterion}: verified by `{command or tool that produces pass/fail}`
- [ ] {Criterion}: verified by `{command or tool that produces pass/fail}`
- [ ] {Criterion}: verified by `{command or tool that produces pass/fail}`

---

## 7. Task List with Dependencies

<!-- Required: medium+ | Skip: small/mini -->
<!-- Pattern: BUILD -> VERIFY (blocking) -> CHECKPOINT -> next phase -->

| Task ID | Description | Phase / Wave | blockedBy | Type |
|---------|-------------|--------------|-----------|------|
| T1 | {Task description} | Phase 1 | -- | BUILD |
| T2 | Verify T1 output | Phase 1 | T1 | VERIFY |
| T3 | Checkpoint | Phase 1 | T2 | CHECKPOINT |
| T4 | {Task description} | Phase 2 | T3 | BUILD |
| T5 | Verify T4 output | Phase 2 | T4 | VERIFY |
| T6 | Checkpoint | Phase 2 | T5 | CHECKPOINT |

---

## 8. Three-Tier Verification Gates

<!-- Required: large/ultra | Optional: medium | Skip: small/mini -->
<!-- All-or-nothing per phase. Cumulative across phases. -->

### Phase 1

- **Tier 1 (Structure/Lint)** — {Files exist at expected paths; syntax valid; imports/references resolve.}
- **Tier 2 (Unit/Content)** — {This phase's tests pass; or content validation criteria met.}
- **Tier 3 (Integration/E2E)** — {Cumulative integration or cross-reference integrity tests pass.}

### Phase 2

- **Tier 1 (Structure/Lint)** — {Files exist at expected paths; syntax valid.}
- **Tier 2 (Unit/Content)** — {Phase 2 tests pass; ALL Phase 1 tests still pass.}
- **Tier 3 (Integration/E2E)** — {Cumulative integration tests pass.}

> For non-code tasks: Tier 1 = structure check, Tier 2 = content accuracy, Tier 3 = cross-ref integrity via Glob.

---

## 9. Test Strategy / TDD

<!-- Required: medium+ for code tasks | Include if code task: small | Skip: non-code small/mini -->
<!-- Tests are written BEFORE implementation. -->

### Tests to Write First

1. **{Test Name}** -- {What this test validates and how failure is detected.}
2. **{Test Name}** -- {What this test validates and how failure is detected.}
3. **{Test Name}** -- {What this test validates and how failure is detected.}

### Framework

| Language | Framework | Test Location |
|----------|-----------|---------------|
| {Python / PowerShell / Bash / KQL} | {pytest / Pester / bats-core / manual} | {`tests/` mirroring source} |

### How to Run

```bash
# {Test 1 name}
{command}

# {Test 2 name}
{command}

# {Test 3 name}
{command}
```

> These tests link to Tier 2 gate in section 8.

---

## 10. Build Path

<!-- Required: all scopes -->
<!-- Each task references its Task ID from section 7. -->

#### T1 -- {Task Description}

- **Input**: {File, artifact, or prior task output}
- **Output**: {Absolute output file path}
- **Validation**: {Command or check that proves T1 succeeded}

#### T2 -- Verify T1 Output

- **Input**: T1 output at `{/abs/path}`
- **Output**: Verification report or pass/fail signal
- **Validation**: {Specific check command; must be external evidence, not self-report}

#### T3 -- Checkpoint

- **Action**: Update STATE.md; confirm with Tyler if flagged.

#### T4 -- {Task Description}

- **Input**: {File, artifact, or prior task output}
- **Output**: {Absolute output file path}
- **Validation**: {Command or check that proves T4 succeeded}

---

## 11. Forward-Reference Markers

<!-- Required: large/ultra | Include if circular deps exist: medium | Skip: small/mini -->
<!-- Use only for genuine circular dependencies, not missing work. -->

```
[PENDING <{TOPIC}> -- will be updated after <{Phase/Task ID}>]
```

{Describe the circular dependency here. Schedule a consistency pass after the blocking task resolves.}

---

## 12. DIAGNOSE-FIX-RETRY Escalation

<!-- Required: medium+ | Skip: small/mini -->

3-attempt circuit breaker. Maps to SME assessor verdicts.

- **Attempt 1** -- Diagnose root cause -> apply targeted fix -> retry. SME verdict: CONTINUE.
- **Attempt 2** -- Broaden context (read adjacent files, check environment) -> apply different fix -> retry. SME verdict: CONTINUE.
- **Attempt 3** -- Escalate to Tyler with full diagnostic log: what failed, what was tried, current hypothesis. SME verdict: FLAG.

Never proceed past 3 attempts without Tyler's input.

---

## 13. Agent Return Protocol

<!-- Required: medium+ | Skip: small/mini -->

Every agent completing a task in this plan MUST return this structured block:

```
AGENT COMPLETE: [{what was the focus of this task}]
OUTPUT FILE: [{absolute path to primary deliverable}]
SUMMARY: [{2-3 key findings or decisions made}]
KEY FINDING: [{single most important insight from this task}]
INTENT ALIGNMENT: [{how this output serves the Intent from section 1}]
STATUS: COMPLETE | PARTIAL | BLOCKED
GAPS: [{anything not completed and why; "None" if fully complete}]
```

---

## 14. Risks & Mitigations

<!-- Required: medium+ | Optional: small | Skip: mini -->

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| {Risk description} | Low / Med / High | Low / Med / High | {Specific action to reduce or handle this risk} |
| {Risk description} | Low / Med / High | Low / Med / High | {Specific action to reduce or handle this risk} |
| {Risk description} | Low / Med / High | Low / Med / High | {Specific action to reduce or handle this risk} |

---

## 15. Output Files

<!-- Required: all scopes -->

| # | File | Description | Agent |
|---|------|-------------|-------|
| 1 | {/abs/path/to/output-file.ext} | {What this file is and what it contains} | {builder / documenter} |
| 2 | {/abs/path/to/output-file.ext} | {What this file is and what it contains} | {builder / documenter} |

---

## Changelog

| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-08T09:45 | plan-standard-integration | builder | Expanded template from 10 to 16 sections per implementation plan standard |
