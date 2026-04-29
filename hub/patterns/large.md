---
type: pattern
scope: large
---

# Large Scope Pattern

High-complexity tasks requiring deep research, detailed planning, multi-round building, and thorough documentation. Use for cross-domain projects, multi-deliverable efforts, or tasks where correctness is critical and must be independently verified.

## Wave Sequence

| Wave | Agent | Purpose |
|------|-------|---------|
| 1 | gatherer | Deep research — multiple sources, cross-domain context |
| 2 | planner | Detailed plan with TDD strategy, acceptance criteria, risk analysis |
| 3 | builder | Primary deliverables — iterative build with per-task validation |
| 4 | builder + verifier | Remaining deliverables + independent verification of all outputs |
| 5 | documenter | Full documentation pass — notes, KB, INDEX.md, state files |

Waves 4-5 are typical. Some large tasks may need only 4 waves if the build completes in one wave, or may extend to 5 if verification surfaces issues requiring a fix round.

## Round Ranges

| Wave | Min Rounds | Max Rounds | Typical |
|------|-----------|------------|---------|
| 1 (Research) | 2 | 4 | 2-3 |
| 2 (Planning) | 2 | 4 | 2 |
| 3 (Build — primary) | 2 | 4 | 3 |
| 4 (Build — remaining + verify) | 2 | 4 | 2-3 |
| 5 (Documentation) | 2 | 3 | 2 |

**max_rounds_per_wave**: 6

## Checkpoints

- **After Research wave (Wave 1)**: Morpheus summarizes key findings and gaps from assessor's STATE.md updates. Tyler confirms research direction or requests additional investigation.
- **After Planning wave (Wave 2)**: Morpheus relays the plan's Objective and Acceptance Criteria to Tyler. Tyler confirms, edits, or reprioritizes.
- **After first Build round (Wave 3, Round 1)**: Morpheus presents initial build output summary for Tyler review. Catches misalignment early before further build investment.

## Verifier Rules

- **Verifier dispatch**: Required. Dispatch verifier in Wave 4 after the final build round. Verifier operates blind to the plan — checks facts against reality, validates security claims, confirms file existence and cross-references.
- **SME assessor**: Dispatched after every round in every wave. Multiple SME personas may be dispatched sequentially for cross-domain work.
- **If verifier disputes claims**: Morpheus dispatches a fix round (builder) followed by re-verification. If disputes persist after fix, FLAG to Tyler.

## Circuit Breaker

If any wave hits 6 rounds without ADVANCE:
- Auto-FLAG to Tyler: "Wave {N} ({wave-name}) hit round limit (6). Assessor's last verdict: {summary}. Remaining gaps: {from STATE.md}. Options: extend limit by 2, skip to next wave, restructure task, or abort?"

## Example Flow

```
User: "Build a complete incident response automation framework with Sentinel integration,
       including detection rules, response playbooks, and KQL query library."
Morpheus: scope = large (cross-domain, multiple deliverables, needs deep research)

Wave 1: Research (3 rounds)
  Round 1: [gatherer] → NIST IR framework + Sentinel SOAR capabilities
           [SME: SecOps] → Verdict: CONTINUE — need Sentinel-specific playbook API research.
  Round 2: [gatherer] → Sentinel playbook/Logic App integration + KQL best practices
           [SME: SecOps + Sentinel Specialist] → Verdict: CONTINUE — need detection rule templates.
  Round 3: [gatherer] → detection rule patterns + community KQL repos
           [SME: SecOps + Sentinel Specialist] → Verdict: ADVANCE — research comprehensive.
  → Tyler checkpoint: "Research found 3 frameworks. Recommend NIST-aligned approach with
     Sentinel SOAR. Gap: need your input on alert severity mapping. Continue?" Tyler: "Yes, 
     use P1-P4 mapping from our existing policy."

Wave 2: Planning (2 rounds)
  Round 1: [planner] → creates detailed plan with TDD strategy
           [SME: Operations Expert + Software Architect] → Verdict: CONTINUE — needs test framework spec.
  Round 2: [planner] → adds test strategy, refines acceptance criteria
           [SME: Operations Expert] → Verdict: ADVANCE — plan complete.
  → Tyler checkpoint: Relays objective + acceptance criteria. Tyler confirms.

Wave 3: Build — primary (3 rounds)
  Round 1: [builder] → KQL detection rule library (tests first)
           [SME: SecOps + KQL Specialist] → Verdict: CONTINUE — 8/12 rules done.
  → Tyler checkpoint (first build): "KQL library 8/12 rules complete. On track." Tyler: "Proceed."
  Round 2: [builder] → remaining KQL rules + response playbook docs
           [SME: SecOps] → Verdict: CONTINUE — playbooks need Sentinel Logic App integration detail.
  Round 3: [builder] → completes playbook integration + automation scripts
           [SME: SecOps + Software Engineer] → Verdict: ADVANCE — primary build complete.

Wave 4: Build — verify (2 rounds)
  Round 1: [verifier] → blind fact-check of all deliverables
           Verdict: DISPUTES FOUND (78%) — 2 KQL queries reference deprecated tables.
  Round 2: [builder] → fixes deprecated table references
           [verifier] → re-verifies
           Verdict: VERIFIED (94%) — all claims confirmed.

Wave 5: Documentation (2 rounds)
  Round 1: [documenter] → updates all docs, KB, notes
           [SME: QA Analyst] → Verdict: CONTINUE — missing cross-refs in INDEX.md.
  Round 2: [documenter] → fixes cross-refs
           [SME: QA Analyst] → Verdict: ADVANCE — documentation complete.

→ Task complete.
```

## When to Use Large

- Multi-deliverable projects (scripts + docs + configs)
- Cross-domain work requiring multiple SME personas
- Tasks where factual accuracy has operational impact (IR playbooks, detection rules)
- Projects requiring 12-30 total agent dispatches
- Work that Tyler needs to review at multiple stages

## When to Upgrade to Ultra

- Task will span multiple sessions (days/weeks)
- More than 5 distinct deliverable types
- Requires iterative refinement across sessions with Tyler feedback loops
- Cross-project dependencies
