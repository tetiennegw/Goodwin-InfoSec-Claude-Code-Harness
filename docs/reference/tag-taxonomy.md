---
title: "Tag Taxonomy"
last-updated: 2026-04-08
related-files: [hub/templates/daily-note.md]
---

# Tag Taxonomy

Tags are used in daily note timeline entries to enable filtering and searching across the work log. Tags are flexible — new ones emerge naturally from work. The lists below seed the standard vocabulary.

## Tag Categories

### Domain Tags

What area of work this relates to.

| Tag | Description |
|-----|------------|
| `#security` | Security operations, threat detection, incident response |
| `#automation` | Workflow automation, scripting, SOAR |
| `#api` | API integrations, endpoint development |
| `#compliance` | Regulatory compliance, audit, policy |
| `#infrastructure` | Network, cloud, system architecture |

### Action Tags

What type of work was performed.

| Tag | Description |
|-----|------------|
| `#research` | Information gathering, investigation |
| `#plan` | Planning, requirements, design |
| `#build` | Creating deliverables, coding, writing |
| `#review` | Assessment, verification, code review |
| `#document` | Documentation updates, KB articles |
| `#incident` | Incident response activities |

### Tool Tags

Which tools or platforms were involved.

| Tag | Description |
|-----|------------|
| `#sentinel` | Microsoft Sentinel, Log Analytics |
| `#defender` | Microsoft Defender for Office 365 / Endpoint |
| `#crowdstrike` | CrowdStrike Falcon |
| `#python` | Python scripts or tooling |
| `#powershell` | PowerShell scripts or tooling |
| `#kql` | Kusto Query Language |

### Status Tags

Current state of the work.

| Tag | Description |
|-----|------------|
| `#started` | Work has begun |
| `#completed` | Work is finished and verified |
| `#blocked` | Waiting on external input or access |
| `#flagged` | Needs Tyler's attention |

### Scope Tags

Matches the task's scope level.

| Tag | Description |
|-----|------------|
| `#mini` | Mini scope task |
| `#small` | Small scope task |
| `#medium` | Medium scope task |
| `#large` | Large scope task |
| `#ultra` | Ultra scope task |

## Usage in Timeline Entries

Tags appear at the end of the entry header line:

```markdown
### 14:30 | builder | [2026-04-08-phishing-runbook] | #security #build #sentinel #kql #medium
Built phishing triage runbook with 5 KQL detection queries.
-> [phishing-triage-runbook.md](../../kb/runbooks/phishing-triage-runbook.md)
```

## Filtering with Grep

Find all entries related to a domain:
```bash
grep -rn "#security" notes/
```

Find all completed work:
```bash
grep -rn "#completed" notes/2026/04/
```

Find all KQL-related work in April:
```bash
grep -rn "#kql" notes/2026/04/
```

Find all flagged items requiring attention:
```bash
grep -rn "#flagged" notes/
```

Combine tags for precise filtering:
```bash
grep -rn "#security.*#build" notes/2026/04/
```

Find all large-scope tasks:
```bash
grep -rn "#large" notes/
```

## Adding New Tags

New tags can be introduced at any time. Follow these conventions:

1. Use lowercase, single-word tags prefixed with `#`
2. Prefer existing tags where they fit
3. Domain-specific tools get their own tool tags (e.g., `#proofpoint`, `#splunk`)
4. If a new tag is used 3+ times, add it to this reference document
5. Tags should be specific enough to be useful in grep but general enough to apply across tasks
