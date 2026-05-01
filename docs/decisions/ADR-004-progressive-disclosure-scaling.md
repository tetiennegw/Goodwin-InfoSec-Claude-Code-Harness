---
title: "ADR-004: Progressive Disclosure Scaling Model"
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
  Purpose: ADR documenting the 3-tier progressive disclosure model for context loading
  Changelog (max 10):
    2026-04-15T00:00:00Z | 2026-04-13-the-protocol-skill | builder | Created ADR-004
-->

# ADR-004: Progressive Disclosure Scaling Model

## Status
Accepted

## Context

Claude Code's context window is finite. Every token spent loading protocol definitions,
research artifacts, and historical state is a token not available for reasoning, code generation,
or output. For a trivial passthrough request ("what is X?"), loading the full orchestration
framework, all research paths, and prior ADRs would consume 3,000-4,000 tokens unnecessarily.

The prior `prompt-context-loader.sh` loaded a fixed set of context regardless of request
scope. This worked when the system was small, but as The Protocol adds domain profiles,
sub-protocols, research artifacts, and historical STATE.md files, loading everything for every
request becomes unsustainable.

The system needs a principled rule for what context to load at what scope. The rule must be
simple enough to implement in a skill file, deterministic (same scope always loads the same
tiers), and designed so agents can fetch additional context on demand via file paths rather
than having it pre-loaded.

## Decision

Adopt a **three-tier progressive disclosure model** keyed to task scope.

- **Tier 1 (~500 tokens)**: Always loaded. Skill metadata, matched profile frontmatter, and
  active-tasks.md. Sufficient for passthrough and Mini scope. Agents can answer, route, or
  delegate with this context alone.

- **Tier 2 (~2,000 tokens total)**: Loaded for Small and Medium scope. Adds the full matched
  domain profile (scope heuristics, sub-protocol definitions, verification gates) and relevant
  rule files. Agents can execute a multi-step build with this context.

- **Tier 3a (~3,000 tokens, Large scope)**: Adds research artifact paths (not content),
  codebase scan results, and relevant prior task STATE.md paths. Agents receive paths, not
  file contents — they read files on demand. Covers complex multi-wave work.

- **Tier 3b (~4,000 tokens, Ultra scope)**: Adds everything in 3a plus cross-project STATE.md
  paths, prior ADRs, HANDOFF.md from the previous session, and subsystem spec paths.

The key principle: **paths, not content**. At Tier 3+, agents receive file paths to research
and prior context — they use Read/Glob on demand rather than having content pre-loaded. This
keeps the orchestrator context lean while giving agents the tools to fetch what they need.

## Alternatives Considered

### Alternative 1: Load everything always

Load all protocol files, all research artifacts, all prior STATE.md content at session start.

- **Pros**: Agents always have full context; no on-demand fetching required; simpler logic
- **Cons**: Context window consumed by irrelevant history on every request; trivial requests
  pay the cost of Ultra-scope preparation; as the knowledge base grows, this becomes
  impossible within a single context window
- **Why rejected**: Context window is a hard constraint. A growing system cannot load
  everything. Research from context-engineering: observation masking alone achieves 52%
  compression; selective loading is the correct approach.

### Alternative 2: Load nothing; agents request context as needed

Start each request with minimal context. Agents call Read/Glob for everything they need.

- **Pros**: Zero upfront token cost; only genuinely needed files are loaded
- **Cons**: Routing and scope assessment require at minimum the profile triggers and scope
  heuristics — without Tier 1, the orchestrator cannot even classify the request; cold-start
  problem for every request
- **Why rejected**: Some baseline context is necessary for classification. Pure on-demand
  loading breaks the routing step that determines which domain and scope apply.

### Alternative 3: Two tiers (minimal / full)

Binary switch: either load minimal context (passthrough/Mini) or full context (everything else).

- **Pros**: Simpler decision logic; fewer thresholds to calibrate
- **Cons**: "Full" context is too expensive for Small/Medium requests; wastes context on
  research paths that are only needed at Large+; medium tasks pay Ultra cost
- **Why rejected**: The gap between Small (a 3-step config change) and Ultra (a multi-week
  platform build) is too large to cover with a binary switch. The 3a/3b distinction matters.

## Consequences

### Positive
- Passthrough requests consume ~500 tokens of protocol overhead, not 4,000
- Context window budget scales with task complexity; simple tasks stay lean
- Agents at Tier 3+ can fetch research content on demand; orchestrator stays under budget
- Tier thresholds are tunable as the system grows without changing the routing logic

### Negative
- Tier 3 agents must make additional Read calls for research content (latency cost)
- Tier boundaries require calibration; wrong classification leads to under-loaded context
- Paths-not-content discipline requires agents to explicitly request file reads, which is
  an extra step vs. having content pre-loaded

### Neutral
- Token budgets (500/2000/3000/4000) are approximate targets, not hard limits
- The three-tier model maps naturally to the Mini/Small-Medium/Large/Ultra scope clusters

## References
- `hub/staging/2026-04-13-the-protocol-skill/wave-1/round-1/research-context-engineering.md` — three-tier progressive disclosure, 52% compression via observation masking
- Plan Part 1: Sub-Protocol Scaling Matrix (context loaded column)
- `CLAUDE.md` — scope table with wave/round counts per scope
- `.claude/protocols/_schema.md` — context-tier field definitions per sub-protocol

## Changelog
| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-15T00:00:00Z | 2026-04-13-the-protocol-skill | builder | Created ADR-004 |
