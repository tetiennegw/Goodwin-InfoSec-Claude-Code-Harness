---
type: research
task-id: "{TASK_ID}"
agent: gatherer
created: "{YYYY-MM-DD HH:MM}"
last-updated: "{YYYY-MM-DD HH:MM}"
inputs:
  - "{path/to/input-file-1.md}"
  - "{path/to/input-file-2.md}"
---

# Research: {Topic Title}

## Sources Consulted

| # | Source | Type | Accessed | Relevance |
|---|--------|------|----------|-----------|
| 1 | NIST SP 800-61 Rev 2 — Computer Security Incident Handling Guide | Framework/Standard | 2026-04-06 | High — defines 4-phase IR model used as structural backbone |
| 2 | SANS Institute — Phishing Incident Response Playbook (2025) | Industry Guide | 2026-04-06 | High — provides SOC-specific triage workflow |
| 3 | Cofense 2025 Annual Phishing Report | Vendor Report | 2026-04-06 | Medium — current phishing trend data and detection rates |
| 4 | Internal: kb/security/email-gateway-config.md | Internal Doc | 2026-04-06 | High — confirms Proofpoint TAP as email gateway |
| 5 | Microsoft Sentinel Documentation — KQL for email events | Vendor Docs | 2026-04-06 | High — KQL table names and schema for email-related detections |

## Findings

### 1. NIST 4-Phase Incident Response Model

NIST SP 800-61 defines four phases: Preparation, Detection & Analysis, Containment/Eradication/Recovery, and Post-Incident Activity. This model is widely adopted and maps well to SOC automation workflows.

**Evidence**: NIST SP 800-61 Rev 2, Section 3.1 — "Organizations should follow a structured approach to incident handling that includes preparation, detection and analysis, containment, eradication, recovery, and post-incident activity."

### 2. Proofpoint TAP Integration Points

Goodwin uses Proofpoint Targeted Attack Protection (TAP) as its email security gateway. The TAP API v2 exposes `/v2/siem/messages/blocked` and `/v2/siem/messages/delivered` endpoints relevant to phishing detection.

**Evidence**: Internal file `kb/security/email-gateway-config.md` confirms Proofpoint TAP deployment. Proofpoint TAP API documentation describes SIEM-compatible endpoints.

### 3. Sentinel KQL Detection Patterns

Microsoft Sentinel's `EmailEvents` and `EmailUrlInfo` tables provide the primary data surfaces for phishing detection queries. Common patterns include URL reputation scoring, sender domain age analysis, and attachment hash matching.

**Evidence**: Microsoft Sentinel documentation — AdvancedHunting schema reference for EmailEvents table.

## Key Takeaways

1. **NIST 4-phase model** provides the best structural foundation for a phishing triage runbook — it is the industry standard and maps to Goodwin's existing SOC workflow categories.
2. **Proofpoint TAP API** is the primary email telemetry source — detection queries should leverage TAP SIEM endpoints before falling back to native Sentinel email tables.
3. **KQL detection queries** should target `EmailEvents`, `EmailUrlInfo`, and `EmailAttachmentInfo` tables in Sentinel for phishing-specific hunting.
4. **SOC triage SLAs** from SANS suggest a 15-minute initial triage target for phishing reports — the runbook should be designed to support this cadence.
5. **Gap identified**: Current SOC shift structure is unknown — this affects escalation path design in the runbook.

## Gaps Identified

- **SOC shift structure**: Could not determine current SOC team shifts or on-call rotation. This impacts escalation procedures in the runbook. Recommend asking Tyler.
- **Proofpoint TAP license tier**: Unknown whether Goodwin has TAP Premium (which includes URL defense forensics) or TAP Standard. This affects available API endpoints.
- **Existing runbook inventory**: No existing phishing runbook found in the knowledge base — confirming this is a net-new deliverable.

## Relevance to Macro Goal

This research directly supports the macro goal of building a phishing triage runbook for the SOC team. The NIST framework provides structure, the Proofpoint TAP integration provides detection capability, and the Sentinel KQL patterns provide the query foundation. The identified gaps (SOC shifts, TAP tier) should be resolved before the planning wave begins.

## Changelog

| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-06 14:30 | phishing-runbook | gatherer | Initial research artifact created with 5 sources, 3 findings, 3 gaps |
