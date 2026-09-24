# ZCAG Boss23 shared-execution Phase A contract

Date: 2026-09-22
Lane: `ct-zcag-boss23-shared-exec-a-20260922`
Exact author base: `e789bbbfa55bebefa2433cfd25695ce10b64a223`

## Authority ceiling

This delivery is Phase A only. Phase A remains UNWIRED.

It adds a pure ZCAG transactional kernel, deterministic test targets, and an
additive prepared-open API in the existing execution choke point. It does not
register `LAB_ENTRY_23`, add or change an input, alter a wrapper, modify
`LabCore.mqh`, generate a surface, deploy an EA, start a terminal, run Strategy
Tester, perform research, select parameters, promote a candidate, or authorize
DEMO/LIVE trading.

Phase B depends on an explicit release of PARAM_LINKAGE ownership followed by a
new bounded contract. Phase A does not reserve, imply, or bypass that release.

The rejected `13ec887db2a2586ec4e332fb7345a5f15613ec34` source is predecessor
reference only. Its consumed repair budget is not reset. This contract does not
admit that head or its defects.

## Frozen strategy thesis

The future consumer remains a long-only, closed/final-bar virtual compressed
grid. The ladder is virtual while flat; no physical averaging orders or pending
ladder are introduced. Compression depth, higher-low support, mean-reversion
z-score, and reclaim remain the entry thesis. Phase A invents no new trading
condition and submits no order.

## Transactional state contract

Regime processing validates the candidate closed-bar timestamp, close, middle
band, and upper band before changing regime state, resetting a ladder, or
committing the timestamp. A transient read failure leaves every field unchanged,
allowing the same closed bar to retry. A valid retry commits exactly once.

Decision processing validates its entire local snapshot before ladder depth,
expiry age, support invalidation, entry readiness, or decision timestamp may
change. The snapshot includes timestamp, H/L/C1/C2, step ATR, structure ATR,
z-score history, contiguous structure history, and a positive monotonically
increasing closed-decision-bar ordinal. Invalid data leaves state unchanged;
the same decision bar may retry and then commit exactly once.

A snapshot whose timestamp is the same as or older than the last committed
timestamp is already consumed and cannot rewind state, even if its payload is
otherwise valid. A strictly newer valid decision snapshot must also advance
the ordinal. The kernel computes elapsed decision bars only from the ordinal
difference; it never estimates bars from timestamp seconds, session gaps, or
weekends. The difference must be positive and representable by the integer
expiry counter. A transient unreadable snapshot commits neither timestamp nor
ordinal, so the next valid snapshot's ordinal difference includes every missed
closed decision bar. Expiry is applied before entry readiness.

Phase B's future caller must source this ordinal from a deterministic closed-bar
sequence for the decision series, initialize runtime ordinal zero before the
first commit, preserve it with runtime state, and pass the exact current closed
bar's monotonically increasing identity on every retry. Phase A remains
unwired and does not implement or select that caller data source.

Structure history is tri-state:

- `ZCAG_INVALID_HISTORY`: a required bar is missing, unreadable, nonfinite, or
  nonpositive.
- `ZCAG_VALID_NON_PIVOT`: all required bars are valid but the candidate loses a
  strict-low comparison.
- `ZCAG_VALID_PIVOT`: all required bars are valid and the causal pivot passes.

The search never substitutes older pivots across a recent history gap.

Entry readiness preserves the frozen predecessor conjunction. Reached depth
must be at least `min_levels`; the latest pivot must be a higher low; the
closed low and close must qualify against the support zone; the z-score must
qualify; and the close must reclaim the deepest reached rung. The support zone
requires:

`closedLow <= pivot + structureATR * zoneWidth`

`closedClose >= pivot - structureATR * zoneWidth`

Pre-entry structure invalidation remains `pivot - structureATR * breakATRMult`.

## Shared execution contract

Legacy `Exec_Open` retains its exact signature, body, and behavior. Existing
callers are not routed through the new API.

The additive transaction is:

1. `Exec_PrepareOpen` reads one MacroGate block/multiplier identity snapshot.
2. It derives the effective reduce-only multiplier and validates broker minimum,
   maximum, and step.
3. It applies the multiplier, hard cap, broker cap, and step normalization once,
   producing `final_checked_lot`.
4. The future Phase B caller must pass that exact value to heat and projected
   margin checks.
5. `Exec_SubmitPreparedOpen` rechecks NewsGuard, spread, and the complete
   MacroGate identity immediately before submission.
6. A changed block existence/value/time, multiplier existence/value/time,
   effective block state, or effective multiplier state
   refuses submission. It never silently resizes.
7. Submission uses the prepared lot directly. It does not call
   `Exec_MacroLotMult` or `Exec_NormalizeLot`.
8. A live `Buy` or `Sell` is called exactly once. The transport boolean alone
   is insufficient: success additionally requires `TRADE_RETCODE_DONE`, a
   nonzero result deal, and finite positive result volume equal to the checked
   submission lot within floating-point tolerance derived from the broker
   volume step. `DONE_PARTIAL`, `PLACED`, requote, timeout, rejection, missing
   deal, or different volume all return false without retry or resize.

DryRun remains an intent-only true result and is represented separately from a
broker-confirmed completed market execution in the pure result assessor.

The enforced identity is:

`heat_checked_lot == margin_checked_lot == broker_submitted_lot`

Finite MacroGate multiplier values outside `(0,1)` retain the established
no-op policy and remain part of the identity snapshot. If the multiplier GV
exists, a nonfinite raw value fails closed even when that GV is stale. A
nonfinite identity, invalid broker volume property, invalid prepared state,
mismatched checked lot, active block, changed raw snapshot, or changed effective
state fails closed. No multiplier can upscale lot.

## Phase A evidence

`ZoneCompressedGrid_Transactional_Test.mq5` covers Bollinger, decision OHLC,
both ATR, z-history, and structure-history transient failures; unchanged state;
same-bar retry; exactly-once commit; and INVALID_HISTORY versus
VALID_NON_PIVOT. It also proves that below-minimum compression depth and support
zone failure block readiness, while a fully qualifying snapshot sets
`entry_ready=true` and still commits exactly once. Deterministic target and stop
arithmetic retain the predecessor semantics. Acceptance correction coverage
adds regime bull-to-bear stale replay, decision T1-to-T3 stale replay, a missed
bar followed by ordinal-gap expiry, invalid elapsed identities, and same-bar
zero-aging retry.

`Execution_CheckedLot_Test.mq5` covers absent, reduce, finite invalid/no-op, and
nonfinite multipliers; changed multiplier and block identities; invalid
prepared state; invalid volume properties; and the final checked-lot identity.
It separately proves rejection when raw MacroGate existence/value/time remains
identical but either effective multiplier or effective block state changes.
The acceptance correction matrix distinguishes DryRun intent from completed
execution and covers DONE, DONE_PARTIAL, PLACED, rejection, timeout, requote,
transport failure, missing deal, mismatched volume, nonfinite volume, and
invalid volume-step evidence. The source cage also injects caller-inventory
failure and requires it to throw before caller-preservation PASS.

The PowerShell cages are deterministic/offline source guards with optional
isolated compile-only operation. They never run Strategy Tester or make a
performance claim. Acceptance still requires `scripts/tpl_regression.ps1`,
compile evidence, normal hooks, a clean exact-head packet, and separate
read-only GPT Scrutiny.
