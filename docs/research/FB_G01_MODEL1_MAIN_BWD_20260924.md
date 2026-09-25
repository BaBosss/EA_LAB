# FB-G01 Persistent Adaptive Donchian Grid — fixed Model-1 MAIN+BWD

Status: **VALID_FIXED_MODEL1_EVIDENCE_WITH_MAIN_SAFETY_HALT / NO STRATEGY VERDICT**
Date: 2026-09-25
Lane: `ct-fb-g01-model1-main-bwd-v1-20260924`

## 1. Frozen identity

- Strategy: FB-G01 / `Boss_25_PersistentAdaptiveGrid` / `LAB_ENTRY_25`.
- Accepted source head: `8da04fc789ca55e6c673d41899e9136cfa72a75e`.
- Run base/canonical at execution: `4219785c6f4cc6c0f38ec3cdf92869160eb522ca`.
- No acceptance-relevant FB-G01 source-path drift existed between those refs.
- Home frozen by owner: XAUUSD / H1.
- Tester model: MT5 Model 1 / 1 Minute OHLC, Build 6182.
- Initial deposit: USD 10,000; leverage: 1:100.
- Fixed configuration: V0 declared defaults, full surface 160/160.
- EX5 SHA256: `fbd0ff95b2b063c48902b5f6e35043c094761d5e7f300f6ab4102c1a8ca13101`.
- Build receipt: `br-63f00daebfff4386908a1c936d71897b`.
- Set SHA256: `a9d434bf37ddc3a4ed8a906a6b1e640ef71e7abde286fcd9f9b194eb95bc5a57`.
- Effective-config fingerprint: `c9a9f95094d8d92e059ec7c894de76f57dce5d25a9b97792e3acd3ea3927d6d8` (`surface+constants`).
- Optimization: OFF. Retuning between windows: NONE. HOLDOUT: **UNSPENT**.

## 2. Window results

| Window | PF | Net | EqDD max | Trades | Cycles | Classification |
|---|---:|---:|---:|---:|---:|---|
| MAIN 2023–2025 | 0.23 finite | -2,188.86 | 2,610.53 / 25.05% | 46 | 16 | **SAFETY_HALT** |
| BWD 2020–2022 | 5.54 finite | +571.73 | 1,665.39 / 16.01% | 57 | 24 | **VALID_FULL_WINDOW_WITH_END_TEST_FORCED_CLOSE** |

Report history quality is 98% for MAIN and 99% for BWD. Final tester balances are 7,811.14 and 10,571.73 respectively. Both runs returned RC=0 and the tester reported successful completion; RC=0 by itself is not a strategy pass.

## 3. MAIN truncation RCA

MAIN trading did not stop because of a terminal crash, missing report, identity mismatch, persistence refusal, or no-signal inference.

At **2025-02-05 12:31:40** the EA logged:

- `[RISK] HARD KILL: DD 25.05% >= 25.00% (profile 2) -> closing all`;
- three open 0.01-lot SELL positions were closed successfully;
- `[RISK] HARD KILL complete: broker flat verified -> halt (persisted)`.

The last deal is therefore the safety close at 2025-02-05 12:31:40, leaving about 328.5 days to the requested MAIN end. This is a valid strategy path reaching the pre-existing shared hard-risk boundary. It must not be rerun merely to bypass the kill, and no risk/default weakening is authorized.

The frozen set has `ProtectLevel=2` (NORMAL), `RC_PersistHalt=true`, and `RC_MaxLevelsOverride=0`. Under the shared RiskControl source this means a 25% hard-DD kill and an effective default safety depth of three levels.

## 4. BWD lifecycle

BWD traded through the requested window. It had no hard-risk kill. On 2020-03-16 one basket-close request encountered a closed market four times at 01:04:00–01:04:59 (`retcode=10018`); the same close succeeded at 01:05:00. The next cycle did not start until 02:45:40, so the transient close failure did not become a persistence fault or same-bar reset.

The final BWD live cycle was **not** a target-completed basket. Three positions were closed by the tester at 2022-12-30 23:58:59 explicitly `due end of test`. BWD PF/net therefore include normal end-window liquidation of that still-open cycle.

## 5. Grid / exposure / basket evidence

V0 uses flat 0.01 lot per physical rung. The configured strategy clamp is five rungs per side, but the current shared safety cage limits effective simultaneous depth to three under the frozen NORMAL profile.

Observed in both windows:

- max concurrent owned positions: **3**;
- max aggregate open lots: **0.03**;
- max observed BUY rungs in one cycle: **3**;
- max observed SELL rungs in one cycle: **3**;
- theoretical V0 lot ladder L1..L5: **0.01 / 0.01 / 0.01 / 0.01 / 0.01**;
- exact ATR-normalized maximum grid span: **UNAVAILABLE_NOT_EXPORTED**;
- spacing formula remains `max(anchor * 0.25%, ATR14[1] * 0.75)`.

MAIN reconstructed 16 cycles: 15 normal strategy-flat cycles plus one safety-halt cycle. BWD reconstructed 24 cycles: 23 normal strategy-flat cycles plus one still-open cycle liquidated by the tester at window end.

For the normal strategy-flat cycles, realized profit+swap after close is at or above the frozen 0.25%-of-cycle-start-balance target in **15/15 MAIN** and **23/23 BWD** cases. This is a post-close consistency check. The strategy's actual target trigger is **live owned basket profit + swap**, not realized net profit, and must not be reported as realized net.

Wait-new-bar behavior is consistent with the contract: 15 MAIN and 23 BWD flat-to-next-entry transitions were checked, with **zero** next entries in the same H1 bar as the prior flat close.

## 6. Refusal / halt diagnostics

Across the exact two run segments:

- persistence mismatch halts: 0;
- account-baseline discontinuity events: 0;
- init refusals: 0;
- unconfirmed/partial-order refusal diagnostics: 0;
- OPEN_INTENT diagnostics: 0;
- deposit-load cap diagnostics: 0;
- MAIN hard kills: 1, completed hard kills: 1;
- BWD market-closed close failures: 4, followed by successful close;
- ordinary spread/data guard refusal count: **UNAVAILABLE_NOT_LOGGED**.

The absence of a logged ordinary spread/data refusal count is not treated as zero. It does not explain MAIN cessation because the hard kill is explicitly recorded.

## 7. Mechanical validity and research interpretation boundary

**MECHANICAL_VALIDITY = PASS.** Symbol resolution was exact XAUUSD, the full set surface was 160/160, build receipt/EX5/config fingerprint/set identity matched in both runs, leverage was verified 1:100, both reports were fresh, and both tester runs finished normally.

**Performance bar clearance = false.** This is not a declaration that the strategy is dead or accepted. MAIN hit the shared hard-risk boundary before the window ended, MAIN has 46 trades, and BWD has 57 trades. Both participation counts are below the canonical 100-closed-trades-per-window selection floor. BWD also contains one tester-end liquidation rather than a target-completed final basket.

Therefore this lane records mechanically valid fixed-config evidence, with MAIN classified `SAFETY_HALT`. It issues **no Candidate, Grade/KINT, optimization, HOLDOUT, DEMO/LIVE or whole-strategy PASS claim**. The downstream FB-H01 gate remains **NOT_CLEARED**.

## 8. Durable artifacts

Machine package: `factory/runs/fb-g01-model1-main-bwd-v1-20260924/`

Key files:
- `RESULT.json` — normalized closeout/classification.
- `MAIN.json`, `BWD.json` — parsed tester metrics.
- `GRID_CYCLE_ANALYSIS.json` — reconstructed cycles/exposure/wait-new-bar checks.
- `DIAGNOSTICS.json` — per-window halt/refusal counts.
- `RUNTIME_LOG_EXCERPTS.txt` — hard-kill, close-retry and end-test source-log excerpts.
- `raw/*.htm` — native MT5 reports.
- `graphs/*.png` — native equity/holding/histogram/MFE-MAE artifacts.
- full-surface `.set`, leverage/truncation sidecars and exact build receipt.

The source tester-agent log used for the runtime excerpts has SHA256
`7c60944d073472d0009d66432ba05a257a4eb3241a2d615cb86c5b1d4c5cc15e`.

## 9. Closeout

Classification: **VALID_FIXED_MODEL1_EVIDENCE_WITH_MAIN_SAFETY_HALT**.

Next action for this contract: **close the existing Model1 lane as DONE**. Any additional FB-G01 diagnostic, variant, optimization or deeper research requires a separate prospective contract; HOLDOUT remains unspent.
