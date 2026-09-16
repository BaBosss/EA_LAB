# Arxon -> EA Template V2: implementation and merge plan

Date: 2026-09-16. Inspected canonical base: `a9c54b8f4e2924a4329ea502ba34ffb5ee435c53`.
Status: **DESIGN/PLANNING ONLY; executable implementation not begun.**
Direct consumer: [six family cards and 23 component slots](../../ea_template/strategy_cards/arxon/README.md).

## 1. Deliver the cards now; do not equate the parent gate with a documentation blocker
The owner wants the whole library prepared. Stage A therefore integrates cards and implementation work packages without choosing trades. Two subsequent routes exist: (a) a one-change child of an exact qualified parent, or (b) a separately approved source-bound new-family contract. Neither route is chosen simply because an indicator has a colour or arrow.
Keep ARX/W/M/O identifiers documentation-only. Do not allocate Bxx/LAB_ENTRY/Exxx IDs, create Factory StrategyRecords or expose new inputs from a card. Alerts and Session Clock are infrastructure, not standalone EAs. Embedded OBV/MFI and standalone OBV+/MFI+ remain distinct configuration lineages until parity proves reuse.

## 2. Actual repository attachment points (not a new framework)
| Observed path | How the future implementation uses it |
|---|---|
| `ea_template/core/entries/IEntry.mqh` | EntrySignal(direction,strength,confidence,valid,reason); Entry_MakeNone; no order management in the entry seam. |
| `ea_template/core/LabCore.mqh` | Compile-time LAB_ENTRY_11..19 includes and entry dispatch; first entry and Stack ownership are distinct. |
| `ea_template/core/entries/Entry_GridTrendMA.mqh` | Existing example is MA ordering evaluated with Indi_* shift 0, not proof of K2 close-cross parity. |
| `ea_template/core/Indicators.mqh` | Existing indicator access/lifecycle home; proposed Arxon provider must be reviewed before use here. |
| `ea_template/core/Inputs.mqh` | Exposed enums and per-entry inputs; no IDs, names, or values added by this package. |
| `docs/PARAM_REGISTRY.csv` | Actual canonical parameter registry; NOT ea_template/PARAM_REGISTRY.yaml or a new parallel input registry. |
| `scripts/param_registry_check.ps1` | Required parameter alignment checker for future input changes. |
| `scripts/param_registry_fix_lines.ps1` | Existing bounded parameter registry maintenance, only after an approved input edit. |
| `ea_template/core/Stack.mqh` | Position additions remain chassis-owned. |
| `ea_template/core/RiskControl.mqh` | Risk cage remains supreme; no indicator can override it. |
| `ea_template/core/ExitManager.mqh` | Exit ownership remains explicit; a context event may not liquidate positions implicitly. |
| `ea_template/core/ConfigFingerprint.mqh` | Future effective parameter binding must remain reproducible. |
| `scripts/tpl_regression.ps1` | Mandatory on future core edits; not run as a research test in this documentation scope. |
| `factory/strategy_catalog.json` | Existing accepted strategy catalog; left unchanged, ARX IDs are documentation IDs only. |
| `ea_template/DESIGN_V2.md` | V1/modules are deprecated; future EA builds must target current V2 compile-time wrapper design. |
| `ea_template/PRODUCT_CONCEPT.md` | Shared chassis x entry x home/config; native mechanics and defaults require explicit contracts. |

`ea_template/README.md` contains stale V1 material; its new Arxon entrypoint must explicitly route to V2. Do not broadly rewrite the old README in this scope. `DESIGN_V2.md` also includes historical examples: actual current source, not a numeric token shown in a stale example, controls the new wrapper pattern.

### Critical adapter mismatch discovered by inspection
`Entry_GridTrendMA.mqh` reads `Indi_FastMA(0)`/`Indi_SlowMA(0)` and returns their current ordering. A close-confirmed K2 cross is an **event**, not that sustained state; sharing the MA helper does not prove shared signal semantics. Separate bar availability, event ID, one-shot consumption, eligibility and no-signal behavior. Existing `EntrySignal` has numeric strength/confidence: define their exact downstream meaning before adding an Arxon adapter; never call a convenient `1.0` a market probability or use an arbitrary floor. Use an explicit reviewed no-data path rather than representing missing data as neutral.

## 3. Common prospective component contract
Each provider must bind source/version, parameters, logical symbol and actual broker/feed, chart and calculation timeframe, price and volume basis, exchange/broker clock, warmup, source-bar time, confirmation/availability time, validity, event identity and lifecycle. These are required **design fields**, not a newly installed runtime schema.
Freeze: input ranges and equality; repeated events and restart; indicator handle creation/release; history truncation; HTF developing/confirmed policy; session/DST rollover; invalid/empty/zero-volume data; provider on/off versus display-only toggles. No secret screenshot-backplot timing.
All trading decisions need an explicit entry/exit mapping, selected home, position-engine/native-mechanic exceptions, sizing and risk configuration. Reuse current chassis semantics only after proving applicability to the selected family. Do not silently apply the generic reference's lot/grid/stop values to every Arxon-derived EA.

## 4. Work packages and order of execution
| Work package | Output / scope | Entry gate | Exit gate / next consumer |
|---|---|---|---|
| A — cards and plan | Six family cards + 23 module cards, source evidence, actual V2 map, README | This owner request | Document validation + independent scoped review; eligible documentary merge |
| B1 — standalone MFI semantic freeze | Bind verified 7/hlc3/55/45/90/10 reference separately from future EA defaults; freeze zero flow, volume and bar sampling | Source description + exact intended component consumer | Approved deterministic non-trading component contract; no parent performance claim |
| B2 — Stochastic event freeze | Resolve simultaneous individual crosses vs first joint in-zone, K/D smoothing, equality/rearm, close timing | Authoritative source/author answer or lawful per-bar reference | One frozen event definition; role/direction must be approved before entry/filter mapping |
| B3 — K2 freeze | Close-cross 8/21 engine; seed/source, ties and MTF policy; A2 not included by default | Version/settings and reference capture | One K2 component contract; no implicit EMA200/55 or A2 filter |
| B4 — RSI/OBV detector freeze | RSI timing variants remain distinct; OBV slope/cross/divergence not bundled | Source details / reference | Exact individual detector contract before implementation |
| B5 — session/profile/structure freeze | Every W/M slot's separate calendar, finality or zone lifecycle | Card-specific source gaps resolved | Individual provider contracts; closed session experiment not reopened |
| C — pure component implementation | Order-free provider, fixture/reference data and isolated harness | Per-provider semantic contract + authorized author | Compile/harness checks, exact event/value comparison; no Tester run implied |
| D — V2 adapter and input binding | ENTRY adapter or specifically scoped FILTER/EXIT consumer, allocated identity, registry/fingerprint/report wiring | Entry or parent contract with home/role/direction/position/risk ownership | Exact build/source/set; PARAM_REGISTRY + compile + all impacted core cages |
| E — review-gated code merge | Frozen exact component/adapter HEAD | C/D evidence | Qualified different-family core review; one repair/recheck; eligible FF integration |
| F — controlled research | One fixed-config control versus one logical child or separately approved new-family baseline | Prospective ExperimentContract / accepted home/window/build/config | MAIN then untouched BWD, participation/year/cost/concentration, falsifier and report |
| G — candidate/deployment gates | Only separately authorized downstream work | Required frozen same-lineage Model4 MAIN+BWD and other canonical gates | No automatic HOLDOUT, Candidate, runtime, DEMO/LIVE or trading |

B1/B2/B3 can be prepared independently without editing shared core. B4 and each B5 submodule are independent only after their source inputs are identified. Writer serialization is mandatory at Inputs/PARAM_REGISTRY/LabCore/README/status. Normal WIP <=4; isolated <=8, never compete with accepted runtime/tester lanes. Do not run every permutation: one causal question per experiment, not a library-wide optimization matrix.

The next bounded non-trading consumer is **B1 MFI source-to-computation semantic freeze**, while Stochastic remains the existing first research-planning lead; this is not a ranking of profitable strategies or a change to the accepted experiment queue.

## 5. All-component coverage / split plan
- **W01 VWAP / AVWAP / bands**: A single price-location filter or one registered VWAP event; neither bounce nor breakout is selected. Freeze: anchor and reset calendar; price source and volume type; variance/band formula; post-session continuation and zero-volume policy.
- **W02 K2 Ribbon, context EMAs, MTF and A2**: A K2 cross entry family or one parent filter; freeze K2 alone before any A2/MTF extension. Freeze: EMA seed/price basis and equality; MTF completed vs developing bars; A2 confluence version and delays; entry/exit direction and signal expiry.
- **W03 Initial Balance / session IB / extensions**: One independent IB location/event consumer, never an automatic rescue of the closed session experiment. Freeze: exchange/broker clock mapping; duration and first eligible session bar; range lock and extensions; short sessions and missing bars.
- **W04 TPO / value area / naked levels / single prints**: One explicitly selected profile feature, not a combined auction score. Freeze: row sizing and bracket assignment; POC tie-breaking and value-area expansion; TPO versus volume POC version; level memory and tested-state rules.
- **W05 Degrees of Power**: Context-only until a separate consumer and causal historical engine are frozen; no invented score or floor. Freeze: exact ordered predicates; historical point-in-time inputs; missing-input behavior; direct consumer of a gauge value.
- **W06 Alerts**: An internal event log/adapter dependency. No standalone EA, webhook, scheduler or broker action is activated. Freeze: event namespace and confirmation trigger; toggle semantics; duplicate/restart behavior; delivery versus strategy decision separation.
- **W07 Embedded OBV read**: Embedded confirmation component; share an engine with O01 only after identical-version parity is demonstrated. Freeze: embedded version and formula; volume feed and initialization; smoothing and pivots; proof before sharing standalone implementation.
- **W08 Embedded MFI read**: Embedded context filter; do not silently copy fixed standalone bands into the Wave slot or vice versa. Freeze: embedded period/source/bands; volume and zero-flow behavior; standalone-to-embedded mapping; role and neutral handling.
- **M01 Trend Path / exhaustion zigzag**: A confirmed turn/context feature only after finality is defined; never trade at a retrospectively moved pivot. Freeze: saturation condition/version; structure timeframe; chart extreme tracking and finality; pivot replacement and rearming.
- **M02 Order Blocks / breakers / HTF slot**: One block-location filter or one specific lifecycle event per contract, not every OB behavior in one EA. Freeze: block selection mode and bounds; structure break dependency; mitigation/invalidation/breaker priority; HTF creation availability and expiry.
- **M03 Market Structure / BOS / CHoCH**: A structure-event entry candidate or one confirmation filter; direction and trade management stay unselected. Freeze: left/right confirmation bars; ties and initial bias; close-versus-wick break; unswept swing and major/minor priority.
- **M04 FVG / IFVG / HTF slot**: One gap event or one location filter, not a combined gap/OB/structure rescue stack. Freeze: three-bar gap boundaries; size/displacement rules; touch/fill/inversion order; HTF and already-spent gap policy.
- **M05 Naked Key Levels**: One distance/location or touch event from a frozen level source; no added score ranking. Freeze: period definition and rollover; touch-versus-cross equality; eviction policy; scope of historical memory.
- **M06 Session Key Levels**: Location infrastructure only unless an independent non-rescue consumer is separately accepted. Freeze: session timezone/calendar; close and reopening behavior; developing-versus-final levels; visibility and tested-level retention.
- **M07 Daily / weekly / monthly Key Levels**: One previous-period level feature; Fibonacci is optional and separately frozen, not assumed. Freeze: trading-day/week/month boundaries; level precedence at equal prices; selected retracement recipe; developing-versus-previous period.
- **M08 Daily Zones**: One location filter with an independent trigger; do not manufacture entries solely from zone colour. Freeze: daily calendar and range basis; zone fractions/version; boundary equality; zone entry/exit and expiry.
- **M09 Anchor Candles**: One named pattern candidate per contract; no silent adoption of general textbook detector thresholds. Freeze: pattern definitions and thresholds; inside-bar containment and ties; overlapping detector priority; close confirmation and expiry.
- **M10 Session Clock**: Shared clock helper, not a standalone EA. Closed Black Tide session research remains closed. Freeze: IANA/broker timezone mapping; DST and overlap handling; sessions actually used by parent; unknown-clock behavior.
- **M11 Consolidation / confirmed and failed breaks**: Either one confirmed breakout or one failed-break event in a separate contract; no outcome-based choice. Freeze: range window and ATR/average definition; freeze/expand policy; grace and reconfirmation; event ordering and expiry.
- **O01 Arxon OBV+**: Select slope OR smoothing cross OR one divergence detector as one causal change. Freeze: slope and flat rule; smoothing defaults; price/OBV pivot pairing; regular/hidden divergence and confirmation delays.
- **O02 Arxon MFI+**: A three-state filter with a separate entry trigger; green is not an automatic BUY and neutral is not an automatic exit. Freeze: input volume type; numeric warmup and zero-flow policy; bar-close sampling; what neutral means to the selected parent.
- **O03 Stochastic + Dual Zone Entry**: One event mapped to an explicit parent OR new-family contract; neither reversal nor continuation is selected. Freeze: K/D periods and smoothing; same-bar double crossing versus first joint-in-zone; equality and rearming; entry/filter/exit/context role and direction.
- **O04 RSI Cross Alert**: A version-labelled event provider, potentially Arxon-inspired; no exact clone claim until timing parity is proven. Freeze: authoritative version/timing; period/bands/smoothing; equal extremes and rearming; optional divergence as separate change.

## 6. Merge acceptance, regression and presentation
A documentary merge must leave every MQ5/MQH, accepted Factory catalog and parameter-registry byte unchanged. The card checker proves coverage/links/authority boundary only; it does not test trading code.
C/D/E must use the installed compilation/build-receipt and parameter paths, `scripts/param_registry_check.ps1`, applicable input/fingerprint checks, and `scripts/tpl_regression.ps1` for any core edit, plus canonical hooks. Validate all prior Boss builds under the bounded regression contract. Existing known failures are preserved, never silenced by changing baselines. Obtain the required different-family review on a clean frozen HEAD; same-family document review is not a substitute.
F must read `CLAUDE.md`, `docs/research/EA_RND_PROTOCOL.md`, `docs/research/EA_REPORT_SCHEMA.md` and its exact family/experiment contract. No Model2 performance claims, cross-install A/B comparisons, BWD retuning, HOLDOUT discovery, invented grading/KINT floors or Candidate from M1. Model4 is primary `D:\Meta 5`, serial under canonical rules; Meta5c has no Model4 authority.

## 7. Definitions of done and blockers
- **Cards integrated**: source/design material is reachable inside Template and has passed its documentary gates.
- **Component implemented**: compiled order-free engine with exact semantic tests; no automatic order capability.
- **EA integrated**: qualified reviewed adapter + frozen parameters + chassis/regression evidence are canonical. This milestone does not claim that.
- **Research validated / deployed**: separate decisions based on their own evidence and owner authority.

Preserve `SEMANTICS_REQUIRED / NO_QUALIFIED_PARENT` for the existing Stochastic experiment; preserve RSI timing ambiguity; distinguish embedded/standalone MFI/OBV; preserve `HYP-SB-005` and other closed branches. A source-supported default is not permission to change a runtime default. Source code access and parity remain unproven. Full manuals were not re-audited here; current-page/manual discrepancies remain explicit freeze questions.

## 8. Coordination and durable handoff
This package owns only its new card directory, this plan and the Template README link. Another live lane owns P03/PROJECT_STATE during authoring; do not seize its writer. Main Control Tower can consume this canonical package as a source-bound planning result and record a status locator in its normal serialized state sync. `CONTRACT.md` is the exact order for this bounded documentary lane, not a replacement global taskboard or a new Control Tower.
