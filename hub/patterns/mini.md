---
type: pattern
scope: mini
---

# Mini Scope Pattern

One-shot tasks requiring a single agent dispatch and assessment. Use for quick lookups, simple file creation, straightforward edits, or any task completable in one focused pass.

## Wave Sequence

| Wave | Agent | Purpose |
|------|-------|---------|
| 1 | Any work agent (gatherer, planner, or builder) | Complete the task in one pass |

## Round Ranges

| Wave | Min Rounds | Max Rounds | Typical |
|------|-----------|------------|---------|
| 1 | 1 | 2 | 1 |

**max_rounds_per_wave**: 2

## Checkpoints

- **Tyler checkpoints**: None — task is too small to warrant interruption.
- **Post-wave confirmation**: None.

## Verifier Rules

- **Verifier dispatch**: Never. Mini tasks do not justify the cost of independent verification.
- **SME assessor**: Dispatched after the work agent's output. One assessment round is typical.

## Circuit Breaker

If Wave 1 hits 2 rounds without the assessor returning ADVANCE:
- Auto-FLAG to Tyler: "Mini task hit round limit (2). Options: extend to small scope, skip, or abort?"
- Do NOT silently continue past the limit.

## Example Flow

```
User: "Create a KQL query that detects failed login attempts from foreign IPs."
Morpheus: scope = mini (single deliverable, clear requirements)

Wave 1: Build
  Round 1: [builder] → writes kql query file
           [SME: Security Operations + KQL Specialist] → checks syntax, logic, MITRE mapping
           Verdict: ADVANCE — query is valid, covers T1078, thresholds reasonable.

→ Task complete. Documenter updates daily note with pointer.
```

## When to Use Mini

- Single-file deliverables with clear requirements
- Lookups that need an artifact written (not just an answer)
- Quick research that requires a structured output
- Simple script or config generation

## When to Upgrade to Small

- Task requires research before building (2 waves)
- Multiple files need to be produced
- Requirements are ambiguous and need a planning step
