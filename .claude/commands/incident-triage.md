---
description: Create an incident triage workspace — initiate incident response documentation
user-invocable: true
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, TaskCreate, TaskUpdate]
schema-version: 1
---
# Incident Triage

Initiate incident response documentation and triage workspace.

**Usage**: `/incident-triage <incident-title>`

## Step 1: Parse Arguments
- The incident title is provided in `$ARGUMENTS`.
- If no title is provided, ask Tyler to describe the incident.
- Generate a slug from the title (lowercase, hyphens, no special chars).

## Step 2: Create Incident File
- Generate filename: `ops/incidents/YYYY-MM-DD-{slug}.md`
- Ensure the `ops/incidents/` directory exists (create if needed).
- Write the incident file with this structure:

```markdown
---
type: incident
incident-id: YYYY-MM-DD-{slug}
severity: TBD
status: INVESTIGATING
created: YYYY-MM-DDTHH:MM
last-updated: YYYY-MM-DDTHH:MM
reporter: {{user.name}}
---
# Incident: {Incident Title}

## Status: INVESTIGATING | Severity: TBD

## Initial Indicators
- {What triggered this investigation}

## Affected Systems
- TBD — pending investigation

## Timeline
| Time | Event | Source |
|------|-------|--------|
| HH:MM | Incident reported | {{user.name}} |

## MITRE ATT&CK Mapping
| Tactic | Technique | ID | Evidence |
|--------|-----------|-----|----------|
| | | | |

## Indicators of Compromise (IOCs)
| Type | Value | Context |
|------|-------|---------|
| | | |

## Containment Actions
- [ ] {Immediate containment steps}

## Root Cause
TBD — pending investigation.

## Remediation
- [ ] {Remediation steps once root cause identified}

## Lessons Learned
<!-- Fill after incident closure -->

## Changelog
| Timestamp | Agent | Change |
|-----------|-------|--------|
| YYYY-MM-DDTHH:MM | morpheus | Incident file created |
```

## Step 3: Register and Track
- Add the incident to `INDEX.md` under an incidents section.
- Create a `TaskCreate` entry for the incident investigation.
- Add a timeline entry to today's daily note:
  ```
  ### HH:MM | morpheus | [{incident-id}] | #incident #security #started
  Incident triage initiated: {incident title}
  -> [incident-{slug}](ops/incidents/YYYY-MM-DD-{slug}.md)
  ```

## Step 4: Prompt Next Steps
Tell Tyler:
- Incident file created at `ops/incidents/YYYY-MM-DD-{slug}.md`
- Severity is set to TBD — ask Tyler to classify (P1-Critical, P2-High, P3-Medium, P4-Low)
- Suggest immediate actions: gather IOCs, check Sentinel for related alerts, identify affected users/systems

## Rules
- Time is critical during incidents. Create the file FAST, refine later.
- Always use UTC timestamps in the incident timeline.
- Never close an incident without Tyler's explicit approval.
- The MITRE ATT&CK mapping should be updated as the investigation progresses.
