# B11 / B12 / B18 prospective owner decision packets — 2026-09-12

**NON_AUTHORITATIVE_PROPOSAL / OWNER_CHOICE_REQUIRED / NO RATIFICATION OR EXECUTION AUTHORITY**

BASE: `728dbcb215e10c4be799ed1c4f6443bd7bdf0727`. Device: BaBoss, requested device ID `bbb88aa0-1598-43f6-b56c-a7db22af086a`. Lane: `QRESET-07-FAMILY-DECISION-PACKS`. Remote: `https://github.com/BaBosss/EA_LAB.git`. Worktree: `D:\EA_LAB_CONTROL\worktrees\qreset07-family-decision-packs-20260912`.

The owner can prospectively choose one entry bundle, explicit ATR period and Home per family. No current evidence identifies a uniquely justified best choice. The three families have accepted source implementations and ratified native classification `NONE`; they need explicit reference decisions and a fresh bounded screen contract rather than a core rewrite. This packet does not choose those values or open a tester run.

The direct consumer is owner selection followed by Control Tower creation of a **new** fixed-reference Model1 contract. Historical H01 configuration, Home, results and package identities never become Bxx-00 authority by implication. A numeric/Home change is configuration identity, not automatically a new causal family. Accepted closed experiments remain closed.

## One-page owner summary

All options below remain **UNSELECTED**. Their names describe the research context, not expected profitability. Selecting a Home alone does not authorize copying its historical chassis or sizing. The listed entry bundles and ATR14 are candidate values that still require explicit prospective acceptance. Custom source-valid values remain possible through the detailed decision fields below.

| Family | Choice A | Choice B | Choice C | What is being decided |
|---|---|---|---|---|
| B11 GridTrend | Listed MA bundle + ATR14 + XAUUSD/H1: familiar H01 reference context | Same bundle + ATR14 + USDJPY/H4: context with an accepted stack-mechanism contrast | Same bundle + ATR14 + XAUUSD/H4: context where the accepted stack contrast retained losing BWD | Freeze MA periods/method/TF, ATR period and one Home; keep generic xx-00 chassis |
| B12 Breakout | Listed breakout bundle + ATR14 + XAUUSD/H1: familiar H01 context | Same bundle + ATR14 + XAUUSD/H4: closed-bar confirmation mechanism context | Same bundle + ATR14 + USDJPY/H1: opposite historical window-sign context | Freeze lookback, confirmation count, session state, ATR period and one Home |
| B18 JumStoch | Listed Mode1 BUY bundle + ATR14 + XAUUSD/H1: accepted H01 context, with a distinct new reference consumer still required | Same bundle + ATR14 + EURUSD/H1: original-source/historical seed context, including prior failure; no presumed edge | Defer B18 reference execution until a distinct useful consumer justifies it; preserve Mode1 and existing status | Freeze the prospective numeric/Home identity or intentionally keep the branch parked; do not reopen Mode2 selection |

Listed B11 bundle: `_0_FastMA=20`, `_0_SlowMA=50`, `_0_MAMethod=MODE_EMA (1)`, `_0_MA_TF=PERIOD_CURRENT (0)`.

Listed B12 bundle: `_12_Bars=20`, `_12_ConfirmBars=1`, `_12_HourFrom=0`, `_12_HourTo=0` (session gate disabled).

Listed B18 bundle: `_18_Direction=1 (BUY)`, `_18_DirMode=1 (FAITHFUL_MOMENTUM_JOIN)`, `_18_MaPeriod=25`, `_18_KPeriod=32`, `_18_DPeriod=12`, `_18_Slowing=12`, `_18_LoLevel=25`, `_18_UpLevel=75`.

**No performance ranking is recommended.** B11's stack experiment does not authorize SINGLE in B11-00; B12's confirmation experiment argues against silently choosing tick mode; B18 Mode2 is a separate alternate causal hypothesis, not an available substitution inside the current faithful identity.

Common Home support: **XAUUSD/H1** has accepted historical H01 context in all three families. **EURUSD/H1** is a source-supported research context for all three, but B18's relevant context includes an older failed chassis-seed campaign, not an accepted new B18-00 result. USDJPY/H4 and XAUUSD/H4 have specific B11 mechanism context; XAUUSD/H4 and USDJPY/H1 have specific B12 confirmation context. Home compatibility is not evidence of profitability, portable economics or current data readiness.

## Shared decisions already settled, and those still required

Canonical owners: `docs/architecture/EA_TEMPLATE_XX00_FAMILY_RATIFICATION_V1.md`, `EA_TEMPLATE_XX00_BACKTEST_READINESS_V1.md`, `ea_template/PRODUCT_CONCEPT.md`, current PROJECT_STATE and the later source-bound readiness audit. Exact BASE blob hashes and source line anchors are in the JSON companion.

Already ratified for these three families: native semantics `NONE`; generic `GRID_AGAINST`, signal ATR distance x2 on `PERIOD_CURRENT`; StackConfirm `DISTANCE`; generic `ATR_BASED` Exit; EA-owned basket balance stop at10% of current account balance. `NONE` means no native exception; it does not mean SINGLE or no grid. ATR period remains explicit.

The minimum prospective entry/Home decision is four components per family: entry bundle, positive integer ATR period, exact Home symbol, exact Home timeframe. This document provides no universal optimizer range or strategy-performance bar. The safe option domains below describe supported mechanics, not proven profitable or risk-safe settings.

**Screen materialization remains a separate explicit step.** Product concept describes a10,000-cent research profile, fixed0.10 primary lot and additive progression preference; B13/B15's later exception used USD10,000, fixed0.01 and no progression as experiment-only controls. That exception names B13/B15. Do not silently transplant it into B11/B12/B18, convert cents to USD, or promote a regression snapshot's risk/exit settings. A new screen contract must explicitly resolve account unit, deposit/leverage, first lot/progression, TP multiplier, maximum levels and effective safety caps, extra filters, shared direction and cadence controls, then freeze the full set. The owner reference decision itself creates no production default or risk change.

## B11 — GridTrend decision packet

### 1. Purpose and accepted semantics

B11 supplies a moving-average direction signal to the common chassis. Its source compares fast and slow MA **at shift0**: fast above slow yields BUY, fast below slow SELL, equal/unready values no signal. It is a directional-state test, not a detected one-time MA crossover event despite the file header's shorthand. Shared `TradeDir` can restrict direction; optional shared ATR-expansion or MA-slope filters may suppress signals. The clean generic reference keeps extra filters OFF unless separately defined.

Signal source: `ea_template/core/entries/Entry_GridTrendMA.mqh:11`; MA construction: `ea_template/core/Indicators.mqh:37`; wrapper: `ea_template/Boss_11_GridTrend.mq5:10`. Native map=NONE; historical `GRID_TREND` is not a native exception and must not replace xx-00 `GRID_AGAINST`.

### 2. Prospective fields and source-supported options

| Field | Listed candidate | Safe semantic option set | What a different choice changes | Source |
|---|---|---|---|---|
| `_0_FastMA` |20| Explicit positive MA period; preserve an intentional fast/slow ordering | Responsiveness of the fast signal average | Inputs.mqh:838 |
| `_0_SlowMA` |50| Explicit positive MA period; equal periods create no strict directional difference | Slow reference horizon; fast<slow is a sensible named-role constraint, not an optimizer range | Inputs.mqh:844 |
| `_0_MAMethod` |EMA/1| SMA, EMA, SMMA or LWMA enum supported by the shared MA handles | Weighting of both MA series | Inputs.mqh:850; PARAM_REGISTRY.csv `_0_MAMethod` |
| `_0_MA_TF` |PERIOD_CURRENT/0| Current Home TF or explicit supported MT5 timeframe, with source-consumer rationale | Signal horizon; this is distinct from the fixed current-TF signal ATR rule | Inputs.mqh:856; Indicators.mqh:33 |
| `_0_ATR_Period` |14| Explicit positive integer; current TF remains fixed | Shared ATR scaling for the reference grid; not a change to MA entry periods | Inputs.mqh:1169 |
| Home symbol/TF |Unselected| Three summary choices; H02 additionally supplies EURUSD/GBPUSD/USDJPY/XAUUSD on M15/H1/H4 as historical contexts | Market, cadence and evidence identity | H01/H02 owners; BT8 contract |

No custom MA period or smoothing method is selected here. A custom bundle is `OWNER_CHOICE_REQUIRED`; an ordinary integer accepted by source is not a qualified research parameter merely because it compiles. B11's MA shift0 behavior is preserved. A closed-bar-only signal rewrite would be a different implementation/causal contract.

### 3. Historical and negative context

H01 XAUUSD/H1 on **MT5-lane3 / D:\Meta 5c**, Model1: MAIN PF1.02, net+529.17,2822 trades, native EqDD19.57%; BWD PF0.88, net-2031.99,2657 trades, EqDD22.88%. These are frozen historical H01 controls, not predicted B11-00 behavior.

H02 found no B11 dual-window positive PF pair. B11 XAUUSD/M15 and GBPUSD/M15 MAIN/BWD were the two ineligible pairs because four cells were suspected truncated near the hard cage. This is not a reason to tune a risk cap from the packet.

BT8 on **MT5-lane3 / D:\Meta 5c**, Model1 changed only `GRID_TREND91 -> SINGLE90`. USDJPY/H4 PF parent→child was0.97→1.10 MAIN and1.05→1.11 BWD; XAUUSD/H4 was1.02→1.04 MAIN and0.81→0.82 BWD. EqDD improved in all four comparisons, but XAU BWD still lost. Accepted conclusion: `GRID_STACK_MATERIAL_WEAKNESS / ENTRY_ONLY_NOT_YET_QUALIFIED`. This is evidence about those two engines under frozen historical controls, not direct evidence about prospective `GRID_AGAINST92`.

### 4. Choice effects, unknowns and next contract

A preserves historical Home context; B/C place the reference beside existing mechanism context without reusing the old experiment as a new result. All preserve the candidate MA bundle; only the proposed Home differs. They authorize neither SINGLE, GRID_TREND, filters, optimization nor a risk/default change.

UNKNOWN: useful MA periods/method/Home for the generic reference; B11-00 performance under ATRx2 plus basket stop; exact new build/set/effective caps; whether any separately motivated MA change improves cross-window behavior. The closed BT8 task is not reopened.

Smallest following experiment proposal: **one frozen B11-00 Home/config, MAIN+BWD, two Model1 cells**, after complete owner/reference and screen-control freeze. Direct consumer: create the first honest generic-reference evidence record at that Home. This is fixed-reference characterization, not a one-change attribution claim against H01 (the chassis may differ on several specified controls). Stop after the pair; no automatic expansion or optimizer. Full common contract requirements below apply.

## B12 — Breakout decision packet

### 1. Purpose and accepted semantics

B12 supplies a Donchian breakout seed. The lookback channel starts **before** the confirmation window: `channelStart=ConfirmBars+1`. With confirmation1, the last closed bar must close beyond the channel. With N>=1, all N closed bars must remain beyond the same channel. With0, current ask above the high or bid below the low supplies the signal. Session gating is optional; shared direction/filter controls can also suppress entry.

Source: `ea_template/core/entries/Entry_Breakout.mqh:11`, confirmation branch:34, session branch:51; wrapper: `ea_template/Boss_12_Breakout.mq5:10`. Native map=NONE. Closed-bar confirmation is source-supported and has accepted mechanism evidence; replacing it is not automatically authorized by presenting the input.

### 2. Prospective fields and source-supported options

| Field | Listed candidate | Safe semantic option set | What a different choice changes | Source |
|---|---|---|---|---|
| `_12_Bars` |20| Explicit integer>=2 for an unambiguous lookback; source clamps smaller values to2 | Channel horizon, excluding confirmation bars | Inputs.mqh:446; Entry_Breakout.mqh:13 |
| `_12_ConfirmBars` |1|1 preserves accepted candidate; explicit N>=1 requires prospective rationale;0 exists but is excluded from an ordinary continuation by BT5's no-switch conclusion | Number/timing of closed-bar confirmations;0 uses live ask/bid | Inputs.mqh:452; Entry_Breakout.mqh:14 |
| `_12_HourFrom` |0| Pair with HourTo: equal valid hours disable the filter; otherwise explicit0..23 start | Entry session only | Inputs.mqh:458 |
| `_12_HourTo` |0| End-exclusive0..23; From<To same-day interval; From>To wraps midnight | Entry session only, not automatic flattening or exit schedule | Inputs.mqh:464; Entry_Breakout.mqh:56 |
| `_0_ATR_Period` |14| Explicit positive integer on PERIOD_CURRENT | Reference ATR scale, separate from channel lookback | Inputs.mqh:1169 |
| Home symbol/TF |Unselected| XAUUSD/H1, XAUUSD/H4 or USDJPY/H1 highlighted; other exact H02 contexts require explicit selection | Market/TF evidence identity | H01/H02 and BT5 owners |

The session code calls `TimeGMT()` and is documented as UTC hours. This packet verifies that source call, not a qualified historical UTC conversion in Strategy Tester. Choosing a restricted session requires explicit clock/evidence semantics before execution;0/0 avoids that additional session-selection question. Do not guess a profitable session or introduce a session filter from recent outcomes.

### 3. Historical and negative context

H01 XAUUSD/H1 on **MT5-lane2 / D:\Meta 5b**, Model1: MAIN PF0.95, net-399.07,965 trades, EqDD7.72%; BWD PF0.92, net-446.56,929 trades, EqDD6.25%. H02 found no dual-window positive PF B12 pair. The family does not become robust by preserving its default confirmation count.

BT5 ran all comparisons on **MT5-lane3 / D:\Meta 5c**, Model1, changing only confirmation1→0. XAUUSD/H4 parent→child PF:1.26→1.05 MAIN and0.91→0.79 BWD; USDJPY/H1:0.93→0.85 MAIN and1.15→0.99 BWD. Trade count increased in all four windows while PF/net/DD worsened. The parent itself remained window-dependent: XAU positive only MAIN, USDJPY positive only BWD. The accepted result says not to switch to tick mode or open optimization from this result.

No numerical comparison is made between the lane2 H01 and lane3 BT5 values. They describe different experiments and installation histories. BT5's same-install parent/child contrast is the mechanism evidence.

### 4. Choice effects, unknowns and next contract

A retains historical H01 Home context; B/C retain exact contexts of the accepted confirmation diagnostic. They do not select a better Home by PF. All retain confirmation1 and session OFF. The observations justify making confirmation semantics visible, not copying a historical winner or reopening the ablation on more homes.

UNKNOWN: which generic-reference Home/bundle has useful cross-window behavior; whether any new session choice is causally justified and clock-qualified; appropriate custom N/lookback; exact screen build/set/effective controls. Numeric options remain prospective owner choices.

Smallest following proposal: **one frozen B12-00 Home/config, two Model1 MAIN+BWD cells**, with its new generic-reference consumer. Do not rerun BT5 confirmation1→0. A later causal change needs one logical change and a distinct unresolved cross-window question, not an optimizer inferred from the packet.

## B18 — JumStoch decision packet

### 1. Purpose and settled semantics

B18 ports only the JUMSTOCH Trend **seed**: closed-bar price relative to LWMA plus the main Stochastic line. It does not port the standalone's four-basket engine, BEP shift or trailing composition. The common chassis owns grid, sizing, protection and exits. Native map=NONE.

The owner already selected **Mode1 / FAITHFUL_MOMENTUM_JOIN** on2026-09-02. Mode2 is `ALTERNATE_REVERSION_HYPOTHESIS_ONLY`; stale wrapper/header/parameter-registry comments saying the decision remains open do not reopen it. Readiness still asks for the field to be explicitly frozen in a new reference, but that does not make Mode1 versus2 a new unrestricted choice.

Source: `ea_template/core/entries/Entry_JumStoch.mqh:41`; indicator construction: `ea_template/core/Indicators.mqh:62`; semantic decision: `docs/factory/BOSS18_SEMANTIC_DECISION_PACKET.md`, OWNER DECISION section; H01 closure: `docs/factory/BOSS18_H01_FIXED_BASELINE_RESULTS.md`.

Mode1 BUY condition: Close[1]>LWMA[1] and Stoch main[1]<UpLevel. SELL: the source uses `!above` and Stoch>LoLevel; therefore exact equality Close==LWMA follows the non-above branch, even though older prose abbreviates it as below. `_18_Direction` chooses one fixed direction per instance; there is no single dual-engine option. This packet records the source edge case without changing it.

### 2. Prospective fields and source-supported options

| Field | Listed candidate | Safe semantic option set | What a different choice changes | Source |
|---|---|---|---|---|
| `_18_Direction` |1 BUY|1 BUY or2 SELL in a separately explicit reference choice; never BOTH in one instance | Which Mode1 condition can seed this instance | Inputs.mqh:786; Entry_JumStoch.mqh:43 |
| `_18_DirMode` |1| Explicitly freeze1 for the current faithful identity;2 requires a separate alternate causal/semantic contract | Mode2 mirrors the signal meaning and is not ordinary tuning | Inputs.mqh:792; current semantic owner |
| `_18_MaPeriod` |25| Explicit positive integer; MA method remains hardcoded LWMA on current Home TF | Displacement reference horizon | Inputs.mqh:798; Indicators.mqh:62 |
| `_18_KPeriod` |32| Explicit positive integer | Stochastic calculation horizon | Inputs.mqh:804 |
| `_18_DPeriod` |12| Explicit positive integer for indicator construction; no automatic causal benefit asserted | %D construction parameter; seed reads main buffer, not a %K/%D cross | Inputs.mqh:810; Indicators.mqh:63,180 |
| `_18_Slowing` |12| Explicit positive integer | Smoothing inside stochastic construction | Inputs.mqh:816 |
| `_18_LoLevel` |25| Explicit oscillator-level value in0..100; choose intentional ordered Lo<Up band for faithful interpretation | Mode1 SELL-side threshold; BUY-only reference may not consume it materially | Inputs.mqh:822; Entry_JumStoch.mqh:59 |
| `_18_UpLevel` |75| Explicit oscillator-level value in0..100; no chosen optimizer lattice | Mode1 BUY-side threshold; SELL-only reference may not consume it materially | Inputs.mqh:828; Entry_JumStoch.mqh:58 |
| `_0_ATR_Period` |14| Explicit positive integer; signal ATR TF remains current | Generic chassis reference scale, not LWMA/Stoch period | Inputs.mqh:1169 |
| Home symbol/TF |Unselected| XAUUSD/H1 accepted H01 context; EURUSD/H1 original-source/historical context; AUDUSD/H1 exists as historical A/B context but is not highlighted for new spend | Market/TF identity; no inference of standalone-engine portability | H01, semantic packet, historical Lane-A verdict |

These domains prevent ambiguous input choices; they do not promise valid execution at every possible value. No custom K/D/slowing/threshold value is selected. Freeze every physical key, but distinguish constructed indicators from parameters demonstrably active in the chosen direction; do not optimize an inactive opposite-side threshold.

### 3. Historical and negative context

Accepted Mode1 BUY H01 on **MT5-lane1 / D:\Meta 5**, Model1, XAUUSD/H1: MAIN PF1.19, net+2347.58,1631 trades, native EqDD5.11%,412 baskets; BWD PF0.98, net-154.55,1583 trades, EqDD7.82%,391 baskets. Both windows had36/36 active months. MAIN2023 and BWD2021/2022 were losing years. Participation does not explain away the mixed-window result.

H01 used historical grid ATRx1, fixed0.01, no progression, ATR TPx3 and ATR SLx2. Those are not the generic xx-00 reference's ATRx2/basket-balance-stop semantics. Its result cannot validate the unbuilt B18-00 config, and accepting the listed entry bundle does not authorize importing those historical management controls.

Standing historical status remains **DEAD-OPTIMIZED / NOT-DEPLOY at the chassis-seed port/cell level**; it does not kill the separate standalone JUMSTOCH artifact. The older Lane-A campaign already tested the seed on EURUSD/AUDUSD and H1/H4 with both mode/direction variants and exit changes. No numeric Lane-A metric is reproduced here because its precise install identity was not established in this packet. The qualitative standing verdict is retained through the current canonical semantic/H01 owners, not independently re-adjudicated.

Current H01 routing is **STOP_EXPANSION_NO_DIRECT_CONSUMER**, `NEXT_ADMISSIBLE_QUESTION=NONE_FROM_H01`. “First B18-00 reference” must have a concrete owner/Control Tower consumer distinct from rerunning a closed H01 or the old seed optimization ladder. Cosmetic renaming is not a consumer.

### 4. Choice effects, unknowns and next contract

A can create a distinct generic-reference comparison context only after the new account/chassis/test-control package and its purpose are prospectively frozen. B is a source-provenance context with prior contrary seed evidence, not a recommended rescue. C intentionally defers tester work while the useful consumer is unresolved. All preserve Mode1; none authorizes Mode2, new exits, H02 expansion or a reversal of the standing status.

UNKNOWN: whether the generic reference adds useful new information after prior seed/H01 results; B18-00 behavior under its future full control set; a justified custom Home or entry setting; exact new source/build/set and runtime profile. No evidence uniquely narrows the choice. **OWNER CHOICE REQUIRED**, including whether to defer.

Smallest possible following proposal: **one direction, one Mode1 B18-00 Home/config, two Model1 MAIN+BWD cells**, only if Control Tower first names a genuinely distinct consumer and owner freezes the reference. The old H01 contract remains closed. A BUY+SELL comparison would be at least two configuration pairs under another explicit scope, not a free addition to this pair.

## Proposed smallest common Model1 contract shell

**NON_AUTHORITATIVE_PROPOSAL — no taskboard order, preregistration, set or experiment was created.**

Can do: Codex Primary / explicitly bounded deterministic research executor. Suggested: deterministic source/materialization/preflight and runner; model only for contract design and final interpretation/review.

Objective: produce one exact frozen generic family reference on one explicitly selected Home, without selecting parameters from outcomes. Parent/reference: the family source and ratified xx-00 architecture; H01/BT evidence is context, not falsely relabelled same-config control. If multiple chassis controls differ from H01, do not call the result a one-change causal experiment.

Required before READY:

1. Current canonical BASE plus explicit owner decision record for every family entry field, ATR period and Home. B18 keeps Mode1 and a distinct consumer.
2. Explicit experiment-only account unit/deposit/currency/leverage, lot/progression, TP multiplier, max depth, safety caps, direction/cadence and all other full-surface controls, with requested/effective/ignored/reason distinctions. No B13/B15 exception is inherited.
3. Exact wrapper and transitive source graph, compiled EX5/build receipt, full set SHA/effective fingerprint, tester INI absolute launch and preserved paths/hashes, and literal model/symbol/TF/windows/Optimization/ForwardMode values.
4. Fresh runtime lane claim on one legal install; both cells stay there. No cross-install H01 A/B or outcome ranking. Resolve missing history/symbol economics before launch.
5. Source-bound report-package outputs, four R1 view roles, independent-basket participation evidence where valid, native image capture/missing/refused state, log/year/parser/identity receipts and integrity manifest specified before tester time.

Proposed matrix: exactly MAIN `2023.01.01..2025.12.31` and BWD `2020.01.01..2022.12.31`, Model1 /1 Minute OHLC minimum, Optimization0 and Forward0. These windows are historical research precedent offered for a **new prospective contract**, not silently adopted execution authority. HOLDOUT stays unspent and forbidden.

Mechanical acceptance: both source-bound cells prove the frozen identities and exact requested interval; no stale/reused/truncated/config-mismatched evidence; raw source, set, INI, report, graph-state, log, year split and machine summaries reconcile. A cage firing is a mechanical/path observation, never an invitation to enlarge it. Empty/mechanical/UNKNOWN cells stay explicit; missing native graphs are not reconstructed as native evidence.

Evidence fields: MAIN/BWD and year PF/net/trades/baskets, exact native EqDD field, exposure/lot/depth/active-time diagnostics or source-qualified UNKNOWN, history quality, hard-kill/truncation state, source/build/config/install identity, full requested/effective controls, known unknowns. R1 PF/opportunity/PF-versus-participation/DD views identify exact cell and sample unit.

Decision rule: characterize the frozen reference and stop after two cells; any quantitative pulse/falsifier bar must be declared by the new contract before evidence. This packet introduces no universal trade floor, Grade, PF target or winner rule. A valid losing result cannot be repaired. No automatic optimization, Model4, alternate Home, retuning or expansion follows.

Budget: one bounded mechanical repair maximum, then one targeted recheck. Only a genuinely failed/missing observation may be rerun under its new explicit contract; packaging-only defects consume preserved evidence without Strategy Tester. Repeated failure, moving origin, unratified semantics or missing required provenance freezes the branch. No old-contract reopening or PASS-shopping.

Review/authority: normal package/tooling review and applicable deterministic checks; any source/core/risk behavior change exits this scope and needs the mandated qualified different-family review plus its own contract. No runtime attachment, deployment, trading, production risk/default change, HOLDOUT, Candidate/DEMO/LIVE, KINT/Grade or owner attestation is granted.

## Ready after owner freeze — exact meaning

The three entry implementations have no new core patch identified by the current source/readiness owners. Complete entry/ATR/Home decisions make them ready for **new contract/materialization work**. They are not immediately READY_FOR_MT5: full screen controls, exact build/set identities, preflight, runtime lane and review/authority still need to be bound. B18 additionally needs its distinct consumer; defer remains a valid decision.

Do not spend tester time merely to fill three slots. The three families tie on source prerequisites, not profitability. If only one consumer is justified, freeze and commission only that one pair. No model or owner must rank unseen Bxx-00 performance from old H01 results.

## Validation and provenance limits

This packet read the exact current BASE boot/state/authority/queue owners, VISION, Product Concept, family ratification/readiness, three wrappers, three entry modules, shared indicator/input owners, historical H01/H02 and BT8/BT5/B18 records, negative knowledge directory and the targeted historical B18 verdict. The negative-knowledge directory search produced no direct B11/B12/B18 matching note; canonical family/result owners and the targeted B18 verdict provide the negative context instead. A missing index entry is not absence of negative evidence.

The JSON records raw Git blob SHA256/OIDs and line anchors, family fields/options, all three owner choice sets, historical context with lane labels and the draft contract text. Local analysis checks that every source path/anchor exists, candidate entry values match current source/regression snapshots, all unresolved fields are explicit, Mode2 is excluded from current-reference options, and the two output artifacts alone are staged. These are documentation consistency checks, not tests of strategy performance.

No fresh compile, MT5, optimization, raw outcome reinterpretation, governance edit, set materialization, candidate promotion, risk/default change or owner ratification occurred. Historical report numbers are cited within their own lane and experiment; no cross-install comparison was made. Current data availability, broker clock semantics for a new session, new effective configuration and performance remain unverified until a separately authorized consumer checks them.
