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

## KNOWN LIMITATION — ✅ SOLVED 2026-07-25 (Phase C), kept for the record
- ~~**Deep HY history unavailable keyless.** FRED `fredgraph.csv` caps at ~3yr (2023-07+) even
  with `cosd`. So the covid_2020 CREDIT_STRESS backtest fired via its MOVE+VIX components, NOT
  via deep credit data.~~ **Solved without an API key** by adding a *derived* credit axis:
  **CREDITPX = HYG/IEF price ratio** (junk-bond ETF vs Treasury ETF = credit risk appetite),
  both legs carrying 10yr of Yahoo history. FRED HY_OAS stays as a live-precision component;
  CREDITPX supplies the deep history. See Phase C below.

---
## PHASE C (2026-07-25) — deep credit axis + push notify + alert-fatigue fix

**C1. CREDITPX credit axis (Opus-seat).** `mris_macro_feeder.ps1` gained a `ratio` feed kind
(`Compute-RowRatio` + `Get-CloseMap`, aligning two independently-holidayed series before
dividing). Snapshot is now 7/7 OK.
**Anchors are MEASURED, not guessed** — probe over 2016-2026 (worst pct_vs_sma200 / worst 5d):
| episode | vs SMA200 | 5d | reads as |
|---|---|---|---|
| covid_2020 | **-26.2%** | **-14.2%** | full credit crisis |
| svb_2023mar | -2.8% | **-5.7%** | bank shock caught by the 5d leg only |
| inflation_2022 | -5.5% | -3.8% | moderate (a rates event) |
| yield_spike_2023 | +2.4% | -1.2% | correctly NOT a credit event |
→ stress anchors -15% (trend) / -8% (5d); CREDIT_STRESS reweighted to 6 components.

**C2. Backtest now checks SPECIFICITY, not just sensitivity — 7/7 PASS.** The deep axis paid
for itself immediately: CREDIT_STRESS previously fired **67/125 days in inflation_2022** (a
rates event) because MOVE/VIX dominated its weights = false positive. It is now **0/125**, while
covid_2020 still peaks 100. A gate that cries wolf in the wrong regime is worse than no gate,
so "[spec] model must stay quiet in a non-matching episode" is now a permanent pre-registered bar.
SVB Mar-2023 peaks 52 = "forming" — defensible for a contained, backstopped bank scare.

**C3. Push notify (Sonnet).** `mris_notify.ps1` → Telegram Bot API, reads token from the
gitignored `scripts\config.yaml`, **HIGH alerts only** (INFO/COOL stay file-only), graceful
no-op when unconfigured, token scrubbed from all output/exceptions, wrapped so a notifier
failure can never break the alert chain. `-NoPush` suppresses. **User must supply their own bot
token** — Claude cannot create accounts.

**C4. Alert-fatigue defect found & fixed (Opus-seat).** The mandated real chain run exposed it:
classifier flag text embeds live prices (`LOADED_FUSE: USDJPY 163.85 at extreme`), so a
163.77→163.79 tick made the SAME standing condition look like a new flag and fired a spurious
HIGH push. Flags are now compared by **key** (`TYPE:SUBJECT`, digits stripped) with a
back-compat path for older baselines. Verified: price tick inside a standing flag = silent;
a genuinely new flag type = still alerts.
- US2Y (Yahoo `2YY=F`) history only 2021+, and neither US2Y nor YCURVE is used by the 3 current
  model formulas (they are fetched for brief display + future models).

**C5. Live-vs-backtest PARITY verified (the load-bearing check).** `mris_crisis_backtest.ps1`
reimplements the scorer independently of `mris_crisis_models.ps1`; if they diverged, the 7/7
would validate something other than what runs live. Replayed the backtest over 2026-07-18..25
and compared its last row to the live `crisis_models_state.json` from the same date:
**YIELD_SHOCK 45.1 / CREDIT_STRESS 5.0 / INFLATION_OIL 83.5 — identical to the decimal in both.**
The two implementations agree.

**C6. Check-harness flaw found & fixed during C5.** Running a SUBSET of windows printed
`[spec] ... PASS` for windows that were never run — absence of data was being counted as a
quiet gate, so a partial run could masquerade as a validated one. Checks now return
PASS/FAIL/**SKIP**, and any skip prints "this run does NOT validate the gate". Full run still
7 passed / 0 failed / 0 skipped.

## PHASE D — PROPOSED fold into the real-money path (NOT built; needs user ratify)

The user's original ask was "reduce lot on big macro events / pause trading". MacroGate already
has the machinery (`MacroGate_Core.mqh`: reads a state string from the exported CSV, sets a
per-magic lot-multiplier GlobalVariable, can block new orders). So the only missing piece is a
**policy** mapping crisis scores → state. Proposed design, deliberately the most conservative
shape available:

**Iron rule: the crisis layer may only ever REDUCE risk, never increase it — one notch, never up.**
It can downgrade the exported state (RISK_ON→NEUTRAL→RISK_OFF) but can NEVER upgrade one. A false
positive then costs some missed profit; it can never cause overexposure. Given Phase-C specificity
(0/125 false-fire days in the tested non-credit episodes) that trade is acceptable.

| condition | proposed effect on the EXPORTED state | rationale |
|---|---|---|
| any crisis model `active` (≥60) | downgrade one notch (max once) | a confirmed macro shock |
| CREDIT_STRESS `active` | downgrade one notch **and** flag carry legs | credit is the fastest-contagion axis |
| models only `forming` (40-60) | **no change** — brief/alert only | avoid throttling on noise |
| all `dormant` | no change | 8-barometer RI stands alone |

Not proposed: letting a crisis score raise the state, block-new on `forming`, or any auto-close
(user doctrine: reduce lot, never cut).

**Gate before this is built:** (1) Codex blind audit of the Phase-A/C code — first attempt was
dispatched to a background Codex job whose result proved **unretrievable** from the main seat
(registry lives in the forwarder's process; `status`→"No jobs recorded yet", `result <id>`→"No job
found"). The highest-value item was therefore verified in-seat instead (C5 parity). A synchronous
Codex audit is still owed before any live flip. (2) user ratifies the policy table — **RATIFIED
2026-07-25**; (3) implement behind a **default-OFF** switch; (4) produce the real cost estimate
BEFORE any live flip.

---
### PHASE D BUILT 2026-07-25 (switch DEFAULT OFF — nothing live has changed)

`mris_export_regime.ps1` gained `-EnableCrisisFold` (off by default) + `mris_fold_costcheck.ps1`.
Fold rules as ratified, plus two guards added during implementation:
- **coverage ≥ 0.5 required** — a score computed from a fraction of its components must never
  throttle live lots.
- **fail-safe** — missing/unparseable `crisis_models_state.json` exports the core state unchanged.
- **Proof the switch is inert when off:** exported CSV hash byte-identical before/after
  (`2A7D4424…5E38`). With it on: `NEUTRAL -> RISK_OFF (INFLATION_OIL=83.5)` and the reason is
  written into the CSV's flags column for audit.

**COST ESTIMATE (`mris_fold_costcheck.ps1`) — "newly throttled" = days the fold engaged
lot-reduce/block that the core layer alone would not have:**

| window | days | newly throttled | read |
|---|---|---|---|
| calm_2017 (VIX ~10) | 67 | **0 (0%)** | does not cry wolf in a calm tape |
| precovid_2019q4 | 62 | **0 (0%)** | same |
| calm_2021h1 | 59 | 8 (13.6%) | oil-reopening surge — arguably a true early signal, not noise |
| covid_2020 | 67 | **0 (0%)** | ⚠️ **headroom only 1.5%** — core was already throttling 50/67 days, so this window cannot price the fold. The earlier claim that it "empirically confirms the STRESS cap costs zero" was OVERSTATED: it is consistent with that, not proof of it, and the core's 2020 risk-off count is itself inflated by the ORDER-203 AUDJPY-pin defect. |
| inflation_2022 | 106 | 27 (25.5%) | core said NEUTRAL 62 days; 2022 was genuinely hostile to risk |
| yield_spike_2023 | 63 | 19 (30.2%) | core said NEUTRAL all 63 days — this is exactly the gap the user spotted vs the vercel site |

**Honest reading:** the fold is ~free in calm tape and redundant in a full crisis (the core
8-barometer layer already fires). Its entire value lands in the **mid-regime** stress the core
misses — which is precisely the divergence that started this order.

**Cost, re-measured 2026-07-25 on windows with real HEADROOM** (headroom = days the core was NOT
already throttling; without it a window reads 0% for the wrong reason):
| calm window | headroom | newly throttled |
|---|---|---|
| calm_2017 | 97% | **0/67 (0%)** |
| precovid_2019q4 | 40.3% | **0/62 (0%)** |
| calm_2021h1 | 96.6% | 8/59 (13.6%) — oil reopening, arguably a true early signal |
`mris_fold_costcheck.ps1` now prints headroom per window and **excludes saturated windows from
the cost verdict** instead of averaging them in (covid_2020 headroom 1.5%, calm_2019 2%).

### Scrutinize pass 2026-07-25 — 6 defects found and fixed (all verified by re-run)
1. **[major] the phone-push path had no evidence gate.** The fold refused to throttle below
   `coverage >= 0.5`, but `mris_alert.ps1` compared `label` alone — so a partial feed outage
   could push a HIGH "CRISIS active" built from a fraction of the components. Degraded models
   (`status != OK`) are now carried as `unknown`, which the rank map scores -1 so it can never
   register as an upward crossing. Verified: degraded→silent, same jump with good data→still alerts.
2. **[major] the fold ignored the age of the crisis scores.** The exported CSV is rewritten
   daily, so MacroGate's own file-age guard always sees a fresh file and cannot tell that the
   scores inside are days old (the crisis stage is non-fatal in `mris_run.ps1`). Added a
   `generated_utc` gate (`fold_policy.max_age_hours`, default 30) mirroring `EffStatus`.
   Verified: 216h-old state → fold skipped, fresh → folds.
3. **[minor] the cost estimator encoded its own copy of the policy.** Ladder + `min_coverage`
   now live in `crisis_models.json` `fold_policy`, read by BOTH the exporter and the estimator;
   the crisis backtest emits per-model `*_cov` columns so the estimator can apply the same
   evidence gate. Cost numbers unchanged (verified), but they can no longer silently drift.
4. **[minor] Infinity could fabricate a max-severity score.** `bps5d` divides by
   `1 + chg5d/100`, so a -100% print yields ±Infinity; for a component whose stress anchor sits
   BELOW its calm anchor the ramp clamped that to a full 100. `Ramp` now rejects NaN/Infinity as
   no-data. Verified against ±Inf and NaN.
5. **[nit] the fold appended to `flags` after the comma/quote sanitisation** the original author
   put there, and used culture-sensitive `[string]$score`. Now sanitised identically and
   formatted with InvariantCulture. (The MQL reader `MG_SplitCsv` is quote-aware, so this was
   latent, not live.)
6. **[nit] `-Detailed` hardcoded the total barometer weight (13).** Now summed from config.

Re-verified after all six: C5 parity still identical (43.4 / 4.1 / 76.1 both sides), backtest
still 7 passed / 0 failed / 0 skipped, fold-OFF export still deterministic and free of any
`CRISIS_FOLD` text, full 7-step chain clean and silent, all scripts pure ASCII.

**⚠️ Finding about the CORE layer (not the new one):** the first cost run used `calm_2019` as the
control and reported 0% — but only because the **core** layer already sat at RISK_OFF on **48/51
days** of mid-2019, so the fold had nowhere to downgrade. A saturated control reads as "free" for
the wrong reason. Re-run with 2017/2019Q4/2021H1 controls. Separately, core printing RISK_OFF ~94%
of mid-2019 deserves its own look — that is the 8-barometer layer being trigger-happy, and it is
NOT in this order's scope.

## NOT DONE (future, gated)
- Codex blind audit — NOT required now (layer is advisory, does not touch exported RI).
  REQUIRED before any fold into the MacroGate real-money path.
- Fold any crisis score into RI / MacroGate — separate order, user-ratified only.
