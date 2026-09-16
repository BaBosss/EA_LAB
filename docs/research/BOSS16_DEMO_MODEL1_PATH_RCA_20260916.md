# Boss16 Demo vs Model1 path RCA — 2026-09-16

Status: `RESEARCH_DIAGNOSTIC_ONLY / ZERO_NEW_MT5 / SUPPORTED_MECHANISM_NOT_CAUSAL_CERTIFICATION`

Evidence extraction base: `eed2c48455cb14cb0fd16ad0f687148f332fc3cf`.
Final integration base: `2cb99c13f4b1eba0dd8762140b3ecad6be8cbd7d`; canonical advances were orthogonal to Boss16 RCA/source-binding paths, and evidence numbers were not changed by re-anchor.
Direct consumer: explain the material `990016` Demo-vs-C04 sign divergence without retuning, rerunning MT5, or changing runtime.
Authority ceiling: no strategy PASS/FAIL, Candidate, DEMO->LIVE, risk/default, runtime, deployment, trading, or HOLDOUT authority.

## 1. Evidence boundary

This RCA reuses the reviewed Demo same-period package and the already-executed C04 report. It performs no new Strategy Tester run.

- Demo frozen source: `factory/runs/demo_sameperiod_replay_20260916/evidence/demo_5magic_rows_through_20260914.csv`, SHA256 `26c3b30c...d40046cd`.
- Boss16 set: `ea_template/sets/Boss16_Kangaroo_XAU_21_30.set`, SHA256 `37c6da42...f0c4f6b`.
- C04 report: SHA256 `07b8242e...9507327`, reused only as previously generated diagnostic evidence.
- Exness mutable HCC cache observed at extraction: SHA256 `6882af6e...f70267d7`, 15,105,309 bytes.
- ThinkMarkets mutable HCC cache observed at extraction: SHA256 `3df66732...d339179`, 41,067,168 bytes.
- Current Kangaroo mechanics blob equals deploy-era `d96df976...` blob: `12d7a342f8c204edb8186741dedbc9a9a940810f`.

The package freezes only the decision-critical extracted records. HCC files are mutable caches; whole-file hashes above bind the extraction observation, not a permanent future cache identity.

## 2. Identity findings

C04's report carries all 42 assignments from the tracked flat Boss16 set with 42/42 exact value matches. `_16_BaseLotMode=0` in the report, consistent with the flat deployment treatment.

This narrows but does not close identity: the full effective Demo input surface was not durably captured after attach, so exact Demo configuration continuity through the observation window is still not certified.
## 3. Basket-level observation

Counting independent basket episodes changes the interpretation materially:

| surface | independent episodes | net | max observed open depth |
|---|---:|---:|---:|
| Demo Exness | 5 | +117.56 | 4 |
| C04 Model1 ThinkMarkets | 1 | -318.44 | 5 |

The five Demo episodes close at +34.21, +6.44, +6.48, +32.45 and +37.98. C04 remains one continuous episode from 2026-08-28 through 2026-09-02.

## 4. Mechanic that separates the paths

`Kangaroo.mqh` uses the lowest open BUY fill as the current adverse-grid reference. The next add occurs intrabar only when current ask reaches:

`lowest_open_fill - max(0.8 * ATR14(H1, shift 1), 150 pips)`.

For XAUUSD's observed scale the ATR term dominates. The ATR implementation was independently checked against the installed MT5 `Examples/ATR.mq5`: rolling 14-bar SMA of True Range.

After deduplicating local HCC cache records by timestamp and excluding one-record cache-block artifacts, the selected H1 inputs contain 58–60 distinct M1 records each:

- Exness ATR14 = `33.5360714286`; grid step = `26.8288571429`.
- ThinkMarkets ATR14 = `33.5785714286`; grid step = `26.8628571429`.

The ATR difference is small. The decisive difference is the L2 fill:

- Demo L2 fill = `4426.138` -> next trigger = `4399.309143`.
- Model1 L2 fill = `4418.58` -> next trigger = `4391.717143`.
- Fill-reference delta = `+7.558` in Demo versus Model1.
The Demo's actual L3 fill is `4398.916`, which is below the Demo trigger and therefore consistent with the source add predicate firing.

Over the same elapsed window after Model1 L2, the lowest decoded ThinkMarkets M1 bid low is `4396.39`, still above the Model1 trigger `4391.717143`. Because ask cannot be below bid, the Model1 path cannot satisfy that L3 add threshold in this window.

This separation is mechanically sufficient to alter the open-position set. Once the open set differs, overlap-pair, basket-dollar and later add/exit predicates operate on a different state path.

## 5. Broker-bar comparison

Four descriptive M1 examples aligned by the observed +3 hour trade-time offset show small OHLC differences at L0/L1/L2/L3-relevant minutes. The largest absolute OHLC component difference among these four examples is about `0.521`.

The +3 hour shift is post-outcome descriptive alignment only; it is not promoted into a qualified broker-clock model. The finding therefore does **not** claim universal Exness/ThinkMarkets bar equivalence.

## 6. Interpretation

Classification: `MODEL1_INTRAMINUTE_FILL_PATH_CONFOUND_SUPPORTED_NOT_CAUSALLY_CERTIFIED`.

Supported: the already-observed C04 sign flip can be explained by the Model1 intraminute fill path moving the L2 reference by about 7.56 dollars, which moves the next grid trigger enough for Demo to add L3 while Model1 cannot in the matched elapsed window.

Not established: a complete causal decomposition of every later exit, exact Demo tick replay, or exact full-surface configuration parity.

This reduces the value of another same-period Model1 rerun as a diagnostic for this question. A new Model1 run would still use generated intraminute path mechanics rather than reproduce the missing historical Exness tick sequence.
## 7. Preserved blockers

- C04 typed truncation remains `UNKNOWN / truncated=null`; this RCA does not upgrade C04 into full-window eligibility.
- No qualified historical Exness real-tick stream is available for a source-bound replay. The monitor cache exposes usable HCC bar history but not a qualified historical tick sequence for this contract.
  `tick_source_preflight.json` observed one `ticks.dat`, zero `.tkc` files, and zero matches for four Boss16 entry timestamps encoded as little-endian seconds or milliseconds. This is a qualification failure for the observed cache shape, not proof that no other historical-tick source exists.
- The HCC 60-byte record layout is an empirically decoded local cache layout, not asserted as an official MetaQuotes HCC specification.
- Exact Demo full-input continuity remains unproven beyond the attach/readback evidence already carried by the deployment record.
- Broker/symbol-specification differences remain possible residual confounds even though the sampled M1 OHLC bars are close.

## 8. Next consumer

Do not spend another Model1 rerun merely to chase C04 parity. The next evidence-producing step is `QUALIFY_HISTORICAL_EXNESS_REAL_TICK_SOURCE_BEFORE_ANY_MODEL4_GRADE_DIAGNOSTIC`.

If no qualified historical Exness tick source can be bound, stop at this RCA and keep the Demo forward record as the observed evidence. Do not manufacture exact parity from generated ticks or cache-only assumptions.

Package: `factory/runs/boss16_demo_path_rca_20260916/`.
`verify_package.py --external` recomputes basket counts/net, 42/42 input matching, ATR14, trigger levels, crossing/non-crossing and source hashes. Its negative self-test must reject 4/4 mutants.
