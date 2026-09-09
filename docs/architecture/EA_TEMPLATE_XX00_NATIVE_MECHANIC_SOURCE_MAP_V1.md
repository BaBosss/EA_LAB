# EA Template `xx-00` Native-Mechanic Source Map V1

Status: `RECOMMENDATION_ONLY / OWNER_RATIFICATION_REQUIRED / NO IMPLEMENTATION AUTHORITY`

Canonical source ref: `526f88bb9ecba8c181a0e0a48a2bb345effd4aea`.

Direct consumer: owner ratification of B11-B18 family-specific `xx-00` native-mechanic residuals. This document does not instantiate any `Bxx-00`, resolve H01 aliases, alter the generic baseline, or authorize EA/runtime/risk/default changes.

## Decision rule

A mechanic is native only when removing it changes what the strategy hypothesis means. A mechanic is not native merely because it is a current default, appears in a `.set`, improves historical performance, or is available in the chassis.

Classification vocabulary:

- `NONE`: source separates the family entry hypothesis from that mechanic strongly enough that no native exception is recommended.
- `CANDIDATE`: source is mixed or product wording could reasonably include the mechanic; owner must choose.
- `STRONG_NATIVE`: source explicitly couples the mechanic to the hypothesis or strategy-owned execution pipeline; owner ratification is still required.

Evidence and interpretation are kept separate below. No performance result is used to decide native status. B19 is excluded by contract.

## Summary recommendation

| Family | Classification | Recommendation | Confidence | Owner decision needed |
| --- | --- | --- | --- | --- |
| B11 GridTrend | `CANDIDATE` | Lean `NONE`; treat MA direction as the family thesis and shared Stack as chassis unless owner intends “GridTrend” to mean MA+grid as one inseparable product. | MEDIUM | `NONE` vs native Grid/Stack semantics |
| B12 Breakout | `NONE` | Donchian breakout remains the thesis; Stack is shared post-entry management. | HIGH | Ratify `NONE` |
| B13 MeanRev | `NONE` | BB+RSI mean-reversion entry remains the thesis; DCA/grid is shared chassis management. | HIGH | Ratify `NONE` |
| B14 GridLog | `STRONG_NATIVE` | Grid exposure + LOG-power escalation + basket-target ownership are hypothesis-essential candidates. Exact ATR residual and risk settings are not auto-carried. | HIGH | Ratify exact mechanic list and native Exit override |
| B15 ST03 | `NONE` | MACD consecutive-count edge trigger is explicitly “on the chassis”; Stack/Exit remain shared. | HIGH | Ratify `NONE` |
| B16 Kangaroo | `STRONG_NATIVE` | Adverse ATR grid + Kangaroo lot law + Kangaroo-owned basket/overlap exits are inseparable pipeline candidates. Safety cages are not promoted as native mechanics. | HIGH | Ratify exact owned mechanic list |
| B17 Wave5 | `STRONG_NATIVE` | Wave-1 structural invalidation SL is explicitly thesis-defining; SINGLE-only construction while structural levels are active is a required compatibility invariant. Structural TP/exit ownership remains a narrower candidate. | HIGH | Ratify structural SL + SINGLE invariant; decide native target/exit scope |
| B18 JumStoch | `NONE` | Source explicitly says only the seed signal is ported; Grid/DCA/SL/TP/BEP/trailing are chassis. | HIGH | Ratify `NONE` |

## B11 — GridTrend

**Source facts**

- `ea_template/core/entries/Entry_GridTrendMA.mqh:3` explicitly says `Pure signal. Stacking handled by Stack.mqh`.
- `_triage/factory_os/strategy_catalog.py:20` describes additions as `under the shared stack cage`.
- The same strategy card describes the broader product as MA trend + ATR grid, so descriptive product wording is broader than the entry seam.

**Interpretation:** the strongest architectural evidence says the MA direction is separable from Stack. The product name/summary nevertheless makes Grid prominent enough that an owner could intentionally define the family more broadly. Therefore this is `CANDIDATE`, leaning `NONE`, rather than silently treating current Grid behavior as native.

**Owner choice:** `NONE`, or explicitly name the Grid/Stack mechanic and state why MA-only would no longer be the intended B11 hypothesis.

## B12 — Breakout

**Source facts**

- `ea_template/core/entries/Entry_Breakout.mqh:2,11` defines a Donchian breakout signal through the common `Entry_Evaluate()` seam.
- `_triage/factory_os/strategy_catalog.py:29` calls scaling `Shared stack additions with ATR-aware spacing`.

**Interpretation:** removing shared stacking changes position management, not the Donchian breakout condition itself. Recommendation: `NONE`.

## B13 — MeanRev

**Source facts**

- `ea_template/core/entries/Entry_MeanReversion.mqh:2,12` defines BB/RSI mean-reversion through the common entry seam.
- `_triage/factory_os/strategy_catalog.py:38` calls DCA/grid scaling `Shared DCA/grid stack`.

**Interpretation:** the mean-reversion hypothesis remains identifiable without DCA. Recommendation: `NONE`. This does not claim DCA is unimportant to performance; performance is outside this classification.

## B14 — GridLog

**Source facts**

- `_triage/factory_os/hypothesis_b14.py:12` states that B14-H01's pinned configuration is `PART OF THE HYPOTHESIS, NOT A DEFAULT`, and names a GridLog grid with LOG-power escalation, no broker SL, and a basket money target.
- `_triage/factory_os/hypothesis_b14.py:76` pins `LotProg=PROG_LOG_POWER` for H01.
- `_triage/factory_os/strategy_catalog.py:44` summarizes B14 as `ATR grid + log-power lots + basket exits`.
- `ea_template/core/entries/Entry_GridLog.mqh` implements the GridLog distance-arm seed, while shared Stack/MM carry the later grid/progression mechanics.

**Interpretation:** this is the clearest non-owned-pipeline case where source still explicitly couples position mechanics to a registered causal hypothesis. Recommendation: `STRONG_NATIVE` for the *mechanic concepts* `GRID_STACK`, `LOG_POWER_PROGRESSION`, and `BASKET_TARGET_OWNERSHIP`.

This does **not** copy B14-H01 into `B14-00`: exact multiplier, ATR period/source, basket target value, lot factor, `SL_NONE`, account-DD values, or any historical optimized center remain configuration/risk semantics and are not auto-inherited. In particular, “no broker SL” in H01 is not promoted here over the already ratified generic basket-balance protection without a separate owner decision.

**Owner choice:** ratify the exact native mechanic list; separately decide whether the native Exit override is basket-target based. Generic ATR ×2 on `PERIOD_CURRENT` can remain the reference spacing unless owner explicitly requires a B14-native distance law.

## B15 — ST03

**Source facts**

- `_triage/factory_os/strategy_catalog.py:53` calls the strategy `MACD consecutive-count edge trigger on the chassis`.
- `ea_template/core/entries/Entry_ST03.mqh` owns the MACD run-count/rearm signal state, while normal LabCore Stack/Exit paths remain shared.

**Interpretation:** the causal mechanism is the MACD consecutive-count/rearm trigger. Recommendation: `NONE` for Stack/Exit native exceptions.

## B16 — Kangaroo

**Source facts**

- `ea_template/core/LabCore.mqh:493-498` says Kangaroo owns the `ENTIRE pipeline`: first entry, adverse grid adds, every exit, emergency DD, and short-circuits before shared Exit/Stack/Recovery/Hedge/Basket.
- `ea_template/core/entries/Kangaroo.mqh:4` names the adverse-only grid and owned lot behavior.
- `ea_template/core/entries/Kangaroo.mqh:11` declares `ONE EXIT OWNER` for entry 16.
- Shared `MoneyManagement.mqh` also documents that Kangaroo owns its lot law rather than `MM_FirstLot`.

**Interpretation:** `STRONG_NATIVE`. Candidate strategy-native mechanics are `ADVERSE_ATR_GRID`, `KANGAROO_LOT_LAW`, and `KANGAROO_BASKET_OVERLAP_EXIT_PIPELINE`. Removing these while retaining only the RSI seed would materially change the implemented Kangaroo hypothesis.

The hard RiskControl cage is **not** promoted as a native strategy mechanic; safety remains supreme and separately owned. Likewise, this map does not ratify a particular emergency-DD percentage or risk default.

## B17 — Wave5

**Source facts**

- `ea_template/core/LabCore.mqh:383-385` states: `Wave5 is a structural design: its whole thesis is a stop at the wave-1 invalidation level`.
- `ea_template/core/LabCore.mqh:348-372` fail-closes structural mode unless Stack is SINGLE, Recovery is OFF, and Hedge is OFF because additional legs would reuse a structural level validated for a different entry.
- `_triage/factory_os/strategy_catalog.py:75` describes the exit surface as structural SL/TP with trailing and divergence tightening.

**Interpretation:** `STRONG_NATIVE` for `WAVE1_STRUCTURAL_INVALIDATION_SL`. `STACK_SINGLE_WHEN_STRUCTURAL` is a required construction invariant coupled to that native stop, not evidence that SINGLE is universally best. Recovery/Hedge OFF are compatibility constraints under structural mode, not generic product-default decisions.

The structural TP/target side is a narrower `CANDIDATE`: source exposes structural TP plus alternate Trail/RunTrend ownership, so this map does not select one native Exit mode automatically.

**Owner choice:** ratify structural SL + SINGLE invariant; separately choose whether a structural target/exit override belongs in `B17-00`.

## B18 — JumStoch

**Source facts**

- `ea_template/core/entries/Entry_JumStoch.mqh:6-9` says `ONLY the SEED SIGNAL is ported here`; grid/DCA, SL, TP, BEP shift, and trailing come from the Boss V2 chassis, not the standalone.
- `_triage/factory_os/strategy_catalog.py:83` likewise calls scaling the `Shared chassis grid/DCA path after the seed signal`.

**Interpretation:** `NONE` with high confidence. The LWMA/Stochastic direction-mode seed is the family mechanism; chassis position/exit mechanics are explicitly separated.

## Cross-family conclusions

1. **Source ownership is stronger than wrapper defaults.** `StackMode`, `StackConfirm`, Exit and lot defaults show current configuration, not automatically native semantics.
2. **An owned pipeline is strong but not unlimited authority.** B16 ownership supports native-mechanic recommendations, but safety/risk numbers remain separate.
3. **A registered hypothesis can make shared chassis mechanics native.** B14 demonstrates this: the mechanics execute through shared modules, yet the hypothesis owner explicitly couples Grid + LOG-power + basket target.
4. **A safety/compatibility invariant can accompany a native mechanic without becoming a universal default.** B17 SINGLE/Recovery-OFF/Hedge-OFF is required when its structural stop is active.
5. **Historical H01/configuration is evidence, not identity migration.** Nothing here maps H01 to `00`, selects optimized values, or spends HOLDOUT.

## Proposed owner ratification template

```text
B11 = NONE | NATIVE(<exact mechanic + causal reason>)
B12 = NONE | NATIVE(<exact mechanic + causal reason>)
B13 = NONE | NATIVE(<exact mechanic + causal reason>)
B14 = NONE | NATIVE(<exact mechanic list + causal reason>)
B15 = NONE | NATIVE(<exact mechanic + causal reason>)
B16 = NONE | NATIVE(<exact mechanic list + causal reason>)
B17 = NONE | NATIVE(<exact mechanic list + causal reason>)
B18 = NONE | NATIVE(<exact mechanic + causal reason>)

For any family with NATIVE:
- NATIVE_STACK_OVERRIDE = NONE | <mode/distance concept + causal reason>
- NATIVE_EXIT_OVERRIDE = NONE | <exit concept + causal reason>
- ATR_PERIOD_OR_SOURCE = still explicit separately; do not infer it from current defaults/H01.

I ratify these as `xx-00` research/reference family semantics only. They do not authorize implementation, runtime/default changes, optimization, HOLDOUT, Candidate, deployment, trading, or LIVE: YES
```

Until the owner ratifies a row, its family residual remains `SEMANTICS_REQUIRED`. This document itself is not a mapping authority.
