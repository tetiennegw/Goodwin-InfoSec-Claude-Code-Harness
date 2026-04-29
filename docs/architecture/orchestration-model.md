---
title: "Orchestration Model"
last-updated: 2026-04-08
related-files: [CLAUDE.md, .claude/rules/hub.md, hub/patterns/medium.md, hub/patterns/large.md]
---

# Orchestration Model

## The Orchestration Loop

Morpheus follows a strict loop for every task above passthrough scope:

```
1. Receive request
2. Assess scope (passthrough | mini | small | medium | large | ultra)
3. Create hub/staging/{task-id}/STATE.md with macro goal + validation framework
4. FOR each wave:
     round = 1
     WHILE round <= max_rounds:
       a. Dispatch WORK AGENT (gatherer/planner/builder/documenter)
       b. Work agent writes artifact, returns summary
       c. Dispatch SME ASSESSOR (parameterized per domain)
       d. Assessor reads artifact, verifies externally, updates STATE.md
       e. Read verdict:
          - ADVANCE  -> next wave
          - CONTINUE -> round += 1, iterate with feedback
          - FLAG     -> pause, ask Tyler
          - FAIL     -> retry different approach or escalate
     END WHILE
     IF max_rounds exceeded -> auto-FLAG to Tyler
   END FOR
5. Final wave (documenter) -> update notes, KB, INDEX.md
6. Task complete
```

## Scope Assessment

When a request arrives, Morpheus classifies it:

| Scope | When to Use | Waves | Max Rounds/Wave |
|-------|-------------|-------|-----------------|
| **Passthrough** | Simple question, no artifact needed | 0 | 0 |
| **Mini** | Single deliverable, clear requirements | 1 | 2 |
| **Small** | Research-then-build, mostly clear | 2 | 3 |
| **Medium** | Research + plan + build + docs | 3-4 | 4 |
| **Large** | Cross-domain, multi-deliverable, verification required | 4-5 | 6 |
| **Ultra** | Multi-session, 5+ deliverable types | 5+ | 8 |

Full pattern details: [Scope Patterns Reference](../reference/scope-patterns.md)

## STATE.md — The Living Document

Every task (mini and above) gets a STATE.md in `hub/staging/{task-id}/`. It contains:

- **Macro Goal**: What we are trying to accomplish
- **Validation Framework**: Acceptance criteria, SME roles, per-wave validation approach
- **Wave Plan**: Planned wave sequence with agent assignments
- **Progress Summary**: Timestamped log of completed rounds with evidence
- **Artifacts Produced**: Paths to all output files
- **Open Items**: Unresolved questions or blockers
- **Next Action**: What should happen next

SME assessors are the primary writers of STATE.md (after backing up to STATE.md.bak). Morpheus reads it but rarely writes to it directly.

See [STATE.md Specification](../reference/state-file-spec.md) for the full format.

## Dispatch Templates

When dispatching a work agent, Morpheus sends:

```
TASK: {what to do this round}
TASK_ID: {task-id}
STATE_FILE: {absolute path to STATE.md}
INDEX_FILE: {absolute path to INDEX.md}
INPUT FILES:
- {path}: {one-line description}
OUTPUT:
- Write to: {absolute output path}
CONSTRAINTS:
- Read STATE.md first for macro goal and progress
- Consult INDEX.md for existing files
- Return 6-10 sentence summary
```

For SME assessors, the dispatch includes ROLE (persona), VALIDATION CRITERIA (from STATE.md), and SCOPE (round range).

Full templates: [Dispatch Templates Reference](../reference/dispatch-templates.md)

## Circuit Breaker

Every scope has a `max_rounds_per_wave`. If a wave hits the limit without the assessor returning `ADVANCE`, Morpheus auto-FLAGs to Tyler with:
- Which wave and how many rounds elapsed
- The assessor's last verdict and summary
- Options: extend limit, skip wave, restructure, or abort

This prevents infinite loops.

## Tyler Checkpoints

Checkpoints are scope-dependent:

| Scope | Checkpoints |
|-------|-------------|
| Passthrough | None |
| Mini | None |
| Small | None |
| Medium | After planning wave |
| Large | After research + planning + first build round |
| Ultra | After every major phase (research, planning, each build phase) |

At a checkpoint, Morpheus summarizes progress and asks Tyler to confirm, edit, or redirect.

## Cross-Session Resume

For tasks that span sessions (large/ultra):

1. On session end: Morpheus ensures STATE.md and `hub/state/active-tasks.md` reflect current state
2. On session start: Morpheus reads `active-tasks.md` to find in-progress tasks
3. Reads each task's STATE.md to understand where things stand
4. Presents the last assessor verdict and next action to Tyler
5. Resumes from the recorded next-action

All artifacts persist in `hub/staging/{task-id}/` — no work is lost between sessions.

## Critical Rules

1. **Never dispatch two SME assessors in parallel** — they both write to STATE.md, causing conflicts
2. **Never do work directly** — always dispatch a sub-agent
3. **Compact completed waves after 3+ are done** — collapse to one-line summaries to save context
4. **Re-read STATE.md from disk** if you need past context rather than relying on token memory
5. **Pass file PATHS to agents, not content** — keep orchestrator context minimal
