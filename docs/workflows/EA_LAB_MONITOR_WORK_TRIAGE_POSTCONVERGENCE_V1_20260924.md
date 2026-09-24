# EA_LAB Monitor Work Triage Post-Convergence V1

Classification: `READ_ONLY_PRESENTATION / SOURCE_CANDIDATE / NO_RUNTIME_OR_DEPLOYMENT_AUTHORITY`.

## Frozen base and authority

This bounded author change was first authored from exact accepted truth/freshness base
`1df924b1ac7e112148dd8a70773c8c63b0b9a893`, then mechanically reanchored without
path overlap onto canonical parent `4c3b6509ff399ac49e22af5614dd999cc8774575`.
The accepted Monitor truth/freshness Repair1 invariants remain the non-regression base. This change does not modify
`truth.js`, `server.py`, HTML/CSS, Registry, PROJECT_STATE, taskboards, runtime,
scheduled tasks, services, OneDrive, MT5, EA/core, research strategy, trading, or
risk/default state.

The reanchored source is committed only as a clean candidate for Main Control Tower freeze
and one separate exact-head acceptance-grade GPT Scrutiny. Commit presence is not
acceptance or integration; this author does not self-approve the candidate.

## Inputs consumed

Historical triage/support evidence was read as design input, not applied as an
accepted patch:

- `D:\EA_LAB_CONTROL\evidence\monitor-work-triage-v1-20260922\CONTROLLER_GAPS.md`
- `D:\EA_LAB_CONTROL\evidence\monitor-work-triage-v1-20260922\WAVE2A_REPAIR_AND_TRIAGE_RECONCILIATION_20260922.md`
- `D:\EA_LAB_CONTROL\evidence\monitor-convergence-wave2a-r1-20260922\TRIAGE_FROZEN_HEAD.diff`
- `D:\EA_LAB_CONTROL\evidence\monitor-convergence-wave2a-r1-20260922\TRIAGE_CONTINUATION_STAGED.patch`

The accepted truth/freshness contract and review evidence were treated as the
non-regression base:

- `docs/workflows/MONITOR_CONVERGENCE_FOLLOWUP_V1_20260923.md`
- `D:\EA_LAB_CONTROL\evidence\monitor-convergence-followup-v1-20260923\MONITOR_REPAIR1_TARGETED_RECHECK_RESULT_20260924.txt`
- `D:\EA_LAB_CONTROL\evidence\monitor-convergence-followup-v1-20260923\MONITOR_REPAIR1_FINAL_CANDIDATE_RECEIPT_20260924.json`

The targeted Repair1 recheck records `SCRUTINY_PASS / HIGH` against exact head
`1df924b1ac7e112148dd8a70773c8c63b0b9a893`. It does not review this successor
candidate.

## Behavior added

- `Model.work()` retains valid `DONE` Registry rows so accumulated history is
  inspectable. `unresolved` is true only when the raw Registry state is not
  `DONE`; historical blocker or `superseded_by` text cannot make a `DONE` row a
  current agent.
- `work_presentation()` derives display/category, concise Thai reason and next
  action, and narrowly scoped reconciliation notes. Its priority is repair
  exhaustion, state synchronization, review, other explicit blocker, Registry
  scope closure, then process/result presentation. Terminal job results never
  erase a higher explicit gate.
- Raw Registry state, blocker, job result, process observation, review identity,
  heads, dependencies, and supersession claim remain separate. Additive
  `acceptance=UNKNOWN`, `canonical=NOT_ASSESSED`, and `consumption=UNKNOWN`
  fields fail closed. `DONE`, `COMPLETE`, reviewed-head equality, and
  `superseded_by` never imply `PASS`.
- Existing `STALE_REGISTRY`, `LIVENESS_UNAVAILABLE`, `STALLED`,
  `RECOVERY_REQUIRED`, `ACTIVE_PROCESS`, and `TERMINAL_RECONCILE` display
  semantics remain available when no higher explicit gate applies. Overview,
  Agent Graph, and current unfinished counts require both current freshness and
  `unresolved=true`.
- The Work page defaults to `UNRESOLVED`, exposes `ALL`, `HISTORY`, `DONE`, and
  every observed raw/presentation state, searches lane/title/owner/worker/raw
  blocker/reason/next action, renders every matching row without a hidden
  100-row cutoff, and reports shown/total counts. The Thai empty result explains
  how to clear search or use `ALL / HISTORY`.
- The Work drawer shows raw Registry, derived presentation, job/process/review
  fields, fail-closed acceptance/canonical/consumption, evidence basis, and any
  supersession claim. All values pass through the existing HTML escape helper.
- Search/filter updates reuse the existing Work render path. Ten-second aging
  still uses the accepted DOM patch path, preserving live drawer/focus/details/
  scroll behavior; refresh/offline behavior is unchanged.

## Tests run

All commands ran from the assigned worktree with portable Python provisioned by
dot-sourcing `scripts/use_python.ps1` and calling `Assert-PortablePython`.

| Gate | Result |
| --- | --- |
| `tools/mobile_report_hub/owner_webapp/test_owner_webapp.py` | 33/33 PASS |
| `node --check tools/mobile_report_hub/owner_webapp/owner_webapp.js` | PASS |
| `node tools/mobile_report_hub/owner_webapp/test_work_ui.cjs` | 18/18 assertions PASS |
| `node tools/mobile_report_hub/owner_webapp/truth.test.cjs` | 9/9 PASS |
| `node tools/mobile_report_hub/owner_webapp/browser_truth.cjs` | 15/15 real model-to-DOM scenarios PASS |
| `scripts/_test/run_mobile_report_hub_data_tests.ps1` | 154 tests: 153 PASS, 1 known Windows privilege-dependent symlink skip |
| `scripts/_test/run_mobile_report_hub_ui_tests.ps1` | PASS |
| `git diff --check` | PASS |

Focused negatives cover terminal COMPLETE plus GPT scrutiny, terminal FAILED
plus serialized state convergence, exhausted repair, generic blocker, historical
DONE, supersession, missing durable-job liveness, every required search field,
history filters, more than 100 rows, empty recovery text, HTML-like blocker
escaping, and offline no-fetch.

## Limitations and handoff

- This layer presents existing evidence; it does not reconcile or mutate the
  Registry and does not independently establish acceptance, canonicality,
  consumption, success, or current process progress.
- `HISTORY` currently selects rows whose Registry scope is no longer unresolved;
  `DONE` selects the raw `DONE` state explicitly. They intentionally coincide for
  the current Registry state model but remain separate owner-facing concepts.
- No browser layout certification beyond the inherited model-to-DOM cage and
  static UI wrapper is claimed for this successor.
- No runtime, deployment, service, scheduler, hosting, OneDrive, MT5, trading,
  risk/default, or promotion authority is granted.
- Main CT must bind the reanchored exact candidate head, reuse only hash-identical prior
  deterministic evidence where valid, run any required exact-head checks, and obtain
  independent GPT Scrutiny before acceptance or integration.
