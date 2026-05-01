---
title: Neo External Documentation
type: external-docs-index
source: Patrick Keenan (Neo owner)
ingested: 2026-04-28
next-refresh: 2026-07-28
refresh-cadence: quarterly
cli-version-at-ingest: "1.1.0 (CLI version-line); binary banner reads v2.0 — version drift TBD with Patrick"
status: active
---

# Neo External Documentation

Point-in-time snapshots of the Neo CLI user guide and configuration reference, ingested from Patrick Keenan's authoritative source on 2026-04-28. These files are read-only reference copies — do not edit them; refresh the entire directory on the quarterly schedule instead.

## Files in This Directory

| File | Purpose | Source Lines |
|------|---------|-------------|
| [user-guide.md](user-guide.md) | Day-to-day usage: getting started, REPL, one-shot prompts (`neo prompt --json`), reader/admin tasks, skills, administration, tool reference, role permissions, rate limits, API endpoints, alert triage API, observability | ~1305 |
| [configuration.md](configuration.md) | Web server env vars, API key management, Entra ID setup, CLI config, Azure app registration, third-party integrations (Lansweeper, Abnormal Security, ThreatLocker), Cosmos DB, prompt injection guard, structured logging, Azure deployment | ~1646 |

## Version Pin

- **Neo CLI version at ingest**: 1.1.0 (reported by `neo --version` or `neo auth status`)
- **Binary banner at ingest**: `[ S E C U R I T Y  A G E N T  v2.0 ]` (displayed in REPL on startup)
- **Version drift note**: CLI version-line (1.1.0) and binary banner (v2.0) do not agree. Confirm with Patrick Keenan which designator is authoritative before citing a version externally. See `hub/state/roadmap.md` "Neo follow-ups" for the tracking item.
- **Ingest date**: 2026-04-28
- **Next quarterly refresh**: 2026-07-28

## Placeholder Domain Notice

These ingested copies contain the generic placeholder domain `neo.companyname.com` in several places — notably in the Alert Triage API section of `user-guide.md` (lines 1048, 1089, 1143, 1146) and the Logic App configuration section of `configuration.md`.

**Goodwin's deployed URL is `https://app-neo-prod-001.azurewebsites.net`** (Azure-hosted; confirmed by Patrick's sanctioned configuration during Tyler's onboarding 2026-04-28). The internal domain `neo.goodwinprocter.com` has a bundled-Node TLS chain incompatibility with the Goodwin root CA and should not be used until Neo is rebuilt with the Goodwin root CA pinned.

The placeholder text has been left verbatim in these files as it appeared in the authoritative source. Morpheus skill artifacts (`.claude/commands/neo.md`, `.claude/protocols/security.md`, etc.) use the correct Azure URL.

## Security Caveat

These ingested copies are point-in-time snapshots. For the live, authoritative configuration:

1. Contact **Patrick Keenan** (Neo owner, `pkeenan@goodwinlaw.com`)
2. Refer to the Neo admin panel at `https://app-neo-prod-001.azurewebsites.net` (admin role required)
3. Do not rely on these files for production configuration decisions — always verify against the live server

## Refresh Protocol

On or before 2026-07-28 (quarterly):

1. Request updated docs from Patrick or download from the server's `/downloads` page
2. Replace both files (`user-guide.md`, `configuration.md`) with the new versions verbatim
3. Update this README's Version Pin section with the new version and ingest date
4. Update `next-refresh` frontmatter field to 3 months out
5. Add a changelog row below

## Cross-References

- Morpheus skill: [`.claude/commands/neo.md`](../../../.claude/commands/neo.md)
- Morpheus rule: [`.claude/rules/neo.md`](../../../.claude/rules/neo.md)
- Feature doc: [`docs/morpheus-features/neo-integration.md`](../morpheus-features/neo-integration.md)
- Memory: `memory/project_neo_integration.md`

## Changelog

| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-28T12:00 | 2026-04-24-neo-skill-onboarding | documenter (W10R1) | Initial ingest of user-guide.md (1305 lines) and configuration.md (1646 lines) from Patrick's authoritative source. README authored with version pin, placeholder notice, security caveat, and quarterly refresh schedule. |
