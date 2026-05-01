---
name: Default Protocol
schema-version: 1
description: >-
  Fallback protocol profile. Matches any request not claimed by a domain-specific profile.
  All domain profiles inherit from this via extends: default. Sections defined here are
  the authoritative baseline — domain profiles override only what they need.
triggers: []
# Empty triggers = catch-all. Runtime: if no other profile matches, use default.
anti-triggers: []
always-activate-skills:
  - task-list-management
  - daily-note-management
min-core-version: 1
created: 2026-04-14
last-updated: 2026-04-14
status: active
---

<!--
  DEFAULT PROTOCOL PROFILE
  ========================
  This file is the root of the protocol inheritance chain.

  Inheritance semantics:
  - Domain profiles declare `extends: default` in frontmatter
  - The skill reads both files and merges: domain-profile sections OVERRIDE default sections
  - Sections absent from the domain profile fall through to this file
  - This file MUST be complete enough to run end-to-end on its own (no missing required sections)

  DO NOT remove sections from this file. Domain profiles override; they do not delete.
-->

## Scope Heuristics

Generic scope indicators extracted from the current prompt-context-loader.sh pipeline (Steps 0-4)
and the CLAUDE.md scope table. Domain profiles replace this section with domain-specific
indicators but these remain the fallback for any unclassified request.

| Scope | Waves | Rounds/Wave | Max | Checkpoints | Indicators |
|-------|-------|-------------|-----|-------------|------------|
| **Passthrough** | 0 | 0 | 0 | None | Greetings, factual lookups, 1-step clarifications, read-only queries with no artifact output |
| **Mini** | 1 | 1 | 2 | None | 1-2 steps; single-file edit or quick lookup; one agent sufficient; no plan needed |
| **Small** | 2 | 1-2 | 3 | None | 3-5 steps; single function or config change; straightforward deliverable; no research wave |
| **Medium** | 3-4 | 1-3 | 4 | After planning | 5-15 steps; multi-file change or feature; research or design phase warranted; plan-mode required |
| **Large** | 4-5 | 2-4 | 6 | After research + planning + first build | 15-50 steps; system redesign, cross-component integration, comprehensive research; multi-wave |
| **Ultra** | 5+ | 2-5 | 8 | Multiple, cross-session | 50+ steps; full platform build, multi-week project, codebase migration; cross-session with HANDOFF.md |

### Auto-Escalation Rules

Escalate to Medium+ automatically when the request contains:

- **Research/analysis keywords**: research, investigate, analyze, compare, evaluate, comprehensive, thorough, deep-dive
- **Multi-file implementation keywords**: implement, build, refactor, migrate, integrate — when clearly multi-file or multi-component
- **Architecture keywords**: redesign, overhaul, platform, system, infrastructure — when paired with action verbs
- **Scope signals from Tyler**: "full", "complete", "end-to-end", "production-ready", or explicit scope override

### Passthrough Indicators (skip orchestration entirely)

Answer directly — no staging dir, no STATE.md, no task list — when:
- Request is a factual question answerable from context already in session
- Request is a greeting, status check, or administrative question (e.g., "what tasks are active?")
- Request is 1-step and produces no file artifact (e.g., "what is the syntax for X?")
- Tyler explicitly says "quick" or "off the top of your head"


---

## Sub-Protocols

The Default Protocol has a single sub-protocol called Generic that handles all scopes.
Domain profiles replace this section with multiple sub-protocols (one per scope cluster).

> **Task-list discipline applies to every sub-protocol.** Every wave/phase transition runs TaskCreate / TaskUpdate per `.claude/rules/task-handling.md` (naming, 3-level urgency, non-cancellation invariant). `/the-protocol` Step 0.5 creates the M0/M1/M2 meta-tasks before sub-protocol execution begins.

### Generic (all scopes)

Scaling parameters follow the Sub-Protocol Scaling Matrix from the plan. Values here are the
baseline; domain profiles provide domain-tuned values for each sub-protocol.

#### Passthrough
- **Scaffolding**: None — answer directly
- **Research**: None
- **Plan**: None
- **Build**: None — orchestrator responds inline
- **Verification**: None
- **Artifact chain**: none

#### Mini
- **Scaffolding**: STATE.md only (minimal frontmatter + next action)
- **Research**: None or 1 targeted web search
- **Plan**: Flat checklist (3-5 steps), inline in STATE.md
- **Build**: 1 builder agent, single round
- **Verification**: Manual check — file exists, output readable
- **Artifact chain**: intent → build → assert

#### Small
- **Scaffolding**: STATE.md + output file in staging dir
- **Research**: None or 1 quick search
- **Plan**: Flat checklist (5-10 steps), acceptance criteria inline
- **Build**: 1 builder agent, up to 2 rounds
- **Verification**: Manual run + assert output exists
- **Artifact chain**: intent → build → assert → done

#### Medium
- **Scaffolding**: STATE.md + staging dir with wave subdirs
- **Research**: 1 gatherer wave (5-10 sources)
- **Plan**: Full 16-section plan (scope-gated for Medium)
- **Build**: TDD — tests first → implement → verify per phase; up to 3 rounds/wave
- **Verification**: 3-tier gates per phase (lint → unit → E2E)
- **Artifact chain**: research → requirements → design → TDD tests → build → 3-tier verify
- **Context loaded**: Tier 1+2 — full profile + relevant rules files

#### Large
- **Scaffolding**: STATE.md + staging dir + component plans within hub plan + ADRs (major decisions only)
- **Research**: 1 gatherer wave, 2-4 rounds, 15-25 sources
- **Plan**: Hub plan (full 16-section), component-level detail within hub, 10-30 tasks
- **Build**: Sequential builders, foundation-first gate, max 6 agents/wave, single-session
- **Verification**: 3-tier gates + 1 verifier pass (end of build)
- **Artifact chain**: research → requirements+design (hub plan) → ADRs → TDD tests → sequential build → verification → docs
- **Foundation gate**: Phase 1 must COMPLETE before Phase 2 begins
- **Context loaded**: Tier 1+2+3a — profile + rules + research paths + codebase scan + prior domain tasks (~3K tokens)

#### Ultra
- **Scaffolding**: STATE.md + staging dir + per-subsystem specs + ADRs (all decisions) + dependency graph + HANDOFF.md
- **Research**: 2 gatherer waves (broad survey then focused deep-dive), 2-5 rounds each, 25-40+ sources total
- **Plan**: Hub plan + per-subsystem specs in `staging/{task-id}/subsystems/`, 30-80+ tasks, Subsystem Interface Matrix, Phasing Strategy
- **Build**: Phased parallel builders, per-phase verification gates, max 8 agents/wave, cross-session
- **Verification**: 3-tier gates + per-phase verifier + regression gates + cross-subsystem integration + security review + hardening phase
- **Artifact chain**: research (broad) → research (focused) → PRD → ADRs → subsystem specs → phased parallel builds → per-phase verification → integration → hardening → docs
- **Foundation gate**: Each phase must PASS its phase gate before the next begins
- **Session span**: Multi-session — HANDOFF.md written at each session boundary
- **Tyler checkpoints**: After every major phase — Tyler may descope, reprioritize, or restructure
- **Context loaded**: Tier 1+2+3b — everything Large + cross-project STATE.md + prior ADRs + HANDOFF.md + subsystem specs (~4K tokens)

---

## Wave Sequences

| Scope | Wave Sequence |
|-------|---------------|
| Passthrough | (none — inline response) |
| Mini | [builder(1 round)] → [documenter] |
| Small | [builder(1-2 rounds)] → [documenter] |
| Medium | [gatherer] → [planner] → [builder(2-3 rounds)] → [verifier] → [documenter] |
| Large | [gatherer(1 wave)] → [planner(hub plan)] → [builder(primary, 2-4 rounds)] → [builder+verifier(remaining + verify)] → [documenter] |
| Ultra | [gatherer(broad)] → [gatherer(focused)] → [planner(hub + subsystem specs)] → [builder(Phase 1)] → GATE → [builder+verifier(Phase 2)] → GATE → [builder+verifier(Phase N)] → GATE → [hardening] → [documenter] |

Agent roster for reference:

| Agent | Role | Model |
|-------|------|-------|
| gatherer | Research + info gathering | sonnet |
| planner | Structured planning | opus |
| builder | Produces deliverables | sonnet/opus |
| verifier | Independent fact-check (blind to plan) | opus |
| documenter | Updates notes/kb/state/INDEX.md | sonnet |
| sme-assessor | Dynamic SME (parameterized per dispatch) | opus |
| context-curator | Reusable classifier, owns taxonomy | sonnet |

---

## Acceptance Criteria Template

Generic EODIC criteria that apply to any work type. Domain profiles append domain-specific
criteria below these. Every criterion must be Executable, Observable, Deterministic,
Independent, and Cumulative.

### Any Scope (universal baselines)
- [ ] All output files exist at specified paths: test -f {output-path}
- [ ] All markdown artifacts have valid YAML frontmatter: grep returns 2+ delimiter lines
- [ ] Changelog entries present in each artifact: grep -c "Changelog" {file} returns 1+
- [ ] No hardcoded secrets: grep -rni "password|secret|api.key|token" {output-dir} returns 0 (or only doc references)
- [ ] STATE.md updated with current progress and next action

### Mini / Small (5-field MVP)
- [ ] Output file readable and non-empty: wc -l {output} greater than 0
- [ ] Intent captured in STATE.md macro goal: grep -c "Macro Goal" hub/staging/{task-id}/STATE.md
- [ ] No broken cross-references: wiki-link targets exist on disk (verified via Glob)

### Medium (adds plan and TDD validation)
- [ ] All unit tests pass: {test-runner} tests/ exits 0
- [ ] Plan artifact exists: test -f hub/staging/{task-id}/plan-*.md
- [ ] All required plan sections present (16-section standard): section heading count >= 8
- [ ] Research artifact exists and has sources: test -f hub/staging/{task-id}/research-*.md

### Large (adds ADR and security)
- [ ] All Phase 1 (foundation) criteria met before Phase 2 starts (enforced at CHECKPOINT)
- [ ] ADRs exist for major design decisions: ls docs/decisions/ADR-*.md | wc -l returns >= 1
- [ ] Cross-component integration spot checks pass (defined per-task in STATE.md)
- [ ] No injection vulnerabilities or privilege escalation in any produced code

### Ultra (adds subsystem traceability and session handoff)
- [ ] Per-subsystem acceptance criteria defined in subsystem specs
- [ ] Each phase gate passed before next phase began (evidenced in STATE.md Progress Summary)
- [ ] HANDOFF.md current at every session boundary: test -f hub/staging/{task-id}/HANDOFF.md
- [ ] Artifact traceability: every requirement in STATE.md links to at least one test case
- [ ] Regression gate: all prior phase tests still pass after each new phase

---

## SME Personas

Generic reviewer personas. Domain profiles replace this section with domain-specific personas.
These generalist personas are used when no domain profile matches.

### Primary — General Reviewer
A senior practitioner (10+ years) in the relevant discipline. Validates:
- Does the deliverable accomplish its stated intent?
- Is the scope appropriate — neither over-engineered nor under-specified?
- Are all acceptance criteria verifiably met with external evidence?
- Is the STATE.md accurate and up to date?

Dispatch template fragment:

    ROLE: You are a Senior Generalist Practitioner with 10+ years of experience across
    software engineering, technical writing, and systems architecture.
    Validate that the work product meets its stated intent and acceptance criteria.
    Require EXTERNAL EVIDENCE (file checks, test runs, grep output) — never accept agent self-reports.

### Secondary — Quality Assurance Reviewer
Validates structural and formatting completeness. Checks:
- Frontmatter YAML is valid (all required fields present, no syntax errors)
- Changelog is present and follows the max-10-entry standard
- All internal cross-references and wiki-links resolve to existing files
- No section from the schema is missing from the artifact

Dispatch template fragment:

    ROLE: You are a Documentation Quality Reviewer specializing in structured technical
    artifacts and schema compliance. Validate format, frontmatter, cross-references,
    and changelog completeness. Use Glob/Grep to verify all referenced file paths exist.

### Tertiary — Security Reviewer (Large+ only)
Required for Large scope, mandatory for Ultra. Checks:
- No hardcoded secrets, tokens, or credentials in any artifact
- No injection vulnerabilities in produced code
- Least-privilege principle applied to any permission grants or agent dispatches
- Sensitive data masked in logs and outputs

Dispatch template fragment:

    ROLE: You are an Application Security Engineer. Review all produced artifacts for
    hardcoded secrets, injection risks, over-privileged access patterns, and sensitive
    data exposure. Use grep/search tools — do not rely on agent assertions.

---

## Verification Gates

Standard 3-tier gates from hub.md (.claude/rules/hub.md). All gates are blocking and cumulative.
Domain profiles may add domain-specific checks to any tier but may not remove these baseline checks.

### Tier 1 — Build / Lint (blocking)

Applies at: end of every build phase, before any CHECKPOINT advances.

For code:
- All source files parse without syntax errors
- Linter/formatter passes with zero errors (warnings allowed if documented)
- All imports resolve; no missing dependencies

For documentation / plans / runbooks:
- Markdown structure valid (all required sections present, correct heading levels)
- YAML frontmatter parses without errors (grep "^---" returns 2 delimiters)
- All required frontmatter fields populated (type, task-id, agent, created, last-updated)

For scripts (Goodwin toolchain):
- Bash: shellcheck passes (or documented exceptions)
- PowerShell: Invoke-ScriptAnalyzer clean (or documented exceptions); AllSigned policy satisfied before testing
- KQL: logic review complete, time parameters externalized via let statements

### Tier 2 — Unit / Content (blocking, cumulative)

Applies at: after each phase; ALL prior phase Tier 2 tests must also pass.

For code:
- All unit tests pass (current phase + ALL prior phases)
- Test coverage meets threshold (defined per-task in STATE.md)
- test_map.txt reflects actual test/function mapping

For documentation:
- Content accuracy validated (SME reviewer confirms claims are correct)
- All internal cross-references exist: each wiki-link target verified via Glob
- No orphaned sections (every heading has content beneath it)

### Tier 3 — E2E / Integration (blocking, cumulative)

Applies at: end of full build (before documenter wave); skipped for Mini/Small.

For code:
- Integration tests pass (real or mocked external dependencies)
- End-to-end workflow runs without manual intervention
- Security scan passes (no secrets, no injection vectors, no over-privilege)

For documentation / protocols:
- Cross-file integrity: all ref: links resolve via Glob across the full artifact set
- Acceptance criteria in STATE.md independently verified by SME assessor (not author)
- All ADRs linked from the artifacts that implement their decisions

### VERIFY Task Execution Checklist

When a VERIFY task fires in the task list:
1. Check all output files from this phase exist (test -f for each entry in Build Path)
2. Run Tier 1 checks above
3. If Medium+: run Tier 2 checks
4. If Large+: run Tier 3 checks (or confirm they will run at end of full build)
5. Record pass/fail in STATE.md Progress Summary with timestamp
6. If FAIL: trigger DIAGNOSE-FIX-RETRY (3 attempts max, then FLAG to Tyler)
7. If PASS: advance to CHECKPOINT task

### CHECKPOINT Task Execution Checklist

After every VERIFY passes:
1. Update STATE.md:
   - Progress Summary: append this phase outcome with timestamp
   - current-wave / current-round: increment
   - last-updated: set to now
   - Open Items: update
   - Next Action: set to next phase first task
2. Call TaskUpdate: mark this phase tasks as completed
3. Confirm active-tasks.md regenerated (PostToolUse hook fires automatically on STATE.md write)
4. A CHECKPOINT that does not update STATE.md is a protocol violation

---

## Agent Return Protocol

All agents completing any task under this protocol MUST return the following structured block.
Domain profiles may extend with additional fields.

    AGENT COMPLETE: [what was the focus of this task]
    OUTPUT FILE: [absolute path to primary artifact]
    SUMMARY: [2-3 key findings or decisions made]
    KEY FINDING: [single most important insight]
    INTENT ALIGNMENT: [how this output serves the Intent stated in STATE.md]
    STATUS: COMPLETE | PARTIAL | BLOCKED
    GAPS: [anything not completed and why — or "none"]

---

## Changelog

| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-14T00:00 | 2026-04-13-the-protocol-skill | builder | Created default.md — baseline protocol profile capturing current prompt-context-loader.sh pipeline and CLAUDE.md scope table |
