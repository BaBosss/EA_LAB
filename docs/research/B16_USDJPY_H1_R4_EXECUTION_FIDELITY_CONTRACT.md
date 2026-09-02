# B16 USDJPY/H1 BUY R4 Execution-Fidelity Robustness Contract

Status: `PREREGISTERED / RESEARCH_ONLY / NO PARAMETER SEARCH`
Hypothesis revision: `B16-R4-r1`
Canonical base at preregistration: `0dc2bb88ab34f931eca29b84d138caaa2ae9b8fd`
Direct consumer: decide whether the frozen B16 USDJPY/H1 BUY 14/30 research reference should be PARKED for execution-fidelity failure or retained as `R4_EXECUTION_FIDELITY_NOT_FALSIFIED` evidence.
HOLDOUT: `UNSPENT / FORBIDDEN`.
Optimization: `NONE / FORBIDDEN`.

## Accepted evidence reused — do not rediscover

- Accepted 14/30 historical Model-1 reference: MAIN PF 1.53 / net +252.53 / 275 trades / native EqDD 3.85%; BWD PF 1.11 / net +44.10 / 267 trades / native EqDD 2.40%. These numbers are historical context only because they came from another MT5 installation.
- Exact parent full-surface set SHA256: `7a8e8c78bfbcd245e039a629cceb8914a91531b86db23a2b5bf7c45f5778a782`.
- Accepted build receipt: `br-4fa94d22907b446ebc721d524bdfa5d1`; EX5 SHA256: `212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db`.
- H08 is closed `MAIN_PLATEAU_FOUND / CENTER_REJECTED_BWD / CLOSED_NO_RETUNING`; the failed 14/35 center does not authorize another RSI search.
- Current SingleTP/BasketTP behavior remains frozen by the accepted USDJPY/H1 exit-concentration diagnostic.
- H05 RSI, H06/H07 depth, and H08 RSI paths remain closed at their accepted scopes.

## Frozen parent

Symbol/TF/direction are `USDJPY / H1 / BUY`. Freeze `_16_RsiPeriod=14`, `_16_RsiLow=30`, `_16_MaxOrdersPerSide=10`, `_16_AtrMultFirst4=0.8`, `_16_AtrMultAfter=1.4`, `_16_LadderMult=1.0`, `_16_TpSingleAtrMult=0.35`, `_16_BasketTpUsdPer01=16.0`, `_16_OverlapMinUsd=5.0`, and every other parent strategy, sizing, protection, safety, and runtime input. H07 depth3 is not imported as a USDJPY default.

## Allowed robustness dimension and same-install rule

The sole experimental dimension is Strategy Tester model fidelity. All acceptance-critical evidence is a new paired lineage on `D:\Meta 5` only. Run in this order:

1. Model 1 MAIN: `2023.01.01..2025.12.31`.
2. Model 1 BWD: `2020.01.01..2022.12.31`.
3. Only if both controls pass, Model 4 MAIN on the same installation.
4. Model 4 BWD on the same installation.

Never compare acceptance-critical numbers from this lineage against Meta5b/Meta5c numbers. Historical H08 numbers remain context only. Before every runtime claim, query Lane Registry. `D:\Meta 5` is the Boss19 primary lane and Model 4 is globally serial; an active Boss19/Model4 owner means `WAITING_RUNTIME`, never process eviction or ownership bypass.

## Mechanical acceptance

Every cell must preserve exact set/build/EX5 identity, USDJPY/H1 identity, requested date window, deposit USD 10,000, leverage 1:100 MATCH, `Optimization=0`, full-window eligibility, non-truncation, fresh report provenance, and no unexplained tester/harness failure. Every full-window run receives the canonical year split. Strategy loss is evidence, not mechanical failure.

Model-1 control bars are preregistered as MAIN PF >= 1.20, net > 0, and >= 100 closed trades; BWD PF >= 1.00, net > 0, and >= 100 closed trades. If either control fails after mechanical acceptance, stop R4 as `R4_CONTROL_FAIL / PARK`; do not run Model 4.

Model-4 acceptance uses the same preregistered window bars: MAIN PF >= 1.20, net > 0, >= 100 closed trades; BWD PF >= 1.00, net > 0, >= 100 closed trades. Also report native EqDD, largest closed loss, max realized depth, max aggregate lots/exposure, and yearly distribution. No new numeric threshold is invented for these diagnostics; the canonical Model-4 no-cliff requirement is assessed from exact reported evidence, not a hindsight-tuned cutoff.

## Stop rule, repair budget, and decision

- Mechanical/harness/environment failure permits at most one bounded repair inside this R4 evidence package; no strategy/core/risk semantics may change.
- The same unresolved question twice is `BLOCKED` and ends the lane.
- Any mechanically valid Model-4 window missing its preregistered bar yields `R4_FAIL / PARK`; no retune, no alternate RSI pair, no range expansion, and no BWD mining.
- If both Model-4 windows pass, classify only `R4_EXECUTION_FIDELITY_NOT_FALSIFIED` and return the evidence for downstream routing. This does not create Candidate/HOLDOUT/DEMO/LIVE authority.

## Evidence package and reporting

Preserve exact tester INIs, reports, leverage/truncation sidecars, run receipts, year splits, deterministic metric/exposure summary, hashes, and execution console under `factory/runs/b16_r4_20260902/usdjpy_buy_h1/`. The milestone report must separate Evidence / Interpretation / Decision and follow `docs/research/EA_REPORT_SCHEMA.md`. `QUALITY_GRADE = UNRATIFIED`; `KINT-001` remains OPEN.

## Authority ceiling

`RESEARCH_ONLY`. Forbidden: H05/H07/H08 reopening, RSI/depth/CountBars retuning, parameter or range expansion, optimization, HOLDOUT, Candidate/DEMO/LIVE, deployment/trading, strategy/risk/default changes, Grade/KINT invention, cross-install numeric comparison, runtime ownership bypass, and process killing.

`bars:` Model1 MAIN PF >=1.20 + net>0 + >=100 trades; Model1 BWD PF >=1.00 + net>0 + >=100 trades; Model4 MAIN/BWD use the same per-window bars after control PASS.
`flat-lot probe:` N-A — `_16_LadderMult=1.0` is frozen and R4 changes only tester model fidelity.
