---
title: "TE GW Brain / Morpheus Orchestrator — Documentation"
last-updated: 2026-04-22
related-files: [CLAUDE.md, INDEX.md, .claude/rules/hub.md]
---

# Morpheus Orchestrator

Morpheus is an AI orchestration framework built on Claude Code. It turns a single Claude Code session into a managed system of specialized sub-agents that research, plan, build, verify, and document work — with human checkpoints at every critical decision point.

## Who is this for?

This documentation is for **Tyler's team at Goodwin Procter** and anyone forking the Morpheus foundation to build their own orchestrated agent system. If you use Claude Code and want structured, validated, auditable AI-assisted work — this is your starting point.

## What does Morpheus do?

1. **Receives a task** from you (e.g., "Create a phishing triage runbook")
2. **Assesses scope** — passthrough (answer directly) through ultra (multi-session project)
3. **Dispatches specialized agents** in waves: gatherer, planner, builder, verifier, documenter (for Medium+, the orchestration plan is presented and approved before any scaffolding happens -- plan-first is mechanically enforced)
4. **Validates every output** with dynamic SME assessors who require external evidence, never trusting self-reports
5. **Tracks state** in file-based artifacts so work survives across sessions
6. **Documents everything** in daily notes with pointer-based entries and a searchable tag taxonomy

Morpheus never does work directly. It orchestrates.

## Core Design Principles

- **Hub-and-spoke orchestration** — Morpheus is the hub; sub-agents are spokes that write artifacts and return summaries
- **File-based artifact passing** — agents communicate through files, not token carry-over
- **Progressive disclosure** — context loads on-demand to stay within token limits
- **External validation** — SME assessors verify work using tools (Glob, Grep, Bash, WebSearch), never accepting claims at face value
- **Human-in-the-loop** — Tyler checkpoints at scope-appropriate intervals
- **Mechanically enforced governance** — a harness-audit ledger tracks protocol compliance; a replay corpus of real failure cases benchmarks every harness change; 8 north-star metrics are published nightly (see `docs/morpheus-features/north-star-standard.md`)

## Quick Start

1. [Prerequisites](getting-started/01-prerequisites.md) — what you need installed
2. [Fork and Customize](getting-started/02-fork-and-customize.md) — make it yours
3. [First Session](getting-started/03-first-session.md) — what happens when you launch
4. [Your First Task](getting-started/04-your-first-task.md) — end-to-end walkthrough

## Architecture

- [Overview](architecture/overview.md) — system diagram and core concepts
- [Orchestration Model](architecture/orchestration-model.md) — waves, rounds, STATE.md
- [North-Star Standard](morpheus-features/north-star-standard.md) — 8 invariants, 8 metrics, 3 self-improvement loops (v2 governance target)
- [v2 Harness Overhaul (2026-04-22)](morpheus-features/v2-harness-overhaul-2026-04-22.md) — 30 patches implementing the north-star standard
- [Agent Definitions](architecture/agent-definitions.md) — all 6 agents explained
- [Validation Standard](architecture/validation-standard.md) — the trust model
- [Notes System](architecture/notes-system.md) — daily/weekly/monthly hierarchy
- [Hooks Architecture](architecture/hooks-architecture.md) — all 4 hooks
- [INDEX System](architecture/index-system.md) — directory source of truth
- [Progressive Disclosure](architecture/progressive-disclosure.md) — context layering

## Reference

- [Dispatch Templates](reference/dispatch-templates.md) — copy-pasteable agent dispatch prompts
- [Artifact Templates](reference/artifact-templates.md) — all 6 artifact formats
- [Scope Patterns](reference/scope-patterns.md) — passthrough through ultra
- [Changelog Standard](reference/changelog-standard.md) — artifact changelog format
- [Tag Taxonomy](reference/tag-taxonomy.md) — notes tagging system
- [STATE.md Specification](reference/state-file-spec.md) — task state format

## Customization

- [Adding Agents](customization/adding-agents.md)
- [Adding SME Domains](customization/adding-sme-domains.md)
- [Adding Hooks](customization/adding-hooks.md)
- [Adding Rules](customization/adding-rules.md)
- [Adding Skills](customization/adding-skills.md)
- [Personalizing Identity](customization/personalizing-identity.md)

## Recent Changes

| Date | Change | Reference |
|------|--------|-----------|
| 2026-04-28 | Neo integration -- first-class peer SOC tool; /neo skill, security.md protocol, neo.md rule, external docs ingest, feature doc | [neo-integration](morpheus-features/neo-integration.md) |
| 2026-04-22 | v2 Orchestration-Loop Overhaul -- 30 patches, 7 phases, mechanically enforced governance, replay corpus, nightly metrics | [v2-harness-overhaul-2026-04-22](morpheus-features/v2-harness-overhaul-2026-04-22.md) |

## Changelog

See [docs/changelog.md](changelog.md).
