---
globs: hub/**
schema-version: 1
---

# Morpheus Orchestration Protocol

This rule is auto-loaded for all `hub/**` paths. It defines the complete orchestration protocol, dispatch templates, validation standards, and artifact conventions.

---

## Interaction Mandates

1. **`/the-protocol` is the sole entry point for non-Passthrough tasks.** Scope assessment, skill evaluation, clarifying questions, plan mode, and scaffolding all happen inside the protocol run — not in hooks, not in ad-hoc prose, not pre-batched before invocation. No other skill or hook makes these decisions.
2. **AskUserQuestion for all clarifications** — Never ask questions via inline text. Always use the AskUserQuestion tool so the user gets a proper prompt with selectable options. For Medium+, clarifications fire INSIDE plan mode (Step 6c of `/the-protocol`), not before.
3. **EnterPlanMode for Medium+ tasks — mandatory, enforceable.** For Medium, Large, or Ultra scope, `/the-protocol` Step 6a calls `EnterPlanMode` BEFORE any clarifying questions, context gathering, or scaffolding. Self-justified skips are protocol violations and MUST be logged to `hub/state/harness-audit-ledger.md`. The only legitimate exception is explicit Tyler authorization, which itself must be logged.
4. **Task-list discipline per `.claude/rules/task-handling.md`.** Meta-work is task-worthy (Step 0.5 of `/the-protocol` creates M0/M1/M2 meta-tasks); every TaskCreate carries a 3-level urgency assignment (`immediate`/`sequenced`/`deferred`); tasks are non-cancellable without Tyler's same-turn authorization. Enforcement: `.claude/hooks/task-discipline-audit.ps1` (Stop-event, audit-only, writes `TASKDISC:{PASS|SOFT|FAIL}` rows to the ledger).

---

## Implementation Plan Standard

All plans produced by the planner agent MUST follow the 16-section standard defined in `.claude/rules/implementation-plan-standard.md`. The standard is automatically loaded into context when `EnterPlanMode` fires (via PreToolUse hook at `.claude/hooks/plan-mode-context.sh`).

Key sections beyond the original template:
- **Intent** — WHY the task exists (Phase 0 output, captured before any build work)
- **Task List with Dependencies** — explicit task inventory with blockedBy and interleaved VERIFY/CHECKPOINT tasks
- **Three-Tier Verification Gates** — cascading build/lint → unit → E2E gates per phase
- **EODIC Acceptance Criteria** — each criterion must be Executable, Observable, Deterministic, Independent, Cumulative
- **DIAGNOSE-FIX-RETRY** — 3-attempt escalation before Tyler involvement
- **Agent Return Protocol** — structured completion with INTENT ALIGNMENT check

Scope gating applies: small-scope plans may omit sections marked optional/skip for their scope. See the gating table in the standard.

---

## Orchestration Loop (Wave/Round)

Morpheus executes tasks in **waves**. Each wave has one or more **rounds**.

```
FOR each wave in task:
  round = 1
  WHILE round <= max_rounds_for_scope:
    1. Dispatch WORK AGENT with dispatch template
    2. Work agent writes artifact to hub/staging/{task-id}/
    3. Dispatch SME ASSESSOR with assessment template
    4. SME assessor reads artifact, verifies externally, updates STATE.md
    5. Read verdict from SME:
       - ADVANCE  → break inner loop, move to next wave
       - CONTINUE → round += 1, iterate with SME feedback
       - FLAG     → pause, surface to Tyler for decision
       - FAIL     → retry with different approach or escalate
  END WHILE
  IF max_rounds exceeded → FLAG to Tyler
END FOR
```

**Critical rules:**
- NEVER dispatch two SME assessors in parallel (STATE.md write conflict)
- NEVER do work directly -- always dispatch a sub-agent
- Compact completed waves after 3+ are done (collapse to one-line summaries)
- Re-read STATE.md from disk if you need past context

**Pre-execution gate (HARD REQUIREMENT — applies to ALL non-passthrough work):**

Scaffolding is a **post-approval step for Medium+**. It runs AFTER Tyler approves the orchestration plan via `ExitPlanMode`, not before. For Small/Mini, it runs after Step 6 clarifications complete (no plan mode required).

Sequence:

1. `/the-protocol` Step 6: EnterPlanMode → gather context → AskUserQuestion clarify → present orchestration plan → ExitPlanMode (Tyler approves)
2. `/the-protocol` Step 7: **Create staging directory**: `hub/staging/{task-id}/`
3. Step 7: **Create STATE.md** (schema-version: 2) with frontmatter (task-id, scope, status, protocol, sub-protocol, current-wave, current-round, created, last-updated, planner-task-id, plan-approved-at, pending-decisions, blockers, verified-artifacts, resume-command) + macro goal + validation framework
4. Step 7: **Create TaskCreate entries**: full task list from plan section 8a with dependencies from 8b
5. Step 7.5: **Create Planner task** (Large/Ultra only, idempotent by task-id slug)
6. Step 7: **Log to daily note**: timeline entry documenting work start (per `.claude/rules/daily-note.md`)
7. Step 8: **Pre-handoff gate** — verify all of the above before invoking `/orchestration-dispatch`; audit-ledger entry (pass or fail)

**Creating any durable side effect (staging dir, STATE.md, Planner task, TaskCreate entries, daily-note entry) before plan approval on Medium+ is a protocol violation.** If detected mid-session, the orchestrator MUST pause, log the violation to `hub/state/harness-audit-ledger.md`, roll back (rm the premature staging dir), and restart from Step 6.

**This gate applies even when Morpheus executes directly** (plan-mode work, interactive skill workflows, in-session builds). The "pure orchestrator" exception for interactive skills does NOT exempt plan-first sequencing.

**Post-phase gate (HARD REQUIREMENT — after every phase/wave):**

After each phase completes, before advancing to the next:

1. **Update STATE.md**: Progress Summary, current-wave, current-round, last-updated, Next Action
2. **Update TaskUpdate**: mark completed phase tasks as `completed`
3. **Log to daily note**: if the phase produced significant deliverables, prepend a timeline entry

---

## STATE.md Update Mandate

STATE.md is the single source of truth for every task. It MUST be updated:

1. **Before work begins** -- created during Phase 0 Scaffold (pre-execution gate)
2. **After every work agent round** -- SME assessor updates progress, artifacts, open items
3. **After every wave/phase completion** -- mark wave as done, update current-wave, current-round, last-updated
4. **After every assessor verdict** -- record verdict, update next-action
5. **On any status change** -- in-progress, blocked, flagged, completed
6. **On cross-session resume** -- verify STATE.md matches reality before continuing
7. **After plan-mode direct execution** -- if the orchestrator executes work in-session (interactive skills, plan-mode builds), STATE.md must be updated as if a sub-agent had done it

**STATE.md updates trigger active-tasks.md regeneration** via PostToolUse hook. This means updating STATE.md automatically keeps the cross-session task index current — no manual active-tasks.md edits needed.

**Good example:**
```markdown
## Progress Summary
- Wave 1 (Research): COMPLETE - Gatherer produced 3 research artifacts covering KQL, Sentinel, and SOAR. SME verified all sources. [2026-04-07T14:30]
- Wave 2 (Plan): Round 1 - Planner produced plan artifact. Awaiting SME assessment. [2026-04-07T15:00]
```

**Bad example:**
```markdown
## Progress Summary
- Did some research
- Working on planning now
```
The bad example lacks timestamps, wave labels, artifact references, and status markers.

---

## Work Agent Dispatch Template

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
- Include changelog entry in artifact (see Changelog Standard below)
CONSTRAINTS:
- Read STATE.md first to understand the macro goal and current progress
- Consult INDEX.md when you need to find existing files
- Write output to specified path using the required artifact format
- Return a 6-10 sentence summary (what you did, key findings/outputs, any issues)
- Do not spawn sub-agents
```

---

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
3. Verify against the task's validation criteria -- require EXTERNAL EVIDENCE for every claim
   (file existence checks, grep for specific content, web verification for factual claims)
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
- NEVER trust self-reported success -- verify via tool use (Read file, Glob, Grep, Bash)
- Do not rubber-stamp -- weak output gets CONTINUE with specific gaps
- For code: run tests/lint if available; check file existence; verify imports resolve
- For research: verify sources exist (WebSearch); check claim accuracy
- For docs: verify all linked files exist (Glob); check cross-refs
- Update STATE.md accurately -- all agents depend on it
```

### How Morpheus Defines PERSONA + DOMAIN_CRITERIA

At task inception, Morpheus determines the domain expertise needed and writes it into STATE.md under `## Validation Framework`. When dispatching the generic `sme-assessor` agent:

1. **PERSONA**: A natural-language description of who the SME is (e.g., "Senior Security Engineer with 10+ years in SIEM/SOAR platforms")
2. **DOMAIN_CRITERIA**: Specific checklist items the SME must verify, drawn from the task's acceptance criteria and domain best practices

**Good example:**
```
ROLE: You are a Senior Security Analyst with deep expertise in Microsoft Sentinel and KQL.
Also acting as an Incident Response Specialist specializing in phishing detection playbooks.

VALIDATION CRITERIA:
- KQL queries must parse without syntax errors (run in Bash with mock if possible)
- Detection logic must cover: sender reputation, URL analysis, attachment hashing
- Playbook steps must reference real Sentinel entity types
- All external tool references must be tools available in the Goodwin environment
```

**Bad example:**
```
ROLE: You are an expert. Check if the work looks good.
```

---

## Validation Standard

### Core Principles
1. **NEVER trust agent self-reports** -- require external evidence (test output, file existence, grep results)
2. **Exit conditions driven by external tools, not LLM assessment** -- tests pass/fail, lints succeed, files exist
3. **Hard iteration limits** -- max_rounds_per_wave as circuit breaker (see scope table in CLAUDE.md)
4. **Agents have submission authority, NOT merge authority** -- Tyler approves all final deliverables
5. **Clear context between phases** -- use file-based artifact passing, not token carry-over

### Validation by Work Type

| Work Type | Validation Method |
|-----------|------------------|
| Research | Verify sources exist (WebSearch), check claim accuracy, cross-reference multiple sources, check recency |
| Plans | Verify research artifacts exist and were consumed, check acceptance criteria are measurable, verify step feasibility |
| Code | TDD: tests before implementation, run tests via Bash, check file existence, verify imports, use test_map.txt for function-to-test mapping |
| Documentation | Verify all linked files exist (Glob), check cross-refs resolve, validate STATE.md accuracy |

### Validation Criteria at Project Inception
During wave 0, Morpheus defines in STATE.md `## Validation Framework`:
- Specific, measurable acceptance criteria for the entire task
- Per-wave validation approach (what gets tested how)
- SME roles for each wave (domain + subdomain)
- For code tasks: test strategy (unit, integration, E2E)

---

## Changelog Standard

All artifacts in `hub/**` MUST include a changelog. Maximum 10 entries, newest first.

### Format for Markdown Artifacts

Include YAML frontmatter:
```yaml
---
type: {type}
task-id: {task-id}
agent: {agent-type}
created: {ISO timestamp}
last-updated: {ISO timestamp}
inputs: [{files consumed}]
---
```

Plus a `## Changelog` section:
```markdown
## Changelog
| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-07T15:45 | 2026-04-07-phishing-runbook | security-sme | Added detection logic per assessment |
| 2026-04-07T15:30 | 2026-04-07-phishing-runbook | builder | Created initial runbook draft |
```

### Format for Code Files

```python
# ============================================================
# Task: {task-id}
# Agent: {agent-type}
# Created: {ISO timestamp}
# Last-Updated: {ISO timestamp}
# Plan: {plan file path}
# Purpose: {description}
# Changelog (max 10):
#   2026-04-07T15:30 | {project} | {agent} | Created initial script
#   2026-04-07T16:00 | {project} | {agent} | Fixed input validation per review
# ============================================================
```

### Enforcement
- SME assessors check changelog presence and accuracy as part of validation
- Missing or stale changelogs result in CONTINUE verdict, not ADVANCE

---

## Artifact Conventions

### Frontmatter Requirements
Every markdown artifact in `hub/staging/` MUST have YAML frontmatter with at minimum:
- `type`: research | plan | build | assessment | documentation
- `task-id`: matches the staging directory name
- `agent`: which agent type produced it
- `created`: ISO timestamp
- `last-updated`: ISO timestamp

### File Naming in Staging Directories
```
hub/staging/{task-id}/
  STATE.md                           # Living state document
  STATE.md.bak                       # Backup before SME updates
  research-{topic-slug}.md           # Gatherer output
  plan-{deliverable-slug}.md         # Planner output
  build-{deliverable-slug}.{ext}     # Builder output
  assessment-w{N}r{N}.md             # SME assessor output
  docs-{topic-slug}.md               # Documenter output
```

**Good example:** `research-sentinel-kql-best-practices.md`
**Bad example:** `output.md`, `file1.md`, `notes.md`

---

## Cross-Session State

### active-tasks.md (`hub/state/active-tasks.md`)
Lists all in-progress tasks with their STATE.md paths. Morpheus reads this at session start to resume work.

```markdown
| Task ID | Status | STATE.md Path | Last Updated |
|---------|--------|---------------|--------------|
| 2026-04-07-phishing-runbook | wave-3 | hub/staging/2026-04-07-phishing-runbook/STATE.md | 2026-04-07T16:00 |
```

### completed-tasks.md (`hub/state/completed-tasks.md`)
Archive of finished tasks. Moved from active-tasks.md when task completes.

```markdown
| Task ID | Completed | Summary | Key Artifacts |
|---------|-----------|---------|---------------|
| 2026-04-07-setup | 2026-04-07T12:00 | Initial system setup | hub/staging/2026-04-07-setup/STATE.md |
```

### Cross-Session Resume Protocol
1. Read `hub/state/active-tasks.md` to find in-progress tasks
2. For each active task, read its `STATE.md` to understand current state
3. Resume from the last recorded next-action in STATE.md
4. If STATE.md seems stale, verify artifact existence before continuing
