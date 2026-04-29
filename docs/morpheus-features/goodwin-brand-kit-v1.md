---
title: Goodwin Brand Kit v1
category: morpheus-feature
tags: [brand, templates, artifacts, ops, goodwin]
created: 2026-04-18
last-updated: 2026-04-18
last-verified: 2026-04-18
review-interval: 90d
status: draft
audience: Tyler (current), Goodwin security team (future open-source)
owner: {{user.name}}
related-runbook: none
related-state: hub/staging/2026-04-17-goodwin-brand-kit-v1/STATE.md
---

# Goodwin Brand Kit v1

> **Operational brand kit for Goodwin-stakeholder-facing artifacts -- reduces visual-identity scaffolding from ~2 hours of hand-crafting to under 10 minutes by providing CSS variables, HTML/Markdown templates, logo assets, and voice/tone rules derived from public sources.**

---

> **STANDING DISCLAIMER -- READ BEFORE USE**
>
> This kit is **NOT OFFICIAL GOODWIN BRAND GUIDANCE**. It is {{user.name}} personal operational aid, derived solely from public sources (goodwinlaw.com, official press kit, LinkedIn, AmLaw industry conventions, Sparrow presentation). No Marketing or OGC approval path has been established (approver: **UNASSIGNED**). Distribution: **Tyler-only**. Every artifact produced using this kit must carry this disclaimer until a named approver clears it for external use.

---

## Overview

**What it is**: A gitignored operational brand kit at `ops/brand/` containing a master guide, dual color palette, typography stacks, logo variants and usage rules, voice/tone guidelines, CSS custom properties, HTML and Markdown templates, logo assets, and a proof-of-concept Sparrow rebuild. Every rule and asset carries inline provenance metadata (`provenance: observed|inferred|substituted | source: URL | accessed: DATE`) so fidelity gaps are always explicit.

**Why it exists**: Tyler regularly produces Goodwin-stakeholder-facing artifacts (incident presentations, impact reports, memos) that require consistent visual and written identity. Before v1, each artifact required 2+ hours of hand-crafting color values, typography choices, and classification banner wording from scratch. The kit encodes those decisions once -- with full provenance -- so each new artifact takes under 10 minutes to scaffold. It also surfaces the firm dual visual identity: the public orange/charcoal brand (goodwinlaw.com, 2016 rebrand) vs. the AmLaw document-convention navy/gold palette (Sparrow presentation, IR artifacts).

**Who uses it**: Tyler directly. No agent automation wraps the kit in v1 -- it is a static asset library. Skill integrations (`/build-report`, `/research` brand-export mode, `/incident-triage` brand handoff) are gated for v2.

**Status**: `draft` -- v1 delivered. v2 gated on governance triggers (see Governance section).

## Architecture

The kit is a directory of standalone files. No runtime scripts, no hooks, no databases. All templates use `{{PLACEHOLDER}}` fields for content injection.

### Directory layout

The kit lives at `ops/brand/` (gitignored; not under `docs/standards/` because that would be a contradictory placement for a working-draft, public-source-derived kit).

    ops/brand/
    +-- GOODWIN-BRAND-GUIDE.md             master spec (start here)
    +-- Goodwin Logo Usage Guidelines.pdf  official PDF (observed; 12/15/22; 1.55 MB)
    +-- palette.md                         dual palette: orange/charcoal + navy/gold
    +-- typography.md                      Playfair Display + Source Serif Pro stacks
    +-- logo-usage.md                      6 variants with rules from official PDF
    +-- voice-and-tone.md                  Register/Classification/Structure/Citations + boilerplate
    +-- assets/
    |   +-- logo-*.{svg,png}              14 logo files (2 SVGs + 12 raster)
    +-- templates/
    |   +-- goodwin-brand.css             29 --gw-* custom properties, 52 .gw-* classes
    |   +-- presentation.html             265-line HTML scaffold, {{PLACEHOLDER}} fields
    |   +-- report.md                     266-line Markdown scaffold, classification banner
    +-- examples/
        +-- sparrow-rebuild.html           Sparrow rebuilt with kit CSS (visual proof)

### Provenance discipline

Every color hex, font name, logo variant rule, and voice guideline carries one of three provenance levels:

- **observed** -- directly seen or downloaded from a public source (screenshot, PDF download, live site CSS inspection)
- **inferred** -- reasonable inference from visual evidence, not directly confirmed in writing
- **substituted** -- an OFL-licensed stand-in for an inaccessible proprietary asset (primarily webfonts)

Approximately 100 provenance tags span the 7 brand documents. The discipline ensures fidelity gaps are never invisible assumptions -- when Marketing or OGC reviews the kit, every approximation is findable by grep.

### Dual palette rationale

Goodwin 2016 rebrand established an orange-dominant visual identity (`#D34D25`, `#F7941E`, `#2D3539` charcoal) observed on goodwinlaw.com. Sparrow and other AmLaw IR artifacts conventionally use navy/gold -- consistent with legal-industry document design but distinct from Goodwin marketing brand. The kit ships both as named palettes:

- **Palette A** -- Public marketing: orange (`#D34D25` / `#F7941E` gradient), charcoal (`#2D3539`), and accent variants. Provenance: `observed`.
- **Palette B** -- AmLaw document convention: navy, gold, and supporting tones derived from the Sparrow presentation. Provenance: `inferred` (firm-convention match, not firm-attested).

Labels prevent inadvertent blending of marketing and document palettes in a single artifact.

## User flows

### Flow 1: Scaffold a branded HTML presentation

**Goal**: Produce a Goodwin-branded HTML presentation skeleton in under 10 minutes.

**Steps**:
1. Copy `ops/brand/templates/presentation.html` into the task staging directory.
2. Open the copy; search for `{{PLACEHOLDER}}` -- every field is labeled with what it expects (title, incident name, classification, date, author, etc.).
3. Replace `{{PLACEHOLDER}}` fields with actual content.
4. Confirm classification banner wording with OGC if delivering externally. The default banner is `PRIVILEGED AND CONFIDENTIAL -- ATTORNEY WORK PRODUCT` (Sparrow-inherited; see Known Limitations).
5. Remove the `INTERNAL WORKING DRAFT` disclaimer footer only if the output has been cleared for external use by a named approver.
6. Open the file in a browser; verify it renders correctly. CSS loads via relative path to `goodwin-brand.css` -- adjust the link href if the copy is not co-located with the templates directory.

**Expected result**: A styled HTML file with Goodwin-orange header, classification banner, section structure, and all `{{PLACEHOLDER}}` fields clearly marked for content fill-in.

### Flow 2: Scaffold a Markdown impact report

**Goal**: Produce a structured Markdown report ready for content fill-in.

**Steps**:
1. Copy `ops/brand/templates/report.md` into the task staging directory.
2. Fill in YAML frontmatter fields: title, classification, date, author, task-id.
3. Replace `{{PLACEHOLDER}}` content blocks in the 5 required sections: Executive Summary, Impact Assessment, Technical Findings, Recommendations, Appendices.
4. The classification banner slot appears at the top of the document body -- confirm wording before sharing outside the immediate security team.
5. The standing disclaimer footer is pre-populated -- leave it in place unless cleared for external use.

**Expected result**: A frontmatter-valid Markdown file with classification banner slot, 5 structured sections, and standing disclaimer footer.

### Flow 3: Look up a logo variant or color value

**Goal**: Find the correct logo file or hex value for a specific use case without guessing.

**Steps**:
1. For logos: open `ops/brand/logo-usage.md`. Six variants documented (full-color horizontal, full-color stacked, mark-only, reversed, monochrome-black, monochrome-white) with clear-space rules, minimum sizes (0.75 inch mark-only; 1.25 inch full logo), and 11 prohibited uses extracted verbatim from the official Goodwin Logo Usage Guidelines PDF (12/15/22).
2. Select the appropriate file from `ops/brand/assets/`. SVG preferred for digital; PNG variants cover size/background combinations.
3. For colors: open `ops/brand/palette.md`. 17 named colors (5 Palette A public, 12 Palette B document) with hex, RGB, WCAG contrast notes, usage guidance, and provenance tag.
4. For CSS: reference the `--gw-*` custom property in `goodwin-brand.css` (e.g., `var(--gw-orange)`, `var(--gw-navy)`).

## Configuration

No runtime configuration. The table below lists every file a user must know to use the kit.

| Path | Purpose | Required for |
|------|---------|-------------|
| `ops/brand/GOODWIN-BRAND-GUIDE.md` | Master spec -- start here | Orientation |
| `ops/brand/palette.md` | Hex/RGB/usage + provenance for 17 named colors | Any color decision |
| `ops/brand/typography.md` | Font stacks + fallback rationale | HTML/CSS work |
| `ops/brand/logo-usage.md` | 6 variants + rules from official PDF | Any logo use |
| `ops/brand/voice-and-tone.md` | 8 boilerplate snippets + classification guidance | Written artifacts |
| `ops/brand/assets/logo-*.{svg,png}` | 14 logo files (2 SVGs + 12 raster) | Artifacts with a logo |
| `ops/brand/templates/goodwin-brand.css` | 29 `--gw-*` custom properties, 52 `.gw-*` component classes | HTML templates |
| `ops/brand/templates/presentation.html` | 265-line HTML scaffold | Presentations |
| `ops/brand/templates/report.md` | 266-line Markdown scaffold | Reports and memos |
| `ops/brand/examples/sparrow-rebuild.html` | Sparrow rebuilt with kit CSS (visual validation) | Proof of kit fidelity |

### gitignore verification

`ops/brand/` is gitignored. Verify at any time:

    git check-ignore -v ops/brand/GOODWIN-BRAND-GUIDE.md
    # expected: .gitignore:N:ops/brand/   ops/brand/GOODWIN-BRAND-GUIDE.md

If the command returns nothing, the gitignore pattern is missing. Re-add `ops/brand/` (with trailing slash) to `.gitignore`.

### First-time setup

The kit is self-contained -- no installation required. If you cloned fresh, `ops/brand/` will be absent (gitignored) and must be reconstructed from the brand kit build task. To verify an existing installation:

1. Confirm `ops/brand/` is present on disk.
2. Confirm `ops/brand/templates/goodwin-brand.css` exists -- it is referenced by relative path in `presentation.html`.
3. Open `ops/brand/examples/sparrow-rebuild.html` in a browser. It should display a styled incident presentation. If CSS fails to load, adjust the relative path to `goodwin-brand.css` in the link tag.

## Known Limitations

These documented fidelity gaps in v1 are tracked candidates for v2 resolution when a governance contact is established.

| Limitation | Detail | Provenance level |
|-----------|--------|-----------------|
| Proprietary webfont inaccessible | Goodwin website uses a proprietary webfont whose name is not exposed in public CSS. `typography.md` uses OFL-licensed substitutes: Playfair Display + Source Serif Pro. Visually compatible but not the actual firm typefaces. | `substituted` |
| Internal IR document palette unconfirmed | Palette B (navy/gold) matches AmLaw tradition and the Sparrow color scheme, but has not been confirmed as Goodwin internal IR palette by any firm source. | `inferred` |
| OGC classification banner wording unconfirmed | Templates default to Sparrow-inherited banner: `PRIVILEGED AND CONFIDENTIAL -- ATTORNEY WORK PRODUCT`. OGC has not validated this wording for all artifact types. Confirm before external delivery. | `inferred` |
| Voice and tone rules not firm-attested | Voice/tone guidelines derived from AmLaw convention + Sparrow presentation tone analysis. Not Goodwin official communications policy. | `inferred` |

## Governance

### v2 trigger conditions

v2 scoping and skill integrations activate when **ANY ONE** of the following occurs:

| Trigger | Description |
|---------|-------------|
| (a) Named OGC or Marketing approver | A named contact from Goodwin Marketing or OGC provides written OK on v1 core docs (palette.md, logo-usage.md, voice-and-tone.md) |
| (b) 3+ branded artifacts in a single month | Tyler produces at least 3 artifacts using v1 templates within one calendar month -- signals operational value warranting deeper integration |
| (c) Teammate fork request | A Goodwin security teammate requests access to or a fork of the brand kit |

### v2 scope (deferred from v1)

| Item | Reason deferred |
|------|----------------|
| `/build-report` skill | Requires governance baseline; would automate OGC-adjacent classification decisions |
| `/research` brand-export mode | Non-trivial orchestration change; low urgency until v1 validated in production |
| `/incident-triage` brand integration | Same governance dependency as `/build-report` |
| Print CSS | Low-frequency need; handcraft when required |
| Memo template | Not produced frequently enough to justify v1 effort |
| Runbook template | Same as memo template |
| Footer standardization on internal templates | Minor polish; batch into v2 |

## Integration points

The brand kit is self-contained with no Morpheus hooks or skill wiring. This is intentional for v1.

| Touches | How | Files |
|---------|-----|-------|
| None (v1) | Static asset library -- no hooks, no skills, no STATE.md writes | -- |

Planned v2 integration surfaces:

| v2 Target | Planned integration |
|-----------|-------------------|
| `/build-report` skill | Auto-copy `report.md` template into task staging dir on skill init |
| `/research` skill | Brand-export mode renders research artifacts with Goodwin CSS |
| Hooks framework | `feature-change-detector.sh` could watch `ops/brand/templates/**` for edits and flag doc debt |

See [hooks-framework.md](hooks-framework.md) for how v2 hook wiring would work.

## Troubleshooting

### Common failure modes

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| CSS not loading in presentation.html | Relative path to goodwin-brand.css broken (copy not in templates/ dir) | Update the `<link>` href to the actual location of `goodwin-brand.css` |
| git status shows ops/brand/ files | .gitignore rule missing or wrong pattern | Run `git check-ignore -v ops/brand/GOODWIN-BRAND-GUIDE.md`; re-add `ops/brand/` to .gitignore if missing |
| Missed PLACEHOLDER on delivery | Search missed a field | Search for `PLACEHOLDER` (case-sensitive) in the output file before delivery |
| ops/brand/ absent after fresh clone | gitignored directory not cloned | Reconstruct by re-running the brand kit build task (Waves 2-3) per STATE.md |

## References

**Kit entry point**:
- [`ops/brand/GOODWIN-BRAND-GUIDE.md`](../../ops/brand/GOODWIN-BRAND-GUIDE.md) -- start here for any brand question

**Brand documents**:
- [`ops/brand/palette.md`](../../ops/brand/palette.md) -- dual palette: Palette A public orange/charcoal; Palette B AmLaw document navy/gold
- [`ops/brand/typography.md`](../../ops/brand/typography.md) -- Playfair Display + Source Serif Pro stacks with fallback rationale
- [`ops/brand/logo-usage.md`](../../ops/brand/logo-usage.md) -- 6 logo variants, rules from official Goodwin Logo Usage Guidelines PDF (12/15/22)
- [`ops/brand/voice-and-tone.md`](../../ops/brand/voice-and-tone.md) -- emphatic disclaimer, 8 boilerplate snippets, legal-exposure flags

**Templates and assets**:
- [`ops/brand/templates/goodwin-brand.css`](../../ops/brand/templates/goodwin-brand.css) -- 29 `--gw-*` custom properties, 52 `.gw-*` component classes
- [`ops/brand/templates/presentation.html`](../../ops/brand/templates/presentation.html) -- HTML presentation scaffold (265 lines)
- [`ops/brand/templates/report.md`](../../ops/brand/templates/report.md) -- Markdown report scaffold (266 lines)
- [`ops/brand/examples/sparrow-rebuild.html`](../../ops/brand/examples/sparrow-rebuild.html) -- proof artifact: Sparrow rebuilt with kit CSS
- [`ops/brand/assets/`](../../ops/brand/assets/) -- 14 logo files (2 SVGs + 12 raster PNG variants)

**Build history**:
- [`hub/staging/2026-04-17-goodwin-brand-kit-v1/STATE.md`](../../hub/staging/2026-04-17-goodwin-brand-kit-v1/STATE.md) -- full wave-by-wave build log
- Plan: `{{paths.home}}\.claude\plans\replicated-stirring-meerkat.md` (v2 revision, post-second-opinion re-plan)
- Second opinion: [`thoughts/second-opinions/2026-04-17-goodwin-brand-kit-plan.md`](../../thoughts/second-opinions/2026-04-17-goodwin-brand-kit-plan.md) -- plan review that defined v1 scope and governance framework

**Research**:
- [`hub/staging/2026-04-17-goodwin-brand-kit-v1/research-brand-intel.md`](../../hub/staging/2026-04-17-goodwin-brand-kit-v1/research-brand-intel.md) -- brand intelligence (545 lines, 19 provenance tags, 10 public sources)

**See also**:
- [hooks-framework.md](hooks-framework.md) -- v2 hook wiring target for brand kit skill integrations
- [orchestration-loop.md](orchestration-loop.md) -- orchestration loop that managed the brand kit build waves

## Changelog

| Timestamp | Project | Agent | Change |
|-----------|---------|-------|--------|
| 2026-04-18T01:54 | 2026-04-17-goodwin-brand-kit-v1 | builder | Created feature doc -- v1 initial, all sections complete |
