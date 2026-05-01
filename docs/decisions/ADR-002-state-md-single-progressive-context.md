---
title: "ADR-002: STATE.md as Single Progressive Context Document"
status: accepted
date: 2026-04-15
decision-makers: [{{user.name}}, Morpheus]
task-id: 2026-04-13-the-protocol-skill
agent: builder
created: 2026-04-15T00:00:00Z
last-updated: 2026-04-15T00:00:00Z
---

<!--
  Task: 2026-04-13-the-protocol-skill
  Agent: builder
  Created: 2026-04-15T00:00:00Z
  Last-Updated: 2026-04-15T00:00:00Z
  Plan: .claude/plans/fluffy-shimmying-waterfall.md
  Purpose: ADR documenting why STATE.md is a single progressive markdown doc, not a DB or split files
  Changelog (max 10):
    2026-04-15T00:00:00Z | 2026-04-13-the-protocol-skill | builder | Created ADR-002
-->

# ADR-002: STATE.md as Single Progressive Context Document

## Status
Accepted

## Context

Tasks in the Morpheus system span multiple sessions. The orchestrator must maintain enough
context to resume work accurately after a context window reset or a days-long gap. Each
wave produces new artifacts; each round updates the task's status, verdict, and next action.

Agents — orchestrator, builder, SME assessor, documenter — all need a shared view of task
state. They must know: what was the original goal? what has been done? what artifacts exist?
what is blocked? what happens next? This information needs to be accessible in a single read,
not assembled from multiple files per agent call.

The system runs on a Goodwin endpoint with AllSigned PowerShell policy and ThreatLocker.
External databases, SQLite, or structured stores require additional tooling and approval.
The environment is file-based by necessity.

## Decision

Every task gets exactly one `STATE.md` in its staging directory. It is the single source of
truth for that task's cross-session state.

STATE.md is structured with named sections — frontmatter (YAML, machine-readable), Macro Goal,
Project Scaffold (visual tree), Task Table, Context Inventory, Progress Summary, Validation
Framework, Open Items, and Next Action. Sections are added progressively as the task advances:
Mini scope tasks get frontmatter + Macro Goal + Next Action only; Ultra scope tasks get the
full schema including Context Inventory and subsystem status matrices.

Agents read STATE.md first and write to it after every wave. The PostToolUse hook regenerates
`active-tasks.md` from all STATE.md frontmatter fields automatically, giving a cross-task
index without manual maintenance.

## Alternatives Considered

### Alternative 1: External database or structured store

Use a SQLite database or JSON store to track task state, with agents querying/updating via
script calls.

- **Pros**: Relational queries possible; concurrent write safety; structured schemas
- **Cons**: Requires tooling not available on Goodwin endpoints; agents cannot read/write
  directly via LLM tools; adds a service dependency; cross-session state becomes opaque
- **Why rejected**: Environment constraints rule this out. File-based state is required.

### Alternative 2: Multiple tracking files (one per concern)

Split state across several files: `progress.md`, `tasks.md`, `artifacts.md`, `blockers.md`.

- **Pros**: Each file stays small; concerns are separated
- **Cons**: Every agent must read N files to get full context; write coordination across files
  is error-prone; SME assessors need full context in one read to write accurate verdicts;
  file count grows with task complexity
- **Why rejected**: Context assembly from multiple files costs tokens and introduces
  inconsistency risk. A single file with named sections is faster to read and harder to corrupt.

### Alternative 3: Flat unstructured STATUS.md

A single file but with no schema — free-form notes from each agent appended in sequence.

- **Pros**: Minimal structure; agents write freely
- **Cons**: Machine-readable parsing breaks (frontmatter fields cannot be extracted);
  active-tasks.md regeneration fails; Next Action is buried; verifiers cannot locate
  Validation Framework predictably
- **Why rejected**: Structured sections are required for hook-driven regeneration of
  active-tasks.md and for reliable cross-agent reads.

## Consequences

### Positive
- Every agent needs only one `Read` call to get full task context
- STATE.md frontmatter drives active-tasks.md regeneration automatically (PostToolUse hook)
- Schema-version field enables forward-compatible upgrades via migrators
- Visual scaffold tree in STATE.md lets Tyler inspect task progress at a glance

### Negative
- STATE.md grows large on Ultra scope tasks (may approach 500+ lines)
- Concurrent writes by two agents in the same wave would corrupt state (mitigated by rule:
  never dispatch two SME assessors in parallel)
- Schema must be versioned carefully; old STATE.md files must be migrated on schema bump

### Neutral
- Progressive section addition means Mini tasks have lightweight STATE.md; only complex
  tasks pay the overhead of full schema
- STATE.md.bak convention (SME assessors back up before writing) provides one-level recovery

## References
- `hub/templates/state.md` — canonical STATE.md template with all sections
- `.claude/protocols/_schema.md` — schema-version field and migration rules
- `hub/staging/2026-04-13-the-protocol-skill/wave-1/round-1/research-context-engineering.md` — blackboard architecture, progressive context
- `hub/staging/2026-04-13-the-protocol-skill/wave-1/round-1/research-autonomous-context-awareness.md` — HANDOFF.md pattern, dirty queue
- Plan Part 4: STATE.md redesign and visual scaffold spec

## Changelog
| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-15T00:00:00Z | 2026-04-13-the-protocol-skill | builder | Created ADR-002 |
