---
type: pattern
scope: ultra
---

# Ultra Scope Pattern

Maximum-complexity tasks spanning multiple sessions, requiring deep multi-domain research, detailed planning with TDD, iterative building with verification, and comprehensive documentation. Use for projects that will take days or weeks, involve cross-project dependencies, or require sustained Tyler collaboration throughout.

## Wave Sequence

| Wave | Agent | Purpose |
|------|-------|---------|
| 1 | gatherer | Deep multi-source research — external + internal + cross-project |
| 2 | gatherer | Focused follow-up research on gaps from Wave 1 |
| 3 | planner | Comprehensive plan with TDD strategy, phased build path, risk matrix |
| 4 | builder | Phase 1 build — core deliverables with tests |
| 5 | builder + verifier | Phase 2 build — remaining deliverables + independent verification |
| 6+ | builder/verifier | Additional phases as needed — fix rounds, extensions, refinements |
| N | documenter | Final documentation pass |

Wave count is variable (5+). Morpheus determines actual wave count at planning time and adjusts dynamically based on assessor feedback.

## Round Ranges

| Wave | Min Rounds | Max Rounds | Typical |
|------|-----------|------------|---------|
| 1 (Research — broad) | 2 | 5 | 3 |
| 2 (Research — focused) | 2 | 4 | 2 |
| 3 (Planning) | 2 | 5 | 3 |
| 4 (Build — phase 1) | 2 | 5 | 3-4 |
| 5 (Build — phase 2 + verify) | 2 | 5 | 3 |
| 6+ (Additional phases) | 2 | 5 | 2-3 |
| N (Documentation) | 2 | 3 | 2 |

**max_rounds_per_wave**: 8

## Checkpoints

- **After Research waves (Waves 1-2)**: Morpheus presents consolidated research summary. Tyler confirms direction, adjusts scope, or requests additional investigation.
- **After Planning wave (Wave 3)**: Full plan review — Morpheus relays Objective, Acceptance Criteria, TDD Strategy, Build Phases, and Risk Matrix. Tyler confirms or restructures.
- **After each Build phase (Waves 4, 5, 6+)**: Morpheus presents build progress summary. Tyler reviews, requests changes, or approves continuation.
- **Before Documentation wave**: Morpheus confirms all deliverables are verified and Tyler-approved before final documentation pass.

## Cross-Session State

Ultra tasks persist across sessions via:
1. **`hub/state/active-tasks.md`**: Entry with current wave/round and next action
2. **`hub/staging/{task-id}/STATE.md`**: Full living document — assessors keep this current
3. **Session resume protocol**: Morpheus reads active-tasks.md on session start, then reads relevant STATE.md to resume

### Session Boundary Handling
- Before ending a session: Morpheus ensures STATE.md and active-tasks.md reflect current state
- On session resume: Morpheus reads STATE.md, presents last assessor's verdict and next action to Tyler
- Cross-session artifacts: All wave/round outputs persist in staging directory — no work is lost

## Verifier Rules

- **Verifier dispatch**: Required after every build phase (not just the final one). Each build phase gets independent verification.
- **Multi-verifier rounds**: If verifier disputes are found, a fix round + re-verification cycle runs before the next build phase.
- **SME assessor**: Dispatched after every round. For cross-domain work, multiple SME personas dispatched sequentially per round.
- **Verification escalation**: If verifier confidence stays below 80% after a fix round, auto-FLAG to Tyler with the disputed claims and evidence.

## Circuit Breaker

If any wave hits 8 rounds without ADVANCE:
- Auto-FLAG to Tyler: "Wave {N} ({wave-name}) hit round limit (8). This is an ultra-scope task and limits are generous. Assessor's diagnosis: {last verdict summary}. Options: extend limit by 3, restructure remaining waves, descope deliverables, or pause task?"
- Ultra tasks should rarely hit this limit — if they do, the task likely needs restructuring, not just more rounds.

## Example Flow

```
User: "Design and build a complete SOC automation platform: threat detection library,
       automated response playbooks, analyst dashboard specs, metrics framework,
       and integration architecture for Sentinel + Defender + Proofpoint."
Morpheus: scope = ultra (multi-domain, multi-deliverable, will span sessions)

Session 1:
  Wave 1: Research — broad (3 rounds)
    Round 1: [gatherer] → SOC automation frameworks + industry benchmarks
             [SME: SecOps] → Verdict: CONTINUE — need vendor-specific integration docs.
    Round 2: [gatherer] → Sentinel/Defender/Proofpoint API capabilities
             [SME: SecOps + Integration Specialist] → Verdict: CONTINUE — need detection rule patterns.
    Round 3: [gatherer] → detection libraries + MITRE ATT&CK mapping strategies
             [SME: SecOps + Threat Intel Specialist] → Verdict: ADVANCE — broad research complete.
    → Tyler checkpoint: "Research covers 5 domains. Key finding: Logic Apps preferred for 
       Sentinel SOAR. Gap: need your Proofpoint license tier." Tyler: "Enterprise."

  Wave 2: Research — focused (2 rounds)
    Round 1: [gatherer] → Proofpoint Enterprise API + dashboard metric patterns
             [SME: SecOps + Data Analyst] → Verdict: CONTINUE — need KPI benchmarks.
    Round 2: [gatherer] → SOC KPI benchmarks + dashboard UX patterns
             [SME: SecOps + Data Analyst] → Verdict: ADVANCE — focused research complete.
    → Tyler checkpoint: Confirms focused findings. "Prioritize detection library first."

  Wave 3: Planning (3 rounds)
    Round 1: [planner] → drafts comprehensive plan with 4 build phases
             [SME: Software Architect + SecOps] → Verdict: CONTINUE — TDD strategy needs detail.
    Round 2: [planner] → adds test framework, refines acceptance criteria per phase
             [SME: Software Architect] → Verdict: CONTINUE — risk matrix incomplete.
    Round 3: [planner] → completes risk matrix, finalizes build phases
             [SME: Software Architect + Operations Expert] → Verdict: ADVANCE — plan complete.
    → Tyler checkpoint: Full plan review. Tyler approves Phase 1 priorities, defers Phase 4.

Session 2 (next day):
  Morpheus reads active-tasks.md → resumes at Wave 4.
  "Resuming SOC automation platform task. Last state: planning complete, Wave 4 (Build Phase 1) next."

  Wave 4: Build — Phase 1: Detection Library (4 rounds)
    Round 1: [builder] → test framework + first 10 KQL detection rules
             [SME: SecOps + KQL Specialist] → Verdict: CONTINUE — 10/25 rules, tests passing.
    → Tyler checkpoint (first build): "10/25 detection rules done, tests green." Tyler: "Continue."
    Round 2: [builder] → next 10 rules + MITRE mapping
             [SME: SecOps + KQL Specialist] → Verdict: CONTINUE — 20/25, 2 need optimization.
    Round 3: [builder] → remaining 5 rules + optimization fixes
             [SME: SecOps + KQL Specialist] → Verdict: ADVANCE — Phase 1 build complete.
    Round 4: [verifier] → blind verification of all 25 rules
             Verdict: VERIFIED (91%) — 1 deprecated table reference found.
    → Tyler checkpoint: "Detection library complete, verified at 91%. 1 minor fix needed."

  Wave 5: Build — Phase 2: Response Playbooks (3 rounds)
    ...continues across sessions as needed...

  Wave N: Documentation
    Round 1: [documenter] → comprehensive doc update
             [SME: QA Analyst] → Verdict: CONTINUE — cross-refs incomplete.
    Round 2: [documenter] → fixes cross-refs, completes INDEX.md
             [SME: QA Analyst] → Verdict: ADVANCE — documentation complete.

→ Task complete. Moved to completed-tasks.md.
```

## When to Use Ultra

- Multi-session projects spanning days or weeks
- 5+ distinct deliverable types across multiple domains
- Projects requiring sustained Tyler collaboration and multiple review gates
- Cross-project dependencies or platform-level work
- Tasks requiring 20-50+ total agent dispatches

## When Ultra Is Overkill

- If the task can be described in one sentence, it is not ultra
- If all deliverables are in one domain, large is likely sufficient
- If no cross-session persistence is needed, large scope with extra waves is better
