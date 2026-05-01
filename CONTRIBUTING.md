# Contributing to {{harness.name}}

{{harness.name}} is a Goodwin InfoSec internal forkable orchestration harness. Most "contributions" are personal forks customized for individual Goodwin teammates. Upstream contributions are welcome for: new skills, new hooks, agent improvements, doctrine refinements, and bug fixes.

> **Audience reminder**: this repo is licensed for Goodwin Procter LLP internal use (see `LICENSE`). Do not fork to non-Goodwin GitHub orgs or redistribute outside Goodwin.

---

## 1. Forking & customizing

```bash
# Clone the canonical Goodwin InfoSec repo
git clone https://github.com/Goodwin-InfoSec/Goodwin-InfoSec-Claude-Code-Harness.git my-{{harness.name}}
cd my-{{harness.name}}

# Open Claude Code in this directory and run:
/onboard
```

`/onboard` captures your identity, team, company context, and optional-extension preferences (Neo, Planner, Codex, signing). It then substitutes `{{namespace.field}}` placeholders across ~30 SANITIZE files and stamps a `.harness-onboarded` sentinel.

For the 6 major customization vectors (agents, hooks, skills, rules, sme-domains, identity) see `docs/customization/`.

## 2. Contributing back

To submit a PR upstream:

1. Branch off `main` in your fork.
2. Make changes; verify locally (see PR Checklist below).
3. Open a PR against `Goodwin-InfoSec/Goodwin-InfoSec-Claude-Code-Harness`.
4. Required reviewers: at least one Goodwin InfoSec teammate familiar with the changed area.

Required for every PR:

- Passing `health-check.sh` (run by PostToolUse hook on every Edit/Write)
- No `{{` placeholder regressions in your changed files (run `grep -r '{{' .claude/ docs/ hub/templates/ | grep -v '\.gitkeep'` — should be empty in non-template files)
- North-Star Standard invariants preserved (see `docs/morpheus-features/north-star-standard.md`)
- No leakage of personal user / team / company values into committed files (post-substitution scan should still pass)

## 3. Development setup

Same as `/onboard`-driven setup:

- Goodwin endpoint (Win11 + Git Bash + Node 18+ + PowerShell 5.1 + PowerShell 7+)
- Claude Code CLI (`claude --version` >= 1.0)
- For hook authoring on Goodwin endpoints with ThreatLocker: see `docs/morpheus-features/scripting-lifecycle.md` and `.claude/rules/scripts.md` § PowerShell hooks for the **bash-fallback writer pattern** (mandatory for any hook that writes to the project tree — Storage Control denies `powershell.exe` writes regardless of signature).

## 4. PR checklist

- [ ] Code compiles / lints / tests pass (where applicable)
- [ ] North-Star invariants preserved (8 from `north-star-standard.md`)
- [ ] Audit-ledger format unchanged (rows still match `| {ISO} | {task-id} | {hook-tag} | RESULT:{PASS\|FAIL} | {details} |`)
- [ ] No `{{paths.*}}` / `{{user.*}}` / `{{company.*}}` resolved values committed
- [ ] No Goodwin-confidential paths committed (no `C:\Users\TE9\...`, no `tetiennegw`, no Sparrow/GWIN business logic)
- [ ] Feature doc added to `docs/morpheus-features/` if change adds a major capability
- [ ] Tests added for new scripts (Pester / pytest / bats-core per language)
- [ ] Daily-note timeline entry written documenting the change (per `.claude/rules/daily-note.md` § Prepend Protocol)

## 5. Code of Conduct

All contributors are expected to follow Goodwin Procter LLP's internal code of conduct. Be professional, be kind, assume good faith, and surface concerns through Goodwin InfoSec leadership ({{team.manager.name}} or successor) rather than escalating in PR threads.

## 6. License compatibility

By submitting a PR you agree to license your contribution under the repo's `LICENSE` (Goodwin internal use). Do not include third-party code with incompatible licenses (GPL, AGPL, BSL) — open an AskUserQuestion / Slack thread with InfoSec leadership before bringing in external dependencies.
