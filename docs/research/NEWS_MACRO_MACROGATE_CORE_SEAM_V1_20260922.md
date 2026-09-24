# News/Macro — MacroGate explicit-UNKNOWN core seam V1 — 2026-09-22

Status: AUTHOR PATCH PREPARED / DETERMINISTIC AND NATIVE GATES NOT YET RUN.

Authority ceiling: SOURCE/CORE TESTER-SEAM PARITY ONLY. This change does not authorize performance A/B, optimization, HOLDOUT, runtime or Monitor activation, deployment, DEMO/LIVE attachment, sizing, risk/default changes, or trading. It produces no strategy-performance verdict.

## Identity and authority

- Lane: ct-news-macro-mg-core-seam-v1-20260922
- Exact author base: 1852860a32de2661a63cf9b7b37a25cfd3872363
- Upstream native-parity canonical: 5e84dd3e7c662e80e631d7f9e72903d0ba2420c6
- Upstream reviewed tooling head: 2aab10ff2cdc70a35d428dfaff7cd22379628dac
- Upstream review: SCRUTINY_PASS / HIGH / ALLOW_INTEGRATION
- Required final review: a separate read-only, exact-head acceptance-grade GPT Scrutiny job after all deterministic gates pass. The author cannot self-approve.

Frozen source/evidence identities:

- causal timeline SHA256: 44ed3c16451bf9d8e9066d1f552939c62d3c0bfcb1c9059613ad4150d963ed5f
- causal manifest SHA256: 436baeeb45d1aba7d5176473dbc462963e43d1b31937e3fcbdf16ad76771d3e1
- native candidate SHA256: 9a960be151838156c36efaa5075899e072ffe4ce2eb8700faff9191b637b9840
- quarantine SHA256: 1578fd75476b414a501633e6a9d0b00623e034c5c4ac6637c7a484138179dd69
- MacroGate_Core.mqh reviewed dependency SHA256: 80a71cb73a54bfcfaae49857c2d977f5a6e120e553428035178043dd5717de93
- LabCore.mqh reviewed dependency SHA256: e4b89caf9c2ea725127fa7b34bdfc3484f242651f82aa7eb4850b7cb485e8301
- ThinkMarkets broker-clock contract SHA256: ce472070a96b970ea280aa672988bc8c05207b9ded9234c86b08e49703737a37

The frozen upstream result contains 2,180 stable server-time rows, 12 transition quarantines, and one action-level trigger mismatch on 2024-11-03. Upstream native parity remains unqualified and performance remains NOT_RUN.

## Bounded semantic change

MacroGate now distinguishes three parser outcomes:

1. the existing recognized states RISK_ON, NEUTRAL, RISK_OFF, and STRESS;
2. the explicit token UNKNOWN;
3. malformed or unrecognized text, represented internally as INVALID and skipped.

Explicit UNKNOWN is retained only while MQL_TESTER is true. Non-tester/live loading still skips UNKNOWN, preserving the prior behavior. A retained tester UNKNOWN participates in the existing ascending timeline and RowAsOf selection. When selected after the existing availability and row-staleness checks, MG_Tick clears MacroGate-owned BLOCK and LOTMULT global variables for every configured magic and returns.

The seam does not inspect, close, cancel, or modify positions or orders. The next recognized row resumes the existing trigger, block, and lot-multiplier behavior. Before-first-row, file and row staleness, ordering validation, lot multiplier, trigger policy, and the four recognized-state meanings are unchanged.

No exporter is changed. The semantic fixture uses server-time timestamps with offset zero. This seam does not invent a DST switch instant or qualify a performance quarantine interval; that clock/export contract remains a later prospective milestone.

## Focused no-trade fixture

MacroGate_UnknownSeam_Test writes its own CSV in the tester sandbox and emits exactly one matching PASS or FAIL verdict. It covers:

- explicit UNKNOWN parsing, retention, RowAsOf selection, and the 2024-11-03 prior-NEUTRAL quarantine case;
- RISK_OFF and STRESS setting BLOCK/LOTMULT, followed by UNKNOWN clearing both;
- NEUTRAL and RISK_ON followed by UNKNOWN remaining inactive;
- UNKNOWN followed by RISK_OFF or STRESS resuming the ordinary gate;
- malformed text being skipped rather than retained;
- unsorted recognized rows failing safe;
- pre-first-row and stale-row behavior remaining inactive;
- RISK_OFF trigger-disable behavior and STRESS trigger behavior remaining unchanged;
- unchanged position and pending-order counts for the whole fixture.

The focused PowerShell runner statically proves the live/non-tester skip and explicit tester gate, rejects trade APIs in the fixture, deploys only the test and its include dependency to an order-owned EA_LAB_TEST tree, requires a 0-error/0-warning compile, and launches only this Model-1 no-trade unit fixture. If the primary lane is busy it reports TESTER_BUSY without force or process termination. It leaves bounded deployed artifacts and reports their path because no post-run cleanup authority is assumed.

## Required integration gates

The patch integrator must verify the exact clean base, path allowlist, and git apply check before applying verbatim. Acceptance then requires:

- focused static/compile/native runner PASS;
- scripts/tpl_regression.ps1 CLEAN because shared core changed;
- git diff --check and normal hooks;
- exact-head clean/source/evidence identities;
- separate acceptance-grade GPT Scrutiny at HIGH reasoning.

A failure grants no performance or strategy conclusion. One bounded source repair is available only if the final review identifies an in-scope material defect, followed by impacted deterministic gates and one targeted exact-head recheck.
