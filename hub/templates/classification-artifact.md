---
type: classification-report
task-id: "{TASK_ID}"
agent: context-curator
created: "{YYYY-MM-DDTHH:MM}"
last-updated: "{YYYY-MM-DDTHH:MM}"
inputs:
  - "{absolute/path/to/file-1.ext}"
  - "{absolute/path/to/file-2.ext}"
taxonomy-file: "hub/state/context-categories.md"
taxonomy-entry-count-before: {N}
taxonomy-entry-count-after: {N+M}
confidence: high | medium | low
---

# Classification Report — {Short Title}

> Standardized output of the `context-curator` agent. Any skill invoking the curator receives one of these per classification run. The format is fixed — assessors and downstream skills rely on the section order and structure. See `.claude/agents/context-curator.md` for the agent definition and invocation contract.

---

## 1. Source Content Summary

One paragraph (2–4 sentences) describing WHAT the input file(s) actually contain, derived from direct reading of the file — not from the CONTEXT hint provided by the caller. If the caller's hint conflicts with the actual content, note the discrepancy here.

**Source integrity check**: confirm the file was readable and the content matches (or diverges from) the caller's CONTEXT summary.

---

## 2. Classifications

One row per input file. `Categories` lists all assigned labels (existing + new); `New?` flags categories created for this classification; `Confidence` is per-file; `Notes` explains any edge cases.

| # | File | Categories | New? | Confidence | Notes |
|---|------|-----------|------|-----------|-------|
| 1 | `{relative/path/from/repo/root}` | `cat1`, `cat2`, `cat3` | cat2, cat3 | High/Medium/Low | {per-file notes} |

---

## 3. New Categories Created

List every new category added to the taxonomy during this run. If none, state "No new categories — all content mapped to existing taxonomy."

- `{scope}:{slug}` — One-sentence definition of what this category covers. Why it was created instead of reusing an existing category. Expected future content that would fall into this category.

---

## 4. Classification Rationale

For each category assigned in section 2, explain the specific signal in the source content that justified that label. This is the audit trail — an assessor should be able to re-derive the classification from this section alone.

- `{category}` — {specific phrase, sentence, or attribute in the source that drove the assignment}

---

## 5. Confidence Assessment

Overall confidence level (must match the frontmatter field) with justification.

- **High** when: sender/source is explicit, scope/timeframe/entities are named, content unambiguously matches existing or newly created categories
- **Medium** when: some key signals are inferred rather than explicit, or one category is a judgment call
- **Low** when: content is fragmentary, sender is unknown, or multiple valid classifications conflict

**Signals raising confidence**: {list concrete signals from the source}
**Signals lowering confidence**: {list any ambiguities, missing context, or conflicting cues}

---

## 6. Downstream Signals

Things the curator noticed in the source that the calling skill (or Tyler) may want to act on. These are NOT cascades the curator executes — the curator is a leaf classifier. The caller decides what to do with these signals.

Organize by target surface:

### Cascade candidates (for `/ingest-context` or similar)
- {Proposed change → target file} with HIGH / MEDIUM / LOW risk tag and one-sentence rationale.

### Calendar / scheduling signals
- {Implied meeting, deadline, or time-sensitive item referenced in the source}

### Knowledge base signals
- {Suggests a new or updated `knowledge/` article}

### Daily note signals
- {Content worth logging in today's daily note beyond the automatic ingest entry}

### Other
- {Anything that doesn't fit the above buckets}

If a section has no signals, write "None."

---

## 7. Taxonomy Delta

Explicit accounting of the changes made to `hub/state/context-categories.md` in this run.

- **Entry count**: {before} → {after}
- **Last-updated timestamp**: {ISO timestamp}
- **Scopes touched**: `{scope1}`, `{scope2}`
- **Categories added**: `{category1}`, `{category2}`
- **Categories modified**: {list or "none"}
- **Categories deprecated**: {list or "none"}
- **Changelog entry appended to taxonomy file**: yes / no

---

## 8. Return Summary (inline to caller)

The 6–10 sentence inline summary the curator returned to the caller when this report was written. Paste verbatim for audit-trail purposes — this is what the calling skill saw.

```
{paste the inline return summary here}
```

---

## Changelog

| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| {ISO} | {task-id} | context-curator | Initial classification report |
