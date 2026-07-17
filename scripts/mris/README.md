# MRIS — Macro Regime Intelligence System (ORDER-073 Phase-2)

A read-only **macro barometer + regime + whisper-brief** layer for the EA portfolio.
It does **not** trade and does **not** touch any terminal. It reads market barometers,
classifies a risk regime with explainable rules, maps which deployed legs are
carry/risk-exposed, and writes a short Thai "market whisper" brief — the philosophy
of the AUD/JPY north-star article: *the market whispers before it shouts; listen in
time and prepare.* (`ตลาดไม่ตะโกนเตือน มันกระซิบ`)

This is the macro sibling of Phase-1 `scripts\news_calendar.ps1` (event calendar) and
the intended upstream signal source for **Phase-3 MacroGate** (a NewsGuard-style
watchdog that would reduce-lot / block-new on carry legs during RISK_OFF — *not built
yet*, blocked on the user locking tripwire thresholds via an MRIS session).

## Pipeline

```
Yahoo chart API        ──► mris_web_feeder.ps1 ──► barometer_snapshot.csv  (all 8 rows)
Export_Barometers.mq5  ──► (OPTIONAL later refine of AUDJPY/USDJPY/XAU/BTC)
                                                  │
barometer_snapshot.csv ──► mris_classify.ps1 ──► regime_state.json
DEPLOYMENTS.csv        ──► mris_exposure.ps1 ──► exposure_map.json
   (both)              ──► mris_brief.ps1    ──► whisper_brief.md + .html
                            mris_run.ps1  = webfeed -> classify -> exposure -> brief
```

Run it:

```powershell
& D:\EA_LAB\scripts\mris\mris_run.ps1
# outputs land in D:\EA_LAB\portfolio\mris\
```

## Files

| File | Role |
|---|---|
| `mris_web_feeder.ps1` | **web feeder for ALL 8 barometers.** Pulls free no-key daily OHLC from the Yahoo chart API, computes spot/sma200/atr20/chg5d + an `asof` stamp, **merges in-place** into `barometer_snapshot.csv`. Per-symbol JSON cache + STALE fallback like `news_calendar.ps1`. Owning all 8 stops half the Risk Index reading off a frozen hand-seed. |
| `barometers.json` | barometer set + **tripwire rules** (relative: vs SMA200 / ATR-drop). `user_pin` = optional absolute line you set by hand (e.g. AUDJPY 110). Every threshold tunable. |
| `mris_classify.ps1` | reads snapshot + config → Risk Index (weighted mean of signals) → state RISK_ON/NEUTRAL/RISK_OFF/STRESS + confidence + flags. Age-gates any row whose `asof` is older than `-MaxAgeHours` (default 120). Zero LLM tokens. |
| `mris_exposure.ps1` | joins `DEPLOYMENTS.csv` → tags legs DIRECT_CARRY / RISK_ON / HEDGE / NEUTRAL_FX → per-state suggested action (**reduce-lot, never cut** — user rule). |
| `mris_brief.ps1` | state + exposure → Thai whisper brief (md) + HTML fragment for LIVE_DASHBOARD embed. |
| `brief_templates.json` | all Thai/emoji phrasing (kept out of the .ps1 so scripts stay pure-ASCII; edit tone here). |
| `mris_run.ps1` | one-shot orchestrator. |
| `..\..\_mt5_auto\mris\Export_Barometers.mq5` | MT5 feeder: dumps broker-priced barometers (spot/SMA200/ATR20/chg5d) to `Common\Files\barometer_snapshot_mt5.csv`. |

## Data feeds — all 8 live from Yahoo

The classifier reads a **normalized snapshot CSV** so the data source is decoupled.
As of the 2026-07-17 hardening the web feeder owns **every** row:

| snapshot symbol | Yahoo ticker | note |
|---|---|---|
| AUDJPY | `AUDJPY=X` | FX spot (clean SMA/ATR) |
| USDJPY | `JPY=X` | USD/JPY spot |
| XAUUSD | `GC=F` | gold front future ~ spot |
| BTCUSD | `BTC-USD` | crypto spot |
| VIX | `^VIX` | equity fear gauge |
| DXY | `DX-Y.NYB` | ICE dollar index |
| COPPER | `HG=F` | copper front future |
| US10Y_JP10Y | `^TNX` | US10Y **as spread proxy** |

- **Why all 8 (not just the broker gaps):** a warning layer must never read half its scale
  off a hand-seeded snapshot that silently ages. `Export_Barometers.mq5` stays an OPTIONAL
  refinement — if wired later it can overwrite the 4 FX/metal/crypto rows with exact broker
  prices; the daily macro read does not need that precision.
- **JP10Y note:** no free headless daily JP 10Y source (JGB is BOJ-pinned near 1%), so the
  US10Y_JP10Y spread barometer is fed with the **US leg only** (`^TNX`) as a proxy — the 5d
  spread move is ~entirely the US side. `carry_fuel` converts the yield's 5d move to bps and
  scores narrowing vs `narrowing_5d_bps` (user-lockable, default 15). `source_note` flags it.
- **Futures-roll caveat:** `GC=F` / `HG=F` are continuous front-future series, so their
  `sma200` can carry contract-roll steps. The classifier only uses gold/copper **`chg5d`**
  (single-contract window) for their signals, not their SMA200 — so this does not affect the
  regime read; treat their stored `sma200` as indicative only.
- **Freshness / resilience:** every row carries an `asof` stamp. A fetch failure falls back
  to a fresh per-symbol JSON cache (`portfolio\mris\webfeed_cache\`, <20h); with neither fresh
  data nor cache the row is tagged `STALE`. The classifier **excludes** any non-OK row *and*
  age-gates any OK row older than `-MaxAgeHours` (default 120) to `STALE_AGED` — weights
  renormalise, it never crashes, and a frozen snapshot cannot masquerade as live.

## Design guardrails (do not "fix" these)

- **No hardcoded price levels in rules.** Tripwires are relative (SMA200 / ATR). The
  `110` for AUDJPY is a user-set `user_pin`, not a rule constant — it exists so a
  proximity flag fires, and the user owns that number.
- **Proposes "watch / reduce-lot / block-new", never auto-close.** Correlation/risk →
  reduce lot, not cut (user doctrine). All output is advisory; the user decides.
- **Not investment advice.** Signal ≠ certainty. The system surfaces parallel warning
  lines early; it does not predict.

## Current read (2026-07-17, all 8 barometers live from Yahoo)

`NEUTRAL` · RI 0.269 · HIGH confidence · 8/8 active — risk-on intact. One loaded line
flagged: USDJPY (~162) at a 40-yr extreme = crowded carry / record JPY short. AUDJPY
(~113.3) sits *just past* the 3% early-warn band above the 110 pin — a good example of
why the AUDJPY band may want widening to 4–5% so the whisper does not flicker off on a
single up-day (a threshold-session decision). VIX ticked to ~18 (+21% 5d off a low base,
still sub-elevated), gold/BTC soft. Not a crisis; a "prepare the umbrella" whisper.
See `portfolio\mris\whisper_brief.md`.
