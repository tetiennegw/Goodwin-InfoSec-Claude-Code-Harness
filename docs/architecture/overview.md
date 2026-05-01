---
title: "Architecture Overview"
last-updated: 2026-04-08
related-files: [CLAUDE.md, INDEX.md, .claude/rules/hub.md]
---

# Architecture Overview

## System Diagram

```
                        +------------------+
                        |     You (Tyler)  |
                        |   Checkpoints    |
                        +--------+---------+
                                 |
                    +------------v-----------+
                    |       MORPHEUS          |
                    |    (Orchestrator)      |
                    |                        |
                    |  Reads: CLAUDE.md      |
                    |  Tracks: STATE.md      |
                    |  Maps: INDEX.md        |
                    +--+--+--+--+--+--+-----+
                       |  |  |  |  |  |
          +------------+  |  |  |  |  +-------------+
          |     +---------+  |  |  +--------+       |
          v     v            v  v           v       v
       +-----+-----+  +-----+-----+  +-----+-----+-----+
       |gather|plan |  |build|verif|  |docum|  SME      |
       |  er  | ner |  | er  | ier |  |enter| assessor  |
       +------+-----+  +-----+-----+  +-----+----------+
          |     |         |     |        |        |
          v     v         v     v        v        v
       +--------------------------------------------------+
       |              File System (Artifacts)              |
       |                                                   |
       |  hub/staging/{task-id}/   notes/YYYY/MM/          |
       |    STATE.md               YYYY-MM-DD.md           |
       |    research-*.md          INDEX.md                 |
       |    plan-*.md              hub/state/active-tasks   |
       |    build-*.md             knowledge/**             |
       |    assessment-*.md                                 |
       +--------------------------------------------------+
```

## Core Concepts

### Hub-and-Spoke Model

Morpheus is the **hub**. It never does work directly — it dispatches **spoke** agents (gatherer, planner, builder, verifier, documenter, sme-assessor). Each spoke writes its output to an artifact file and returns a 6-10 sentence summary. Morpheus reads summaries and file paths, never artifact contents.

### Waves and Rounds

Work progresses in **waves** (research, planning, building, documentation). Each wave has one or more **rounds** (work agent dispatch + SME assessment). Scope determines wave count and round limits.

### STATE.md — The Living Document

Every task has a `hub/staging/{task-id}/STATE.md` that tracks the macro goal, validation criteria, progress, artifacts, and next action. SME assessors update it after every round. It is the single source of truth for task state.

### Dynamic SME Assessors

The `sme-assessor` agent is a generic template parameterized at dispatch time with a **PERSONA** (who the SME is) and **DOMAIN_CRITERIA** (what to check). This means Morpheus can summon any kind of expert without needing a dedicated agent file for each domain.

### File-Based Artifact Passing

Agents communicate through files, not token carry-over. This means:
- Work survives across sessions
- Context stays minimal (Morpheus reads paths, not contents)
- Any agent can read any prior agent's output by path

### Progressive Disclosure

Context loads on-demand through 8 layers (see [Progressive Disclosure](progressive-disclosure.md)). CLAUDE.md is always loaded. Rules load by path glob. Agent definitions load at dispatch. Templates load when referenced. This keeps token usage efficient.

## The 8 Connected Systems

| # | System | Purpose | Key File(s) |
|---|--------|---------|-------------|
| 1 | **Orchestration** | Wave/round loop, scope assessment, dispatch | CLAUDE.md, `.claude/rules/hub.md` |
| 2 | **Agents** | Specialized workers with defined I/O contracts | `.claude/agents/*.md` |
| 3 | **State Management** | Per-task living documents, cross-session persistence | `hub/staging/*/STATE.md`, `hub/state/active-tasks.md` |
| 4 | **Validation** | SME assessment, independent verification, external evidence | `.claude/agents/sme-assessor.md`, `.claude/agents/verifier.md` |
| 5 | **Notes** | Daily/weekly/monthly/quarterly/yearly work log | `notes/**`, `hub/templates/*-note.md` |
| 6 | **Index** | Directory source of truth, auto-updated | `INDEX.md`, `.claude/hooks/update-index.sh` |
| 7 | **Hooks** | Automated behaviors on session/prompt/tool events | `.claude/settings.local.json`, `.claude/hooks/` |
| 8 | **Knowledge Base** | Reusable articles with lifecycle management | `knowledge/**`, `.claude/rules/knowledge.md` |
