# Arxon Black Tide — B5 remaining-component source freeze

Date: 2026-09-16
Canonical parent: `eed2c48455cb14cb0fd16ad0f687148f332fc3cf`
Status: **SOURCE_BOUND_COMPONENT_FREEZE / NO_NEW_MT5 / NO_TRADING_ROLE**

## 1. Scope and authority
This closes the source-reading pass for the remaining Black Tide Wave/Map component cards not already covered by B1-B4.
It records what the fresh public descriptions support and preserves unresolved computation/home/clock/parity questions.
It does **not** select BUY/SELL, ENTRY/FILTER/EXIT role, parent EA, home, risk, Stack, exit, FamilyID, LAB_ENTRY, optimizer, HOLDOUT, Candidate, runtime or deployment.

Fresh source captures:
- `S02` Black Tide Wave — HTML SHA256 `ffbc3d2374d8be65dc3c6447bcc70cb4c3e027499af5df283889a77aaef74a58`.
- `S03` Black Tide Map — HTML SHA256 `11c3ce3a717744bf965a9442abd6eebc37ac87c3727e6b4b64e6205c8ac1ff01`.
- Captured 2026-09-16 under `D:\EA_LAB_CONTROL\evidence\arxon-strategy-cards-20260916`.

Global rule: visual/reference/context output is not a trade decision. Historical origin bars, confirmation/availability times and first admissible action times remain distinct. Display toggles may not rewrite historical computation.
## 2. Black Tide Wave remaining components
| ID | Source-supported facts | Still unresolved before exact provider/trading consumer | B5 status |
|---|---|---|---|
| W01 VWAP | Main VWAP can anchor Session/Day/Week/Month/Year; source is selectable and the published default is version-dependent: earlier releases used `ohlc4`, while later/current release notes move Main, Session and Period VWAP defaults to `hlc3`; optional SD bands exist. | target version/source binding, exact weighted-variance/band parity, zero-volume policy, broker volume basis, reset/calendar parity | `SOURCE_PARTIAL / VERSION_AND_PARITY_REQUIRED` |
| W03 Initial Balance | regular-session anchored range; duration configurable, public default 60 minutes; high/low lock after duration; midpoint and range extensions exist. | broker/exchange session mapping, missing/short session handling, exact first eligible bar | `HOME_CLOCK_REQUIRED` |
| W04 TPO/Profile | configurable bracket; default block 30m; Resolution/Ticks row sizing; public VA default 70%; per-session VAH/VAL/POC/Mid freeze after session; naked memory exists. | binning/tie rules, POC/value-area expansion parity, session calendar, TPO-vs-volume version choices | `COMPLEX_PARITY_REQUIRED` |
| W05 Degrees of Power | structural gauge `-6..+6`; reads today's IB/developing VA plus prior VA/range. Later public releases also publish the per-bar DOP integer as a Data Window output selectable by other indicators through `input.source()`; the output is `na` until all required references exist, while `0` is a real Neutral reading. | exact ordered predicates, historical point-in-time reconstruction, missing-input behavior, direct consumer | `SEMANTICS_REQUIRED / NO_DIRECT_CONSUMER` |
| W06 Alerts | one alert stream; event-specific dedup/re-arm rules; messages can include structural context; confluence is separately composed. | canonical event namespace, restart/replay identity, delivery-vs-decision boundary | `INFRASTRUCTURE_ONLY` |
| W07 embedded OBV | Wave exposes OBV slope, vs-MA and divergence reads; later confluence can consume OBV direction/MA relation. | embedded version/config, slope formula, smoothing/divergence parity, proof before sharing O01 implementation | `EMBEDDED_LINEAGE / PARITY_REQUIRED` |
| W08 embedded MFI | Wave describes length 7, `hlc3`, bands 90/55/50/45/10, zone/value/slope read; own timeframe and non-repainting closed read. | embedded-vs-standalone config identity, zero-flow/feed parity, role/neutral behavior | `EMBEDDED_LINEAGE / CONFIG_FREEZE_REQUIRED` |

W02 K2 is owned by B3 and is not re-frozen here.
## 3. Black Tide Map components — structure/zones
| ID | Source-supported facts | Still unresolved before exact provider/trading consumer | B5 status |
|---|---|---|---|
| M01 Trend Path | exhaustion zigzag; current public rules use MFI(`hlc3`,7) 90/10 plus both Stochastic lines 80/20; structure timeframe default 1H; chart timeframe tracks exact extreme; HH/HL/LH/LL labels. | pivot replacement/finality, exact Stochastic computation, multi-path rearm and unaligned override parity | `SOURCE_PARTIAL / PIVOT_FINALITY_REQUIRED` |
| M02 Order Blocks | block is scanned backward from structure break; selection modes Extreme/Heaviest/Last opposing; fresh→mitigated→invalidated lifecycle; optional HTF slot; volume measures are descriptive/proxy. | exact zone bounds, structure dependency, lifecycle priority, HTF availability, same-bar conflicts | `COMPLEX_PARITY_REQUIRED` |
| M03 Market Structure | major/minor scales derive from one swing length; asymmetric confirmation bars; confirmed pivot finality; breaks use most recent unswept swing; swept level is not broken twice. | tie/equality, initial bias, exact close-vs-wick break predicate, parameter values/version | `SOURCE_PARTIAL / BREAK_RULE_REQUIRED` |
| M04 FVG/IFVG | bullish `low[0] > high[2]`, bearish `high[0] < low[2]`; confirmed-bar detection; ATR and displacement filters; fill and inversion are distinct; spent gap cannot invert; HTF slot exists. | filter parameter values/formulas, exact touch/fill priority, inversion candle requirements, HTF parity | `SOURCE_PARTIAL / FILTER_FREEZE_REQUIRED` |
| M05 Naked Key Levels | completed-period highs/lows remembered until retested; High is tested by `high >= level`, Low by `low <= level`; spent levels are evicted before live ones; memory is independent of drawing cap. | exact period universe/calendar, equal-time precedence, history limits | `CALENDAR_FREEZE_REQUIRED` |
| M06 Session Key Levels | Asia/London/New York session highs/lows draw after close; default clear mode keeps pair until the same session reopens. | session strings/timezones/DST, broker-clock mapping, short/missing sessions | `HOME_CLOCK_REQUIRED` |
| M07 Daily/Weekly/Monthly Key Levels | PDH/PDL, PWH/PWL, PMH/PML plus directional Fibonacci grid; prior-period extremes are snapshotted on rollover from chart bars; higher period wins at identical price. | exact Fibonacci level recipe, rollover calendar, same-price provenance behavior | `CALENDAR/RECIPE_FREEZE_REQUIRED` |
| M08 Daily Zones | premium/discount golden zones are 61.8%–78.6% retracement bands of yesterday's daily range. | trading-day calendar, zero-range policy, boundary equality and zone lifecycle | `CALENDAR_FREEZE_REQUIRED` |
| M09 Anchor Candles | Doji, Hammer, Inverted Hammer and Inside Bar are separately marked; optional bar coloring. | exact pattern thresholds, equality/containment rules, overlap priority, expiry | `SEMANTICS_REQUIRED` |
| M10 Session Clock | bottom strips for open sessions/overlap; no independent session windows; reuses Session Key Levels hours/timezone/toggles; intraday only. | same M06 timezone/DST/broker mapping and unknown-clock behavior | `SHARED_CLOCK_INFRASTRUCTURE` |
| M11 Consolidation | range box uses relative tightness vs recent windows plus absolute ATR max-height gate; break is provisional with grace/reopen; decisive travel can confirm early; separate confirmed-break/failed-break alerts. | exact window/average/ATR parameters, grace duration, early-confirm threshold, expansion/reconfirm ordering | `SEMANTICS_REQUIRED` |

## 4. Preserved separation
- Black Tide Map itself says it is a reference layer, not a trade system/signal generator. Do not turn geometry labels into BUY/SELL without a separate causal contract.
- M10 session-clock/context work does not reopen closed `HYP-SB-005 / Boss19 P5` session research.
- W07/W08 embedded reads are separate configuration lineages from standalone O01/O02 until same-version parity proves reuse.
- W06 alerts and M10 Session Clock are infrastructure, not standalone EA families.
- DOP/confluence scores or thresholds are not authorized trading floors; no arbitrary score is introduced here.

## 5. B5 outcome
The remaining Black Tide source-reading pass is **COMPLETE** at documentary scope. Public descriptions now support a bounded mechanism inventory for every W/M component, but most complex providers still require explicit computation/calendar/parity freezes before code can claim source parity.
No additional order-free provider is authorized automatically by this B5 document. The only implemented Arxon provider in this milestone remains O02/MFI from Work Package C.
