# ORDER-076 — mq5 new-work smoke verdict (Opus lead, 2026-07-14)

Scope: FXDREEMA_XRAY.csv filter `has_sl=yes & lot_escalation=no` → 69 (16 mq5 + 53 mq4).
53 mq4 = already covered by ORDER-036 MT4 1,318-sweep (use existing results, not re-run).
New work = 16 mq5. Opus name-DQ'd 4 (SDK example scripts ×2, OpenAI-API EA, Tools/dashboard).
Remaining 12 smoke-screened by ea-screener (compile→ex5→smoke both-window MAIN 2023-26 + BWD 2020-22,
Model 1, flat-lot; has_sl & no-escalation so no escalation added). Raw reports: `_mt5_auto/reports/O076_*.htm`.

## Result table (raw evidence)
| # | Name | Sym | TF | MAIN PF | BWD PF | Trades | note |
|---|------|-----|-----|---------|--------|--------|------|
| 1 | (Jobot) GOLD SD Optimized v1 | XAU | H1 | 0.84 | 0.41 | 9/3 | thin, fail |
| 2 | (Jobot) Fibo Harmonic Pattern | XAU | H1 | — | — | — | COMPILE-FAIL (25 err) |
| 3 | (oh) fibo gold v06 | XAU | H1 | 0.88 | timeout | 1501 | churn, fail |
| 4 | (Jobot) Fibo QM Advance T5 | XAU | H1 | 0.24 | 0.00 | 129/81 | blowout |
| 5 | (Jobot) Fibo QM Advance v6 | XAU | H1 | 0.24 | — | 888 | blowout |
| 6 | (Tanakorn) Fibo QM Advance V14 | XAU | H1 | 0.33 | — | 280 | blowout |
| 7 | (Tanakorn) Fibo QM Advance V16 | XAU | H1 | 0.92 | 0.65 | 291/882 | fail |
| 8 | (ny) High Low Server Time MT5 | XAU | H1 | — | — | — | COMPILE-FAIL (29 err) |
| 9 | (Jobot) EA Inside Bar Break Out | XAU/EUR | H1 | 0.01/0.77 | — | 7/396 | fail |
| 10 | (PrinnbotX) G Scalping (Exness) | EUR/XAU | M15 | 0.42/0.43 | — | 4433/10875 | spread-eaten (win 2-21%) |
| 11 | **(ICE) CCI Currencies Strength Trend** | EUR | H1 | **1.08** | **1.20** | 10/12 | both-window PF>1, DD 1.8-2.4% — SAMPLE TOO THIN |
| 12 | (Joh) Workshop1 v3 | XAU | H1 | 0.50 | — | 78203 | churn |

## VERDICT (lead)
- **11 of 12 = REJECT / PARK.** 9 structural-fail (PF<1 every window; #4-6/#10/#12 = blowout or spread-eaten churn — STRUCTURAL, tune won't save). 2 COMPILE-FAIL (#2, #8 = genuine source errors, not name errors; can't evaluate). The 4× "Fibo QM Advance" being dead matches the user's own folder tag "0. Not work" — hand-signal confirmed.
- **1 survivor: #11 (ICE) CCI Currencies Strength Trend — PARKED-VERIFY(user), build-on-needs-data.** Passes both-window (MAIN 1.08 / BWD 1.20) with low DD — per doctrine (PF>1 even once = build-on, not bench) this is NOT dead. BUT 10-12 trades total = statistically empty; the PF is noise-dominated, cannot confirm edge. Mechanism (CCI currency-strength trend) is basket-designed → EURUSD alone starves it of signals.
- **Build-on branch (if pursued):** run the full FX-majors basket (EUR/GBP/USD/JPY/AUD/CAD crosses) to lift trade count into significance, ± lower TF, before any validator/robustness pass. Only then judge deploy. Do NOT deploy at n=10.

## UPDATE 2026-07-14 — CCI build-on FX-majors basket (does more data rescue #11?)
Ran EA11 across 9 majors both-window H1 (`_mt5_auto/cci_basket_results.csv`). **Build-on did NOT rescue it.**
- Every symbol still yields only 7–13 trades — the EA is inherently low-frequency; a basket run does not multiply signals.
- **Red flag:** USDJPY / USDCAD / NZDUSD / USDCHF MAIN produce IDENTICAL results (PF 0.60, net −138.39, 8 trades) → the EA's currency-strength signal does not read the chart symbol as an independent stream (uses a hardcoded internal pair set); "basket expansion" is not real diversification.
- Best cells (AUDUSD 1.28/1.56, EURUSD 1.08/1.20, EURJPY 0.94/1.18) pass both-window but at n=9–13 = still noise-dominated. Majority of symbols PF<1.
- **Verdict: stays PARKED — not worth further chase.** Would need a fundamentally different (much lower TF or true multi-symbol) harness to ever reach statistical power; the identical-row artifact says the design is low-frequency by construction. Not dead (both-window survivors exist) but not buildable to significance on this mechanism as-is. Re-open only if user has specific interest.

## Acceptance check
16 mq5 accounted for: 4 name-DQ + 12 smoked (2 compile-fail, 9 structural-fail, 1 build-on-needs-data).
53 mq4 = deferred to ORDER-036 existing results (not re-run per order instruction). Top-by-BWD-OOS = #11.
