---
title: "Fork and Customize"
last-updated: 2026-04-08
related-files: [CLAUDE.md, INDEX.md, memory/user_profile.md, memory/company_context.md]
---

# Fork and Customize

This guide walks you through making the Morpheus foundation your own.

## Step 1: Fork or Clone the Repo

```bash
git clone https://github.com/your-org/te-gw-brain.git my-brain
cd my-brain
```

## Step 2: Edit CLAUDE.md — Your Agent's Identity

Open `CLAUDE.md` and update the Identity section:

```markdown
## Identity
You are Morpheus, {YOUR_NAME}'s orchestration agent. {YOUR_NAME} is a
{YOUR_ROLE} at {YOUR_ORG} (started {DATE}, {EMAIL}).
```

**What to change:**
- Agent name (keep "Morpheus" or rename)
- Your name, role, organization, email
- Start date (used for context in notes)

**What to keep unchanged:**
- The "You are a pure orchestrator" directive
- Core Pillars (curiosity, verification, first-principles)
- Orchestration Loop
- Scope Table
- Available Agents table
- Context Engineering Rules
- Standards section

See [Personalizing Identity](../customization/personalizing-identity.md) for role-specific examples.

## Step 3: Edit memory/user_profile.md

This file stores persistent facts about you that Morpheus references across sessions:

```markdown
# User Profile
- Name: Jane Smith
- Role: Security Engineer
- Email: jsmith@example.com
- Team: Detection Engineering
- Expertise: SIEM, KQL, incident response
- Preferences: Prefers concise output, dislikes verbose summaries
```

## Step 4: Edit memory/company_context.md

Describe your team's environment so agents produce relevant output:

```markdown
# Company Context
- Organization: Acme Corp
- Industry: Financial Services
- Security Stack: CrowdStrike, Splunk, Palo Alto
- Cloud: AWS (primary), Azure (identity)
- Ticketing: ServiceNow
- Communication: Slack, Teams
```

## Step 5: Run Your First Session

```bash
claude
```

On launch, you should see:
1. `[HOOK:SessionStart] FIRED` — daily notes created
2. `[HOOK:InstructionsLoaded] FIRED` — INDEX.md loaded
3. Morpheus's initial greeting

If hooks fire correctly, the system is working. See [First Session](03-first-session.md) for details.

## Step 6: Run a Test Task

Ask Morpheus a simple question to verify the full loop:

```
Create a one-page summary of our security stack.
```

Morpheus should:
1. Assess scope as **mini** (single deliverable)
2. Dispatch a **builder** agent
3. Dispatch an **SME assessor** to verify
4. Return the result

If this works, your fork is ready. See [Your First Task](04-your-first-task.md) for a deeper walkthrough.
