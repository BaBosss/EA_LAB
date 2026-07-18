//+------------------------------------------------------------------+
//| Kangaroo.mqh (V2) - entry 16 basket engine (ORDER-072).          |
//| KangarooInspired: RSI-fade first entry (bar open) + ATR-spaced   |
//| ADVERSE-only grid + FLAT lots (optional capped ladder) + per-    |
//| order ATR SL + three dollar-based exits (single-order TP /       |
//| basket net-$ / overlap pair-close) + optional ladder_flatten     |
//| controlled-loss release + emergency equity-DD close-all.         |
//| Mechanics source: _triage\KANGAROO_LOGIC_NOTES.md par.3-4 (con-  |
//| firmed Gold_Kangaroo behaviors), money-based per ORDER-072.      |
//|                                                                  |
//| ONE EXIT OWNER (DESIGN_V2 / MERGE-02 rule): this module owns     |
//| EVERY exit for entry 16. Legs carry a per-order broker SL        |
//| (protective only - mode-93 precedent) and NEVER a broker TP.     |
//| LabCore::OnTick short-circuits into Kangaroo_OnTick(), so the    |
//| chassis ExitManager / Stack / Recovery / Hedge / Basket paths    |
//| never run for this build. The cage stays supreme ABOVE this      |
//| module: RiskControl hard-kill DD + deposit-load block + RC_MaxLot|
//| clamp all still apply. Compiled OUT of every other build         |
//| (#ifdef LAB_ENTRY_16 in LabCore) - additive, Boss_11..15 keep    |
//| byte-identical behavior.                                         |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_KANGAROO_MQH
#define BOSS_LAB_KANGAROO_MQH
#include "Inputs.mqh"
#include "Indicators.mqh"
#include "Execution.mqh"
#include "RiskControl.mqh"
#include "entries/IEntry.mqh"

#ifndef LAB_ENTRY_TAG
#define LAB_ENTRY_TAG "16_KangarooGrid"
#endif

// recompile-safe state (reset in Kangaroo_Init from OnInit)
datetime g_k16_last_bar = 0;   // bar-open gate for first entries

// ORDER-132 (Codex F3) + 132b (Codex K1/K2/K3): overlap pair-close INTENT.
// Once the pair predicate fires, BOTH tickets are armed (before any close is
// sent - two simultaneous rejects must not lose the decision, and the predicate
// is not guaranteed to re-fire after prices move). Each slot is reconciled
// against broker state every tick until confirmed gone; while armed, the intent
// owns the tick (no new pairs, no grid adds). Persisted via scoped GVs so a
// restart mid-liquidation resumes it (K2); tester GVs are sandboxed per pass.
ulong g_k16_pair_a = 0;   // newest-leg ticket of the armed pair (0 = none)
ulong g_k16_pair_b = 0;   // oldest-leg ticket of the armed pair (0 = none)
// ORDER-132b (Codex K4): full-basket close latch - same X2 pattern as ExitManager.
bool  g_k16_closeall_pending = false;

void Kangaroo_PairPersist()
{
   if(!RC_PersistHalt || DryRun) return;
   if(g_k16_pair_a != 0) Persist_Set("k16_pair_a", (double)g_k16_pair_a); else Persist_Del("k16_pair_a");
   if(g_k16_pair_b != 0) Persist_Set("k16_pair_b", (double)g_k16_pair_b); else Persist_Del("k16_pair_b");
   Persist_Flush();
}

void Kangaroo_Init()
{
   g_k16_last_bar         = 0;
   g_k16_pair_a           = 0;
   g_k16_pair_b           = 0;
   g_k16_closeall_pending = false;
   if(RC_PersistHalt && !DryRun)
   {
      g_k16_pair_a = (ulong)Persist_Get("k16_pair_a", 0.0);
      g_k16_pair_b = (ulong)Persist_Get("k16_pair_b", 0.0);
      if(g_k16_pair_a != 0 || g_k16_pair_b != 0)
         PrintFormat("[K16] pair-close intent restored from persist (a=%I64u b=%I64u) - resuming liquidation",
                     g_k16_pair_a, g_k16_pair_b);
   }
}

// reconcile one pair-intent slot: close if still open (and still OURS - a
// restored ticket is re-validated against symbol+magic), clear when gone.
// Returns true while the slot still holds a live position.
bool Kangaroo_PairSlotOpen(ulong &tk)
{
   if(tk == 0) return false;
   if(!PositionSelectByTicket(tk)) { tk = 0; return false; }   // gone (closed/SL/manual)
   if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
      (long)PositionGetInteger(POSITION_MAGIC) != _0_Magic)
   {
      PrintFormat("[K16] pair intent ticket %I64u no longer matches symbol+magic - dropping intent", tk);
      tk = 0;
      return false;
   }
   Exec_CloseTicket(tk);
   if(!PositionSelectByTicket(tk)) { tk = 0; return false; }   // broker-confirmed gone
   return true;
}

// full-basket close with broker-flat proof (K4): retried until confirmed.
bool Kangaroo_CloseBasket()
{
   if(Exec_CloseAll()) { g_k16_closeall_pending = false; return true; }
   g_k16_closeall_pending = true;
   static datetime last_log = 0;
   datetime now = TimeCurrent();
   if(now - last_log >= 60)
   {
      last_log = now;
      Print("[K16] basket close incomplete - residual remains, retrying every tick");
   }
   return true;   // close intent owns the tick either way
}

int Kangaroo_Dir() { return (_16_Direction == 1 ? 1 : 2); }

// digit-aware pip: 10*point on 3/5-digit symbols, else point (XAUUSD 2-digit ->
// pip = point = $0.01, so 9000 pips = $90 price range = original scale exactly).
// Same rule as Stack_PipSize()/Entry_GridLog_PipSize().
double Kangaroo_PipSize()
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point = Indi_Point();
   if(digits == 5 || digits == 3) return point * 10.0;
   return point;
}

// grid spacing (price units) for the NEXT add when `have` orders are already
// open on this side: max(ATR-mult x Signal-ATR, MinDistPips floor).
// First-four zone = have < 4 (gaps before orders 2..4), wider mult from order 5.
// ATR read at shift 1 (last CLOSED bar) - GridLog parity lesson: a forming-bar
// ATR moves intrabar and mis-prices the trigger.
double Kangaroo_StepPrice(const int have)
{
   double atr = Indi_ATR(1);
   if(atr <= 0.0) return 0.0;
   double mult = (have < 4 ? _16_AtrMultFirst4 : _16_AtrMultAfter);
   double d1 = atr * mult;
   double d2 = _16_MinDistPips * Kangaroo_PipSize();
   return (d1 > d2 ? d1 : d2);
}

// per-order SL distance (price units): SlAtrMult x Risk-ATR, hard ceiling
// MaxSlPips (digit-aware). Original: fixed $90; ATR-mult per chassis standard,
// pip ceiling keeps the original's worst-case bound.
double Kangaroo_SLDist()
{
   double atr = Indi_RiskATR(1);
   if(atr <= 0.0) return 0.0;
   double d = atr * _16_SlAtrMult;
   if(_16_MaxSlPips > 0.0)
   {
      double cap = _16_MaxSlPips * Kangaroo_PipSize();
      if(cap > 0.0 && d > cap) d = cap;
   }
   return d;
}

// side price extreme of my open orders: lowest open for BUY, highest for SELL.
// Adds reference this (not last-by-time) so an add fires ONLY on a fresh
// adverse extreme - after an overlap pair-close removes the newest order,
// price oscillation cannot refill the same hole. Matches observed original
// behavior (new orders during 2024-11-06 crash appeared at new lows only).
double Kangaroo_ExtremePrice(const int dir)
{
   double best = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsMine(i)) continue;
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      if(best <= 0.0) { best = open; continue; }
      if(dir == 1) { if(open < best) best = open; }
      else         { if(open > best) best = open; }
   }
   return best;
}

// lot law (ORDER-072 decision 1): FLAT default - every order = BaseLot.
// LadderMult > 1.0 enables the capped ladder for A/B: order N = max currently
// OPEN lot x LadderMult, first 4 orders of a side always BaseLot (also gives
// the observed original reset: once opens drop back below 4, lots restart at
// base). Per-order cap MaxLotPerOrder, then the cage (RC_MaxLot) clamps last.
double Kangaroo_NextLot(const int have)
{
   double lot = _16_BaseLot;
   if(_16_LadderMult > 1.0 && have >= 4)
   {
      double maxOpen = 0.0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!Exec_PosIsMine(i)) continue;
         double v = PositionGetDouble(POSITION_VOLUME);
         if(v > maxOpen) maxOpen = v;
      }
      if(maxOpen > 0.0) lot = maxOpen * _16_LadderMult;
   }
   if(_16_MaxLotPerOrder > 0.0 && lot > _16_MaxLotPerOrder) lot = _16_MaxLotPerOrder;
   return RiskControl_ClampLot(lot);   // cage stays supreme
}

// open one order (level = current open count) with per-order SL, NO broker TP
bool Kangaroo_Open(const int have)
{
   int dir = Kangaroo_Dir();
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return false;
   double entry = (dir == 1 ? t.ask : t.bid);
   double slD   = Kangaroo_SLDist();
   if(slD <= 0.0)
   {
      // ORDER-129 fail-closed (Codex system review SEV-1): this module PROMISES a
      // per-order SL. Risk-ATR unavailable (fresh attach / risk-TF not synced) used
      // to fall through as sl=0 -> a naked first order right after restart. Skip the
      // entry instead; the signal re-fires once the buffer is ready.
      static datetime last_log = 0;
      datetime now = TimeCurrent();
      if(now - last_log >= 60)
      {
         last_log = now;
         Print("[16] SL distance unavailable (risk-ATR not ready) - entry skipped, will retry");
      }
      return false;
   }
   double sl    = (dir == 1 ? entry - slD : entry + slD);
   double lot   = Kangaroo_NextLot(have);
   return Exec_Open(dir, lot, sl, 0.0, LAB_ENTRY_TAG + " L" + IntegerToString(have));
}

// locate newest + oldest own positions (by open time). Returns open count.
int Kangaroo_FindEnds(ulong &newestTk, ulong &oldestTk, double &newestPnl, double &oldestPnl)
{
   newestTk = 0; oldestTk = 0; newestPnl = 0.0; oldestPnl = 0.0;
   datetime tNew = 0, tOld = 0;
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsMine(i)) continue;
      n++;
      datetime pt  = (datetime)PositionGetInteger(POSITION_TIME);
      ulong    tk  = PositionGetInteger(POSITION_TICKET);
      double   pnl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(newestTk == 0 || pt >= tNew) { tNew = pt; newestTk = tk; newestPnl = pnl; }
      if(oldestTk == 0 || pt <  tOld) { tOld = pt; oldestTk = tk; oldestPnl = pnl; }
   }
   return n;
}

// exit 1: exactly one open order - managed TP at TpSingleAtrMult x Risk-ATR
// (managed close, not broker TP: one exit owner, no per-leg broker TP ever)
bool Kangaroo_SingleTPHit()
{
   double dist = Indi_RiskATR(1) * _16_TpSingleAtrMult;
   if(dist <= 0.0) return false;
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsMine(i)) continue;
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      long   type = PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY)  return (t.bid >= open + dist);
      if(type == POSITION_TYPE_SELL) return (t.ask <= open - dist);
   }
   return false;
}

// all exits, in priority order. Returns true if the whole side closed this tick.
bool Kangaroo_ManageExits()
{
   int have = Exec_CountAll();
   if(have <= 0)
   {
      if(g_k16_pair_a != 0 || g_k16_pair_b != 0)
      {
         g_k16_pair_a = 0; g_k16_pair_b = 0;
         Kangaroo_PairPersist();
      }
      g_k16_closeall_pending = false;
      return false;
   }

   // ORDER-132b (Codex K4): an armed full-basket close is finished FIRST -
   // partial success changes have/net, so its original predicate cannot be
   // trusted to re-fire.
   if(g_k16_closeall_pending) return Kangaroo_CloseBasket();

   // ORDER-132/132b (F3, K1/K2/K3): reconcile an armed pair-close intent.
   // While any slot is live, the intent owns the tick: no other exits are
   // evaluated and (via OnTick) no grid adds - never add exposure on top of an
   // unresolved liquidation.
   if(g_k16_pair_a != 0 || g_k16_pair_b != 0)
   {
      bool aOpen = Kangaroo_PairSlotOpen(g_k16_pair_a);
      bool bOpen = Kangaroo_PairSlotOpen(g_k16_pair_b);
      Kangaroo_PairPersist();
      if(aOpen || bOpen)
      {
         static datetime last_log = 0;
         datetime now = TimeCurrent();
         if(now - last_log >= 60)
         {
            last_log = now;
            PrintFormat("[K16] pair-close intent unresolved (a=%I64u b=%I64u, retcode=%d) - retrying",
                        g_k16_pair_a, g_k16_pair_b, (int)g_trade.ResultRetcode());
         }
         return true;
      }
   }

   double net = Exec_BasketProfit();

   // exit 1: single-order TP (original TP_80 role)
   if(have == 1 && Kangaroo_SingleTPHit())
      return Kangaroo_CloseBasket();   // ORDER-132b (K4): broker-flat proof or retry

   // exit 2: basket net-$ close (dollar-true replacement of the original's
   // unweighted pip-sum 160 - the confirmed real-loss-at-"TP" defect)
   if(have >= 2 && _16_BasketTpUsdPer01 > 0.0)
   {
      double target = _16_BasketTpUsdPer01 * (Exec_TotalLots() / 0.01);
      if(target > 0.0 && net >= target)
         return Kangaroo_CloseBasket();
   }

   // exit 4 (ladder_flatten, default OFF): deep ladder + controlled loss ->
   // flatten the side (the de-facto DD-release that let the original survive
   // 2024-11-06; explicit module here, A/B separately per spec decision 5)
   if(_16_FlattenOn && have >= _16_FlattenMinOrders && net >= -_16_MaxControlledLossUsd)
   {
      PrintFormat("[K16] ladder_flatten: %d orders, net %.2f >= -%.2f -> close all",
                  have, net, _16_MaxControlledLossUsd);
      return Kangaroo_CloseBasket();
   }

   // exit 3: overlap pair-close - newest (big/near) + oldest (deep red) close
   // together when their combined net-$ clears the threshold ("intelligent
   // overlapping system" - the confirmed DD-eater of the original).
   // ORDER-132b (Codex K1): the intent is armed (and persisted) BEFORE any close
   // is sent - a double reject must not lose the decision, because prices move
   // and the pair predicate is not guaranteed to be true again next tick.
   // (Slots can only be empty here: a live intent already returned above.)
   if(have >= _16_OverlapMinOrders && _16_OverlapMinUsd > 0.0)
   {
      ulong nTk, oTk; double nP, oP;
      int n = Kangaroo_FindEnds(nTk, oTk, nP, oP);
      if(n >= _16_OverlapMinOrders && nTk != 0 && oTk != 0 && nTk != oTk &&
         (nP + oP) >= _16_OverlapMinUsd)
      {
         PrintFormat("[K16] overlap pair-close: newest %I64u (%.2f) + oldest %I64u (%.2f) = %.2f >= %.2f",
                     nTk, nP, oTk, oP, nP + oP, _16_OverlapMinUsd);
         g_k16_pair_a = nTk;
         g_k16_pair_b = oTk;
         Kangaroo_PairPersist();
         // close + broker-state reconcile (never trust call results alone - 129
         // doctrine). DryRun: legs remain but the intent stays armed and keeps
         // logging intents (no real writes: PairPersist is DryRun-inert).
         bool aOpen = Kangaroo_PairSlotOpen(g_k16_pair_a);
         bool bOpen = Kangaroo_PairSlotOpen(g_k16_pair_b);
         Kangaroo_PairPersist();
         if(aOpen || bOpen)
         {
            PrintFormat("[K16] pair-close unresolved this tick (a=%I64u b=%I64u) - intent armed, retrying",
                        g_k16_pair_a, g_k16_pair_b);
            return true;   // own the tick: no adds on top of an in-flight liquidation
         }
         // both broker-confirmed gone - side still open, not a full basket close
      }
   }

   return false;
}

// grid add: ADVERSE moves only, distance-only trigger (no signal confirm -
// matches the original fxDreema grid), intrabar like the original ladders.
void Kangaroo_TryAdd()
{
   int dir  = Kangaroo_Dir();
   int have = Exec_CountDir(dir);
   if(have <= 0) return;
   if(have >= _16_MaxOrdersPerSide) return;    // HARD cap (a real one)
   if(!RiskControl_AllowNewOrder()) return;    // cage: halt + deposit load

   double step = Kangaroo_StepPrice(have);
   if(step <= 0.0) return;
   double ref = Kangaroo_ExtremePrice(dir);
   if(ref <= 0.0) return;

   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return;
   bool adverse = (dir == 1 ? (t.ask <= ref - step) : (t.bid >= ref + step));
   if(!adverse) return;

   Kangaroo_Open(have);
}

// first entry: market order at bar open only, needs a valid RSI-fade signal
void Kangaroo_TryFirstEntry(const bool newBar)
{
   if(!newBar) return;                       // bar-open gate (spec: entry at bar open)
   if(Exec_CountAll() > 0) return;
   if(!RiskControl_AcctGateOK()) return;     // acct-DD gate (no-op unless enabled)
   if(!RiskControl_AllowNewOrder()) return;

   EntrySignal s = Entry_Evaluate();
   if(!s.valid) return;
   Kangaroo_Open(0);
}

// whole entry-16 pipeline. Always returns true (LabCore short-circuit guard).
bool Kangaroo_OnTick()
{
   datetime b = iTime(_Symbol, _Period, 0);
   bool newBar = (b != g_k16_last_bar);
   if(newBar) g_k16_last_bar = b;

   // (1) cage hard kill first - unchanged supremacy
   if(RiskControl_CheckDD()) return true;
   if(RiskControl_IsHalted()) return true;

   // (1b) emergency equity-DD close-all (ORDER-072 decision 6: 70%, tighter
   // than the original's UNVERIFIED 80% stop, and implemented for real).
   // With default ProtectLevel the cage KillDD (25%) halts long before this
   // fires - this is the ultimate backstop for loosened-cage configurations.
   if(_16_EmergencyDDPct > 0.0 && Exec_CountAll() > 0 &&
      RiskControl_CurrentDDPct() >= _16_EmergencyDDPct)
   {
      PrintFormat("[K16] EMERGENCY close-all: equity DD %.2f%% >= %.2f%%",
                  RiskControl_CurrentDDPct(), _16_EmergencyDDPct);
      Kangaroo_CloseBasket();   // ORDER-132b (K4): broker-flat proof or per-tick retry
      return true;
   }

   // (2) exits - this module is the single exit owner
   if(Kangaroo_ManageExits()) return true;

   // (3) grid adds (adverse-only, intrabar)
   Kangaroo_TryAdd();

   // (4) first entry at bar open
   Kangaroo_TryFirstEntry(newBar);
   return true;
}

#endif // BOSS_LAB_KANGAROO_MQH
