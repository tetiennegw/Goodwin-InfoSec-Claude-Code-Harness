---
title: "Hooks Architecture"
last-updated: 2026-04-08
related-files: [.claude/settings.local.json, .claude/hooks/skill-assessor.sh, .claude/hooks/update-index.sh, scripts/utils/ensure-note.sh]
---

# Hooks Architecture

Hooks are automated scripts that fire on Claude Code lifecycle events. They are configured in `.claude/settings.local.json` and execute bash commands or scripts.

## All Hooks

| Hook Event | Script | Trigger | Purpose |
|-----------|--------|---------|---------|
| **SessionStart** | `scripts/utils/ensure-note.sh` | Session begins | Create daily/weekly/monthly/quarterly/yearly notes from templates |
| **InstructionsLoaded** | Inline command | CLAUDE.md finishes loading | Load INDEX.md into context |
| **UserPromptSubmit** | `.claude/hooks/skill-assessor.sh` | Every prompt submitted | List available skills, recommend matching ones |
| **PostToolUse (Write)** | `.claude/hooks/update-index.sh` | After any Write tool call | Add newly created files to INDEX.md |

## Standardized Hook Output Header

Every hook MUST output a standardized header line:

```
[HOOK:{event}] FIRED — {description}
[HOOK:{event}] SKIPPED — {reason}
[HOOK:{event}] ERROR — {what went wrong}
```

Examples:
```
[HOOK:SessionStart] FIRED — Created daily note for 2026-04-08
[HOOK:SessionStart] SKIPPED — daily note already exists
[HOOK:InstructionsLoaded] FIRED — INDEX.md loaded (23 entries)
[HOOK:PostToolUse:Write] FIRED — Added docs/README.md to INDEX.md under Documentation
[HOOK:PostToolUse:Write] SKIPPED — docs/README.md already in INDEX.md
[HOOK:UserPromptSubmit] FIRED — Available skills: ...
```

This format is greppable and makes hook behavior visible in session output.

## Hook 1: SessionStart — ensure-note.sh

**Configuration**:
```json
"SessionStart": [{
  "hooks": [{
    "type": "command",
    "command": "bash scripts/utils/ensure-note.sh"
  }]
}]
```

**Behavior**: Creates note files from templates in `hub/templates/` if they do not exist. Fills date placeholders. See [Notes System](notes-system.md) for details.

## Hook 2: InstructionsLoaded — INDEX.md Loader

**Configuration**:
```json
"InstructionsLoaded": [{
  "hooks": [{
    "type": "command",
    "command": "if [ -f INDEX.md ]; then ENTRIES=$(grep -c '^- ' INDEX.md 2>/dev/null || echo 0); echo \"[HOOK:InstructionsLoaded] FIRED — INDEX.md loaded ($ENTRIES entries)\"; cat INDEX.md; else echo '[HOOK:InstructionsLoaded] SKIPPED — INDEX.md not found'; fi"
  }]
}]
```

**Behavior**: Reads INDEX.md and outputs its full contents so Morpheus has the directory map in context from the start. This avoids the need for agents to search for files that are already indexed.

## Hook 3: UserPromptSubmit — Skill Assessor

**Configuration**:
```json
"UserPromptSubmit": [{
  "hooks": [{
    "type": "command",
    "command": "bash .claude/hooks/skill-assessor.sh"
  }]
}]
```

**Behavior**: Receives the prompt as JSON on stdin (`{"prompt": "..."}`). Scans `.claude/commands/` for `.md` files (skills/slash commands). Extracts descriptions from frontmatter. Performs keyword matching against the prompt. Outputs the skill list and any recommendations.

## Hook 4: PostToolUse (Write) — Index Updater

**Configuration**:
```json
"PostToolUse": [{
  "matcher": "Write",
  "hooks": [{
    "type": "command",
    "command": "bash .claude/hooks/update-index.sh"
  }]
}]
```

**Behavior**: Receives the Write tool's input as JSON on stdin (`{"tool_input": {"file_path": "..."}}`). Computes the relative path, determines the INDEX.md section based on path prefix (`hub/` -> Hub, `scripts/` -> Scripts, etc.), and appends the entry if not already present. Skips INDEX.md itself to avoid recursion.

**Section mapping**:
| Path Prefix | INDEX.md Section |
|-------------|-----------------|
| `hub/` | Hub |
| `scripts/` | Scripts |
| `knowledge/` | Knowledge Base |
| `notes/`, `ops/` | Operational |
| `.claude/` | Configuration |
| `docs/` | Documentation |
| Other | Uncategorized |

## How to Add a New Hook

1. Choose the event: `SessionStart`, `InstructionsLoaded`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `Stop`
2. Write a bash script in `.claude/hooks/` (or use an inline command for simple hooks)
3. Start with `set -euo pipefail` and the standardized header output
4. Add the configuration to `.claude/settings.local.json`
5. For PostToolUse, use the `"matcher"` field to filter by tool name

See [Adding Hooks](../customization/adding-hooks.md) for a step-by-step guide.
