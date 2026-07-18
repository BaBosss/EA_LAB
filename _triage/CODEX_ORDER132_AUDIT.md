# Independent QA audit — commit `0dcf60e2`

Scope audited: the complete `git show 0dcf60e2` change plus the current call paths in `ea_template/core/*.mqh` and `ea_template/tests/*.mq5`. The scoped working-tree files are byte-identical to the commit (`git diff 0dcf60e2 -- ea_template/core ea_template/tests` is empty). No compiler, Strategy Tester, or trading platform was run.

Platform semantics used to refute false positives: MT5 terminal GlobalVariable names are limited to 63 characters and expire four weeks after their last use ([GlobalVariableSet](https://www.mql5.com/en/docs/globals/globalvariableset)); `CTrade::PositionClosePartial` returning `true` proves only the basic structure check, not server execution ([PositionClosePartial](https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradepositionclosepartial)); pending-order helpers have the same contract and require `ResultRetcode()` plus `ResultOrder()` checks ([BuyStop](https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradebuystop)). `Exec_Init()` does set synchronous mode, but that does not change these documented return contracts.

## `ea_template/core/Persist.mqh`

### Finding P1 — the scoped key is not bounded to MT5's 63-character limit

1. Severity: SEV1 (money/state-loss risk)

2. File:line evidence:

   `ea_template/core/Persist.mqh:30-37`

   ```cpp
   return StringFormat("%04x_%I64d_%s_%I64d",
                       (int)(h & 0xFFFF),
                       AccountInfoInteger(ACCOUNT_LOGIN),
                       _Symbol,
                       _0_Magic);
   }

   string Persist_Key(const string name) { return "Boss2_" + Persist_ScopeId() + "_" + name; }
   ```

   `ea_template/core/Persist.mqh:44-49`

   ```cpp
   string key = Persist_Key(name);
   ResetLastError();
   if(GlobalVariableSet(key, value) == 0)
   {
      PrintFormat("[PERSIST] ERROR: GlobalVariableSet failed for %s (err %d)", key, GetLastError());
      return false;
   }
   ```

3. Concrete failure scenario:

   1. A broker uses a suffixed symbol and a long account login, and the operator supplies a long but legal `long` magic number.
   2. `Boss2_` + server hash + login + symbol + magic + `rc_state`/`rc_peak_eq` exceeds 63 characters.
   3. The kill closes positions, but both scoped state writes fail.
   4. After restart, `RiskControl_Init()` cannot restore `KILL_PENDING` or `HALTED`; the EA returns as RUNNING. `Persist_Test.mq5:36` tests only the tester's current short key and does not bound all legal inputs.

4. Suggested fix:

   Hash the complete canonical tuple `(server, login, symbol, magic)` into a fixed-length, collision-resistant identifier, reserve space for the longest state name, and enforce `StringLen(Persist_Key(name)) <= 63` during `OnInit`. On failure, reject live/demo initialization fail-closed.

### Finding P2 — the 16-bit server hash permits cross-server state collisions

1. Severity: SEV2 (real bug, bounded impact)

2. File:line evidence:

   `ea_template/core/Persist.mqh:26-34`

   ```cpp
   string srv = AccountInfoString(ACCOUNT_SERVER);
   uint h = 5381;
   for(int i = 0; i < StringLen(srv); i++)
      h = ((h << 5) + h) + (uint)StringGetCharacter(srv, i);
   return StringFormat("%04x_%I64d_%s_%I64d",
                       (int)(h & 0xFFFF),
                       AccountInfoInteger(ACCOUNT_LOGIN),
                       _Symbol,
                       _0_Magic);
   ```

3. Concrete failure scenario:

   1. Two different server names collide in the 65,536-value `h & 0xFFFF` space.
   2. Those servers issue the same numeric login, and the same symbol and magic are used.
   3. Both instances generate the same `Boss2_*` keys.
   4. A halt, kill-pending state, or high-water mark from server A is restored on server B.

4. Suggested fix:

   Use a substantially wider hash over the full scope tuple, not a 16-bit hash of only the server. A fixed-length 128-bit digest (or two independently mixed 64-bit values) leaves enough room for the state-name suffix while making accidental aliasing operationally negligible.

### Finding P3 — automatic legacy migration is destructive and cannot establish which account/symbol owns the state

1. Severity: SEV1 (money/state-loss risk)

2. File:line evidence:

   `ea_template/core/Persist.mqh:98-111`

   ```cpp
   bool Persist_MigrateLegacy(const string name)
   {
      if(Persist_Has(name)) return false;         // already scoped - scoped value wins
      if(!Persist_HasLegacy(name)) return false;  // nothing to migrate
      double v = Persist_GetLegacy(name, 0.0);
      if(DryRun)
      {
         PrintFormat("[PERSIST] DryRun: would migrate %s -> %s (%.2f) - skipped (no writes in DryRun)",
                     Persist_LegacyKey(name), Persist_Key(name), v);
         return false;
      }
      if(!Persist_Set(name, v)) return false;     // keep legacy on failed write
      Persist_DelLegacy(name);
      PrintFormat("[PERSIST] migrated legacy %s -> %s (%.2f)", Persist_LegacyKey(name), Persist_Key(name), v);
      return true;
   }
   ```

   `ea_template/core/RiskControl.mqh:121-145`

   ```cpp
   Persist_MigrateLegacy("rc_peak_eq");
   ...
   if(Persist_GetLegacy("rc_kill_pending", 0.0) > 0.5)   st = RC_STATE_KILL_PENDING;
   else if(Persist_GetLegacy("rc_halted", 0.0) > 0.5)    st = RC_STATE_HALTED;
   ...
   Persist_DelLegacy("rc_kill_pending");
   Persist_DelLegacy("rc_halted");
   ```

3. Concrete failure scenario:

   1. A terminal contains `Boss_990208_rc_kill_pending=1` created on account A, or the same legacy magic was reused on two symbols.
   2. The first post-132 `OnInit()` occurs on account B/symbol B before the intended owner is upgraded.
   3. B copies the magic-only value into B's scoped key, deletes the only legacy copy, and resumes `Exec_CloseAll()` against B's matching positions.
   4. The true owner later initializes with neither its halt/kill state nor its peak. The migration document warns the operator, but there is no code guard or ownership proof.

4. Suggested fix:

   Do not auto-claim ambiguous magic-only live state. Require an explicit migration manifest/operator confirmation that names the destination server/login/symbol/magic, or quarantine ambiguous legacy state and fail initialization closed until attribution is supplied. For multi-symbol reuse, fan out only from an explicit inventory rather than first-initializer-wins.

### Finding P4 — legacy deletion is unchecked, and stale keys are never cleaned once a scoped key exists

1. Severity: SEV2 (real bug, bounded impact)

2. File:line evidence:

   `ea_template/core/Persist.mqh:85-88`

   ```cpp
   void Persist_DelLegacy(const string name)
   {
      string key = Persist_LegacyKey(name);
      if(GlobalVariableCheck(key)) GlobalVariableDel(key);
   }
   ```

   `ea_template/core/Persist.mqh:100-111`

   ```cpp
   if(Persist_Has(name)) return false;         // already scoped - scoped value wins
   ...
   Persist_DelLegacy(name);
   PrintFormat("[PERSIST] migrated legacy %s -> %s (%.2f)", Persist_LegacyKey(name), Persist_Key(name), v);
   return true;
   ```

3. Concrete failure scenario:

   1. The scoped write succeeds but `GlobalVariableDel()` fails.
   2. Migration nevertheless logs success and returns `true`.
   3. Future initialization in this scope returns immediately because the scoped key exists, so it never retries legacy cleanup.
   4. A later account/symbol without a scoped key can import the stale magic-only halt/peak state.

4. Suggested fix:

   Make deletion return and check a boolean, verify the key is absent, and keep a durable cleanup-pending state until confirmed. Cleanup must run even when the destination scoped key already exists; only report migration complete after both the scoped write and legacy removal are confirmed and flushed.

## `ea_template/core/RiskControl.mqh`

### Finding R1 — critical persistence failure is logged but not reconciled or retried

1. Severity: SEV1 (money/state-loss risk)

2. File:line evidence:

   `ea_template/core/RiskControl.mqh:205-223`

   ```cpp
   if(Exec_CloseAll())
   {
      g_rc_kill_pending = false;
      g_rc_halted       = true;
      ...
      bool ok = Persist_Set("rc_state", RC_STATE_HALTED);
      ok = Persist_Set("rc_peak_eq", g_rc_peak_equity) && ok;
      Persist_Flush();
      if(!ok) Print("[RISK] ERROR: HALT persist incomplete - halt state may not survive a restart");
      ...
      PrintFormat("[RISK] HARD KILL complete: broker flat verified -> halt%s",
                  (RC_PersistHalt ? " (persisted)" : ""));
      return true;
   }
   ```

   `ea_template/core/RiskControl.mqh:250-259`

   ```cpp
   g_rc_kill_pending = true;
   if(RC_PersistHalt && !DryRun)
   {
      if(!Persist_Set("rc_state", RC_STATE_KILL_PENDING))
         Print("[RISK] ERROR: kill-pending persist failed - a restart mid-kill would forget the kill");
      Persist_Flush();
   }
   RiskControl_KillReconcile();
   ```

3. Concrete failure scenario:

   1. `Persist_Set(KILL_PENDING)` fails, for example because of Finding P1.
   2. The EA proceeds with broker closes instead of marking persistence dirty.
   3. `Persist_Set(HALTED)` also fails; memory is changed to `g_rc_halted=true`, and the log still prints `(persisted)` solely because `RC_PersistHalt` is enabled.
   4. A terminal/process restart clears memory and restores no state, so new orders are allowed again.

4. Suggested fix:

   Add a `persist_dirty` reconciliation state processed before the halted early return. Keep retrying the critical write/flush and never log `(persisted)` unless it succeeded. If a valid durable key cannot be created, fail initialization or remain fail-closed; still close exposure for safety, but do not consider the state transition complete.

### Finding R2 — DryRun still mutates persistent high-water marks

1. Severity: SEV2 (real bug, bounded impact)

2. File:line evidence:

   `ea_template/core/RiskControl.mqh:64-72`

   ```cpp
   void RiskControl_AcctHwmUpdate()
   {
      if(RC_AcctDDLimitPct <= 0.0) return;
      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      if(eq > g_rc_acct_hwm)
      {
         g_rc_acct_hwm = eq;
         Persist_Set("acct_hwm", g_rc_acct_hwm);
      }
   }
   ```

   `ea_template/core/RiskControl.mqh:184-191`

   ```cpp
   if(eq > g_rc_peak_equity)
   {
      g_rc_peak_equity = eq;
      if(RC_PersistHalt) Persist_Set("rc_peak_eq", g_rc_peak_equity);
   }
   ```

3. Concrete failure scenario:

   1. A DryRun observation instance is attached with `RC_AcctDDLimitPct>0` or sees a new equity peak under the default `RC_PersistHalt=true`.
   2. `RiskControl_Init()`/`RiskControl_CheckDD()` reaches these functions.
   3. The DryRun instance writes scoped `acct_hwm` or `rc_peak_eq` even though the ORDER-132 constraint says DryRun must not write/delete terminal GVs.
   4. A later real attach restores observation-run state and can block or change live risk behavior.

4. Suggested fix:

   Centralize the no-write policy in `Persist_Set` (or use a separate explicitly allowed test helper) and also guard these callers with `!DryRun`. Add a test that enables the account gate, advances a peak under DryRun, and asserts no scoped GV is created.

### Finding R3 — terminal-GV expiry can silently remove HALTED and peak state

1. Severity: SEV1 (money/state-loss risk)

2. File:line evidence:

   `ea_template/core/RiskControl.mqh:126-127`

   ```cpp
   if(Persist_Has("rc_state"))
      st = Persist_Get("rc_state", RC_STATE_RUNNING);
   ```

   `ea_template/core/RiskControl.mqh:187-190`

   ```cpp
   if(eq > g_rc_peak_equity)
   {
      g_rc_peak_equity = eq;
      if(RC_PersistHalt) Persist_Set("rc_peak_eq", g_rc_peak_equity);
   }
   ```

   `ea_template/core/LabCore.mqh:176-177`

   ```cpp
   if(RiskControl_CheckDD()) return;
   if(RiskControl_IsHalted()) return;
   ```

3. Concrete failure scenario:

   1. An EA is HALTED and remains attached for more than four weeks, or a running EA remains below its stored equity peak for more than four weeks.
   2. The halted path returns every tick without touching `rc_state`; the running path touches `rc_peak_eq` only on a new high.
   3. MT5 expires terminal GlobalVariables four weeks after their last use.
   4. A later restart/recompile finds no `rc_state`/peak and starts RUNNING or measures DD from a lower reset peak.

4. Suggested fix:

   Refresh every critical key on a periodic timer/tick well inside the four-week TTL, including while halted, or move durable safety state to storage without TTL. Add a restore test that simulates an expired/missing key and requires an explicit operator reset rather than silently assuming RUNNING when the last durable state is unknown.

## `ea_template/core/Execution.mqh`

### Finding E1 — partial-close success is not broker-confirmed

1. Severity: SEV1 (money/state-loss risk)

2. File:line evidence:

   `ea_template/core/Execution.mqh:400-418`

   ```cpp
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsMine(i)) continue;
      ulong  tk  = PositionGetInteger(POSITION_TICKET);
      double vol = PositionGetDouble(POSITION_VOLUME);
      double closeVol = Exec_NormalizeCloseLot(vol * frac);
      if(closeVol <= 0.0 || closeVol >= vol) continue;
      ...
      if(!g_trade.PositionClosePartial(tk, closeVol))
      {
         allOk = false;
         PrintFormat("[EXEC] partial-close FAILED %I64u vol=%.2f retcode=%d", tk, closeVol, (int)g_trade.ResultRetcode());
      }
   }
   return allOk;
   ```

   `ea_template/core/ExitManager.mqh:406-414`

   ```cpp
   if(!g_exit_partial1_done && _2_PartialPct1 > 0.0 && pctOfTarget >= _2_PartialPct1)
   {
      if(Exec_ClosePartialFraction(_2_PartialFrac1))
         g_exit_partial1_done = true;
   }
   ...
   if(Exec_ClosePartialFraction(_2_PartialFrac2))
      g_exit_partial2_done = true;
   ```

3. Concrete failure scenario:

   1. `PositionClosePartial()` passes its local/basic structure check and returns `true`, but the trade server rejects the request, times out ambiguously, or executes less than requested.
   2. No accepted `ResultRetcode`, `ResultVolume`, or before/after position-volume check is performed.
   3. `allOk` remains true and ExitManager latches the milestone.
   4. The intended risk reduction is never retried although the live volume did not fall as required.

4. Suggested fix:

   Snapshot each ticket's volume, submit the request, require an accepted server retcode, then reselect the ticket and verify the observed remaining volume is at or below the intended target (or the ticket is gone). Treat timeout as UNKNOWN and reconcile before deciding whether to retry.

### Finding E2 — mixed-success retries repeatedly close legs that already succeeded

1. Severity: SEV1 (money/state-loss risk)

2. File:line evidence:

   `ea_template/core/Execution.mqh:399-418`

   ```cpp
   bool allOk = true;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ...
      double closeVol = Exec_NormalizeCloseLot(vol * frac);
      ...
      if(!g_trade.PositionClosePartial(tk, closeVol))
      {
         allOk = false;
         ...
      }
   }
   return allOk;
   ```

   `ea_template/core/ExitManager.mqh:401-409`

   ```cpp
   // (A mixed-success retry re-fractions the already-reduced legs, closing
   // slightly more than one clean pass would - risk-REDUCING direction, accepted.)
   ...
   if(Exec_ClosePartialFraction(_2_PartialFrac1))
      g_exit_partial1_done = true;
   ```

3. Concrete failure scenario:

   1. A 30% milestone runs on two 1.00-lot legs.
   2. Leg A closes 0.30; leg B is rejected, so the milestone remains armed.
   3. On every retry, the function closes another 30% of A's current remaining volume while retrying B.
   4. Repeated rejection of B can drain the successful/cushion leg far beyond 30%, concentrating the basket in the leg the broker would not close. This is not bounded to a single “slight” over-close.

4. Suggested fix:

   Snapshot a per-ticket target remaining volume when the milestone arms. On retry, close only the shortfall to that target and skip tickets already at/below it. Retain per-ticket completion until the whole milestone is reconciled.

### Finding E3 — pending placement treats a `CTrade` boolean as accepted, and timeout retries are not idempotent

1. Severity: SEV1 (money/state-loss risk)

2. File:line evidence:

   `ea_template/core/Execution.mqh:315-324`

   ```cpp
   bool ok = false;
   if(direction == 1) ok = (isStop ? g_trade.BuyStop(...)
                                   : g_trade.BuyLimit(...));
   else               ok = (isStop ? g_trade.SellStop(...)
                                   : g_trade.SellLimit(...));
   if(ok) PrintFormat("[EXEC] pending placed dir=%d stop=%d lot=%.2f at %.5f (%s)",
                      direction, (isStop ? 1 : 0), lot, price, comment);
   ...
   return ok;
   ```

   `ea_template/core/Stack.mqh:220-228`

   ```cpp
   if(Exec_PlacePending(g_stack_dir, isStop, lot, price, sl, "PYR L" + IntegerToString(k)))
   {
      g_stack_leg_ok[k]     = true;
      g_stack_leg_ticket[k] = g_trade.ResultOrder();
   }
   else
      allOk = false;
   ...
   g_stack_ladder_placed = allOk;
   ```

3. Concrete failure scenario:

   1. If the basic structure check returns true but the server rejects, Stack marks the leg confirmed, possibly with ticket 0, and eventually returns forever through `g_stack_ladder_placed`.
   2. Conversely, on an ambiguous timeout the helper can return false while the broker later creates the order.
   3. The next tick submits the same `PYR Lk` again without reconciling live orders/history.
   4. The basket ends with either a missing leg or duplicate GTC legs and doubled exposure.

4. Suggested fix:

   Return a tri-state `ACCEPTED / REJECTED / UNKNOWN`. Require an accepted pending-order retcode, nonzero `ResultOrder()`, and broker-order verification before marking success. Give each basket+leg a stable idempotency identity and reconcile current orders plus recent history before retrying UNKNOWN.

### Finding E4 — the account-level margin cap reserves only this EA's own pending orders

1. Severity: SEV1 (money/state-loss risk)

2. File:line evidence:

   `ea_template/core/Execution.mqh:237-243`

   ```cpp
   bool Exec_OrdIsMine(const int index)
   {
      ulong tk = OrderGetTicket(index);
      if(tk == 0) return false;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) return false;
      if((long)OrderGetInteger(ORDER_MAGIC) != _0_Magic) return false;
      return true;
   }
   ```

   `ea_template/core/Execution.mqh:259-272`

   ```cpp
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!Exec_OrdIsMine(i)) continue;
      ...
      if(OrderCalcMargin(...))
         sum += m;
   }
   ```

   `ea_template/core/Stack.mqh:140-142`

   ```cpp
   double projected = AccountInfoDouble(ACCOUNT_MARGIN) + Exec_PendingMarginProjection() + legM;
   double loadPct   = 100.0 * projected / bal;
   if(loadPct >= maxLoadPct)
   ```

3. Concrete failure scenario:

   1. Account margin is 10% with a 30% cap.
   2. EA A places resting legs projected at 15%; it sees 25% and passes.
   3. EA B on another symbol/magic also projects 15%, but A's GTC orders are excluded, so B also sees 25% and passes.
   4. A gap fills both ladders before either EA can veto; account deposit load reaches about 40%, above the account-level cage.

4. Suggested fix:

   Reserve projected margin for all account pending orders, regardless of symbol/magic, or maintain an atomic account-scoped reservation ledger shared by every EA. The same account-level formula must be used by every placement lane.

## `ea_template/core/ExitManager.mqh`

### Finding X1 — partial-close milestones are not tied to a durable basket identity

1. Severity: SEV1 (money/state-loss risk)

2. File:line evidence:

   `ea_template/core/ExitManager.mqh:353-354`

   ```cpp
   bool g_exit_partial1_done = false;
   bool g_exit_partial2_done = false;
   ```

   `ea_template/core/ExitManager.mqh:396-414`

   ```cpp
   double profit = Exec_BasketProfit();
   if(profit <= 0.0) { g_exit_partial1_done = false; g_exit_partial2_done = false; return; }
   ...
   if(Exec_ClosePartialFraction(_2_PartialFrac1))
      g_exit_partial1_done = true;
   ...
   if(Exec_ClosePartialFraction(_2_PartialFrac2))
      g_exit_partial2_done = true;
   ```

3. Concrete failure scenario:

   1. A live profitable basket completes the first 30% partial and leaves `g_exit_partial1_done=true` only in memory.
   2. The EA recompiles, restarts, or the terminal switches account and reinitializes while the same basket remains open and above the first threshold.
   3. The global resets to false.
   4. The next management tick performs the first partial again, producing an unintended second reduction; both milestones can repeat after each restart.

4. Suggested fix:

   Persist milestone progress keyed by a durable basket identity and reconcile it against current ticket volumes/history on init. Delete it only after that basket is broker-flat. At minimum, reconstruct already-completed milestones before allowing a new partial request.

### Finding X2 — ordinary full-basket exits discard `Exec_CloseAll()`'s proof and forget the exit intent

1. Severity: SEV1 (money/state-loss risk)

2. File:line evidence:

   `ea_template/core/ExitManager.mqh:428-433`

   ```cpp
   if(profit <= -_32_SL_Money)
   {
      ...
      Exec_CloseAll();
      return true;
   }
   ```

   `ea_template/core/ExitManager.mqh:445-458`

   ```cpp
   if(targetMoney > 0.0 && profit >= targetMoney) { Exec_CloseAll(); return true; }
   ...
   if(_32_SL_Money > 0.0 && profit <= -_32_SL_Money) { Exec_CloseAll(); return true; }
   ...
   if(Exec_CountDir(1) > 0 && f < s) { Exec_CloseAll(); return true; }
   if(Exec_CountDir(2) > 0 && f > s) { Exec_CloseAll(); return true; }
   ```

   `ea_template/core/Execution.mqh:343-346`

   ```cpp
   Exec_CancelAllPending();
   if(DryRun) return true;
   return (Exec_CountAll() == 0 && Exec_CountPending() == 0);
   ```

3. Concrete failure scenario:

   1. A basket TP/stop/trend exit fires; some tickets close and one position or pending order is rejected.
   2. `Exec_CloseAll()` correctly returns false, but ExitManager discards it and tells `LabCore::OnTick()` to return as if flat.
   3. The changed residual P/L/count no longer satisfies the original predicate on the next tick.
   4. The close intent is forgotten and normal Stack/Recovery/Hedge management can resume around residual exposure.

4. Suggested fix:

   Add an `EXIT_PENDING` reconciliation state that owns every tick and blocks all adds until `Exec_CloseAll()==true`. Return “fully closed” only on broker proof; persist safety-stop exit intent if it must survive restart.

## `ea_template/core/Kangaroo.mqh`

### Finding K1 — when both pair closes fail, no close intent is armed

1. Severity: SEV1 (money/state-loss risk)

2. File:line evidence:

   `ea_template/core/Kangaroo.mqh:276-296`

   ```cpp
   if(g_k16_pair_residual == 0 && have >= _16_OverlapMinOrders && _16_OverlapMinUsd > 0.0)
   {
      ...
      Exec_CloseTicket(nTk);
      Exec_CloseTicket(oTk);
      ...
      bool goneNew = !PositionSelectByTicket(nTk);
      bool goneOld = !PositionSelectByTicket(oTk);
      if(goneNew != goneOld)
      {
         g_k16_pair_residual = (goneNew ? oTk : nTk);
         ...
      }
   }
   ```

3. Concrete failure scenario:

   1. The pair threshold is met and both close requests are rejected during a liquidity gap.
   2. `goneNew==false` and `goneOld==false`, so no ticket is armed.
   3. Price moves and the combined P/L drops below `_16_OverlapMinUsd` on the next tick.
   4. The pair exit is never retried, despite both tickets still being live. The comment's assumption that the predicate remains true next tick is not guaranteed.

4. Suggested fix:

   Arm a two-ticket pair-close intent before sending either request. Reconcile both tickets every tick until both are absent; do not condition retries on the original P/L predicate after intent is armed.

### Finding K2 — asymmetric residual intent is intentionally memory-only and is lost on restart

1. Severity: SEV1 (money/state-loss risk)

2. File:line evidence:

   `ea_template/core/Kangaroo.mqh:37-48`

   ```cpp
   // until the broker confirms it gone. In-memory only: after a restart the leg
   // simply rejoins normal grid management ...
   ulong g_k16_pair_residual = 0;

   void Kangaroo_Init()
   {
      g_k16_last_bar      = 0;
      g_k16_pair_residual = 0;
   }
   ```

   `ea_template/core/Kangaroo.mqh:291-295`

   ```cpp
   if(goneNew != goneOld)
   {
      g_k16_pair_residual = (goneNew ? oTk : nTk);
      PrintFormat("[K16] pair-close ASYMMETRIC: %I64u closed, %I64u remains -> retrying until closed",
                  (goneNew ? nTk : oTk), g_k16_pair_residual);
   }
   ```

3. Concrete failure scenario:

   1. The profitable pair leg closes and the deep losing leg is rejected, so the residual ticket is armed.
   2. The terminal/EA crashes before a later retry succeeds.
   3. `Kangaroo_Init()` clears the only record of the outstanding exit.
   4. The profitable partner that made the threshold true is gone, so the pair predicate may never recur; the losing tail remains under ordinary grid logic instead of the already-decided liquidation.

4. Suggested fix:

   Persist the pair-close intent (both tickets and a basket/position identity) before the first close attempt. On init, validate each ticket's current symbol+magic and resume reconciliation; clear the state only after both are broker-confirmed gone.

### Finding K3 — failed residual liquidation does not block new grid adds

1. Severity: SEV1 (money/state-loss risk)

2. File:line evidence:

   `ea_template/core/Kangaroo.mqh:212-235`

   ```cpp
   if(g_k16_pair_residual != 0)
   {
      ...
      Exec_CloseTicket(g_k16_pair_residual);
      ...
      else
      {
         ...
         PrintFormat("[K16] pair-close residual %I64u still open ... - retrying", ...);
      }
   }
   ```

   `ea_template/core/Kangaroo.mqh:364-368`

   ```cpp
   if(Kangaroo_ManageExits()) return true;

   // (3) grid adds (adverse-only, intrabar)
   Kangaroo_TryAdd();
   ```

3. Concrete failure scenario:

   1. An asymmetric pair-close leaves a losing residual and its retry is rejected.
   2. `Kangaroo_ManageExits()` returns false even though `g_k16_pair_residual` remains nonzero.
   3. The same tick reaches `Kangaroo_TryAdd()`; if price is adverse and the cage has room, a new position opens.
   4. The EA adds exposure while an earlier exit transaction is still unresolved, potentially recreating or enlarging the basket being liquidated.

4. Suggested fix:

   Return an explicit `EXIT_PENDING` status while any residual exists and short-circuit grid/first-entry logic. Hard-kill/emergency safety may continue to run above it, but no risk-adding path should run until the exit is confirmed.

### Finding K4 — Kangaroo's other full exits also discard broker-flat proof

1. Severity: SEV1 (money/state-loss risk)

2. File:line evidence:

   `ea_template/core/Kangaroo.mqh:240-267`

   ```cpp
   if(have == 1 && Kangaroo_SingleTPHit())
   {
      Exec_CloseAll();
      return true;
   }
   ...
   if(target > 0.0 && net >= target)
   {
      Exec_CloseAll();
      return true;
   }
   ...
   Exec_CloseAll();
   return true;
   ```

   `ea_template/core/Kangaroo.mqh:355-361`

   ```cpp
   if(_16_EmergencyDDPct > 0.0 && Exec_CountAll() > 0 &&
      RiskControl_CurrentDDPct() >= _16_EmergencyDDPct)
   {
      ...
      Exec_CloseAll();
      return true;
   }
   ```

3. Concrete failure scenario:

   1. Basket TP/flatten/single TP fires, but one close or pending cancellation fails.
   2. Kangaroo returns as though the basket closed and does not arm reconciliation.
   3. Partial success changes `have`/net profit, clearing the trigger on the next tick.
   4. The residual resumes normal Kangaroo management and may be added to. Emergency DD usually re-fires if DD remains high, but the profit/flatten predicates need not.

4. Suggested fix:

   Use the same broker-flat `EXIT_PENDING` state for every Kangaroo full exit. Continue calling `Exec_CloseAll()` and block adds until its returned proof is true; persist emergency/safety exit intent across restart.

## `ea_template/core/Stack.mqh`

### Finding S1 — restart treats any partial ladder as complete

1. Severity: SEV2 (real bug, bounded impact)

2. File:line evidence:

   `ea_template/core/Stack.mqh:94-101`

   ```cpp
   bool   g_stack_ladder_placed = false;
   bool   g_stack_ladder_own    = false;
   ...
   bool   g_stack_leg_ok[STACK_MAX_LEGS + 1];
   ulong  g_stack_leg_ticket[STACK_MAX_LEGS + 1];
   ```

   `ea_template/core/Stack.mqh:174-181`

   ```cpp
   if(!g_stack_ladder_own)
   {
      if(filled != 1 || pending > 0)
      {
         // mid-basket restart/recompile: ladder (or its fills) already exists at
         // the broker and THIS session did not place it - never re-place on top
         g_stack_ladder_placed = true;
         return;
      }
   ```

3. Concrete failure scenario:

   1. A three-leg ladder places leg 1; legs 2 and 3 are vetoed/rejected and remain armed only in memory.
   2. The EA restarts while leg 1 is still pending.
   3. All per-leg arrays reset; `pending>0` makes the restart guard latch the whole ladder complete.
   4. Missing legs 2 and 3 are never reconstructed or retried.

4. Suggested fix:

   Rebuild planned-leg state on init from stable basket+leg identities in broker orders/positions/history, then retry only genuinely absent legs. If state cannot be reconstructed unambiguously, fail closed or cancel/rebuild the whole ladder transactionally.

### Finding S2 — stored tickets are never reconciled after placement

1. Severity: SEV2 (real bug, bounded impact)

2. File:line evidence:

   `ea_template/core/Stack.mqh:100-101`

   ```cpp
   bool   g_stack_leg_ok[STACK_MAX_LEGS + 1];
   ulong  g_stack_leg_ticket[STACK_MAX_LEGS + 1];
   ```

   `ea_template/core/Stack.mqh:171-172`

   ```cpp
   if(g_stack_ladder_placed) return;
   if(_9_PendingMode != 2 && _9_PendingMode != 3) { g_stack_ladder_placed = true; return; }
   ```

   `ea_template/core/Stack.mqh:220-223`

   ```cpp
   if(Exec_PlacePending(...))
   {
      g_stack_leg_ok[k]     = true;
      g_stack_leg_ticket[k] = g_trade.ResultOrder();
   }
   ```

3. Concrete failure scenario:

   1. Every pending leg is initially accepted, so `g_stack_ladder_placed=true`.
   2. The broker later cancels one GTC order, a manual action removes it, or a partially filled remainder is canceled.
   3. `Stack_ManagePyramid()` returns at line 171 before checking the stored ticket.
   4. The promised per-leg retry never occurs; `g_stack_leg_ticket[]` is write-only tracking data.

4. Suggested fix:

   Reconcile each leg on every tick or in `OnTradeTransaction`: active pending, filled position/history, canceled/rejected remainder, or unknown. A canceled leg should re-arm according to explicit policy; a filled leg should be marked completed without requiring a live order ticket.

### Finding S3 — the pending margin budget is never revalidated after placement

1. Severity: SEV1 (money/state-loss risk)

2. File:line evidence:

   `ea_template/core/Stack.mqh:140-154`

   ```cpp
   double projected = AccountInfoDouble(ACCOUNT_MARGIN) + Exec_PendingMarginProjection() + legM;
   double loadPct   = 100.0 * projected / bal;
   if(loadPct >= maxLoadPct)
   {
      ...
      return false;
   }
   return true;
   ```

   `ea_template/core/Stack.mqh:171`

   ```cpp
   if(g_stack_ladder_placed) return;
   ```

3. Concrete failure scenario:

   1. A GTC ladder is validly placed at 25% projected load under a 30% cap.
   2. Balance is withdrawn/reduced, another EA opens positions, leverage changes, or account margin rises while these pendings rest.
   3. Projected fill load is now above 30%, but the completed-ladder early return prevents any new budget check or cancellation.
   4. A later gap fills the resting orders and breaches the cage before placement code can intervene.

4. Suggested fix:

   Continuously recompute account-wide projected load while GTC orders exist and cancel/resize the lowest-priority excess legs before they can fill. Recheck on trade/account transactions as well as ticks, with a conservative fail-closed policy when margin cannot be calculated.

## Summary

| Severity | Finding |
|---|---|
| SEV1 | P1 — Scoped GlobalVariable names can exceed 63 characters and lose kill/halt state. |
| SEV2 | P2 — A 16-bit server hash can alias state across servers. |
| SEV1 | P3 — First-initializer legacy migration can apply state to the wrong account/symbol and consume the true owner's copy. |
| SEV2 | P4 — Unchecked legacy deletion can leave cross-importable stale keys permanently. |
| SEV1 | R1 — Failed critical persistence is neither reconciled nor retried, while logs can still claim persistence. |
| SEV2 | R2 — DryRun writes persistent high-water marks. |
| SEV1 | R3 — Four-week terminal-GV expiry can silently remove HALTED and peak state. |
| SEV1 | E1 — Partial-close milestones latch on a raw `CTrade` boolean without observed volume reduction. |
| SEV1 | E2 — Mixed-success retries repeatedly reduce already-successful legs. |
| SEV1 | E3 — Pending placement is neither broker-confirmed nor idempotent after ambiguous timeout. |
| SEV1 | E4 — The account-level margin cap excludes other EAs' resting pending exposure. |
| SEV1 | X1 — Partial milestones reset across restart and can execute twice on the same basket. |
| SEV1 | X2 — Ordinary full exits discard broker-flat proof and can forget residual exposure. |
| SEV1 | K1 — A two-ticket pair close with two failures arms no retry intent. |
| SEV1 | K2 — Asymmetric pair-close residual intent is lost on restart. |
| SEV1 | K3 — Kangaroo can add new exposure while residual liquidation is failing. |
| SEV1 | K4 — Kangaroo's non-pair full exits also discard broker-flat proof. |
| SEV2 | S1 — Restart mistakes any partial ladder for a complete ladder. |
| SEV2 | S2 — Stored ladder tickets are never reconciled after later cancellation. |
| SEV1 | S3 — Resting GTC ladders are never re-budgeted after account conditions change. |
