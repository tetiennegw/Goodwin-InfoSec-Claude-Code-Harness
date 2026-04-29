---
title: "Dispatch Templates"
last-updated: 2026-04-08
related-files: [.claude/rules/hub.md, .claude/agents/gatherer.md, .claude/agents/planner.md, .claude/agents/builder.md, .claude/agents/sme-assessor.md]
---

# Dispatch Templates

These are the exact prompt templates Morpheus uses when dispatching sub-agents. Copy and customize for your own use.

## Work Agent Dispatch Template (Generic)

Used for gatherer, planner, builder, and documenter.

```
TASK: {what to do this round}
TASK_ID: {task-id}
STATE_FILE: {absolute path to STATE.md} -- read this first for macro context
INDEX_FILE: {absolute path to INDEX.md} -- consult this to find relevant existing files
INPUT FILES:
- {path}: {one-line description}
OUTPUT:
- Write to: {absolute output path}
- Follow the artifact template for your agent type (defined in your agent file)
- Include changelog entry in artifact (see Changelog Standard)
CONSTRAINTS:
- Read STATE.md first to understand the macro goal and current progress
- Consult INDEX.md when you need to find existing files
- Write output to specified path using the required artifact format
- Return a 6-10 sentence summary (what you did, key findings/outputs, any issues)
- Do not spawn sub-agents
```

## Gatherer Dispatch — Filled Example

```
TASK: Research phishing detection frameworks, Goodwin's email security stack
(Proofpoint TAP + Sentinel), and industry best practices for SOC phishing
triage runbooks.
TASK_ID: 2026-04-08-phishing-runbook
STATE_FILE: {{paths.home}}/Documents/TE GW Brain/hub/staging/2026-04-08-phishing-runbook/STATE.md
INDEX_FILE: {{paths.home}}/Documents/TE GW Brain/INDEX.md
INPUT FILES:
- memory/company_context.md: Goodwin security stack and environment info
OUTPUT:
- Write to: {{paths.home}}/Documents/TE GW Brain/hub/staging/2026-04-08-phishing-runbook/research-phishing-frameworks.md
- Follow hub/templates/research-artifact.md format
- Include changelog entry
CONSTRAINTS:
- Read STATE.md first for macro goal
- Consult INDEX.md for existing security KB articles
- Search locally first (Glob, Grep), then web (WebSearch, WebFetch)
- Return 6-10 sentence summary
- Do not spawn sub-agents
```

## Planner Dispatch — Filled Example

```
TASK: Create a detailed build plan for the phishing triage runbook, including
TDD strategy, acceptance criteria, and step-by-step build path.
TASK_ID: 2026-04-08-phishing-runbook
STATE_FILE: {{paths.home}}/Documents/TE GW Brain/hub/staging/2026-04-08-phishing-runbook/STATE.md
INDEX_FILE: {{paths.home}}/Documents/TE GW Brain/INDEX.md
INPUT FILES:
- hub/staging/2026-04-08-phishing-runbook/research-phishing-frameworks.md: Research findings on phishing frameworks and Goodwin stack
OUTPUT:
- Write to: {{paths.home}}/Documents/TE GW Brain/hub/staging/2026-04-08-phishing-runbook/plan-phishing-runbook.md
- Follow hub/templates/plan-artifact.md format
- Include changelog entry
CONSTRAINTS:
- Read STATE.md first
- Plans must be PRESCRIPTIVE -- builder must execute without questions
- Include Objective section (relayed to Tyler)
- Include TDD section with tests defined before build
- Return 6-10 sentence summary
- Do not spawn sub-agents
```

## Builder Dispatch — Filled Example

```
TASK: Build the phishing triage runbook per plan tasks 1-3 (skeleton,
detection queries, triage decision tree).
TASK_ID: 2026-04-08-phishing-runbook
STATE_FILE: {{paths.home}}/Documents/TE GW Brain/hub/staging/2026-04-08-phishing-runbook/STATE.md
INDEX_FILE: {{paths.home}}/Documents/TE GW Brain/INDEX.md
INPUT FILES:
- hub/staging/2026-04-08-phishing-runbook/plan-phishing-runbook.md: Build plan with 5 tasks
- hub/staging/2026-04-08-phishing-runbook/research-phishing-frameworks.md: Research findings
OUTPUT:
- Write to: {{paths.home}}/Documents/TE GW Brain/kb/runbooks/phishing-triage-runbook.md
- Follow plan's Build Path tasks in order
- Include changelog entry
CONSTRAINTS:
- Read STATE.md first
- Follow the plan precisely -- do not freelance
- Write tests BEFORE implementation where plan specifies TDD
- Return 6-10 sentence summary
- Do not spawn sub-agents
```

## Dynamic SME Assessor Dispatch Template

```
ROLE: You are a {DOMAIN_SME_TITLE} with deep expertise in {DOMAIN_DESCRIPTION}.
Also acting as a {SUBDOMAIN_SME_TITLE} specializing in {SUBDOMAIN_DESCRIPTION}.

Assess round {N} of wave {wave-name}.
TASK_ID: {task-id}
STATE_FILE: {absolute path to STATE.md} -- read AND update this file
ROUND_OUTPUT: {path to this round's artifact}
SCOPE: {scope} -- round range for this wave: {range}

VALIDATION CRITERIA (from STATE.md):
{Copied from STATE.md ## Validation Framework section}

YOUR JOB:
1. Read STATE.md for macro goal, progress, and validation criteria
2. Read the round's output artifact thoroughly
3. Verify against the task's validation criteria -- require EXTERNAL EVIDENCE
   for every claim (file existence checks, grep for specific content, web
   verification for factual claims)
   DO NOT accept agent self-reports at face value
4. Back up STATE.md to STATE.md.bak before updating
5. Update STATE.md:
   - Progress Summary: add this round's assessed results
   - Artifacts Produced: add new artifact paths
   - Estimated rounds: update remaining for this wave
   - Open Items: add new questions/blockers found
   - Next Action: what should happen next
6. Return verdict: ADVANCE | CONTINUE | FLAG | FAIL + 4-6 sentence explanation

CONSTRAINTS:
- NEVER trust self-reported success -- verify via tool use
- Do not rubber-stamp -- weak output gets CONTINUE with specific gaps
- Update STATE.md accurately -- all agents depend on it
```

## SME Assessor Dispatch — Filled Example

```
ROLE: You are a Senior Security Operations Analyst with deep expertise in
SOC workflows and threat detection.
Also acting as an Azure Sentinel Specialist specializing in KQL query
optimization and Sentinel workbook design.

Assess round 1 of wave 3 (Build).
TASK_ID: 2026-04-08-phishing-runbook
STATE_FILE: {{paths.home}}/Documents/TE GW Brain/hub/staging/2026-04-08-phishing-runbook/STATE.md
ROUND_OUTPUT: {{paths.home}}/Documents/TE GW Brain/kb/runbooks/phishing-triage-runbook.md
SCOPE: medium -- round range for this wave: 1-3

VALIDATION CRITERIA (from STATE.md):
- Runbook follows NIST 4-phase structure
- Contains 5+ KQL detection queries targeting EmailEvents
- Each query has MITRE ATT&CK mapping and severity level
- Triage decision tree covers user-reported, automated, executive targeting
- Escalation procedures reference Goodwin SOC SLAs (15-min initial triage)
- All cross-references resolve to existing files
- Changelog section present

YOUR JOB:
1. Read STATE.md for macro goal and progress
2. Read the runbook thoroughly
3. Verify each criterion with external evidence:
   - Grep for NIST phase headers
   - Count KQL queries via grep
   - Verify MITRE technique IDs via WebSearch
   - Check cross-ref file paths via Glob
4. Back up STATE.md, then update it
5. Return verdict + 4-6 sentence explanation
```

## Documenter Dispatch — Filled Example

```
TASK: Update all documentation for completed phishing runbook task.
TASK_SUMMARY: Built a Sentinel-integrated phishing triage runbook with 5 KQL
queries, NIST 4-phase structure, and SOC triage procedures.
TASK_ID: 2026-04-08-phishing-runbook
STATE_FILE: {{paths.home}}/Documents/TE GW Brain/hub/staging/2026-04-08-phishing-runbook/STATE.md
INDEX_FILE: {{paths.home}}/Documents/TE GW Brain/INDEX.md
ARTIFACT_FILES:
- hub/staging/2026-04-08-phishing-runbook/research-phishing-frameworks.md
- hub/staging/2026-04-08-phishing-runbook/plan-phishing-runbook.md
DELIVERABLE_FILES:
- kb/runbooks/phishing-triage-runbook.md
- kb/security/kql-phishing-queries.md
FINAL_LOCATIONS:
- kb/runbooks/phishing-triage-runbook.md
- kb/security/kql-phishing-queries.md
TODAY: 2026-04-08
OUTPUT: {{paths.home}}/Documents/TE GW Brain/hub/staging/2026-04-08-phishing-runbook/doc-update-log.md
DAILY_NOTE: {{paths.home}}/Documents/TE GW Brain/notes/2026/04/2026-04-08.md
CONSTRAINTS:
- Update daily note with timeline entry
- Update INDEX.md with new files
- Move task from active-tasks.md to completed-tasks.md
- Return 6-10 sentence summary
```
