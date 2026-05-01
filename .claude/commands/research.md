---
description: Create a research artifact — investigate a topic with structured findings, sources, and gaps
user-invocable: true
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch, TaskCreate, TaskUpdate]
schema-version: 1
---
# Research

Investigate a topic and produce a structured research artifact.

**Usage**: `/research <research-topic>`

## Step 1: Parse Arguments
- The research topic is provided in `$ARGUMENTS`.
- If no topic is provided, ask Tyler what to research.
- Generate a slug from the topic (lowercase, hyphens, no special chars).

## Step 1b: Neo Delegation Check (Neo-Aware)
Before setting up the workspace, evaluate whether the research topic warrants live SOC data from Neo:
- **Trigger keywords** (case-insensitive): Sentinel, Defender, Entra, Abnormal, ThreatLocker, Lansweeper, AppOmni, SOC, IR, MITRE, IOC, threat intel, phishing, incident, alert, KQL, identity risk, risky user, isolate, containment, indicator
- **Scope gate**: only fire for scope >= Small (skip for Passthrough-scope research — no AskUserQuestion overhead for quick lookups).
- **If triggered AND scope >= Small**: fire `AskUserQuestion` before Step 2 with:
  - Question: "This research topic contains security-ops keywords. Delegate to /neo for live SOC data instead of (or in addition to) static research?"
  - Options: `/neo` (Recommended) | Static research only | Both — run /neo first, then synthesize
  - If Tyler chooses `/neo` or Both: invoke the `/neo` skill with the research topic as the query, then continue or skip Step 3 as appropriate.

## Step 2: Set Up Workspace
- Determine or create a task-id: `YYYY-MM-DD-research-{slug}`.
- Create staging directory if needed: `hub/staging/{task-id}/`.
- Create `STATE.md` in the staging directory with:
  - Macro goal: Research {topic}
  - Validation framework: sources verified, claims cross-referenced, gaps identified
  - Wave plan: Wave 1 = Research gathering, Wave 2 = Synthesis and documentation

## Step 3: Dispatch Gatherer Agent
Dispatch the gatherer agent (`.claude/agents/gatherer.md`) with:

```
TASK: Research "{topic}" — gather structured findings with sources
TASK_ID: {task-id}
STATE_FILE: hub/staging/{task-id}/STATE.md
INDEX_FILE: INDEX.md
INPUT FILES:
- (any relevant existing KB articles identified via INDEX.md)
OUTPUT:
- Write to: hub/staging/{task-id}/wave-1/round-1/research-{slug}.md
- Use research artifact template with sections:
  - Executive Summary
  - Key Findings (numbered, with source citations)
  - Sources (with URLs, access dates, reliability ratings)
  - Gaps and Open Questions
  - Recommendations
- Include YAML frontmatter (type: research, task-id, agent: gatherer, timestamps)
- Include changelog entry
CONSTRAINTS:
- Verify all sources exist via WebSearch
- Cross-reference claims across multiple sources
- Flag low-confidence findings explicitly
- Return 6-10 sentence summary
```

## Step 4: Document
- Add a timeline entry to today's daily note with `#research` tag.
- Update `INDEX.md` with the new research artifact.
- Update `TaskUpdate` when research is complete.

## Rules
- Research artifacts are NEVER final deliverables — they feed into planning and build waves.
- All claims must have source citations. Unsourced claims get flagged.
- The gatherer returns a summary to Morpheus; the full content lives in the artifact file.
