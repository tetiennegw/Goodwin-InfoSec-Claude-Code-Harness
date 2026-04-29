---
title: "ADR-005: Gradual Migration from Hardcoded Hook Text"
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
  Purpose: ADR documenting why migration from hook text is gradual, not big-bang
  Changelog (max 10):
    2026-04-15T00:00:00Z | 2026-04-13-the-protocol-skill | builder | Created ADR-005
-->

# ADR-005: Gradual Migration from Hardcoded Hook Text

## Status
Accepted

## Context

The scope assessment → planning → execution pipeline currently lives as hardcoded text inside
`prompt-context-loader.sh`. It works. Every task Tyler initiates passes through this hook;
it fires on every prompt submission and provides the orchestration instructions that Morpheus
runs from. Replacing it is not a small change — it is replacing the entire task routing
layer of the system.

The risk of a big-bang replacement is high: if The Protocol's skill file has bugs, is not
loaded correctly, or produces different routing decisions than the hook, all tasks are
affected simultaneously. There is no fallback, no rollback, and Tyler would notice failures
immediately across all work domains.

The Goodwin environment adds additional constraints: AllSigned PowerShell policy means any
new or modified `.ps1` hook must be signed before it will execute. ThreatLocker audit trails
make experimental changes visible. A breaking hook change is not easily undone without
another sign-and-deploy cycle.

## Decision

Build The Protocol skill **alongside** the existing hook text, validate it in parallel, then
deprecate the hook text only after validation passes.

The migration has three phases:

1. **Build phase** (complete): Create all protocol files (profiles, schema, skill command)
   without touching `prompt-context-loader.sh`. The new skill is available but not yet
   authoritative — it can be invoked manually by Tyler or by Morpheus for testing.

2. **Validation phase** (next): Run The Protocol skill against a representative set of
   request types and compare its routing decisions and context-loading behavior against the
   current hook. Document any divergences. This phase requires Tyler's sign-off before
   advancing.

3. **Deprecation phase** (after validation): Update `prompt-context-loader.sh` to delegate
   to the skill command rather than containing the inline routing text. The old text is
   commented out (not deleted) until one full week of production use confirms no regressions.
   Only then is the old text removed.

At no point does a single commit simultaneously remove the old routing and activate the new
routing. One must be validated before the other is retired.

## Alternatives Considered

### Alternative 1: Big-bang replacement

Delete the hardcoded hook text and activate The Protocol skill in a single commit.

- **Pros**: Clean break; no dual-running logic; no "commented-out" maintenance debt
- **Cons**: If the skill has any bug — wrong scope assessment, missing context, bad trigger
  matching — all tasks fail immediately with no fallback; rollback requires another sign
  cycle on Goodwin endpoints; no validation window
- **Why rejected**: The risk-to-benefit ratio is poor. The hook works. The Protocol is
  unproven in production. A system that routes all tasks is not the right place for an
  untested first deployment.

### Alternative 2: Feature flag in the hook

Add a boolean flag in the hook that switches between old logic and new skill invocation.
Set flag to false initially; flip to true after testing.

- **Pros**: Rollback is a flag toggle; both paths coexist in one file
- **Cons**: The hook file grows more complex; the flag must be managed across sessions;
  PowerShell AllSigned means any flag-editing commit still requires a sign cycle;
  the flag itself is state that could get out of sync
- **Why rejected**: The added complexity in the hook file doesn't provide meaningful
  advantage over the build/validate/deprecate sequence, which achieves the same safety
  property without bifurcating the hook's logic.

### Alternative 3: Parallel hook files

Keep `prompt-context-loader.sh` unchanged and create a new `the-protocol-loader.sh` that
Tyler can manually activate. Run both for a period, then swap.

- **Pros**: Zero changes to the working hook during testing
- **Cons**: Two hooks producing instructions simultaneously would conflict; Morpheus would
  receive contradictory routing context; requires careful session isolation to test
- **Why rejected**: Two active routing hooks in the same session is not safely composable.
  The skill-alongside-hook approach (build phase only, skill not yet authoritative) achieves
  the isolation goal without dual-hook conflicts.

## Consequences

### Positive
- Existing hook continues to work throughout the build and validation phases
- Validation phase produces documented evidence before any production change
- Tyler's explicit sign-off is required between phases — no autonomous cutover
- Deprecated text is preserved (commented) during the transition period as a reference

### Negative
- Migration takes longer than big-bang (multiple phases with checkpoints)
- During validation phase, two routing systems exist simultaneously — routing decisions
  must be compared manually or via test harness
- Old hook text persists in the codebase during transition, adding some confusion

### Neutral
- The sign-before-deploy requirement on Goodwin endpoints applies to any hook modification;
  this is unchanged by the migration strategy
- Deprecation of hook text is a separate commit from the skill build — both are tracked in
  the task table (T3.2 and T4.2 respectively)

## References
- `.claude/hooks/prompt-context-loader.sh` — the current hook being migrated from
- `.claude/commands/the-protocol.md` — the skill being migrated to
- Plan "Migration Strategy" section: gradual cutover, validation gate, deprecation step
- `hub/staging/2026-04-13-the-protocol-skill/wave-1/round-1/research-self-maintaining-architecture.md` — ESLint deprecation+codemod pattern, schema migrators
- `hub/staging/2026-04-13-the-protocol-skill/STATE.md` — T3.2 and T4.2 task entries

## Changelog
| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-15T00:00:00Z | 2026-04-13-the-protocol-skill | builder | Created ADR-005 |
