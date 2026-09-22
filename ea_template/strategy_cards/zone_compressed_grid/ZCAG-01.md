# ZCAG-01 — Zone-Compressed Adaptive Grid

## 1. Owner-stated thesis

Instead of buying every adverse grid rung, accumulate the intended grid exposure virtually and deploy it only when a deep pullback reaches a qualified recovery zone. The total position may equal the maximum notional of the conventional ladder, but the account is not exposed during the intermediate descent.

This is a **timing/exposure-shape hypothesis**, not a guarantee of lower risk. Once the compressed order is filled, full exposure is present immediately; a failed support zone can still create severe adverse excursion.

## 2. V0 role

- Direction: LONG only.
- Market role: buy a mean-reverting pullback inside a confirmed higher-timeframe bull regime.
- Stack role: `STACK_SINGLE`; no real DCA adds after entry.
- Recovery/Hedge: OFF in V0.
- Exit owner: strategy-defined next virtual grid level, subject to the shared risk cage.
- Order authority: existing Template execution/risk layers only after a separately accepted implementation.

## 3. Virtual grid state

While flat, define an armed pullback anchor `A` and spacing `S`.
Virtual rung `k` is `L(k) = A - k*S`, k >= 1.
No order is sent when a rung is crossed.

`ReachedLevels` is the deepest consecutive rung reached during the current armed pullback. It is reset on regime invalidation, structure invalidation, expiry, completed trade, or a newly armed anchor.

Prospective defaults for later owner/contract freeze, not current runtime defaults:

- `S = ATR(entry_tf, closed_bar) * StepATRMult`
- `MinCompressedLevels = 3`
- `MaxCompressedLevels = 11`
- `BaseVirtualLot` = comparator's per-rung lot
- `MaxExposureLots = BaseVirtualLot * MaxCompressedLevels`, additionally capped by the existing risk cage

The intended aggregated exposure is `min(BaseVirtualLot * ReachedLevels, MaxExposureLots)`.

## 4. Gate A — bull regime

Required before arming and still required at entry.
The owner specified a higher-timeframe trend system such as Bollinger Band Breakout. V0 does not silently replace this with ADX or EMA.

Implementation contract must freeze:

- regime timeframe;
- Bollinger period/deviation/source;
- exact bullish-state transition;
- exact bullish-state invalidation;
- closed-bar/finality semantics.

Suggested deterministic state for the first executable experiment: bullish state arms only on a closed-bar upper-band breakout and remains active until the frozen invalidation rule fires. This suggestion is not executable until the contract records the exact rule.

## 5. Gate B — mean-reversion stretch

The owner supplied Z-Score or Bollinger %B on H1/H4 and gave `Z <= -3` as an example of a deep downside stretch.

Prospective Z-Score formula:

`Z = (Close[1] - SMA(Close, N)[1]) / StdDev(Close, N)[1]`

The executable contract must freeze `N`, timeframe, price source, equality rule, warmup, zero-std handling, and whether H1 OR H4 is sufficient or both are required.

No current card asserts that -3 is optimal.

## 6. Gate C — structural key level

The user requires Price Structure / Dow Theory support rather than an arbitrary price band. To make this machine-testable, the first proposed provider is a confirmed swing-support zone:

- obtain two confirmed pivot lows using a non-repainting left/right-bar rule;
- require the latest confirmed pivot low to be above the prior confirmed pivot low (higher low);
- create a support zone around the latest confirmed pivot;
- require current price or the deepest virtual rung to intersect that zone;
- invalidate if a closed bar breaks below the frozen support buffer.

Pivot width, zone width, support buffer, confirmation delay and timeframe remain explicit contract fields. A discretionary drawn line is not acceptable evidence for automated testing.

## 7. Entry trigger

All three gates must be true at the same decision point:

1. bull regime active;
2. downside stretch qualifies;
3. structural support qualifies.

Additionally `ReachedLevels >= MinCompressedLevels`.

The final market entry requires a frozen reversal confirmation so the EA does not buy merely because price is extreme. Candidate confirmation for V0 is a closed-bar reclaim of the active rung or support-zone midpoint; bullish engulfing may be tested only as a preregistered alternative, not silently combined after seeing results.

## 8. Position sizing invariant

The central safety invariant is:

`CompressedNotional <= SequentialComparatorMaxNotional`

and the resulting requested lot must still pass broker normalization, max-lot, deposit-load and all existing Template risk cages.

The compressed design must never use the delayed entry as permission to exceed the comparator's maximum notional. If the desired aggregated lot cannot be placed safely, the action is skip/fail-closed rather than split into unplanned rescue orders.

## 9. Exit

Primary V0 target is the **next virtual grid level above the reached rung**:

`TP = L(ReachedLevels - 1)`

For level 1, the contract must define whether TP is the anchor or the mean. No dynamic profit target may be introduced after the run begins.

Shared hard-kill/risk controls remain authoritative. V0 has no post-entry averaging, recovery ladder or hedge.

## 10. Invalidation / reset

Reset without entry when bull regime is lost, key support fails, virtual ladder expires, data is not final/qualified, or any execution/risk gate refuses the action.

After entry, no new virtual levels can increase real exposure. A new pullback cycle starts only after the prior position is fully flat and the arming conditions are re-established.

## 11. Evidence required before performance claims

Report at minimum:

- average entry-price advantage versus the sequential comparator;
- time exposed / time underwater;
- maximum adverse excursion after actual entry;
- maximum drawdown, deposit load and maximum lot;
- missed-trade rate where the sequential grid profited but compressed entry never triggered;
- failed-zone rate after compressed entry;
- trade count and participation;
- net/PF only at a qualified research model under the normal EA_LAB protocol.

Sharpe improvement is a hypothesis only. Delaying exposure can lower path drawdown, but concentration at one deep entry can worsen loss if the zone fails.

## 12. Direct consumer

Prospective `Boss_23_ZoneCompressedGrid` / `LAB_ENTRY_23`, only after a separate executable implementation contract freezes the unresolved parameters and authorizes core seams. No implementation or MT5 authority is granted by this card.
