---
title: "Adding Rules"
last-updated: 2026-04-08
related-files: [.claude/rules/hub.md, .claude/rules/scripts.md, .claude/rules/knowledge.md, .claude/rules/index-consultation.md]
---

# Adding Rules

Rules are path-specific instructions that load automatically when Claude Code accesses a matching file path. They define standards and conventions for specific parts of the project.

## File Location

Rules live in `.claude/rules/`. Each file is a markdown document with YAML frontmatter specifying which paths trigger it.

## Frontmatter Format

```yaml
---
globs: {glob pattern or array of patterns}
---
```

### Glob Pattern Examples

| Pattern | Matches |
|---------|---------|
| `hub/**` | All files under hub/ |
| `scripts/**` | All files under scripts/ |
| `knowledge/**` | All files under knowledge/ |
| `**/*` | All files (global rule) |
| `*.py` | All Python files |
| `hub/staging/**` | Only staging area files |

Multiple patterns:
```yaml
---
globs:
  - "scripts/**"
  - "*.py"
  - "*.ps1"
---
```

## When Rules Load

Rules load automatically when:
1. An agent reads a file matching the glob pattern
2. An agent writes to a path matching the glob pattern
3. Claude Code processes a tool call involving matching paths

Rules do **not** load at session start (unlike CLAUDE.md). They load on-demand as part of progressive disclosure.

## Existing Rules

| Rule | Glob | Purpose |
|------|------|---------|
| `hub.md` | `hub/**` | Orchestration protocol, dispatch templates, validation standards, changelog format |
| `scripts.md` | `scripts/**` | Script headers, language standards, TDD approach, security practices |
| `knowledge.md` | `knowledge/**` | KB article format, staleness detection, cross-reference conventions |
| `index-consultation.md` | `**/*` | Consult INDEX.md before searching, verify updates after writes |

## Creating a New Rule

### Step 1: Identify the Need

A rule is appropriate when:
- A specific directory has conventions that agents must follow
- You want standards enforced automatically (not just documented)
- Multiple agents work in the same area and need consistent behavior

### Step 2: Write the Rule

```markdown
---
globs: "ops/runbooks/**"
---

# Runbook Standards

This rule is auto-loaded for all `ops/runbooks/**` paths.

---

## Required Format

Every runbook MUST include:

1. YAML frontmatter with: title, version, owner, tags, last-tested
2. Prerequisites section listing required access and tools
3. Step-by-step procedure with numbered steps
4. Rollback section for any destructive actions
5. Changelog section (max 10 entries)

## Testing Requirement

Runbooks MUST include a `last-tested` date in frontmatter. Runbooks not
tested within 90 days are flagged as stale.

## Example

```yaml
---
title: "Phishing Triage Runbook"
version: "1.0"
owner: {{user.name}}
tags: [phishing, triage, incident-response]
last-tested: 2026-04-08
---
```
```

### Step 3: Save and Test

Save to `.claude/rules/{name}.md`. The rule activates immediately — no restart needed. Test by having an agent access a file matching the glob pattern and verify the rule's standards are followed.

## Tips

- **Keep rules focused** — one rule per directory/concern
- **Include examples** — agents follow examples more reliably than abstract instructions
- **Use "MUST" and "NEVER"** — clear imperatives work better than suggestions
- **Reference templates** — point to `hub/templates/` for format details rather than duplicating
