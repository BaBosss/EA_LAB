# EA_LAB EA Regime Framework

Status: CANONICAL STRATEGY-RESEARCH REGIME OWNER
Authority: research attribution only; no runtime regime gate or risk/default authority.

## Purpose

This file owns the regime vocabulary and anti-leakage procedure used to attribute EA research evidence. It reuses accepted MRIS/MacroGate lessons but does not replace their runtime/governance contracts.

A regime is **market context**, not a verdict. `GOOD` and `BAD` are always strategy-relative.

Do not write `2022 was a bad market`. Write the evidence claim instead, for example: `Boss19-0 performed poorly under the regime states heavily represented in its 2020-2022 BWD window`.

Both **YEAR VIEW** and **REGIME VIEW** are required for serious strategy analysis.

## 1. Research regime dimensions

### A. Macro regime
- `RISK_ON`
- `NEUTRAL`
- `RISK_OFF`
- `STRESS`

### B. Local market structure
- `TREND_UP`
- `TREND_DOWN`
- `RANGE`
- `TRANSITION`

### C. Volatility state
- `LOW`
- `NORMAL`
- `HIGH`
- `EXTREME`

These labels define dimensions, not universal thresholds. Exact local/volatility calibration is a research question. Do not invent universal ADX, ATR, price-level, or percentile thresholds in order to fill a table.## 2. Anti-leakage contract

Required causal order:

```text
historical market/macro data
 -> frozen regime-classifier definition
 -> immutable/as-of regime timeline
 -> EA trades/results
 -> deterministic join of trades to the frozen timeline
 -> aggregate performance by regime
 -> interpretation
```

Forbidden order:

```text
look at losing trades
 -> label those periods "bad regime"
 -> design the classifier around the losses
```

Do not use hindsight absolute price labels such as `Gold > 3000 = bull` unless that rule was prospectively justified, available as-of, and explicitly part of the experiment. Prefer relative/statistical market-state rules with known as-of data.

If percentile-style volatility calibration is proposed, mark it `RESEARCH_DESIGN` until its lookback, as-of semantics and thresholds are frozen and validated.

A classifier used to explain a parent and child must be the same frozen classifier/timeline unless the experiment explicitly studies the classifier itself.

## 3. Attribution unit

Regime analysis must preserve the strategy's real evidence unit. Single-position systems may aggregate by trade; recovery/grid systems may additionally need basket/episode attribution so correlated legs are not misrepresented as independent outcomes.

Missing regime data is `UNAVAILABLE/UNKNOWN`, not silently `NEUTRAL`.

Mechanical/test failures remain separate from regime performance and may not be assigned to a market state as losses.## 4. Required regime-affinity output

Each serious strategy should eventually produce a deterministic `REGIME_AFFINITY.csv` (or schema-equivalent table) with at least:
- `macro_state`;
- `local_state`;
- `vol_state`;
- participation (`trades` and/or baskets/episodes as applicable);
- `PF`;
- `net`;
- `DD`;
- `hard_kill_count`;
- exposure metrics when relevant;
- evidence/classification field.

Year totals and regime totals must reconcile to the same run/evidence identity or explicitly explain why they do not.

Potential future operating-envelope language may distinguish:
- `PREFERRED`;
- `CAUTION`;
- `INVALID`.

Mapping those states to `ENABLE / REDUCE / BLOCK_NEW` is **future runtime strategy work**. This framework does not activate a regime gate, change lot sizing, or modify risk policy.

## 5. Comparison discipline

For Parent vs Child comparison:
1. use the same evidence windows and tester model where the comparison claims causality;
2. use the same frozen regime timeline;
3. report absolute performance and parent delta;
4. show participation so apparent improvement is not just trade starvation;
5. flag concentration where one regime/year dominates the result.

A BWD failure may identify regime incompatibility rather than permanent concept death. That interpretation must remain a hypothesis until broad-home and regime evidence support it.

## 6. Current Boss19 boundary

Boss19 `19-0` has MAIN/BWD evidence on XAUUSD H1 but **does not yet have an accepted broad Symbol x TF regime-affinity map**. The current evidence supports a recent-regime pulse plus poor older-window behavior; it does not support a runtime regime gate yet. Its next research consumer is the broad fixed-config matrix followed by attribution against a frozen classifier.