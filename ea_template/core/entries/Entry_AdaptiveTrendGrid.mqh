//+------------------------------------------------------------------+
//| Entry_AdaptiveTrendGrid.mqh (V2) - Boss19 entry-owned engine.    |
//|                                                                  |
//| Trend selects one finite D1-ATR pending ladder.  Boss19 owns the |
//| ladder lifecycle and strategy exits; the shared execution and    |
//| risk cage remain the only order/risk authorities.                 |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_ENTRY_ADAPTIVETRENDGRID_MQH
#define BOSS_LAB_ENTRY_ADAPTIVETRENDGRID_MQH

#include "IEntry.mqh"

int    g_b19_atr_d1_handle = INVALID_HANDLE;
int    g_b19_armed_dir     = 0;       // 0=none, 1=UP/BUY, 2=DOWN/SELL
double g_b19_reference     = 0.0;     // flat-state reference price
double g_b19_step          = 0.0;     // step captured when this ladder armed
int    g_b19_levels         = 0;
bool   g_b19_adopted        = false;  // broker state existed before this session
bool   g_b19_ambiguous      = false;  // fail-safe: never place through ambiguity
bool   g_b19_any_leg_placed  = false;
double g_b19_target[];
bool   g_b19_leg_placed[];

void B19_ResetArm()
{
   g_b19_armed_dir = 0;
   g_b19_reference = 0.0;
   g_b19_step      = 0.0;
   g_b19_levels    = 0;
   g_b19_adopted   = false;
   g_b19_ambiguous = false;
   g_b19_any_leg_placed = false;
   ArrayResize(g_b19_target, 0);
   ArrayResize(g_b19_leg_placed, 0);
}

double B19_ReadD1ATR()
{
   if(g_b19_atr_d1_handle == INVALID_HANDLE) return 0.0;
   double value[];
   if(CopyBuffer(g_b19_atr_d1_handle, 0, 1, 1, value) < 1) return 0.0;
   if(!MathIsValidNumber(value[0]) || value[0] <= 0.0) return 0.0;
   return value[0];
}

double B19_Step()
{
   double atr = B19_ReadD1ATR();
   if(atr <= 0.0 || !MathIsValidNumber(_9_StepATRmult) || _9_StepATRmult <= 0.0)
      return 0.0;
   double step = atr * _9_StepATRmult;
   if(!MathIsValidNumber(step) || step <= 0.0) return 0.0;
   return step;
}

int B19_Levels()
{
   if(_9_MaxLevels <= 0) return 0;
   int cage = RiskControl_MaxLevels();
   if(cage <= 0) return 0;
   return (_9_MaxLevels < cage ? _9_MaxLevels : cage);
}

int B19_CurrentTrend()
{
   double fast = Indi_FastMA(0);
   double slow = Indi_SlowMA(0);
   if(!MathIsValidNumber(fast) || !MathIsValidNumber(slow) || fast <= 0.0 || slow <= 0.0)
      return 0;

   int dir = 0;
   if(fast > slow) dir = 1;
   else if(fast < slow) dir = 2;
   if(dir == 1 && TradeDir == TRADEDIR_SHORT_ONLY) return 0;
   if(dir == 2 && TradeDir == TRADEDIR_LONG_ONLY) return 0;
   return dir;
}

int B19_CountPositions(const int dir)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsMine(i)) continue;
      long type = PositionGetInteger(POSITION_TYPE);
      if(dir == 0 || (dir == 1 && type == POSITION_TYPE_BUY) ||
         (dir == 2 && type == POSITION_TYPE_SELL))
         count++;
   }
   return count;
}

int B19_PendingDirection(bool &ambiguous)
{
   int dir = 0;
   ambiguous = false;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!Exec_OrdIsMine(i)) continue;
      long type = OrderGetInteger(ORDER_TYPE);
      int orderDir = 0;
      if(type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_BUY_STOP ||
         type == ORDER_TYPE_BUY_STOP_LIMIT) orderDir = 1;
      if(type == ORDER_TYPE_SELL_LIMIT || type == ORDER_TYPE_SELL_STOP ||
         type == ORDER_TYPE_SELL_STOP_LIMIT) orderDir = 2;
      if(orderDir == 0) { ambiguous = true; continue; }
      if(dir == 0) dir = orderDir;
      else if(dir != orderDir) ambiguous = true;
   }
   return dir;
}

void B19_AdoptBrokerState(const int positions, const int pending)
{
   if(positions == 0 && pending == 0) return;
   int buys  = B19_CountPositions(1);
   int sells = B19_CountPositions(2);
   if(buys > 0 && sells > 0)
   {
      g_b19_ambiguous = true;
      Print("[B19] ambiguous broker state: both BUY and SELL positions exist - no new orders");
      return;
   }

   bool pendingAmbiguous = false;
   int pendingDir = B19_PendingDirection(pendingAmbiguous);
   int brokerDir = (buys > 0 ? 1 : (sells > 0 ? 2 : pendingDir));
   if(pendingAmbiguous || brokerDir == 0)
   {
      g_b19_ambiguous = true;
      Print("[B19] ambiguous broker pending state - no duplicate placement");
      return;
   }
   if(g_b19_armed_dir == 0)
   {
      g_b19_armed_dir = brokerDir;
      g_b19_adopted   = true;
      g_b19_reference = 0.0;
      g_b19_step      = 0.0;
      g_b19_levels    = 0;
      ArrayResize(g_b19_target, 0);
      ArrayResize(g_b19_leg_placed, 0);
      PrintFormat("[B19] adopted existing %s broker state; no ladder is placed on top",
                  (brokerDir == 1 ? "UP" : "DOWN"));
   }
   else if(g_b19_armed_dir != brokerDir)
   {
      g_b19_ambiguous = true;
      Print("[B19] armed direction disagrees with broker state - no duplicate placement");
   }
}

bool B19_PositionExists(const ulong ticket)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(PositionGetTicket(i) == ticket) return true;
   return false;
}

bool B19_ManageExits(const int buys, const int sells)
{
   if(buys > 0 && sells > 0) return true;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return true;

   if(buys > 0)
   {
      double atr = B19_ReadD1ATR();
      if(atr <= 0.0 || !MathIsValidNumber(_22_TP_ATRmult) || _22_TP_ATRmult <= 0.0)
         return false;
      double volume = 0.0;
      double value  = 0.0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!Exec_PosIsMine(i) || PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
            continue;
         double v = PositionGetDouble(POSITION_VOLUME);
         volume += v;
         value  += v * PositionGetDouble(POSITION_PRICE_OPEN);
      }
      if(volume <= 0.0) return false;
      double target = value / volume + atr * _22_TP_ATRmult;
      if(tick.bid < target) return false;
      if(!Exec_CloseAll())
         Print("[B19] UP target close incomplete - retrying");
      return true;
   }

   if(sells > 0)
   {
      double step = B19_Step();
      if(step <= 0.0) return false;
      bool acted = false;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!Exec_PosIsMine(i) || PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL)
            continue;
         ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
         double open  = PositionGetDouble(POSITION_PRICE_OPEN);
         if(tick.ask > open - step) continue;
         acted = true;
         if(!Exec_CloseTicket(ticket))
         {
            PrintFormat("[B19] DOWN leg close failed %I64u - retrying", ticket);
            return true;
         }
         if(B19_PositionExists(ticket))
         {
            PrintFormat("[B19] DOWN leg close not confirmed %I64u - retrying", ticket);
            return true;
         }
      }
      return acted;
   }
   return false;
}

bool B19_OrderMatches(const long type, const int dir, const bool isStop)
{
   bool buy = (type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_BUY_STOP ||
               type == ORDER_TYPE_BUY_STOP_LIMIT);
   bool stop = (type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP ||
                type == ORDER_TYPE_BUY_STOP_LIMIT || type == ORDER_TYPE_SELL_STOP_LIMIT);
   return ((dir == 1) == buy && isStop == stop);
}

ulong B19_FindPendingNear(const double price, const double tolerance,
                          const int dir, const bool isStop, bool &ambiguous)
{
   ambiguous = false;
   int nearCount = 0;
   int exactCount = 0;
   ulong exactTicket = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!Exec_OrdIsMine(i)) continue;
      if(MathAbs(OrderGetDouble(ORDER_PRICE_OPEN) - price) > tolerance) continue;
      nearCount++;
      if(B19_OrderMatches(OrderGetInteger(ORDER_TYPE), dir, isStop))
      {
         exactCount++;
         exactTicket = OrderGetTicket(i);
      }
   }
   if(nearCount > 1 || exactCount > 1 || (nearCount == 1 && exactCount == 0))
   {
      ambiguous = true;
      return 0;
   }
   return exactTicket;
}

double B19_LotForLevel(const int dir, const int level)
{
   double base = _41_FixedLot;
   if(!MathIsValidNumber(base) || base <= 0.0) return 0.0;
   double raw = base;
   if(dir == 1)
      raw = base * (1.0 + MathMax(0.0, _51_ProgFactor) * (level - 1));
   else
      raw = base / MathPow(MathMax(1.0, _52_ProgMult), level - 1);
   if(!MathIsValidNumber(raw) || raw <= 0.0) return 0.0;
   return RiskControl_ClampLot(raw);
}

void B19_PlaceMissing()
{
   if(g_b19_adopted || g_b19_armed_dir == 0 || g_b19_levels <= 0) return;
   if(!RiskControl_AcctGateOK() || !RiskControl_AllowNewOrder()) return;

   bool allPlaced = true;
   for(int k = 1; k <= g_b19_levels; k++)
   {
      if(g_b19_leg_placed[k]) continue;
      bool isStop = (g_b19_armed_dir == 1 && _9_PendingMode != 2);
      bool nearAmbiguous = false;
      ulong existing = B19_FindPendingNear(g_b19_target[k], g_b19_step * 0.5,
                                            g_b19_armed_dir, isStop, nearAmbiguous);
      if(nearAmbiguous)
      {
         allPlaced = false;
         PrintFormat("[B19] level %d ambiguous near target %.5f - placement refused", k, g_b19_target[k]);
         continue;
      }
      if(existing != 0)
      {
         g_b19_leg_placed[k] = true;
         g_b19_any_leg_placed = true;
         continue;
      }

      double lot = B19_LotForLevel(g_b19_armed_dir, k);
      if(lot <= 0.0 || !Stack_MarginBudgetOK(g_b19_armed_dir, lot, g_b19_target[k]))
      {
         allPlaced = false;
         continue;
      }
      string comment = "B19 L" + IntegerToString(k);
      if(Exec_PlacePending(g_b19_armed_dir, isStop, lot, g_b19_target[k], 0.0, comment))
      {
         if(DryRun || g_trade.ResultOrder() != 0)
         {
            g_b19_leg_placed[k] = true;
            g_b19_any_leg_placed = true;
         }
         else
            allPlaced = false;
      }
      else
         allPlaced = false;
   }
   if(allPlaced) Print("[B19] finite pending ladder complete");
}

void B19_Arm(const int dir)
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;
   if(!RiskControl_AcctGateOK() || !RiskControl_AllowNewOrder()) return;

   double step = B19_Step();
   int levels = B19_Levels();
   if(step <= 0.0 || levels <= 0) return;

   g_b19_armed_dir = dir;
   g_b19_reference = (dir == 1 ? tick.ask : tick.bid);
   g_b19_step      = step;
   g_b19_levels    = levels;
   g_b19_adopted   = false;
   g_b19_ambiguous = false;
   g_b19_any_leg_placed = false;
   ArrayResize(g_b19_target, levels + 1);
   ArrayResize(g_b19_leg_placed, levels + 1);
   for(int k = 0; k <= levels; k++) g_b19_leg_placed[k] = false;

   // Boss19-specific mapping: UP mode 2 is BUY LIMIT below ask; every other
   // value (including 0 and 3) is BUY STOP above ask. DOWN is always SELL LIMIT.
   bool isStop = (dir == 1 && _9_PendingMode != 2);
   for(int k = 1; k <= levels; k++)
      g_b19_target[k] = (dir == 1 ? (isStop ? g_b19_reference + k * step
                                             : g_b19_reference - k * step)
                                  : g_b19_reference + k * step);
   B19_PlaceMissing();
}

bool B19_CancelPendingAndConfirm()
{
   if(!Exec_CancelAllPending()) return false;
   return (Exec_CountPending() == 0);
}

bool AdaptiveTrendGrid_OnTick()
{
   // Boss19 owns this complete pipeline, including the hard cage calls. The
   // LabCore caller returns immediately so shared strategy exits/stack paths
   // cannot run for this build.
   if(RiskControl_CheckDD()) return true;
   if(RiskControl_IsHalted()) return true;
   if(Exit_SafetyMoneyStop()) return true;

   int positions = Exec_CountAll();
   int pending   = Exec_CountPending();
   if(positions == 0 && pending == 0 && g_b19_armed_dir != 0 &&
      (g_b19_adopted || g_b19_any_leg_placed))
      B19_ResetArm();
   B19_AdoptBrokerState(positions, pending);
   if(g_b19_ambiguous) return true;

   int buys  = B19_CountPositions(1);
   int sells = B19_CountPositions(2);
   if(B19_ManageExits(buys, sells)) return true;

   int trend = B19_CurrentTrend();
   if(g_b19_armed_dir != 0 && trend != 0 && trend != g_b19_armed_dir)
   {
      if(pending > 0 && !B19_CancelPendingAndConfirm()) return true;
      if(Exec_CountAll() > 0) return true;  // filled old legs continue their own exits
      if(Exec_CountPending() > 0) return true;
      B19_ResetArm();
      return true;
   }

   if(g_b19_armed_dir != 0)
   {
      // A ladder remains the same ladder while any leg is filled or resting.
      // Retry only its missing legs; never re-arm from a later tick's price.
      if(!g_b19_adopted) B19_PlaceMissing();
      return true;
   }
   if(Exec_CountAll() > 0 || Exec_CountPending() > 0) return true;
   if(trend == 0) return true;
   B19_Arm(trend);
   return true;
}

bool Entry_AdaptiveTrendGrid_Init()
{
   B19_ResetArm();
   if(FirstLotMode != FIRSTLOT_FIXED)
   {
      PrintFormat("[INIT] FATAL: Boss19 requires FirstLotMode=FIRSTLOT_FIXED, got %d", FirstLotMode);
      return false;
   }
   if(LotProg != PROG_NONE)
   {
      PrintFormat("[INIT] FATAL: Boss19 requires LotProg=PROG_NONE, got %d", LotProg);
      return false;
   }
   if(StackMode != STACK_SINGLE || RecoveryMode != REC_NONE || HedgeMode != HEDGE_OFF)
   {
      PrintFormat("[INIT] FATAL: Boss19 requires StackMode=90, RecoveryMode=80, HedgeMode=0 (got %d/%d/%d)",
                  StackMode, RecoveryMode, HedgeMode);
      return false;
   }
   g_b19_atr_d1_handle = iATR(_Symbol, PERIOD_D1, _0_ATR_Period);
   if(g_b19_atr_d1_handle == INVALID_HANDLE)
   {
      Print("[INIT] FATAL: Boss19 D1 ATR handle failed");
      return false;
   }
   return true;
}

void Entry_AdaptiveTrendGrid_Deinit()
{
   if(g_b19_atr_d1_handle != INVALID_HANDLE)
      IndicatorRelease(g_b19_atr_d1_handle);
   g_b19_atr_d1_handle = INVALID_HANDLE;
   B19_ResetArm();
}

// LabCore's generic compile-time seam still requires a signal function. Boss19
// never reaches that path: AdaptiveTrendGrid_OnTick owns the engine above.
EntrySignal Entry_Evaluate()
{
   return Entry_MakeNone("Boss19 entry-owned engine");
}

#endif // BOSS_LAB_ENTRY_ADAPTIVETRENDGRID_MQH
