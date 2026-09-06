---
card_type: NEGATIVE_KNOWLEDGE
status: RESEARCH_ONLY
authority: RESEARCH_ONLY
canonical_base_sha: e62c7c6820b5d602be04f0da85a7ef2269a7cc35
direct_consumers:
  - Boss19 P4 prejoin/regime-join routing after accepted broad36 package
  - future B16 research routing after accepted R4 closeout
  - future experiment deduplication
---

# Closed and non-repeat research paths — B16 / B15 / Boss19

Purpose: preserve accepted negative or limiting evidence so later research does not spend runtime re-opening already answered questions. This file does not replace the canonical result owners and does not issue strategy verdicts.

## Boss19 P4 Repair02 -> Repair03 -- provenance defect closed; broad36 package complete/reviewed

Canonical owners: `docs/research/BOSS19_P4_UNIT_EXPORT_REPAIR02_RESULT.md`, `docs/research/BOSS19_P4_UNIT_EXPORT_REPAIR03_RESULT.md`, `docs/research/BOSS19_P4_BROAD36_ROI_GATE_20260902.md`, and `docs/research/BOSS19_P4_BROAD36_SOURCE_BOUND_RESULT.md`.

Historical negative evidence: Repair02 reconciled 113 IN / 113 OUT / 113 realized units through exact `DEAL_POSITION_ID`, but per-row `magic` was configured `_0_Magic` rather than source `DEAL_MAGIC`. This was an instrumentation/provenance failure, not strategy failure.

Accepted closure evidence: Repair03 separates configured run magic `990001` from per-deal source magic read by `HistoryDealGetInteger(deal, DEAL_MAGIC)`. H3-C03-MAIN reconciles 113 IN / 113 OUT / 113 source positions / 113 realized units / 0 open; source magic values are `[0,990001]`, and the three tester-forced closes are auditable as source magic `0`.

Environment limit: Repair02-to-Repair03 non-swap execution fields are exact. Broker swap changed by `+61.31`, exactly explaining net `4445.51 -> 4506.82`; this is environment economics, not a strategy semantic change.
Current boundary: Repair03 is `PASS / RESEARCH_ONLY`; broad36 execution/package are `ACCEPTED / REVIEWED / COMPLETE` at `ecd5c2b3af0791674a7cce18464e632750f37755` with 36/36 cells, 1,549 realized units, 0 open and 0 unknown-time. This closes evidence production only; deterministic prejoin/regime join is next and no P4 strategy interpretation authority exists yet.

## Boss19 P4 broad36 runner guard -- mechanical review blocker closed

Canonical owners: `scripts/research/boss19_p4b/run_unit_export_cell.ps1`, `scripts/_test/run_p4b_unit_export_tests.ps1`, `docs/research/BOSS19_P4_BROAD36_ROI_GATE_20260902.md`, and `docs/research/BOSS19_P4_BROAD36_SOURCE_BOUND_RESULT.md`; closure commit `2d333d367a93fa93c2e01c5055edbcca805463b2`.

Historical limiting finding: the first broad36 ROI-contract review found two real execution-precondition gaps: `unknown_time_unit_count` could pass through to PASS, and the runner did not pin all accepted Repair03 source/EX5/build-receipt/H3 identities before MT5 launch. These were harness/product-guard defects, not strategy evidence.

Accepted closure evidence: the runner now pins frozen H3 manifest SHA, diagnostic source SHA, diagnostic EX5 SHA, exact build receipt, build-receipt-registry SHA, and set SHA; it refuses identity drift before runtime and refuses `unknown_time_unit_count != 0` before PASS. Focused unit-export regression = 53/53 PASS and the exact-head independent runner-guard review found no material issue.

Do not repeat:
- do not reopen these exact guard defects without new identity changes or a reproducible regression;
- do not relax the unknown-time refusal to rescue a broad36 cell;
- do not treat an identity/joinability refusal as Boss19 strategy failure;
- do not infer regime edge from runner readiness or from the accepted source-bound package.

Current boundary: runner guard readiness is `PASS / REVIEWED / CANONICAL`; broad36 execution/package are also complete/reviewed. The next dependency is deterministic prejoin/regime join against the frozen classifier timeline; no P4 interpretation, HOLDOUT, optimization, Candidate/Grade/KINT, risk/default, deployment or trading authority follows from the package itself.

Do not repeat:
- do not rerun Repair03 H3-C03-MAIN merely to reconfirm the same source-provenance property;
- do not infer per-deal source magic from configured run identity;
- do not reinterpret the historical Repair02 instrumentation defect as Boss19 strategy or regime failure;
- do not rerun the accepted broad36 batch merely to rediscover evidence.

Next admissible continuation: use the accepted frozen broad36 package as input to the separately authorized deterministic prejoin/regime join. Do not rerun broad36, spend HOLDOUT, optimize, or infer a strategy verdict before that consumer is accepted.

## B16 GBPUSD/H4 SELL H05 — RSI entry search exhausted

Canonical owner: `docs/research/B16_GBP_SELL_H4_OPT01_RESULTS.md`.

Accepted evidence: the only preregistered positive interior center was 21/70. It stayed positive in fixed MAIN+BWD and all six years, but materially reduced net, trades, cycles, active participation, and BWD realized depth versus parent 14/70.

Negative/limiting finding: local sign stability did not produce a better continuation reference. Decision was `DO_NOT_ADOPT_CENTER_RETAIN_PARENT_RESEARCH_REFERENCE`.

Do not repeat:
- do not widen or refine the same RSI lattice;
- do not use BWD to choose another RSI pair;
- do not treat the positive 21/70 center as promotion or robustness evidence.

## B16 GBPUSD/H4 SELL H06/H07 — bounded depth question closed

Canonical owners: `docs/research/B16_GBP_SELL_H4_DEPTH2_01_RESULTS.md` and `docs/research/B16_GBP_SELL_H4_DEPTH3_01_RESULTS.md`.

Accepted evidence: depth2 preserved aggregate MAIN+BWD sign but lost 2025 MAIN utility; depth3 restored 2025 sign, all-six-year positivity, and aggregate economics while actually touching depth3. The accepted parent already supplies realized depth4 evidence.

Negative/limiting finding: the direct 2/3/parent-realized4 structural question is answered. Depth3 is context-specific research evidence, not a universal max-depth default.
Do not repeat:
- do not run a depth4 child merely because depth3 was strong;
- do not search depth4-9 adaptively;
- do not transfer depth3 as a universal grid-depth rule or risk default.

Reopen only with new admissible evidence: a separate prospective robustness/default question with its own authority and falsifier, not another depth-search loop.

## B16 USDJPY/H1 H08 — MAIN RSI plateau rejected by BWD

Canonical owner: `docs/research/B16_USDJPY_BUY_H1_OPT01_RESULTS.md`.

Accepted evidence: the locked 14/35 center improved MAIN to PF 1.68 / net +415.62 / 420 trades but failed BWD at PF 0.66 / net -229.49 / 230 trades. The accepted 14/30 parent remains positive in both windows at PF 1.53 / 1.11 with 275 / 267 trades.

Negative/limiting finding: the H08 MAIN plateau does not transport backward. This is strategy evidence after mechanical acceptance, not a harness defect.

Do not repeat:
- do not widen the upper RSI boundary after seeing BWD;
- do not refine/reopen H08;
- do not mine the same BWD window for another center;
- do not treat 14/35 as a robustness finalist.

R4 continuation is now complete. The accepted 14/30 parent remains the research reference; do not reopen H08.

## B16 USDJPY/H1 R4 — execution fidelity not falsified; 2020 weakness remains

Canonical owner: `docs/research/B16_USDJPY_H1_R4_EXECUTION_FIDELITY_RESULTS.md`.

Accepted evidence: same-install `D:\Meta 5` Model1 MAIN/BWD and Model4 MAIN/BWD all passed the preregistered full-window bars with frozen mechanics. Model1 = MAIN PF 1.54 / +255.30 / 275 trades, BWD PF 1.13 / +50.22 / 267. Model4 = MAIN PF 1.38 / +187.32 / 273, BWD PF 1.20 / +74.73 / 262. No model-switch sign flip or depth/exposure cliff appeared.

Negative/limiting finding: 2020 remains losing under both tester models (Model1 PF 0.7574 / net -40.91; Model4 PF 0.7921 / net -35.06). `R4_EXECUTION_FIDELITY_NOT_FALSIFIED` is therefore execution-fidelity evidence only, not all-year or regime-wide robustness.

Do not repeat:
- do not rerun the same Model1-to-Model4 fidelity question without a new direct consumer;
- do not use 2020 as a post-hoc retuning surface;
- do not reopen H05/H07/H08 from the R4 result;
- do not infer HOLDOUT, Candidate, DEMO/LIVE, Grade/KINT, risk/default or deployment authority.

Reopen only for a distinct prospectively contracted unresolved robustness question such as Monte Carlo or broader broker/install portability, and only when a direct consumer exists.

## B16 USDJPY/H1 exit-off paths — aggregate improvement is concentration-sensitive

Canonical owner: `docs/research/B16_USDJPY_H1_EXIT_CONCENTRATION_DIAGNOSTIC.md`.

Accepted evidence: disabling Single TP or Basket TP can improve aggregate net/DD, but the realized path collapses into a few long-lived episodes, including zero-closure years and maximum holds beyond 1,000 days.

Negative/limiting finding: aggregate improvement is not sufficient evidence for exit redesign because participation and holding concentration change materially.

Do not repeat:
- do not promote SingleTP-off or BasketTP-off from headline PF/net/DD alone;
- do not reopen exit redesign without a prospective consumer that explicitly measures participation/concentration.

## B16 XAUUSD/H4 exit-off paths — Repair01 replicates the exit-concentration mechanism

Canonical owner: `docs/research/B16_XAU_H4_EXIT_CONCENTRATION_REPAIR01_RESULTS_20260905.md`; frozen diagnostic SHA256 `5194fa5986767d9c47a4c4220b70699e8a21ac6e31aa14457d74837c46acf7b1`; acceptance record `factory/runs/b16_exitdiag_20260905/xau_h4/repair01_acceptance.json`.

Accepted evidence: after Repair01 replaced the mismatched control source with the already-accepted H03 parsed parent object, all three mechanically eligible windows (SingleTP-off MAIN, SingleTP-off BWD, BasketTP-off MAIN) satisfied the preregistered `>=3 of 4` concentration rule on all four dimensions (max hold, active share, top-1 positive-cycle GP share, zero-close years) — in fact every eligible window scored higher than its control on all four. `BasketTP-off / BWD` remains mechanically ineligible hard-cage evidence at 25.00% DD and is excluded from the verdict exactly as preregistered. Classification: `HYPOTHESIS_NOT_FALSIFIED / EXIT_CONCENTRATION_REPLICATED`; decision `RETAIN_CURRENT_EXITS_FROZEN`.

Negative/limiting finding: this replicates the previously observed USDJPY/H1 exit-off mechanism pattern (see the entry below) on a second Symbol×TF context. Disabling Single TP or Basket TP can again produce attractive aggregate PF/net in some windows while collapsing realized participation into a few extremely long-lived, highly concentrated cycles (max holds up to ~1,029 days, zero-close years present). Aggregate PF/net alone is therefore not sufficient evidence for removing either exit on XAUUSD/H4, exactly as it was not sufficient on USDJPY/H1.

Do not repeat:
- do not open an exit-parameter search/removal from XAUUSD/H4 headline PF/net alone;
- do not treat the BasketTP-off MAIN `UNDEFINED_NO_GROSS_LOSS` PF (MT5 displays 0.00) as a clean result without checking cycle count and concentration;
- do not rerun Repair01 or open Repair02 — Repair01 is the single bounded research repair for this diagnostic and no automatic follow-up is authorized;
- do not infer HOLDOUT, Candidate, DEMO/LIVE, Grade/KINT, risk/default, or deployment authority from this replication.

Reopen only with a separately preregistered XAUUSD/H4 exit-redesign hypothesis that explicitly includes participation/holding/concentration guardrails in addition to aggregate PF/net/DD — never a bare PF/net-driven exit search.

## B15 CountBars timing path — parked

Canonical owner: `docs/research/B15_COUNTBARS_SENS_01_RESULTS.md`.

Accepted evidence: parent CountBars=2, CountBars=1, and CountBars=3 each produced exactly 1/3 dual-positive H4 homes across GBPUSD/USDJPY/EURUSD. CountBars=3 improved GBPUSD locally but did not repair USDJPY BWD or EURUSD MAIN.

Negative/limiting finding: consecutive-confirmation timing around the parent did not improve cross-home portability. `MECHANISM_VALUE=WEAK` for this timing-adjustment path; the existing edge latch itself is not invalidated.

Do not repeat:
- do not widen CountBars under the same timing hypothesis;
- do not change MACD periods, RearmBars, or EdgeTrigger as a post-result rescue;
- do not mine BWD for a replacement timing setting.

## Cross-path rule

Local improvement is not portability evidence. A mechanically accepted strategy failure stays strategy evidence; an instrumentation/provenance failure stays instrumentation evidence. Re-open a closed path only when new evidence creates a distinct prospective causal question with a direct consumer and a frozen falsifier.
