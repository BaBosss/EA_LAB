# Boss19 P4 — 2022 Confound Diagnostic

Status: `DIAGNOSTIC_COMPLETE / RESEARCH_ONLY / STOP_EXPANSION_PARK`

Decision: `NO_P5_READY_LEVER_FROM_CURRENT_P4_LABELS`

Authority: read-only interpretation of already accepted P4 evidence. This report authorizes no P5 execution, strategy change, optimization, HOLDOUT use, Candidate/Grade/KINT change, risk/default change, runtime attachment, deployment, or trading.

## 1. Direct consumer

Resolve the narrow question left by the accepted P4 interpretation: is Boss19's 2022 weakness a broad calendar-year effect, a stable classifier-STRESS effect, an interaction that yields a prospective one-change lever, or only a concentrated/time-confounded observation?

The direct consumer is the P5 gate. PASS requires either one defensible prospective one-change hypothesis with a falsifier, or an explicit `STOP_EXPANSION / PARK` when the accepted evidence does not support one.

## 2. Frozen evidence reused

- canonical base: `469a2f1c12933f26b256836a4425240cdb84cd3e`
- P4 regime-attribution package: `353ab806a1ce29046adb249f84c205d0a34a5de8`
- broad36 source package: `ecd5c2b3af0791674a7cce18464e632750f37755`
- detail source: `_mt5_auto/p4b_boss19_regime/regime_attribution_detail.csv`
- accepted population: 1,549 DEAL units, 1,549 `CLASSIFIED`, 0 `UNKNOWN`
- reconciled total net: `+17718.78`
- HOLDOUT: `UNSPENT`; optimization: `NONE`

No MT5/tester run, evidence rebuild, parameter search, or HOLDOUT access occurred in this diagnostic.
## 3. Evidence

### 3.1 Year-level result

| Year | Units | Net | PF |
|---|---:|---:|---:|
| 2020 | 367 | +4564.52 | 6.57 |
| 2021 | 110 | -2127.34 | 0.30 |
| 2022 | 190 | -3538.07 | 0.46 |
| 2023 | 368 | +3696.90 | 2.80 |
| 2024 | 292 | +6667.75 | 14.01 |
| 2025 | 222 | +8455.02 | 3.67 |

2022 is negative, but the loss is not broad across the available homes. XAUUSD contributes `-3749.45`; removing XAUUSD leaves the rest of 2022 at `+211.38`. Negative 2022 symbol-group net is 84.1% XAUUSD, 10.6% GBPUSD, and 5.4% AUDUSD; USDJPY is `+874.03` and BTCUSD is `+48.91`.

Across the nine symbol/TF pairs that actually have 2022 entries, five are net negative; the other nine of eighteen possible pairs have no 2022 entries and cannot support a 2022 sign claim. Only two participating pairs are negative in both 2021 and 2022. This does not support treating "calendar year 2022" as a uniform failure state across homes; the observed signed loss is economically concentrated in XAUUSD.

### 3.2 STRESS versus non-STRESS

- 2020: STRESS `+753.34`; non-STRESS `+3811.18`.
- 2021: STRESS `0.00`; non-STRESS `-2127.34`.
- 2022: STRESS `-2015.27`; non-STRESS `-1522.80`.

Therefore STRESS explains only part of 2022's loss, while a different losing BWD year exists without STRESS contribution. The accepted P4 conclusion remains intact: classifier-STRESS is not a stable harmful regime and is not a defensible kill-switch/filter lever from this evidence.
### 3.3 Two concentrated 2022 episodes

Entry-month grouping isolates the negative 2022 group-net to two months:

- March 2022: `-3866.64` across 74 units.
- October 2022: `-1089.38` across 23 units.
- all other 2022 entry months combined: `+1417.95`.

March is dominated by XAUUSD: 23 XAUUSD units contribute `-4023.32`, while USDJPY in the same month contributes `+629.10`. The XAUUSD loss crosses H1 (`-1907.70`), M15 (`-1333.84`), and H4 (`-781.78`). Seven XAUUSD exits associated with entries on 2022-03-08 alone contribute `-3061.53`.

October is a different episode: all 23 units are USDJPY and net `-1089.38`, led by H4 `-547.41` and H1 `-514.34`. This is not the same symbol or classifier mix as the March episode.

The exclusions above are diagnostic decompositions only. They are not recommendations to exclude a symbol, month, or historical period from future operation.

### 3.4 Classifier tuple stability check

March XAUUSD's largest negative tuple is `(STRESS, TREND_UP, EXTREME)`: 11 units, `-2831.85`. The same pooled tuple is positive in BWD-2020 (`+355.99`, 21 units) and MAIN-2025 (`+441.54`, 16 units).

October USDJPY's largest negative tuple is `(NEUTRAL, TREND_UP, LOW)`: five units, `-1037.31`. The pooled tuple is positive in BWD-2020 (`+553.09`), negative in BWD-2021 (`-73.38`) and BWD-2022 (`-1022.61`), positive in MAIN-2023 (`+524.92`), negative in MAIN-2024 (`-64.76`), and positive in MAIN-2025 (`+213.05`).

Both candidate classifier explanations reverse sign across accepted windows/years. No single frozen classifier label separates the adverse episodes from profitable observations without hindsight.
## 4. Interpretation

The accepted evidence supports **concentrated temporal/context dependence**, not a stable STRESS effect and not a broad 2022 calendar-year effect. The two largest adverse episodes differ materially: March is XAUUSD-heavy and largely STRESS/TREND_UP/EXTREME; October is USDJPY-heavy and primarily NEUTRAL/TREND_UP/LOW.

A common `TREND_UP` label does not create a usable lever: TREND_UP is the dominant profitable local structure in the full P4 evidence, and the relevant macro/volatility combinations reverse sign in other accepted years. Gating TREND_UP, STRESS, EXTREME volatility, LOW volatility, XAUUSD, or a calendar month from these observations would be a post-hoc restriction that discards profitable counterexamples.

2021 also remains materially negative across several symbols (XAUUSD, EURUSD, GBPUSD, AUDUSD) while USDJPY is positive, so the historical weakness is not reducible to one repeating 2022-only state.

No universal sample-size or confidence threshold is introduced. `KINT-001` remains open and participation confidence remains governed by the existing fail-closed contract.

## 5. Decision

`STOP_EXPANSION / PARK`

`P5_HYPOTHESIS_CANDIDATE = NONE_FROM_CURRENT_P4_LABELS`

The deterministic diagnostic does not produce a single prospective, falsifiable strategy lever that survives the accepted counter-evidence. Creating a STRESS filter, year filter, symbol exclusion, month exclusion, or volatility gate now would be hindsight-driven rather than preregistered mechanism evidence.

P4 remains complete. Boss19 V0 remains `PARKED-VERIFY(user)`. P5 remains blocked unless a future direct consumer supplies genuinely new evidence or an independently motivated one-change mechanism that can be preregistered without mining these same adverse episodes.

## 6. Scrutiny / authority boundary

- Evidence was reused; accepted MT5 evidence was not rerun.
- Evidence, interpretation, and decision are separated above.
- Negative evidence and profitable counterexamples are preserved rather than filtered away.
- No BWD retuning, optimization, HOLDOUT search, Candidate/Grade/KINT mapping, risk/default change, runtime/deployment action, or trading action occurred.
- This report requires independent review before canonical integration because it closes a consequential research branch by `STOP_EXPANSION / PARK`.
