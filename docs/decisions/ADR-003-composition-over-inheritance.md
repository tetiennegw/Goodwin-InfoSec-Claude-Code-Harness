---
title: "ADR-003: Composition Over Inheritance for Protocol Profiles"
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
  Purpose: ADR documenting why single-level composition (extends: default) was chosen
  Changelog (max 10):
    2026-04-15T00:00:00Z | 2026-04-13-the-protocol-skill | builder | Created ADR-003
-->

# ADR-003: Composition Over Inheritance for Protocol Profiles

## Status
Accepted

## Context

Domain protocol profiles share substantial common behavior: all profiles need Scope Heuristics
as a fallback, all need auto-escalation rules, all need sub-protocol scaffolding templates, and
all need always-activate-skills baselines. Without a sharing mechanism, each domain profile
must duplicate these shared sections — creating maintenance burden and divergence risk.

The profiles are markdown files read by an LLM, not compiled classes. Any "inheritance" or
"composition" mechanism must be implementable by a skill that reads two files and merges
their sections — not by a runtime type system. The solution must be simple enough to express
in a 300-line markdown skill file without a parser or object model.

The system must also avoid deep chains: if `code.md` extends `backend.md` which extends
`default.md`, the skill must read three files and resolve conflicts across three layers —
complex, fragile, and hard to reason about.

## Decision

Adopt **single-level composition** via the `extends: default` frontmatter field.

Every domain profile declares `extends: default` in its YAML frontmatter. The skill, when
loading a domain profile, reads both the domain file and `default.md`, then merges them
section-by-section: domain profile sections take precedence; sections absent from the domain
profile fall through to `default.md`. The merge rule is simple: "domain overrides, default
fills gaps."

`default.md` is the complete, self-sufficient baseline. It must work end-to-end on its own.
Domain profiles override only the sections where their behavior differs (typically: Scope
Heuristics, Sub-Protocols, and Verification Gates). They inherit everything else without
re-stating it.

`extends` depth is capped at 1: a domain profile may extend `default` only. Domain profiles
cannot extend other domain profiles. This prevents inheritance chains.

## Alternatives Considered

### Alternative 1: Copy-paste (no sharing mechanism)

Each domain profile is a complete standalone file with all sections duplicated.

- **Pros**: No merge logic needed; each file is fully self-contained and readable in isolation
- **Cons**: Auto-escalation rules, passthrough indicators, and scaffolding templates must be
  duplicated across every profile; one update requires N file edits; divergence accumulates
  silently
- **Why rejected**: With 4+ profiles, maintenance burden becomes unsustainable. A bug fix in
  auto-escalation logic would require editing every profile file.

### Alternative 2: Deep inheritance chains

Allow profiles to extend other domain profiles (e.g., `code-backend.md extends code.md`
which extends `default.md`).

- **Pros**: Enables fine-grained specialization within a domain
- **Cons**: Merge resolution across 3+ levels requires a proper MRO (Method Resolution Order);
  LLM-readable merge logic becomes ambiguous at depth 3+; circular extends are possible;
  debugging which file a behavior came from becomes painful
- **Why rejected**: The skill is a markdown file read by an LLM. Implementing MRO in a skill
  is more complex than the benefit justifies. Single-level composition is sufficient.

### Alternative 3: Mixin files (multiple extends targets)

Allow `extends: [default, security-base]` to pull from multiple files.

- **Pros**: Finer-grained reuse without deep chains
- **Cons**: Conflict resolution between two non-default parents requires explicit rules;
  ordering matters; schema complexity increases
- **Why rejected**: Premature complexity. Single extends: default covers all current needs.
  Revisit if a domain genuinely needs cross-domain mixing.

## Consequences

### Positive
- Shared behavior lives in exactly one place (`default.md`); updates propagate to all profiles
- Domain profiles are concise — they only state what makes them different
- Merge logic is a simple two-file section overlay; implementable in ~20 lines of skill logic
- Single-level cap eliminates circular dependency risk

### Negative
- `default.md` must remain complete and correct; it is a single point of failure for all profiles
- Profiles cannot specialize another domain profile without duplication (depth-1 constraint)
- Merge conflict resolution (when both files define the same section) must be clearly documented

### Neutral
- `extends: default` is the only allowed value today; schema validation rejects other values
- If a future domain genuinely requires cross-domain composition, the schema supports adding
  a `mixins` field without breaking existing `extends` semantics

## References
- `.claude/protocols/default.md` — the complete fallback baseline all profiles extend
- `.claude/protocols/code.md` — example of a domain profile with `extends: default`
- `.claude/protocols/_schema.md` — schema definition for the `extends` field and merge rules
- `hub/staging/2026-04-13-the-protocol-skill/wave-1/round-1/research-extensibility-patterns.md` — composition not inheritance, 5-field MVP profile
- Plan Part 2: Profile file schema and composition semantics

## Changelog
| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-15T00:00:00Z | 2026-04-13-the-protocol-skill | builder | Created ADR-003 |
