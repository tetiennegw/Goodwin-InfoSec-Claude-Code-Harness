---
title: "Artifact Templates"
last-updated: 2026-04-08
related-files: [hub/templates/research-artifact.md, hub/templates/plan-artifact.md, hub/templates/build-artifact.md, hub/templates/assessment-artifact.md, hub/templates/verification-artifact.md, hub/templates/doc-update-artifact.md]
---

# Artifact Templates

All agent outputs follow structured templates stored in `hub/templates/`. Every template requires YAML frontmatter and a Changelog section.

## Template Summary

| Template | Agent | File | When Used |
|----------|-------|------|-----------|
| Research Artifact | gatherer | `hub/templates/research-artifact.md` | Wave 1 (Research) |
| Plan Artifact | planner | `hub/templates/plan-artifact.md` | Wave 2 (Planning) |
| Build Artifact | builder | `hub/templates/build-artifact.md` | Wave 3+ (Build) |
| Assessment Artifact | sme-assessor | `hub/templates/assessment-artifact.md` | After every round |
| Verification Artifact | verifier | `hub/templates/verification-artifact.md` | Verification wave (large/ultra) |
| Doc-Update Artifact | documenter | `hub/templates/doc-update-artifact.md` | Final wave (Documentation) |

## 1. Research Artifact

**Produced by**: gatherer

**Required sections**:
- **Frontmatter**: type: research, task-id, agent, created, last-updated, inputs
- **Sources Consulted**: Table with source, type, accessed date, relevance rating
- **Findings**: Numbered findings, each with evidence citations
- **Key Takeaways**: Top 3-5 insights ranked by relevance to macro goal
- **Gaps Identified**: What could not be determined, with recommendations
- **Relevance to Macro Goal**: How this research connects to the task objective
- **Changelog**

**Example**: A research artifact for the phishing runbook would list NIST SP 800-61, SANS IR handbook, and Cofense 2025 report as sources, with findings about the 4-phase IR model, Proofpoint TAP API endpoints, and Sentinel KQL table schemas.

## 2. Plan Artifact

**Produced by**: planner

**Required sections**:
- **Frontmatter**: type: plan, task-id, agent, created, last-updated, inputs
- **Objective**: 2-3 sentences relayed to Tyler for confirmation
- **Research References**: Table linking research artifacts to key insights
- **Existing Codebase References**: Reusable files/modules found via INDEX.md
- **Acceptance Criteria**: Measurable checkboxes
- **Test Strategy / TDD**: Tests to write first, framework, how to run
- **Build Path**: Numbered tasks with subtasks, inputs, outputs, and per-task validation
- **Risks & Mitigations**: Table with likelihood, impact, and mitigation strategy
- **Output Files**: Final destination paths for all deliverables
- **Changelog**

**Example**: A plan for the phishing runbook includes 5 build tasks, 4 TDD validation tests (KQL syntax, cross-reference integrity, section completeness, MITRE mapping), and 3 identified risks.

## 3. Build Artifact

**Produced by**: builder

Two variants depending on deliverable type:

### Variant A: Markdown Deliverable (runbooks, KB articles, docs)
- **Frontmatter**: type: deliverable, task-id, agent, created, last-updated, inputs, plan-step
- Content per plan specification
- **Changelog**

### Variant B: Code File (scripts, queries, configs)
- **Comment header block**: Task, agent, created, last-updated, plan reference, purpose, changelog
- Code content per plan specification

## 4. Assessment Artifact

**Produced by**: sme-assessor

**Required sections**:
- **Frontmatter**: type: assessment, task-id, agent (SME persona), created, assessed-artifact, verdict
- **Evaluation Summary**: 2-3 sentence overview of what was assessed
- **Domain-Specific Checks**: Table with criterion, result (PASS/PARTIAL/FAIL), evidence
- **External Evidence Collected**: Table with tool used, what was verified, result
- **Issues Found**: Critical and minor issues with specific descriptions
- **STATE.md Updates Applied**: What was changed in STATE.md
- **Verdict**: ADVANCE, CONTINUE, FLAG, or FAIL with detailed justification
- **Changelog**

## 5. Verification Artifact

**Produced by**: verifier

**Required sections**:
- **Frontmatter**: type: verification, task-id, agent, created, confidence (0-100), deliverables-verified
- **Claims Checked**: Table with claim, verdict (confirmed/disputed/unverifiable), evidence
- **Factual Accuracy**: Score and narrative assessment
- **Logical Soundness**: Assessment of internal consistency
- **Security Review**: Credential exposure, data handling, privilege scope
- **Overall Confidence**: Percentage with explanation
- **Changelog**

**Key difference from assessment**: The verifier is blind to plans and prior reviews. It checks "are the facts correct?" independently.

## 6. Doc-Update Artifact

**Produced by**: documenter

**Required sections**:
- **Frontmatter**: type: doc-update, task-id, agent, created, files-updated, files-created
- **Daily Note Entry Added**: File path and entry content
- **INDEX.md Updates**: Entries added
- **Knowledge Base Updates**: Files created or modified in KB
- **State Updates**: Changes to active-tasks.md, completed-tasks.md, STATE.md
- **Cross-References Added**: Table of source, target, and reference type
- **Changelog**

## Common Requirements

All artifacts share these requirements:
1. **YAML frontmatter** with at minimum: type, task-id, agent, created, last-updated
2. **Changelog section** at the bottom (max 10 entries, newest first)
3. **Descriptive filename**: `research-{topic-slug}.md`, not `output.md`
4. **Written to the OUTPUT path** specified in the dispatch prompt
