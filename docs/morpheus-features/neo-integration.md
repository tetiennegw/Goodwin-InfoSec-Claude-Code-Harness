---
type: feature-doc
feature-name: neo-integration
owner: orchestrator
created: 2026-04-28
last-updated: 2026-04-28
status: active
audience: {{user.name}} (current); Goodwin security team (future)
tags: [neo, soc-tooling, security, orchestration, peer-tool]
---

# Neo Integration

Neo (Goodwin's internal Claude-powered security agent CLI) is a **first-class peer tool** inside the Morpheus harness. This document covers the architecture, auth model, role boundaries, invocation triggers, security boundaries, and cross-references for the Neo/Morpheus integration.

## Overview

Neo is an AI-powered SOC agent owned and operated by {{team.manager.name}} at Goodwin Procter. It provides approximately 55 read-only and destructive security tools spanning Microsoft Sentinel KQL, Defender XDR, Entra ID, Abnormal Security, ThreatLocker, Lansweeper, and AppOmni. Morpheus delegates security-operations questions to Neo via the /neo skill rather than attempting to answer them directly.

## Architecture

Morpheus --> /neo skill --> neo prompt --json --> Neo server (https://app-neo-prod-001.azurewebsites.net) --> ~55 SOC tools --> NDJSON stream --> /neo parses and formats for Tyler.

### Component Inventory

| Component | Path | Role |
|-----------|------|------|
| /neo skill | .claude/commands/neo.md | Procedural source of truth; invocation protocol |
| Security protocol | .claude/protocols/security.md | Auto-activates on SOC-keyword prompts |
| Neo rule | .claude/rules/neo.md | Auto-loads for neo-adjacent file paths; naming/caching/key safety conventions |
| Prompt context hook | .claude/hooks/prompt-context-loader.sh | SessionStart NEO_API_KEY/config.json health check |
| Feature doc | docs/morpheus-features/neo-integration.md | This file |
| External docs | docs/external/neo/ | Verbatim snapshots of Patrick's user-guide + configuration docs |

## Auth Model

Goodwin's canonical auth path (post 2026-04-28 onboarding):

1. Run: neo auth login
2. Browser opens Microsoft login page (PKCE OAuth2 against Goodwin Entra ID tenant)
3. Tokens saved to ~/.neo/config.json
4. Run: neo config set server https://app-neo-prod-001.azurewebsites.net

**Primary path**: Entra ID via neo auth login. Token stored in ~/.neo/config.json. No API key required for Tyler's interactive use.

**Fallback path**: NEO_API_KEY environment variable. Retained for service-account and automation use cases. Never embed the value in scripts, config files, or artifacts -- reference the env var name only.

**Auth priority** (CLI resolves in this order, first match wins):
1. --api-key flag (dev-only -- never use in production; visible in process table)
2. NEO_API_KEY env var
3. Saved API key in ~/.neo/config.json
4. Saved Entra ID tokens in ~/.neo/config.json

**Server URL**: https://app-neo-prod-001.azurewebsites.net (Azure-hosted; Goodwin root CA compatible). Do NOT use neo.goodwinprocter.com -- bundled-Node TLS chain incompatibility. See Prerequisite D in .claude/commands/neo.md for details.

## Role Boundaries

| Role | Description | Tool access | Message limit/session |
|------|-------------|-------------|----------------------|
| reader | Tyler's role (default) | ~55 read-only tools | 100 messages |
| admin | Destructive actions (password reset, machine isolation) | All tools | 200 messages |
| triage | Logic App service principals | Read-only (same as reader) | N/A (API, not REPL) |

Tyler operates as reader. Destructive tools require admin role and are double-gated: Neo's server-side confirmation REPL prompt AND Morpheus's AskUserQuestion pre-approval.

**Morpheus never auto-confirms destructive actions.** If Neo encounters a destructive tool need in --json mode, it exits 1 with a resume instruction; Morpheus surfaces this to Tyler and waits.

## When Morpheus Offers /neo

Security-operations keywords that trigger a /neo offer (from memory/feedback_neo_offer_on_security_work.md):

Sentinel, KQL, Defender, Entra, Abnormal, phishing, SOC, incident, IR, investigation, alert, user risk, sign-in logs, ThreatLocker, Lansweeper, AppOmni, XDR, MFA, identity risk, password reset, machine isolation, MITRE, IOC, threat intel, indicator of compromise

**Trigger conditions** (all three must be met):
1. One or more keywords above appear in Tyler's prompt
2. Scope >= Small (Passthrough-scope SOC questions may get a /neo offer directly, without full orchestration)
3. The work is primarily SOC investigation / tooling (not content-creation, planning, or coding)

**Offer format**: AskUserQuestion with /neo marked (Recommended). Tyler approves or declines. If approved, Morpheus invokes the /neo skill.

**Passthrough exception**: For pure read-only SOC queries at Passthrough scope, Morpheus may offer /neo directly via AskUserQuestion without entering plan mode. This is the only orchestration-escape permitted.

## Security Boundaries

From skill body section 12 and rule section Key Safety:

1. **Never --api-key flag** -- process table exposure. Use env var or config.json Entra token.
2. **Never auto-confirm destructive tools** -- Neo's REPL prompt is the human-in-the-loop point. /neo skill exit-code-1 handler routes Tyler to interactive resume.
3. **Never commit credentials** -- NEO_API_KEY value must not appear in any artifact, daily note, transcript, or git-tracked file. Only the env var name may appear in documentation.
4. **--json stdout is PII-bearing** -- NDJSON stream passes tool_call events with raw arguments (UPNs, KQL queries, justifications). Never redirect --json stdout to untrusted log collectors or shared storage.
5. **INJECTION_GUARD_MODE=monitor** -- default server-side setting. Neo monitors for prompt injection attempts but allows them through in monitor mode. Do not set to block without confirming false-positive rates with Patrick.
6. **Session IDs in STATE.md / HANDOFF.md only** -- conv_<uuid> session identifiers are correlation handles, not credentials. Store them for cross-session resume but do not log them to chat channels.
7. **Azure URL canonical** -- https://app-neo-prod-001.azurewebsites.net is the Goodwin production endpoint.

## Neo Result Caching

Per .claude/rules/neo.md:

- Cache window: 1 hour for identical queries within a task
- Cache location: hub/staging/{task-id}/neo-results/
- File naming: {timestamp}-{slug}.ndjson + {timestamp}-{slug}.meta.json sidecar
- Cache bypass: neo --no-cache <query> or queries > 24 hours old
- Caching is OFF for destructive actions (always live)

## Cross-References

| Surface | Path | Purpose |
|---------|------|---------|
| /neo skill | .claude/commands/neo.md | Procedural source of truth (invocation, pre-flight, JSON parsing, error handling, security boundaries) |
| Neo rule | .claude/rules/neo.md | Auto-loading conventions (query naming, result schema, caching, key safety, Tyler-approval gates) |
| Security protocol | .claude/protocols/security.md | Domain protocol that activates on SOC-keyword prompts and routes to /neo |
| Prompt context hook | .claude/hooks/prompt-context-loader.sh | SessionStart check: warns if neither ~/.neo/config.json nor NEO_API_KEY is set |
| STATE.md template | hub/templates/state.md | neo-session-ids: field for cross-session resume |
| HANDOFF.md template | hub/templates/handoff.md | ## Neo Sessions section (Ultra scope) |
| Daily-note rule | .claude/rules/daily-note.md | Rule 9: Neo timeline entries MUST include #neo tag and session ID |
| Neo memory (integration) | memory/project_neo_integration.md | Architecture + Phase 1 onboarding flow + canonical auth path |
| Neo memory (offer trigger) | memory/feedback_neo_offer_on_security_work.md | Canonical 20-keyword list + scope gate + AskUserQuestion format |
| Team context | CLAUDE.md Team Context | Neo row: version, auth path, server URL, owner |
| External docs | docs/external/neo/ | Verbatim snapshots of Patrick's user-guide + configuration docs (ingested 2026-04-28) |
| Roadmap follow-ups | hub/state/roadmap.md | 10 queued improvements for post-onboarding work |

## Follow-Up Roadmap Pointer

Seven primary follow-up items plus three Phase-1-derived mini items are recorded in hub/state/roadmap.md under 'Neo Follow-Ups (post-onboarding)'. Key items:
- /incident-triage harness integration (Medium-Large)
- neo-investigator agent type when chained Neo calls become common (Medium)
- /the-protocol Step 5 conditional Neo branch automation (Small)
- NEO credential pre-commit leak scanner (Small)
- Neo banner v2.0 / CLI v1.1.0 version drift resolution (Mini -- Patrick)
- ~/.neo/config.json POSIX mode 644 vs 0600 rule verification (Mini)
- neo not on Git Bash PATH workaround (Mini)

## Changelog

| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-28T12:00 | 2026-04-24-neo-skill-onboarding | documenter (W10R1) | Created initial feature doc. Architecture diagram, auth model (Entra primary + API-key fallback), role boundaries (reader/admin/triage), invocation trigger keywords, security boundaries (7 rules), caching strategy, full cross-reference table, roadmap pointer. |
