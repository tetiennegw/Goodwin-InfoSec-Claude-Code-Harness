---
description: Dispatch sub-agents in waves for medium+ scope tasks — the core orchestration skill
user-invocable: true
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, TaskCreate, TaskUpdate, TaskList]
schema-version: 1
---
# Orchestration Dispatch

You are executing the wave/round orchestration loop. This is Morpheus's core execution skill.

**Task-list discipline applies throughout.** Every TaskCreate and TaskUpdate call made during wave/round execution follows `.claude/rules/task-handling.md` — naming standard, 3-level urgency model, dependency inference heuristics, non-cancellation invariant. As waves complete, TaskUpdate marks `in_progress` → `completed` for each wave task; do NOT mark tasks `cancelled` or `deleted` without Tyler's same-turn authorization. The Stop-event hook `.claude/hooks/task-discipline-audit.ps1` audits compliance and writes `TASKDISC:{PASS|SOFT|FAIL}` rows to `hub/state/harness-audit-ledger.md`.

## Step 0: Pre-execution STATE.md Sanity Check (HARD GATE)

Before reading or dispatching anything, validate the STATE.md contract. If any check fails, STOP with a BLOCKED response — do not proceed.

- [ ] `test -f hub/staging/{task-id}/STATE.md` — file exists
- [ ] Frontmatter has `schema-version: 2`
- [ ] Required frontmatter fields present: `task-id`, `scope`, `status`, `protocol`, `sub-protocol`, `current-wave`, `current-round`, `last-updated`, `planner-task-id`, `plan-approved-at`, `pending-decisions`, `blockers`, `verified-artifacts`, `resume-command`
- [ ] Required body sections present: `## Macro Goal`, `## Task Table`, `## Validation Framework`, `## Progress Summary`, `## Next Action`
- [ ] `## Next Action` is non-empty

If any FAIL, emit:
```
BLOCKED — STATE.md does not meet v2 contract:
- {specific gap 1}
- {specific gap 2}
Returning to /the-protocol for scaffolding correction.
```

This prevents orchestration from running on a half-scaffolded STATE.md — the silent-failure mode that let the 2026-04-21 Azure kickoff advance.

## Step 1: Read Current State
- Read the task's `STATE.md` at `hub/staging/{task-id}/STATE.md`.
- Identify: current wave, current round, macro goal, validation framework, next action.
- Read `hub/state/active-tasks.md` to confirm the task is tracked.

### Step 1a: Auto-Rescope Check (Small scope)

Only applies if STATE.md `scope: small`. At each loop iteration (start of each new round), evaluate:

- File-touch count (this task's staging dir + any directly referenced files outside staging): > 5?
- Tool-call count since task kickoff: > 20?
- Elapsed wall-clock since Phase 0 scaffold: > 45 minutes?
- New external-system call added since last round (Planner write, Graph, external API)?

If **ANY** of the four conditions is true, fire `AskUserQuestion`:

> "This Small task has exceeded typical scope boundaries ({triggered-condition}). Re-scope to Medium and re-enter `/the-protocol` Step 6 (plan mode), or continue at Small?"

Options: "Re-scope to Medium (Recommended)" / "Continue at Small" / "Other".

On re-scope: update STATE.md `scope: medium`, log the transition in Progress Summary with the trigger condition, and hand back to `/the-protocol` Step 6a. On continue-at-Small: log the override in Progress Summary so the scope-reclassification-rate metric can track it.

## Step 2: Dispatch Work Agent
Use the Work Agent Dispatch Template:

```
TASK: {what to do this round — derived from STATE.md next-action}
TASK_ID: {task-id}
STATE_FILE: {absolute path to STATE.md}
INDEX_FILE: {absolute path to INDEX.md}
INPUT FILES:
- {path}: {one-line description of each input}
OUTPUT:
- Write to: hub/staging/{task-id}/wave-{N}/round-{M}/{artifact-name}.{ext}
- Follow the artifact template for your agent type
- Include changelog entry
CONSTRAINTS:
- Read STATE.md first for macro context
- Consult INDEX.md for file discovery
- Return 6-10 sentence summary
- Do not spawn sub-agents
```

Select the appropriate agent based on wave type:
- Research wave -> `gatherer` agent (`.claude/agents/gatherer.md`)
- Planning wave -> `planner` agent (`.claude/agents/planner.md`)
- Build wave -> `builder` agent (`.claude/agents/builder.md`)
- Documentation wave -> `documenter` agent (`.claude/agents/documenter.md`)

## Step 3: Dispatch SME Assessor
After the work agent returns, dispatch the dynamic SME assessor:

```
ROLE: You are a {DOMAIN_SME_TITLE} with deep expertise in {DOMAIN_DESCRIPTION}.
Also acting as a {SUBDOMAIN_SME_TITLE} specializing in {SUBDOMAIN_DESCRIPTION}.

Assess round {M} of wave {wave-name}.
TASK_ID: {task-id}
STATE_FILE: {absolute path to STATE.md}
ROUND_OUTPUT: {path to this round's artifact}
SCOPE: {scope} — round range for this wave: {range}

VALIDATION CRITERIA:
{Copied from STATE.md ## Validation Framework section}
```

Use agent file: `.claude/agents/sme-assessor.md`

## Step 4: Read Verdict and Act
Read the SME assessor's verdict from STATE.md:

| Verdict | Action |
|---------|--------|
| **ADVANCE** | Move to next wave. Update `current-wave` in STATE.md. Call `TaskUpdate` for completed items. |
| **CONTINUE** | Increment round. Dispatch next work agent round with SME feedback incorporated. |
| **FLAG** | Pause execution. Surface the issue to Tyler with the SME's explanation. Wait for Tyler's decision. |
| **FAIL** | Retry once with a different approach. If second attempt also fails, escalate to Tyler. |

## Step 5: Update State
- Update STATE.md progress summary with wave/round results.
- Update `TaskUpdate` for any completed task items.
- If wave completed, check if more waves remain. If all waves done, proceed to documentation wave.

## Rules
- NEVER dispatch two SME assessors in parallel (STATE.md write conflict).
- NEVER do work directly — always dispatch a sub-agent.
- Compact completed waves after 3+ are done (collapse to one-line summaries in STATE.md).
- Re-read STATE.md from disk before each dispatch — do not rely on cached context.
- Max rounds per wave are defined by the scope table in CLAUDE.md.
