---
type: pattern
scope: small
---

# Small Scope Pattern

Two-wave tasks that need a brief research or planning phase before producing the deliverable. Use for tasks with moderate complexity where the requirements are mostly clear but some context gathering is needed first.

## Wave Sequence

| Wave | Agent | Purpose |
|------|-------|---------|
| 1 | gatherer or planner | Research context or create a lightweight plan |
| 2 | builder or documenter | Produce the deliverable using Wave 1 output |

## Round Ranges

| Wave | Min Rounds | Max Rounds | Typical |
|------|-----------|------------|---------|
| 1 | 1 | 2 | 1 |
| 2 | 1 | 2 | 1 |

**max_rounds_per_wave**: 3

## Checkpoints

- **Tyler checkpoints**: None — small scope tasks proceed without human interruption.
- **Post-wave confirmation**: None.

## Verifier Rules

- **Verifier dispatch**: Never. Small tasks do not justify independent verification.
- **SME assessor**: Dispatched after each wave's work agent output. Assessor decides ADVANCE or CONTINUE within the round range.

## Circuit Breaker

If any wave hits 3 rounds without ADVANCE:
- Auto-FLAG to Tyler: "Wave {N} hit round limit (3). Options: extend to medium scope, skip wave, or abort?"

## Example Flow

```
User: "Write a knowledge article about Goodwin's Proofpoint TAP API integration."
Morpheus: scope = small (needs research first, then writing)

Wave 1: Research
  Round 1: [gatherer] → researches Proofpoint TAP API docs + existing internal files
           [SME: Security Operations + Email Security Specialist] → verifies sources
           Verdict: ADVANCE — 4 sources found, TAP API endpoints documented, gaps noted.

Wave 2: Build
  Round 1: [builder] → writes knowledge article using research artifact
           [SME: Technical Writer + Security Operations] → checks accuracy, structure, links
           Verdict: ADVANCE — article complete, cross-refs valid, changelog present.

→ Task complete. Documenter updates daily note + INDEX.md.
```

## When to Use Small

- Research-then-build tasks with clear deliverable shape
- Knowledge articles or runbook drafts needing background research
- Config or script creation needing API/tool documentation first
- Tasks requiring 2-5 total agent dispatches

## When to Upgrade to Medium

- Task requires both research AND a detailed plan before building
- Multiple deliverables across different file types
- Acceptance criteria need Tyler's confirmation
- Research phase may take more than 2 rounds
