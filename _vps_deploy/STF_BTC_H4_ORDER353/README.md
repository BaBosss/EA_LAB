# STF BTC H4 — ORDER-353 demo leg (magic 990026)

**This is an A/B partner for the existing `990025` leg, not an independent portfolio leg.**
Both trade the same SuperTrend concept on BTC. Two SuperTrend BTC legs are near-perfectly
correlated, so running this as a "second leg" would add risk without adding diversification
(`portfolio-edge-thesis`: corr > 0.60 = redundant). Run as a paired experiment, judged as one.

## What is being tested

`990025` = the current crypto SuperTrend config. `990026` = the ORDER-353 tuned config:
pyramid deepened from 1 add to **7 adds at 1.0 ATR**, plus the **Kaufman ER regime gate at 0.25**.

The open question the backtest could not answer: **does the ER gate stand down correctly when
the regime is not trending?** Every piece of evidence that the gate helps comes from BWD
2020-2022 — the same window its threshold was tuned on. On MAIN it blocked 2 of 91 entries;
on the 2026H1 holdout it blocked **zero**. So the gate's most important property has never
been observed out of sample.

Running both legs answers it with a built-in control: when a non-trend regime arrives,
**990026 should stand down while 990025 keeps trading**. If both trade the same, the gate is
inert and the regime-conditional thesis is unsupported regardless of P&L.

## Files

| file | note |
|---|---|
| `(TRD)_SuperTrendFlip_rev05.ex5` | compiled 2026-07-27 09:07:59, source 09:07:46 → **not stale** (mtime is the only valid staleness test; MQL5 compiles are not byte-reproducible) · ⚠️ **on disk only — `.gitignore` line 53 excludes `*.ex5`, so this file is NOT in the repo.** A fresh clone gets this bundle without its binary; recompile from `ea_projects/(TRD)_SuperTrendFlip/(TRD)_SuperTrendFlip_rev05.mq5` or copy from the terminal's `MQL5\Experts\` |
| `STF_BTC_H4_ORDER353_DEMO.set` | `_06_AllowLive=true`, `_06_Magic=990026` |

## Canonical pre-attach RI02 packet

The canonical artifact is `(TRD)_SuperTrendFlip_rev05_ri02.ex5`, logical identity
`(TRD)_SuperTrendFlip_rev05`, for account `463666728`, magic `990026`, symbol `BTCUSDm`,
timeframe `PERIOD_H4`. Its build receipt is `br-81fad90230b74411a444ebe3aaae8506`, source SHA256 is
`19e686b82126985d79b3cfb58ba12381f7d47a0de2fdeb714333db365c07ec84`, and artifact SHA256 is
`a4c1d8da91d0032d9cbc94c2b0d3c2351a40d2a507a6824e2cfff0865bc75b11`.

The compatible DealsExporter is the additive `time_unix` build: source SHA256
`51d119609675a040273d85d7f41bffbcd16fd991b0e87171b183204fba363237`, artifact SHA256
`f4d530d756472eb5432fe27bb5eb1c1f23b720b5a212a4d9d546c3fd5666f277`. Treat
`EXPORTER_UPDATE_REQUIRED_BEFORE_FORWARD_EVIDENCE` as blocking until the VPS exporter is proven
equivalent. This packet is pre-attach: `attach_epoch`, attach time, and first-trade fields remain null.

> ⚠️ **The source `.set` shipped `_06_AllowLive=false`.** That exact defect made the `990025`
> leg sit silent for three days in July 2026 while looking attached and healthy. It is fixed
> in this bundle — **verify it on the chart's Inputs tab after attaching anyway**, because the
> per-terminal tester/chart cache can override unlisted inputs.

## Attach checklist (do all four — the first two have each failed before)

1. **Open the Inputs tab and read the values back.** Confirm `_06_AllowLive = true`,
   `_06_Magic = 990026`, `_07_MaxAdds = 7`, `_03_UseER = true`, `_03_ErMin = 0.25`.
2. **Confirm the inputs listed above actually appear.** A missing input means an older `.ex5`
   is loaded — file size is not a reliable check, a missing input name is.
3. Symbol **BTCUSD/BTCUSDm, H4**, lot **0.01** (permanently small — see sizing note below).
4. Record the real attach timestamp. The judge clock starts when the leg **first trades**,
   not when it is attached — `990025` had to have its clock re-based for exactly this reason.

## Evidence behind this config (all Model 4, real ticks)

| window | trades | PF | note |
|---|---|---|---|
| BWD 2020-2022 | 121 | 1.89 | soft gate ≥ 1.0 |
| MAIN 2023-2025 | 89 | 3.99 | hard gate ≥ 1.2 |
| holdout 2026H1 | 16 | 4.02 | never used for selection |
| MC (bootstrap, 2000×, 210 trades) | — | PF-5th **2.12**, ruin **0.00%** | bars: PF-5th ≥ 1.0, ruin ≤ 2% |

Model 1 vs Model 4 differ by under 1% with identical trade counts — no model-switch cliff.

## What the headline numbers hide — read before sizing up

* **Two losing years out of six** (2021 −106, 2025 −225); the baseline host has one. Profit is
  concentrated in 2022 and 2024. Whole-window PF hides this entirely.
* **This is leverage on an existing edge, not a new edge.** In the holdout it made ~2× the
  baseline's profit (+406 vs +219) with **3× the drawdown** (7.61% vs 2.53%) — at equal risk
  the shallow baseline wins that window. The user accepted the higher drawdown explicitly;
  it is recorded here so nobody re-derives it as a discovery later.
* **Use 7.61% as the drawdown figure, not the Monte Carlo's 2.89%.** Order-resampling destroys
  the serial correlation that produces real drawdowns, so MC understates DD here. Observed beats
  simulated when they disagree in this direction.
* **`ErMin` was chosen using BWD**, so BWD is no longer out-of-sample evidence for it. `0.25`
  was taken over the higher-scoring `0.30` because `0.32` collapses (PF 4.75 → 2.53); `0.30`
  sits one step from that cliff. The robust part of the gate's benefit is threshold-independent
  anyway — BWD drawdown is identical for every `ErMin` from 0.20 to 0.40.

## Sizing

**Permanently small lot. Never size up on PF.** The edge lives in the escalation engine as much
as in the signal, and the return profile is concentrated in two of six years.
