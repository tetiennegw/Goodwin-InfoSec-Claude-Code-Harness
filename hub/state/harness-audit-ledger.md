---
type: audit-ledger
purpose: Append-only audit record for `/the-protocol` invocations and signed-hook validator events
schema-version: 1
---

# Harness Audit Ledger

Every `/the-protocol` invocation appends a row here with PASS/FAIL evidence per `.claude/rules/hub.md`. Hooks (`protocol-execution-audit.ps1`, `task-discipline-audit.ps1`, `plan-compliance-audit.ps1`, etc.) also append rows here.

Legend: AUQ=AskUserQuestion, EPM=EnterPlanMode, XPM=ExitPlanMode, PLN=Planner-task (NA for Small/Mini, DEF for deferred), SCAF=scaffold-after-approval.

---

## Ledger

<!-- Append new rows below this marker. Never edit prior rows. -->
<!-- LEDGER-APPEND-ANCHOR -->
