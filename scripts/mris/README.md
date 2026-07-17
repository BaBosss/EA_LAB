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
Yahoo chart API        ──► mris_web_feeder.ps1 ─┐ (VIX/DXY/COPPER/US10Y proxy)
Export_Barometers.mq5  ──► (AUDJPY/USDJPY/XAU/BTC)├─► barometer_snapshot.csv
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
| `mris_web_feeder.ps1` | **web feeder** for the barometers the broker does NOT price (VIX, DXY, COPPER, US10Y proxy). Pulls free no-key daily OHLC from the Yahoo chart API, computes spot/sma200/atr20/chg5d, **merges in-place** into `barometer_snapshot.csv` (never clobbers broker rows). Per-symbol cache + STALE fallback like `news_calendar.ps1`. |
| `barometers.json` | barometer set + **tripwire rules** (relative: vs SMA200 / ATR-drop). `user_pin` = optional absolute line you set by hand (e.g. AUDJPY 110). Every threshold tunable. |
| `mris_classify.ps1` | reads snapshot + config → Risk Index (weighted mean of signals) → state RISK_ON/NEUTRAL/RISK_OFF/STRESS + confidence + flags. Zero LLM tokens. |
| `mris_exposure.ps1` | joins `DEPLOYMENTS.csv` → tags legs DIRECT_CARRY / RISK_ON / HEDGE / NEUTRAL_FX → per-state suggested action (**reduce-lot, never cut** — user rule). |
| `mris_brief.ps1` | state + exposure → Thai whisper brief (md) + HTML fragment for LIVE_DASHBOARD embed. |
| `brief_templates.json` | all Thai/emoji phrasing (kept out of the .ps1 so scripts stay pure-ASCII; edit tone here). |
| `mris_run.ps1` | one-shot orchestrator. |
| `..\..\_mt5_auto\mris\Export_Barometers.mq5` | MT5 feeder: dumps broker-priced barometers (spot/SMA200/ATR20/chg5d) to `Common\Files\barometer_snapshot_mt5.csv`. |

## Data feeds — what's live vs pending

The classifier reads a **normalized snapshot CSV** so the data source is decoupled:

- **Broker-priced (MT5 exporter):** AUDJPY, USDJPY, XAUUSD, BTCUSD → `Export_Barometers.mq5`.
  (Snapshot rows are still SEED spot levels until the exporter is wired into the run;
  the web feeder never touches these rows.)
- **Web-fed (`mris_web_feeder.ps1`, LIVE):** VIX (`^VIX`), DXY (`DX-Y.NYB`),
  COPPER (`HG=F`), and US10Y_JP10Y via US10Y proxy (`^TNX`) — all from the free no-key
  Yahoo chart API, computed from 1y daily OHLC. All 8 barometers now feed the Risk Index.
- **JP10Y note:** there is no free headless daily JP 10Y source (JGB is BOJ-pinned near
  1% and barely moves), so the US10Y_JP10Y spread barometer is fed with the **US leg only**
  (`^TNX`) as a proxy — the 5d spread move is ~entirely the US side. The classifier's
  `carry_fuel` branch converts the yield's 5d move to bps and scores narrowing vs
  `narrowing_5d_bps` (user-lockable, default 15). `source_note` flags the proxy.
- **Feeder resilience:** a fetch failure falls back to a fresh per-symbol JSON cache
  (`portfolio\mris\webfeed_cache\`, <20h); with neither fresh data nor cache the row is
  tagged `STALE` and the classifier excludes it (weights renormalise) — never crashes.

## Design guardrails (do not "fix" these)

- **No hardcoded price levels in rules.** Tripwires are relative (SMA200 / ATR). The
  `110` for AUDJPY is a user-set `user_pin`, not a rule constant — it exists so a
  proximity flag fires, and the user owns that number.
- **Proposes "watch / reduce-lot / block-new", never auto-close.** Correlation/risk →
  reduce lot, not cut (user doctrine). All output is advisory; the user decides.
- **Not investment advice.** Signal ≠ certainty. The system surfaces parallel warning
  lines early; it does not predict.

## Current read (2026-07-17, all 8 barometers live)

`NEUTRAL` · RI 0.192 · MED confidence · 8/8 active — risk-on intact but **two loaded
lines flagged**: AUDJPY (~113) only ~3% above the 110 pin, and USDJPY (~161) at a 40-yr
extreme = crowded carry / record JPY short. Web feeds read benign (VIX 16.7 calm-ish,
DXY flat, copper mildly constructive, US10Y spread ~flat 3bps/5d). Not a crisis; a
"prepare the umbrella" whisper. See `portfolio\mris\whisper_brief.md`.
