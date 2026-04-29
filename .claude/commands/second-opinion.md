---
description: Get a structured second opinion from OpenAI Codex CLI with multi-agent analysis
user-invocable: true
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep, Agent, Skill, AskUserQuestion]
argument-hint: <topic or question> [--files=path1,path2,...] [--cwd=project-path]
schema-version: 1
---

# Second Opinion

Get an independent second opinion from OpenAI's Codex CLI on a topic, issue, task, or project. Codex runs with multi-agent orchestration enabled, providing deep analysis from multiple perspectives. Then compare both AI perspectives into a structured analysis document.

**Usage**: `/second-opinion <topic or question> [--files=path1,path2,...] [--cwd=project-path]`

**Prerequisites**:
- OpenAI Codex CLI installed (`codex --version` works)
- `OPENAI_API_KEY` set in environment
- `analyst` profile configured in `~/.codex/config.toml`
- See `docs/SECOND-OPINION-SETUP.md` for full setup guide

**Arguments**: $ARGUMENTS

## Step 0: Parse Arguments

Extract from `$ARGUMENTS`:
- **Topic/Question**: Everything that isn't a flag (required)
- **--files=path1,path2,...**: Optional comma-separated file paths to include as context
- **--cwd=path**: Optional working directory for Codex (defaults to vault root with `--skip-git-repo-check`; if a git project path is given, Codex runs there with full repo context)

If no topic/question provided, ask the user via AskUserQuestion:
- "What topic, issue, or decision would you like a second opinion on?"

## Step 1: Claude's Independent Position

Before consulting Codex, generate YOUR OWN brief position on the topic. Write 3-5 concise bullet points capturing:
- Your assessment of the situation
- Key considerations you see
- Your recommended approach (if applicable)
- Any concerns or risks you'd flag

Store this internally — do NOT share with Codex (to avoid bias).

## Step 2: Build Context Package

1. **Read specified files** (from `--files` flag) — include their contents as context for Codex
2. **If no files specified**, check if the topic references specific files in the vault or project — offer to include them via AskUserQuestion
3. **Build a context summary** that includes:
   - The exact topic/question
   - Relevant file contents (truncated to ~10K chars per file if very large)
   - Any relevant background that helps frame the question

## Step 3: Craft Codex Prompt

Write the following to a temp file. The prompt MUST include multi-agent orchestration scaffolding.

**On Windows**, use `$env:TEMP/second-opinion-prompt.md` instead of `/tmp/`.

Write to the temp file:

```
# Second Opinion Analysis Request

## Your Role
You are an independent analyst providing a thorough second opinion. Approach this with fresh eyes. Challenge assumptions. Look for blind spots. Be constructively critical.

## Multi-Agent Analysis Strategy (USE THIS)
For the most thorough analysis, orchestrate multiple perspectives:

1. **Devil's Advocate Agent**: Challenge every assumption. What could go wrong? What's being overlooked? What biases might be influencing the current thinking?

2. **Domain Expert Agent**: Validate technical claims against best practices. Are the approaches sound? Are there industry standards being ignored? What do authoritative sources say?

3. **Pragmatist Agent**: Assess real-world feasibility. What are the trade-offs? What's the simplest path that works? Where is complexity being added unnecessarily?

4. **Synthesis Agent**: After gathering all perspectives, synthesize into a unified, actionable analysis.

Spawn these agents and gather their findings before writing your final response.

## Topic/Question
{TOPIC_PLACEHOLDER}

## Context & Reference Material
{CONTEXT_PLACEHOLDER}

## Required Output Structure

Respond with EXACTLY this structure (use these headers):

### Executive Summary
2-3 sentences: What is your independent assessment? What's the single most important thing to know?

### Key Findings
Numbered list of your most important observations. Be specific and actionable.

### Agreements with Current Direction
What aspects of the current approach/thinking are solid and should be maintained?

### Challenges & Concerns
What could go wrong? What assumptions are risky? What's being underestimated?

### Alternative Approaches
What would you do differently? Propose at least one concrete alternative with trade-off analysis.

### Blind Spots Identified
What isn't being considered? What questions aren't being asked?

### Recommendations
Your top 3-5 actionable recommendations, prioritized by impact.

### Confidence Assessment
- Overall confidence in this analysis: [HIGH/MEDIUM/LOW]
- What additional information would increase confidence?
- What would change your mind about your key recommendations?
```

Replace `{TOPIC_PLACEHOLDER}` with the actual topic/question.
Replace `{CONTEXT_PLACEHOLDER}` with the file contents and context built in Step 2.

## Step 4: Execute Codex

Determine the working directory and run Codex. Use PowerShell for Windows compatibility:

```powershell
# If --cwd specified (git project):
cd "{CWD_PATH}"; codex exec -p analyst -a never -o "$env:TEMP\codex-response.md" - < "$env:TEMP\second-opinion-prompt.md"

# If no --cwd (vault root, not a git repo):
cd "{{paths.home}}\Documents\TE GW Brain"; codex exec -p analyst -a never --skip-git-repo-check -o "$env:TEMP\codex-response.md" - < "$env:TEMP\second-opinion-prompt.md"
```

**Timeout**: Set Bash timeout to 300000ms (5 minutes) to allow for multi-agent orchestration.

**Error handling**:
- If Codex fails with API key error: Tell user to check OPENAI_API_KEY
- If Codex times out: Report timeout, suggest simpler query
- If Codex returns empty: Retry once, then report failure and present Claude's position alone

## Step 5: Read & Parse Codex Response

Read the Codex response temp file to get the analysis.

If the response is empty or clearly malformed, inform the user and skip to presenting Claude's position alone.

## Step 6: Create Structured Comparison Document

Generate a slug from the topic (lowercase, hyphens, max 50 chars).

**Ensure directory exists**:
```bash
mkdir -p "{{paths.home}}/Documents/TE GW Brain/thoughts/second-opinions"
```

Create file at: `thoughts/second-opinions/YYYY-MM-DD-{slug}.md`

Write the structured analysis document:

```markdown
---
date: YYYY-MM-DD
time: HH:MM AM/PM
topic: "{Original topic/question}"
engine: "OpenAI Codex CLI (multi-agent)"
files_analyzed: [list of files if any]
tags: [second-opinion, ai-analysis, plus any detected domain tags]
---

# Second Opinion: {Topic Title}

**Requested**: YYYY-MM-DD at HH:MM AM/PM
**Engine**: OpenAI Codex CLI (multi-agent orchestration)
**Files Analyzed**: {list or "None"}

---

## Executive Summary
{2-3 sentence synthesis of BOTH perspectives — where do they converge and diverge?}

---

## Claude's Position
{The 3-5 bullet points from Step 1}

---

## Codex's Analysis
{Full Codex response from Step 5, preserving its structure}

---

## Comparative Analysis

### Agreements
{Points where both AIs align — these are high-confidence findings}

### Disagreements
{Points of divergence — flag these for human judgment}

### Unique Insights from Codex
{Perspectives or considerations that Claude did not raise}

### Unique Insights from Claude
{Perspectives or considerations that Codex did not raise}

---

## Synthesis & Recommendation
{Your final synthesized recommendation that weighs both perspectives. Be explicit about which AI's reasoning you find more compelling on each point, and why.}

---

## Confidence & Caveats
- **Overall alignment**: {HIGH/MEDIUM/LOW — how much do the two AIs agree?}
- **Decision readiness**: {Is there enough consensus to act, or does this need human judgment?}
- **Open questions**: {What remains unresolved?}
```

## Step 7: Daily Note Entry

After saving the analysis file, invoke the `daily-note-management` skill to log this work.

The daily note entry should follow the standard entry format and include:
- What was done: Second opinion analysis on {topic}
- Key outcome: 1-sentence summary of the synthesis
- Link to the full analysis: `[[YYYY-MM-DD-{slug}]]`

## Step 8: Present to User

Show a concise summary in the conversation:

1. **Topic**: What was analyzed
2. **Key Agreements**: Top 2-3 points of consensus
3. **Key Disagreements**: Top 2-3 points of divergence
4. **Top Recommendation**: The synthesized recommendation
5. **Full Analysis**: Link to the saved file path

## Important Rules

- **NEVER share Claude's position with Codex** — the second opinion must be independent
- If Codex multi-agent fails, it will still provide a single-agent response — that's fine
- Truncate very large files to ~10K chars each to stay within Codex context limits
- The `analyst` profile in `~/.codex/config.toml` sets high reasoning effort and read-only sandbox
- Clean up temp files after successful runs
- Always invoke `daily-note-management` skill after completion — this is mandatory
