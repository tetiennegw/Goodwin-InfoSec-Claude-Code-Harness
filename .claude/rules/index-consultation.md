---
globs: "**/*"
schema-version: 1
---

# INDEX.md Consultation Rule

This rule applies globally to all paths. It ensures agents efficiently discover files by consulting INDEX.md before resorting to search tools.

---

## Before Searching: Consult INDEX.md

Before using Glob or Grep to search for files, FIRST check INDEX.md at the project root to see if the file or directory is already indexed.

**Protocol:**
1. If you need to find a file, read INDEX.md first
2. If INDEX.md has the path you need, use it directly -- no search required
3. Only use Glob/Grep if INDEX.md does not contain what you need
4. If you find a file via Glob/Grep that was NOT in INDEX.md, note this -- the PostToolUse hook should add it on next Write, but verify

This saves context tokens and keeps file discovery consistent across agents.

---

## After Creating Files: Verify INDEX.md Update

After creating any new file via the Write tool:
1. The PostToolUse hook (`update-index.sh`) automatically appends new files to INDEX.md
2. Agents should verify the hook fired by checking for `[HOOK:PostToolUse:Write] FIRED` in the output
3. If the hook did not fire or the file is missing from INDEX.md, manually add it

This ensures INDEX.md remains the accurate, complete directory source of truth.
