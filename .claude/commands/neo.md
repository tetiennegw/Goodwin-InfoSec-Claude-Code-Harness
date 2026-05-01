---
description: Delegate a security investigation to Neo (Goodwin's internal Claude-powered security agent). Wraps `neo prompt --json` with auth, session handling, destructive-action awareness, and daily-note logging. Use when read-only SOC tooling -- Sentinel KQL, Defender XDR, Entra, Abnormal, Lansweeper, AppOmni, ThreatLocker -- is the right surface.
user-invocable: true
allowed-tools: [Bash, Read, Edit, Glob, Grep, AskUserQuestion]
schema-version: 1
argument-hint: <natural-language investigation> [--session <id>] [--admin]
---

# /neo

Delegate a security investigation to Neo, Goodwin's internal Claude-powered security agent. Neo provides ~55 read-only SOC tools spanning Microsoft Sentinel, Defender XDR, Entra ID, Abnormal, ThreatLocker, Lansweeper, and AppOmni. Morpheus wraps the `neo prompt --json` CLI surface with session tracking, destructive-action gating, and automatic daily-note logging.

**Usage**: `/neo <natural-language investigation>` `[--session <id>]` `[--admin]`

---

## 1. Description

Neo is Goodwin's internal Claude-powered security agent, installed and directed by {{team.manager.name}} (Tyler's manager). It runs as an external CLI at `neo` and exposes ~55 SOC tools via a NDJSON-streaming JSON API. Neo is a **peer tool** to Morpheus -- Morpheus orchestrates workflows and tracks state; Neo executes security investigations using its privileged tool integrations.

**Owner**: {{team.manager.name}} (Goodwin InfoSec manager).
**Version in use**: Neo v1.1.0 (as of 2026-04-24).
**Sanctioned server URL**: `https://app-neo-prod-001.azurewebsites.net` (Azure-hosted; standard Azure cert chain, works out-of-the-box with neo.exe).
**Internal URL** (`neo.goodwinprocter.com`): present but **NOT recommended** -- the bundled-Node `fetch()` in neo.exe v1.1.0 does not honor `NODE_EXTRA_CA_CERTS` for the Goodwin-internal TLS chain. Symptom is generic `fetch failed`. The only known workaround is `NODE_TLS_REJECT_UNAUTHORIZED=0`, which disables TLS validation entirely and is INSECURE. Use the Azure URL instead.
**Auth**: Entra ID via `neo auth login` (browser SSO; token stored in `~/.neo/config.json` mode 0600). API-key fallback (`NEO_API_KEY` env var) exists for service-account use cases but is NOT the canonical path for Tyler's interactive use.

**When `/neo` is the right surface**: Any investigation that requires querying Sentinel KQL, Defender XDR alerts, Entra sign-in logs, Abnormal email analysis, ThreatLocker audit, Lansweeper asset lookup, or AppOmni SaaS security. Do NOT use for general coding, planning, or documentation tasks -- those stay in the default Morpheus orchestration flow.

---

## 2. When to Invoke

### Tyler-Explicit Invocation
Any time Tyler types `/neo <query>`, route directly to Step 0: Argument Parsing without AskUserQuestion.

### Proactive Offer Rule
When Tyler's message contains **any of the following security-ops keywords** AND the task scope is >= Small, Morpheus MUST fire AskUserQuestion offering Neo dispatch:

**Trigger keywords**: Sentinel, KQL, Defender, XDR, Entra, sign-in logs, MFA, risky user, Abnormal, phishing, ThreatLocker, Lansweeper, asset lookup, AppOmni, SOC, incident, IR, containment, isolate, password reset.

**Default answer**: "Yes, delegate to /neo (Recommended)" -- Tyler can override to "No, handle in Morpheus".

Cross-ref: `feedback_neo_offer_on_security_work.md` memory for the full offer-on-security-work rule.

**Do NOT auto-fire** for Passthrough scope or when Tyler has already typed `/neo` explicitly.

---

## 3. Prerequisites

Before `/neo` can be used, all of the following must be true. Complete Phase 1 Onboarding (below) if any prerequisite is unmet.

1. **`~/.neo/config.json` exists** with a valid Entra ID token (created by `neo auth login`). This is the canonical auth path.
2. **`neo config set server`** persisted with value `https://app-neo-prod-001.azurewebsites.net` (so subsequent invocations don't need `--server`).
3. `neo --version` returns a string containing `1.1.0` cleanly (no certificate errors, no ThreatLocker block — see Prerequisites A and D below).
4. `neo prompt --json "test"` returns valid NDJSON ending with a `response` event (smoke test).

**Optional**: `NEO_API_KEY` environment variable for service-account / non-interactive use cases. Not required if Entra auth is configured. If both are present, Neo's behavior is determined by which the CLI evaluates first — prefer one auth path or the other, not both.

### Prerequisite A -- ThreatLocker Whitelist for neo.exe

> **CRITICAL -- Read before first invocation.** ThreatLocker Application Control blocks ALL new `.exe` files by default, including `neo.exe`. This is DISTINCT from AllSigned policy, which applies only to `.ps1` scripts. AllSigned does NOT govern EXE files.

**First-invocation symptoms of a ThreatLocker block**:
- Command hangs (no output, no error) -- ThreatLocker intercepts execution before the process starts
- OR returns immediately with `Access is denied` from the OS
- ThreatLocker tray icon (system tray, lower-right) shows a pending request or alert badge

**Unblock procedure** (one-time; Tyler must run this):
1. Run `neo --version` once. If it hangs / returns "Access is denied": ThreatLocker is blocking it.
2. Open ThreatLocker (system tray icon -> right-click -> Open ThreatLocker).
3. Navigate to **Request Approval** and locate the pending blocked entry for `neo.exe`.
4. Submit approval request with reason: `Goodwin internal Claude security agent -- directed by {{team.manager.name}}`.
5. Wait for approval from Patrick or Goodwin IT.
6. After approval: re-run `neo --version`. Expect Neo banner / version output cleanly.

**Diagnostic**: Open ThreatLocker -> **Audit** -> filter by application name `neo.exe` or by the Program Files path (`C:\Program Files (x86)\Neo\`). Look for `Blocked` or `Approved` status with a recent timestamp.

### Prerequisite D -- TLS Chain Compatibility (Why We Use the Azure URL)

> Goodwin corporate endpoints route HTTPS through a TLS-terminating proxy that re-signs with the internal CA. The Goodwin root CA certificate is at `{{paths.home}}\goodwin-root-ca.pem`. Node-based tools normally use `NODE_EXTRA_CA_CERTS` to ingest this CA, but neo.exe v1.1.0's bundled Node `fetch()` does NOT honor that env var -- the bundled binary either ships its own CA bundle or uses undici's bundled-CA path that bypasses the env var.

**Confirmed via diagnostic 2026-04-27**:
- Raw `curl -H "Authorization: Bearer ..." https://neo.goodwinprocter.com/api/agent` → HTTP 200 + valid NDJSON (OS-level TLS chain works fine via OpenSSL)
- `neo prompt` against `neo.goodwinprocter.com` → generic `fetch failed`
- `NODE_TLS_REJECT_UNAUTHORIZED=0` makes neo.exe work but disables ALL TLS validation (insecure -- do not ship)
- `NODE_EXTRA_CA_CERTS={{paths.home}}\goodwin-root-ca.pem` does NOT help

**Sanctioned workaround (Patrick, 2026-04-28)**: Use the Azure-hosted URL `https://app-neo-prod-001.azurewebsites.net`. Azure's cert chain is in Node's default CA bundle, so the bundled-Node TLS bug is sidestepped entirely. This is the canonical Goodwin path until Neo is rebuilt with the Goodwin root CA pinned in.

**Distinguishing TLS failure from auth failure**:
- **TLS failure**: stderr contains `fetch failed` / `certificate` / `x509` / `self-signed` / `unable to verify`. Typically exit code 3.
- **Auth failure**: stderr contains `401` / `unauthorized` / `invalid api key`. Typically exit code 1.

**Do NOT regenerate the API key when you see `fetch failed`** -- that wastes a key rotation and does not fix the underlying TLS issue. Confirm with `neo config get server` that the Azure URL is set; if not, run `neo config set server https://app-neo-prod-001.azurewebsites.net`.

### Phase 1 Onboarding Flow (Tyler-Executed, One-Time)

Complete these steps once before first invocation. Manual Tyler-session steps -- not Morpheus-automated.

**(a)** **Verify ThreatLocker whitelist** -- in PowerShell, run `neo --version`. If "Access is denied" or hang: follow Prerequisite A unblock procedure before continuing.

**(b)** **Set the Azure server URL at User scope** so all your future PowerShell sessions inherit it:
```powershell
[Environment]::SetEnvironmentVariable('NEO_SERVER', 'https://app-neo-prod-001.azurewebsites.net', 'User')
```

**(c)** **Authenticate via Entra ID** -- this opens your browser for SSO; complete the sign-in flow:
```powershell
$env:NEO_SERVER = 'https://app-neo-prod-001.azurewebsites.net'  # hydrate for current shell
neo auth login
```
Expected output: a URL prints (browser auto-launches in most cases), Tyler completes login, terminal returns `Logged in as {{user.email}}`. Token is now in `~/.neo/config.json` mode 0600.

**(d)** **Persist the server as default** so you don't need `--server` on every invocation:
```powershell
neo config set server https://app-neo-prod-001.azurewebsites.net
```
Expected: `Default server saved: https://app-neo-prod-001.azurewebsites.net`.

**(e)** **Smoke test** the agent-to-agent path:
```powershell
neo prompt --json "reply with the single word OK"
```
Expected NDJSON stream including `{"type":"response","text":"OK"}`. Session ID is also emitted.

**(f)** **Restart Claude Code** so the parent app process inherits the updated `NEO_SERVER` User-scope env var. After restart, the SessionStart hook warning (`NEO_API_KEY not set`) may still fire — that's expected and harmless because `/neo` no longer relies on the API key. The hook check will be relaxed in a future update.

---

## 4. Step 0 -- Argument Parsing

Parse `$ARGUMENTS` before any tool call.

```
Full invocation: /neo <prompt_text> [--session <session_id>] [--admin]
```

Extract:
- **`prompt_text`**: Everything that is not a recognized flag (required). If empty: fire AskUserQuestion.
- **`--session <id>`**: Session ID from a prior Neo conversation. If present, use Mode B in Step 2.
- **`--admin`**: Escalation flag. Currently unused — admin-key creation is deferred to roadmap. If passed: warn Tyler that admin escalation requires interactive Neo REPL (`neo --session <id>`) and Morpheus will not auto-confirm destructive actions. Proceed with reader-token flow.

---

## 5. Step 1 -- Pre-flight Check

Run before any `neo prompt` invocation.

### Auth Configuration Check

Primary check: confirm Entra token exists and server is set.

```bash
if [ ! -f "$HOME/.neo/config.json" ]; then
  echo "ERROR: ~/.neo/config.json not found. Run: neo auth login"
  echo "See /neo skill body Phase 1 Onboarding for full flow."
  exit 1
fi
```

Optional fallback acceptance: if `NEO_API_KEY` is set (service-account use case), allow continuation even without config.json — neo CLI will pick up the env var.

### Server URL Check

```bash
SAVED_SERVER=$(neo config get server 2>/dev/null || echo "")
if [ -z "$SAVED_SERVER" ] && [ -z "${NEO_SERVER:-}" ]; then
  echo "ERROR: No server URL configured. Run: neo config set server https://app-neo-prod-001.azurewebsites.net"
  exit 1
fi
```

If saved server is the internal URL (`neo.goodwinprocter.com` or similar), warn but proceed:
```
WARN: Using internal Neo URL. The bundled-Node TLS chain bug may cause `fetch failed`.
      Recommend: neo config set server https://app-neo-prod-001.azurewebsites.net
```

---

## 6. Step 2 -- Execution Mode

Two modes depending on argument parsing in Step 0.

### Mode A -- New Conversation (no `--session` flag)

```bash
TMP_STDERR=$(mktemp /tmp/neo-stderr-XXXXXX.txt)
neo prompt --json "$prompt_text" 2>"$TMP_STDERR"
EXIT_CODE=$?
STDERR_CONTENT=$(cat "$TMP_STDERR")
# Session ID emitted as the first NDJSON line: {"type":"session","sessionId":"conv_..."}
```

### Mode B -- Continue Session (`--session <id>` passed)

```bash
TMP_STDERR=$(mktemp /tmp/neo-stderr-XXXXXX.txt)
neo prompt --json "$prompt_text" --session "$session_id" 2>"$TMP_STDERR"
EXIT_CODE=$?
STDERR_CONTENT=$(cat "$TMP_STDERR")
```

---

## 7. Step 3 -- Stream Parsing

Read NDJSON stdout line by line. Mandatory event handling:

| Event type | Morpheus action |
|------------|----------------|
| `session` | Extract `sessionId` -- the canonical session ID for STATE.md |
| `thinking` | Silently discard (internal reasoning; not surfaced to Tyler) |
| `tool_call` | Capture `tool_name` for "Tools Neo used" summary |
| `tool_result` | Discard (verbose; final answer arrives via `response` event) |
| `confirmation_required` | STOP -- route to Step 4: Destructive-Action Handling immediately |
| `response` | Capture `text` -- the final answer to surface to Tyler |
| `context_trimmed` | Warn: "Neo context trimmed -- consider breaking investigation into smaller queries." |
| `usage` | Capture `input_tokens` and `output_tokens` for budget display |
| `error` | Log `message` + `code`; route to Error Handling table in section 11 |

"Tools Neo used" summary format (present alongside final response):

```
Tools Neo used:
- <tool_name_1>
- <tool_name_2>
```

---

## 8. Step 4 -- Destructive-Action Handling

If a `confirmation_required` event is received OR exit code 1 with `paused for confirmation` in stderr:

**NEVER auto-confirm destructive actions.**

Present to Tyler via AskUserQuestion:
- Question: "Neo has paused -- it is requesting confirmation for a destructive action. You must resume interactively to approve or reject."
- Options:
  - "I will resume interactively: open a terminal and run `neo --session <session_id>`" (Recommended)
  - "Abandon this Neo session"

If Tyler chooses abandon: log the abandoned session ID to STATE.md under Open Items.

**Why not auto-confirm**: Destructive tools include device isolation, account disable, password reset, and email quarantine. Tyler's reader-role token cannot trigger these (Neo server-side enforces role); but if/when Tyler escalates to admin token, Morpheus still does not auto-confirm. The interactive REPL pause is the human-in-the-loop point.

---

## 9. Step 5 -- Result Reporting

Present to Tyler in this order after exit code 0:

1. **Neo's response** (from `response` event `text` field) -- full text
2. **Tools Neo used** -- bulleted list from `tool_call` events
3. **Token usage**: Input: {input_tokens} | Output: {output_tokens}
4. **Session ID**: Session: {sessionId} -- save for future `--session` resume
5. **80% budget warning** (if applicable): Warning: Neo is at >80% of its 2-hour token budget. Consider pausing.

---

## 10. Step 6 -- Daily-Note Logging

After every successful Neo invocation (exit code 0), prepend a timeline entry to today's daily note per `.claude/rules/daily-note.md`.

**Required fields for Neo invocation entries**:

```markdown
- **HH:MM AM/PM** - **Neo Investigation: <brief description>** #neo #security

  **Work Type**: Security Investigation via Neo

  **Tools Neo Used**:
  - <tool_name_1>
  - <tool_name_2>

  **Response Summary**: 1-2 sentence sanitized description (no raw UPNs, no verbatim queries)

  **Session ID**: <sessionId> (use with /neo --session <id> to resume)

  **Token Usage**: Input: {input_tokens} | Output: {output_tokens}

  **Strategic Value**: One paragraph explaining why this investigation mattered.

---
```

**The `#neo` tag is MANDATORY** on every Neo invocation entry. It enables cross-session retrieval: `grep -ri "#neo" notes/`.

Do NOT include raw Entra tokens, raw API key values, raw UPNs, or verbatim NDJSON `tool_call.input` fields in daily-note entries.

---

## 11. Error Handling

| Exit Code | Condition | Remediation |
|-----------|-----------|-------------|
| `0` | Success | Parse NDJSON; surface response + tool-call summary + token usage; proceed to Step 6 logging |
| `1` (paused for confirmation in stderr) | Destructive action paused | Route to Step 4 -- never auto-confirm; instruct Tyler to resume: `neo --session <id>` |
| `1` (other) | Agent error | Show stderr. If `401` / `unauthorized` / `token expired`: run `neo auth login` to refresh Entra token. |
| `1` (`fetch failed`) | TLS chain bug on internal URL | Confirm `neo config get server` returns the Azure URL. If not, run `neo config set server https://app-neo-prod-001.azurewebsites.net`. |
| `2` | Bad usage (invalid flags) | Config bug. Log to `hub/state/harness-audit-ledger.md`. Check Step 0. Do NOT retry. |
| `3` | Network / connectivity error | Show server URL. Verify VPN/network. If cert/x509 in stderr: see Prerequisite D — switch to Azure URL. |

---

## 12. Security Boundaries

These constraints are NON-NEGOTIABLE for every `/neo` invocation:

1. **Never use `--api-key` flag**. If using API-key auth (service-account fallback), always set `NEO_API_KEY` environment variable. The `--api-key` flag exposes the key in `ps aux` process listings and shell history.

2. **Never auto-confirm destructive actions**. See Step 4. Even with `--admin` flag active, Morpheus must not pass `--confirm` or equivalent. Tyler must approve interactively.

3. **Never commit credentials to any file**. This includes `NEO_API_KEY` env-var values, Entra tokens, the contents of `~/.neo/config.json`, refresh tokens, or any auth artifact. They live exclusively in OS-managed locations: env-var store (User scope) or `~/.neo/config.json` (mode 0600). If accidentally written to a project file: revoke + re-auth immediately. For Entra: `neo auth logout` then `neo auth login`. For API key: revoke at Neo Settings then regenerate.

4. **`--json` stdout is PII-bearing**. The `tool_call` event `input` field may contain UPNs, email addresses, Entra object IDs, KQL queries. Never log raw NDJSON to shared channels (Teams, Slack, Jira). Daily-note summary must be sanitized.

5. **Injection guard mode**: `INJECTION_GUARD_MODE=monitor` (Neo default). Do not change to `block` without understanding the false-positive rate on Goodwin tool inventory.

6. **Session IDs in STATE.md and HANDOFF.md only**. Neo `sessionId` values stored in STATE.md `neo-session-ids:` field and HANDOFF.md `## Neo Sessions` section (Ultra tasks). Do not store in CLAUDE.md, memory files, or daily-note entries beyond a single sanitized reference.

7. **Server URL is Azure (`app-neo-prod-001.azurewebsites.net`), not internal (`neo.goodwinprocter.com`).** The internal URL has a known bundled-Node TLS bug (Prerequisite D). Do not switch to internal URL without a sanctioned workaround from Patrick — and never via `NODE_TLS_REJECT_UNAUTHORIZED=0`.

---

## 13. Changelog

| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-28T09:10-04:00 | 2026-04-24-neo-skill-onboarding | orchestrator (post-Phase-1) | **Auth-path overhaul**: API-key + internal URL replaced with Entra ID (`neo auth login`) + Azure URL (`https://app-neo-prod-001.azurewebsites.net`) as canonical Goodwin path. Rewrote §1 (server URL + auth method), §3 Prerequisites + Phase 1 Onboarding flow (a-f), §5 Step 1 Pre-flight (config.json + server check instead of NEO_API_KEY check), §11 Error Handling (added `fetch failed` row, refreshed `401` remediation), §12 Security Boundaries (added boundary 7 — Azure URL canonical). Prerequisites A (ThreatLocker) and D (TLS chain) preserved with refreshed framing — D now explains *why* we use the Azure URL. NEO_API_KEY remains documented as service-account fallback. Confirmed working via Phase 1 smoke test 2026-04-28T09:05 by Tyler + Patrick. |
| 2026-04-24T00:00-05:00 | 2026-04-24-neo-skill-onboarding | builder (Wave 3 R1) | Created /neo skill: 13 sections, frontmatter per plan spec, Phase 1 onboarding flow, ThreatLocker whitelist prereq (Gap A/AC23), Goodwin root CA TLS prereq (Gap D/AC26), NDJSON stream parsing, destructive-action gating, daily-note #neo tag logging, security boundaries |
