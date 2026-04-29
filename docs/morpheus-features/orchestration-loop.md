---
title: Orchestration Loop
category: morpheus-feature
tags: [orchestration, morpheus-core, v2]
created: 2026-04-17
last-updated: 2026-04-22
last-verified: 2026-04-22
review-interval: 90d
status: active
audience: Tyler (current), Goodwin security team (future open-source)
owner: {{user.name}}
related-runbook: none
related-state: hub/staging/2026-04-22-harness-intake-improvements/STATE.md
absorbs-skills: [the-protocol, orchestration-dispatch, skill-opportunity-detector]
---

# Orchestration Loop

> **How Morpheus routes requests into wave-based sub-agent execution — the v2 plan-first Protocol → dispatch → verify → checkpoint pattern.**

## Overview

**What it is**: The deterministic control loop that routes every non-passthrough request through classify → (plan-first for Medium+) → scaffold → dispatch → verify → checkpoint, so no task ever runs ad-hoc. Mechanically it is two interlocking skills (/the-protocol and /orchestration-dispatch) plus the STATE.md + TaskCreate scaffolding they produce and consume. The Protocol handles routing through an 8-step sequence: classify domain, load profile, assess scope, select sub-protocol, activate skills, run plan mode + context gather + AskUserQuestion clarify + present plan (Step 6a—6d for Medium+), scaffold post-approval (Step 7), optionally create a Planner task (Step 7.5 for Large/Ultra), run the pre-handoff gate (Step 8), and hand off. Dispatch handles execution: reads STATE.md, walks the wave sequence, dispatches a work agent per round, then a dynamic SME assessor, reads the verdict, and either advances to the next wave or retries with feedback.

**Why it exists**: Without the loop, Morpheus would do work directly and regress into the worst-case LLM agent pattern — freelancing across the full context window, skipping verification because everything “looks right,” and silently diverging from Tyler’s intent as tasks get longer. The v2 loop enforces four disciplines that free-form chat does not: (1) plan-first for Medium+ (no staging dir, STATE.md, TaskCreate, or daily-note entry is written before Tyler approves the orchestration plan via ExitPlanMode); (2) scope-appropriate scaffolding (Mini skips it, Medium+ mandates STATE.md + TaskCreate + daily note — post-approval); (3) separation of concerns (work agents write artifacts to files; SME assessors verify with external evidence; the main session reads summaries and state, not content); (4) cross-session continuity (STATE.md v2 is typed/durable, TaskCreate is session-ephemeral, HANDOFF.md v1 bridges Ultra tasks that span sessions with a validated schema).

**Who uses it**: Invoked automatically at the start of every non-passthrough task via /the-protocol. /orchestration-dispatch is the internal wave executor called by /the-protocol Step 8 — Tyler rarely invokes it directly. /skill-opportunity-detector feeds back pattern signals from daily notes (repeated manual steps become candidate skills). All three are registered in the skills table in CLAUDE.md. The prompt-context-loader hook, post-v2 overhaul, provides only time-context + environment context + forced-YES overrides for /ingest-context and /approve-pending — it no longer duplicates scope/pre-flight logic.

**Status**: active — v2 overhaul landed 2026-04-22 (task: 2026-04-22-harness-intake-improvements). v1 production since 2026-04-15; v2 fixes the rubber-stamp failure mode documented in hub/state/replay-corpus/2026-04-21-azure-kickoff-rubber-stamp/.

---

## What Changed in v2

The 2026-04-22 overhaul was driven by a specific protocol incident on 2026-04-21: Morpheus silently skipped `EnterPlanMode`, batched clarifications outside `/the-protocol`, created STATE.md before any plan was visible, and omitted the Planner task for an Ultra-scope task. A Codex multi-agent second opinion confirmed the root cause was architectural, not a typo in a rule file. See `docs/morpheus-features/north-star-standard.md` for the full 8-invariant north-star this overhaul targets and `thoughts/second-opinions/2026-04-22-harness-overhaul-codex.md` for the comparative analysis.

### Before / After at a Glance



