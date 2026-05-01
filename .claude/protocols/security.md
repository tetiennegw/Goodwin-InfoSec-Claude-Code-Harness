---
name: Security Operations Protocol
schema-version: 1
extends: default
description: Security investigation, incident response, threat hunting, detection engineering, and SOC tooling work — anything that needs Sentinel KQL, Defender XDR, Entra, Abnormal, ThreatLocker, Lansweeper, or AppOmni data
triggers:
  - investigat.*incident
  - threat.*hunt
  - sentinel.*kql
  - defender.*xdr
  - sign-in.*log
  - risky.*user
  - phish
  - abnormal.*security
  - threatlocker.*approval
  - lansweeper.*asset
  - appomni
  - SOC.*investigat
  - IR.*workflow
  - contain.*account
  - isolate.*machine
  - reset.*password
  - block.*indicator
  - run.*kql
anti-triggers:
  - write a detection
  - build a runbook
  - implement soar
  - create a playbook
always-activate-skills:
  - task-list-management
  - daily-note-management
  - neo
min-core-version: 1
created: 2026-04-27
last-updated: 2026-04-27
---

<!--
  SECURITY OPERATIONS PROTOCOL PROFILE
  ====================================
  Domain: Day-to-day SOC work — investigation, threat hunting, IR, detection, asset/identity lookups.
  Anything that pulls data from Sentinel/Defender/Entra/Abnormal/ThreatLocker/Lansweeper/AppOmni.

  Verification philosophy: SOC work is evidence-driven. Verification favors observable signals
  from external systems (a Sentinel query returns expected rows, an Entra user has expected
  risk state, a Defender alert has expected severity) over abstract correctness.

  Anti-trigger rationale: simple string containment (no regex). Requests to *write* a detection
  rule, *build* a runbook, *implement* SOAR automation, or *create* a playbook are deliverable-
  shaped (route to code.md). Investigation/hunt/contain/triage are evidence-shaped (route here).

  /neo is the primary SOC tool. This profile activates it via always-activate-skills so any
  matched request gets the offer + capability surfaced in Step 5 of /the-protocol.
-->

## Scope Heuristics

Domain-specific scope indicators for SOC work. These replace the generic Default Protocol heuristics for any request that activates the Security Operations Protocol.

| Indicator | Scope |
|-----------|-------|
| Single SOC question, single tool, no follow-up expected ("who logged in from China yesterday?") | Mini |
| Single user/host investigation, 1-3 tool calls, write-up not required | Small |
| Multi-entity threat hunt, multiple tool surfaces (Sentinel + Defender + Entra), correlation needed | Medium |
| Incident response with containment actions (isolate + reset password + block indicator), team-visible writeup | Large |
| Multi-vector breach response, cross-session, multiple containment layers, executive briefing | Ultra |

### Auto-Escalation Rules (security-specific)

Escalate beyond initial assessment when:

- **Containment requested**: any request that asks to isolate a host, reset a password, block an indicator, or remediate email — escalate to Medium+ (always-on confirmation gate per /neo skill body)
- **Multi-entity correlation**: query touches ≥3 user identities OR ≥3 hosts OR ≥3 indicators — escalate to Medium+ (correlation analysis warrants a structured artifact)
- **Time window > 30 days**: hunt or investigation across more than 30 days of telemetry — escalate to Medium+ (large data sets need a documented query plan)
- **Privileged identities involved**: any tier-0 admin, executive, or break-glass account — escalate to Large+ (privileged-access incidents have political and compliance dimensions)
- **External-party notification likely**: breach with possible client / regulator / vendor disclosure — escalate to Ultra (multi-session, parallel legal/comms work)

---

## Sub-Protocols

> **Task-list discipline applies to every sub-protocol.** Every wave/phase transition runs TaskCreate / TaskUpdate per `.claude/rules/task-handling.md` (naming, 3-level urgency, non-cancellation invariant). `/the-protocol` Step 0.5 creates the M0/M1/M2 meta-tasks before sub-protocol execution begins.

### Quick SOC Question (Mini)
- **Scaffolding**: STATE.md (minimal: frontmatter + macro goal + next action). No staging dir if the answer fits in one /neo round-trip.
- **Research**: None — Neo IS the research surface for SOC questions
- **Plan**: Inline (1-3 sentences in STATE.md, no formal plan artifact)
- **Build**: 1 /neo invocation, single round, captured in daily-note timeline entry with `#neo` tag + session id
- **Verification**: Tyler reads the response and acks; no SME assessor needed
- **Artifact chain**: question → /neo invocation → daily-note entry → done

### Single-User Investigation (Small)
- **Scaffolding**: STATE.md + staging dir; `neo-session-ids: [<session>]` populated in frontmatter
- **Research**: 1-3 /neo calls (user lookup → sign-in logs → risky-user state, or similar chain)
- **Plan**: Flat checklist (3-7 steps), acceptance criteria inline in STATE.md
- **Build**: 1 builder agent OR direct in-session via `/neo`; produces investigation summary at `hub/staging/{task-id}/investigation-{user-slug}.md`
- **Verification**: Manual review by Tyler; SME optional
- **Artifact chain**: intent → /neo evidence chain → investigation writeup → done

### Threat Hunt (Medium)
- **Scaffolding**: STATE.md + staging dir + `neo-results/` cache directory; `neo-session-ids: []` may grow as hunt iterates
- **Research**: 1 gatherer wave (compressed if Neo provides primary evidence; otherwise external threat intel via WebSearch); 1-3 /neo rounds for KQL hunt + corroboration
- **Plan**: Full 16-section plan (scope-gated for Medium); Build Path includes explicit /neo invocations with expected tool calls + cache-key slugs
- **Build**: 1-2 builder agents; one /neo round per hypothesis; correlate results in builder summary; update `hub/state/active-tasks.md` only via STATE.md frontmatter change
- **Verification**: 3-tier — query syntax (KQL parses, no obvious errors) → Neo round-trip (queries returned data) → correlation (findings cross-reference correctly)
- **Artifact chain**: hypothesis → research → plan → /neo evidence chain → hunt writeup → SME assessment → docs

### Incident Response (Large)
- **Scaffolding**: STATE.md + staging dir + per-phase subdirs + ADRs for major decisions (containment scope, notification timing); backward-compat matrix only if existing detections are tuned during IR
- **Research**: 1 gatherer wave, 2-4 rounds; must include — alert source review, entity inventory (users/hosts/indicators), timeline reconstruction; Neo is the primary evidence-gathering surface
- **Plan**: Hub plan (full 16-section), phase-level detail, 10-30 tasks; foundation-first ordering (containment plan before any destructive action)
- **Build**: Sequential builders, foundation-first gate (containment APPROVED before any /neo destructive call), max 6 agents/wave, single-session if possible
- **Verification**: 3-tier + 1 verifier pass + post-containment validation (`get_machine_isolation_status` confirms isolate took effect; `get_user_info` confirms password reset propagated)
- **Artifact chain**: alert → triage → plan → containment ADR → /neo destructive calls (with Tyler-confirmation gates) → post-containment verify → IR report → docs
- **Foundation gate**: Containment plan must be APPROVED by Tyler before any destructive `/neo` call fires
- **Session span**: Single session preferred; multi-session via HANDOFF.md if breach is large
- **Tyler checkpoints**: Before each destructive call (isolate, reset, block); after each containment phase

### Breach Response (Ultra)
- **Scaffolding**: STATE.md + staging dir + per-subsystem specs (one per affected system: identity, endpoint, email, network) + ADRs for ALL decisions + HANDOFF.md (mandatory) + executive-briefing template
- **Research**: 2 gatherer waves (broad survey of attacker activity + focused timeline reconstruction); 3-5 rounds each; cross-reference with vendor advisories, threat intel feeds, and prior-incident archives
- **Plan**: Hub plan + per-subsystem specs in `staging/{task-id}/subsystems/`; 30-80+ tasks; subsystem-impact matrix showing cross-system blast radius; Phasing Strategy with explicit notification milestones (legal, comms, clients, regulators)
- **Build**: Phased parallel builders, per-phase verification gates, max 8 agents/wave, cross-session; affected systems may require parallel containment + recovery; old (compromised) state is forensically preserved at all times
- **Verification**: 3-tier + per-phase verifier + regression gates (containment in subsystem A doesn't break subsystem B) + cross-subsystem integration + end-to-end recovery validation
- **Artifact chain**: detection → broad research → focused research → executive brief → IR plan → ADRs → subsystem specs → phased containment → /neo destructive calls (heavily Tyler-gated) → recovery validation → post-incident review → docs
- **Foundation gate**: Each subsystem phase must PASS its phase gate before the next subsystem begins; legal/comms gates run in parallel with technical phases
- **Session span**: Multi-session — HANDOFF.md updated at every session boundary; resume checklist includes — verify containment still in effect, verify forensic evidence preserved, verify executive brief is current
- **Tyler checkpoints**: After every major phase; before any destructive containment; before any external-party notification

---

## Wave Sequences

| Sub-Protocol | Wave Sequence |
|---|---|
| Quick SOC Question | [/neo] |
| Single-User Investigation | [/neo (1-3 rounds)] -> [documenter (daily-note entry only)] |
| Threat Hunt (Medium) | [gatherer (compressed)] -> [planner] -> [builder + /neo (2-3 rounds)] -> [sme-assessor] -> [documenter] |
| Incident Response (Large) | [gatherer (1 wave)] -> [planner (hub plan)] -> [containment ADR] -> [builder + /neo + Tyler-gated destructive (2-4 rounds)] -> [post-containment verifier] -> [documenter] |
| Breach Response (Ultra) | [gatherer (broad)] -> [gatherer (focused)] -> [planner (hub+subsystems)] -> [builder (Phase 1: containment)] -> GATE -> [builder + /neo (Phase 2: recovery)] -> GATE -> [builder (Phase N: hardening)] -> GATE -> [post-incident review] -> [documenter] |

---

## Acceptance Criteria Template

EODIC criteria templates for SOC work. The key difference from Code Protocol: verification favors observable signals from real systems (a Sentinel query returns expected rows, an Entra user has expected state, a Defender alert resolves correctly) over unit test coverage.

### Quick SOC Question
- [ ] /neo invocation logged to today's daily note with `#neo` tag and session id: `grep -c '#neo' notes/.../{date}.md` returns >= 1
- [ ] Response addresses the user's actual question (Tyler ack)

### Single-User Investigation
- [ ] All Neo session ids captured in STATE.md `neo-session-ids:` field
- [ ] Investigation writeup exists at expected path: `test -f hub/staging/{task-id}/investigation-{slug}.md`
- [ ] Writeup cites every Neo tool used (`run_sentinel_kql`, `get_user_info`, etc.) with timestamp + session id
- [ ] Risk verdict captured (HIGH / MEDIUM / LOW / NO-FINDING) with confidence rationale

### Threat Hunt
- [ ] Hypothesis captured in STATE.md macro goal (testable, falsifiable)
- [ ] All KQL queries used parse without syntax errors (verify via `neo prompt --json` returning a `tool_result` with no error event)
- [ ] Hunt writeup includes: hypothesis, queries used, corroborating data, verdict (CONFIRMED / PARTIAL / DISPROVED), recommended detection if confirmed
- [ ] All entities flagged (if any) have a follow-up action recorded in STATE.md `pending-decisions:` or roadmap

### Incident Response
- [ ] Containment ADR exists and is APPROVED before any destructive /neo call
- [ ] Every destructive call paired with a confirmation gate (Tyler-typed `yes` per Neo's confirmation prompt)
- [ ] Post-containment verification runs (`get_machine_isolation_status` for isolate; `get_user_info` for password reset; `list_indicators` for block_indicator) and confirms intended state
- [ ] IR report includes timeline (with timestamps), entities (users/hosts/indicators), actions taken (with confirmation evidence), and lessons learned
- [ ] Post-IR roadmap entry created if any detection/policy gaps surfaced

### Breach Response
- [ ] HANDOFF.md exists and is current at every session boundary; `## Neo Sessions` section enumerates all in-flight Neo conversations
- [ ] Per-subsystem specs in `hub/staging/{task-id}/subsystems/` (one per affected system); each has its own acceptance criteria
- [ ] Containment verified across ALL subsystems before recovery begins
- [ ] Forensic evidence preserved (full NDJSON of every /neo invocation captured to `hub/staging/{task-id}/neo-results/`)
- [ ] Executive briefing artifact exists and was reviewed by Tyler before any external-party notification
- [ ] Post-incident review covers: timeline, attacker TTPs, detection gaps, response effectiveness, action items with owners + due dates

---

## SME Personas

Security-specific expert identities. The SOC framing is essential — these reviewers must understand attacker TTPs, MITRE ATT&CK mappings, real-world IR pacing, not just generic "is this technically correct?" review.

- **Primary (investigation review)**: Senior SOC Analyst (7+ years L2/L3 in MDR or in-house SOC) — validates query logic, IOC analysis, false-positive rate intuition, MITRE ATT&CK mappings, attribution claims, and that the investigation answers the actual question (not a related-but-different one)
- **Secondary (threat intel + DFIR)**: Threat Intel Analyst with DFIR experience — validates threat-actor attribution, TTP fingerprinting, IOC quality, retrospective hunt coverage, and that the hunt didn't miss obvious adjacent indicators
- **Tertiary (Large required, Ultra required)**: Incident Commander — validates IR pacing, containment scope (not too broad, not too narrow), notification sequencing (legal/comms/clients/regulators), executive-briefing clarity, and that lessons-learned actually map to durable changes (not just "be more careful next time")

---

## Verification Gates

Security-specific 3-tier gates. Unlike Code Protocol which focuses on test coverage, Security Operations Protocol focuses on **observable signals from real systems**. Gates are cumulative and blocking — a later tier cannot pass if an earlier tier failed.

### Tier 1 (Query / Syntax) — blocking
- All KQL queries parse without syntax errors: `neo prompt --json` returns a `tool_result` event with no `error` field for each `run_sentinel_kql` invocation
- All Defender XDR / Entra / Abnormal / ThreatLocker / Lansweeper / AppOmni queries use valid entity types (the agent rejects unknown entity types loudly via Neo's tool input validation)
- All STATE.md `neo-session-ids:` entries are valid UUIDs (or null)
- All /neo invocations referenced in artifacts have a `#neo`-tagged daily-note entry with matching session id

### Tier 2 (Neo Round-Trip) — blocking, cumulative
- /neo skill activates when invoked (no skill-resolution failure)
- Each /neo invocation completes with a `response` event (no premature stream termination)
- For destructive calls: confirmation gate fires (`exit 1` + `paused for confirmation` stderr); Tyler interactively resumes via `neo --session <id>`
- For 80%-budget warnings: skill surfaces them and Tyler is informed before continuing
- For 429 rate-limit: skill surfaces the error with the specific window (2-hour vs weekly) and Tyler decides whether to wait or escalate

### Tier 3 (Containment / Validation) — blocking, cumulative
- For investigations: a verifier independently re-queries the key entities and corroborates the writeup's claims
- For containment actions: post-action validator confirms intended state (`get_machine_isolation_status`, `get_user_info`, `list_indicators`)
- For breach response: cross-subsystem integration check — containment in one subsystem doesn't break legitimate operations in another
- For all sub-protocols: no Neo credential leaks anywhere — covers both auth paths. (a) `grep -rE 'NEO_API_KEY\s*=\s*[a-zA-Z0-9]{12,}' .claude/ docs/ hub/ memory/` returns 0 matches (API-key fallback path); (b) no `~/.neo/config.json` content (Entra token, refresh token, or session) appears in any project file. The Entra path is canonical post-2026-04-28; both checks remain since either credential type is bearer-equivalent if exposed.

---

## Agent Return Protocol Extensions

| Field | Required For | Description |
|-------|-------------|-------------|
| NEO_INVOCATIONS | All sub-protocols | List of `{session_id, query_summary, tool_calls_count, outcome}` for every /neo call this round |
| NEO_BUDGET_REMAINING | Medium+ | Last `usage` event's input/output/cache_read counts; if any >= 80% of budget, FLAG to Tyler |
| CONTAINMENT_ACTIONS | Large+ | List of destructive Neo tool names invoked + confirmation evidence (timestamp, Tyler-typed yes) |
| FORENSIC_EVIDENCE | Ultra only | Path list to all captured NDJSON + sidecar `.meta.json` under `hub/staging/{task-id}/neo-results/` |
| EXTERNAL_NOTIFICATIONS | Ultra only | List of external parties notified (legal / comms / clients / regulators) with timestamps + content references |

---

## Changelog

| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-27T09:38 | 2026-04-24-neo-skill-onboarding | builder (Wave 5 R1, applied by orchestrator) | Created initial security.md profile. Frontmatter: 19 ERE triggers, 4 plain-string anti-triggers, always-activate-skills includes /neo. Body: 5 sub-protocols (Quick SOC Question / Single-User Investigation / Threat Hunt / Incident Response / Breach Response) with foundation gate at Large+; SME personas (Senior SOC Analyst primary, Threat Intel + DFIR secondary, Incident Commander tertiary required at Large+); Verification Gates 3-tier (query syntax / Neo round-trip / containment validation); Agent Return Protocol Extensions for NEO_INVOCATIONS/NEO_BUDGET_REMAINING/CONTAINMENT_ACTIONS/FORENSIC_EVIDENCE/EXTERNAL_NOTIFICATIONS. T5b deliverable for AC4 + AC5. |
