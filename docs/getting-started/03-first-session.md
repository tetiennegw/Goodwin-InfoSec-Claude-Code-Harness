---
title: "First Session"
last-updated: 2026-04-08
related-files: [.claude/settings.local.json, scripts/utils/ensure-note.sh, INDEX.md]
---

# What Happens on First Launch

When you run `claude` in the project directory, four hooks fire in sequence. Understanding this startup flow helps you troubleshoot and extend the system.

## Hook 1: SessionStart — ensure-note.sh

**Trigger**: Claude Code session begins.

**What it does**: Runs `scripts/utils/ensure-note.sh`, which creates today's notes from templates if they do not already exist:

- `notes/YYYY/MM/YYYY-MM-DD.md` — daily note
- `notes/YYYY/YYYY-WNN.md` — weekly note
- `notes/YYYY/YYYY-MM.md` — monthly note
- `notes/YYYY/YYYY-QN.md` — quarterly note
- `notes/YYYY/YYYY.md` — yearly note

**Expected output**:
```
[HOOK:SessionStart] FIRED — Created daily note for 2026-04-08: notes/2026/04/2026-04-08.md
[HOOK:SessionStart] SKIPPED — weekly note already exists: notes/2026/2026-W15.md
...
ensure-note.sh complete.
```

## Hook 2: InstructionsLoaded — INDEX.md Loader

**Trigger**: CLAUDE.md finishes loading.

**What it does**: Reads INDEX.md and outputs its contents so Morpheus has the directory map in context.

**Expected output**:
```
[HOOK:InstructionsLoaded] FIRED — INDEX.md loaded (23 entries)
```

Followed by the full contents of INDEX.md. This is how Morpheus knows what files exist without searching.

## Hook 3: UserPromptSubmit — Skill Assessor

**Trigger**: Every time you submit a prompt.

**What it does**: Scans `.claude/commands/` for available slash commands and checks if any match keywords in your prompt. Outputs the skill list and any recommendations.

**Expected output**:
```
[HOOK:UserPromptSubmit] FIRED — Available skills:
  /some-skill: Description of the skill
No specific recommendations for this prompt.
```

## What Morpheus Does Next

After hooks fire, Morpheus reads CLAUDE.md (its identity) and is ready for your first prompt. It will:

1. Consult INDEX.md (already in context from the hook) to understand the directory
2. Reference memory files if needed for your profile and preferences
3. Wait for your task

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `SKIPPED — INDEX.md not found` | INDEX.md missing from project root | Create INDEX.md or run a documenter pass |
| `ensure-note.sh: command not found` | Script not executable | Run `chmod +x scripts/utils/ensure-note.sh` |
| No hook output at all | Hooks not configured | Check `.claude/settings.local.json` has the hooks section |
| `jq: command not found` | jq not installed | Install jq: `winget install jqlang.jq` or `apt install jq` |
