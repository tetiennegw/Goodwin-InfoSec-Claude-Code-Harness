---
type: deliverable
task-id: "{TASK_ID}"
agent: builder
created: "{YYYY-MM-DD HH:MM}"
last-updated: "{YYYY-MM-DD HH:MM}"
inputs:
  - "{path/to/plan-artifact.md}"
  - "{path/to/research-artifact.md}"
plan-step: "{Task N from plan}"
---

# Build: {Deliverable Title}

> This template shows two variants: a **markdown deliverable** (runbooks, KB articles, docs) and a **code file comment header** (scripts, configs, queries). Use whichever fits the deliverable type.

---

## Variant A: Markdown Deliverable

Use this format for runbooks, knowledge articles, process documentation, and other prose deliverables.

```markdown
---
type: runbook
title: Phishing Triage Runbook
version: "1.0"
author: builder (via Morpheus orchestrator)
created: 2026-04-07
last-reviewed: 2026-04-07
owner: {{user.name}} ({{user.email}})
tags: [phishing, triage, incident-response, sentinel, proofpoint]
---

# Phishing Triage Runbook

## 1. Preparation

### Prerequisites
- Access to Microsoft Sentinel workspace (Log Analytics)
- Proofpoint TAP dashboard access (read + quarantine permissions)
- Microsoft Defender for Office 365 admin access
...

## 2. Detection & Analysis

### KQL Detection Queries

#### Query 1: Suspicious URL Clicks from Email
...

## Changelog

| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-07 14:00 | phishing-runbook | builder | Initial runbook — Preparation + Detection phases complete |
```

---

## Variant B: Code File Comment Header

Use this format for scripts, KQL query files, configuration files, and other code deliverables. Place this header block at the top of the file.

```kql
// ============================================================
// File: kql-phishing-detection-queries.kql
// Task: 2026-04-07-phishing-runbook
// Plan Step: Task 2 — Detection & Analysis Phase with KQL Queries
// Agent: builder
// Created: 2026-04-07
// Inputs: research-phishing-frameworks.md, plan-phishing-runbook.md
// ============================================================

// Query 1: Suspicious URL Clicks — T1566.002 (Spearphishing Link)
// Severity: High | Expected FP Rate: Low
// Description: Detects users clicking URLs in emails where the domain
//   was registered within the last 30 days.
EmailEvents
| where Timestamp > ago(24h)
| join EmailUrlInfo on NetworkMessageId
| where UrlDomain has_any (
    ThreatIntelligenceIndicator
    | where ThreatType == "url"
    | distinct DomainName
)
| project Timestamp, RecipientEmailAddress, SenderFromAddress, Subject, Url
| sort by Timestamp desc

// ...additional queries...

// Changelog:
// 2026-04-07 14:30 | phishing-runbook | builder | Initial 5 KQL detection queries created
```

---

## Variant C: PowerShell Hook (`.claude/hooks/*.ps1`)

Use this variant for any new lifecycle hook. **Do NOT use Variant B (generic code header) for hooks** — Goodwin endpoints require additional scaffolding (bash-fallback writer for ThreatLocker Storage Control + signing + settings registration) that the generic template lacks.

**Always start with the scaffold:**

```
/script-scaffold powershell-hook <hook-name> [description]
```

The scaffold writes to `.claude/hooks/<hook-name>.ps1` with:
- Standard header block (Hook / Lifecycle Event / Matcher / Purpose / Task / Created / Dependencies / Changelog)
- `Write-FileViaBashFallback` function (mandatory — see `.claude/rules/scripts.md` § PowerShell hooks)
- Stdin JSON parse skeleton
- Ledger-append block with the try/catch + bash-fallback wrap baked in

**Required next steps after scaffolding:**

1. Implement the hook-specific logic between the stdin parse and the ledger append.
2. `/sign-script .claude/hooks/<hook-name>.ps1` — Goodwin Authenticode signature is mandatory before any execution attempt (AllSigned + ThreatLocker Application Control).
3. Register in `.claude/settings.local.json` under the appropriate event + matcher with `timeout` 5000–10000 ms.
4. Smoke-test by triggering the lifecycle event from a real tool use; confirm a PLANCOMP/TASKDISC/RESULT row appears in `hub/state/harness-audit-ledger.md`. **A hook that "ran without error" but produced no ledger row is a silent failure** — investigate the bash-fallback path before declaring done.
5. Re-sign on every edit (signing invalidates on byte-level changes).

See `.claude/hooks/plan-compliance-audit.ps1` and `.claude/hooks/protocol-execution-audit.ps1` as reference implementations of the full pattern.

---

## Builder Notes

- Always write the deliverable to the **output path specified in the plan** (the `Output Files` section).
- Follow the plan's **Build Path** tasks in order — each task has specific inputs, subtasks, and validation criteria.
- Run the plan's **TDD tests** after completing each task to validate before moving on.
- Include a **Changelog** entry at the bottom of every deliverable file.
- For hook builds: use Variant C above (do NOT hand-write a hook from Variant B).
- Return a 6-10 sentence summary to the orchestrator covering: what was built, which plan tasks were completed, test results, output paths, and any issues encountered.

## Changelog

| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-07 14:00 | phishing-runbook | builder | Template reference — shows both markdown and code variants |
