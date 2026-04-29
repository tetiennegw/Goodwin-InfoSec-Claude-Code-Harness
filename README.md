# {{harness.name}} — Orchestration Discipline for Claude Code (Goodwin InfoSec Edition)

A Goodwin-internal forkable harness that turns Claude Code into a disciplined orchestrator: scope-classified work, plan-mode-gated execution, audited task discipline, and a sub-agent workflow that writes artifacts to disk instead of bloating the conversation. Pairs with **Neo** (Goodwin's internal Claude-powered SOC agent) — Morpheus orchestrates work, Neo executes SOC investigations.

> **Status**: Goodwin InfoSec internal use only. See `LICENSE` for terms.
> **Audience**: Goodwin Procter LLP InfoSec teammates, contractors, and authorized agents.

---

## 1. What is {{harness.name}}?

{{harness.name}} is a Claude Code project template that ships:

- A **plan-mode-first orchestration loop** (`/the-protocol`): every Medium+ task enters plan mode, gathers context, fires clarifying `AskUserQuestion` prompts, drafts an implementation plan, and only scaffolds (staging dir, STATE.md, TaskCreate entries, daily-note timeline) AFTER Tyler approves the plan.
- **Wave/round dispatch** via `/orchestration-dispatch`: sub-agents (gatherer, planner, builder, verifier, documenter, sme-assessor, context-curator) run in waves; an SME assessor verifies each round with external evidence and returns ADVANCE / CONTINUE / FLAG / FAIL verdicts.
- **17 lifecycle hooks**: SessionStart presence checks, UserPromptSubmit context loading, PreToolUse plan-mode standard injection, PostToolUse INDEX.md auto-update + STATE.md frontmatter validation, Stop-event audit-ledger writes for protocol-execution / task-discipline / plan-compliance / daily-note-logging.
- **Cross-session resume**: `STATE.md` (per-task) + `HANDOFF.md` (Ultra) + `hub/state/active-tasks.md` (auto-generated) keep work durable across Claude Code restarts.
- **Pairing with Neo**: when SOC tooling (Sentinel KQL, Defender XDR, Entra, Abnormal, ThreatLocker, Lansweeper, AppOmni) is the right surface, `/neo` delegates the investigation to Goodwin's Claude-powered Neo CLI and logs results back to the daily note.

This is the same harness {{user.name}} runs every day at {{company.name}}. Onboarding makes it yours.

## 2. Who is it for?

Goodwin InfoSec teammates who want:

- Reproducible orchestration discipline on Goodwin endpoints (ThreatLocker AllSigned + Storage Control friendly)
- Plan-first execution with audit-ledger backed enforcement
- Cross-session task state that survives restarts and context resets
- A working pattern for pairing Claude Code with internal SOC tooling (Neo, Sentinel, Defender)
- A starting point for personal harness extension — fork, run `/onboard`, customize

## 3. Quick start

```bash
git clone https://github.com/Goodwin-InfoSec/Goodwin-InfoSec-Claude-Code-Harness.git
cd Goodwin-InfoSec-Claude-Code-Harness
# Open Claude Code in this directory
# In your first prompt:
/onboard
```

`/onboard` walks you through:

1. Identity capture (name, email, role, manager — populates `CLAUDE.md`, `memory/`, `INDEX.md`)
2. Team capture (peers, lead tools)
3. Optional extensions: **Neo**, **Planner**, **Codex**, **Signing** — each gated yes/no
4. Path scaffolding (creates `notes/YYYY/MM/`, `ingest/`, `hub/staging/`, `hub/state/`, `memory/`, etc.)
5. Seed-file creation (`hub/state/harness-audit-ledger.md` with `LEDGER-APPEND-ANCHOR`, today's daily note with `PREPEND-ANCHOR:v1`, `MEMORY.md` index, etc.)
6. Dependency bootstrap (Claude Code CLI, Node 18+, Git Bash, PowerShell 7+, optional `jq`, optional Neo binary, optional code-signing cert)
7. Sentinel stamp (`.harness-onboarded` JSON — gitignored per-user)

Estimated time: ~5 minutes on a clean Goodwin Win11 + Git Bash + Node 18+ box.

## 4. What you get post-onboarding

- **25 skills** — `/the-protocol`, `/orchestration-dispatch`, `/research`, `/eod`, `/checkpoint`, `/ingest-context`, `/document-feature`, `/weekly-review`, `/second-opinion`, `/incident-triage`, plus the new `/onboard`
- **17 hooks** — daily-note presence checks, plan-compliance audit, task-discipline audit, protocol-execution audit, `INDEX.md` auto-update, `active-tasks.md` regeneration, etc.
- **7 sub-agents** — gatherer, planner, builder, verifier, documenter, sme-assessor, context-curator
- **5 scope patterns** + **9 rules** + **5 protocol profiles** — the doctrine layer
- **14 templates** for STATE.md, daily notes, plans, research/build/assessment artifacts

## 5. Optional extensions

Each is opt-in via `/onboard`. Defaults to disabled unless you explicitly enable.

- **Neo** — `/neo` delegates SOC investigations to Goodwin's internal Claude-powered Neo CLI. Requires Neo binary install + `NEO_API_KEY` (or Entra ID via `~/.neo/config.json`). See `docs/morpheus-features/neo-integration.md`.
- **Planner** — `/sync-planner` two-way syncs `STATE.md` ↔ Microsoft Planner boards. Requires `Microsoft.Graph.Planner` PS module + Goodwin Entra tenant. Per-user board mapping captured at `/onboard` time.
- **Codex** — `/second-opinion` calls OpenAI Codex CLI for cross-validation on plan and build artifacts. Requires Codex CLI + `OPENAI_API_KEY`.
- **Signing** — `/sign-script` Authenticode-signs PowerShell hooks with your Goodwin code-signing cert (BYO thumbprint). Required to satisfy ThreatLocker AllSigned policy on Goodwin endpoints. If you don't have a cert, `/onboard` skips signing and configures hooks to run with `ExecutionPolicy=Bypass` instead.

## 6. Documentation

- `docs/getting-started/` — 4-doc walkthrough (prerequisites, fork-and-customize, first-session, your-first-task)
- `docs/morpheus-features/` — feature deep-dives (orchestration-loop, hooks-framework, daily-notes-system, task-state-management, north-star-standard, task-discipline-primitive, neo-integration)
- `docs/architecture/` — conceptual model (overview, agent-definitions, hooks-architecture, orchestration-model, validation-standard)
- `docs/customization/` — adding-agents, adding-hooks, adding-skills, adding-rules, adding-sme-domains, personalizing-identity
- `docs/reference/` — artifact-templates, changelog-standard, dispatch-templates, scope-patterns, state-file-spec, tag-taxonomy

## 7. Contributing

See `CONTRIBUTING.md` for the fork → customize → upstream-PR flow. Contributions must preserve the 8 north-star invariants (see `docs/morpheus-features/north-star-standard.md`).

## 8. License

PROPRIETARY — Goodwin Procter LLP InfoSec internal use only. See `LICENSE` for full terms. Pending Goodwin Legal review.

## 9. Acknowledgements

Built and battle-tested by {{user.name}} ({{user.role}}, {{company.name}} InfoSec) over the 2026-03 → 2026-04 build cycle. Templated for Goodwin InfoSec teammate adoption with manager approval from {{team.manager.name}}.
