# ORDER-212 — NuiIndy CutLoss=30 guardrail provenance

**Evidence hunt only. No backtests run. No verdicts/scorecard/registry/.set edited.**

## Answer up front

**CLEAN.** The "both-window 1.19/2.20" numbers come from two full-year, non-optimization
single runs on EURUSD H1, magic 1524, `CutLoss_Percent=30`:

| Number | Window (FromDate–ToDate) | Ends |
|---|---|---|
| **1.19** | `2022.01.01` – `2023.01.01` (calendar year 2022, "stress") | 2023.01.01 — clean |
| **2.20** | `2024.01.01` – `2025.01.01` (calendar year 2024, "benign") | 2025.01.01 — clean |

Neither window touches 2026 or the 2026H1 holdout. Both end well before the 2025.12.31 cutoff.

## 1. Every ini found for this EA (55 total under `_mt5_auto/ini/`, MT5 only — no MT4 inis exist for NuiIndy)

The two that produced the guardrail numbers, exact `[Tester]` blocks:

| ini file | Expert | Symbol | Period | Model | FromDate | ToDate | Optimization | Report |
|---|---|---|---|---|---|---|---|---|
| `NUI_EURUSD_cut30only_2022.ini` | `(NuiIndy) Dynamic RSI+ADX Style (4)` | EURUSD | H1 | 4 | 2022.01.01 | 2023.01.01 | 0 | `NUI_EURUSD_cut30only_2022` |
| `NUI_EURUSD_cut30only_2425.ini` | `(NuiIndy) Dynamic RSI+ADX Style (4)` | EURUSD | H1 | 4 | 2024.01.01 | 2025.01.01 | 0 | `NUI_EURUSD_cut30only_2425` |

Both have `[TesterInputs]` identical except window: `CutLoss_Percent=30`, `MAX_Order=99999.0`,
`Multiple1=1.0`, `Multiple2=1.0`, `Multiple3=1.2`, `MagicStart=1524`, `Near_by_Pips=10.0`,
`RSI_Period=24.0`, `ADX_period=14.0`, `ADX_Value=30.0` — i.e. the "cut30-only" config: uncapped
order count, escalation intact, only the basket DD-kill added.

Sibling inis in the same batch (for context, not the source of 1.19/2.20):
- `NUI_EURUSD_cap12cut30_2022.ini` / `_2425.ini` — MAX_Order capped to 12 + CutLoss=30 (the
  "❌ MAX_Order cap guts profit" row in the verdict table, PF 0.42 / 1.27 — not the recommended
  config, not the numbers this order is chasing).
- `NUI_EURUSD_H1_base_2425.ini`, `NUI_EURUSD_H1_flat_2425.ini`, `NUI_EURUSD_H1_single_2326.ini`,
  `NUI_EURUSD_H1_base_2326.ini` — the earlier baseline/flat-lot/single-order lever-isolation runs
  (PF 2.20 baseline / 0.72 flat / 0.90 single) that established "edge = escalation," predate the
  guardrail sweep.
- All other `NUI*`/`smoke_NuiIndy*`/`SMOKE_*NuiIndy*`/`OOS_NuiIndy*` inis (S3_NuiAUDJPY,
  S3_NuiUSDJPY, RIGOR_NuiIndy_M4_OOS, QWEN_NUII_*, DIAG_NuiIndy_H4, NUIH4_c0-c4 IS/OOS,
  VERIFY_NuiIndy_IS/OOS, NuiIndy_center_OOS, NuiIndy_robust_IS/OOS, NuiIndy_RSI_ADX_IS/OOS,
  OPT_NuiIndy, SMOKE_NEW_NuiIndy_RSI_ADX_*, SMOKE_C5_NuiIndy_*, SMOKE_B4_NuiIndy_TriArb_*) belong to
  other lanes (symbol-expansion smoke screens ORDER-095 batch 2, Tri-Arb sibling EA, optimization
  passes) — none of these carry `CutLoss_Percent=30` as the isolated variable with matching PF
  1.19/2.20, and none are cited by the verdict doc for this number.

## 2. The specific artifacts that produced 1.19 and 2.20

**Verdict doc**, `_triage/ORDER095_NUIINDY_EXPAND_VERDICT.md:52`:
```
| **cut30-only (uncapped orders + CutLoss=30)** | **PF 1.19 / +$1,081 / DD15.4%** | **PF 2.20 / +$2,689 / DD16.6%** | ✅ **RECOMMENDED** |
```
(table header at line 48: `| Config | 2022 stress | 2024–25 benign | note |`)

**Reports** (verified by direct extraction from the tester HTML, UTF-16LE encoded — grep needed
`iconv -f UTF-16LE`):

- `_mt5_auto/reports/NUI_EURUSD_cut30only_2022.htm`:
  - Period row: `<td nowrap colspan="10" align="left"><b>H1 (2022.01.01 - 2023.01.01)</b></td>`
  - Profit Factor row: `<td nowrap><b>1.19</b></td>`
- `_mt5_auto/reports/NUI_EURUSD_cut30only_2425.htm`:
  - Period row: `<td nowrap colspan="10" align="left"><b>H1 (2024.01.01 - 2025.01.01)</b></td>`
  - Profit Factor row: `<td nowrap><b>2.20</b></td>`

Both report HTML "Period:" fields match their corresponding `.ini` `FromDate`/`ToDate` exactly, and
both report PF values match the verdict-doc table exactly. Chain is closed: ini → tester run →
report → verdict table → scorecard/EDGE_CATALOG citation.

**Commit**: `10b7d648b8333190b0dbde90a9842004acb3d923` — `[claude] ORDER-095 NuiIndy: EXPANSION
REJECTED (martingale, no entry edge) + LIVE guardrail found`. This commit added
`_triage/ORDER095_NUIINDY_EXPAND_VERDICT.md` in full (single commit, no prior history — the file
was created whole). Commit message body: `DD-kill CutLoss=30 = free tail-insurance (byte-identical
benign 2.20/16.6%DD, profitable 2022 stress 1.19/+$1081/15.4%DD).` The verdict doc's own header
states `Date: 2026-07-17`, matching the report file timestamps (`Jul 17 22:17` for the 2022 run,
`Jul 17 22:44` for the 2425 run).

Downstream citations (repeat the same two numbers, no new evidence):
- `EA_SCORECARD_AND_REGISTRY.md:157` — `"LIVE guardrail rec: CutLoss=30 (free tail-insurance,
  both-window 1.19/2.20)"`
- `EDGE_CATALOG.md:63` — `"CutLoss_Percent=30 = free tail-insurance (both-window profitable
  1.19/2.20, DD bounded ~15%)"`

## 3. Windows stated as dates

- **1.19** → EURUSD H1, **2022.01.01 to 2023.01.01** (calendar year 2022 — the "2022 stress" /
  EUR-fall year the lab uses as its BWD-style stress proxy in this doc, though it is not the
  standard 2020-2022 BWD window — it's a single year, not the 3-year BWD span).
- **2.20** → EURUSD H1, **2024.01.01 to 2025.01.01** (calendar year 2024 — labeled "2024–25 benign"
  in the doc, though it is a single calendar year, not the MAIN window as currently pinned
  (2023.01–2025.12)).

Both are single-year windows, not the doctrine's standard MAIN (36mo) / BWD (2020-2022) pins — this
was a bespoke lever-isolation sweep for the guardrail question, not a full backtest-optimize-rigor
ladder run. That is a methodology note, not a leak: both windows still end before 2025.12.31, so
neither touches the reserved 2026H1 holdout.

## 4. One-line verdict

**CLEAN** — 1.19 comes from 2022.01.01–2023.01.01, 2.20 comes from 2024.01.01–2025.01.01; both
windows end on or before 2025.12.31, well clear of the 2026H1 holdout.

## 5. How CutLoss actually behaves in this (third-party, source-recovered) EA

- The verdict doc states the source was recovered from roaming Experts
  (`9CA16B…\MQL5\Experts\(NuiIndy) Dynamic RSI+ADX Style (4).mq5`, fxDreema-generated, 16.6k lines)
  — "locked" was a false label; the EA is NOT actually protected/compiled-only, full source was
  read.
- `CutLoss_Percent` is a genuine exposed `extern`/input parameter, not a hardcoded constant: it
  appears in every `[TesterInputs]` block of every ini for this EA, and in the `.set` files
  (`_mt5_auto/ab_sets/nuiindy_sets/NUI_cut30only.set` and siblings `NUI_cap12_cut30.set`,
  `NUI_cap20_cut40.set`, `NUI_cap8_cut25.set`, `NUI_cut40only.set`) as a plain
  `CutLoss_Percent=<value>` line alongside `MAX_Order`, `Multiple1/2/3`, etc. It is therefore
  reachable and settable from the MT5 "Inputs" tab / a `.set` file on the live terminal — no
  recompile or source edit needed to change it.
- As-shipped default is `CutLoss_Percent=100` (per verdict doc line 21-22: "no real SL — cuts only
  at total-account loss"). The verdict's mechanism claim (not independently re-verified by this
  order, since re-running backtests was forbidden) is that this is a basket/equity-level DD-kill,
  not a per-trade stop, and that it "never fires inside the normal DD envelope" in the two tested
  years (peak DD 16.6% < 30% in the benign year, meaning the cut30 config is reported
  byte-identical to as-shipped there) — i.e. the guardrail is claimed to be free insurance in the
  two windows actually tested, untested above a 30% DD event.
- Caveat inherited from the verdict doc itself (line 57-58): neither tested window pushed DD past
  30%, so the cut's ruin-capping behavior was never empirically triggered — its protective value
  above the tested DD range is asserted, not observed.
- No evidence was found in this hunt of a *third* independent run reproducing 1.19/2.20 outside
  the two reports above — the entire evidential chain traces back to this one 2026-07-17 sweep
  (two report files, one commit, one verdict doc, two downstream citations that just repeat the
  numbers).

## Files/artifacts referenced

- `D:\EA_LAB\_triage\ORDER095_NUIINDY_EXPAND_VERDICT.md`
- `D:\EA_LAB\_mt5_auto\ini\NUI_EURUSD_cut30only_2022.ini`
- `D:\EA_LAB\_mt5_auto\ini\NUI_EURUSD_cut30only_2425.ini`
- `D:\EA_LAB\_mt5_auto\reports\NUI_EURUSD_cut30only_2022.htm`
- `D:\EA_LAB\_mt5_auto\reports\NUI_EURUSD_cut30only_2425.htm`
- `D:\EA_LAB\_mt5_auto\ab_sets\nuiindy_sets\NUI_cut30only.set`
- `D:\EA_LAB\EA_SCORECARD_AND_REGISTRY.md:157`
- `D:\EA_LAB\EDGE_CATALOG.md:54-63`
- commit `10b7d648b8333190b0dbde90a9842004acb3d923`
