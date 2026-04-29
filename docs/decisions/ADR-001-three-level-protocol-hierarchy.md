---
title: "ADR-001: Three-Level Protocol Hierarchy"
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
  Purpose: ADR documenting why a 3-level hierarchy was chosen over flat or 2-level alternatives
  Changelog (max 10):
    2026-04-15T00:00:00Z | 2026-04-13-the-protocol-skill | builder | Created ADR-001
-->

# ADR-001: Three-Level Protocol Hierarchy

## Status
Accepted

## Context

The Protocol's scope assessment and execution pipeline needed a structural model to organize
domain specialization. The prior system was a single monolithic pipeline in
`prompt-context-loader.sh` — no domains, no scaling, every request ran through the same logic.

As Tyler adds new work domains (security ops, code development, harness maintenance, future
domains), the system needs a way to express domain-specific scope heuristics, scaffolding
rules, and verification gates without making the core logic a sprawling if-else chain. The
structure must also allow sub-protocol specialization — a "write a simple Bash script" and
"build a multi-service detection platform" are both code tasks but require radically different
execution paths.

The hierarchy must be extensible by adding new profiles (files), not by modifying core logic.
New domain onboarding cannot require touching the orchestrator's main routing code.

## Decision

Adopt a three-level hierarchy: **Protocol (root) → Domain → Sub-Protocol**.

- **Protocol (root)**: The orchestration core. Defines universal rules, dispatch templates,
  scope table, and the routing algorithm. Lives in `CLAUDE.md` and `hub.md`. One instance.
- **Domain**: A named profile file (e.g., `code.md`, `harness.md`) under `.claude/protocols/`.
  Captures domain-specific scope heuristics, triggers, sub-protocols, and overrides. One file
  per domain; discovered by folder scan at runtime.
- **Sub-Protocol**: A named section within a domain profile. One per scope cluster
  (Mini/Small, Medium, Large, Ultra). Defines scaffolding depth, research requirements, plan
  sections, build process, and verification gates for that scope within the domain.

Routing is sequential: classify domain → assess scope → select sub-protocol → execute.

## Alternatives Considered

### Alternative 1: Flat list of named workflows

A flat registry mapping (domain, scope) pairs to workflow definitions, with no nesting.

- **Pros**: Simple to understand; no hierarchy to navigate
- **Cons**: Combinatorial explosion — 4 domains × 5 scopes = 20 separate workflow files;
  cross-cutting concerns (e.g., "always require STATE.md") must be duplicated in every entry;
  adding a new domain requires 5 new files
- **Why rejected**: Does not scale; no place to express shared defaults; duplication risk is
  high as the system grows

### Alternative 2: Two-level hierarchy (Protocol → Domain only, no sub-protocols)

Domain profiles define everything, but scope-dependent behavior is handled by inline
conditionals within each profile.

- **Pros**: Fewer abstraction levels; easier to read a single file
- **Cons**: Domain profile files become complex conditional documents; scope-specific rules
  are interleaved and harder to isolate; adding a new scope behavior requires editing every
  domain profile
- **Why rejected**: Scope scaling is a first-class concern, not a detail. Sub-protocols make
  scope boundaries explicit and independently verifiable.

## Consequences

### Positive
- Adding a new domain requires one new profile file — no core logic changes
- Sub-protocol boundaries make scope-appropriate behavior explicit and auditable
- `default.md` catches unclassified requests without special-casing in the router
- Domain files are independently testable and reviewable

### Negative
- Three abstraction levels require more initial learning to understand routing
- Profile files must be kept consistent with the schema (`_schema.md`)
- Runtime must merge `extends: default` sections correctly; merge logic is non-trivial

### Neutral
- Four domain files initially (default, code, harness, security-ops planned)
- Sub-protocol count per domain will grow as scope coverage improves

## References
- `.claude/protocols/_schema.md` — profile file schema and validation rules
- `.claude/protocols/default.md` — root fallback profile (catch-all)
- `.claude/protocols/code.md` — example domain profile with 4 sub-protocols
- `hub/staging/2026-04-13-the-protocol-skill/wave-1/round-1/research-extensibility-patterns.md` — folder-based discovery, composition patterns
- Plan Part 1: Three-level hierarchy and routing workflow

## Changelog
| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-15T00:00:00Z | 2026-04-13-the-protocol-skill | builder | Created ADR-001 |
