# ORDER-200 — MRIS Macro Extension (Bond/Credit/Oil/Equity axes + Crisis Models)

**Owner:** Opus-seat (lead + judge). Origin: user 2026-07-24 — the
`bond-crisis-dashboard-v2.vercel.app` site. User wants its *idea* absorbed into our
own stack so we don't depend on a site that may disappear, and used as a daily
market-regime read that shapes strategy (reduce-lot / pause on big macro events).

## Guiding doctrine (do NOT violate)
1. **Advisory-only shadow first.** New axes live in a SEPARATE snapshot + SEPARATE
   classifier. They do NOT alter the validated 8-barometer RI/state that
   `mris_export_regime.ps1` writes to the MacroGate CSV real accounts read. Zero
   blast radius on the live path until backtest proves them + user ratifies.
2. **Absorb barometers, never the site's AI trade recs.** Macro layer = risk throttle
   (reduce-lot/block-new), not an entry-direction signal.
3. **Explainable rules, zero LLM tokens** — same as `mris_classify.ps1`.
4. **Backtest before real money.** Any new score that later folds into the exported
   RI must first fire correctly on 2020 covid / 2022 / 2024 carry-unwind via the
   timeline replay, and pass a Codex blind audit (risk-path code, AGENTS.md §5.1).

## Data feeds (ALL verified free from this box 2026-07-24)
| snapshot symbol | source | fetch method | ref value 2026-07-24 |
|---|---|---|---|
| US2Y     | Yahoo `2YY=F`          | Invoke-WebRequest (existing pattern) | ~3.96 |
| WTI      | Yahoo `CL=F`           | Invoke-WebRequest | ~89.9 |
| SP500    | Yahoo `^GSPC`          | Invoke-WebRequest | ~7408 |
| MOVE     | Yahoo `^MOVE`          | Invoke-WebRequest | ~80.1 |
| HY_OAS   | FRED `BAMLH0A0HYM2`    | **curl.exe** (IWR times out — TLS proxy) | ~2.68 (=268bps) |
| YCURVE   | FRED `T10Y2Y`          | **curl.exe** | ~ (10Y-2Y slope %) |

- **GOTCHA:** PowerShell `Invoke-WebRequest` to `fred.stlouisfed.org` TIMES OUT on this
  box (TLS MITM proxy). Use `curl.exe -s -m 25 <url>`. Yahoo works fine via IWR.
- FRED CSV format: `observations` endpoint returns `DATE,VALUE` rows; the graph CSV
  `https://fred.stlouisfed.org/graph/fredgraph.csv?id=<ID>` returns `<date>,<value>`
  with a header line. Missing values appear as `.` — skip them.
- No free headless JGB10Y source (known MRIS limitation) — out of scope.

## Snapshot schema (IDENTICAL to core `barometer_snapshot.csv`)
File: `portfolio\mris\barometer_snapshot_macro.csv`
Columns: `symbol,spot,sma200,atr20,chg5d_pct,data_status,asof,source_note`
- Yahoo tickers (US2Y/WTI/SP500/MOVE): compute spot/sma200/atr20/chg5d_pct exactly
  like the existing `Compute-Row` in `mris_web_feeder.ps1` (OHLC).
- FRED series (HY_OAS/YCURVE): single value series. spot = latest value; chg5d_pct =
  pct change vs value 5 observations ago; sma200 = mean of last 200 values; atr20 =
  mean absolute day-over-day change of last 20 values (TR proxy; there is no H/L).
- Same resilience as core feeder: per-symbol raw cache in `webfeed_cache\`, STALE
  fallback, `asof` stamp, atomic write.

## Work breakdown
- **A1 (DELEGATE → Sonnet):** `scripts\mris\mris_macro_feeder.ps1` — new standalone
  feeder producing `barometer_snapshot_macro.csv` per the schema above. Mirror the
  existing feeder's structure/resilience. Verify: run it; CSV has 6 rows, all
  `data_status=OK`, values within 10% of the ref column above.
- **A2 (Opus-seat writes — risk logic):** `scripts\mris\mris_crisis_models.ps1` +
  config `scripts\mris\crisis_models.json` → `portfolio\mris\crisis_models_state.json`.
  Explainable 0-100 composite scores: YIELD_SHOCK, CREDIT_STRESS, INFLATION_OIL.
  Reads BOTH snapshots (core for ^TNX/VIX, macro for the new axes). Advisory only.
- **A3 (DELEGATE → Sonnet, after A2):** brief-template strings + a `mris_brief.ps1`
  section rendering the crisis models. Wire `mris_macro_feeder` + `mris_crisis_models`
  into `mris_run.ps1` AFTER the existing 4 steps (non-fatal).
- **B (Opus-seat + Codex):** extend `mris_backtest_timeline.ps1` to replay the crisis
  models over 2020/2022/2024; prove they fire; Codex blind audit before any fold into
  exported RI. Fold = separate future order, user-ratified.

## Acceptance
- `mris_run.ps1` still produces the SAME core `regime_state.json` (byte-identical logic
  path) — the extension is purely additive.
- `crisis_models_state.json` present with 3 scored models + component breakdown.
- Backtest: each crisis model shows an elevated score in its matching historical
  episode (CREDIT_STRESS high in 2020 Mar; INFLATION_OIL high in 2022; etc.).

---
## RESULTS (Opus/Fable-seat 2026-07-24) — Phase A DONE, Phase B concept-check PASS

**Built & verified live:**
- `mris_macro_feeder.ps1` (Sonnet) → `barometer_snapshot_macro.csv`: 6/6 OK
  (US2Y 4.04, WTI 90.4, SP500 7415, MOVE 70.9, HY_OAS 2.68, YCURVE 0.34).
- `mris_crisis_models.ps1` + `crisis_models.json` (Opus-seat) → `crisis_models_state.json`.
  Live read 2026-07-24: INFLATION_OIL **83 active**, YIELD_SHOCK 45 forming, CREDIT_STRESS 4 dormant.
- brief + orchestrator wiring (Sonnet): full chain = webfeed→macrofeed→classify→crisismodels
  →exposure→brief, 6 steps clean. Core `regime_state.json` UNCHANGED (NEUTRAL RI~0.31) —
  advisory layer proven non-invasive.

**Backtest concept-check** (`mris_crisis_backtest.ps1`, 4 windows): **4/4 PASS**
| window | expect | result |
|---|---|---|
| covid_2020      | CREDIT_STRESS fires | peak 100, 27/73 days active ✅ |
| inflation_2022  | INFLATION_OIL fires | peak 100, 44/125 days active ✅ |
| yield_spike_2023| YIELD_SHOCK fires   | peak 90, 19/76 days active ✅ |
| calm_2019       | all dormant (<60)   | peaks 28/16/43 all dormant ✅ |

**Interesting divergence vs the site (2026-07-24):** site called YIELD_SHOCK #1 (opaque "91%");
our layer calls INFLATION_OIL #1 (WTI +9.5%/5d, +20% vs SMA200) with every component shown.
Ours is auditable; the site's is not. This is exactly why we backtest before trusting a score.

## KNOWN LIMITATION (do not paper over)
- **Deep HY history unavailable keyless.** FRED `fredgraph.csv` caps at ~3yr (2023-07+) even
  with `cosd` — a proxy/CDN cap on this box. So the covid_2020 CREDIT_STRESS backtest fired via
  its MOVE+VIX components (HY component dropped, weights renormalised = graceful degradation),
  NOT via deep HY data. LIVE credit reads use real HY (2023+, covers now). Folding CREDIT_STRESS
  into the real-money RI would need either a free FRED API key for deep HY validation OR forward
  accumulation — a FUTURE user-ratified order, gated on a Codex blind audit (risk-path, §5.1).
- US2Y (Yahoo `2YY=F`) history only 2021+, and neither US2Y nor YCURVE is used by the 3 current
  model formulas (they are fetched for brief display + future models).

## NOT DONE (future, gated)
- Codex blind audit — NOT required now (layer is advisory, does not touch exported RI).
  REQUIRED before any fold into the MacroGate real-money path.
- Fold any crisis score into RI / MacroGate — separate order, user-ratified only.
