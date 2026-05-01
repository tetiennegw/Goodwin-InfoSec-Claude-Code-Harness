---
title: "Adding Hooks"
last-updated: 2026-04-08
related-files: [.claude/settings.local.json, .claude/hooks/skill-assessor.sh, .claude/hooks/update-index.sh]
---

# Adding Hooks

## Available Hook Events

| Event | When It Fires | Input (stdin JSON) |
|-------|--------------|-------------------|
| `SessionStart` | Session begins | None |
| `InstructionsLoaded` | After CLAUDE.md loads | None |
| `UserPromptSubmit` | Every prompt submitted | `{"prompt": "user's text"}` |
| `PreToolUse` | Before a tool executes | `{"tool_name": "...", "tool_input": {...}}` |
| `PostToolUse` | After a tool executes | `{"tool_name": "...", "tool_input": {...}, "tool_output": "..."}` |
| `Stop` | Session ends | None |

For `PreToolUse` and `PostToolUse`, you can filter by tool name using the `"matcher"` field.

## Configuration Format

Hooks are configured in `.claude/settings.local.json` under the `"hooks"` key:

```json
{
  "hooks": {
    "EventName": [
      {
        "matcher": "ToolName",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/your-script.sh"
          }
        ]
      }
    ]
  }
}
```

- `"matcher"` is optional. Only used for `PreToolUse` and `PostToolUse` to filter by tool name.
- Multiple hooks can fire on the same event (array of hook objects).

## Step-by-Step: Creating a New Hook

### 1. Write the Script

Create a new file in `.claude/hooks/`:

```bash
#!/bin/bash
# ============================================================
# Task: N/A (system hook)
# Agent: N/A
# Created: 2026-04-08
# Purpose: {What this hook does}
# Dependencies: {jq, bash, etc.}
# Changelog (max 10):
#   2026-04-08 | system | builder | Created initial hook
# ============================================================

set -euo pipefail

HOOK_NAME="HOOK:{EventName}"

# Read stdin if this hook receives input
INPUT=$(cat)

# Your logic here...

# Always output the standardized header
echo "[$HOOK_NAME] FIRED — {description of what happened}"
```

### 2. Make It Executable

```bash
chmod +x .claude/hooks/your-script.sh
```

### 3. Add to settings.local.json

```json
"PostToolUse": [
  {
    "matcher": "Write",
    "hooks": [
      {
        "type": "command",
        "command": "bash .claude/hooks/update-index.sh"
      }
    ]
  },
  {
    "matcher": "Bash",
    "hooks": [
      {
        "type": "command",
        "command": "bash .claude/hooks/your-new-hook.sh"
      }
    ]
  }
]
```

### 4. Test It

Run a session and trigger the event. Check for the standardized header in output:

```
[HOOK:PostToolUse:Bash] FIRED — {description}
```

## Standardized Header Requirement

Every hook MUST output exactly one of:

```
[HOOK:{event}] FIRED — {what happened}
[HOOK:{event}] SKIPPED — {why it was skipped}
[HOOK:{event}] ERROR — {what went wrong}
```

This format is:
- **Greppable**: `grep "HOOK:" session.log` finds all hook activity
- **Parseable**: Status (FIRED/SKIPPED/ERROR) is always in the same position
- **Visible**: Easy to spot in session output

## Example: PostToolUse Hook for Bash Commands

A hook that logs all Bash commands executed during a session:

```bash
#!/bin/bash
set -euo pipefail

HOOK_NAME="HOOK:PostToolUse:Bash"
LOG_FILE="hub/logs/bash-commands.log"

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

if [[ -z "$COMMAND" ]]; then
  echo "[$HOOK_NAME] SKIPPED — Could not extract command"
  exit 0
fi

mkdir -p "$(dirname "$LOG_FILE")"
echo "$(date -Iseconds) | $COMMAND" >> "$LOG_FILE"
echo "[$HOOK_NAME] FIRED — Logged command to $LOG_FILE"
```

Configuration:
```json
"PostToolUse": [
  {
    "matcher": "Bash",
    "hooks": [
      {
        "type": "command",
        "command": "bash .claude/hooks/log-bash.sh"
      }
    ]
  }
]
```

## Tips

- **Keep hooks fast** — they run synchronously and block the session
- **Use `exit 0`** — non-zero exits may cause Claude Code to report errors
- **Read stdin once** — pipe to a variable, then parse. You cannot re-read stdin.
- **Test with `echo '{"prompt":"test"}' | bash .claude/hooks/your-script.sh`**
