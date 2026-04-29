---
name: Harness Protocol
schema-version: 1
extends: default
description: Claude Code orchestration harness optimization and extension -- hooks, skills, rules, agents, templates, protocols, STATE.md system, daily notes system, and the orchestration loop itself
triggers:
  - optimize.*hook
  - improve.*skill
  - refactor.*agent
  - fix.*hook
  - update.*template
  - redesign.*harness
  - overhaul.*orchestration
  - tweak.*rule
  - extend.*protocol
  - add.*skill
  - create.*hook
  - update.*rule
  - debug.*hook
  - migrate.*harness
  - add.*sub-protocol
  - orchestration.*improvement
  - hook.*not firing
  - skill.*not activating
  - rule.*not loading
anti-triggers:
  - write a script
  - build an app
  - implement a function
  - create a database
  - deploy a service
  - write tests for
always-activate-skills:
  - task-list-management
  - daily-note-management
min-core-version: 1
created: 2026-04-15
last-updated: 2026-04-15
---

<!--
  HARNESS PROTOCOL PROFILE
  ========================
  Domain: The Claude Code orchestration harness itself -- all files under .claude/,
  hub/templates/, hub/state/, hub/staging/, and CLAUDE.md.

  Verification philosophy: Harness work is integration-first. Unit logic is minimal;
  the primary signal is: do hooks fire? do skills activate? do rules auto-load? does
  STATE.md round-trip correctly? Verification gates favor observable system behavior
  over code coverage metrics.

  Anti-trigger rationale: simple string containment (bash ERE lookahead not supported).
  If a request matches an anti-trigger and does NOT also match a trigger, skip this profile.
-->

## Scope Heuristics

Domain-specific scope indicators for harness work. These replace the generic Default Protocol
heuristics for any request that activates the Harness Protocol.

| Indicator | Scope |
|-----------|-------|
| Single file change in .claude/ (one hook parameter, one rule entry, one skill trigger) | Mini |
| Fix a broken hook, tweak a skill trigger, add one rule entry, update one template section | Small |
| Optimize a single harness component end-to-end (a hook, skill, agent, or template) | Medium |
| Restructure multiple components, add new protocol profile, update dependent rules/hooks | Large |
| Ground-up rethinking of the harness architecture, phased migration, multi-session | Ultra |

### Auto-Escalation Rules (Harness-specific)

Escalate beyond initial assessment when the request involves:

- **Cross-cutting changes**: a change touching both hooks AND rules AND CLAUDE.md -- escalate to Medium+
- **Migration work**: any change requiring old behavior deprecated and new behavior phased in -- escalate to Large+
- **Schema changes**: changes to _schema.md, hub/templates/state.md, or STATE.md frontmatter spec -- escalate to Medium+ (backward compatibility required)
- **Hook ordering changes**: changes to the PostToolUse/PreToolUse/SessionStart hook chain -- escalate to Large (cascading failure risk)
- **New domain protocol**: adding a new .claude/protocols/{domain}.md -- Small for MVP profile, Medium for full profile


---

## Sub-Protocols

> **Task-list discipline applies to every sub-protocol.** Every wave/phase transition runs TaskCreate / TaskUpdate per `.claude/rules/task-handling.md` (naming, 3-level urgency, non-cancellation invariant). `/the-protocol` Step 0.5 creates the M0/M1/M2 meta-tasks before sub-protocol execution begins.

### Quick Fix (Mini/Small)
- **Scaffolding**: STATE.md (minimal: frontmatter + macro goal + next action), single output file in .claude/
- **Research**: None -- harness internals are already in context via hook-loaded rules
- **Plan**: Flat checklist (3-7 steps), acceptance criteria inline in STATE.md
- **Build**: 1 builder agent, single round; no TDD -- manual integration verification
- **Verification**: Manual integration check -- confirm hook fires, skill activates, or rule loads for its glob; grep for FIRED/SKIPPED in .claude/logs/ if available
- **Artifact chain**: intent -> build -> manual integration check -> done

### Component Optimization (Medium)
- **Scaffolding**: STATE.md + staging dir with wave subdirs; update INDEX.md after build
- **Research**: 1 gatherer wave (5-10 sources or existing harness doc review); read adjacent component files to understand dependencies
- **Plan**: Full 16-section plan (scope-gated for Medium); include backward-compatibility notes in Section 15 (Risks)
- **Build**: 1-2 builder agents; update CLAUDE.md if component behavior changes externally; write harness integration assertions before implementing
- **Verification**: 3-tier gates -- structure check -> integration check (hook fires, skill activates, rule globs match) -> cross-component spot check (dependent hooks/skills still work)
- **Artifact chain**: research -> requirements -> design -> integration assertions -> build -> 3-tier verify -> CLAUDE.md/INDEX.md update

### Architecture Overhaul (Large)
- **Scaffolding**: STATE.md + staging dir + component plans within hub plan + ADRs (major decisions only); backward-compatibility matrix table in STATE.md
- **Research**: 1 gatherer wave, 2-4 rounds, 15-25 sources; must include: existing harness component inventory, current hook chain map, known failure modes
- **Plan**: Hub plan (full 16-section), component-level detail within hub, 10-30 tasks; foundation-first ordering (hooks before skills that depend on them)
- **Build**: Sequential builders, foundation-first gate, max 6 agents/wave, single-session; deprecated components kept functional until migration complete
- **Verification**: 3-tier gates + 1 verifier pass (end of build) + backward-compatibility regression (old callers still work after each phase)
- **Artifact chain**: research -> component inventory -> requirements+design (hub plan) -> ADRs -> migration plan -> sequential build -> backward-compat regression -> integration verification -> docs
- **Foundation gate**: Hook infrastructure changes must COMPLETE before dependent skills or rules are rebuilt
- **Session span**: Single session

### System Redesign (Ultra)
- **Scaffolding**: STATE.md + staging dir + per-subsystem specs (hooks, skills, rules, protocols, templates) + ADRs (all decisions) + HANDOFF.md + feature-flag plan for parallel old/new operation
- **Research**: 2 gatherer waves (broad survey of orchestration patterns then focused deep-dive on migration strategy), 2-5 rounds each, 25-40+ sources total
- **Plan**: Hub plan + per-subsystem specs in staging/{task-id}/subsystems/; 30-80+ tasks; Subsystem Interface Matrix showing cross-subsystem dependencies; Phasing Strategy with explicit feature-flag milestones
- **Build**: Phased parallel builders, per-phase verification gates, max 8 agents/wave, cross-session; old system remains functional at all times (parallel operation via feature flags in prompt-context-loader.sh or CLAUDE.md)
- **Verification**: 3-tier gates + per-phase verifier + regression gates (all prior phases re-tested after each new phase) + cross-subsystem integration + end-to-end harness smoke test (new session from scratch exercises all hooks/skills/rules)
- **Artifact chain**: research (broad) -> research (focused) -> PRD -> ADRs -> subsystem specs -> feature-flag scaffold -> phased parallel builds -> per-phase verification -> integration -> deprecation of old system -> docs
- **Foundation gate**: Each subsystem phase must PASS its phase gate before the next subsystem begins
- **Session span**: Multi-session -- HANDOFF.md written at each session boundary; session resume checklist in HANDOFF.md includes: verify hooks still fire, verify active-tasks.md regenerates, verify daily note logging works
- **Tyler checkpoints**: After every major phase -- Tyler may descope, defer subsystems, or adjust migration timeline


---

## Wave Sequences

| Sub-Protocol | Wave Sequence |
|---|---|
| Quick Fix | [builder(1 round)] -> [documenter] |
| Component Optimization | [gatherer] -> [planner] -> [builder(2-3 rounds)] -> [verifier] -> [documenter] |
| Architecture Overhaul (Large) | [gatherer(1 wave)] -> [planner(hub plan)] -> [builder(primary, 2-4 rounds)] -> [builder+verifier(remaining + backward-compat)] -> [documenter] |
| System Redesign (Ultra) | [gatherer(broad)] -> [gatherer(focused)] -> [planner(hub+subsystems)] -> [builder(Phase 1: hooks)] -> GATE -> [builder+verifier(Phase 2: skills+rules)] -> GATE -> [builder+verifier(Phase N: protocols+templates)] -> GATE -> [hardening(deprecation+smoke)] -> [documenter] |


---

## Acceptance Criteria Template

EODIC criteria templates for harness work. The key difference from Code Protocol: verification
focuses on observable system integration behavior (hooks fire, skills activate, rules load)
rather than unit test coverage.

### Quick Fix
- [ ] Modified file exists and is non-empty: `test -f {output-path} && wc -l {output-path}`
- [ ] No syntax errors in modified file: `bash -n {hook-path}` exits 0 (bash hooks); YAML frontmatter parses cleanly for skill/rule/protocol files
- [ ] Integration signal confirmed: manually trigger the change and observe expected behavior (hook fires, skill activates, or rule loads for its glob)

### Component Optimization
- [ ] Component file exists at correct path: `test -f {component-path}`
- [ ] All required sections present: `grep -c "^## " {component-path}` meets expected count for component type
- [ ] Hook fires or skill activates correctly: `grep "FIRED" .claude/logs/` returns match after test trigger, or manual integration verification documented
- [ ] Dependent components unbroken: skills/rules/hooks that depend on this component still behave correctly after the change
- [ ] External references updated: `grep "{component-name}" CLAUDE.md` returns expected reference if component behavior changed externally

### Architecture Overhaul
- [ ] All component files in .claude/ exist at specified paths: `ls .claude/hooks/ .claude/commands/ .claude/rules/ .claude/agents/` shows all expected files
- [ ] No regression in existing hooks: PostToolUse, PreToolUse, and SessionStart hooks all fire without error after a test trigger
- [ ] active-tasks.md regenerates correctly: `bash scripts/utils/generate-active-tasks.sh` exits 0 and output reflects current STATE.md frontmatter
- [ ] Daily note logging works end-to-end: new timeline entry appears in today's note after a work item completes (verified by reading note)
- [ ] ADRs exist for major design decisions: `ls docs/decisions/ADR-*.md | wc -l` returns >= 1
- [ ] Backward-compatibility verified: existing callers in CLAUDE.md and hook invocations still function without modification

### System Redesign
- [ ] Per-subsystem acceptance criteria defined in subsystem specs: `grep -l "Acceptance Criteria" hub/staging/{task-id}/subsystems/*.md | wc -l` equals subsystem count
- [ ] Each phase gate passed before next phase began: evidenced in STATE.md Progress Summary with explicit GATE PASS markers and timestamps
- [ ] Full harness smoke test passes: new session from scratch -- SessionStart fires, daily note scan completes, active-tasks.md loads, and first prompt activates the correct protocol profile
- [ ] Old system deprecated only after new system verified: feature flags removed only after all integration gates pass
- [ ] HANDOFF.md current at every session boundary: `test -f hub/staging/{task-id}/HANDOFF.md && grep "Session Resume Checklist" hub/staging/{task-id}/HANDOFF.md` exits 0
- [ ] Regression gate: all prior subsystem tests still pass after each new subsystem phase (re-run full integration suite)
- [ ] Cross-subsystem round-trip verified: user prompt -> protocol activation -> STATE.md initialization -> agent dispatch -> artifact write -> STATE.md update -> active-tasks.md regeneration -> daily note logging all work in sequence


---

## SME Personas

Harness-specific expert identities. The orchestration systems framing is essential -- these
reviewers must understand the hook/skill/rule architecture, not just code quality in isolation.

- **Primary (orchestration review)**: Orchestration Systems Architect -- 8+ years building autonomous agent orchestration platforms; validates hook execution chains, skill activation logic, rule glob patterns, protocol routing correctness, STATE.md round-trip integrity, and progressive disclosure mechanics
- **Secondary (integration verification)**: DevOps/Platform Engineer specializing in hook-driven automation and CLI toolchain design -- validates that hooks fire on correct events, skills activate on correct triggers, rules auto-load for correct glob patterns, and that the PostToolUse/PreToolUse/SessionStart chain remains stable after changes
- **Tertiary (Large required, Ultra required)**: Context Engineering Specialist -- expertise in LLM context window management, progressive disclosure token budgets, and STATE.md compaction strategies; validates that harness changes do not bloat context, that progressive disclosure tiers are respected, and that agent handoff quality is maintained across session boundaries

---

## Verification Gates

Harness-specific 3-tier gates. Unlike Code Protocol which focuses on test coverage,
Harness Protocol focuses on integration correctness: observable system behavior.
Gates are cumulative and blocking -- a later tier cannot pass if an earlier tier failed.

### Tier 1 (Structure / Lint) — blocking
- All modified files in .claude/ are non-empty and have valid structure for their type: hooks have shebang + set -euo pipefail; skills/rules/protocols have YAML frontmatter; agents have their identity header
- Hook files pass shell syntax check: `bash -n {hook-path}` exits 0 for bash hooks; `Invoke-ScriptAnalyzer` clean for PowerShell hooks (or documented exceptions with rationale)
- YAML frontmatter in all modified skill, rule, protocol, and agent files parses without errors: grep returns exactly 2 `---` delimiter lines
- Required frontmatter fields present: protocols need name/schema-version/description/triggers; STATE.md files need task-id/scope/status/created/last-updated

### Tier 2 (Integration Check) — blocking, cumulative
- Hook fires on its trigger event: PostToolUse fires after Write/Edit; PreToolUse fires before specified tools; SessionStart fires at session open; UserPromptSubmit fires prompt-context-loader
- Skill activates when its trigger pattern matches a representative prompt: test with a prompt containing the trigger phrase and confirm activation
- Rule auto-loads for its declared glob pattern: files matching the glob have the rule active (verified by hook log or manual behavior check)
- STATE.md PostToolUse hook fires after any Write/Edit to a STATE.md file: active-tasks.md regenerates correctly with updated frontmatter values
- All pre-existing hooks that were working before this change still fire correctly after (no regression)

### Tier 3 (End-to-End / System) — blocking, cumulative
- Full harness round-trip works: user prompt -> protocol activation -> domain classification -> scope assessment -> sub-protocol selection -> STATE.md initialization -> agent dispatch -> artifact write -> STATE.md update -> active-tasks.md regeneration -> daily note logging
- Daily note timeline entry produces correctly formatted output per .claude/rules/daily-note.md: 12-hour AM/PM timestamps, vertical bullet lists, proper separator at column 0, mandatory blank lines between fields
- All harness files referenced in CLAUDE.md and INDEX.md exist on disk: no dead references
- Context budget not exceeded: profile activates within its declared progressive disclosure tier token budget (Mini/Small ~500 tokens, Medium ~2K, Large ~3K, Ultra ~4K)
- Cross-session resume works: a simulated session restart with HANDOFF.md (if applicable) surfaces correct deferred approvals and task state

---

## Agent Return Protocol Extensions

| Field | Required For | Description |
|-------|-------------|-------------|
| HOOK_VERIFICATION | All | "hooks tested: [list]; result: FIRED / NOT FIRED / SKIPPED (reason)" |
| SKILL_ACTIVATION | Small+ | "skill trigger tested with prompt: [phrase]; result: ACTIVATED / NOT ACTIVATED" |
| BACKWARD_COMPAT | Medium+ | "components tested for regression: [list]; result: PASS / FAIL (details)" |
| INTEGRATION_LOG | Medium+ | path to .claude/logs/ entry or inline evidence of hook/skill execution |
| MIGRATION_STATUS | Large+ | "old behavior: DEPRECATED / STILL ACTIVE; feature flags: [list with status]" |
| SUBSYSTEM_STATUS | Ultra only | per-subsystem pass/fail matrix (hooks / skills / rules / protocols / templates) |

---

## Changelog

| Timestamp | Agent | Change |
|-----------|-------|--------|
| 2026-04-15T00:00 | builder | Created harness.md -- domain protocol profile for Claude Code orchestration harness with 4 sub-protocols: Quick Fix, Component Optimization, Architecture Overhaul, System Redesign |
