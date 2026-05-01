---
task-id: {task-id}
schema-version: 1
artifact-type: handoff
scope: ultra
created: {ISO timestamp}
last-updated: {ISO timestamp}
session-count: {N}
last-session-ended: {ISO timestamp}
---

# HANDOFF — {Task Title}

> **Purpose**: This file is the cross-session resume packet for Ultra tasks. A fresh Morpheus instance reading only this file + `STATE.md` must be able to resume work with no missing intent, blockers, or next step. If you are starting a new session on this task, **read this file first**, then STATE.md, then whatever the Next Command below tells you to read.

---

## Intent
<!-- Original macro goal from STATE.md § Macro Goal. Copy VERBATIM. Do not paraphrase.
     The whole point is that intent never drifts across sessions. -->

{Verbatim copy of STATE.md macro goal.}

---

## Pending Decisions
<!-- Unresolved ADRs or open-design questions. One row per decision.
     "Why it matters" is the context that the next session needs to decide. -->

| # | Decision | Options on table | Why it matters | Blocking? |
|---|---------|------------------|----------------|-----------|
| D1 | {short title} | A: {opt} / B: {opt} / C: {opt} | {context — what downstream work depends on this} | {Y / N} |

---

## Active Blockers
<!-- Anything preventing the next wave from launching. Each entry names an owner and unblock criterion. -->

| # | Blocker | Owner | Unblock criterion | First seen |
|---|---------|-------|-------------------|------------|
| B1 | {description} | {Tyler / external / internal} | {what has to be true to proceed} | {ISO} |

---

## Verified Artifacts
<!-- Artifacts produced and externally verified (SME-assessed or test-run-passed). Each row has a verification timestamp.
     Do NOT list unverified artifacts here — this is the "ground truth" inventory a new session can trust. -->

| # | Artifact path | Produced by | Verified by | Verified at | Hash / signature |
|---|--------------|-------------|-------------|-------------|-------------------|
| V1 | {relative path} | {agent} | {SME persona / test run} | {ISO} | {sha256 first 12 chars OR "n/a"} |

---

## Next Command
<!-- The literal command a new session can execute to resume. Copy-paste ready. No ambiguity.
     If the next step requires Tyler decision, say so explicitly and list the Decision ID from Pending Decisions above. -->

```
{Literal command, e.g.: /orchestration-dispatch hub/staging/{task-id}/STATE.md}
```

**If Tyler decision required first**: Resolve Decision D{N} before resuming. See § Pending Decisions above.

---

## Planner Links
<!-- Planner task ID(s) + direct URLs. Cross-references to the external PM surface. -->

- **Personal board** (`{{user.name}}'s Work`): {plannerTaskId} — {URL}
- **Project board** (if dual-written): {plannerTaskId} — {URL}
- **Last sync**: {ISO} ({pull/push direction})

---

## Resume Checklist
<!-- 10-point human-walkable verification that context is restored.
     A fresh session agent should mentally (or literally) tick these before proceeding. -->

- [ ] 1. STATE.md `status` is not `completed` (else archive via /eod)
- [ ] 2. STATE.md `current-wave` matches the wave referenced in Next Command
- [ ] 3. STATE.md `planner-task-id` resolves to a real Planner task (spot-check URL)
- [ ] 4. All Verified Artifacts in the table above exist on disk (`test -f`)
- [ ] 5. All Active Blockers are still active (or their unblock criterion has been met — update this file before resuming)
- [ ] 6. Pending Decisions have not been resolved out-of-band (check daily notes since `last-session-ended`)
- [ ] 7. No new Scope Changes in STATE.md since `last-session-ended` that invalidate the Next Command
- [ ] 8. Intent section above still matches Tyler's stated goal (re-confirm if session spanned >7 days)
- [ ] 9. Agent roster for the upcoming wave is intact (`.claude/agents/` has the expected personas)
- [ ] 10. `hub/state/harness-audit-ledger.md` shows no unresolved FAIL entries for this task-id

If ANY row fails, DO NOT resume silently. Surface the failure to Tyler via AskUserQuestion.

---

## Session History
<!-- Append-only log of past sessions. Never edit prior rows. -->

| Session | Started | Ended | Waves advanced | Delta intent? | Notes |
|---------|---------|-------|----------------|---------------|-------|
| {N} | {ISO} | {ISO} | {W1-W2} | No | {one-line summary of what moved} |
## Neo Sessions
<!-- Ultra-only -- Active and historical Neo session references for cross-session resume. -->
<!-- Delete this section for Large and below. -->

| Session ID | Query summary | Status | Resume command |
|------------|---------------|--------|----------------|
| {neo-conversation-id} | {brief description of what was queried} | {active/completed/expired} | neo --resume {session-id} |
---

## Changelog
| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| {ISO} | {task-id} | {agent} | {what changed in this HANDOFF packet} |
