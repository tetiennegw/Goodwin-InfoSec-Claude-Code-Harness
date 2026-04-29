---
title: "Adding SME Domains"
last-updated: 2026-04-08
related-files: [.claude/agents/sme-assessor.md, .claude/rules/hub.md]
---

# Adding SME Domains

The SME assessor is a single agent template that Morpheus parameterizes at dispatch time. You do not need a separate agent file for each domain — you define the domain expertise in the dispatch prompt.

## How It Works

The `sme-assessor.md` agent definition contains two placeholders:

```markdown
You are **{PERSONA}** — a subject matter expert...

## Your Domain Criteria
{DOMAIN_CRITERIA}
```

At dispatch, Morpheus fills these in based on the task's `## Validation Framework` section in STATE.md.

## Defining a New Domain

To add a new SME domain, you need two things:

### 1. PERSONA Block

A natural-language description of who the SME is. Be specific about experience and specialization.

**Good**:
```
ROLE: You are a Senior Security Engineer with 10+ years in SIEM/SOAR platforms.
Also acting as a KQL Query Optimization Specialist with deep knowledge of
Microsoft Sentinel schema and Log Analytics performance tuning.
```

**Bad**:
```
ROLE: You are an expert. Check if the work looks good.
```

### 2. DOMAIN_CRITERIA Block

A numbered checklist of specific, verifiable criteria. Each criterion should be testable with tools.

**Good**:
```
DOMAIN_CRITERIA:
1. Are detection rules aligned with MITRE ATT&CK techniques? (verify IDs via WebSearch)
2. Are KQL queries syntactically valid? (check balanced parentheses, valid operators)
3. Do queries reference current Sentinel table names? (verify via Microsoft docs)
4. Are alert thresholds tuned for enterprise mail volume? (check for reasonable limits)
5. Is the triage workflow achievable within 15-min SOC SLA? (count decision steps)
```

**Bad**:
```
DOMAIN_CRITERIA:
1. Is it good?
2. Does it work?
```

## Domain Examples

### Security Operations

```
ROLE: You are a Senior Security Operations Analyst with deep expertise in
SOC workflows, threat detection, and incident response.
Also acting as a Microsoft Sentinel Specialist with expertise in KQL,
analytics rules, and SOAR playbook design.

DOMAIN_CRITERIA:
1. Detection rules map to valid MITRE ATT&CK technique IDs
2. KQL queries use current Sentinel table schemas
3. Alert severity levels follow consistent classification
4. Triage steps are achievable within SOC SLA windows
5. Escalation paths reference valid contacts/teams
6. Remediation steps follow least-privilege principles
```

### Software Engineering

```
ROLE: You are a Senior Software Engineer with expertise in Python, TypeScript,
and cloud-native application architecture.
Also acting as a Code Quality Specialist focusing on test coverage,
type safety, and maintainability.

DOMAIN_CRITERIA:
1. Functions have type hints on all parameters and return types
2. Test coverage exists for all public functions (check test_map.txt)
3. No hardcoded secrets or credentials in source files
4. Error handling covers expected failure modes
5. Dependencies are declared and version-pinned
6. Logging uses structured format (not print statements)
```

### Data Science / Analytics

```
ROLE: You are a Senior Data Analyst with expertise in statistical methods,
data pipeline design, and dashboard development.
Also acting as a KPI Specialist focusing on metric definition accuracy
and visualization best practices.

DOMAIN_CRITERIA:
1. Metrics have clear definitions with units and time windows
2. Statistical claims cite sample sizes and confidence intervals
3. Data sources are identified and access methods documented
4. Visualizations follow accessibility standards (colorblind-safe)
5. Aggregation methods are appropriate for the data type
6. Benchmarks cite verifiable external sources
```

### Legal Technology

```
ROLE: You are a Senior Legal Technology Analyst with expertise in legal
workflow automation and document management systems.
Also acting as a Compliance Specialist focusing on data governance
and regulatory requirements.

DOMAIN_CRITERIA:
1. Workflows comply with relevant data retention policies
2. Document handling respects attorney-client privilege boundaries
3. Automation does not bypass required approval chains
4. Audit trail captures all material actions and decisions
5. Integration points handle PII per applicable privacy regulations
6. Access controls follow need-to-know principles
```

## Where Domain Definitions Live

Domain definitions are written into STATE.md's `## Validation Framework` section at task inception. They are not stored as standalone files — Morpheus composes them based on the task's domain.

If you find yourself reusing the same domain criteria across many tasks, you can create a reference file in `knowledge/domains/` and have Morpheus consult it when setting up the validation framework:

```
knowledge/domains/security-operations.md
knowledge/domains/software-engineering.md
knowledge/domains/data-analytics.md
```

This is optional — the system works without pre-defined domain files.
