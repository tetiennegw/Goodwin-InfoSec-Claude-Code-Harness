---
type: pattern
scope: medium
---

# Medium Scope Pattern

Multi-wave tasks requiring research, planning, building, and documentation. The most common pattern for substantive work. Use for tasks with moderate-to-high complexity where requirements need discovery and a structured plan before execution.

## Wave Sequence

| Wave | Agent | Purpose |
|------|-------|---------|
| 1 | gatherer | Research context, gather requirements, identify constraints |
| 2 | planner | Create structured plan with acceptance criteria and build path |
| 3 | builder | Produce deliverables following the plan |
| 4 | documenter | Update daily notes, knowledge base, INDEX.md, state files |

Waves 3-4 are typical. Some medium tasks may skip Wave 1 (if context is already available) or combine Waves 3-4, resulting in 3 waves.

## Round Ranges

| Wave | Min Rounds | Max Rounds | Typical |
|------|-----------|------------|---------|
| 1 (Research) | 1 | 3 | 1-2 |
| 2 (Planning) | 1 | 3 | 1 |
| 3 (Build) | 1 | 3 | 2 |
| 4 (Documentation) | 1 | 2 | 1 |

**max_rounds_per_wave**: 4

## Checkpoints

- **After Planning wave (Wave 2)**: Morpheus relays the plan's Objective section to Tyler for confirmation or edits. Tyler may adjust acceptance criteria, priorities, or scope.
- **No other checkpoints**: Research and build proceed without interruption unless FLAG is returned.

## Verifier Rules

- **Verifier dispatch**: Optional. Morpheus may dispatch verifier after the final build round if the deliverable contains factual claims, security recommendations, or external references that need independent validation.
- **SME assessor**: Dispatched after every round in every wave. The assessor is the primary quality gate.
- **Verifier vs. assessor**: Assessor checks "did we follow the plan?" Verifier checks "are the facts correct?" — only needed when factual accuracy is critical.

## Circuit Breaker

If any wave hits 4 rounds without ADVANCE:
- Auto-FLAG to Tyler: "Wave {N} ({wave-name}) hit round limit (4). Current state: {assessor's last summary}. Options: extend limit, skip to next wave, or abort?"

## Example Flow

```
User: "Create a phishing triage runbook for the SOC team."
Morpheus: scope = medium (needs research, planning, building, docs — 4 waves)

Wave 1: Research
  Round 1: [gatherer] → researches NIST/SANS/Cofense frameworks + Goodwin email infra
           [SME: SecOps + Sentinel Specialist] → verifies sources via WebSearch
           Verdict: CONTINUE — found frameworks but need Sentinel-specific query patterns.
  Round 2: [gatherer] → deeper research on Sentinel + Proofpoint integration
           [SME: SecOps + Sentinel Specialist] → verifies 3 sources
           Verdict: ADVANCE — research sufficient for planning.

Wave 2: Planning
  Round 1: [planner] → creates structured runbook plan with acceptance criteria
           [SME: Operations Expert] → validates plan feasibility and completeness
           Verdict: ADVANCE — plan complete.
  → Tyler checkpoint: Morpheus relays plan objective. Tyler confirms.

Wave 3: Build
  Round 1: [builder] → writes runbook per plan tasks 1-3
           [SME: SecOps + Sentinel Specialist] → checks content, verifies KQL syntax
           Verdict: CONTINUE — main doc done but detection logic section incomplete.
  Round 2: [builder] → completes remaining sections
           [SME: SecOps] → then [SME: QA Analyst] → both verify
           Verdict: ADVANCE — deliverable complete, all files verified via Glob.

Wave 4: Documentation
  Round 1: [documenter] → updates daily note, KB, INDEX.md
           [SME: QA Analyst] → verifies cross-refs and changelog
           Verdict: ADVANCE — all documentation updated.

→ Task complete.
```

## When to Use Medium

- Runbooks, procedures, or process documentation
- Multi-section knowledge articles requiring research
- Script development needing requirements gathering
- Tasks requiring 6-15 total agent dispatches

## When to Upgrade to Large

- Research phase expected to take 3+ rounds
- Multiple distinct deliverables that build on each other
- Tyler needs to review intermediate build output (not just the plan)
- Cross-domain expertise needed (security + engineering + operations)
