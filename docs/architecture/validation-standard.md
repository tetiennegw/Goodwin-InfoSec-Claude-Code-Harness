---
title: "Validation Standard"
last-updated: 2026-04-08
related-files: [.claude/rules/hub.md, .claude/agents/sme-assessor.md, .claude/agents/verifier.md]
---

# Validation Standard

## Core Philosophy

**Never trust self-reports. Require external evidence.**

When a builder agent says "I created 5 KQL queries," the SME assessor does not take that at face value. It runs `grep -c "EmailEvents" artifact.md` to count queries, uses `Glob` to verify file existence, and checks claim accuracy via WebSearch. Every validation must be backed by tool-based evidence.

## Five Principles

1. **Never trust agent self-reports** — require external evidence (test output, file existence, grep results)
2. **Exit conditions driven by external tools, not LLM assessment** — tests pass/fail, lints succeed, files exist
3. **Hard iteration limits** — `max_rounds_per_wave` as circuit breaker (see scope table)
4. **Agents have submission authority, NOT merge authority** — Tyler approves all final deliverables
5. **Clear context between phases** — file-based artifact passing, not token carry-over

## Validation by Work Type

### Research

| Check | Tool | Example |
|-------|------|---------|
| Sources exist | WebSearch | Search for "NIST SP 800-61" to confirm the publication is real |
| Claims are accurate | WebSearch + WebFetch | Verify that Proofpoint TAP actually exposes the cited API endpoints |
| Multiple sources | Read artifact | Confirm 3+ independent sources in the Sources Consulted table |
| Recency | WebSearch | Check publication dates are within acceptable range |

### Plans

| Check | Tool | Example |
|-------|------|---------|
| Research artifacts consumed | Read + Glob | Verify research artifact paths in the plan actually exist |
| Criteria are measurable | Read | Each acceptance criterion must be testable (not "make it good") |
| Steps are feasible | Read | Verify that plan references real tools and realistic approaches |
| TDD defined | Read | Plan must include test strategy section for code tasks |

### Code

| Check | Tool | Example |
|-------|------|---------|
| Tests pass | Bash | Run `pytest tests/` or equivalent test command |
| Files exist | Glob | Verify all output files at their declared paths |
| Imports resolve | Grep | Check that imported modules exist in the project |
| Function-to-test mapping | Read | Verify `test_map.txt` is updated with new functions |

### Documentation

| Check | Tool | Example |
|-------|------|---------|
| Linked files exist | Glob | Resolve every `[text](path)` link to a real file |
| Cross-refs resolve | Read | Open referenced files and verify they contain expected content |
| STATE.md accurate | Read | Compare STATE.md claims against actual file system state |
| Changelog present | Grep | Search for `## Changelog` section in artifact |

## RALPH Loops

The RALPH pattern (Research, Analyze, Locate, Propose, Handoff) guides how assessors structure their verification:

1. **Research**: Understand what the artifact claims to deliver
2. **Analyze**: Evaluate quality, completeness, and accuracy
3. **Locate**: Find external evidence for/against each claim
4. **Propose**: Draft verdict with specific gaps or confirmations
5. **Handoff**: Update STATE.md and return verdict to Morpheus

## Stripe Minions Principles

Inspired by Stripe's approach to AI agent validation:

- **Agents propose, humans decide** — Tyler has final merge authority on all deliverables
- **Validation at every boundary** — every agent-to-agent handoff includes assessment
- **Evidence over assertion** — tool output beats narrative claims
- **Circuit breakers prevent runaway** — max_rounds prevents infinite iteration

## TDAD Test Mapping

For code tasks, the plan defines tests **before** implementation (Test-Driven Agent Development):

1. Planner writes test cases in the plan's TDD section
2. Builder writes test files first (they should fail)
3. Builder implements the code
4. Builder runs tests (they should pass)
5. SME assessor independently runs the tests via Bash
6. `test_map.txt` maps every function to its test for targeted regression

## Validation Framework in STATE.md

At task inception, Morpheus writes a `## Validation Framework` section in STATE.md:

```markdown
## Validation Framework

### Acceptance Criteria
- [ ] Runbook follows NIST 4-phase structure
- [ ] Contains 5+ KQL detection queries
- [ ] Each query has MITRE ATT&CK mapping
- [ ] Escalation procedures reference SOC SLAs

### Per-Wave Validation
| Wave | Validation Approach | SME Role |
|------|-------------------|----------|
| 1 (Research) | Source verification, claim accuracy | SecOps Analyst |
| 2 (Planning) | Feasibility check, criteria measurability | Operations Expert |
| 3 (Build) | KQL syntax, content completeness, link integrity | SecOps + KQL Specialist |
| 4 (Docs) | Cross-ref resolution, changelog presence | QA Analyst |
```

This framework is defined once and referenced by every assessor for the duration of the task.
