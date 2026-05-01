---
title: "INDEX System"
last-updated: 2026-04-08
related-files: [INDEX.md, .claude/hooks/update-index.sh, .claude/rules/index-consultation.md]
---

# INDEX System

## What is INDEX.md?

`INDEX.md` is the directory source of truth for the entire project. It is a categorized list of all significant files, maintained at the project root. Morpheus and all agents consult it before searching for files.

## Why It Matters

Without INDEX.md, every agent would need to `Glob` or `Grep` to find files — burning context tokens on search results. With INDEX.md loaded into context (via the InstructionsLoaded hook), agents can look up file paths directly.

## Structure

```markdown
# TE GW Brain -- Index

## Active Projects
- [Project Name](hub/staging/task-id/STATE.md) -- description

## Configuration
- [CLAUDE.md](CLAUDE.md) -- Morpheus orchestrator identity
- [.claude/agents/](.claude/agents/) -- Agent definitions

## Hub (Orchestration)
- [active-tasks.md](hub/state/active-tasks.md) -- Cross-session persistence

## Notes (Macro Work Log)
- [notes/2026/04/](notes/2026/04/) -- April 2026 daily notes

## Knowledge Base
### Security
### Tools

## Scripts
- [ensure-note.sh](scripts/utils/ensure-note.sh) -- Auto-create notes

## Documentation
- [docs/README.md](docs/README.md) -- Documentation entry point
```

Entries are grouped by section. Each entry is a markdown link with a brief description.

## Auto-Update via PostToolUse Hook

When any agent writes a file using the Write tool, the `update-index.sh` hook fires:

1. Extracts the file path from the tool's JSON input
2. Computes the relative path from the project root
3. Checks if the path is already in INDEX.md (skips if so)
4. Determines the appropriate section based on path prefix
5. Appends the entry under that section

This keeps INDEX.md current without manual maintenance.

## Consultation Rule

The `.claude/rules/index-consultation.md` rule applies globally (`globs: "**/*"`) and enforces:

**Before searching:**
1. Read INDEX.md first
2. If INDEX.md has the path you need, use it directly
3. Only use Glob/Grep if INDEX.md does not contain what you need

**After creating files:**
1. Verify the PostToolUse hook fired (`[HOOK:PostToolUse:Write] FIRED` in output)
2. If the hook did not fire, manually add the file to INDEX.md

## How Agents Use INDEX.md

| Agent | How It Uses INDEX.md |
|-------|---------------------|
| **Gatherer** | Finds existing research, KB articles, configs before searching |
| **Planner** | Locates existing modules, patterns, and reusable components |
| **Builder** | Finds files to reference or extend |
| **Verifier** | Resolves cross-references to verify link targets exist |
| **Documenter** | Updates INDEX.md with new files, verifies completeness |
| **SME Assessor** | Resolves paths mentioned in artifacts for verification |

## Keeping INDEX.md Current

Three mechanisms ensure accuracy:

1. **Auto-update hook**: `update-index.sh` adds new files on Write
2. **Documenter wave**: The documenter agent reviews and updates INDEX.md at task completion
3. **Manual review**: Tyler or Morpheus can audit INDEX.md for stale entries

If INDEX.md ever becomes stale, the documenter can rebuild it by scanning the file system.
