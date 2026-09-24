# Monitor Convergence Follow-up V1 — Prospective Contract

Classification: MONITOR_SOURCE / NEW_SUCCESSOR_CONTRACT / NO_DEPLOYMENT_RUNTIME.

Predecessor `ct-monitor-convergence-wave2a-r1-20260922` remains rejected/blocked. Its invalid patch and preflight findings are preserved as design evidence only. Repair1 1/1 remains consumed; this contract does not regenerate that patch, rename a Repair2, or reset its budget.

## Objective

Close only the still-open owner-webapp convergence invariants while preserving already-correct Monitor behavior and fail-closed evidence semantics.

## Required invariants

- Bind to the actual SafeProjection producer schema; do not invent fields. Current producer identity/availability semantics must be verified before consumer logic is accepted.
- Unavailable/invalid evidence must never aggregate or render as qualified numeric zero.
- Do not invent expected/observed process-start identity fields that accepted providers do not supply.
- Do not trust or fabricate `consumption_state`, deliverable acceptance, or equivalent evidence without a qualified canonical producer/schema.
- Parse ordinary `Z` timestamps and valid offsets strictly without a pre-try crash; malformed/future/unparseable timestamps remain UNKNOWN/invalid as contracted.
- Propagate real source availability independently from transport/cache freshness.
- Freshness must age at actual read/render time; static capture age is not a substitute for current display aging.
- Malformed-only account sources remain invalid/unavailable and must not collapse to valid-empty.
- Server/build identity must make stale implementation reuse impossible; unchanged APP identity cannot silently serve an older server.
- Existing routing expectations and fail-closed behavior remain intact unless this contract explicitly changes them.
- No Monitor number, liveness, acceptance, runtime state, news/regime, or account status may be fabricated to satisfy UI presentation.

## Production-chain acceptance cage

The acceptance test must exercise the real chain, not a hand-built snapshot shortcut:

`Model.snapshot -> server serialization -> truth.js -> owner_webapp.js -> rendered DOM`

The cage must cover available, unavailable, malformed, stale, future, cache/transport-separated, and version-mismatch conditions. It must demonstrate that unavailable inputs cannot become zero and that rendered freshness changes as time advances.

## Scope and authority

Source changes may be proposed only after this contract is frozen and the implementation lane has explicit path ownership for the actual owner-webapp/server/tests surfaces. The rejected patch must not be applied wholesale or with weaker patch flags.

No Monitor deployment, tunnel/scheduler/service activation, runtime attachment, MT5 action, trading, risk/default change, or PROJECT_STATE/P03 mutation follows from this source contract.
## Acceptance

Before exact-head review:
- focused source/unit tests for every invariant above
- full production-chain rendered-DOM cage
- inherited relevant Monitor/data/browser regressions
- strict timestamp and malformed-account negatives
- stale-server/version negative
- source/provider schema binding proof
- PowerShell/JS/Python parse or compile checks as applicable
- `git diff --check`
- normal hooks

One bounded in-scope repair maximum. Freeze one exact clean head and obtain one independent acceptance-grade GPT Scrutiny. Author cannot self-approve. Workers do not push.

## Owner-authorized same-lane implementation (2026-09-24)

Owner resume instruction freezes this successor's scope on lane
`ct-monitor-convergence-followup-v1-20260923`, worktree
`D:\EA_LAB_CONTROL\w\monitor-convergence-followup-v1-0923`, registered base
`4e2363071c8569619aa5e6fbb20a86198e077fc8`. The Registry remains untouched.
The only authorized tracked changes are this contract and these seven paths:

- `tools/mobile_report_hub/owner_webapp/model.py`
- `tools/mobile_report_hub/owner_webapp/server.py`
- `tools/mobile_report_hub/owner_webapp/truth.js`
- `tools/mobile_report_hub/owner_webapp/owner_webapp.js`
- `tools/mobile_report_hub/owner_webapp/test_owner_webapp.py`
- `tools/mobile_report_hub/owner_webapp/truth.test.cjs`
- `tools/mobile_report_hub/owner_webapp/browser_truth.cjs`

Dependency sequence: bind producer fields and source identity -> implement model,
serialization and display truth -> focused/adversarial and production DOM gates ->
inherited regressions -> normal hooks and ONE normal `[codex]` commit only if all
gates pass -> return to Main CT for independent scrutiny. No author self-review,
push, source integration, deployment, hosting, restart, Scheduled Task, runtime or
MT5 mutation, trading, or risk/default authority is granted. Temporary isolated
test fixtures and disposable browser contexts are test evidence only. The rejected
Wave2A Repair1 has not been reopened, applied, or given another repair budget.

### Implemented source semantics

- `projection_view` consumes the existing `build_index.safe_projection` envelope:
  `status`, `entity`, `source_kind`, `authority`, `build_id`, `generated_at`,
  `accounts`, and `findings`. It preserves AVAILABLE/MISSING/INVALID. The producer
  enum matrix is exercised directly, including CONFLICT, WATCH and REAL_MONEY.
  No invented SafeProjection version, confidence, process-start, consumption or
  acceptance fields are consumed. Producer-local timestamps remain legal data but
  have UNKNOWN absolute freshness; only a qualified current projection supplies
  the findings count. A qualified empty list can be zero; unavailable evidence cannot.
- UTC/offset timestamps require full calendar-valid date/time, seconds and explicit
  `Z` or `+/-HH:MM`. Missing offsets, malformed dates and invalid offset components
  are rejected. Any future observation is FUTURE, never CURRENT. Source age is
  recomputed from the original timestamp on each route/filter render and every
  ten seconds while visible. A successful fetch or server cache hit does not reset it.
  Existing source freshness windows remain 26h (general/projection), 24h (Registry)
  and 30h (Control Room/live source/monitor detail). Process observations are
  explicitly OBSERVED and expire after the existing 30-second polling interval;
  unavailable process evidence cannot supply a current liveness/progress claim.
- Broker account times remain `BROKER_SERVER_TIME_TZ_UNQUALIFIED`. Chart range
  coordinates use calendar arithmetic only, never an absolute freshness assertion.
  Charts show discrete marks with no connecting segments, including across gaps.
  Malformed-only input is INVALID and absent input MISSING. Conflicting samples
  retain null marks. An unplaceable malformed sample withholds the potentially
  outdated latest balance; gaps never become numeric zero or a valid empty series.
- `/health` binds the loaded model/server source hashes, four actual asset hashes,
  startup time and configured source-root identity. Changed startup bytes refuse
  service/reuse; app-name-only and mismatched identities cannot reuse an old server.
  `truth.js` is serialized ahead of the production `owner_webapp.js` without changing
  HTML/CSS. Browser refresh rejects a mismatched server identity or schema.
- The DOM cage invokes real `Model.snapshot`, real file readers, `Application`
  caching, `server.render`/`serialize`, `truth.js`, and production owner-webapp DOM.
  Only Git blob I/O is replaced with bounded fixture bytes; no hand-built snapshot
  bypasses the model. API failure/version negatives are injected at the browser
  transport boundary. All seven routes execute in the actual browser DOM.

### Deterministic checkpoint (2026-09-24; uncommitted)

| Gate | Result |
| --- | --- |
| Focused owner-webapp Python suite | 29/29 PASS |
| `node .../owner_webapp/truth.test.cjs` | 9/9 PASS |
| `node .../owner_webapp/browser_truth.cjs` | 11/11 model-produced DOM scenarios PASS |
| Mobile hub data wrapper | 154 tests: 153 PASS, 1 existing privilege-dependent symlink skip |
| Mobile hub static UI wrapper | PASS |
| `agent_graph_v31.cjs` | 17/17 groups PASS |
| `research_workbook.test.cjs` | 93/93 checks PASS |
| `browser_navigation_binding.cjs` | 52/52 PASS, 390px and 1280px |
| `browser_research_workbook.cjs` | PASS, desktop/mobile/missing-index and storage negatives |
| SafeProjection S11 wrapper | BLOCKED: 85/87 scenarios pass; WIRE1 and WIRE2 cannot invoke `ajv`; wrapper Part B not reached |
| Schema structure / generated contracts check | PASS; 39 generated contract blocks match |
| `browser_v3.cjs` | FAIL at line 259: expects v3.3 cache identifier |
| `browser_native_graphs.cjs` | FAIL at line 214: expects v3.4 cache identifier |
| Python compile (3 files), JS syntax (4 files), `git diff --check` | PASS |
| Normal commit hooks | NOT RUN: all-gates-pass prerequisite is unmet; no commit attempted |

Runtime resolution was process-local only. Portable Python is `tools/python312/python.exe`
after `scripts/use_python.ps1`. Browser NODE_PATH used the existing
`D:/EA_LAB_CONTROL/external_tools/local_npm/playwright-cli/node_modules` and
`C:/Users/patip/AppData/Local/npm-cache/_npx/210338ee94cf9539/node_modules`.
The latter provides the AJV JavaScript module for browser tests, **not** the missing
`ajv` CLI required by S11. No replacement validator or weakened assertion was used.
Inherited browser fixture output is under
`%TEMP%/monitor-convergence-followup-v1-0924`; owner DOM fixtures are regenerated
in memory by `test_owner_webapp.py --browser-fixtures`.

The two inherited browser failures are bound to unchanged base bytes:
`git diff --exit-code HEAD -- mobile_report_hub/sw.js
tools/mobile_report_hub/tests/browser_v3.cjs
tools/mobile_report_hub/tests/browser_native_graphs.cjs` is clean. Actual
`mobile_report_hub/sw.js:3` uses
`ea-lab-report-hub-v3.9-second-brain-reader-repair1`, while the assertions demand
`ea-lab-report-hub-v3.3-dashboard-merge` and
`ea-lab-report-hub-v3.4-owner-report`. These files are outside this lane's write
scope. They were neither changed nor bypassed.

Disposition: **BLOCKED_REQUIRED_GATES**, not READY_FOR_MAIN_CT_MONITOR_SCRUTINY.
Main CT needs an authorized resolution for those unchanged regression assertions
and an available AJV CLI before all required gates and normal hooks can pass.
No commit/push or review has occurred. HEAD remains
`4e2363071c8569619aa5e6fbb20a86198e077fc8`, committed tree
`fc525d545ef5856f2396da43ee522f7960980faf`; the eight authorized files contain the
uncommitted candidate. This checkpoint is deterministic author evidence, not
acceptance or an independent review receipt.
