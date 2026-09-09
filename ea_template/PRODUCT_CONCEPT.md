# EA Template Product Concept — Owner Intent and Anti-Drift Contract

Status: `OWNER-RATIFIED PRODUCT CONCEPT / NO RUNTIME OR RISK AUTHORITY`
Captured from owner discussions + preserved historical EA_LAB concept material on 2026-09-08.
Base canonical ref at consolidation: `8eb953d36f8e92b20251e50dafab90c6e5d7f126`.

## 1. Why this file exists

EA Template is a primary EA_LAB product, not a side utility and not one strategy EA.
The project has repeatedly drifted because the owner concept was spread across chat, old handoffs, `_triage/chatgpt_convs`, code comments, and stale README text.
This file is the durable detailed owner of EA Template product intent. It is canonical only when these bytes are present on pushed `origin/master`.

`VISION.md` remains the short project/factory philosophy. `PROJECT_STATE.md` remains status. `AGENTS.md` remains permissions. `DESIGN_V2.md` and source code describe implementation. This file owns what EA Template is supposed to be.

Anti-drift rule: if current implementation, generated UX, or a proposed change conflicts with this product concept, do not silently redefine the concept to match the code. Classify the mismatch as `DRIFT`, preserve evidence, and bring the semantic decision back to the owner/Control Tower.

This file does not authorize deployment, runtime attachment, LIVE, real money, or new numeric risk defaults. Research reference values below are not runtime authority.

## 2. Product identity

EA Template is a reusable EA factory/chassis. The stable/shared mechanics are reused; the main source of new EA families is the entry mechanism.

```text
SHARED CHASSIS
  MM / lot sizing / lot progression
  Position Engine / stack / grid / DCA / pyramid
  Exit / SL / basket
  Recovery / Hedge
  Risk / execution / persistence / diagnostics
  Filters / regime / macro / news / spread
        x
ENTRY MECHANISM
        x
SYMBOL / TIMEFRAME / CONFIG
        =
TRACEABLE EA FAMILY / VARIANT / EVIDENCE LINEAGE
```
## 3. Identity model

### 3.1 Boss family

Boss/EA family identity is primarily the entry hypothesis or another genuinely different causal mechanism.
Examples: Support/Resistance entry, Bollinger SD entry, breakout, mean reversion, wick displacement, pullback.

### 3.2 Child variant

Create a child when one logical causal mechanism changes, for example:
- add/remove a MACD filter;
- change stack confirmation from distance-only to Price Action;
- change lot law from additive to multiplier/martingale;
- change exit architecture from fixed target to run-trend.

Do not create a new child merely because a numeric value changes inside the same mechanism.

### 3.3 Home / configuration

Symbol, timeframe, optimized numeric center, broker profile, and account profile are configuration/evidence identity, not automatically a new EA family.

```text
24-00 = entry reference architecture
24-01 = one causal child
XAUUSD/H1 = home/cell
Config A = parameter center
Build hash + set hash = exact executable evidence identity
```

One variant = one logical change remains the research rule. Architecture search can overfit too; having many modes in the library is not permission to select the best result from every permutation on one dataset.
## 4. Original concept -> current implementation -> gap/drift map

| Layer | Owner/original concept | Current implementation at base ref | Interpretation |
|---|---|---|---|
| Product | One reusable EA factory; shared mechanics, replaceable entry | Boss V2 shared chassis exists | `ALIGNED`, but owner UX/docs drifted |
| Entry | Main family differentiator; new entry mechanisms added continuously | Per-entry Boss wrappers and entry modules exist | `ALIGNED` |
| Filters | Optional/shared; add as child experiments | Trend/regime/filter pieces exist; not one clean owner surface | `PARTIAL` |
| Position Engine | Dropdown; Grid is the primary owner preference, while Single/DCA/Pyramid remain selectable | `Single / GridTrend / GridAgainst / Pyramid` | `ALIGNED` |
| Grid distance | ATR-first; timeframe/period/multiplier configurable; fixed/floor options allowed | ATR/fixed step + MinPips floor exist | `ALIGNED/PARTIAL UX` |
| Stack confirmation | Distance, signal valid, retrigger, Price Action; richer PA may grow later | Distance / SignalValid / Retrigger / close-beyond-level / Engulfing | `ALIGNED` |
| First lot | Fixed and balance-scaled are primary owner modes; risk%-with-SL also supported | Fixed / Risk% / Balance-scaled | `ALIGNED` |
| Lot progression | Fixed, additive-linear, multiplier/martingale and other laws should be library options | None / Linear-factor / Multiplier / Plus / Log / LogPower / Fibonacci | `SEMANTIC DRIFT RISK`: owner additive 0.10->0.11 maps to current `PROG_PLUS`, not current `PROG_LINEAR` |
| Recovery | Independent same-direction loss-management engine with multiple trigger families | NONE/LIGHT/ADAPTIVE/AGGRESSIVE; ATR adverse trigger + DD-aware sizing | `PARTIAL`: original trigger library is wider |
| Hedge | Independent exposure-reduction engine; multiple modes/triggers | OFF / LOCK with DD trigger and release | `PARTIAL`: original design is wider |
| Exit | Shared dropdown; simple reference plus adaptive/structural alternatives | Fixed TP / ATR TP / Trail / RunTrend / Structural Target | `ALIGNED` |
| SL | Shared dropdown including structural and volatility methods | None / Fixed / Money / ATR / Donchian / S-R / StdDev | `ALIGNED`; owner 10% meaning still unresolved |
| Basket | Shared weighted/basket management and coordinated exits | Multiple basket/TP/exit paths exist | `PARTIAL/OWNERSHIP NEEDS CLARITY` |
| News | Realtime guard plus historical A/B impact layer | NewsGuard/MacroGate realtime path exists; historical macro selector foundation exists | `MISSING/PARTIAL` for historical EA replay + response modes |
| Spread | Execution-quality guard with absolute/relative/rolling modes | Execution controls exist, but requested spread experiment layer is not frozen as product surface | `MISSING/PARTIAL` |
| Risk | Always-on supreme authority; caps all optional engines | RiskControl is supreme cage | `ALIGNED` |
| Operator UX | Owner should see only meaningful active choices and effective config | Full engineering input surface remains large/stale in places | `DRIFTED/PARTIAL` |
| Monitoring | One simple owner health surface + exception delivery | Monitoring pipeline exists but owner delivery/trust remains degraded | Separate product integration concern |
## 5. `xx-00` Entry Reference concept

`xx-00` is the reference configuration for one entry family. It is a control for research, not a claim that the values are optimal and not a LIVE risk preset.

Owner-ratified research reference baseline as of 2026-09-09:
- research account profile: `10,000 cent`;
- entry: owned by that Boss family;
- extra filters: OFF unless part of the native entry definition;
- Position Engine: generic reference = `GRID_AGAINST / DCA`; other modes remain available and a family-native mode may override explicitly;
- grid distance: signal ATR × `2.0`; initial ATR timeframe = `PERIOD_CURRENT` (the timeframe being tested); ATR period/source remains an explicit family/reference field;
- StackConfirm generic reference: `DISTANCE`; stronger confirmation modes remain prospective alternatives, not after-the-fact DD retunes;
- Exit generic reference: `ATR_BASED`; family-native Exit may override explicitly;
- SL reference: `BASKET_BALANCE_STOP`, using `10%` of current account balance as the EA-owned basket loss/drawdown reference amount; close that EA-owned basket on breach;
- first lot primary reference: Fixed `0.10`;
- primary alternate sizing: Balance-scaled lot;
- preferred lot progression behavior: additive `+0.01` per level, e.g. `0.10 -> 0.11 -> 0.12 -> 0.13`;
- Recovery: OFF for the clean reference unless recovery is native to the strategy definition;
- Hedge: OFF for the clean reference;
- News response: OFF in raw reference;
- Spread Guard: OFF in raw reference.

Per-family semantics that must NOT be silently inferred:
- exact native-mechanic exceptions and why removing each mechanic would change the strategy hypothesis;
- any family-specific ATR period/source, Stack-mode/confirmation override, or native Exit override;
- structural S/R SL remains a separate supported concept and is not implied by the generic basket-balance stop.

Native-mechanic exception: if removing Grid/Stack/other mechanics would change what the entry hypothesis actually means, that mechanic may be part of `xx-00`; document it explicitly rather than pretending every reference must be naked/single-order.
## 6. Position Engine / Stack

Position Engine answers: after the entry signal, how are positions added or staged?

Product library:
- `SINGLE` — one order per signal/basket;
- `GRID_TREND` — add in the favorable/trend-extension direction;
- `GRID_AGAINST / DCA` — add against price/average down;
- `PYRAMID` — pending ladder / scale structure.

Grid distance and add confirmation are separate axes. Example:

```text
Position Engine = GRID
Distance = 1 ATR
Confirm = Price Action
=> reaching 1 ATR is necessary but not sufficient; PA must confirm before the add.
```

Stack confirmation library includes:
- distance only;
- original signal still valid;
- fresh retrigger;
- bar close beyond trigger level;
- Price Action such as engulfing.

The Product Concept should preserve these axes separately so `1 ATR + Price Action` is representable without inventing a new Position Engine.

## 7. Money Management / Sizing

First-lot sizing and lot progression are separate axes.

First-lot library:
- Fixed lot;
- Risk % with valid SL distance and instrument economics;
- Balance-scaled / lot-per-balance anchor.

Owner preference: Fixed `0.10` and Balance-scaled are the two primary working modes for the factory reference/research workflow. Risk%-with-SL remains a supported mode, not the same thing as balance scaling.
Lot-progression library currently includes:
- fixed/none;
- proportional linear-factor;
- multiplier/martingale;
- additive plus;
- logarithmic;
- log-power;
- Fibonacci.

Important semantic correction: the owner-described progression `0.10 -> 0.11 -> 0.12 -> 0.13` is additive. In current source that behavior belongs to `PROG_PLUS` (`firstLot + plus * level`), while `PROG_LINEAR` is proportional (`firstLot * (1 + factor * level)`). Product/UI naming must make this difference obvious; do not relabel one as the other silently.

Balance-scaled first lot may combine with any allowed progression, subject to the shared risk cage and broker normalization.

## 8. Recovery Engine

Recovery is not Grid and is not Hedge.

Recovery objective:
- act because an existing basket is losing;
- improve average entry / reduce break-even distance;
- coordinate an escape/basket exit;
- accept that recovery normally increases same-direction exposure.

Original reusable concept modes:
- `NONE`;
- `SOFT` — modest/simple recovery;
- `ADAPTIVE` — market/DD/volatility-aware recovery;
- `CONTROLLED` — explicitly capped multi-step recovery.

Current implementation uses `NONE / LIGHT / ADAPTIVE / AGGRESSIVE`; therefore naming and semantics require a conscious mapping rather than assuming the old and current mode labels are identical.

Current implementation already enforces a strong distinction: Recovery fires only while the basket is red and after adverse ATR travel, while Stack adds are governed by distance/confirmation regardless of basket P&L.
Original Recovery trigger library to preserve as product intent:
- Distance: fixed points, ATR, ATR multiplier;
- Candle/Price Action: engulfing, pin bar, strong close;
- Trend: original trend logic still valid, EMA alignment, trend score;
- Structure: BOS, CHoCH, higher-low/lower-high style confirmation;
- Drawdown: floating DD %, cycle/basket DD %;
- Volatility: ATR expansion/contraction.

Triggers should be modular. Multiple triggers may eventually combine using explicit AND/OR/weighted semantics, but combinations must be prospective and testable; no hidden fallback.

Recovery safety/product requirements:
- maximum recovery steps/exposure must be capped;
- lot escalation must remain below shared Risk Engine ceilings;
- recovery distance/cooldown and chain ownership must be explicit;
- recovery must fail closed when sizing or required market data cannot be derived;
- Recovery must never assume Hedge is active;
- an active higher-authority risk/hedge state may block Recovery.

Old transcript numeric 'recommended defaults' are historical design notes only. They are not imported here as current risk defaults.

## 9. Hedge Engine

Hedge is an independent defensive exposure-management engine.

Objective:
- reduce directional/net exposure;
- reduce or stabilize drawdown;
- survive an adverse move;
- manage temporary opposite-direction exposure and unwind it explicitly.

Original product-mode library:
- `OFF`;
- `EMERGENCY`;
- `PARTIAL`;
- `BREAKOUT`;
- `TREND`;
- `RECOVERY`.

Current implementation is narrower: `OFF / LOCK`, triggered by DD and sized from net exposure, with release on DD recovery. This is a valid subset, not the full original product concept.
Original Hedge trigger library to preserve as product intent:
- emergency DD hedge;
- partial-exposure hedge;
- breakout-against-position hedge;
- trend-reversal hedge;
- candle/Price Action hedge;
- structure hedge;
- portfolio/correlation hedge.

Hedge safety/product requirements:
- cap hedge layers, total hedge exposure, and hedge ratio;
- explicit cooldown/timeout/unwind behavior;
- no recursive hedge-on-hedge;
- hedge positions must be uniquely attributable;
- higher-authority Risk Engine can flatten/halt;
- Hedge must never assume Recovery is active.

## 10. Authority hierarchy

The original reusable platform concept is preserved:

```text
RISK ENGINE
   > HEDGE ENGINE
   > RECOVERY ENGINE
   > SIGNAL / ENTRY ENGINE
```

Reasoning:
- Risk is the survival cage and may block all lower layers;
- Hedge reduces exposure, so Recovery must not silently increase exposure against an active hedge/risk decision;
- Recovery changes basket structure, so ordinary new signals must respect recovery state;
- Signal/Entry finds opportunities but cannot override management/safety authority.

This hierarchy defines product direction only. Numeric thresholds remain owned by approved risk/config contracts, not this file.

## 11. Exit / SL / Basket

Exit is a shared library and may include fixed target, ATR target, trailing, run-trend, structural target, partial/basket logic, and future validated methods.
SL is a separate shared library: none where explicitly allowed, fixed, money/basket, ATR, Donchian, S/R structure, StdDev or other reviewed structural methods.
Basket Engine owns weighted-average/break-even and coordinated basket exits where the selected strategy requires them.
One behavior should have one owner; duplicate TP/SL/basket controls with unclear precedence are product drift, not flexibility.
## 12. Filters / News / Spread

Filters are optional layers added after the entry hypothesis is defined. They should not redefine the Boss family unless the causal mechanism genuinely changes.

Examples already present or discussed across EA_LAB include trend/regime filters, MACD, Bollinger, session, volatility, MacroGate/NewsGuard and execution-quality filters.

### News response product surface

Unified dropdown concept:
- `OFF`;
- `BLOCK_ENTRY` — no new entries in the news window, existing positions keep normal management;
- `FLATTEN` — close relevant exposure per the selected policy;
- `BLOCK_ENTRY_AND_FLATTEN`.

Historical News Impact must become a reusable evidence layer, not a per-EA copied dataset. Target evidence joins historical calendar timestamps to EA trades/baskets and compares BASE vs selected news response over a qualified 1–2 year package (owner preference: start with about 2 years where source coverage allows).

Required report deltas include DD, net profit, PF, trade count, worst basket, missed profit and avoided loss. Do not claim news filtering is beneficial from DD reduction alone.

Future Phase-2 responses may include reduced lot during news, wider grid, or other adaptive exposure controls. Those alter management/risk semantics and require separate prospective contracts.

### Spread / execution-quality guard

Product options discussed:
- OFF;
- absolute max spread;
- relative spread spike vs normal;
- M1 rolling spread condition;
- M5 rolling spread condition.

Historical spread effects require trustworthy bid/ask or tick/spread data. Do not reconstruct a spread history from OHLC alone. Missing evidence is `UNKNOWN/NOT_TESTABLE`.
## 13. Risk, feature gating, and optimizer discipline

Risk Engine is always on. Recovery, Hedge, News response and similar optional modules are feature-gated.
When a module is OFF:
- its inactive parameters must not affect runtime behavior;
- effective config must say they are ignored/locked and why;
- optimizer generation should exclude inactive controls rather than search meaningless combinations.

Capability completeness is not overfit by itself. The factory may support many valid architectures.
Selection overfit appears when many architectures/parameters are searched on the same evidence and the best observed spike is promoted.
Therefore:
- change one logical mechanism at a time where causal attribution matters;
- preregister optimization semantics/ranges before search;
- use regions/plateaus/neighbours rather than Top-1 PF;
- lock before BWD;
- BWD is falsification/robustness, not another optimization surface;
- Model4 MAIN+BWD same installation lineage remains mandatory before Candidate eligibility;
- HOLDOUT remains late/protected.

## 14. Owner-facing product UX

The owner should not need to reason from 100+ raw MQL inputs.
Preferred view:

```text
Boss family / Entry
  -> Variant / changed mechanism
  -> Effective modules
  -> Home: Symbol / TF
  -> Requested -> Effective -> Ignored/Locked -> Reason
  -> Exact build/set/config identity
  -> Evidence / progress / blocker / next action
```

Raw MT5 inputs and parameter IDs remain available as advanced/research implementation detail.
The UI must not create a second configuration truth; it must render the exact effective config produced by the canonical factory/preset path.

## 15. Durable-memory / owner routing

After canonical integration, discoverability should be:
- `START_HERE.md` routes every Template/core worker to `VISION.md` + this file before implementation docs;
- `VISION.md` owns the short factory philosophy and links here for detail;
- this file owns detailed EA Template product intent and anti-drift semantics;
- `ea_template/README.md` is the human usage entrypoint and links here;
- `ea_template/DESIGN_V2.md` owns implementation architecture, not owner intent;
- `PROJECT_STATE.md` owns current status only;
- `AGENTS.md` owns authority/permissions only.

Do not duplicate the full concept into every file. Route to one detailed owner so future edits cannot diverge silently.
## 16. Preserved source anchors for recovery of intent

This consolidation was grounded in, among others:
- `VISION.md` — owner factory philosophy;
- `_triage/chatgpt_convs/015___ EA Recovery Hedge Engine.txt` — preserved original universal Recovery/Hedge discussion;
- `_triage/chatgpt_convs/024_CLAUDE_EA_ARCHITECTURE_DOCS.txt` — preserved modular EA Template/platform architecture discussion;
- `ea_template/DESIGN_V2.md`;
- `ea_template/core/Inputs.mqh`;
- `ea_template/core/Stack.mqh`;
- `ea_template/core/MoneyManagement.mqh`;
- `ea_template/core/Recovery.mqh`;
- `ea_template/core/Hedge.mqh`;
- `ea_template/core/RiskControl.mqh`;
- `ea_template/core/PriceAction.mqh`;
- `docs/handoffs/EA_LAB_WORKFLOW_CONCEPT_DISCUSSION_20260907.md` on the local concept branch.

Historical chat/design artifacts are evidence of earlier intent, not authority by themselves. Where they conflict with a later explicit owner decision, the later owner decision wins after canonical intake.

## 17. Immediate product gaps to take to Control Tower

1. Make this concept discoverable from `START_HERE.md` and the Template README.
2. Reconcile current UI/input names with product semantics; specifically additive lot progression must not be mislabeled as current proportional `PROG_LINEAR`.
3. Build an implementation coverage table: `IMPLEMENTED | PARTIAL | MISSING | DRIFTED | OBSOLETE` with exact code owners/tests.
4. Restore/complete the original Recovery trigger library only through bounded child contracts; do not rewrite current working Recovery wholesale.
5. Expand Hedge beyond DD-lock only when there is a direct consumer and reviewed risk semantics.
6. Add News historical-impact and spread-evidence layers without creating duplicate data/config truth.
7. Prove one real Boss family end-to-end from Entry -> shared chassis -> config -> MT5 evidence -> report -> owner view before calling the factory owner-easy.

Any runtime/default/risk change remains separately gated. Product completeness is a roadmap; it is not permission to activate every module simultaneously.
