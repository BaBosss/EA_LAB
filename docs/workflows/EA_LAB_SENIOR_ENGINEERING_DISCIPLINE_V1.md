# EA_LAB Senior Engineering Discipline V1

Status: **SOURCE-ONLY PROPOSAL — review required**. Adopted from useful ideas in
[pstack / poteto-mode](https://github.com/cursor/plugins/tree/main/pstack), adapted to
EA_LAB. This is **not** the Cursor plugin, a provider/model switch, an agent launcher,
a new Control Tower, or an extension of execution authority.

## Authority and scope

Read `START_HERE.md`, the current pushed `origin/master`, `AGENTS.md`, the exact
assigned task contract, Lane Registry, incumbent owner/lease and the relevant
local `SKILL.md` **before** substantial engineering work. The canonical owner docs,
existing research contracts, negative evidence and remaining repair budgets
always outrank this document. Only the one Main CT may integrate accepted work.
No additional authors, reviewers, testers, gateways or dashboards are authorized
by reading this document. This discipline applies to eligible **T0–T2** work,
not T3 actions (MT5/optimization/HOLDOUT, Factory/Real Submit, trading, risk
changes, runtime or scheduler switch, privileged ACL/key changes, deployment,
secrets, destructive cleanup or owner attestation).

## Route by task, not by ritual

| Task | Existing EA_LAB skill / method | Required proof |
| --- | --- | --- |
| Hard bug, flaky regression | `skills/diagnosing-bugs/SKILL.md` | Exact failing repro and same-surface green repro |
| Feature / behavior change | `skills/tdd/SKILL.md` with agreed observable seam | RED → minimal GREEN; positive and negative behavior tests |
| Code quality / diff review | `skills/code-review/SKILL.md`; applicable `AGENTS.md` review gate | Spec and standards checks; independent exact-head scrutiny when required |
| Performance | Baseline instrumentation, one variable at a time | Comparable before/after measurements and regression checks |
| EA research / native testing | Research protocol, pinned Second Brain/negative memory, approved Harness | Frozen model/build/EX5/SET/broker/windows, native logs and graphs |
| Session recovery | Canonical Git/Registry/process/evidence, original task | Resume only unproven gate; no duplicate writer or retry |
| Simple docs/UI correction | Pin, narrowly edit, render/check | Relevant diff/visual/format proof; no unnecessary heavy process |

Do **not** blindly copy all pstack playbooks into `.agents`, `.claude` or `skills`:
EA_LAB already has `diagnosing-bugs`, `tdd`, `code-review`, and risk-specific
gates. Project-local skills are not automatically ChatGPT plugins. Cursor
slash commands and provider routing do not magically become available in Codex,
Gemini, Claude or ChatGPT.

## Non-trivial bug-fix procedure

1. **PIN:** Capture Git origin/base HEAD/TREE, exact file hashes, worktree
   dirty state, original failed receipt, owner, reviewer, frozen allowlist,
   remaining budget, shared paths and process/lease. If unverified, remain
   `PREP_ONLY` / `BLOCKED`, not a new writer.
2. **REPRODUCE:** Identify the *user-visible* symptom. Run or replay one tight,
   deterministic, red-capable check on the **same relevant surface** (CLI,
   browser size, actual authorized service, or authorized MT5 tester). Record
   command/input/environment/exit/raw output/hash in `BEFORE_RED`.
   If the relevant environment is unavailable, report `REPRO_BLOCKED`, not
   a guessed root cause or an asserted fix.
3. **ISOLATE:** Minimize the repro; inspect relevant code history and old
   negative receipts. Write falsifiable, ranked hypotheses. Use narrowly
   scoped instrumentation or differential experiments to distinguish them.
   Keep `OBSERVED_FACT`, `INFERENCE` and `UNKNOWN` separate. Tool/wrapper
   failure is not automatically a source-code defect or trading failure.
4. **FIX:** Prefer one change that addresses the proven mechanism. Stay within
   the original file allowlist and repair budget; no workaround that weakens
   safety guards, speculative abstraction, unrelated refactor or noisy
   comments/logs. Preserve previous failed candidates and untouched WIP.
5. **PROVE:** Re-run the original symptom check as `AFTER_GREEN`, adversarial
   negatives and impacted regression. Use the **same surface**; a passing
   unit test, adapter, compile, scheduled-task exit code, or mock alone does
   not prove native service/browser/MT5 behavior. Record identities,
   commands, exits and SHA256 receipts. `INCONCLUSIVE_WRONG_SURFACE` is not PASS.
6. **REVIEW:** Freeze one clean candidate HEAD/TREE and the acceptance-relevant
   evidence hashes. Run the contract's deterministic gates before one
   qualified, separate read-only exact-head reviewer. Never self-approve,
   PASS-shop, retry blindly or reset spent budget. Review FAIL remains FAIL.
7. **CLOSE:** Distinguish `EVIDENCE`, `SOURCE`, `RUNTIME`, `BROWSER/AUTH`,
   `MT5/EA_TEST` and `LIVE` outcomes. Source acceptance requires the exact
   designated Main CT integration/hook/remote gates; runtime and trading
   need their own explicit approval and real receipts. A source PR is
   **not** integrated source or installed runtime.

**Never block on an avoidable question.** If an authorized fixture, test,
read or benchmark answers it, run it. Stop only at a real owner decision,
resource/lease conflict, exhausted original budget or security/T3 boundary.
Continue other independent, authorized EA and SYSTEM work while one branch
is blocked; do not invent permission to bypass the blocker.

## Minimum defect receipt (one actual run, not a blank template called proof)

```yaml
lane_id: "<current Registry ID or UNKNOWN>"
original_owner: "<actor/session/lease or UNKNOWN>"
source_base_head_tree: "<verified sha/tree>"
surface: "<actual interface + config/build/browser width>"
before_red: { command: "<actual command>", exit: "<observed>", receipt_sha256: "<hash>" }
root_cause: { mechanism: "<proven or UNKNOWN>", falsifier: "<run + receipt>" }
changed_paths: ["<only allowlisted files>"]
after_green: { command: "<same-surface command>", exit: "<observed or NOT_RUN>" }
negative_regression: "<actual counts/receipts or NOT_RUN>"
review: { candidate_head_tree: "<sha/tree or null>", independent_verdict: "<result or NOT_RUN>" }
acceptance: { source: "<status>", runtime: "<status>", ea_test: "<status>", live: "NOT_AUTHORIZED" }
original_repair_budget_remaining: "<actual number or UNKNOWN>"
blocker_and_one_next: "<one independently verifiable next gate>"
```

## Required fail-closed checks

- **No before-red** → cannot claim root cause proved or bug fixed.
- **GREEN on wrong environment/surface** → `INCONCLUSIVE_WRONG_SURFACE`.
- **Unit PASS but native runtime untested** → `SOURCE_ONLY`/`RUNTIME_UNKNOWN`.
- **Reviewer absent, non-independent or HEAD drifted** → not source accepted.
- **Budget exhausted, unknown author/lease or conflicting writer** → preserve
  evidence; stop that branch, without a disguised successor or blind retry.
- **Missing, malformed, stale, future or unbound Monitor data** → `UNKNOWN`,
  never `0`, `false`, PASS or ACCEPTED by default.
- **MT5 Model1 screening only** → no Model4 Candidate claim and no HOLDOUT
  spend without exact separate approval and lineage.
- **Already accepted identical bytes/evidence** → reuse verified receipt
  instead of repeating a review solely due to a new chat or document.

## Field example — temporal parser incident

The 2026-10-14 lnwjud Temporal source lineage closeout recorded
`SOURCE_INTEGRATED_FF_REMOTE_VERIFIED` at
`af7739842645b7b31cfd52cd3e8c526b8be4de6c` with deterministic checks
55/55 adversarial, 28/28 temporal, 19/19 negative, 62/62 behavioral and
17/17 manifest. Its original `Get-FileHash` actor failure remained historical
FAIL and its repair budget spent. Source integration **did not** prove
installation, original actor recovery, Monitor health or running HTTP gateway.
Receipt locator: `D:\EA_LAB_CONTROL\evidence\ct-lnwjud-temporal-lineage-convergence-20261014\FINAL_TO_MAIN_CT_SOURCE_INTEGRATED_CLOSEOUT_20261014_R1.md`.

## Reporting and improvement loop

Report in Thai using `FACT / CURRENT / READY / BLOCKED / PARKED / LIVE JOB /
UNCERTAINTY / ONE NEXT`, source/runtime/test axes, exact IDs, changed paths,
negative results and remaining budget. Close a defect with the regression
check that would catch its recurrence. Propose a lint, harness or clearer
contract only when evidence identifies the repeated failure and an owner
admits the narrowly scoped improvement. **More rules are not automatically
better; verified behavior is the goal.**

Upstream reference: Cursor pstack README, poteto-mode `SKILL.md` and
bug-fix playbook (consult the live upstream before adopting new behavior).
This adaptation is not a copy of, or dependency on, the pstack plugin.
