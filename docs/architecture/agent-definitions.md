---
title: "Agent Definitions"
last-updated: 2026-04-08
related-files: [.claude/agents/gatherer.md, .claude/agents/planner.md, .claude/agents/builder.md, .claude/agents/verifier.md, .claude/agents/documenter.md, .claude/agents/sme-assessor.md]
---

# Agent Definitions

Morpheus has 6 agent types. Each has a definition file in `.claude/agents/` with YAML frontmatter specifying name, description, allowed tools, and model.

## Agent Overview

| Agent | Role | Model | Tools | Typical Wave |
|-------|------|-------|-------|-------------|
| **gatherer** | Research + information gathering | sonnet | Glob, Grep, Read, Bash, WebSearch, WebFetch | 1 (Research) |
| **planner** | Structured planning with TDD | opus | Glob, Grep, Read, Bash | 2 (Planning) |
| **builder** | Produces deliverables | sonnet/opus | Glob, Grep, Read, Bash, WebSearch, WebFetch | 3+ (Build) |
| **verifier** | Independent fact-checking (blind to plan) | opus | Glob, Grep, Read, Bash, WebSearch, WebFetch | 4 (Verification) |
| **documenter** | Updates notes, KB, INDEX.md, state | sonnet | Glob, Grep, Read, Bash | Final wave |
| **sme-assessor** | Dynamic SME validation | opus | Glob, Grep, Read, Bash, WebSearch, WebFetch | After every round |

## Gatherer

**File**: `.claude/agents/gatherer.md`

**Purpose**: Researches a topic by searching local files (Glob, Grep, Read), the web (WebSearch, WebFetch), and synthesizing findings into a structured research artifact.

**Input**: TASK, TASK_ID, STATE_FILE, INDEX_FILE, INPUT FILES, OUTPUT path

**Output**: A markdown file at OUTPUT path following `hub/templates/research-artifact.md`:
- Sources Consulted table (source, type, accessed date, relevance)
- Findings with evidence
- Key Takeaways (top 3-5)
- Gaps Identified
- Relevance to Macro Goal

**Returns to Morpheus**: 6-10 sentence summary. Example:
> "Researched phishing detection frameworks across 3 industry sources and 2 internal files. Key finding: NIST recommends a 4-phase triage model. Gap: could not determine current SOC shift structure. Full research written to hub/staging/.../research-phishing-frameworks.md."

## Planner

**File**: `.claude/agents/planner.md`

**Purpose**: Reads research artifacts and produces a prescriptive implementation plan that a builder can execute without asking questions.

**Input**: TASK, TASK_ID, STATE_FILE, INDEX_FILE, RESEARCH_FILES, OUTPUT path

**Output**: A plan artifact following `hub/templates/plan-artifact.md`:
- Objective (relayed to Tyler for confirmation)
- Research References
- Acceptance Criteria (measurable checkboxes)
- Test Strategy / TDD
- Build Path (tasks with subtasks, inputs, outputs, per-task validation)
- Risks & Mitigations
- Output Files

**Returns to Morpheus**: 6-10 sentence summary covering objective, approach, key decisions.

## Builder

**File**: `.claude/agents/builder.md`

**Purpose**: Follows a plan precisely to produce deliverables (documents, scripts, configs). Uses TDD where the plan specifies.

**Input**: TASK, TASK_ID, STATE_FILE, INDEX_FILE, PLAN_FILE, OUTPUT_PATHS

**Output**: Deliverable files at the paths specified in the plan. Markdown deliverables get frontmatter + changelog. Code files get comment header blocks.

**Returns to Morpheus**: 6-10 sentence summary — what was built, which plan tasks completed, test results, output paths.

## Verifier

**File**: `.claude/agents/verifier.md`

**Purpose**: Independently verifies deliverables without reading plans or prior assessments. Checks facts against reality.

**Key distinction from SME assessor**: The verifier is **blind to the plan**. It evaluates "are the facts correct?" while the assessor evaluates "did we follow the plan?"

**Input**: TASK, TASK_ID, STATE_FILE (validation criteria only), DELIVERABLE_FILES, VERIFICATION_FOCUS, OUTPUT path

**Output**: A verification artifact following `hub/templates/verification-artifact.md`:
- Claims Checked (claim, verdict: confirmed/disputed/unverifiable, evidence)
- Factual Accuracy score
- Logical Soundness assessment
- Security Review
- Overall Confidence percentage

**Returns to Morpheus**: `VERIFIED (N%)` or `DISPUTES FOUND (N%)` + 6-10 sentence summary.

**When used**: Required for large and ultra scope. Optional for medium. Never for mini/small.

## Documenter

**File**: `.claude/agents/documenter.md`

**Purpose**: After task completion, updates all documentation artifacts: daily notes, INDEX.md, knowledge base, state files.

**Input**: TASK_SUMMARY, TASK_ID, STATE_FILE, INDEX_FILE, ARTIFACT_FILES, DELIVERABLE_FILES, FINAL_LOCATIONS, TODAY, OUTPUT path, DAILY_NOTE path

**Output**: A doc-update artifact following `hub/templates/doc-update-artifact.md`:
- Daily Note Entry Added
- INDEX.md Updates
- Knowledge Base Updates
- State Updates
- Cross-References Added

**Returns to Morpheus**: 6-10 sentence summary listing all files updated.

## SME Assessor (Dynamic)

**File**: `.claude/agents/sme-assessor.md`

**Purpose**: Assesses work quality using domain expertise. The agent definition is a **template** — Morpheus fills in `{PERSONA}` and `{DOMAIN_CRITERIA}` at dispatch time.

### How Dynamic Parameterization Works

The sme-assessor.md file contains placeholders:

```markdown
You are **{PERSONA}** — a subject matter expert...

## Your Domain Criteria
{DOMAIN_CRITERIA}
```

At dispatch, Morpheus replaces these:

```
ROLE: You are a Senior Security Operations Analyst with deep expertise
in SOC workflows and threat detection.
Also acting as an Azure Sentinel Specialist specializing in KQL query
optimization and Sentinel workbook design.

DOMAIN_CRITERIA:
1. Are detection rules aligned with MITRE ATT&CK techniques?
2. Are KQL queries syntactically valid and optimized?
3. Do alert thresholds avoid false positive floods?
4. Is the triage workflow achievable within SOC response SLAs?
```

### Verdict Rules

| Verdict | Meaning | What happens next |
|---------|---------|-------------------|
| **ADVANCE** | Work meets all criteria with external evidence | Next wave begins |
| **CONTINUE** | Specific gaps identified | Same wave, next round with feedback |
| **FLAG** | Decision point requiring Tyler's input | Morpheus pauses and asks Tyler |
| **FAIL** | Fundamentally wrong or off-track | Retry with different approach or escalate |

### Assessment Protocol

1. Read STATE.md for macro goal and validation criteria
2. Read the artifact being assessed thoroughly
3. Apply domain criteria (check each one)
4. Apply task validation criteria from STATE.md
5. Verify externally using tools — cite specific evidence
6. Back up STATE.md to STATE.md.bak
7. Update STATE.md with results
8. Write assessment to OUTPUT path
9. Return verdict + 4-6 sentence explanation
