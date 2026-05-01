```
                                                              __
                               /'\_/`\                       /\ \
                              /\      \    ___   _ __   _____\ \ \___      __   __  __    ____
                              \ \ \__\ \  / __`\/\'__\/\ '__`\ \  _ `\  /'__`\/\ \/\ \  /',__\
                               \ \ \_/\ \/\ \L\ \ \ \/ \ \ \L\ \ \ \ \ \/\  __/\ \ \_\ \/\__, `\
                                \ \_\\ \_\ \____/\ \_\  \ \ ,__/\ \_\ \_\ \____\\ \____/\/\____/
                                 \/_/ \/_/\/___/  \/_/   \ \ \/  \/_/\/_/\/____/ \/___/  \/___/
                                                          \ \_\
                                                           \/_/
```

<div align="center">

### Orchestration Discipline for Claude Code

*Built by Goodwin InfoSec &mdash; for Goodwin InfoSec*

![Status](https://img.shields.io/badge/status-active-brightgreen?style=flat-square)
![Platform](https://img.shields.io/badge/platform-Windows%2011-0078D4?style=flat-square&logo=windows&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=flat-square&logo=powershell&logoColor=white)
![Claude Code](https://img.shields.io/badge/Claude%20Code-required-D34D25?style=flat-square&logo=anthropic&logoColor=white)
![Audience](https://img.shields.io/badge/audience-Goodwin%20InfoSec-2D3539?style=flat-square)
![License](https://img.shields.io/badge/license-proprietary-C8922A?style=flat-square)

</div>

---

## What is Morpheus?

Morpheus turns Claude Code into a **disciplined orchestration engine**. Instead of freeform AI conversations that lose context and drift off-task, Morpheus enforces a structured workflow: every piece of work is scoped, planned, tracked, verified, and logged.

It pairs with **Neo** (Goodwin's internal Claude-powered SOC agent) &mdash; Morpheus orchestrates the work, Neo executes the security investigations.

> **Clone it. Run `/onboard`. Start working.** That's it.

---

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/tetiennegw/Goodwin-InfoSec-Claude-Code-Harness.git
cd Goodwin-InfoSec-Claude-Code-Harness

# 2. Open Claude Code in this directory

# 3. On your first prompt, run:
/onboard
```

Onboarding takes ~5 minutes and walks you through identity capture, team setup, optional extensions, directory scaffolding, and dependency validation. When it's done, the harness is fully personalized to you.

---

## What You Get

| | Feature | What it does |
|---|---------|-------------|
| **Orchestration** | `/the-protocol` | Classifies every request by domain and scope, enters plan mode for Medium+ work, scaffolds task tracking, and hands off to the dispatch loop |
| **Wave Dispatch** | `/orchestration-dispatch` | Runs sub-agents in waves (gatherer &rarr; planner &rarr; builder &rarr; verifier &rarr; documenter) with SME verification gates between each round |
| **Task State** | `STATE.md` + `HANDOFF.md` | Per-task living documents that survive context resets, session restarts, and multi-day work. Auto-generated `active-tasks.md` gives you a cross-session dashboard |
| **Audit Trail** | 17 lifecycle hooks | Protocol-execution audit, task-discipline audit, plan-compliance audit, daily-note logging &mdash; all writing to an append-only ledger |
| **Daily Notes** | Obsidian-compatible | Rich timeline entries with timestamps, tags, file links, and strategic context. Auto-created on session start |
| **Neo Integration** | `/neo` | Delegates SOC investigations to Goodwin's 55-tool security agent (Sentinel, Defender, Entra, Abnormal, ThreatLocker, Lansweeper, AppOmni) |
| **25 Skills** | Slash commands | `/research`, `/eod`, `/checkpoint`, `/ingest-context`, `/incident-triage`, `/second-opinion`, `/weekly-review`, and more |
| **7 Sub-Agents** | Specialized workers | Gatherer, Planner, Builder, Verifier, Documenter, SME Assessor, Context Curator &mdash; each with defined roles and artifact templates |

---

## How It Works

```
You type a request
       |
       v
  /the-protocol
       |
       +---> Classify domain (security? code? harness? default?)
       +---> Assess scope (Passthrough / Mini / Small / Medium / Large / Ultra)
       +---> Enter plan mode (Medium+)
       +---> Clarifying questions via AskUserQuestion
       +---> Draft orchestration plan -> you approve
       |
       v
  Scaffold (staging dir, STATE.md, task list, daily note)
       |
       v
  /orchestration-dispatch
       |
       +---> Wave 1: Gatherer researches -> SME verifies
       +---> Wave 2: Planner designs -> SME verifies
       +---> Wave 3: Builder implements -> SME verifies
       +---> Wave 4: Verifier validates -> SME verifies
       +---> Wave 5: Documenter records
       |
       v
  Done. STATE.md updated. Daily note logged. Task archived.
```

---

## Optional Extensions

Each is opt-in during `/onboard`. Disabled by default.

| Extension | What it enables | Requirements |
|-----------|----------------|--------------|
| **Neo** | `/neo` &mdash; SOC investigations via Goodwin's Claude security agent | Neo CLI + Entra ID auth (`neo auth login`) |
| **Planner** | `/sync-planner` &mdash; two-way sync with Microsoft Planner boards | `Microsoft.Graph.Planner` PS module + Entra tenant |
| **Codex** | `/second-opinion` &mdash; cross-validation via OpenAI Codex CLI | Codex CLI + `OPENAI_API_KEY` |
| **Signing** | `/sign-script` &mdash; Authenticode-sign PowerShell hooks | Goodwin code-signing cert (BYO thumbprint) |

---

## Prerequisites

- **Claude Code** &mdash; CLI or desktop app
- **Git Bash** &mdash; ships with Git for Windows
- **Node.js 18+** &mdash; required by Claude Code
- **PowerShell 5.1+** &mdash; ships with Windows 11
- **Windows 11** &mdash; Goodwin standard endpoint (macOS/Linux: see `docs/reference/cross-os-notes.md`)

ThreatLocker is handled automatically &mdash; hooks use a bash-fallback writer pattern that works within Goodwin's storage policy. If you have a Goodwin code-signing cert, signing is one command via `/sign-script`.

---

## Documentation

| Guide | Description |
|-------|-------------|
| [`docs/getting-started/`](docs/getting-started/) | 4-part walkthrough: prerequisites, fork & customize, first session, your first task |
| [`docs/morpheus-features/`](docs/morpheus-features/) | Deep dives: orchestration loop, hooks, daily notes, task state, Neo integration, north-star standard |
| [`docs/architecture/`](docs/architecture/) | Conceptual model: agents, hooks, orchestration, validation |
| [`docs/customization/`](docs/customization/) | Adding your own agents, hooks, skills, rules, and SME domains |
| [`docs/reference/`](docs/reference/) | Artifact templates, dispatch patterns, scope definitions, state file spec |

---

## Project Structure

```
.claude/
  agents/       7 sub-agent definitions
  commands/     25 slash-command skills (including /onboard)
  hooks/        17 lifecycle hooks (SessionStart, UserPromptSubmit, PostToolUse, Stop)
  protocols/    5 domain profiles (default, code, harness, security, + schema)
  rules/        9 auto-loaded rules (hub, daily-note, scripts, task-handling, etc.)

hub/
  templates/    14 artifact templates (STATE.md, daily-note, plan, research, build, etc.)
  staging/      Per-task working directories (created by /the-protocol)
  state/        Cross-session state (active-tasks, audit ledger, metrics, roadmap)

docs/           Getting started, features, architecture, customization, reference
scripts/        Utility scripts (bash + PowerShell)
notes/          Daily/weekly/monthly notes (Obsidian-compatible, created by hooks)
memory/         Persistent cross-session memory (user profile, feedback, project context)
knowledge/      Team knowledge base articles
```

---

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). Contributions must preserve the [8 north-star invariants](docs/morpheus-features/north-star-standard.md).

The standard flow: fork &rarr; `/onboard` &rarr; customize &rarr; upstream PR for shared improvements.

---

## License

**Proprietary** &mdash; Goodwin Procter LLP InfoSec internal use only. See [`LICENSE`](LICENSE) for full terms.

---

<div align="center">
<sub>Built and battle-tested by Goodwin InfoSec over the 2026 Q1-Q2 build cycle. Templated for teammate adoption.</sub>
</div>
