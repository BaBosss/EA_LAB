# Boss19 AdaptiveTrendGrid V0

Boss19 is an entry-owned Boss V2 engine. It uses the shared FastMA/SlowMA
trend (fast above slow = UP, below = DOWN, equal or not ready = neutral) and
honours `TradeDir`. Shared execution and the hard risk cage remain supreme.

## Ladder

Boss19 owns a D1 ATR handle using `_0_ATR_Period` and reads the last closed D1
bar (`shift=1`). The step is `D1_ATR * _9_StepATRmult`; an invalid ATR or step
blocks new orders and has no fixed fallback. While completely flat, and only
after `RiskControl_AcctGateOK` plus `RiskControl_AllowNewOrder`, it arms one
finite ladder with `N = min(RiskControl_MaxLevels(), _9_MaxLevels)`.

Targets are `k * step` from the flat-state reference, for `k=1..N`.

- UP uses BUY orders. Boss19-specific mapping: `_9_PendingMode == 2` means
  BUY LIMIT below ask; every other value, including 0 and 3, means BUY STOP
  above ask.
- DOWN always uses SELL LIMIT above bid.

Every leg is sent through `Exec_PlacePending` and is checked with
`Stack_MarginBudgetOK` first. Retries scan own pending orders near the target;
an exact single match is adopted, while a missing, conflicting, or ambiguous
match refuses placement. The ladder has no persistence format. On restart or
recompile, existing own positions/pending orders are adopted and never placed
on top of. Full broker-confirmed flatness resets the in-memory arm state.

Lots require `FirstLotMode == FIRSTLOT_FIXED` and `LotProg == PROG_NONE`:

- UP: `_41_FixedLot * (1 + max(0, _51_ProgFactor) * (k - 1))`.
- DOWN: `_41_FixedLot / max(1, _52_ProgMult)^(k - 1)`.

DOWN decay floors at broker `SYMBOL_VOLUME_MIN`; the hard `RC_MaxLot`
ceiling is then re-applied, so a ceiling below broker minimum fails closed instead
of sending a larger lot. Each result is normalized to the broker volume step before
margin preflight and placement.

## Exits and reversal policy

Boss19 requires `SLMode == SL_NONE`, `StackMode == STACK_SINGLE`,
`RecoveryMode == REC_NONE`, and `HedgeMode == HEDGE_OFF` at initialization.
Strategy exits are entry-owned; a non-NONE shared SL declaration is refused rather
than silently ignored. It runs hard DD kill, halted state, and
`Exit_SafetyMoneyStop` before strategy work, and bypasses shared
Stack/Recovery/Hedge/Basket/Exit strategy paths.

For UP positions, Boss19 calculates BUY VWAP and closes all when
`bid >= VWAP + D1_ATR * _22_TP_ATRmult`. The close must be broker-confirmed;
there is no per-leg TP. For DOWN positions, each SELL leg closes independently
when `ask <= open_price - current Boss19 step`; unfilled pending levels remain.
No level is re-armed while any position or pending order remains.

When trend reverses, remaining old pending orders are cancelled but filled
positions are not force-closed. Existing positions continue their original
direction's exit logic. An opposite ladder cannot arm until positions and
pending orders are both confirmed absent. Ambiguous broker state fails safe
and never places a duplicate; the ambiguity latch is recomputed each tick so exits
resume after a transient conflict has genuinely cleared. An empty arm whose broker
placements all fail is reset so later retries use a fresh market reference.

Monte Carlo and block-bootstrap logic are future validation work and are not
part of V0 OnTick behavior.

## V0 probe status and source boundary

This is PRE-BASELINE research, exposed as `ea_template/Probe_19_AdaptiveTrendGrid.mq5` rather than claiming a canonical `Boss_19_*` baseline slot. The visible source post supports the adaptive-grid directionality and approximately `0.3 ATR` over a 30-day context; it does not resolve the exact trend detector, UP STOP-vs-LIMIT choice, sizing coefficients, or VWAP ATR exit multiplier.

Two full-surface V0 probes therefore keep the unresolved UP-order choice explicit:

- `ea_template/sets/probe/Boss_19_AdaptiveTrendGrid_V0_STOP.set`
- `ea_template/sets/probe/Boss_19_AdaptiveTrendGrid_V0_LIMIT.set`

Both pin `_0_ATR_Period=30` and `_9_StepATRmult=0.3`. The 20/50 MA trend probe, 5-level cap, UP linear factor `0.5`, DOWN divisor `1.3`, and `_22_TP_ATRmult=1.0` are engineering hypotheses for triage, not source-parity claims. Promotion to a canonical Boss wrapper requires source clarification plus normal validation/independent review.
