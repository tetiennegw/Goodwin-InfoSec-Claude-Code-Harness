---
description: The Protocol -- 8-step routing and initialization skill. Classifies domain, assesses scope, loads profile, selects sub-protocol, activates skills, runs pre-flight gate, initializes task scaffolding, and hands off to /orchestration-dispatch. Invoked at the start of every non-passthrough task.
user-invocable: true
argument-hint: (none -- reads user request from context)
schema-version: 1
created: 2026-04-15
last-updated: 2026-04-24
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, TaskCreate, TaskUpdate, TaskList, AskUserQuestion, EnterPlanMode]
---

<!--
  THE PROTOCOL SKILL
  ==================
  Task: 2026-04-13-the-protocol-skill
  Agent: builder
  Created: 2026-04-15T00:00:00Z
  Last-Updated: 2026-04-15T00:00:00Z
  Plan: .claude/plans/fluffy-shimmying-waterfall.md (Part 3)
  Purpose: 8-step orchestration entry point -- classifies, routes, scopes, and initializes.
  Changelog (max 10):
    2026-04-24T16:00 | 2026-04-24-integration-depth-clarification-rule | builder | Step 6c expanded: added 6c.i Integration-Depth 3-Question Battery (shape detection, depth/surface-area/assumption-surfacing questions, anti-rule, cross-refs). Preserves existing 6c baseline text.
    2026-04-22T14:05 | 2026-04-22-harness-intake-improvements | morpheus | Phase A2: removed COEXISTENCE NOTE; /the-protocol is now the sole pre-flight engine (prompt-context-loader.sh stripped in Phase A1).
    2026-04-15T00:00:00Z | 2026-04-13-the-protocol-skill | builder | Created initial 8-step skill

  SOLE ENTRY POINT: This skill is the canonical pre-flight engine for every non-Passthrough
  task. Scope assessment, skill evaluation, and pre-flight gate enforcement all live here —
  not in any hook. The UserPromptSubmit hook (prompt-context-loader.sh) loads time + environment
  context + filesystem-driven forced-YES overrides (ingest, approvals); it does NOT make
  orchestration decisions.

  PASSTHROUGH EXCEPTION: If scope is Passthrough, respond inline and return immediately.
  No STATE.md, no TaskCreate, no staging dir. All other scopes proceed through all 8 steps.
-->

# /the-protocol

You are executing The Protocol -- the master routing and initialization flow for all non-passthrough tasks. Follow these 8 steps in order. Do not skip steps. Do not freelance.

---

## Step 0.5: META-TASK TaskCreate (harness work is task-worthy)

**Fire this BEFORE Step 1 for every non-Passthrough invocation.** Meta-work (protocol pre-flight, scaffolding, handoff) is task-worthy per `.claude/rules/task-handling.md` § Meta-Task Principle. Creating these tasks up front ensures the session task list reflects what the harness is actually doing, not just what it eventually builds.

Scope gating:

| Scope | Meta-tasks to TaskCreate now |
|-------|------------------------------|
| Passthrough | **None** (Passthrough exits at Step 3 — pure answer, no instrumented work). |
| Mini / Small | **M0 (pre-flight)** and **M1 (scaffold)**. No M2 — Mini/Small scaffold skips Planner + plan-mode; handoff is inline. |
| Medium / Large / Ultra | **M0 (pre-flight)**, **M1 (scaffold)**, **M2 (handoff)**. Full three-task meta sequence. |

Canonical subjects:
- `META: pre-flight (/the-protocol Steps 1-6)` — mark `in_progress` immediately; mark `completed` at the end of Step 6 (after ExitPlanMode for Medium+).
- `META: scaffold (Step 7 + 7.5)` — mark `in_progress` when Step 7 begins; mark `completed` at the end of Step 7.5.
- `META: handoff (Step 8)` — mark `in_progress` when Step 8a begins; mark `completed` when audit-ledger row is written and `/orchestration-dispatch` is invoked (or inline proceeding is authorized).

Do **NOT** create step-level (8-task) or single-task (1-task) variants. The 3-task granularity was locked 2026-04-23 via AskUserQuestion in plan `.claude/plans/happy-scribbling-cerf.md`. Noise complaints post-launch trigger a review of collapse-to-1, not expand-to-8.

---

## Step 1: CLASSIFY DOMAIN

Determine which protocol profile governs this request.

1. Glob `.claude/protocols/*.md` to discover all profile files.
2. Skip any file whose name starts with `_` (e.g., `_schema.md` is the format spec, not a profile).
3. For each discovered profile, read its YAML frontmatter and extract:
   - `triggers` -- list of ERE regex patterns
   - `anti-triggers` -- list of plain strings (simple containment, NOT regex)
   - `name` -- human-readable profile name
4. Match against the user request:
   - **Triggers**: test each pattern against the request text using case-insensitive ERE regex. Any match activates this profile.
   - **Anti-triggers**: check if the request contains any anti-trigger string (case-insensitive substring). If request matches an anti-trigger AND does NOT also match a trigger, skip this profile.
5. Precedence:
   - Explicit user override (Tyler names a specific protocol) beats everything.
   - Highest-specificity match (longest matching trigger pattern) wins ties.
   - No match on any profile -> use `default.md` as the catch-all fallback.
6. Emit in your response:
   ```
   Protocol: [PROFILE_NAME] -- [one-line reason for match or fallback]
   ```

**Fail-fast**: If `.claude/protocols/` is missing or has no non-underscore `.md` files,
emit `Protocol: DEFAULT (fallback -- no profiles found)` and continue with `default.md`.

---

## Step 2: LOAD PROFILE

Load the matched profile and merge with its parent.

1. Read `.claude/protocols/{matched-profile}.md` in full.
2. Check frontmatter for `extends:` field:
   - If `extends: default`, first read `.claude/protocols/default.md` as the base.
   - Domain profile sections OVERRIDE base sections. Sections absent from the domain profile fall through to `default.md`.
3. Validate that these required sections exist in the merged result (domain or inherited):
   - `## Scope Heuristics`
   - `## Sub-Protocols`
   - `## Wave Sequences`
   - `## Acceptance Criteria Template`
   - `## SME Personas`
   - `## Verification Gates`
4. Fail-fast on missing section: emit a warning and use `default.md` content for that section. Continue with degraded profile -- do not abort.

---

## Step 3: ASSESS SCOPE

Determine the scope of the request using domain-specific heuristics.

1. Read the `## Scope Heuristics` table from the loaded profile (or inherited from `default.md`).
2. Read `### Auto-Escalation Rules` subsection if present.
3. Match request characteristics against heuristic indicators:
   - Consider: files affected, steps required, research warranted, components involved, session span
   - Apply auto-escalation rules if any keywords trigger them
4. Emit in your response — include scope AND a confidence score:
   ```
   Scope: [PASSTHROUGH|MINI|SMALL|MEDIUM|LARGE|ULTRA] -- [one-line reason]
   Confidence: [LOW|MED|HIGH] -- [one-line justification — what about this request is ambiguous or firm?]
   ```
5. Canonical scope names (use exactly these -- aliases fail validation):
   - **Passthrough**: factual question, greeting, 1-step no-artifact, Tyler says quick
   - **Mini**: 1-2 steps, single file, one agent, no plan needed
   - **Small**: 3-5 steps, single deliverable, no research wave
   - **Medium**: 5-15 steps, multi-file or feature, research or design warranted
   - **Large**: 15-50 steps, multi-component, comprehensive research, single-session
   - **Ultra**: 50+ steps, full platform, multi-session, cross-project

### 3a. Scope-Confidence Escalation (Mini/Small only)

If **Confidence is LOW** and scope is **Mini or Small**, fire `AskUserQuestion` BEFORE proceeding:

> "Scope assessed as {MINI|SMALL} with LOW confidence because {reason}. Keep at {scope}, or escalate to {next tier}?"

Options: "Keep at {current scope}" / "Escalate to {next tier}" / "Other".

This catches the Mini/Small misclassification failure mode (a "simple" task with hidden dependencies or compliance requirements that should get a plan). Medium+ is not included because Medium+ already goes through plan mode where misclassification surfaces naturally.

### 3b. Passthrough Episodic Capture (optional)

If scope is Passthrough AND the answer touches preferences, roadmap signals, corrections, or recurring questions, append a one-line entry to `hub/state/episodic-log.md` under the EPISODIC-LOG-ANCHOR. Signal types: `preference`, `roadmap`, `correction`, `repeat-q`, `mental-model`. This is passive memory capture — `/weekly-review` consumes the log to detect patterns and propose new memory entries.

**PASSTHROUGH EXIT**: After optional episodic capture (3b), respond to Tyler directly and STOP here.
Do not proceed to Steps 4-8. No STATE.md, no TaskCreate, no staging dir.

---

## Step 4: SELECT SUB-PROTOCOL

Map domain + scope to the appropriate sub-protocol from the loaded profile.

1. Read `## Sub-Protocols` from the loaded profile.
2. Find the sub-protocol whose scope range matches the assessed scope:
   - Mini and Small typically share one sub-protocol (e.g., Simple Script (Mini/Small))
   - Medium, Large, Ultra each have their own sub-protocol
   - No direct match -> use the sub-protocol for the nearest lower scope range
3. Extract the 6 required scaling parameters:
   - **Scaffolding**: what staging artifacts to create
   - **Research**: gatherer waves, rounds, source count
   - **Plan**: flat checklist vs full 16-section vs hub plan + subsystem specs
   - **Build**: builder count, TDD approach, session span
   - **Verification**: manual vs 3-tier gates vs per-phase verifier
   - **Artifact chain**: ordered sequence from intent to done
4. For Large and Ultra sub-protocols, also extract:
   - **Foundation gate**: blocking condition between phases
   - **Session span**: Single vs Multi-session
   - **Tyler checkpoints**: when to pause for Tyler review
5. Read `## Wave Sequences` table to get the ordered agent dispatch sequence for this sub-protocol.
6. Emit in your response:
   ```
   Sub-protocol: [name] -- [what it provides for this scope]
   Wave sequence: [from ## Wave Sequences table]
   ```

---

## Step 5: EVALUATE AND ACTIVATE SKILLS

Activate all skills needed for this task.

1. **Standard skill evaluation**: For each skill in `.claude/commands/`, evaluate YES/NO for the current request (same logic as prompt-context-loader Step 1).
2. **Profile-mandated skills**: Read `always-activate-skills` from the profile frontmatter. These activate unconditionally when this protocol is selected -- add them to the YES list regardless of request content.
3. For each skill on the YES list: invoke `Skill(skill-name)` to activate it.
4. Emit in your response:
   ```
   Skills activated: [list of skill names]
   ```

---

## Step 6: PRE-FLIGHT GATE (PLAN-FIRST — ordering matters)

**Scope branches**:
- **Passthrough** already exited at Step 3.
- **Mini / Small**: do 6c (context gather, lightweight) + 6d (AskUserQuestion clarify if anything is ambiguous). **No plan mode** (not required by standard). Proceed directly to Step 7.
- **Medium / Large / Ultra**: execute 6a → 6b → 6c → 6d in order. **Skipping 6a is a protocol violation** (see enforcement block below).

### 6a. Enter Plan Mode (Medium+ — FIRST, always)

Call `EnterPlanMode`. This is the gate. Nothing writable happens before `ExitPlanMode` is called later in 6d.

**ENFORCEMENT — NON-NEGOTIABLE**: If scope ∈ {Medium, Large, Ultra} and `EnterPlanMode` has not been called this turn, **STOP**. Do not gather context. Do not ask clarifying questions. Do not create staging dir, STATE.md, TaskCreate entries, daily-note entries, or Planner tasks. The only way through is to call `EnterPlanMode` now, or to have Tyler explicitly authorize an exception — which itself must be logged to `hub/state/harness-audit-ledger.md` with reason and timestamp. **No rationalization exceptions. No "the planner agent will handle it later." No "we already have the context." The rule is the rule; the audit hook verifies it.**

### 6b. Context Gathering (scaled by scope, inside plan mode)

Load only what this scope tier requires — do not load everything:

| Scope | What to Load | Approx Token Budget |
|-------|-------------|---------------------|
| Mini / Small | Profile + relevant rules files if clearly domain-specific | ~500-1000 tokens |
| Medium | Full profile + relevant .claude/rules/ files matching this domain | ~2,000 tokens |
| Large | Profile + rules + paths to domain research artifacts (paths only) + codebase scan + prior domain STATE.md paths | ~3,000 tokens |
| Ultra | Everything Large gets + cross-project STATE.md files + prior ADRs + HANDOFF.md from prior session + subsystem specs | ~4,000 tokens |

**Key principle**: pass file PATHS to agents, not file contents. Agents read on demand. This prevents context window overload.

### 6c. Clarifying Questions (Medium+ — inside plan mode, via AskUserQuestion)

Use `AskUserQuestion` tool — **never inline text**. **Fire this even if the scope was pre-discussed or answers feel obvious.** Re-confirmation inside the protocol is not rubber-stamping — it's the gate against pre-batched clarifications bypassing the standard (the 2026-04-21 Azure-kickoff failure mode). At minimum ask:

- What is the desired outcome or deliverable?
- Are there constraints, timelines, or quality requirements?
- Are there existing files this should extend or be compatible with?

Read the profile sub-protocol for domain-specific clarifying questions. Do NOT proceed until Tyler answers.

### 6c.i Integration-Depth 3-Question Battery (mandatory before plan drafting)

**Shape detection — fires before the battery:** Classify the task as integration-shaped or component-shaped before drafting any plan.

- **Component-shaped** = "fix one hook", "update one rule" — narrow defaults are acceptable; existing Step 6c baseline questions are sufficient.
- **Integration-shaped** = "add a peer system", "onboard {tool}", "make X first-class" — broad defaults are required; fire all three questions below.

**Trigger keywords that force integration-shaped treatment:** "fully integrated", "first-class", "tool at my disposal", "add system X", "onboard {tool}".

**Self-trigger heuristic (apply to every Medium+ task):** For every build/integration task ask: "Could this ripple into hooks, rules, templates, agents, protocols, daily-notes, doctrine, or the orchestration loop?" If "plausibly yes" for 2 or more, that IS the clarifying question — ask before plan drafting, not after Tyler rejects a thin plan.

Fire all three questions below **in a single AskUserQuestion call** before plan drafting begins. Do NOT draft the plan until Tyler answers.

**Depth question (mandatory)** — Offer Tyler three integration-depth options with one-line consequences each. Default-recommend the option implied by trigger keywords ("fully integrated" / "first-class" / "tool at my disposal" recommend Broad or Ground-up):

```
Options:
  Thin       -- One component + minimal wiring. Fast. May require a re-plan if ripple effects appear.
  Broad      -- Ripple through harness primitives (hooks, rules, templates, agents, protocols). Recommended for integration-shaped requests.
  Ground-up  -- New protocol profile + agent type + cross-cutting doctrine. For truly new peer systems.
```

**Surface Area question (mandatory, multiSelect)** — Before depth resolves, enumerate the primitives that could plausibly be affected by this task and ask Tyler to confirm or veto each. Primitives to enumerate:

- hooks (.claude/hooks/)
- rules (.claude/rules/*.md)
- templates (hub/templates/*.md)
- agents (.claude/agents/*.md)
- protocols (.claude/protocols/*.md)
- CLAUDE.md doctrine
- docs/morpheus-features/
- hub/state/ files

Use multiSelect on AskUserQuestion so Tyler can confirm or veto each. The confirmed list drives which sections the planner must cover in the orchestration plan.

**Assumption-Surfacing question (mandatory)** — Name the 2-3 assumptions about to be baked into the plan and ask Tyler to confirm or override BEFORE writing the plan. These are the assumptions that, if wrong, force a full plan rewrite. Example phrasings:

- "I'm assuming reader role is enough — no new agent type needed."
- "I'm assuming /incident-triage stays untouched."
- "I'm assuming no new audit hook is required — rule + memory enforcement only."

**Anti-rule (non-negotiable):** "The plan can always be expanded later" or "let's start narrow and grow" IS the violation. Default broad on integration tasks; let Tyler narrow. Narrowing requires one AskUserQuestion; expanding requires a full re-plan.

**Cross-references:**
- Planner-side check: .claude/rules/implementation-plan-standard.md section 6.5 Integration-Depth Sanity Check (authored in parallel with this rule)
- Memory source: feedback_integration_depth_clarification.md

### 6d. Present Orchestration Plan + ExitPlanMode

Synthesize the answers from 6c + context from 6b into a concrete orchestration plan: wave sequence, phase structure, SME persona selection, foundation-gate placement, artifact chain. Write it to `.claude/plans/` using the path provided by plan mode. Call `ExitPlanMode`.

**Tyler must approve via ExitPlanMode before Step 7 runs.** No staging dir, no STATE.md, no TaskCreate, no daily-note entry, no Planner task — nothing writable — is created before this approval.

---

## Step 7: INITIALIZE TASK (POST-APPROVAL — Medium+ only runs after ExitPlanMode)

**PRECONDITION**: For Medium+, Tyler has approved the orchestration plan via `ExitPlanMode`. Creating any durable side effect (staging dir, STATE.md, TaskCreate, daily-note entry, Planner task) before that approval is a protocol violation — roll back and restart from Step 6 if you catch this mid-execution.

For Mini/Small, Step 7 runs directly after Step 6 clarifications (no plan-mode gate).

### 7a. Generate Task ID

Format: `YYYY-MM-DD-{slug}` where slug is lowercase hyphen-separated 2-5 words.
Example: `2026-04-15-sentinel-detection-suite`. If the staging dir already exists (collision), append `-v2`, `-v3` until unique.

### 7b. Create Staging Directory

Run Bash: `mkdir -p hub/staging/{task-id}`

### 7c. Write STATE.md (schema-version: 2)

Read `hub/templates/state.md` as the template. Write `hub/staging/{task-id}/STATE.md` with:

**Required frontmatter (v2 schema — all fields mandatory, nullable values explicit)**:
```yaml
task-id: {task-id}
scope: {scope-lowercase}
status: planning
protocol: {profile-name-lowercase-slug}
sub-protocol: {sub-protocol-name-lowercase-slug}
schema-version: 2
created: {ISO timestamp}
last-updated: {ISO timestamp}
current-wave: 0
current-round: 0
planner-task-id: null   # filled by Step 7.5 for Large/Ultra
plan-approved-at: {ISO timestamp of ExitPlanMode for Medium+; null for Mini/Small}
pending-decisions: []   # unresolved ADRs, populated as planner agent runs
blockers: []            # active blockers; populated during execution
verified-artifacts: []  # list of {path, verified-at}
resume-command: "/orchestration-dispatch hub/staging/{task-id}/STATE.md"
```

**Body sections** (populate from what you know now; agents fill the rest during execution):
- `## Macro Goal` — 2-3 sentences: what this achieves and why it matters to Tyler/Goodwin
- `## Project Scaffold` — visual directory tree; all entries marked not-started; omit for Mini/Small
- `## Task Table` — one row per wave/agent from the wave sequence; status=pending; Large+ adds columns `required-inputs`, `required-outputs`, `blockers`, `verification-status`; omit for Mini
- `## Context Inventory` — paths to any context already gathered; omit for Mini/Small
- `## Validation Framework` — acceptance criteria from profile Acceptance Criteria Template for this sub-protocol; SME Personas from profile; omit for Mini
- `## Progress Summary` — single initialization line with ISO timestamp, protocol name, and sub-protocol name
- `## Open Items` — empty initially
- `## Next Action` — first task from the wave sequence

**Ultra-only sections** (include ONLY when scope is Ultra; omit for all other scopes):
- `## Subsystem Status Matrix` — all subsystems, all phases marked pending
- `## Session History` — one row for this session
- `## Phase Gate Log` — empty
- `## Scope Changes` — empty
- **A stub `HANDOFF.md` must be created in the same staging dir at this step** (per `hub/templates/handoff.md`) so session-boundary handoff is handled from day 1.

### 7d. Create Task List via TaskCreate (APPEND to meta-tasks)

**APPEND the plan's task hierarchy to the existing meta-tasks (M0/M1/M2) that Step 0.5 created at turn start.** Do NOT wipe the meta-tasks; do NOT re-create them. The session task list at this point should show:

- `META: pre-flight` — marked `completed` (Step 6 finished)
- `META: scaffold` — marked `in_progress` (Step 7 is currently running)
- `META: handoff` — still `pending` (Step 8 hasn't begun)
- **+ the plan-section-8a hierarchy appended below**

Create Claude Code session tasks matching the wave sequence from Step 4 AND the plan's section 8a preview:
1. One top-level task per wave or phase (from plan section 8a).
2. Nested sub-tasks for each agent round within each wave.
3. Explicit `VERIFY [phase]` and `CHECKPOINT [phase]` tasks at the end of each phase.
4. For Medium+: first task is `Phase 0: Scaffold` — mark it `in_progress` now (it's running this turn), mark `completed` at end of 7e.
5. Apply blockedBy dependencies from plan section 8b: VERIFY blocks CHECKPOINT; CHECKPOINT blocks next-phase BUILD tasks.
6. Every TaskCreate subject follows `.claude/rules/task-handling.md` § Naming Standard (imperative verb + object + optional scope tag).
7. Every TaskCreate MUST carry an urgency assignment per `.claude/rules/task-handling.md` § Urgency Model (`immediate` / `sequenced` / `deferred`). Plan-task default is `immediate` for work in the current phase, `sequenced` for dependent later-phase work.

### 7e. Log to Daily Note (IMMEDIATE)

Prepend a timeline entry to today's daily note NOW — not after the response, not at end of conversation. Follow the prepend protocol in `.claude/rules/daily-note.md`.

Minimum entry:
```markdown
- **HH:MM AM/PM** - **[task-id] Task Initialized** #{domain} #{scope}

  **Work Type**: Task Initialization via The Protocol

  **Implementation Tasks**:
  - ✅ Protocol classified: {profile name}
  - ✅ Scope assessed: {scope}
  - ✅ Sub-protocol selected: {sub-protocol name}
  - ✅ Plan approved by Tyler: {plan-approved-at timestamp}  (Medium+ only)
  - ✅ STATE.md written: hub/staging/{task-id}/STATE.md
  - ✅ Planner task created: {planner-task-id}  (Large/Ultra only, recorded after Step 7.5)
  - ✅ Task list populated with {N} wave tasks

  **Strategic Value**: Initialized orchestration scaffolding. STATE.md is now the single
  source of truth for all downstream agents. Wave sequence locked in —
  /orchestration-dispatch will execute from here.

---
```

---

## Step 7.5: PLANNER TASK CREATION (Large/Ultra — idempotent, post-scaffold)

**Scope gating**:
- **Large / Ultra**: MUST create a Planner task on "{{user.name}}'s Work" (personal board), idempotent by task-id slug.
- **Medium**: Fire AskUserQuestion "Create Planner task for this project on your personal board? (Recommended for work visibility)" with options Yes/No. Default Yes. If Yes, proceed with the same idempotent-create logic.
- **Small / Mini / Passthrough**: Skip entirely.

### 7.5a. Idempotency check (before create)

Before calling `New-PlannerTask`, check if a task with matching task-id already exists on the personal board. Query pattern: read `hub/state/planner-mapping.json` → find `morpheus-task-id: {task-id}` custom-field entry. If present, **skip create**, retrieve the `plannerTaskId`, record it in STATE.md frontmatter, and proceed to Step 8. Do NOT re-create.

### 7.5b. Create (when no existing task)

Invoke via explicit Bash call (NOT a hook). Use the actual `New-PlannerTask` signature exported from `scripts/planner/PlannerSync.psm1` — verified 2026-04-24 against module Get-Help.

```bash
pwsh.exe -NoProfile -Command "
  Import-Module './scripts/planner/PlannerSync.psm1' -Force;
  Connect-PlannerGraph | Out-Null;
  \$mapping = Get-Content 'hub/state/planner-mapping.json' -Raw | ConvertFrom-Json;
  \$planId = \$mapping.personal.planId;
  \$bucketId = \$mapping.personal.buckets.Planning;
  \$desc = '{macro-goal from STATE.md, plus task-id reference}';
  \$checklist = @( '{phase 1 short label}', '{phase 2 short label}', ... );  # see constraints below
  \$task = New-PlannerTask -Title 'Morpheus: {task-id}' \
                           -PlanId \$planId \
                           -BucketId \$bucketId \
                           -Priority 3 -PercentComplete 0 \
                           -Description \$desc \
                           -Checklist \$checklist \
                           -SkipDailyNoteLog;  # daily-note logging happens in Step 7e instead
  Write-Host ('plannerTaskId=' + \$task.plannerTaskId);
  Write-Host ('descriptionPersisted=' + \$task.descriptionPersisted);
  Write-Host ('checklistPersisted=' + \$task.checklistPersisted);
"
```

**Hard constraints (Graph-enforced — violations cause silent partial failure)**:

1. **Each checklist item title MUST be ≤100 characters.** As of 2026-04-24, `New-PlannerTask` auto-truncates items >100 chars to 97 + `...` and emits `Write-Warning`. Even with auto-truncation, prefer keeping items short (under ~80 chars) so the truncation warning never fires.
2. **Title** is community-reported safe up to 255 chars; longer titles emit a soft warning but Graph may accept.
3. **Description** has no documented hard limit; reasonable max ~28K chars (Planner UI may truncate display).

**Idempotency**: The previous `-MorpheusTaskId` parameter (referenced in earlier versions of this skill) does NOT exist on `New-PlannerTask`. Idempotency is achieved by checking `hub/state/planner-mapping.json` for an existing `morpheus-task-id` mapping (Step 7.5a) OR by writing the task-id into the description as the first line so subsequent searches can find it. The plain create above is correct when 7.5a confirms no existing task.

**Partial-success handling**: `New-PlannerTask` (post 2026-04-24 hardening) splits the details PATCH into independent description-only and checklist-only calls. The return hash includes `descriptionPersisted` and `checklistPersisted` booleans. If either is `$false`, the core task still exists and is usable — surface the partial-failure to Tyler in the Step 7e daily-note entry rather than rolling back.

**Interactive-prompt warning**: `Connect-PlannerGraph` may trigger a WAM browser sign-in if no cached token. This is acceptable because Step 7.5 runs in-session with Tyler present. If Tyler is AFK and the auth prompt would block, return `PARTIAL` status, write a deferred entry to `hub/state/planner-push-queue.json`, and proceed to Step 8 noting the deferred Planner create.

### 7.5c. Record in STATE.md

Update STATE.md frontmatter `planner-task-id:` from `null` to the returned GUID. Update daily-note timeline entry to add the Planner task ID (or mark as deferred).

---

## Step 8: PRE-HANDOFF GATE + HAND OFF

Before invoking `/orchestration-dispatch`, execute the pre-handoff gate. Every check is pass/fail with evidence; any FAIL blocks handoff.

### 8a. Pre-handoff checks (all must PASS)

Universal (every non-Passthrough task):
- [ ] `test -f hub/staging/{task-id}/STATE.md`
- [ ] STATE.md frontmatter has `schema-version: 2`
- [ ] STATE.md `## Next Action` is non-empty
- [ ] TaskList shows all wave tasks created (match section 8a of plan)
- [ ] Today's daily note has the initialization timeline entry (grep for task-id)

Medium+ (add to universal):
- [ ] `ExitPlanMode` was called this turn (plan-first invariant)
- [ ] `AskUserQuestion` was called this turn in Step 6c
- [ ] STATE.md frontmatter `plan-approved-at` is non-null

Large/Ultra (add to Medium+):
- [ ] STATE.md frontmatter `planner-task-id` is non-null (created or explicitly deferred to queue)
- [ ] If deferred, `hub/state/planner-push-queue.json` has the queued entry

Ultra (add to Large/Ultra):
- [ ] `hub/staging/{task-id}/HANDOFF.md` exists with v1 schema (Intent, Pending Decisions, Active Blockers, Verified Artifacts, Next Command, Planner Links, Resume Checklist)

### 8b. Write audit-ledger entry

Append to `hub/state/harness-audit-ledger.md`:

```
| {ISO} | {task-id} | {scope} | AUQ:{Y|N} | EPM:{Y|N} | XPM:{Y|N} | PLN:{Y|N|NA|DEF} | SCAF:{Y|N} | RESULT:{PASS|FAIL} | {details or —} |
```

Where AUQ=AskUserQuestion, EPM=EnterPlanMode, XPM=ExitPlanMode, PLN=Planner-task (NA for Small/Mini, DEF for deferred), SCAF=scaffold-after-approval.

### 8c. Handoff (only on PASS)

On FAIL emit:
```
BLOCKED — pre-handoff gate failure:
- {gap 1}
- {gap 2}
Will not hand off. Roll back and restart from Step {6 or 7}.
```

On PASS invoke `/orchestration-dispatch` with STATE.md path and emit:
```
Handing off to /orchestration-dispatch
STATE.md: {absolute path}
Protocol: {name} | Sub-protocol: {name} | Scope: {scope}
Wave sequence: {from Step 4}
First wave: {first entry}
Audit-ledger: PASS
```

STATE.md is the handoff contract. Everything downstream agents need is in it.

---

## Rules

1. **Passthrough is the only early exit.** All other scopes complete Steps 4-8 before any work begins. Starting work without STATE.md and TaskCreate is a protocol violation.
2. **AskUserQuestion -- never inline text.** All clarifying questions use the AskUserQuestion tool. Never ask via chat response text.
3. **EnterPlanMode required for Medium+.** Do not begin implementation without entering plan mode first.
4. **Anti-triggers are plain strings, NOT regex.** Check if request text contains the anti-trigger string (case-insensitive substring). Never use regex for anti-trigger matching.
5. **Trigger matching uses ERE regex.** Trigger patterns use extended regular expressions (no lookahead, no backreferences).
6. **Profile inheritance is always resolved.** If a profile has `extends: default`, load `default.md` first, then apply domain profile sections as overrides.
7. **STATE.md is the single source of truth.** After initialization, all information flows through STATE.md. Pass file paths between agents, never file contents.
8. **SME assessors write assessment artifacts to disk.** Format: `hub/staging/{task-id}/assessment-w{N}r{N}.md`. Never inline-only returns.
9. **Clarifications fire inside the protocol, even when pre-gathered.** If scope was pre-discussed before `/the-protocol` fired, Step 6c still fires an AskUserQuestion re-confirmation. Pre-batched clarifications feeding a rubber-stamp protocol run is the 2026-04-21 Azure-kickoff failure mode. The gate is the gate.
10. **Scaffolding is post-approval for Medium+.** Nothing writable (staging dir, STATE.md, TaskCreate entries, daily-note entry, Planner task) is created before Tyler approves the orchestration plan via `ExitPlanMode`. If you catch yourself writing a scaffold artifact pre-approval, STOP and roll back.
11. **Planner creation is idempotent by task-id slug.** Step 7.5 checks `hub/state/planner-mapping.json` (or equivalent Planner custom-field query) before calling `New-PlannerTask`. Duplicate creates are logged as metric-degrading incidents (`#duplicate-planner-task` in the audit ledger).
12. **No self-justified skips.** If you're about to rationalize skipping a standard ("the planner agent will handle it later", "we already gathered scope", "plan mode isn't useful here"), that's the violation. Stop. Either the rule fires or Tyler explicitly authorizes an exception (which itself must be logged to the audit ledger with reason and timestamp).
9. **Log to daily note immediately.** The initialization entry goes in today daily note during Step 7e -- never deferred to after the conversation.
10. **Never dispatch two SME assessors in parallel.** Sequential only -- parallel SME assessors cause STATE.md write conflicts.
13. **Meta-work is task-worthy.** Step 0.5 TaskCreates M0/M1/M2 (pre-flight / scaffold / handoff) for Medium+, M0/M1 for Mini/Small, none for Passthrough. Meta-tasks are tracked and status-transitioned just like build tasks. They are NOT invisible overhead. Rule: `.claude/rules/task-handling.md` § Meta-Task Principle. Enforcement: `.claude/hooks/task-discipline-audit.ps1` (Stop event) writes `TASKDISC:{PASS|SOFT|FAIL}` rows to `hub/state/harness-audit-ledger.md`.
14. **Non-cancellation invariant.** Tasks are never silently cancelled or deleted. `TaskUpdate status=cancelled` or `status=deleted` requires Tyler's same-turn authorization (keywords: cancel / drop / abandon / nevermind / skip / remove / kill / scrap). Session-end is NOT authorization. Violation logs a FAIL row to the audit ledger. Full rule: `.claude/rules/task-handling.md` § Non-Cancellation Invariant.

---

## Changelog

| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-15T00:00:00Z | 2026-04-13-the-protocol-skill | builder | Created initial 8-step skill -- domain classification via profile trigger matching, scope assessment via domain heuristics, sub-protocol selection, skill activation, pre-flight gate with AskUserQuestion and EnterPlanMode, standardized STATE.md initialization from hub/templates/state.md, and /orchestration-dispatch handoff |