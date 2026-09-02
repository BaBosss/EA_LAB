---
card_type: NEGATIVE_KNOWLEDGE
status: RESEARCH_ONLY
authority: RESEARCH_ONLY
canonical_base_sha: 0dc2bb88ab34f931eca29b84d138caaa2ae9b8fd
direct_consumers:
  - Boss19 P4/P5 interpretation after Repair03
  - Factory B16 PARK versus prospective robustness routing
  - future experiment deduplication
---

# Closed and non-repeat research paths — B16 / B15 / Boss19

Purpose: preserve accepted negative or limiting evidence so later research does not spend runtime re-opening already answered questions. This file does not replace the canonical result owners and does not issue strategy verdicts.

## Boss19 P4 Repair02 — instrumentation blocker, not strategy failure

Canonical owner: `docs/research/BOSS19_P4_UNIT_EXPORT_REPAIR02_RESULT.md`.

Accepted evidence: H3-C03-MAIN preserved PF 4.39 / net +4445.51 / 113 trades / EqDD 13.34% and reconciled 113 IN / 113 OUT / 113 realized units with exact `DEAL_POSITION_ID` linkage.

Negative/limiting finding: per-row exported `magic` is configured `_0_Magic`, not source `DEAL_MAGIC`. Repair02 is therefore `BLOCKED(MAGIC_FIELD_NOT_SOURCE_BOUND)`.

Do not repeat:
- do not rerun the broad 36-cell source-bound export before Repair03 passes the one-cell source-provenance gate;
- do not infer per-deal source magic from configured run identity;
- do not reinterpret this instrumentation defect as Boss19 strategy or regime failure.
Reopen only with new admissible evidence: a prospective Repair03 that separates configured identity from source `DEAL_MAGIC`, preserves exact position ownership, passes independent exact-head review, and reruns only H3-C03-MAIN.

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

Reopen only with new admissible evidence: a distinct prospective robustness contract using the accepted 14/30 parent as frozen reference, if Factory/Control Tower decides continuation has direct value.
## B16 USDJPY/H1 exit-off paths — aggregate improvement is concentration-sensitive

Canonical owner: `docs/research/B16_USDJPY_H1_EXIT_CONCENTRATION_DIAGNOSTIC.md`.

Accepted evidence: disabling Single TP or Basket TP can improve aggregate net/DD, but the realized path collapses into a few long-lived episodes, including zero-closure years and maximum holds beyond 1,000 days.

Negative/limiting finding: aggregate improvement is not sufficient evidence for exit redesign because participation and holding concentration change materially.

Do not repeat:
- do not promote SingleTP-off or BasketTP-off from headline PF/net/DD alone;
- do not reopen exit redesign without a prospective consumer that explicitly measures participation/concentration.

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
