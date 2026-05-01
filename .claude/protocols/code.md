---
name: Code Protocol
schema-version: 1
extends: default
description: Software development -- scripts, extensions, libraries, platforms
triggers:
  - write a script
  - build.*extension
  - implement.*function
  - refactor
  - detection.*platform
anti-triggers:
  - research
  - just explain
  - what is
always-activate-skills:
  - task-list-management
min-core-version: 1
created: 2026-04-15
last-updated: 2026-04-15
---

<!--
  CODE PROTOCOL PROFILE
  =====================
  Task: 2026-04-13-the-protocol-skill
  Agent: builder
  Created: 2026-04-15T00:00:00Z
  Last-Updated: 2026-04-15T00:07:00Z
  Plan: .claude/plans/fluffy-shimmying-waterfall.md
  Purpose: Domain protocol profile for software development work
  Changelog (max 10):
    2026-04-15T00:07:00Z | 2026-04-13-the-protocol-skill | builder | Completed all missing sections per plan Part 3 spec
    2026-04-15T00:00:00Z | 2026-04-13-the-protocol-skill | builder | Created initial code.md with 4 sub-protocols

  Domain: Software development
  Extends: default (inherits base Scope Heuristics fallback and always-activate-skills baseline)
  Sub-protocols: 4 (Simple Script, Library/Tool, Multi-Component System, Platform Architecture)
  Scope coverage: Mini/Small -> Medium -> Large -> Ultra

  Anti-trigger rule: entries above are simple strings (NOT regex). Runtime matching logic:
  if the request matches ANY anti-trigger string AND does NOT also match a trigger pattern,
  this profile is skipped. See _schema.md section 5.1 for rationale.
-->

## Scope Heuristics

Domain-specific indicators for software development requests. These override the default
Scope Heuristics table for any request matched by this profile.

| Indicator | Scope |
|-----------|-------|
| One-off automation, < 200 lines, single language, no external deps | Mini |
| Single script or utility, well-defined input/output, one language | Small |
| Multi-file, one component, TDD needed, external dependencies | Medium |
| Multi-component system, cross-language, integration tests required | Large |
| Multi-service platform, external integrations, phased rollout, cross-session | Ultra |

### Code-Specific Auto-Escalation Rules

Escalate above initial scope assessment when:

- **Test coverage required** -> escalate to Medium minimum (TDD gates required)
- **Cross-language or cross-runtime integration** -> escalate to Large minimum
- **External service contracts** (API clients, webhook handlers, auth flows) -> escalate to Large minimum
- **Deployment or CI/CD pipeline changes** -> escalate to Large minimum
- **Multi-service or microservice work** -> escalate to Ultra minimum
- Tyler uses "production-ready", "hardened", or "enterprise" -> escalate one scope level

---

## Sub-Protocols

> **Task-list discipline applies to every sub-protocol.** Every wave/phase transition runs TaskCreate / TaskUpdate per `.claude/rules/task-handling.md` (naming, 3-level urgency, non-cancellation invariant). `/the-protocol` Step 0.5 creates the M0/M1/M2 meta-tasks before sub-protocol execution begins.

### Simple Script (Mini/Small)

Single-purpose automation or utility. One builder, no formal plan, inline tests.

- **Scaffolding**: STATE.md + single output file
- **Research**: None or 1 quick search (no gatherer wave; inline context sufficient)
- **Plan**: Flat checklist (5-10 steps), acceptance criteria inline in STATE.md
- **Build**: 1 builder agent, tests alongside code (not TDD-gated -- tests written with implementation)
- **Verification**: Manual run + assert output; no 3-tier gates; builder self-verifies
- **Artifact chain**: intent -> build -> assert -> done

### Library/Tool (Medium)

Reusable component or developer tool. TDD-first, 3-tier gates, formal plan.

- **Scaffolding**: STATE.md + staging dir with wave subdirs
- **Research**: 1 gatherer wave (5-10 sources); focus on API design, dependency selection, test strategy
- **Plan**: Full 16-section plan (scope-gated for Medium); sections 4 and 12 may be skipped
- **Build**: TDD -- tests first -> implement -> verify per phase; 2-3 builder rounds per wave
- **Verification**: 3-tier gates (lint -> unit -> E2E) per phase; test_map.txt maintained
- **Artifact chain**: research -> requirements -> design -> TDD tests -> build -> 3-tier verify

### Multi-Component System (Large)

Coordinated set of components with cross-component integration. Sequential build, foundation-first gate, single-session.

- **Scaffolding**: STATE.md + staging dir + component plans within hub plan + ADRs (major decisions only, not all decisions)
- **Research**: 1 gatherer wave, 2-4 rounds, 15-25 sources; breadth over depth (focused topics per round)
- **Plan**: Hub plan (full 16-section), component-level detail within hub, 10-30 tasks; Subsystem Interface Matrix required
- **Build**: Sequential builders, foundation-first gate (Phase 1 COMPLETE before Phase 2), max 6 agents/wave, single-session
- **Verification**: 3-tier gates + 1 verifier pass (end of build) + security review; cumulative across all components
- **Artifact chain**: research -> requirements+design (hub plan) -> ADRs -> TDD tests -> sequential build -> verification -> docs
- **Foundation gate**: Phase 1 (foundation component) must COMPLETE and PASS all Tier 1-2 gates before Phase 2 begins
- **Session span**: Single session -- no HANDOFF.md or session boundary management required

### Platform Architecture (Ultra)

Full platform with multiple subsystems, external integrations, phased rollout. Parallel builders, per-phase gates, multi-session.

- **Scaffolding**: STATE.md + staging dir + per-subsystem specs in staging/{task-id}/subsystems/ + ADRs (all decisions) + dependency graph + HANDOFF.md
- **Research**: 2 gatherer waves (broad survey then focused deep-dive), 2-5 rounds each, 25-40+ sources total
- **Plan**: Hub plan + per-subsystem specs in staging/{task-id}/subsystems/, 30-80+ tasks, Subsystem Interface Matrix, Phasing Strategy section
- **Build**: Phased parallel builders, per-phase verification gates, max 8 agents/wave, cross-session
- **Verification**: 3-tier gates + per-phase verifier pass + regression gates (re-run all prior phase tests) + cross-subsystem integration tests + security review + hardening phase
- **Artifact chain**: research (broad) -> research (focused) -> PRD -> ADRs -> subsystem specs -> phased parallel builds -> per-phase verification -> integration -> hardening -> docs
- **Foundation gate**: Each phase must PASS its phase gate (Tier 1 + Tier 2 minimum) before the next phase begins; Tier 3 gates at subsystem integration points
- **Session span**: Multi-session -- HANDOFF.md written at each session boundary, session resume checkpoint on start; Tyler reviews and approves plan for next session
- **Tyler checkpoints**: After every major phase -- Tyler may descope, reprioritize, or restructure remaining phases before work continues

---

## Wave Sequences

| Sub-Protocol | Wave Sequence |
|---|---|
| Simple Script | [builder] -> [documenter] |
| Library/Tool | [gatherer] -> [planner] -> [builder (2-3 rounds)] -> [verifier] -> [documenter] |
| Multi-Component System | [gatherer (1 wave, up to 4 rounds)] -> [planner (hub plan)] -> [builder (primary, 2-4 rounds)] -> [builder+verifier (remaining components + verify)] -> [documenter] |
| Platform Architecture | [gatherer (broad)] -> [gatherer (focused)] -> [planner (hub + subsystem specs)] -> [builder (Phase 1)] -> GATE -> [builder+verifier (Phase 2)] -> GATE -> [builder+verifier (Phase N)] -> GATE -> [hardening] -> [documenter] |

---

## Acceptance Criteria Template

Per-sub-protocol EODIC criteria. Substitute placeholders ({script}, {src}, {linter}, {test-runner}, {coverage-tool})
with project-specific values at task inception.

### Simple Script

- [ ] Script runs without errors
- [ ] Output matches expected format
- [ ] No hardcoded secrets

### Library/Tool

- [ ] All source files parse (linter passes)
- [ ] All tests pass
- [ ] Test coverage >= 70%
- [ ] Imports resolve, no missing deps
- [ ] No hardcoded secrets

### Multi-Component System

- [ ] All Phase 1 (foundation) acceptance criteria met before Phase 2 starts
- [ ] All component tests pass
- [ ] Cross-component integration spot checks pass
- [ ] Security review: no injection, no secrets, least privilege
- [ ] Architecture ADRs exist for major design decisions
- [ ] No hardcoded secrets

### Platform Architecture

- [ ] Per-subsystem acceptance criteria defined in subsystem specs
- [ ] Each phase gate passes before next phase begins
- [ ] Cross-subsystem integration tests pass at boundaries
- [ ] Regression tests: all prior phase tests still pass after each new phase
- [ ] Security review: no injection, no secrets, least privilege
- [ ] Architecture ADRs exist for ALL design decisions
- [ ] Artifact traceability: every requirement links to a test case
- [ ] Session handoff: HANDOFF.md current at every session boundary

---

## SME Personas

These personas are parameterized into the SME Assessor dispatch when this profile is active.
Replace {language/framework} with the specific technology stack at task inception.

- **Primary (code review)**: Senior Software Engineer -- 10+ years in {language/framework}; validates architecture, code quality, test coverage, adherence to language idioms
- **Secondary (security)**: Application Security Engineer -- static analysis, injection defense, secret scanning, dependency audit, least-privilege review
- **Tertiary (system architecture)**: System Architect -- cross-service integration, data flow, scalability, deployment strategy; required for Ultra, optional for Large

---

## Verification Gates

Three-tier gates apply to Medium and above. Simple Script uses manual run-and-check only.

### Tier 1 (Build/Lint) -- blocking

- All source files parse without syntax errors
- Linter/formatter passes (shellcheck for .sh, pylint/ruff for .py, PSScriptAnalyzer for .ps1)
- All imports resolve; no missing dependencies
- test_map.txt present and matches actual test count (Medium+)

### Tier 2 (Unit/Content) -- blocking, cumulative

- All unit tests pass (current phase AND all prior phases)
- Test coverage meets threshold (>= 70% default; set per-project in STATE.md)
- No regressions: prior phase test suites re-run and pass (Large+)

### Tier 3 (E2E/Integration) -- blocking, cumulative

- Integration tests pass (real or mocked external dependencies)
- Security scan passes: no secrets, no injection vectors, dependency audit clean
- Benchmarks meet requirements if specified
- Cross-subsystem contracts validated (Ultra only)

---

## Agent Return Protocol Extensions

These fields extend the standard Agent Return Protocol (hub.md) for code-domain work.
All fields below are in addition to base fields (AGENT COMPLETE, OUTPUT FILE, SUMMARY, KEY FINDING, INTENT ALIGNMENT, STATUS, GAPS).

| Field | Required For | Description |
|-------|-------------|-------------|
| TEST_RESULTS | All | X passed, Y failed, Z skipped -- zero tolerance for failures at gate |
| COVERAGE | Medium+ | current% vs required% threshold |
| SECURITY_SCAN | Medium+ | clean OR issues listed OR deferred with reason |
| BUILD_LOG_PATH | All | Absolute path to build artifact for auditing |
| SUBSYSTEM_STATUS | Ultra only | Per-subsystem pass/fail matrix referencing phase gate log |

---

## Changelog

| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-15T00:07:00Z | 2026-04-13-the-protocol-skill | builder | Completed all missing sections: Wave Sequences, Acceptance Criteria Template, SME Personas, Verification Gates, Agent Return Protocol Extensions, Changelog |
| 2026-04-15T00:00:00Z | 2026-04-13-the-protocol-skill | builder | Created initial code.md with 4 sub-protocols, Scope Heuristics, and Sub-Protocol definitions per plan Part 3 specification |
