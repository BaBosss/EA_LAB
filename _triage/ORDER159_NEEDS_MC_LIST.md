# ORDER-159 (3) — NEEDS_MC inventory

Rows in `portfolio/expectations.csv` where `dd95_expected` is `UNKNOWN` because **no Monte Carlo has
ever been run** for that EA/leg (not just missed by search). This is an inventory only — it is NOT a
request to run MC, and no MC was run to produce this list. Each CSV row above also carries a
`| NEEDS_MC` tag appended to its `notes` column.

**Format:** magic · ea_name · account · why

1. `1524` · NuiIndy Dynamic RSI+ADX · `159475669` · ORDER095_NUIINDY_EXPAND_VERDICT.md only has flat-lot/single-order probes (escalation-engine diagnosis), no Monte Carlo ever run.
2. `9398` · ST_EA03 Count-MACD · `159475669` · STRUCTURAL no-edge kill (flat-lot PF 0.40) reached before the MC stage — no MC ever run.
3. `939721` · ST_EA03 Count-MACD user config · `159475669` · uncapped-ruin confirmed from source+backtest, removed from the account 2026-07-18 before reaching MC stage — no MC ever run.
4. `990005` · CB_GBP ConsoBreakout · `159475669` · EA_SCORECARD_AND_REGISTRY.md line 162 cites only 3/3 OOS windows; no Monte Carlo evidence found anywhere in the repo for this EA.
5. `990010` · ST03 replica / Boss_15 · `159475669` · chassis-cell verdict DEAD (ORDER-119/135, both-window 0/9), removed from live before MC; standalone variant is PARKED-VERIFY(user) awaiting user optimize — no MC run yet either way.
6. *(blank magic)* · unenumerated user EAs (LondonConso/GoldReaper/MatchaGrid/BRK-XAU) · `159475669` · UNVERIFIED_ROW — no single EA/magic identified, cannot search MC evidence per-EA; needs enumeration first.
7. `7777` · Zeus Gold Hedge V1.2_fix · `141049900` · ZEUS_GOLD_HEDGE_ANALYSIS.md has a genuine MC 95th-pctile-DD table, but only for sibling symbols AUDUSD/AUDJPY/EURCAD of this same EA — NOT for the EURUSD config actually deployed at magic 7777. Needs its own MC run on the deployed EURUSD H1 config.
8. `1112` · Gold_Kangaroo L1 · `141049900` · combined 4-magic-stream basket smoke only (PF 4.86 H1 / DD 11%), explicitly flagged "ยังไม่ validated" in KANGAROO_LOGIC_NOTES.md — no MC ever run.
9. `1113` · Gold_Kangaroo L2 · `141049900` · same combined-basket smoke evidence as L1, no per-leg or basket MC ever run.
10. `1114` · Gold_Kangaroo L3 · `141049900` · same combined-basket smoke evidence as L1, no per-leg or basket MC ever run.
11. `1115` · Gold_Kangaroo L4 · `141049900` · same combined-basket smoke evidence as L1, no per-leg or basket MC ever run.
12. `1` · UnNomGuaiV1.132 · `69424711` · Model-0 MT4 locked-EA backtest only (MaxDD ~19%, not MC); pipeline never included Monte Carlo for this EA.
13. `2` · UnNomGuaiV1.132 (2nd chart instance) · `69424711` · same validated config/evidence as magic 1 — no MC ever run.
14. `5888` · RSI from pips_EA · `69424711` · Model-0 MT4 locked-EA backtest only (MaxDD ~25%, not MC); pipeline never included Monte Carlo for this EA.
15. `990` · swb grid 4.1.0.3_h · `69424711` · Model-0 MT4 locked-EA backtest only (MaxDD ~20%, not MC); pipeline never included Monte Carlo for this EA.
16. *(blank magic)* · ClevrFX_EA · `69424711` · UNVERIFIED_ROW — EA not enumerated/located in repo, cannot search MC evidence.
17. `990302` · Boss_17_Wave5 · `463666728` (XAGUSDm) · `_vps_deploy/WAVE5_XAG/README_DEPLOY.txt` reports only backtest DD range (5-6.5% MAIN / 2-3% BWD) across the 6-cell plateau; no Monte Carlo run found for XAG (unlike the XAU sibling leg, which at least has a worst-case MC run — see exceptions below).
18. `991003` · EA_BREAKOUT_XAU · `463666728` (USDJPYm) · ORDER095_BREAKOUT_XAU_EXPAND_VERDICT.md + `_vps_deploy/EA_BREAKOUT_US30/README_DEPLOY.txt` have no Monte Carlo section, only MAIN/BWD PF and correlation vs the XAU home leg.
19. `991005` · EA_BREAKOUT_XAU · `463666728` (US30m) · same evidence files as the USDJPYm leg, no Monte Carlo section; also thin sample (34t MAIN/26t BWD, WATCH-flagged).
20. `991070` · EmaStoRev · `463666728` (EURUSDm) · ORDER_LANEC_SMCSTO_FAN_VERDICT.md + ORDER126_SMCSTO_ROUNDAVOID_VERDICT.md + `_vps_deploy/SMCSTO_EURUSD/README_DEPLOY.txt` all lack a Monte Carlo section.
21. `990110` · (Boss)_ZeusInspired_GridLog · `415573666` (AUDJPYm) · ORDER109_ZEUS_REGIME_VERDICT.md reports Model-4 MAIN/BWD PF and backtest DD only (16.0%/10.2%); no Monte Carlo section found.
22. `990208` · Boss_14_GridLog leg-8 · `415573666` (GBPJPYm) · revived later via ORDER-106 rescue (2026-07-16), AFTER the original Boss_14 cohort's MC campaign (2026-07-05) — ORDER106_GBPJPY_RESCUE_VERDICT.md + its EA_MASTER_INDEX.csv row report Model-4 PF only, no MC section for this leg.
23. `990303` · Boss_17_Wave5 · `463666728` (USDJPYm) · ORDER082B_WAVE5_USDJPY_VERDICT.md + `_vps_deploy/WAVE5_USDJPY/README_DEPLOY.txt` have no Monte Carlo section; also a THIN leg (11-17 trades/yr, ~85 total over 6yr).
24. *(blank magic)* · unenumerated user EAs (~10) · `146237` · UNVERIFIED_ROW — no single EA/magic identified, cannot search MC evidence per-EA; account has also been dead (no live-deals sensor) since 2026-07-10.
25. `990120` · Boss_12_Breakout (MacroGate leg) · `463666728` (USDJPYm) · `ea_projects/(Boss)_MacroGate/MACROGATE_AB_VERDICT.md` reports a single in-sample 2024 backtest eqDD (57.73%) only; no Monte Carlo ever run, holdout year not yet tested per the ORDER-073 note already on this row.

## Adjacent but NOT in the list above (do not conflate with NEEDS_MC)

These rows also have `dd95_expected=UNKNOWN` but were **left untouched** (no `NEEDS_MC` tag added)
because Monte Carlo genuinely **has** been run for the EA — the write-up just reports a different
statistic (worst-case DD across N iterations, or an MC PF-percentile without a DD percentile) instead
of a labeled 95th-percentile drawdown. Re-running MC from scratch is not what's needed here; re-deriving
or re-reporting the 95th-percentile figure from the existing simulation (if the raw output is still
available) would resolve these without new backtesting:

- `990201`-`990207` — Boss_14_GridLog cohort (USDJPYm/AUDNZDm/EURJPYm/AUDCADm/CADJPYm/EURUSDm/XAUUSDm, `415573666`): `DEMO_DEPLOYMENT_PLAN.md` "Config ร่วม" note reports **MC worst 6-9% at 0.25x sizing** for the cohort (XAU leg 990207 additionally confirms "MC ruin 0%" in its own pipeline description) — no 95th-percentile figure given for any individual leg.
- `990301` — Boss_17_Wave5 XAUUSDm (`463666728`): `_vps_deploy/WAVE5_XAU/README_DEPLOY.txt` reports "Monte Carlo (5000 iters, $10k): ruin 0.00%, DD worst 7.97% MAIN / 4.43% BWD" — worst-case, not 95th percentile.
- `990025` — EA_SUPERTREND crypto ST-BTC (BTCUSD, `463666728`): `_triage/ORDER125_CRYPTO_TRENDRIDER_SPEC.md` reports "MC(BWD) PF_5th 1.04, Ruin 0%" for the ST-BTC config — a Monte Carlo PF percentile, but no DD_95th figure anywhere in the file (the DD_95th 2.5% found in the same file belongs to the sibling DON-ETH pyramid config, magic 990030, which WAS filled by this order).
