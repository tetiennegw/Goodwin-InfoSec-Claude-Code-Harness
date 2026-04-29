---
title: "Your First Task"
last-updated: 2026-04-08
related-files: [CLAUDE.md, .claude/rules/hub.md, hub/patterns/mini.md, hub/patterns/medium.md]
---

# Your First Task — End-to-End Walkthrough

This walks through a medium-scope task so you can see every stage of the orchestration loop.

## The Request

```
You: Create a phishing triage runbook for the SOC team.
```

## Step 1: Scope Assessment

Morpheus analyzes the request and determines scope:

```
Morpheus: This is a medium-scope task (needs research, planning, building, and documentation — 4 waves).
Creating STATE.md...
```

**What happens behind the scenes:**
- Morpheus creates `hub/staging/2026-04-08-phishing-runbook/STATE.md` with the macro goal, validation framework, and wave plan
- `hub/state/active-tasks.md` regenerates automatically via PostToolUse hook when STATE.md is created

## Step 2: Wave 1 — Research

Morpheus dispatches the **gatherer** agent:

```
Morpheus: Dispatching gatherer for Wave 1 (Research)...
```

The gatherer:
1. Reads STATE.md for the macro goal
2. Consults INDEX.md for existing relevant files
3. Searches locally and via web for phishing frameworks (NIST, SANS, Cofense)
4. Writes findings to `hub/staging/.../research-phishing-frameworks.md`
5. Returns a 6-10 sentence summary to Morpheus

Then Morpheus dispatches the **SME assessor** (parameterized as a Senior Security Analyst + Sentinel Specialist):

```
Morpheus: Dispatching SME assessor for Wave 1, Round 1...
```

The assessor:
1. Reads STATE.md and the research artifact
2. Verifies sources exist (WebSearch), checks claim accuracy
3. Updates STATE.md with assessment results
4. Returns: `ADVANCE` or `CONTINUE` with specific feedback

If `CONTINUE`, Morpheus dispatches the gatherer again with the assessor's feedback. If `ADVANCE`, Wave 1 is complete.

## Step 3: Wave 2 — Planning

Morpheus dispatches the **planner**:

```
Morpheus: Dispatching planner for Wave 2 (Planning)...
```

The planner reads the research artifact and produces a detailed plan with:
- Objective (relayed to you for confirmation)
- Acceptance criteria
- TDD strategy
- Build path with subtasks

After SME assessment returns `ADVANCE`:

```
Morpheus: Planning complete. Here's the objective for your review:
"Build a Sentinel-integrated phishing triage runbook covering detection through
remediation, tailored to Goodwin's Proofpoint TAP + Microsoft Defender stack."
Confirm, edit, or reject?
```

**This is a Tyler checkpoint** — you review and approve before building begins.

## Step 4: Wave 3 — Build

Morpheus dispatches the **builder** with the plan:

```
Morpheus: Dispatching builder for Wave 3 (Build), Round 1...
```

The builder follows the plan's build path precisely, writing deliverables to the specified output paths. The SME assessor checks each round. Typical: 2 rounds (initial build + fix round).

## Step 5: Wave 4 — Documentation

Morpheus dispatches the **documenter**:

```
Morpheus: Dispatching documenter for Wave 4 (Documentation)...
```

The documenter:
- Adds a timeline entry to today's daily note
- Updates INDEX.md with new file paths
- Prepends the completed task to completed-tasks.md; active-tasks.md regenerates automatically on next tool call
- Updates STATE.md status to `complete`

## Step 6: Done

```
Morpheus: Task complete. Phishing triage runbook written to kb/runbooks/phishing-triage-runbook.md.
4 waves, 7 rounds total. All deliverables verified by SME assessor.
```

## What to Watch For

- **Hook headers**: Every hook prints `[HOOK:event] FIRED/SKIPPED/ERROR` — if you see SKIPPED or ERROR, something needs attention
- **Verdicts**: `ADVANCE` means quality passed. `CONTINUE` means specific gaps. `FLAG` means Morpheus needs your input. `FAIL` means something is fundamentally wrong
- **STATE.md**: You can read this at any time to see exactly where a task stands
- **Artifacts**: All work products are in `hub/staging/{task-id}/` — nothing is lost
