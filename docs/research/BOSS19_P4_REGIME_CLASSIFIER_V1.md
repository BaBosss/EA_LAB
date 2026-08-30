# Boss19 P4 Regime Classifier V1

Status: P4A FROZEN RESEARCH CONTRACT
Authority: research attribution only. This classifier does not grant a verdict, optimization, HOLDOUT use, runtime activation, trade filtering, sizing, risk/default, deployment, or promotion authority.

## 1. Purpose and identity

This is the sole classifier definition for the Boss19 P4 attribution of the accepted H3 fixed-config matrix. It implements the three dimensions owned by [EA Regime Framework](EA_REGIME_FRAMEWORK.md): macro, local market structure, and volatility. A label is market context, never `GOOD` or `BAD`.

| Field | Frozen value |
|---|---|
| `classifier_id` | `BOSS19_P4_REGIME_CLASSIFIER_V1` |
| Classifier version | `1.0.0` |
| Contract base | `b7c0d624e1e1cd999628b3f70e987933fc7f55e7` |
| Macro implementation source | `scripts/mris/mris_classify.ps1`, SHA-256 `84a20e03e5babebc95a116fa808d808316c2df3b55d0d9f82e28a44b693a0da0` |
| Macro configuration source | `scripts/mris/barometers.json` v`1.0`, SHA-256 `0ea8a658d625e1f1317ea8a2095a55befc84ba5a7bc07da08192f2cc30e49347` |
| Vocabulary / anti-leakage source | `docs/research/EA_REGIME_FRAMEWORK.md` git blob `7fe7ffcd26bcf9b62aca91cd6ca223e14053c5f8` |
| Method source | `docs/research/EA_RND_PROTOCOL.md` git blob `d709c129ee3c7846307be3dfaed7147bbbda419b` |

P4b must emit a `classifier_manifest` before it reads H3 outcomes. The manifest binds this ID/version, this document's committed Git blob ID, the two source hashes above, all raw-market-input hashes, the algorithm parameters below, and the resulting timeline SHA-256. A changed byte, input hash, source hash, parameter, or timestamp rule is a new classifier/timeline and cannot be silently compared or joined as V1.

## 2. Causal time and input contract

All timestamps are UTC. `as_of_utc` means the latest point at which every datum used by that row was already closed and observable; no open bar, later revision, later price, EA trade, P&L, drawdown, participation, or period outcome may enter a classification calculation.

P4b must retain a machine-readable market-input manifest with provider/instrument mapping, UTC normalization rule, source retrieval timestamp, raw-file SHA-256, first/last timestamp, and missing-bar policy. The input source is market/context data only:

- Macro input is daily OHLC for the eight MRIS barometers: `AUDJPY`, `USDJPY`, `VIX`, `DXY`, `XAUUSD`, `BTCUSD`, `US10Y_JP10Y`, and `COPPER`, mapped to the accepted MRIS historical equivalents (`AUDJPY=X`, `JPY=X`, `^VIX`, `DX-Y.NYB`, `GC=F`, `BTC-USD`, `^TNX`, `HG=F`) unless a versioned equivalent source is recorded in the manifest.
- Local and volatility input is the closed OHLC series for the H3 cell's exact logical Symbol and execution TF (`M15`, `H1`, or `H4`), exported from the same named tester-data identity as the cell. It is not inferred from outcomes or substituted with a different install without an explicit data-identity record.
- P4b must acquire enough pre-window history for warmup. Macro inputs require at least 260 completed daily observations before the earliest macro date to be classified, providing a causal buffer beyond SMA200 / ATR20 / five-observation change. Local/volatility inputs require at least 252 calendar days plus 50 closed execution-TF bars before the earliest local date to be classified. If the applicable history is absent, affected rows are `UNKNOWN`; P4b may not shorten the lookback to obtain a label.

The historical input snapshot, not an unpinned live web response, is the evidence input. `mris_backtest_timeline.ps1` is a useful faithful MRIS replay reference, but its network fetch is not an immutable P4 input by itself.

## 3. Macro dimension â€” accepted MRIS semantics

Macro is evaluated once per completed UTC daily source date `D`, using only each barometer's last close on or before `D`, its 200-observation SMA, 20-observation ATR, and five-observation change. The state becomes eligible at `00:00:00Z` on `D + 1 calendar day`; it may never label an earlier timestamp. This is the historical/as-of adaptation of the accepted daily MRIS classifier, not a MacroGate runtime feed.

For every usable barometer, preserve the accepted MRIS signal rules, weights, and RI bands exactly:

| Barometer | Weight | Exact frozen signal rule (`c` = daily close, `r5` = five-observation % change) |
|---|---:|---|
| AUDJPY | 3 | Let `B = c < SMA200`; `F = r5 <= -3 Ã— ATR20 / c Ã— 100`. `B and F: -2`; `F: -1.5`; `B: -1`; otherwise `r5 >= 0: +1`; otherwise `+0.5`. |
| USDJPY | 2 | Let `F = r5 <= -2 Ã— ATR20 / c Ã— 100`. `F: -2`; else `c >= 158: +0.5` with `LOADED_FUSE`; otherwise `0`. |
| VIX | 2 | `<=15` = `+1`; `>=20` = `-1`; `>=30` = `-2` |
| DXY | 1 | 5-day rise `>=1.5%` = `-1`; otherwise `0` |
| XAUUSD | 1 | 5-day rise `>=1%` **and** VIX 5-day rise `>=10%` = `-1`; otherwise `0` |
| BTCUSD | 1 | Let `B = c < SMA200`; `F = r5 <= -3%`. Apply the same `B and F: -2`; `F: -1.5`; `B: -1`; otherwise `r5 >= 0: +1`; otherwise `+0.5` branch. |
| US10Y_JP10Y | 2 | Let `bp5 = (c - c/(1+r5/100)) Ã— 100`. `bp5 <= -15: -1`; `bp5 >= +15: +0.5`; otherwise `0`. |
| COPPER | 1 | Let `B = c < SMA200`; `F = r5 <= -3%`. Apply the same `B and F: -2`; `F: -1.5`; `B: -1`; otherwise `r5 >= 0: +1`; otherwise `+0.5` branch. |

`RI` is the weight-normalized mean of usable barometer signals. Precedence is exact: `STRESS` if usable VIX is `>=30` or `RI < -1.00`; else `RISK_ON` if `RI >= 0.50`; else `NEUTRAL` if `RI >= -0.25`; else `RISK_OFF`. Record MRIS flags, usable count, total usable weight, RI, and agreement confidence (`HIGH >= .75`, `MED >= .50`, otherwise `LOW`). `user_pin` fields remain advisory flags only; they never change an historical label.

A barometer with an unavailable close or insufficient indicator history is excluded and weights are renormalized exactly as MRIS does. This does **not** turn a missing source into `NEUTRAL`: record it in `macro_missing_inputs` and `macro_coverage`. `macro_state = UNKNOWN` when no barometer is usable, the daily row has no prior eligible state, or the last eligible daily state is older than 120 hours at the timestamp being attributed, matching the accepted MRIS weekend/holiday-tolerant freshness gate. `macro_partial = true` whenever fewer than eight barometers are usable. A partial macro label remains inspectable but must carry its coverage; it must not be presented as a full-data label.

## 4. Local-structure dimension

Local structure is calculated independently for every `Symbol Ã— TF`, on closed execution-TF bars only. Let `EMA20_t` and `EMA50_t` be conventional close-price EMAs and let `ATR20_t` be Wilder true-range ATR. Define:

```text
D_t = (EMA20_t - EMA50_t) / ATR20_t
A_t = abs(D_t)
Qtrend_t = nearest-rank 60th percentile of { A_j }
           for valid, closed bars j in [t - 252 calendar days, t)
```

The calibration set is strictly earlier than bar `t`; `nearest-rank(p,n)` is the sorted value at index `ceil(p Ã— n)` (one-indexed). It needs at least 250 valid observations. This rolling distribution is frozen to avoid importing a universal ADX/ATR threshold or choosing a threshold from Boss19 results.

For a bar that closes at `t`, use this precedence:

1. `UNKNOWN` if close/EMA/ATR/calibration is unavailable, `ATR20_t <= 0`, or warmup is incomplete.
2. `TRANSITION` if the sign of `D` crossed zero on any of the current or preceding three closed execution bars. A zero value counts as a cross boundary; this precedence intentionally gives a newly reversed, even initially strong, move a short transition state.
3. `TREND_UP` if `D_t >= Qtrend_t`.
4. `TREND_DOWN` if `D_t <= -Qtrend_t`.
5. `RANGE` otherwise.

The row is eligible only at that bar's close timestamp. An entry between bar closes uses the latest eligible row; P4b must not use the bar that was still open at entry. The use of the cell's execution TF is intentional: M15, H1, and H4 receive separate causal state series, calibration distributions, and timeline hashes. No cross-TF substitution is allowed.

## 5. Volatility dimension

Volatility is also per `Symbol Ã— TF` and uses the same closed bars and strictly prior 252-calendar-day calibration set as local structure. Define `V_t = 100 Ã— ATR20_t / Close_t`. With at least 250 valid prior `V` observations, compute nearest-rank `Q20_t`, `Q80_t`, and `Q95_t`.

Apply this exact precedence:

1. `UNKNOWN` if required input or calibration is unavailable, `Close_t <= 0`, or `ATR20_t <= 0`.
2. `LOW` if `V_t <= Q20_t`.
3. `NORMAL` if `V_t <= Q80_t`.
4. `HIGH` if `V_t <= Q95_t`.
5. `EXTREME` otherwise.

This makes the thresholds causal and symbol/TF-specific without using EA performance. Equal quantile values follow the listed precedence. P4b records `V_t` and all three contemporaneous quantiles for auditability.

## 6. Composite row, missing data, and timeline requirements

There is no fourth composite label. A classified row is the ordered tuple:

```text
(macro_state, local_state, vol_state)
```

with each dimension kept separately. If any dimension is `UNKNOWN`, the tuple is reported with that value and `classification_status = UNKNOWN`; P4b must never substitute `NEUTRAL`, `RANGE`, or `NORMAL`.

The immutable timeline must contain at least:

```text
valid_from_utc, valid_to_utc, symbol, tf,
macro_state, macro_as_of_utc, macro_ri, macro_confidence,
macro_coverage, macro_missing_inputs, macro_partial,
local_state, local_bar_close_utc, local_d, local_qtrend,
vol_state, vol_bar_close_utc, vol_natr_pct, vol_q20, vol_q80, vol_q95,
classification_status, classifier_id, classifier_version
```

`valid_to_utc` is the next row's `valid_from_utc` for the same `Symbol Ã— TF`; daily macro expiry can make `classification_status` unknown before that boundary. Rows must be sorted, non-overlapping, and reproducible solely from the manifest and market inputs. The timeline file hash and canonical byte format are specified by the attribution contract.

## 7. Explicit anti-leakage and non-authority boundaries

- No H3 P&L, winning/losing period, trade count, drawdown, PF, or result-package content may choose the macro rule, calibration window, percentile, threshold, state precedence, or missing-data behavior above.
- Classification is built and hash-pinned before H3 trade/basket data is opened for the join.
- The classifier is shared unchanged for every H3 cell, MAIN and BWD, parent/child comparison, and any later consumer that claims comparability. A classifier study would require a separately pre-registered version.
- `UNKNOWN`, low coverage, sparse participation, concentration, and a regime affinity are evidence descriptors, not a kill switch. No universal 100-trade rule is created here.
- No state maps to `ENABLE`, `REDUCE`, `BLOCK_NEW`, lot sizing, risk controls, or runtime behavior.

## 8. P4b handoff

P4b is ready to build the timeline only when it can create the required raw-market-input manifest and has sufficient pre-window OHLC history. It must produce an immutable, hash-bound timeline before performing the P&L join governed by [Boss19 P4 Regime Attribution Contract](BOSS19_P4_REGIME_ATTRIBUTION_CONTRACT.md).
