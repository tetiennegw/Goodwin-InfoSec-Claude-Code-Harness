#!/bin/bash
# ============================================================
# Merged Skill Assessor + Forced Evaluation Hook
# Source: Morpheus foundation + ishtylerc/claude-code-hooks-framework
# Event: UserPromptSubmit
# Purpose: Discovers available skills, recommends matches, AND forces
#          Claude to evaluate + activate relevant skills before implementation.
#          Includes scope classification for orchestration.
# Dependencies: jq, bash
# Changelog (max 10):
#   2026-04-08 | morpheus-foundation | orchestrator | Merged with prompt-context-loader.sh (formerly skill-forced-eval-hook.sh) from hooks framework
#   2026-04-07 | morpheus-foundation | builder | Created initial skill-assessor hook
# ============================================================

set -euo pipefail

HOOK_NAME="HOOK:UserPromptSubmit"
SKILLS_DIR=".claude/commands"

# Read stdin JSON and extract the prompt field
INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)

# If no prompt extracted, skip
if [[ -z "$PROMPT" ]]; then
  echo "[$HOOK_NAME] SKIPPED — Could not extract prompt from input"
  exit 0
fi

# Check if skills directory exists and has files
if [[ ! -d "$SKILLS_DIR" ]]; then
  SKILL_LIST="(no skills directory found)"
  SKILL_COUNT=0
else
  SKILL_FILES=$(find "$SKILLS_DIR" -maxdepth 2 -name "*.md" 2>/dev/null || true)
  SKILL_COUNT=$(echo "$SKILL_FILES" | grep -c "." 2>/dev/null || echo 0)
fi

# Build skill discovery list
SKILL_DISPLAY=""
RECOMMENDATIONS=""

if [[ "$SKILL_COUNT" -gt 0 ]]; then
  PROMPT_LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

  while IFS= read -r skill_file; do
    [[ -z "$skill_file" ]] && continue
    skill_name=$(basename "$skill_file" .md)
    description=$(sed -n '/^---$/,/^---$/{ /^description:/{ s/^description:[[:space:]]*//; p; q; } }' "$skill_file" 2>/dev/null || true)
    if [[ -z "$description" ]]; then
      description=$(sed -n '/^---$/,/^---$/d; /^[[:space:]]*$/d; { p; q; }' "$skill_file" 2>/dev/null || true)
    fi
    [[ ${#description} -gt 80 ]] && description="${description:0:77}..."

    SKILL_DISPLAY="${SKILL_DISPLAY}  - /${skill_name}: ${description}\n"

    # Keyword matching
    desc_lower=$(echo "$description" | tr '[:upper:]' '[:lower:]')
    for word in $desc_lower; do
      [[ ${#word} -lt 4 ]] && continue
      clean_word=$(echo "$word" | tr -d '[:punct:]')
      [[ -z "$clean_word" ]] && continue
      if echo "$PROMPT_LOWER" | grep -qw "$clean_word" 2>/dev/null; then
        RECOMMENDATIONS="${RECOMMENDATIONS}  - /${skill_name} (matched: ${clean_word})\n"
        break
      fi
    done
  done <<< "$SKILL_FILES"
fi

# Output: skill discovery + forced evaluation protocol
cat <<HOOKEOF
[$HOOK_NAME] FIRED — ${SKILL_COUNT} skills found

MANDATORY SKILL ACTIVATION SEQUENCE:

Step 0 - SCOPE ASSESSMENT (do this FIRST):
Classify the request:
| Scope | Criteria |
|-------|----------|
| Passthrough | Quick answer from memory/context, no tools needed |
| Mini | 1-2 steps, single lookup or small edit |
| Small | 3-5 steps, single deliverable |
| Medium | 5-15 steps, multi-file, research needed |
| Large | 15-50 steps, deep research, multi-deliverable |
| Ultra | 50+ steps, cross-session, major initiative |

Output: **Scope: [LEVEL]** — [one-line justification]

Step 1 - EVALUATE SKILLS:
Available skills:
$(echo -e "$SKILL_DISPLAY")
Keyword matches for this prompt:
$(if [[ -n "$RECOMMENDATIONS" ]]; then echo -e "$RECOMMENDATIONS"; else echo "  (none detected — evaluate manually)"; fi)

For each skill, state: [skill-name] - YES/NO - [reason]

Step 2 - ACTIVATE:
IF any skills are YES → Use Skill(skill-name) tool for EACH relevant skill NOW
IF no skills are YES → State "No skills needed" and proceed
CRITICAL: You MUST call Skill() tool in Step 2. Do NOT skip to implementation.

Step 3 - PRE-FLIGHT (Medium+ ONLY):
Before launching sub-agents, verify:
- Asked clarifying questions (scope, purpose, output format)?
- Gathered initial context (read relevant files)?
- Created TaskCreate entries for the work?
- Created/updated STATE.md if this is a tracked task?

Step 4 - IMPLEMENT after Steps 1-3 are complete.
HOOKEOF
