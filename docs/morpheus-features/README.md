---
title: Morpheus Features Index
category: documentation
tags: [morpheus, features, index]
created: 2026-04-17
last-updated: 2026-04-22
status: active
audience: Tyler (current), Goodwin security team (future open-source)
---

# Morpheus Features

User-facing documentation for every non-trivial Morpheus feature — architecture, user flows, configuration, and troubleshooting pointers.

This directory is the **home page for "how does Morpheus actually work"** — written for a teammate who wants to understand and use a feature without reading the source.

## How to use

- **Looking for a specific feature?** Use the index below.
- **Adding a new feature?** Copy [`_template.md`](_template.md), rename to your feature slug, fill in each section. Then run `/document-feature` to wire it into CLAUDE.md + INDEX.md + the daily note todo list.
- **Changing an existing feature?** The `feature-change-detector.sh` hook will remind you in the daily note. Run `/document-feature update <slug>` to revise the doc.

## Index

| # | Feature | Slug | Status | Audience Ready |
|---|---------|------|--------|----------------|
| 1 | O365 Planner Integration | [`o365-planner-integration`](o365-planner-integration.md) | active | ✅ Tyler + team |
| 2 | Orchestration Loop | [`orchestration-loop`](orchestration-loop.md) | active | ✅ Tyler + team |
| 3 | Daily Notes System | [`daily-notes-system`](daily-notes-system.md) | active | ✅ Tyler + team |
| 4 | Task State Management | [`task-state-management`](task-state-management.md) | active | ✅ Tyler + team |
| 5 | Research & Investigation | [`research-and-investigation`](research-and-investigation.md) | active | ✅ Tyler + team |
| 6 | Scripting Lifecycle | [`scripting-lifecycle`](scripting-lifecycle.md) | active | ✅ Tyler + team |
| 7 | Context Engineering | [`context-engineering`](context-engineering.md) | active | ✅ Tyler + team |
| 8 | Hooks Framework | [`hooks-framework`](hooks-framework.md) | active | ✅ Tyler + team |
| 9 | Feature Documentation System | [`feature-documentation-system`](feature-documentation-system.md) | active | ✅ Tyler + team |
| 10 | North-Star Standard | [`north-star-standard`](north-star-standard.md) | active | ✅ Tyler + team |
| 11 | v2 Orchestration-Loop Overhaul (2026-04-22) | [`v2-harness-overhaul-2026-04-22`](v2-harness-overhaul-2026-04-22.md) | active | ✅ Tyler |
| 12 | Neo Integration (peer SOC tool) | [`neo-integration`](neo-integration.md) | active | ✅ Tyler |

> Skeletons 2–9 were scaffolded by `/document-feature audit` consolidation on 2026-04-17 — frontmatter + section placeholders present; prose TODO. Pick one and fill it in via `/document-feature update <slug>`.

## Document structure

Every feature doc in this directory follows [`_template.md`](_template.md) and has these sections:

1. **Overview** — what it is, why it exists
2. **Architecture** — Mermaid diagrams of flows + topology
3. **User flows** — common tasks with step-by-step walkthroughs
4. **Configuration** — config files, environment variables, permissions
5. **Integration points** — how this feature touches other Morpheus subsystems
6. **Troubleshooting** — pointer to the dedicated runbook (if any) + common failure modes
7. **References** — source files, related ADRs, upstream APIs
8. **Changelog** — dated revision history (max 10 entries, newest first)

## Relationship to other docs

| Surface | Purpose | Lives In |
|---------|---------|----------|
| `docs/morpheus-features/` (this dir) | **User-facing** — how to use + understand each feature | here |
| `docs/reference/*-runbook.md` | **Troubleshooting** — diagnostics + common errors for operators | `docs/reference/` |
| `docs/architecture/*.md` | **Deep design** — architectural decisions + system-wide trade-offs | `docs/architecture/` |
| `docs/decisions/` | **ADRs** — "we chose X because Y" records | `docs/decisions/` |
| `hub/staging/*/STATE.md` | **Build history** — what was done when, by which wave | `hub/staging/` |
| `scripts/*/*.psm1/.py/.sh` | **Inline** — per-function docstrings + headers | `scripts/` |

This directory is the **first stop for "I want to understand this feature"**. The other surfaces are reached from here via links.

## Changelog

| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-28T12:00 | 2026-04-24-neo-skill-onboarding | documenter (W10R1) | Added neo-integration (row 12) to feature index -- Neo as first-class peer SOC tool |
| 2026-04-22T16:12 | 2026-04-22-harness-intake-improvements | documenter | Added north-star-standard (row 10) and v2-harness-overhaul-2026-04-22 (row 11) to feature index |
| 2026-04-17T10:36 | 2026-04-17-morpheus-feature-docs | morpheus | Created Morpheus features index with O365 Planner Integration as first entry |
