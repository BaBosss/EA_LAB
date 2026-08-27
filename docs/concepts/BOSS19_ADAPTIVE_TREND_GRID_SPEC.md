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

Each result is passed through `RiskControl_ClampLot`; final broker
normalization remains in `Exec_PlacePending`.

## Exits and reversal policy

Boss19 requires `StackMode == STACK_SINGLE`, `RecoveryMode == REC_NONE`, and
`HedgeMode == HEDGE_OFF` at initialization. It runs hard DD kill, halted state,
and `Exit_SafetyMoneyStop` before strategy work, and bypasses shared
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
and never places a duplicate.

Monte Carlo and block-bootstrap logic are future validation work and are not
part of V0 OnTick behavior.
