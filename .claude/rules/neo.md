---
globs: "hub/staging/*/neo-results/**,.claude/commands/neo.md,docs/external/neo/**,docs/morpheus-features/neo-integration.md"
schema-version: 1
---

# Neo Conventions

This rule auto-loads when Tyler is editing Neo-related files: the `/neo` skill, the Neo external docs, the feature doc, or anything under a task's `neo-results/` cache directory. It defines query naming, result schema, caching, key safety, and Tyler-approval gates. The skill body remains the procedural source of truth; this rule encodes conventions that should auto-load whenever a downstream agent or Tyler is touching Neo work.

---

## Query Naming Convention

When a Neo invocation is captured to disk (cached result, archived investigation, or audit-ledger row), the slug used to name the file MUST follow:

```
<verb>-<entity>-<filter>
```

- **Verb** (lowercase imperative): `investigate`, `hunt`, `lookup`, `audit`, `triage`, `contain`, `verify`
- **Entity** (kebab-case noun): `<user-upn-without-@domain>`, `<host-shortname>`, `<ip>`, `<domain>`, `<hash-prefix>`, `<incident-id>`
- **Filter** (optional, kebab-case): time window or scope qualifier — `7d`, `tor-login`, `failed-mfa`, `phishing-2026q2`

Length cap: 60 characters (slug only, not full filename). Examples:

- `investigate-jsmith-tor-login`
- `hunt-failed-mfa-7d`
- `lookup-laptop-js4729-defender-alerts`
- `audit-vendor-domain-evil-co`

The slug feeds `hub/staging/{task-id}/neo-results/{timestamp}-{slug}.ndjson` (raw NDJSON capture) and a sidecar `.meta.json` with structured metadata.

---

## Result Schema

When a Neo NDJSON output is captured to disk (rare — most invocations stream-and-discard), the file pair MUST be:

**`{timestamp}-{slug}.ndjson`** — raw NDJSON stream from `neo prompt --json`, untouched. Each line is one event per Neo's wire format (`session`, `thinking`, `tool_call`, `tool_result`, `confirmation_required`, `response`, `usage`, `context_trimmed`, `error`).

**`{timestamp}-{slug}.meta.json`** — structured sidecar:

```json
{
  "session_id": "conv_<uuid>",
  "query": "natural-language question, with NO embedded NEO_API_KEY or other secrets",
  "tool_calls_count": 4,
  "tool_calls_summary": ["run_sentinel_kql", "get_user_info", "search_xdr_by_host", "lookup_asset"],
  "response_summary": "1-2 sentence summary of Neo's final answer",
  "token_usage": { "input": 12345, "output": 678, "cache_read": 0 },
  "timestamp": "2026-04-24T16:30:00-05:00",
  "task_id": "{Morpheus task-id this invocation served, or null}"
}
```

The sidecar exists so downstream agents (verifier, documenter, /catch-up) can scan Neo invocations without re-parsing every NDJSON line.

---

## Caching Strategy

Neo invocations within a task SHOULD NOT re-run identical queries within 1 hour. Before invoking `neo prompt`, check `hub/staging/{task-id}/neo-results/` for a sidecar `.meta.json` whose `query` field matches and whose `timestamp` is within 1 hour. If hit, surface the cached result with a `[CACHED 2026-04-24T16:30 — N min ago]` prefix and skip the live call.

Cache invalidation:
- Different session id → no cache (sessions are independent conversations)
- Tyler types `/neo --no-cache <query>` → bypass cache
- Cache entries older than 24 hours → ignore (data has likely changed)

Caching is OFF by default for destructive actions (admin role) — every destructive invocation runs live. The cache is for read-only investigations.

---

## Credential Safety

Two auth paths exist; neither credential value may appear in any artifact, log, daily note, transcript, or git-tracked file.

### Primary path — Entra ID (Goodwin canonical, 2026-04-28)

`neo auth login` performs Entra ID browser SSO and writes the token to `~/.neo/config.json`. File is created with mode 0600 (owner-only) by the Neo CLI. The token is the operative credential.

Concrete prohibitions:

- Never `cat ~/.neo/config.json` to a shared channel, log file, or screen-share window — the token is bearer-equivalent until it expires
- Never copy `~/.neo/config.json` to another machine, project directory, or backup location — tokens are machine-bound by user-context expectation
- Never check the file mode is anything other than 0600 (`stat -c '%a' ~/.neo/config.json` should return `600` on Git Bash; `(Get-Acl ~/.neo/config.json).Access` on PowerShell). If wider, restore via `chmod 600` (Bash) or `icacls` (PowerShell)
- Never include token contents in `--json` output that gets logged — `neo prompt --json` stdout includes session/tool/response events but should NOT contain the token; if it ever does, that's a Neo-side bug to file with Patrick
- If `~/.neo/config.json` is suspected leaked: `neo auth logout` immediately + `neo auth login` to mint fresh, then change Entra password if compromise extends beyond Neo

### Fallback path — `NEO_API_KEY` env var (service-account use cases)

The `NEO_API_KEY` environment variable value MUST never appear in any artifact, log, daily note, transcript, or git-tracked file. Only the env-var **name** (`NEO_API_KEY`, as a literal reference in documentation or the skill body) may appear.

Concrete prohibitions:

- Never `--api-key` flag on `neo prompt` (process table exposure via `ps aux` / Windows Task Manager)
- Never inline `NEO_API_KEY=value` in Bash command strings, daily-note timeline entries, audit ledger rows, or PR descriptions
- Never echo the env var value to stdout/stderr in any debugging step
- Never commit a `.env` file containing NEO_API_KEY to the repo
- Never include NEO_API_KEY in `--json` output that gets logged to a shared channel — `neo prompt --json` stdout may include tool inputs (UPNs, KQL queries, justifications) but not the key itself; keep it that way

If an API-key leak is suspected: rotate via Neo's Settings → API Keys → Revoke, then re-create + re-set the env var.

### When both paths are configured

If `~/.neo/config.json` exists AND `NEO_API_KEY` is set, the Neo CLI's resolution order determines which is used (per Neo's user-guide: API key overrides config file). Cleaner to pick one — for Tyler's interactive use, the canonical path is Entra ID; if you've kept `NEO_API_KEY` set from earlier onboarding attempts, consider unsetting it via `[Environment]::SetEnvironmentVariable('NEO_API_KEY', $null, 'User')` to reduce confusion.

---

## Tyler-Approval Gates

Certain Neo tool invocations within `/neo` require AskUserQuestion confirmation BEFORE the live call (in addition to Neo's own server-side destructive-action gating):

- **Identity-touching reads**: `get_user_info`, `search_user_messages`, `get_employee_profile`, `get_employee_login_history`, `get_appomni_identity` — these surface PII (emails, devices, sign-in history). The skill body enumerates these and fires AskUserQuestion before the first call within a session.
- **Destructive admin tools** (already gated by Neo, double-gated by Morpheus): `reset_user_password`, `dismiss_user_risk`, `isolate_machine`, `unisolate_machine`, `report_message_as_phishing`, `remediate_abnormal_messages`, `approve_threatlocker_request`, `deny_threatlocker_request`, `set_maintenance_mode`, `schedule_bulk_maintenance`, `enable_secured_mode`, `block_indicator`, `import_indicators`, `delete_indicator`, `action_appomni_finding`, `action_ato_case` — Morpheus NEVER auto-confirms; Neo's REPL prompt is the human-in-the-loop point. The `/neo` skill exit-code-1 handler routes Tyler to interactive resume.
- **High-volume PII queries**: any query that would return more than 100 user records, more than 50 message bodies, or more than 200 asset records — fire AskUserQuestion before invocation. Helpful queries are bounded; "list all users in tenant" is not.

The skill body section 4 (Step 4: Destructive-action handling) is authoritative for the destructive flow. This rule enumerates which tool names trigger the gate so the skill can be a thin checklist.

---

## Cross-References

- [ref:morpheus-features:neo-integration](../../docs/morpheus-features/neo-integration.md) — feature doc with architecture + decision tree
- [ref:external:neo-user-guide](../../docs/external/neo/user-guide.md) — Neo CLI v1.1.0 user guide (full tool inventory)
- [ref:external:neo-configuration](../../docs/external/neo/configuration.md) — Neo server/CLI configuration reference
- [ref:commands:neo](../commands/neo.md) — the `/neo` skill body (procedural source of truth)
- [ref:protocols:security](../protocols/security.md) — Security Operations Protocol that activates `/neo` for SOC-keyword prompts
- [ref:rules:daily-note](daily-note.md) — `#neo` tag rule for timeline entries

---

## Changelog

| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-28T09:15 | 2026-04-24-neo-skill-onboarding | orchestrator (post-Phase-1) | Renamed §Key Safety → §Credential Safety; split into Primary (Entra ID via `~/.neo/config.json`) + Fallback (`NEO_API_KEY` env var) paths. Reflects Patrick's sanctioned 2026-04-28 onboarding flow: Entra is canonical for Tyler's interactive use; API-key remains documented for service-account fallback. Added file-mode 0600 invariant on `~/.neo/config.json`. Added "when both are set" disambiguation. |
| 2026-04-27T09:35 | 2026-04-24-neo-skill-onboarding | builder (Wave 5 R1, applied by orchestrator) | Created initial neo.md rule. Frontmatter `globs:` covers neo-results cache + skill + external docs + feature doc. 6 body sections (Query Naming, Result Schema, Caching, Key Safety, Tyler-Approval Gates, Cross-References) + Changelog. T7b deliverable for AC6. |
