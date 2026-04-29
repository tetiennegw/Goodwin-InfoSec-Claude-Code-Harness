---
title: "Progressive Disclosure"
last-updated: 2026-04-08
related-files: [CLAUDE.md, INDEX.md, .claude/rules/hub.md, .claude/agents/gatherer.md]
---

# Progressive Disclosure

## The Problem

Claude Code has a finite context window. Loading every file at startup would waste tokens on information that is irrelevant to the current task. Progressive disclosure solves this by loading context on-demand, in layers.

## The 8 Layers

Context loads in order of specificity. Earlier layers are always present; later layers load only when needed.

```
Layer 1: CLAUDE.md (always loaded)
  |
  v
Layer 2: INDEX.md (loaded via InstructionsLoaded hook)
  |
  v
Layer 3: Rules (loaded when matching path glob is accessed)
  |
  v
Layer 4: Agent definitions (loaded when agent is dispatched)
  |
  v
Layer 5: STATE.md (loaded when agent reads it for task context)
  |
  v
Layer 6: Templates (loaded when agent needs to produce an artifact)
  |
  v
Layer 7: Patterns (loaded when Morpheus needs scope-specific orchestration rules)
  |
  v
Layer 8: Artifacts (loaded only by the agent that needs them)
```

### Layer 1: CLAUDE.md

Always loaded at session start. Contains Morpheus's identity, core pillars, orchestration loop summary, scope table, agent roster, context engineering rules, and standards. This is the minimum context Morpheus needs to function.

**Token cost**: Low (~800 tokens). Kept deliberately concise.

### Layer 2: INDEX.md

Loaded automatically via the InstructionsLoaded hook. Provides the complete file map so agents can find files without searching.

**Token cost**: Low-medium (~200-500 tokens depending on project size).

### Layer 3: Rules

Path-specific rules in `.claude/rules/`. Loaded automatically when Claude Code accesses a matching path:

| Rule | Glob | When It Loads |
|------|------|---------------|
| `hub.md` | `hub/**` | When working with orchestration files |
| `scripts.md` | `scripts/**` | When working with script files |
| `knowledge.md` | `knowledge/**` | When working with KB articles |
| `index-consultation.md` | `**/*` | Always (global rule) |

**Token cost**: Only the relevant rule loads, not all of them.

### Layer 4: Agent Definitions

Files in `.claude/agents/`. Loaded when Morpheus dispatches that agent type. Each definition includes the agent's critical rules, input/output contracts, and process steps.

**Token cost**: One agent definition per dispatch (~300-500 tokens each).

### Layer 5: STATE.md

The task's living document. Loaded by agents when they read it for macro goal and progress context. Contains everything about the current task.

**Token cost**: Grows over time as progress accumulates. Compacting completed waves helps.

### Layer 6: Templates

Artifact templates in `hub/templates/`. Loaded when an agent needs to produce output in a specific format (research artifact, plan artifact, etc.).

**Token cost**: One template per artifact type (~200-400 tokens each).

### Layer 7: Patterns

Scope patterns in `hub/patterns/`. Loaded by Morpheus when it needs detailed orchestration rules for a specific scope level (wave sequences, round ranges, circuit breakers).

**Token cost**: One pattern file per task (~300-600 tokens each).

### Layer 8: Artifacts

Previous agent outputs (research, plans, assessments). Loaded only by the agent that needs them — for example, the planner reads research artifacts, the builder reads plan artifacts.

**Token cost**: Varies. Morpheus never reads artifact contents — only paths and summaries.

## Why This Matters

| Without Progressive Disclosure | With Progressive Disclosure |
|-------------------------------|----------------------------|
| Load everything at startup | Load on-demand |
| 10,000+ tokens of context before first prompt | ~1,000 tokens at startup |
| Token limit hit on complex tasks | Complex tasks fit in context |
| Irrelevant context confuses agents | Each agent sees only what it needs |

## Design Rules

1. **CLAUDE.md stays concise** — it is always loaded, so every token counts
2. **Morpheus reads paths, not contents** — keeps orchestrator context minimal
3. **Agents read only their inputs** — gatherer does not read plan artifacts
4. **Compact completed waves** — after 3+ waves complete, collapse to one-line summaries in STATE.md
5. **Re-read from disk** — if Morpheus needs past context, re-read STATE.md rather than relying on token memory
