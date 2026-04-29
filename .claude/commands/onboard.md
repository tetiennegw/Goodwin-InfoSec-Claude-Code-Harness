---
description: First-run onboarding — captures identity, optional extensions, scaffolds paths, seeds state files, runs dependency bootstrap, and stamps the .harness-onboarded sentinel. Idempotent — re-running on a stamped repo offers selective re-run.
user-invocable: true
allowed-tools: AskUserQuestion, Bash, Edit, Glob, Read, Write
schema-version: 1
created: 2026-04-29
last-updated: 2026-04-29
---

# /onboard — First-Run Setup

You are running `/onboard` for the {{harness.name}} (Morpheus) public template repo. Your job: walk the user through a 9-step setup that turns a fresh clone into a personalized, ready-to-orchestrate harness.

This skill is **idempotent**. On re-run, detect the `.harness-onboarded` sentinel, read its contents, and offer to re-run individual steps via `AskUserQuestion`. Never destructively overwrite user state without explicit confirmation.

---

## Pre-flight: sentinel check

1. Read `.harness-onboarded` from repo root if present.
2. If present:
   - Parse the JSON; surface `onboarded_at`, `harness_version`, `ext_enabled`.
   - Fire `AskUserQuestion`: "This repo has been onboarded ({{onboarded_at}}). Rerun onboarding?" with options:
     - **Re-run identity capture only** (steps 1-3 + 6 substitution)
     - **Re-run dep bootstrap only** (step 7)
     - **Re-run extension toggles only** (step 3 + relevant bootstrap)
     - **Full rerun** (all 9 steps)
     - **Cancel** (exit /onboard)
   - Branch accordingly; skip steps not selected.
3. If absent: proceed to Step 1.

---

## Step 1 — Identity capture

Use `AskUserQuestion` with multiple questions in a single batch (AUQ supports up to 4 questions per call).

**Questions** (Q1-Q5, all freeform-style; pre-fill defaults where safe):

| # | Question | Default | Required? |
|---|----------|---------|-----------|
| Q1 | What is your full name? | (no default) | YES |
| Q2 | Work email? | (no default) | optional — user may skip |
| Q3 | Job title / role? | "Security Analyst" | YES |
| Q4 | Direct manager's name? | (no default) | optional |
| Q5 | Harness display name? | "Morpheus" | YES |

After Q1-Q5, fire a second AUQ call:

| # | Question | Default | Required? |
|---|----------|---------|-----------|
| Q6 | Company name? | "Goodwin Procter LLP" | YES |
| Q7 | Company email domain? | "goodwinlaw.com" | YES |
| Q8 | Threat profile? (LOW/MEDIUM/HIGH) | "HIGH" | YES |
| Q9 | Industry? | "Legal" | optional |

Persist answers to a transient JSON map at `hub/state/.onboard-substitutions.json` (gitignored — temporary). Schema:

```json
{
  "user": {"name": "...", "email": "...", "role": "...", "manager": "..."},
  "harness": {"name": "...", "tagline": "Orchestration discipline for Claude Code", "repo-url": ""},
  "company": {"name": "...", "domain": "...", "threat-profile": "...", "industry": "..."}
}
```

---

## Step 2 — Team capture

Fire `AskUserQuestion` (single yes/no): "Add team members now? (You can extend later via direct CLAUDE.md edits.)"

- **No** → record `team.members = []` and proceed.
- **Yes** → loop AUQ for up to 5 rows. Each row asks `name`, `role`, `handle`, `notes` (multi-question via AUQ batch). Stop when user answers "Done" or hits 5 rows. Record to `hub/state/.onboard-substitutions.json` under `team.members[]`.

---

## Step 3 — Extension toggles

Fire `AskUserQuestion` (multiSelect): "Which optional extensions to enable?"

- `neo` — Neo CLI delegation (Goodwin internal SOC tool)
- `planner` — Microsoft Planner two-way sync (Entra tenant required)
- `codex` — OpenAI Codex CLI for /second-opinion
- `signing` — Authenticode signing of PowerShell hooks (BYO cert)

Record selections to `hub/state/.onboard-substitutions.json` under `ext.{name}` as booleans.

For each selected extension, fire a follow-up AUQ for config:

- `neo=true` → ask `neo.endpoint` (default: `https://app-neo-prod-001.azurewebsites.net`)
- `planner=true` → ask `planner.tenant_id` (no default; must supply)
- `codex=true` → record only; API key handled in step 7
- `signing=true` → ask "BYO cert path or thumbprint?" (D8 BYO-cert path)

---

## Step 4 — Path scaffolding

Run via Bash:

```bash
TODAY_YYYY=$(date '+%Y')
TODAY_MM=$(date '+%m')
mkdir -p \
  notes/$TODAY_YYYY/$TODAY_MM \
  ingest/processed/$TODAY_YYYY/$TODAY_MM \
  hub/staging \
  hub/state/daily-note-snapshots \
  hub/state/replay-corpus \
  hub/context-log/$TODAY_YYYY/$TODAY_MM \
  memory \
  ops/incidents ops/runbooks ops/brand \
  thoughts/second-opinions \
  knowledge/security knowledge/tools knowledge/processes \
  .claude/plans
echo "[/onboard step 4] Path scaffolding complete: 12 directory chains created (idempotent)."
```

This is idempotent — `mkdir -p` is safe to re-run.

---

## Step 5 — Seed files

Write the following seed files. Use Write tool where allowed; fall back to Bash heredoc for `.claude/` paths.

**Required seeds:**

1. `hub/state/harness-audit-ledger.md` — already in repo with anchor; verify presence via Read. If missing or corrupted, re-write from `hub/templates/audit-ledger-seed.md` (or inline below).

2. `hub/state/active-tasks.md` — header-only seed:
   ```markdown
   # Active Tasks
   _Auto-generated by `scripts/utils/generate-active-tasks.sh` from `hub/staging/*/STATE.md` frontmatter._

   | Task ID | Status | Wave/Round | STATE.md | Last Updated |
   |---------|--------|------------|----------|--------------|
   ```

3. `hub/state/completed-tasks.md` — empty table-header.

4. `hub/state/episodic-log.md` — header + `## Changelog` block.

5. `hub/state/roadmap.md` — empty skeleton with `## Active`, `## Backlog`, `## Done` sections.

6. `hub/state/context-categories.md` — frontmatter + `# Context Categories` heading.

7. `notes/$TODAY_YYYY/$TODAY_MM/$TODAY.md` — copy from `hub/templates/daily-note.md` (which contains the `<!-- PREPEND-ANCHOR:v1 -->` marker per `.claude/rules/daily-note.md`). Today's date format: `date '+%Y-%m-%d'`.

8. `memory/MEMORY.md` — overwrite the stub with derived starter index (per D7 minimal-derived-starters):
   ```markdown
   # Memory Index

   - [User Profile](user_profile.md) — {{user.name}}, {{user.role}} at {{company.name}}
   - [Company Context](company_context.md) — {{company.name}} ({{company.industry}}, threat profile: {{company.threat-profile}})
   - [Team Context](team_context.md) — direct manager + peers
   ```

9. `memory/user_profile.md`, `memory/company_context.md`, `memory/team_context.md` — minimal one-paragraph derived starter for each (D7).

10. `INDEX.md` — empty stub per D6 (auto-regenerated by `update-index.sh` PostToolUse hook on first user Write).

**Optional seed (only if `ext.planner=true`):**

11. `hub/state/planner-mapping.json` — empty skeleton:
    ```json
    {
      "tenant_id": "{{planner.tenant_id}}",
      "personal_board": null,
      "team_boards": []
    }
    ```

---

## Step 6 — Placeholder substitution

Invoke the substitution engine:

```bash
bash scripts/utils/apply-onboard-substitutions.sh hub/state/.onboard-substitutions.json
```

Or on PowerShell:

```powershell
pwsh -File scripts/utils/apply-onboard-substitutions.ps1 -SubstitutionsPath hub/state/.onboard-substitutions.json
```

The engine walks the SANITIZE file list (~30 files per `wave-3/manifest-draft.md`), applies `{{namespace.field}}` → captured-value substitutions, and validates that no residual `{{` tokens remain.

**Validation step**: post-substitution, run:

```bash
grep -rn '{{' --include='*.md' --include='*.json' --include='*.ps1' --include='*.sh' \
  CLAUDE.md INDEX.md .claude/ docs/ hub/templates/ scripts/ memory/ \
  || echo "[/onboard step 6] Substitution validation PASS — no residual placeholders."
```

If residual `{{` tokens are found, halt and ask Tyler to review (likely a missing field in the substitution map).

---

## Step 7 — Dependency bootstrap

Invoke the dep-bootstrap script:

```bash
bash scripts/utils/bootstrap-dependencies.sh
```

Or on PowerShell:

```powershell
pwsh -File scripts/utils/bootstrap-dependencies.ps1
```

The bootstrap script runs the 16-step order from `wave-2/runtime-deps.md §/onboard Bootstrap Recommendations`:

1. Detect OS + Goodwin endpoint
2. Verify Git + Git Bash (capture path → `paths.bash`)
3. Verify Claude Code CLI (`claude --version`)
4. Verify Node.js 18+
5. Verify PowerShell 7+
6. Optional jq install
7. ANTHROPIC_API_KEY (AUQ — capture & setx)
8. Corporate-proxy CA (Goodwin-detected only)
9. Optional gh CLI
10. Optional Codex (if `ext.codex=true`)
11. Optional Neo (if `ext.neo=true` AND Goodwin endpoint)
12. Optional Microsoft.Graph.Planner (if `ext.planner=true`)
13. Optional Pester
14. Code-signing cert resolution (if `ext.signing=true`)
15. Initialize hub state (already covered by step 5)
16. Hook signing (Goodwin AllSigned only — runs `/sign-script` over `.claude/hooks/*.ps1`)

The bootstrap script returns a structured JSON summary fed into step 8's sentinel.

---

## Step 8 — Stamp sentinel

Write `.harness-onboarded` (JSON, repo-root, gitignored) using bash heredoc:

```bash
cat > .harness-onboarded <<EOF
{
  "onboarded_at": "$(date '+%Y-%m-%dT%H:%M:%S%z')",
  "harness_version": "1.0.0",
  "user_email": "$USER_EMAIL",
  "ext_enabled": {
    "neo": $EXT_NEO,
    "planner": $EXT_PLANNER,
    "codex": $EXT_CODEX,
    "signing": $EXT_SIGNING
  },
  "substitutions_applied": $SUB_COUNT,
  "seed_files_created": $SEED_COUNT,
  "schema_version": 1
}
EOF
```

(Substitute the shell variables from the step 1-7 captures.)

The sentinel is the canonical "this repo is onboarded" record. Subsequent SessionStart hook reads it to suppress the onboarding banner.

---

## Step 9 — Welcome message + first-task hint

Print to stdout:

```
✓ Onboarding complete for {{user.name}} at {{company.name}}.

Harness: {{harness.name}} (orchestration discipline for Claude Code)
Sentinel: .harness-onboarded (gitignored)
Substitutions applied: {{substitutions_applied}} / 30 SANITIZE files
Seed files created: {{seed_files_created}}
Optional extensions enabled: {{ext-summary}}

NEXT STEPS:
  • Try `/research` — do your first investigation with structured findings
  • Try `/the-protocol` with a real task — see the orchestration loop in action
  • Try `/checkpoint` — save progress at a natural breakpoint
  • Read README.md for the full feature tour
  • Read docs/getting-started/ for the 4-doc walkthrough

{{harness.name}} is ready.
```

Also: prepend a timeline entry to today's daily note documenting the onboarding completion (per `.claude/rules/daily-note.md` §Prepend Protocol). Tag the entry `#onboard #setup #harness-init`.

---

## Idempotency contract

Re-running `/onboard` on a stamped repo:

1. Read sentinel JSON from `.harness-onboarded`.
2. Surface current state via AskUserQuestion (see "Pre-flight: sentinel check" above).
3. Honor user's selective re-run choice — skip path scaffolding (idempotent anyway), skip seed files unless explicitly re-requested.
4. Re-stamp sentinel with new `onboarded_at` + bumped `schema_version` if format changed.

Self-test: a second `/onboard` invocation immediately after a successful first run should result in `AskUserQuestion → Cancel` and exit with no filesystem changes.

---

## Error handling

- **Missing critical dep** (e.g., `claude --version` fails): halt at step 7; surface via AUQ; offer winget install or skip with warning.
- **Substitution residual** (step 6 validation fails): halt; surface the orphaned `{{` token and the file path; ask Tyler to add the missing field to the substitution map.
- **Sentinel write fails** (rare; permission issue): surface error, proceed but note "onboarding state not persisted — banner will reappear next session."
- **AUQ tool unavailable** (sub-agent context): halt with message "/onboard requires interactive AskUserQuestion; run from main session."

---

## Cross-references

- Architecture: `hub/staging/2026-04-28-morpheus-templatize-port/wave-3/repo-architecture.md` §3
- Decisions: `hub/staging/2026-04-28-morpheus-templatize-port/wave-4/manifest-final.md` (D7 + D8)
- Path deps: `hub/staging/2026-04-28-morpheus-templatize-port/wave-2/path-dependencies.md` §Onboarding Flow Implications
- Runtime deps: `hub/staging/2026-04-28-morpheus-templatize-port/wave-2/runtime-deps.md` §/onboard Bootstrap Recommendations
- Substitution engine: `scripts/utils/apply-onboard-substitutions.sh` (and `.ps1` variant)
- Bootstrap script: `scripts/utils/bootstrap-dependencies.sh` (and `.ps1` variant)
- Tests: `scripts/utils/test-onboard.sh` (and `.ps1` variant)

## Changelog

| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-29T10:00 | 2026-04-28-morpheus-templatize-port | builder (Phase 5 R1) | Created /onboard skill body with 9-step state machine, idempotency contract, AUQ batches for identity/team/ext capture, sentinel JSON schema, error handling. Shipped as docs/reference/onboard-skill-source.md fallback artifact (lockdown workaround per skeleton-receipt §7 Q2). |
