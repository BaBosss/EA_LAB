# QA Audit — commit `629012a0` (ORDER-129)

Scope: full `git show 629012a0` plus the current surrounding call paths in the touched framework and build files. No compiler, Strategy Tester, or trading platform was run. Line references below are to the actual working tree at `629012a0`.

## Findings

### 1. SEV1 — The basket money-stop is still behind the once-per-bar early return

**Evidence.** The order explicitly requires both protections above the gate at `AGENT_TASKBOARD.md:177`:

> `ย้าย RiskControl_CheckDD() + basket money-stop ขึ้นก่อน _0_BarOpenOnly early-return`

The commit moved only the equity-DD check. `ea_template/core/LabCore.mqh:176-189` still does:

```cpp
if(RiskControl_CheckDD()) return;
if(RiskControl_IsHalted()) return;
...
if(_0_BarOpenOnly)
{
   ...
   if(b == g_lab_last_bar)
   {
      if(Exec_CountAll() > 0) return;
```

The sole basket manager remains later at `ea_template/core/LabCore.mqh:203-204`:

```cpp
// (2) manage existing basket; stop if it fully closed this tick
if(Exit_ManageBasket()) return;
```

and the money stop itself is at `ea_template/core/ExitManager.mqh:420-425`:

```cpp
double profit = Exec_BasketProfit();
...
if(_32_SL_Money > 0.0 && profit <= -_32_SL_Money) { Exec_CloseAll(); return true; }
```

**Failure scenario (HYPOTHESIS).** With `_0_BarOpenOnly=true` and an open basket, an intrabar loss can cross `_32_SL_Money` immediately after bar open. The EA returns at `LabCore.mqh:189` and does not evaluate the money stop until the next bar; on H4 that can be almost four hours. This is the exact safety behavior ORDER-129 claimed to remove.

**Attempted refutation / end-to-end trace.** I searched every call to `Exit_ManageBasket()`. The only call is `LabCore.mqh:204`; there is no alternate pre-gate money-stop path. Boss_16 is a genuine exception because `LabCore.mqh:163-169` dispatches to `Kangaroo_OnTick()`, whose hard kill is at `Kangaroo.mqh:296-298`, but that does not refute the finding for Boss_11–15/17/18. Finding stands.

**Suggested fix.** Split the safety money-stop from ordinary basket management and evaluate it before `_0_BarOpenOnly`, alongside `RiskControl_CheckDD()`. Keep profit-taking, trailing, recovery, and signal cadence behind the bar gate if that is intentional.

### 2. SEV1 — Pending-ladder state ignores placement/cancel failure; the new spread rejection can permanently suppress a basket’s ladder

**Evidence.** The new spread gate can legitimately reject a pending placement at `ea_template/core/Execution.mqh:278-284`:

```cpp
bool Exec_PlacePending(...)
{
   if(Exec_NewsBlocked() || Exec_MacroBlocked()) return false;
   if(!Exec_SpreadOK()) return false;
```

But `ea_template/core/Stack.mqh:126-136` discards every return value and unconditionally latches completion:

```cpp
for(int k = 1; k <= nPend; k++)
{
   ...
   Exec_PlacePending(dir, isStop, lot, price, sl, "PYR L" + IntegerToString(k));
}
g_stack_ladder_placed = true;
```

The reset path also ignores the new cancel result at `ea_template/core/Stack.mqh:96-101`:

```cpp
if(filled == 0)
{
   if(pending > 0) Exec_CancelAllPending();
   g_stack_ladder_placed = false;
   return;
}
```

**Failure scenario (HYPOTHESIS).** (a) A transient spread/news/macro block rejects every ladder order on the first placement tick, yet `g_stack_ladder_placed` becomes true; the basket stays permanently single-leg even after conditions normalize. This is an unintended interaction introduced by enforcing `_0_MaxSpread` in the pending path. (b) If flat-basket cancellation fails, `Stack_ManagePyramid()` returns to `LabCore`, which can open a new first leg later in the same tick (`LabCore.mqh:214-233`) while the old GTC pending remains. On the next tick, `filled==1 && pending>0` causes `Stack.mqh:105-109` to mark the ladder as already placed, preserving the stale order.

**Suggested fix.** Make ladder placement transactional: count expected broker pendings and set `g_stack_ladder_placed=true` only after confirmation. Make the flat reset return an ownership/blocking status to `LabCore`; do not permit a new first entry until own pending count is verified zero. Retry rejected individual placements or deliberately cancel the partial ladder and rebuild it.

### 3. SEV1 — Close-result handling is fixed only for the hard kill; ordinary exits can still declare success with residual or one-sided exposure

**Evidence.** `Exec_CloseAll()` now returns broker-state proof at `ea_template/core/Execution.mqh:309-323`, but all ordinary basket exits discard it. For example, `ea_template/core/ExitManager.mqh:422-433` repeatedly uses:

```cpp
if(targetMoney > 0.0 && profit >= targetMoney) { Exec_CloseAll(); return true; }
...
if(_32_SL_Money > 0.0 && profit <= -_32_SL_Money) { Exec_CloseAll(); return true; }
```

Kangaroo does the same at `ea_template/core/Kangaroo.mqh:203-217`:

```cpp
if(have == 1 && Kangaroo_SingleTPHit())
{
   Exec_CloseAll();
   return true;
}
...
Exec_CloseAll();
return true;
```

The most dangerous non-basket case is `ea_template/core/Kangaroo.mqh:242-246`, where two independent close results are ignored:

```cpp
Exec_CloseTicket(nTk);
Exec_CloseTicket(oTk);
// side still open - not a full basket close
```

Partial close also discards the broker result at `ea_template/core/Execution.mqh:356-363`:

```cpp
double closeVol = Exec_NormalizeLot(vol * frac);
...
g_trade.PositionClosePartial(tk, closeVol);
```

while `ea_template/core/ExitManager.mqh:401-409` marks each milestone done unconditionally.

**Failure scenario (HYPOTHESIS).** In an overlap pair-close, the profitable newest ticket closes but the losing oldest ticket is rejected. The profitable leg that made the pair threshold true is gone, so the remaining loss may never satisfy the pair condition again. Similarly, a failed partial close is never retried because `g_exit_partial*_done` is already true. Ordinary full-basket exits retry only if their price/profit predicate remains true on a later tick; unlike the hard kill, they have no persisted reconciliation state.

**Suggested fix.** Propagate close outcomes through every caller. Add an exit-reconciliation state that owns ticks until the requested basket/tickets are confirmed closed. For pair close, track the two tickets and retry the residual ticket. Mark partial milestones complete only after confirmed volume reduction, and log both the CTrade boolean and server retcode.

### 4. SEV1 (HYPOTHESIS) — `rc_kill_pending` is scoped only by magic, so restart/account-switch reconciliation can close the wrong account or strategy instance

**Evidence.** Persistence keys omit account, server, symbol, and strategy identity at `ea_template/core/Persist.mqh:13-15`:

```cpp
string Persist_Key(const string name) { return "Boss_" + IntegerToString(_0_Magic) + "_" + name; }
void Persist_Set(const string name, const double value) { GlobalVariableSet(Persist_Key(name), value); }
```

The new state is restored solely from that key at `ea_template/core/RiskControl.mqh:109-115`:

```cpp
if(Persist_Get("rc_kill_pending", 0.0) > 0.5)
{
   g_rc_kill_pending = true;
```

and then owns the next tick at `RiskControl.mqh:193-197`, invoking `Exec_CloseAll()` against the currently logged-in account and current `_Symbol`. The new magic guard checks only one sentinel at `ea_template/core/LabCore.mqh:75-83`:

```cpp
if(!MQLInfoInteger(MQL_TESTER) && _0_Magic == 990001)
   return INIT_FAILED;
```

It does not detect a duplicated non-default magic.

**Failure scenario (HYPOTHESIS).** A terminal records `Boss_990208_rc_kill_pending=1` on account A, then is restarted/logged into account B where the same non-default magic is valid or reused. The restored pending state can close account B’s matching symbol+magic positions. Reusing one magic on two symbols similarly shares halt/pending state across both instances after reinitialization. The sentinel guard prevents default `990001` on demo/live but does not prevent this collision class.

**Suggested fix.** Scope persisted keys by server, login, symbol, magic, and strategy/version. Add a live attach-time collision registry for actual `(account, symbol, magic)` instances, not only the reserved default. Provide an explicit migration/reset path for old keys.

### 5. SEV2 — DryRun falsely reports “broker flat verified” and can persist HALT while exposure remains

**Evidence.** DryRun deliberately skips every real close/cancel, then returns success unconditionally at `ea_template/core/Execution.mqh:311-323`:

```cpp
if(DryRun) continue;
...
Exec_CancelAllPending();
if(DryRun) return true;
return (Exec_CountAll() == 0 && Exec_CountPending() == 0);
```

`RiskControl_KillReconcile()` treats that `true` as proof at `ea_template/core/RiskControl.mqh:166-176`:

```cpp
if(Exec_CloseAll())
{
   g_rc_kill_pending = false;
   g_rc_halted = true;
   ...
   Persist_Set("rc_halted", 1.0);
```

This contradicts the order’s “persist HALT only after positions+pendings=0” requirement at `AGENT_TASKBOARD.md:177`.

**Failure scenario (HYPOTHESIS).** A DryRun instance attached for observation encounters matching residual exposure or an account-level DD event. It performs no close, persists HALT, and logs “broker flat verified.” Reattaching later with DryRun off inherits the halt even though the earlier exposure was never reconciled.

**Suggested fix.** DryRun must never fabricate flatness. Either rescan and return true only when counts are already zero, or keep a separate non-persisted simulated-kill state. Do not mutate live terminal GlobalVariables from DryRun unless explicitly requested.

### 6. SEV2 (HYPOTHESIS) — Kill persistence is fail-safe only if every GlobalVariable write succeeds and becomes durable

**Evidence.** The trigger transitions memory before persistence at `ea_template/core/RiskControl.mqh:201-207`:

```cpp
g_rc_kill_pending = true;
if(RC_PersistHalt) Persist_Set("rc_kill_pending", 1.0);
RiskControl_KillReconcile();
```

Completion uses three separate writes at `RiskControl.mqh:168-174`:

```cpp
g_rc_kill_pending = false;
g_rc_halted = true;
Persist_Set("rc_halted", 1.0);
Persist_Set("rc_peak_eq", g_rc_peak_equity);
Persist_Set("rc_kill_pending", 0.0);
```

but `ea_template/core/Persist.mqh:15` discards the result:

```cpp
void Persist_Set(const string name, const double value) { GlobalVariableSet(Persist_Key(name), value); }
```

There is no checked return, durable flush, or single persisted state value. Manual reset instructions mention only `rc_halted` at `ea_template/core/Inputs.mqh:424-430`.

**Failure scenario (HYPOTHESIS).** If the pending write fails, or the terminal/process crashes before a recent terminal-global update is durably stored, restart can come back RUNNING after equity has recovered below the threshold. A crash after `rc_halted=1` but before `rc_kill_pending=0` is fail-safe for exposure, but creates the representable `HALTED && KILL_PENDING` state; deleting only `rc_halted` before a reconciliation tick immediately re-halts the EA.

**Suggested fix.** Represent the state with one persisted enum (`RUNNING/KILL_PENDING/HALTED`), check every write, force durability for critical transitions, and persist `KILL_PENDING` successfully before beginning close attempts. Make reset delete/transition all related keys atomically and report persistence failure as a hard error.

### 7. SEV2 — The step arithmetic fixes 0.001/0.1/1.0 opens, but the shared normalizer still applies an open-risk cap to partial-close volume

**Evidence.** The new step-digit loop at `ea_template/core/Execution.mqh:38-46` correctly handles ordinary decimal steps, including 0.001, 0.1, and 1.0:

```cpp
lot = MathFloor(lot / step + 0.0000001) * step;
int stepDigits = 0;
double s = step;
while(stepDigits < 8 && MathAbs(s - MathRound(s)) > 1e-9) { s *= 10.0; stepDigits++; }
lot = NormalizeDouble(lot, stepDigits);
```

However, the same function first applies the new-order cage at `Execution.mqh:36-37`:

```cpp
if(RC_MaxLot > 0.0 && lot > RC_MaxLot) lot = RC_MaxLot;
if(lot > maxv) lot = maxv;
```

and partial-close sizing calls this exact function at `Execution.mqh:354-357`:

```cpp
double vol = PositionGetDouble(POSITION_VOLUME);
double closeVol = Exec_NormalizeLot(vol * frac);
```

**Failure scenario (HYPOTHESIS).** A 1.00-lot legacy/net position with `RC_MaxLot=0.10` and a 50% milestone requests 0.50 but is silently reduced to a 0.10 close; `ExitManager.mqh:403-405` then marks the 50% milestone complete. For a 1.0-step symbol, an unrepresentable fractional close safely becomes zero, but the caller still marks the milestone done, conflating “not executable” with “completed.”

**Suggested fix.** Split `Exec_NormalizeOpenLot()` from `Exec_NormalizeCloseLot()`. The close normalizer must honor broker min/step and remaining volume but must not apply `RC_MaxLot` as a ceiling on risk reduction. Return requested/attempted/confirmed volumes so the milestone state reflects reality.

### 8. SEV2 — Dynamic discovery can still return false-clean when a wrapper is deleted/renamed, and the matching stale `.ex5` is not explicitly purged

**Evidence.** Regression discovers only current source wrappers at `scripts/tpl_regression.ps1:38-41`:

```powershell
$experts = @(Get-ChildItem (Join-Path $root "ea_template\Boss_*.mq5") | Sort-Object Name |
             ForEach-Object { "EALabTpl\" + $_.BaseName })
```

Comparison is one-way at `tpl_regression.ps1:117-131`: it iterates `$rows` and never checks for baseline entries absent from `$rows` before printing clean.

```powershell
foreach ($r in $rows) {
  $b = $base | Where-Object ea -eq $r.ea
  ...
}
...
Write-Host "=== REGRESSION CLEAN ==="
```

The deployed mirror excludes all binaries at `ea_template/deploy.ps1:24-25`:

```powershell
robocopy "$src" "$dst" /MIR ... /XF *.ex5 *.log ...
```

and explicit binary deletion at `deploy.ps1:34-41` occurs only for names still present in the current `$targets` list.

**Failure scenario (HYPOTHESIS).** Delete or rename `Boss_17_Wave5.mq5`. It disappears from `$experts`; the baseline-only `Boss_17_Wave5` row (`ea_template/regression_baseline.csv:8`) is never checked, so all remaining rows can match and the script prints CLEAN. There is also no explicit purge of the orphan `Boss_17_Wave5.ex5`, so an old deployable binary can survive in the destination/lane mirror depending on Robocopy excluded-file behavior. If all Boss sources disappear, `$rows` is empty and the same one-way loop still reaches CLEAN.

**Suggested fix.** Compare source, compiled binaries, runtime expert list, and baseline names as equal sets in both directions; fail on zero experts, duplicates, missing baseline rows, or baseline-only rows. Explicitly enumerate and remove orphan `Boss_*.ex5` files after validating the destination path.

### 9. SEV2 — The rebuilt cage can declare clean with compiler warnings, lacks the required close-failure smoke, and this core commit was recorded before mandatory CLEAN confirmation

**Evidence.** `ea_template/deploy.ps1:45-61` collects warning lines but only parses/fails the error count:

```powershell
$res = ($txt -split "`r?`n" | Where-Object { $_ -match "Result:|error|warning" })
...
$resultLine = ... Where-Object { $_ -match "Result:\s*\d+\s+errors?" }
if ([int]$Matches[1] -gt 0) { $compileFailed = $true }
```

`scripts/tpl_regression.ps1:35-37` trusts that exit status, so `Result: 0 errors, N warnings` can continue to `REGRESSION CLEAN`. The regression file describes only numeric backtests at `tpl_regression.ps1:4-9`; no close-rejection/failure injection exists in the changed scripts, despite `AGENT_TASKBOARD.md:177` requiring `new failure-path smoke (close-fail sim ...)`.

Repository policy is explicit at `AGENTS.md:78-80`:

> `แก้ ea_template\core\* ... tpl_regression.ps1 → ต้อง CLEAN ก่อน commit`

but the committed order status at `AGENT_TASKBOARD.md:174-175` says it is still waiting for `confirm-regression`, admits Boss_18 drift, and re-pins it before isolating the cause:

> `รอ Codex blind-audit + confirm-regression รอบ tester ว่าง`
>
> `Boss_18 drift −17t ... แยกไม่จบ ... รับ + re-pin`

**Failure scenario (HYPOTHESIS).** A warning-bearing build or untested close-failure path receives a green regression result, while the baseline update converts an unexplained behavior change into the new expected value. Subsequent regressions cannot detect the already-blessed drift.

**Suggested fix.** Parse both errors and warnings and enforce 0/0. Add a deterministic broker-failure seam/test that proves pending retry, close retry, and restart reconciliation. Do not commit core changes or confirm a baseline while the required CLEAN run and root-cause isolation remain pending; keep the unexplained Boss_18 result as a failing quarantine row.

### 10. SEV3 — Spread units are undocumented at the input boundary, and “pending enforcement” covers placement but not later fill

**Evidence.** The public input at `ea_template/core/Inputs.mqh:451-453` gives no unit:

```cpp
input long _0_Magic     = 990001;
input int  _0_Slippage  = 20;
input int  _0_MaxSpread = 0; // 0 = ignore
```

The implementation chooses broker points at `ea_template/core/Execution.mqh:64-74`:

```cpp
long spr = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD); // points
if(spr <= (long)_0_MaxSpread) return true;
...
PrintFormat("[EXEC] spread %d > max %d - new order blocked", ...);
```

For pendings, the check occurs only inside `Exec_PlacePending()` at `Execution.mqh:278-282`; an already accepted GTC order is not revisited by this predicate before broker-side fill.

**Failure scenario (HYPOTHESIS).** An operator enters `3` meaning 3 pips on a five-digit FX symbol, but the code interprets 3 points (0.3 pip) and blocks most entries; the inverse misunderstanding can under-protect another instrument. A pending placed at a narrow spread can still trigger during a later rollover/news widening, so the taskboard/progress phrase “enforce จริง market+pending” is broader than what the code guarantees.

**Suggested fix.** Rename/document the input as `_0_MaxSpreadPoints`, log both points and price/pip equivalents, and add digit-boundary tests. Decide explicitly whether the policy is placement-only; if fill-time protection is required, monitor/cancel eligible pendings on spread breach while accounting for broker race conditions.

## Overall assessment

Commit `629012a0` makes several sound local improvements: the hard-kill now re-scans synchronous broker state and retries while pending, the hard DD check is above the generic bar gate, Kangaroo’s current open path refuses missing ATR/SL, the default magic is rejected on non-tester attachments while tester/optimizer use remains available, and decimal-step normalization is materially better for 0.001/0.1/1.0 brokers. It is not yet a complete SEV-1 closure: the explicitly required basket money-stop remains bar-gated; pending and ordinary close callers do not honor the new result contracts; DryRun can fabricate flatness; persisted pending state is neither fully scoped nor transactionally checked; and the rebuilt regression cage retains multiple false-clean paths while the commit itself records an unexplained re-pin before mandatory CLEAN confirmation. I would treat ORDER-129 as requiring corrective changes and a real failure-path smoke before it can be considered complete.
