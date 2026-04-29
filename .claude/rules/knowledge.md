---
globs: knowledge/**
schema-version: 1
---

# Knowledge Base Standards

This rule is auto-loaded for all `knowledge/**` paths. It defines article format, staleness detection, cross-reference conventions, and changelog requirements.

---

## Article Format

Every knowledge base article MUST include YAML frontmatter with lifecycle metadata:

```yaml
---
title: {Article Title}
category: {security|tools|processes|infrastructure|compliance}
tags: [{tag1}, {tag2}]
created: 2026-04-07
last-updated: 2026-04-07
last-verified: 2026-04-07
review-interval: 90d
status: {draft|active|stale|archived}
author: {who created it}
---
```

### Required Fields

| Field | Purpose | Format |
|-------|---------|--------|
| `title` | Human-readable article name | Plain text |
| `category` | Top-level classification | One of the defined categories |
| `created` | When first written | YYYY-MM-DD |
| `last-updated` | When content was last changed | YYYY-MM-DD |
| `last-verified` | When content was last confirmed accurate | YYYY-MM-DD |
| `review-interval` | How often to re-verify | Nd (e.g., 30d, 90d, 180d) |
| `status` | Lifecycle state | draft, active, stale, archived |

### Article Body Structure

```markdown
# {Title}

## Summary
{2-3 sentence overview of what this article covers and why it matters.}

## Content
{Main article content, organized with clear headings.}

## References
- [ref:security:sentinel-overview](../security/sentinel-overview.md)
- {External links with access dates}

## Changelog
| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-07T15:30 | knowledge-base | documenter | Created initial article |
```

---

## Cross-Reference Convention

Use the greppable, bidirectional reference format:

```
[ref:{category}:{slug}]({relative-path})
```

**Examples:**
- `[ref:security:sentinel-kql-basics](../security/sentinel-kql-basics.md)`
- `[ref:tools:azure-cli-setup](../tools/azure-cli-setup.md)`
- `[ref:processes:incident-response](../processes/incident-response.md)`

### Rules
- The `ref:` prefix makes all cross-references greppable across the knowledge base
- Paths are relative from the current file to the target
- When creating a reference, verify the target file exists (Glob check)
- When renaming or moving an article, grep for all `ref:` links pointing to it and update them
- Bidirectional: if article A references article B, article B should reference article A in its References section

---

## Staleness Detection

Articles past their `review-interval` are flagged as stale:

- **Detection**: Compare `last-verified` + `review-interval` against today's date
- **Action**: Set `status: stale` in frontmatter
- **Resolution**: Re-verify content accuracy, update `last-verified` and set `status: active`

### Review Interval Guidelines

| Content Type | Recommended Interval |
|-------------|---------------------|
| Security advisories, threat intel | 30d |
| Tool configurations, API references | 90d |
| Process documentation, runbooks | 90d |
| Architecture decisions, design docs | 180d |
| Historical records, post-mortems | 365d |

---

## Changelog Requirement

Every knowledge article MUST include a `## Changelog` section at the bottom. Follow the standard changelog format (max 10 entries, newest first):

```markdown
## Changelog
| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-07T16:00 | knowledge-base | security-sme | Verified KQL examples against current Sentinel schema |
| 2026-04-07T15:30 | knowledge-base | documenter | Created initial article |
```

Missing changelogs will be flagged by SME assessors during validation.
