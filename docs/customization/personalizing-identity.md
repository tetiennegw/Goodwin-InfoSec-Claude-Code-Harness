---
title: "Personalizing Identity"
last-updated: 2026-04-08
related-files: [CLAUDE.md, memory/user_profile.md, memory/company_context.md]
---

# Personalizing Identity

CLAUDE.md is the agent's identity file. Customizing it correctly is the most important step when forking the Morpheus foundation.

## What to Change

### 1. Identity Section

Replace the identity block with your information:

```markdown
## Identity
You are Morpheus, {YOUR_NAME}'s orchestration agent. {YOUR_NAME} is a
{YOUR_ROLE} at {YOUR_ORG} (started {DATE}, {EMAIL}).
```

### 2. Agent Name (Optional)

You can rename "Morpheus" to anything. Just update it consistently in CLAUDE.md. Agent definitions reference "Morpheus" as "the orchestrator agent" — update those too if you rename.

## What to Keep Unchanged

These sections are structural and should not be modified unless you understand the implications:

- **"You are a pure orchestrator"** directive — removing this causes the agent to do work directly instead of dispatching
- **Core Pillars** — curiosity, verification, first-principles awareness
- **Orchestration Loop** — the wave/round protocol
- **Scope Table** — scope levels and their parameters
- **Available Agents table** — unless you add/remove agents
- **Context Engineering Rules** — these prevent token overflow
- **Standards** — changelog, validation, summary, hook header formats

## Role-Specific Examples

### Security Analyst

```markdown
## Identity
You are Morpheus, Jane Smith's orchestration agent. Jane is a Security
Analyst at Acme Financial (started 2026-01-15, jsmith@acmefinancial.com).

She focuses on threat detection, incident response, and SIEM optimization.
Her team runs Microsoft Sentinel + CrowdStrike Falcon.
```

### Software Engineer

```markdown
## Identity
You are Jarvis, Alex Chen's orchestration agent. Alex is a Senior
Software Engineer at TechCorp (started 2025-06-01, achen@techcorp.io).

Alex works on backend services in Python and TypeScript. The team uses
AWS, PostgreSQL, and GitHub Actions for CI/CD.
```

### Data Scientist

```markdown
## Identity
You are Atlas, Maria Garcia's orchestration agent. Maria is a Data
Scientist at HealthTech Labs (started 2025-09-01, mgarcia@healthtech.com).

Maria builds predictive models for clinical trial outcomes. The team
uses Python (pandas, scikit-learn, PyTorch), Databricks, and Snowflake.
```

### Legal Technology Analyst

```markdown
## Identity
You are Morpheus, Pat Williams' orchestration agent. Pat is a Legal
Technology Analyst at BigLaw Partners (started 2026-02-01, pwilliams@biglaw.com).

Pat manages document automation, e-discovery workflows, and legal research
tools. The team uses iManage, Relativity, and Westlaw Edge.
```

## Memory Files

In addition to CLAUDE.md, update these memory files:

### memory/user_profile.md

Persistent facts about you:

```markdown
# User Profile
- Name: Jane Smith
- Role: Security Analyst
- Email: jsmith@acmefinancial.com
- Team: Threat Detection
- Expertise: SIEM, KQL, incident response, threat hunting
- Preferences: Concise output, prefers tables over prose, wants MITRE mappings on all detections
- Working hours: EST, 9am-6pm
```

### memory/company_context.md

Your team's technology environment:

```markdown
# Company Context
- Organization: Acme Financial
- Industry: Financial Services (FINRA/SEC regulated)
- Security Stack: Microsoft Sentinel, CrowdStrike Falcon, Proofpoint
- Cloud: Azure (primary), AWS (data lake)
- Identity: Azure AD (Entra ID)
- Ticketing: ServiceNow
- Communication: Microsoft Teams
- Code: GitHub Enterprise
- Compliance: SOX, PCI-DSS, NIST CSF
```

This context helps agents produce output tailored to your actual environment rather than generic advice.
