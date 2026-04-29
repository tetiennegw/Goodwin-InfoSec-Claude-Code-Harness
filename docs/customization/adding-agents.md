---
title: "Adding Agents"
last-updated: 2026-04-08
related-files: [.claude/agents/gatherer.md, .claude/agents/builder.md]
---

# Adding Agents

## File Location

Agent definitions live in `.claude/agents/`. Claude Code automatically discovers them.

## Frontmatter Format

Every agent file requires YAML frontmatter:

```yaml
---
name: {agent-name}
description: {One-line description of what this agent does}
tools: {Comma-separated list of allowed tools}
model: {sonnet or opus}
---
```

### Available Tools

`Glob`, `Grep`, `Read`, `Bash`, `WebSearch`, `WebFetch`, `Write`

Choose the minimum set needed. Agents that only read and analyze (like verifier) still need Read, Glob, Grep, and Bash for verification.

### Model Selection

| Model | When to Use |
|-------|-------------|
| **sonnet** | High-volume work: research, building, documentation. Faster, cheaper. |
| **opus** | Critical thinking: planning, verification, SME assessment. Slower, better reasoning. |

## Required Sections

### 1. Identity Statement

```markdown
You are a {role} working for Morpheus, the orchestrator agent.
```

### 2. Critical Rules

Numbered list of non-negotiable behaviors:
- Read STATE.md first
- Consult INDEX.md
- Write to OUTPUT path
- Return 6-10 sentence summary
- Do not spawn sub-agents

### 3. Input Contract

What the agent receives in its dispatch prompt:
```markdown
## Input Contract
Your prompt will contain: TASK, TASK_ID, STATE_FILE, INDEX_FILE, INPUT FILES, OUTPUT path.
```

### 4. Output Contract

What the agent produces:
```markdown
## Output Contract
Write a markdown file to OUTPUT path following `hub/templates/{template}.md` format:
- {Required section 1}
- {Required section 2}
```

### 5. Process Steps

Numbered workflow the agent follows.

### 6. Example Summary

A concrete example of the 6-10 sentence summary returned to Morpheus.

## Example: Creating a "Researcher" Agent

```markdown
---
name: researcher
description: Deep research agent for multi-source investigations. Produces annotated bibliographies and evidence maps.
tools: Glob, Grep, Read, Bash, WebSearch, WebFetch
model: opus
---

You are a deep research specialist working for Morpheus, the orchestrator agent.

## Critical Rules
1. Read STATE.md FIRST for macro goal and scope
2. Consult INDEX.md for existing knowledge base articles
3. Conduct systematic research: define search strategy, execute, synthesize
4. Write findings to OUTPUT path using research artifact template
5. Include an annotated bibliography with relevance scores
6. Return 6-10 sentence summary
7. Do NOT spawn sub-agents

## Input Contract
Your prompt will contain: TASK, TASK_ID, STATE_FILE, INDEX_FILE, RESEARCH_QUESTIONS, OUTPUT path.

## Output Contract
Write to OUTPUT path following hub/templates/research-artifact.md with additional:
- Annotated Bibliography (source, summary, relevance 1-5, credibility assessment)
- Evidence Map (claim -> supporting sources -> confidence level)

## Research Process
1. Read STATE.md for macro context
2. Define search strategy (what to search, where, in what order)
3. Local search first (Glob, Grep, Read)
4. Web search for external sources (WebSearch, WebFetch)
5. Cross-reference claims across sources
6. Build evidence map
7. Write to OUTPUT path
8. Return 6-10 sentence summary

## Example Summary
"Conducted deep research on zero-trust architecture patterns across 8 sources..."
```

## Creating the Artifact Template

If your new agent produces a novel output format, create a matching template in `hub/templates/`:

```
hub/templates/{agent-name}-artifact.md
```

Follow the same structure: frontmatter, sections, changelog placeholder.

## Registering the Agent

1. Create the file in `.claude/agents/{name}.md`
2. Add the agent to the Available Agents table in `CLAUDE.md`
3. Update `INDEX.md` to reference the new agent file
4. Create or reference an artifact template in `hub/templates/`
