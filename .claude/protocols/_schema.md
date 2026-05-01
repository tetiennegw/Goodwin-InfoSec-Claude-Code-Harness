---
type: schema
schema-version: 1
description: Format specification for all protocol profile files in .claude/protocols/
created: 2026-04-14T23:56:00Z
last-updated: 2026-04-14T23:56:00Z
status: active
---

# Protocol Profile Schema — Version 1

This file is **not a protocol profile**. It is the format specification that all profile files (`.claude/protocols/*.md`) must conform to. See `default.md` for the base fallback profile. Start here when creating a new domain profile.

Runtime discovery: the skill globs `.claude/protocols/*.md`, skips `_schema.md` (underscore prefix), reads each profile frontmatter `triggers` field, and regex-matches against the user request. Highest-specificity match wins; ties prompt Tyler.

---

## Table of Contents

1. [File Naming Convention](#1-file-naming-convention)
2. [Frontmatter Requirements](#2-frontmatter-requirements)
3. [Required Body Sections](#3-required-body-sections)
4. [Optional Body Sections](#4-optional-body-sections)
5. [Validation Rules](#5-validation-rules)
6. [5-Field MVP Rule](#6-5-field-mvp-rule)
7. [Sub-Protocol Parameter Reference](#7-sub-protocol-parameter-reference)
8. [Scope Coverage Requirement](#8-scope-coverage-requirement)
9. [Canonical Scope Names](#9-canonical-scope-names)
10. [Complete Profile Example](#10-complete-profile-example)

---

## 1. File Naming Convention

Files beginning with `_` are skipped by the runtime glob. Only `_schema.md` uses this prefix today; reserve the pattern for system files. Domain profile names use lowercase, hyphen-separated slugs (e.g., `security-ops.md`, `legal-tech.md`). One profile per domain — sub-protocols live inside the domain profile, not in separate files.

    .claude/protocols/
      _schema.md          <- this file (format spec, NOT a profile — skipped by runtime)
      default.md          <- always-loaded base fallback profile
      {domain}.md         <- domain-specific profiles (e.g., code.md, harness.md)

---

## 2. Frontmatter Requirements

All profile files begin with a YAML frontmatter block delimited by `---`.

### 2.1 Required Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `name` | string | Human-readable profile name | `Code Protocol` |
| `schema-version` | integer | Schema version this profile targets — must be `1` for this spec | `1` |
| `description` | string | One-sentence description of the domain this profile covers | `Software development — scripts, extensions, libraries, platforms` |
| `triggers` | list of strings | Regex patterns matched against user request text; any match activates this profile | see section 5.1 |

### 2.2 Optional Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `extends` | string | Parent profile filename (without path) to inherit from; unresolved fields fall through to parent | `default` |
| `anti-triggers` | list of strings | Simple string literals (NOT regex) — if request matches any and does NOT match a trigger, skip this profile | `- research` |
| `always-activate-skills` | list of strings | Skill names always activated when this profile is selected | `- task-list-management` |
| `min-core-version` | positive integer | Minimum CLAUDE.md schema version required for this profile to function correctly | `1` |
| `created` | string | ISO date when profile was created | `2026-04-14` |
| `last-updated` | string | ISO date when profile was last modified | `2026-04-14` |

### 2.3 Minimal Frontmatter Example (5-field MVP)

```yaml
---
name: Security Ops Protocol
schema-version: 1
description: Security operations — detection rules, playbooks, investigations
triggers:
  - detection rule
  - write.*playbook
  - investigate.*alert
---
```

### 2.4 Full Frontmatter Example

```yaml
---
name: Code Protocol
schema-version: 1
extends: default
description: Software development — scripts, extensions, libraries, platforms
triggers:
  - write a script
  - build.*extension
  - implement.*function
  - refactor
  - detection.*platform
anti-triggers:
  - research
always-activate-skills:
  - task-list-management
min-core-version: 1
created: 2026-04-14
last-updated: 2026-04-14
---
```


---

## 3. Required Body Sections

Every profile must include the following sections, in this order. A profile missing any required section fails validation.

**Exception**: Profiles using the 5-field MVP rule (section 6) only need the five MVP sections. All other sections inherit from `extends: default`.

### 3.1 `## Scope Heuristics`

A markdown table mapping observable request indicators to canonical scope names. This table drives scope assessment in the skill flow.

**Required format (table with two columns: Indicator and Scope):**

**Rules:**
- At minimum, provide rows for Small, Medium, Large, and Ultra. Mini is optional if it maps to the same heuristic as Small.
- Indicators are human-readable descriptions, not regex.
- Scope values MUST use canonical names (see section 9).

**Example:**

| Indicator | Scope |
|-----------|-------|
| Single script, < 200 lines, one language | Small |
| Multi-file, one component, TDD needed | Medium |
| Multi-component system, cross-language, integration tests | Large |
| Multi-service platform, external integrations, phased rollout | Ultra |

---

### 3.2 `## Sub-Protocols`

One `###` subsection per scope range, each defining the 6 required scaling parameters. Sub-protocols are the heart of a domain profile — they tell the skill how to execute at each scale.

**6 required parameters per sub-protocol:**
- **Scaffolding**: {what staging artifacts to create}
- **Research**: {how much research, how many rounds/sources}
- **Plan**: {plan format — flat checklist vs full 16-section vs hub plan}
- **Build**: {builder configuration — agents, TDD approach, session span}
- **Verification**: {verification approach — manual vs 3-tier gates vs per-phase verifier}
- **Artifact chain**: {ordered sequence of artifact types from start to done}

**Rules:**
- Each sub-protocol must have exactly the 6 parameters above.
- Profiles extending `default` may add optional parameters (`Foundation gate`, `Session span`, `Tyler checkpoints`) for Large and Ultra sub-protocols.
- Sub-protocol names use Title Case. The scope range appears in parentheses after the name.
- All 6 parameters are required. Do not omit any.
- See section 7 for parameter definitions and valid values.
- See section 8 for scope coverage requirements.

**Example:**

    ### Simple Script (Mini/Small)
    - **Scaffolding**: STATE.md + single output file
    - **Research**: None or 1 quick search
    - **Plan**: Flat checklist (5-10 steps), acceptance criteria inline
    - **Build**: 1 builder agent, tests alongside code
    - **Verification**: Manual run + assert output
    - **Artifact chain**: intent -> build -> assert -> done

    ### Library/Tool (Medium)
    - **Scaffolding**: STATE.md + staging dir with wave subdirs
    - **Research**: 1 gatherer wave (5-10 sources)
    - **Plan**: Full 16-section plan (scope-gated for Medium)
    - **Build**: TDD: tests -> implement -> verify per phase
    - **Verification**: 3-tier gates (lint -> unit -> E2E)
    - **Artifact chain**: research -> requirements -> design -> TDD tests -> build -> 3-tier verify

---
### 3.3 `## Wave Sequences`

A table mapping each sub-protocol to its ordered agent wave sequence. This is the execution blueprint — the skill reads this to know which agents to dispatch and in what order.

**Required format (table with two columns: Sub-Protocol and Wave Sequence):**

**Rules:**
- Every sub-protocol defined in `## Sub-Protocols` must have exactly one row in this table.
- Agent sequence notation uses `[agent(config)]` for parameterized agents and `->` for sequential ordering.
- `GATE` markers indicate hard blocking checkpoints between phases (required for Large and Ultra).

**Example:**

| Sub-Protocol | Wave Sequence |
|---|---|
| Simple Script | [builder] -> [documenter] |
| Library/Tool | [gatherer] -> [planner] -> [builder(2-3 rounds)] -> [verifier] -> [documenter] |
| Multi-Component System (Large) | [gatherer(1 wave)] -> [planner(hub plan)] -> [builder(2-4 rounds)] -> [builder+verifier] -> [documenter] |
| Platform Architecture (Ultra) | [gatherer(broad)] -> [gatherer(focused)] -> [planner(hub+subsystems)] -> [builder(Phase 1)] -> GATE -> [builder+verifier(Phase 2)] -> GATE -> [documenter] |

---

### 3.4 `## Acceptance Criteria Template`

One `###` subsection per sub-protocol. Each subsection contains EODIC-formatted checkboxes serving as the reusable template the skill populates when initializing a new task STATE.md.

**Rules:**
- Each criterion must be EODIC (Executable, Observable, Deterministic, Independent, Cumulative). See `.claude/rules/implementation-plan-standard.md` section 7.
- Placeholder tokens (e.g., `{script}`, `{test-runner}`) are valid — filled in at task init time.
- A minimum of 3 criteria per sub-protocol is required. Small sub-protocols may have 3-4; Ultra sub-protocols should have 6-8.

**Example:**

    ### Simple Script
    - [ ] Script runs without errors: bash {script} --help
    - [ ] Output matches expected format: diff output expected.txt
    - [ ] No hardcoded secrets: grep -rn password {script}

    ### Library/Tool
    - [ ] All source files parse: {linter} {src}/
    - [ ] All tests pass: {test-runner} tests/
    - [ ] No hardcoded secrets: grep -rn password {src}/
    - [ ] Test coverage >= 70%: {coverage-tool}
    - [ ] Imports resolve, no missing deps: {import-check}

---
### 3.5 `## SME Personas`

Defines the domain expert identities used when the skill dispatches SME assessor agents. The persona text is copied into the SME assessor ROLE field verbatim.

**Required format:**

    ## SME Personas
    - **Primary ({role label})**: {persona description}
    - **Secondary ({role label})**: {persona description}
    - **Tertiary ({scope note})**: {persona description}

**Rules:**
- **Primary** is required for all profiles.
- **Secondary** is required for all profiles.
- **Tertiary** is required for profiles whose scope covers Large or Ultra; optional for Small/Medium-only profiles.
- Role label in parentheses is a human-readable description of what this SME validates (e.g., code review, security, architecture).
- Persona descriptions must name: domain of expertise, years of experience, specific validation responsibilities. Generic descriptions fail validation.
- The `{language/framework}` pattern is valid — substituted at dispatch time based on the active task detected stack.

**Good example:**

    - **Primary (code review)**: Senior Software Engineer — 10+ years in {language/framework}; validates architecture, code quality, test coverage
    - **Secondary (security)**: Application Security Engineer — static analysis, injection defense, secret scanning, dependency audit
    - **Tertiary (Ultra required, Large optional)**: System Architect — cross-service integration, data flow, scalability, deployment strategy

**Bad example (fails validation — too generic):**

    - **Primary**: An expert reviewer
    - **Secondary**: Security checker

---

### 3.6 `## Verification Gates`

Three-tier gate definitions scoped to this domain. Gates are cumulative and blocking — a later tier cannot pass if an earlier tier failed.

**Required format:**

    ## Verification Gates
    ### Tier 1 ({label}) — blocking
    - {gate criterion}

    ### Tier 2 ({label}) — blocking, cumulative
    - {gate criterion}

    ### Tier 3 ({label}) — blocking, cumulative
    - {gate criterion}

**Rules:**
- All three tiers are required.
- The tier label names the type of validation (e.g., Build/Lint, Unit/Content, E2E/Integration).
- Each tier must have at least 2 gate criteria specific to this domain.
- `blocking` and `blocking, cumulative` annotations are required verbatim.
- Gate criteria must be concrete and checkable — not aspirational.

**Example:**

    ### Tier 1 (Build/Lint) — blocking
    - All source files parse without syntax errors
    - Linter/formatter passes with zero warnings

    ### Tier 2 (Unit/Content) — blocking, cumulative
    - All unit tests pass (current phase + ALL prior phases)
    - Test coverage meets domain threshold

    ### Tier 3 (E2E/Integration) — blocking, cumulative
    - Integration tests pass (real or mocked external deps)
    - Security scan passes (no secrets, no injection vectors)

---
## 4. Optional Body Sections

These sections may be present in a profile. Their absence does not fail validation.

### 4.1 `## Agent Return Protocol Extensions`

A table of additional fields that agents completing tasks under this protocol must include in their return block, beyond the base fields defined in `hub.md`.

**Format (table with columns: Field, Required For, Description):**

**Example:**

| Field | Required For | Description |
|-------|-------------|-------------|
| TEST_RESULTS | All | X passed, Y failed, Z skipped |
| COVERAGE | Medium+ | current% vs required% |
| SECURITY_SCAN | Medium+ | clean OR issues found OR deferred |
| BUILD_LOG_PATH | All | path to artifact for auditing |
| SUBSYSTEM_STATUS | Ultra only | per-subsystem pass/fail matrix |

### 4.2 `## Changelog`

Standard changelog for the profile file itself.

**Format (table with columns: Timestamp, Agent, Change):**

**Rules:**
- Maximum 10 entries, newest first.
- Required when modifying an existing profile. Optional (but recommended) when first creating a profile.
- The Project column is omitted here — unlike hub staging artifacts, the profile name is implicit context.

---

## 5. Validation Rules

These rules are enforced by `scripts/utils/validate-profile.ps1` and checked by SME assessors.

### 5.1 Frontmatter Validation

| Rule | Enforcement |
|------|-------------|
| `schema-version` must equal `1` (this spec) | Hard fail — profile is rejected |
| `name` must be a non-empty string | Hard fail |
| `description` must be a non-empty string | Hard fail |
| `triggers` must be a non-empty list | Hard fail |
| Each trigger must be a valid bash ERE regex (no lookahead, no backreferences) | Hard fail |
| `anti-triggers` entries must be plain strings NOT regex | Hard fail if any entry contains regex metacharacters |
| `extends` must reference an existing `.claude/protocols/{value}.md` file | Hard fail if file not found |
| `min-core-version` must be a positive integer if present | Hard fail if non-integer or negative |

**Anti-trigger rule rationale**: Negative lookahead is not supported in bash ERE (used by the runtime `grep -E` matching). Anti-triggers use simple string containment checks instead. Matching logic: if the request contains ANY anti-trigger string AND does NOT also match a trigger pattern, the profile is skipped.

**Anti-trigger examples — VALID (simple strings only):**

    anti-triggers:
      - research
      - just explain
      - what is

**Anti-trigger examples — INVALID (do not use regex):**

    anti-triggers:
      - "(?!.*implement)"   # broken in bash ERE — lookahead not supported
      - "research\b"        # avoid metacharacters — use plain strings

### 5.2 Section Validation

| Rule | Enforcement |
|------|-------------|
| All 6 required sections must be present | Hard fail |
| `## Sub-Protocols` must cover all scope ranges referenced in `## Scope Heuristics` | Hard fail if coverage gap found |
| Each sub-protocol must define all 6 required parameters | Hard fail if any parameter missing |
| `## Wave Sequences` must have one row per sub-protocol defined in `## Sub-Protocols` | Hard fail if sub-protocol row missing |
| `## SME Personas` must have Primary and Secondary | Hard fail |
| `## SME Personas` must have Tertiary if profile covers Large or Ultra scope | Hard fail |
| `## Acceptance Criteria Template` must have one subsection per sub-protocol | Hard fail |
| Each sub-protocol acceptance criteria must have >= 3 items | Warning (not hard fail) |
| `## Verification Gates` must have all 3 tiers | Hard fail |
| `## Scope Heuristics` table must use canonical scope names only | Hard fail |

### 5.3 Cross-Reference Validation

| Rule | Enforcement |
|------|-------------|
| If `extends` is set, the parent file must load without error | Hard fail |
| `always-activate-skills` entries should match `.claude/commands/{name}.md` filenames | Warning — skill may not exist yet during bootstrapping |

---

## 6. 5-Field MVP Rule

A new domain can be onboarded with just 5 fields. Everything else inherits from `extends: default`.

**The 5 required fields for an MVP profile:**

1. `triggers` (frontmatter) — regex patterns that identify this domain
2. `## Scope Heuristics` — when is this type of work Small vs Large vs Ultra
3. `## SME Personas` — who reviews this domain work
4. `## Acceptance Criteria Template` — reusable EODIC criteria per sub-protocol
5. `## Wave Sequences` — which agents in which order

Everything else falls through to `extends: default`. The `## Sub-Protocols` and `## Verification Gates` sections are not required for MVP profiles — the orchestrator uses `default.md` sub-protocol definitions instead.

**Minimum viable profile structure:**

    ---
    name: Legal Research Protocol
    schema-version: 1
    extends: default
    description: Legal research and document review tasks
    triggers:
      - research.*case law
      - review.*contract
      - draft.*memo
    ---

    ## Scope Heuristics
    | Indicator | Scope |
    |-----------|-------|
    | Single document review, < 1 hour | Small |
    | Multi-document analysis, memo required | Medium |
    | Multi-matter research, precedent mapping | Large |
    | Full case strategy, multi-jurisdiction | Ultra |

    ## Wave Sequences
    | Sub-Protocol | Wave Sequence |
    |---|---|
    | Quick Review (Small) | [builder] -> [documenter] |
    | Memo Analysis (Medium) | [gatherer] -> [builder] -> [verifier] -> [documenter] |

    ## Acceptance Criteria Template
    ### Quick Review (Small)
    - [ ] Document summary produced: file exists at output path
    - [ ] Key dates and parties extracted: grep for structured output
    - [ ] No privileged information exposed: manual review

    ### Memo Analysis (Medium)
    - [ ] Memo structure complete (issue, rule, analysis, conclusion)
    - [ ] At least 3 citations verified to exist
    - [ ] Opposing arguments addressed

    ## SME Personas
    - **Primary (legal review)**: Senior Associate — 5+ years in {practice area}; validates legal accuracy, citation quality, argument structure
    - **Secondary (risk)**: Partner-level reviewer — validates risk exposure, privileged content, client impact

To graduate from MVP to full profile: add `## Sub-Protocols` and `## Verification Gates` sections with domain-specific content, then run `validate-profile.ps1` to confirm.

---
## 7. Sub-Protocol Parameter Reference

Each `### Sub-Protocol Name (scope range)` section under `## Sub-Protocols` must define these 6 parameters:

| Parameter | Description | Valid Values / Examples |
|-----------|-------------|------------------------|
| `Scaffolding` | What staging artifacts to create at task start | `STATE.md + single output file`, `STATE.md + staging dir + per-subsystem specs + HANDOFF.md` |
| `Research` | How much research, how many rounds/sources | `None`, `1 gatherer wave (5-10 sources)`, `2 gatherer waves (broad then focused), 25-40+ sources total` |
| `Plan` | Plan format used | `Flat checklist (5-10 steps)`, `Full 16-section plan (scope-gated for Medium)`, `Hub plan + per-subsystem specs` |
| `Build` | Builder agent configuration | `1 builder agent, tests alongside code`, `TDD: tests -> implement -> verify per phase`, `Phased parallel builders, max 8 agents/wave, cross-session` |
| `Verification` | Verification approach | `Manual run + assert output`, `3-tier gates (lint -> unit -> E2E)`, `3-tier gates + per-phase verifier + regression gates` |
| `Artifact chain` | Ordered artifact sequence from start to completion | `intent -> build -> assert -> done`, `research -> requirements -> TDD tests -> build -> 3-tier verify` |

**Large and Ultra sub-protocols may also include these optional extended parameters:**

| Parameter | Description |
|-----------|-------------|
| `Foundation gate` | Gate condition that must pass before the next phase begins |
| `Session span` | `Single session` or `Multi-session` (Multi-session requires HANDOFF.md) |
| `Tyler checkpoints` | When Tyler is asked to review or approve before work continues |

---

## 8. Scope Coverage Requirement

Every domain profile `## Sub-Protocols` section must cover all scope ranges that its `## Scope Heuristics` table references. Gaps in scope coverage cause validation to fail.

**Standard mapping:**

| Scope Range | Sub-Protocol Role |
|-------------|------------------|
| Mini/Small | Lightest execution path — no research wave, flat checklist plan |
| Medium | Structured execution — 1 research wave, full plan, TDD |
| Large | Multi-phase execution — 2+ research rounds, hub plan, foundation gate |
| Ultra | Cross-session execution — multiple research waves, per-subsystem specs, HANDOFF.md |

If your profile scope heuristics only go up to Medium (all requests in this domain are naturally Small-Medium), you only need sub-protocols for Mini/Small and Medium. Document this explicitly with a comment under `## Sub-Protocols`.

**Example of a profile with declared limited scope:**

    ## Sub-Protocols
    <!-- This domain produces documentation artifacts only. No requests exceed Medium scope.
         Large/Ultra coverage inherits from default.md. -->

    ### Quick Doc (Mini/Small)
    - **Scaffolding**: STATE.md + single output file
    - **Research**: None
    - **Plan**: Flat checklist (3-5 steps)
    - **Build**: 1 builder agent
    - **Verification**: Structural check — all sections present
    - **Artifact chain**: intent -> draft -> review -> done

    ### Structured Doc (Medium)
    - **Scaffolding**: STATE.md + staging dir with wave subdirs
    - **Research**: 1 gatherer wave (5-10 sources)
    - **Plan**: Full 16-section plan (scope-gated for Medium)
    - **Build**: 1 builder agent, 2-3 rounds with SME review
    - **Verification**: 3-tier gates (structure -> content accuracy -> cross-ref integrity)
    - **Artifact chain**: research -> outline -> draft -> SME review -> final

---

## 9. Canonical Scope Names

The scope heuristics table and sub-protocol headers MUST use these exact names. Aliases, abbreviations, or alternate capitalizations fail validation.

| Canonical Name | Description | Aliases (NOT valid in profiles) |
|----------------|-------------|--------------------------------|
| `Mini` | Trivial, passthrough-adjacent | Trivial, Tiny, XS |
| `Small` | Single-wave, minimal research | Simple, Basic |
| `Medium` | Structured, multi-wave | Mid, Moderate |
| `Large` | Multi-phase, verifier pass | Big, Complex |
| `Ultra` | Cross-session, subsystem specs | Mega, XL, Epic |

In sub-protocol headers, scope ranges may be combined with `/` (e.g., `Mini/Small` when both scopes share the same sub-protocol). This is the only valid range notation.

---
## 10. Complete Profile Example

The following is a complete, valid profile file demonstrating all required sections. This mirrors the `code.md` reference implementation. See the actual `code.md` for production detail.

    ---
    name: Code Protocol
    schema-version: 1
    extends: default
    description: Software development — scripts, extensions, libraries, platforms
    triggers:
      - write a script
      - build.*extension
      - implement.*function
      - refactor
    anti-triggers:
      - research
    always-activate-skills:
      - task-list-management
    min-core-version: 1
    created: 2026-04-14
    last-updated: 2026-04-14
    ---

    ## Scope Heuristics
    | Indicator | Scope |
    |-----------|-------|
    | Single script, < 200 lines, one language | Small |
    | Multi-file, one component, TDD needed | Medium |
    | Multi-component system, cross-language, integration tests | Large |
    | Multi-service platform, external integrations, phased rollout | Ultra |

    ## Sub-Protocols

    ### Simple Script (Mini/Small)
    - **Scaffolding**: STATE.md + single output file
    - **Research**: None or 1 quick search
    - **Plan**: Flat checklist (5-10 steps), acceptance criteria inline
    - **Build**: 1 builder agent, tests alongside code
    - **Verification**: Manual run + assert output
    - **Artifact chain**: intent -> build -> assert -> done

    ### Library/Tool (Medium)
    - **Scaffolding**: STATE.md + staging dir with wave subdirs
    - **Research**: 1 gatherer wave (5-10 sources)
    - **Plan**: Full 16-section plan (scope-gated for Medium)
    - **Build**: TDD: tests -> implement -> verify per phase
    - **Verification**: 3-tier gates (lint -> unit -> E2E)
    - **Artifact chain**: research -> requirements -> design -> TDD tests -> build -> 3-tier verify

    ### Multi-Component System (Large)
    - **Scaffolding**: STATE.md + staging dir + component plans within hub plan + ADRs (major decisions only)
    - **Research**: 1 gatherer wave, 2-4 rounds, 15-25 sources
    - **Plan**: Hub plan (full 16-section), component-level detail within hub, 10-30 tasks
    - **Build**: Sequential builders, foundation-first gate, max 6 agents/wave, single-session
    - **Verification**: 3-tier gates + 1 verifier pass (end of build) + security review
    - **Artifact chain**: research -> requirements+design (hub plan) -> ADRs -> TDD tests -> sequential build -> verification -> docs
    - **Foundation gate**: Phase 1 must COMPLETE before Phase 2 begins
    - **Session span**: Single session

    ### Platform Architecture (Ultra)
    - **Scaffolding**: STATE.md + staging dir + per-subsystem specs + ADRs (all decisions) + dependency graph + HANDOFF.md
    - **Research**: 2 gatherer waves (broad survey then focused deep-dive), 2-5 rounds each, 25-40+ sources total
    - **Plan**: Hub plan + per-subsystem specs in staging/{task-id}/subsystems/, 30-80+ tasks
    - **Build**: Phased parallel builders, per-phase verification gates, max 8 agents/wave, cross-session
    - **Verification**: 3-tier gates + per-phase verifier + regression gates + cross-subsystem integration + security review
    - **Artifact chain**: research (broad) -> research (focused) -> PRD -> ADRs -> subsystem specs -> phased builds -> integration -> hardening -> docs
    - **Foundation gate**: Each phase must PASS its phase gate before the next begins
    - **Session span**: Multi-session — HANDOFF.md written at each session boundary
    - **Tyler checkpoints**: After every major phase

    ## Wave Sequences
    | Sub-Protocol | Wave Sequence |
    |---|---|
    | Simple Script | [builder] -> [documenter] |
    | Library/Tool | [gatherer] -> [planner] -> [builder(2-3 rounds)] -> [verifier] -> [documenter] |
    | Multi-Component System (Large) | [gatherer(1 wave)] -> [planner(hub plan)] -> [builder(2-4 rounds)] -> [builder+verifier] -> [documenter] |
    | Platform Architecture (Ultra) | [gatherer(broad)] -> [gatherer(focused)] -> [planner(hub+subsystems)] -> [builder(Phase 1)] -> GATE -> [builder+verifier(Phase 2)] -> GATE -> [documenter] |

    ## Acceptance Criteria Template
    ### Simple Script
    - [ ] Script runs without errors: bash {script} --help
    - [ ] Output matches expected format: diff output expected.txt
    - [ ] No hardcoded secrets: grep -rn password {script}

    ### Library/Tool
    - [ ] All source files parse: {linter} {src}/
    - [ ] All tests pass: {test-runner} tests/
    - [ ] No hardcoded secrets: grep -rn password {src}/
    - [ ] Test coverage >= 70%: {coverage-tool}

    ### Multi-Component System (Large)
    - [ ] All Phase 1 acceptance criteria met before Phase 2 starts
    - [ ] All component tests pass: {test-runner} tests/
    - [ ] Cross-component integration spot checks pass
    - [ ] Security review: no injection, no secrets, least privilege
    - [ ] Architecture ADRs exist for major design decisions

    ### Platform Architecture (Ultra)
    - [ ] Per-subsystem acceptance criteria defined in subsystem specs
    - [ ] Each phase gate passes before next phase begins
    - [ ] Regression tests: all prior phase tests still pass after each new phase
    - [ ] Artifact traceability: every requirement links to test case
    - [ ] Session handoff: HANDOFF.md current at every session boundary

    ## SME Personas
    - **Primary (code review)**: Senior Software Engineer — 10+ years in {language/framework}; validates architecture, code quality, test coverage
    - **Secondary (security)**: Application Security Engineer — static analysis, injection defense, secret scanning, dependency audit
    - **Tertiary (Ultra required, Large optional)**: System Architect — cross-service integration, data flow, scalability, deployment strategy

    ## Verification Gates
    ### Tier 1 (Build/Lint) — blocking
    - All source files parse without syntax errors
    - Linter/formatter passes
    - All imports resolve; no missing dependencies

    ### Tier 2 (Unit/Content) — blocking, cumulative
    - All unit tests pass (current phase + ALL prior phases)
    - Test coverage meets threshold
    - test_map.txt matches actual test count

    ### Tier 3 (E2E/Integration) — blocking, cumulative
    - Integration tests pass (real or mocked external deps)
    - Security scan passes (no secrets, no injection vectors)
    - Cross-subsystem contracts validated (Ultra only)

    ## Agent Return Protocol Extensions
    | Field | Required For | Description |
    |-------|-------------|-------------|
    | TEST_RESULTS | All | X passed, Y failed, Z skipped |
    | COVERAGE | Medium+ | current% vs required% |
    | SECURITY_SCAN | Medium+ | clean OR issues found OR deferred |
    | BUILD_LOG_PATH | All | path to artifact for auditing |
    | SUBSYSTEM_STATUS | Ultra only | per-subsystem pass/fail matrix |

    ## Changelog
    | Timestamp | Agent | Change |
    |-----------|-------|--------|
    | 2026-04-14T23:56 | builder | Created initial code.md profile (referenced as complete example in schema) |

---

## Changelog

| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-14T23:56:00Z | 2026-04-13-the-protocol-skill | builder | Created _schema.md — protocol profile format specification v1 |
