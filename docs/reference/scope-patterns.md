---
title: "Scope Patterns"
last-updated: 2026-04-08
related-files: [hub/patterns/mini.md, hub/patterns/small.md, hub/patterns/medium.md, hub/patterns/large.md, hub/patterns/ultra.md]
---

# Scope Patterns

Morpheus assesses every incoming request and assigns a scope level that determines the wave sequence, round limits, checkpoint rules, and agent assignments.

## Scope Summary Table

| Scope | Waves | Rounds/Wave | Max Total | Checkpoints | Verifier |
|-------|-------|-------------|-----------|-------------|----------|
| **Passthrough** | 0 | 0 | 0 | None | No |
| **Mini** | 1 | 1-2 | 2 | None | No |
| **Small** | 2 | 1-2 | 3 | None | No |
| **Medium** | 3-4 | 1-3 | 4/wave | After planning | Optional |
| **Large** | 4-5 | 2-4 | 6/wave | After research + planning + first build | Required |
| **Ultra** | 5+ | 2-5 | 8/wave | Multiple, cross-session | Required |

---

## Passthrough

**When**: Simple questions that need a direct answer, no artifact needed.

**Behavior**: Morpheus answers directly without dispatching any agents.

**Example**: "What is the MITRE ATT&CK ID for spearphishing links?" -- Morpheus answers: "T1566.002."

---

## Mini

**Pattern file**: `hub/patterns/mini.md`

**Wave sequence**:
| Wave | Agent | Purpose |
|------|-------|---------|
| 1 | Any work agent | Complete the task in one pass |

**Round range**: 1-2 rounds. Circuit breaker at 2.

**Checkpoints**: None.

**Example**:
```
You: "Create a KQL query that detects failed login attempts from foreign IPs."
Morpheus: scope = mini
  Wave 1: [builder] writes query -> [SME] verifies syntax + MITRE mapping
  Verdict: ADVANCE
  Done.
```

**When to use**: Single-file deliverables with clear requirements. Quick lookups needing an artifact.

**Upgrade to small when**: Task needs research first, or requirements are ambiguous.

---

## Small

**Pattern file**: `hub/patterns/small.md`

**Wave sequence**:
| Wave | Agent | Purpose |
|------|-------|---------|
| 1 | gatherer or planner | Research context or create lightweight plan |
| 2 | builder or documenter | Produce deliverable using Wave 1 output |

**Round range**: 1-2 rounds per wave. Circuit breaker at 3.

**Checkpoints**: None.

**Example**:
```
You: "Write a knowledge article about our Proofpoint TAP API integration."
Morpheus: scope = small
  Wave 1: [gatherer] researches TAP API docs + internal files
  Wave 2: [builder] writes KB article using research
  Done.
```

**When to use**: Research-then-build tasks. KB articles needing background research.

**Upgrade to medium when**: Task needs both research AND detailed planning, or Tyler needs to confirm the plan.

---

## Medium

**Pattern file**: `hub/patterns/medium.md`

**Wave sequence**:
| Wave | Agent | Purpose |
|------|-------|---------|
| 1 | gatherer | Research context, requirements, constraints |
| 2 | planner | Structured plan with acceptance criteria |
| 3 | builder | Produce deliverables per plan |
| 4 | documenter | Update notes, KB, INDEX.md |

**Round range**: 1-3 rounds per wave. Circuit breaker at 4.

**Checkpoints**: After Wave 2 (planning) -- Morpheus relays the plan Objective to Tyler for confirmation.

**Example**:
```
You: "Create a phishing triage runbook for the SOC team."
Morpheus: scope = medium
  Wave 1: [gatherer] 2 rounds of research (NIST, SANS, Sentinel docs)
  Wave 2: [planner] 1 round, plan confirmed by Tyler
  Wave 3: [builder] 2 rounds (initial build + fix round)
  Wave 4: [documenter] 1 round
  Done. 4 waves, 6 rounds total.
```

**When to use**: Runbooks, multi-section articles, script development needing requirements. 6-15 total agent dispatches.

**Upgrade to large when**: Research expected to take 3+ rounds, multiple distinct deliverables, or Tyler needs to review build output.

---

## Large

**Pattern file**: `hub/patterns/large.md`

**Wave sequence**:
| Wave | Agent | Purpose |
|------|-------|---------|
| 1 | gatherer | Deep multi-source research |
| 2 | planner | Detailed plan with TDD, risks |
| 3 | builder | Primary deliverables |
| 4 | builder + verifier | Remaining deliverables + verification |
| 5 | documenter | Full documentation pass |

**Round range**: 2-4 rounds per wave. Circuit breaker at 6.

**Checkpoints**: After research, after planning, and after first build round.

**Example**:
```
You: "Build a complete incident response automation framework with
      Sentinel integration, detection rules, and response playbooks."
Morpheus: scope = large
  Wave 1: 3 rounds of deep research
  Wave 2: 2 rounds of planning with TDD strategy
  Wave 3: 3 rounds building detection library
  Wave 4: 2 rounds (remaining deliverables + verifier)
  Wave 5: 2 rounds documentation
  Done. 5 waves, 12 rounds total.
```

**When to use**: Cross-domain work, multi-deliverable projects, tasks where factual accuracy has operational impact. 12-30 agent dispatches.

**Upgrade to ultra when**: Task will span multiple sessions, 5+ deliverable types, or cross-project dependencies.

---

## Ultra

**Pattern file**: `hub/patterns/ultra.md`

**Wave sequence**:
| Wave | Agent | Purpose |
|------|-------|---------|
| 1 | gatherer | Broad multi-source research |
| 2 | gatherer | Focused follow-up research |
| 3 | planner | Comprehensive plan with phased build path |
| 4 | builder | Phase 1 build |
| 5 | builder + verifier | Phase 2 build + verification |
| 6+ | builder/verifier | Additional phases |
| N | documenter | Final documentation |

**Round range**: 2-5 rounds per wave. Circuit breaker at 8.

**Checkpoints**: After every major phase (research, planning, each build phase, before documentation).

**Cross-session**: Ultra tasks persist across sessions via `active-tasks.md` and `STATE.md`. Morpheus resumes from the last recorded next-action.

**Example**:
```
You: "Design and build a complete SOC automation platform: threat detection
      library, playbooks, dashboard specs, metrics, and integration architecture."
Morpheus: scope = ultra
  Session 1: Research (2 waves, 5 rounds) + Planning (1 wave, 3 rounds)
  Session 2: Build Phase 1 (4 rounds) + Phase 2 (3 rounds)
  Session 3: Remaining phases + verification + documentation
  Done. 8+ waves across 3 sessions.
```

**When to use**: Multi-session projects, 5+ deliverable types, sustained Tyler collaboration. 20-50+ agent dispatches.

**Ultra is overkill when**: Task described in one sentence, single domain, no cross-session needed.
