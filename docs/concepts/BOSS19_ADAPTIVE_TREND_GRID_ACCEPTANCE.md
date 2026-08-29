# Boss19 V0 acceptance evidence

## Regression RCA

The archived Build-6090 numeric baseline became non-reproducible on 2026-08-27 even when its exact source commit `3d5df443d9b43bc65845b77a8a09bbf2c3a009ae`, original full `.set` files, Build 6090 terminal binary, bars, and tick counts were reused. Boss16 also showed materially different swap charges and its first divergent basket close shifted by one minute. This is classified **C — ENVIRONMENT/DATA (broker economics/swap drift)**, not a Boss19 core regression.

A same-environment A/B then compiled exact baseline source and candidate source `76d2af28648a605e2bb6c58c4ded79ffdaa38a9f` sequentially against the same current XAUUSD tester environment. Results matched exactly for all eight baseline Boss EAs:

| EA | Net | PF | Trades | Max equity DD abs | BASE vs candidate |
|---|---:|---:|---:|---:|---|
| Boss_11_GridTrend | -433.54 | 0.87 | 480 | 668.57 | exact |
| Boss_12_Breakout | -176.71 | 0.85 | 164 | 263.55 | exact |
| Boss_13_MeanRev | -18.79 | 0.99 | 209 | 317.82 | exact |
| Boss_14_GridLog | 623.09 | 20.89 | 81 | 153.50 | exact |
| Boss_15_ST03 | -157.56 | 0.84 | 136 | 304.83 | exact |
| Boss_16_KangarooGrid | 305.19 | 1.83 | 71 | 458.13 | exact |
| Boss_17_Wave5 | -86.05 | 0.46 | 26 | 102.79 | exact |
| Boss_18_JumStoch | 366.29 | 1.21 | 298 | 199.62 | exact |

The old baseline must not be silently treated as current economics. Existing baseline governance should be re-pinned only through its declared provenance-migration path after the final source HEAD is clean; no strategy/risk semantics are changed by that re-pin.

## Boss19 V0 evidence boundary

The earlier `584.14 / PF 8.34 / 8 trades` run used generic template defaults (`ATR14 × 1.0`) and is infrastructure smoke only. It is **not** evidence for the visible adaptive-grid strategy. V0 strategy triage must use the explicit ATR30 × 0.30 STOP/LIMIT probe sets and treat all still-unresolved coefficients as hypotheses.

## ATR30 x 0.30 V0 probe smoke

On the current XAUUSD / H1 / 2024-01-01..2024-07-01 / Model-1 environment, both explicit full-surface V0 sets compiled and ran with stamped temporary build identity:

| UP hypothesis | Net | PF | Trades | Max equity DD |
|---|---:|---:|---:|---:|
| BUY STOP | 519.88 | 2.33 | 35 | 412.60 (4.11%) |
| BUY LIMIT | 261.47 | 2.91 | 23 | 543.18 (5.23%) |

The repaired helper and Probe wrapper compile 0 errors / 0 warnings. Tester log 20260828 emits `[PASS] AdaptiveTrendGrid_Test`. A negative full-surface run with `SLMode=SL_ATR` returns INIT failure with `Boss19 owns exits and requires SLMode=SL_NONE`. Tester logs also show repeated `[B19] finite pending ladder complete`, confirming the repaired short ladder is no longer silently one-leg-deep on the pinned XAUUSD environment. These remain V0 triage results only; neither is a source-parity claim, optimization verdict, candidate promotion, or permission to attach to DEMO/LIVE.

## Independent review and bounded repair

Claude Code / Opus reviewed frozen SHA `ad45b685ef473a1d80fb8ac1746f8869c3721cef` read-only and returned `VERDICT: PASS`, `ORIGINAL_SCOPE_PRESERVED: YES`, `INTEGRATION_RECOMMENDATION: INTEGRATE`. The review nevertheless identified concrete PRE-BASELINE defects: sub-minimum DOWN lots made later ladder levels unplaceable, non-NONE `SLMode` was silently unreachable, a transient ambiguity latch could suppress strategy exits, and an empty arm could retry stale targets indefinitely.

One bounded repair keeps the hard risk ceiling supreme while flooring DOWN decay at broker minimum only when `RC_MaxLot` still permits it, requires `SLMode=SL_NONE`, recomputes ambiguity from broker state each tick, resets a fully empty failed arm for a fresh reference, and corrects Probe-facing labels. The post-repair smoke values above supersede the earlier 64.15/4.62 smoke values. Exact source coefficients remain engineering hypotheses and the strategy remains PRE-BASELINE.

## Bounded V0 validation close — 2026-08-28

All runs below used the stamped `LAB_ENTRY_19` executable receipt `br-cb9e1136b4a2498aad1fc4cc85a55b18`, EX5 SHA256 `7cd4c979fd00a294e47c9a2b920cbc0590708bb27371ef1912021ea4b0970a5b`, exact XAUUSD / H1 on the ThinkMarkets tester environment, deposit 10,000 USD and verified leverage 1:100. The optimization guard resolved `B19-H01-r1` and allowed exactly the four pre-registered dimensions `_9_StepATRmult`, `_0_FastMA`, `_0_SlowMA`, `_22_TP_ATRmult`.

### MAIN selection

The STOP MAIN surface contains 500 scored configurations (XML SHA256 `bee7ed9021a2d75188575b5eb3a7e0dceec8368cd44b8abdda9238a9be0ddffb`). Reusing the already pre-registered `ORDER-1273` selector rather than choosing the best row after seeing results gives 322 admissible rows at the H1 >=100-trade floor, a 33-row top-10%-by-launcher-Result plateau, and a non-boundary median center:

`_9_StepATRmult=0.30`, `_0_FastMA=20`, `_0_SlowMA=50`, `_22_TP_ATRmult=1.50`.

The exact full-surface locked set is `ea_template/sets/probe/Boss_19_AdaptiveTrendGrid_V0_STOP_VALIDATION_CENTER.set`, config fingerprint `2010efefccfb4bf742df3adf9f1522dbaa061384a2f6e519348d11ede9eee7df`, set SHA256 `671ced2169bdda6812cf1ceb70bbc5a53bcb0985563dcbce92cc64e04f81f0d2`. Exact MAIN re-run (`B19_STOP_CENTER_MAIN_M1.htm`, SHA256 `3fbcb39b5315d6e769f110712f1ec25a771b885daaf3d8243a0b67defe2c1f23`) gives net +4486.59, PF 4.64, 100 closed trades and report equity relative DD 7.58% (maximal equity DD line 6.62%).

### BWD gate

The same locked center on BWD 2020-01-01..2022-12-31 (`B19_STOP_CENTER_BWD_M1.htm`, SHA256 `c97522859886ab191ae750a217565ae398c20c2e9f1e1e8c5bce73ffa0759125`) gives net -2095.59, PF 0.34, 49 closed trades and equity relative DD 25.02%. It therefore fails both the canonical BWD PF >=1.0 gate and the >=100 closed-trades/window participation floor. V0 cannot enter the CANDIDATE funnel.

### Flat-lot falsifier

To test whether MAIN performance is only the sizing progression, a control keeps the selected STOP center and changes only `_51_ProgFactor=0.0` / `_52_ProgMult=1.0`. MAIN (`B19_STOP_FLAT_MAIN_M1.htm`, SHA256 `e76171e6fcc38d978008f860e0977ab144cb1382b11f5c01d7c70826b9bb136f`) remains positive at net +3477.35 / PF 5.78 / 97 trades, so the observed MAIN pulse is not created solely by progression; however 97 trades is itself below the current >=100 participation floor. BWD (`B19_STOP_FLAT_BWD_M1.htm`, SHA256 `6d9d890b266129b1c9064dec58a9ac859c9fcf0e91366437ee27a1bb158f6e23`) collapses to net -1873.43 / PF 0.30 / 37 trades / 25.04% equity DD. The tester agent log confirms this run ended because the existing safety cage fired on 2022-07-06: `[RISK] HARD KILL: DD 25.04% >= 25.00% (profile 2)` followed by broker-flat verification and persisted halt. Risk controls were not disabled or changed for the test.

### LIMIT branch loop breaker

The first LIMIT MAIN surface (500 rows; SHA256 `17ea682c111676e407688da78a1f6a66af110b26855d0cf37c97526296c73ce6`) selected on both a StepATR lower boundary (0.20) and TP upper boundary (1.75). One deterministic lattice expansion was allowed: StepATR lower bound 0.20 -> 0.15 and TP upper bound 1.75 -> 2.00. The resulting 720-row surface (SHA256 `e070e68c67246f177aebc9e7aa6380d0e95fb58bdf7671831cd613b1817639cd`) still selects StepATR=0.15 on the lower boundary. The repeated same-boundary condition trips the bounded-search loop breaker; no further automatic widening is permitted and LIMIT is not a lockable V0 candidate.

### Verdict and evidence boundary

**Canonical working verdict: `PARKED-VERIFY(user)`.** This is not `DEAD-STRUCTURAL`: the strategy is capped and its hard DD cage works, and the flat-lot MAIN control retains a measurable pulse. It is not `CANDIDATE`: the locked STOP center fails BWD by a wide margin and the LIMIT branch never leaves the search boundary. HOLDOUT 2026H1 is deliberately **UNSPENT**; sensitivity fan, MC, Model-4, correlation and deploy packaging are not run after the BWD gate fails. No DEMO/LIVE attachment, real-money action, risk/default change, or strategy-semantic redesign is authorized or performed by this close.

## Research lineage pointer — 2026-08-29

This historical/evidence document maps to research lineage **`19-0`** in `docs/research/BOSS19_EVOLUTION_LEDGER.md`. This file continues to own the accepted measured evidence/provenance above; the ledger owns current family interpretation, parent/child lineage and next-research routing. The mapping does not change any historical metric, verdict, HOLDOUT state, runtime state or strategy semantics.
