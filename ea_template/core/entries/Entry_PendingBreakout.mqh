// A10 C2 port 2026-11-03: ported from the untracked local D:\EA_LAB file core/entries/Entry_PendingBreakout.mqh
// sha256 7ff768556bbb44af6c7217a0932eeef4ec7ad2d38b996b94fd8ee0cb8abe0577; renumbered 19 -> 29 (inputs _19_* -> _29_*). Logic unchanged
// except two fail-closed review fixes (marked "A10 C2 review fix"): the new-bar ladder refresh
// re-arms only after the old pendings are confirmed gone, and a staged partial TP fires once per ticket.
//+------------------------------------------------------------------+
//| Entry_PendingBreakout.mqh (V2) - Entry 29 Pending Stop Ladder    |
//| Multi-level BUY STOP above range High, SELL STOP below range Low |
//| Fixed SL & TP per leg (Risk-Reward 1:4 default, e.g. 5.00/20.00)  |
//| OCO: when one direction triggers, opposite pendings are cancelled|
//| RefreshOnNewBar: adapts pending orders to new range while flat   |
//| Advanced Extensions: SD/ATR box, EMA Trend Filter, Sizing modes, |
//| Pullback Martingale, Asymmetric Counter-Hedge & BE Profit Lock   |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_ENTRY_PENDING_BREAKOUT_MQH
#define BOSS_LAB_ENTRY_PENDING_BREAKOUT_MQH

#include "IEntry.mqh"
#include "../Indicators.mqh"
#include "../Execution.mqh"
#include "../RiskControl.mqh"
#include "../MoneyManagement.mqh"

#ifndef LAB_ENTRY_TAG
#define LAB_ENTRY_TAG "29_PendingBreakout"
#endif

// Recompile-safe internal state
datetime g_pb_last_bar = 0;
ulong    g_pb_partial_done[];   // tickets already partially closed by the staged-TP exit

void PendingBreakout_Init()
{
   g_pb_last_bar = 0;
   ArrayResize(g_pb_partial_done, 0);
}

EntrySignal Entry_Evaluate()
{
   return Entry_MakeNone("Entry 29 owns execution");
}

int PB_CountPendingDir(const int dir)
{
   int n = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!Exec_OrdIsMine(i)) continue;
      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(dir == 1 && (type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_BUY_LIMIT)) n++;
      else if(dir == 2 && (type == ORDER_TYPE_SELL_STOP || type == ORDER_TYPE_SELL_LIMIT)) n++;
      else if(dir == 0) n++;
   }
   return n;
}

void PB_CancelPendingDir(const int dir)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!Exec_OrdIsMine(i)) continue;
      ulong tk = OrderGetTicket(i);
      if(tk == 0) continue;
      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      bool shouldDelete = false;
      if(dir == 1 && (type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_BUY_LIMIT)) shouldDelete = true;
      else if(dir == 2 && (type == ORDER_TYPE_SELL_STOP || type == ORDER_TYPE_SELL_LIMIT)) shouldDelete = true;
      else if(dir == 0) shouldDelete = true;
      
      if(shouldDelete)
      {
         if(DryRun)
         {
            PrintFormat("[DRYRUN] PB cancel pending %I64u dir=%d", tk, dir);
            continue;
         }
         if(Exec_CancelOrderTicket(tk))
            PrintFormat("[PB] pending cancelled %I64u dir=%d", tk, dir);
         else
            PrintFormat("[PB] pending cancel FAILED %I64u retcode=%d", tk, (int)g_trade.ResultRetcode());
      }
   }
}

bool PB_PlacePending(const int direction, const bool isStop, double lot,
                     double price, const double sl, const double tp,
                     const datetime expiration, const string comment,
                     const ENUM_TRADE_INTENT intent)
{
   return Exec_PlacePendingIntent(intent, direction, isStop, lot, price, sl, tp, expiration, comment);
}

bool PB_ArmLadder()
{
   if(!RiskControl_AllowNewOrder()) return false;
   if(Exec_NewsBlocked() || Exec_MacroBlocked()) return false;
   if(!Exec_SpreadOK()) return false;
   
   // Session hour check (broker server time / TimeCurrent)
   if(_29_HourFrom != _29_HourTo)
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int h = dt.hour;
      bool inSession = (_29_HourFrom <= _29_HourTo)
                          ? (h >= _29_HourFrom && h < _29_HourTo)
                          : (h >= _29_HourFrom || h < _29_HourTo);
      if(!inSession) return false;
   }
   
   int lookback = (_29_LookbackBars >= 2 ? _29_LookbackBars : 30);
   double hi = 0.0, lo = 0.0;
   
   // 1. Box trigger calculation
   if(_29_BoxType == 0) // Donchian High/Low
   {
      hi = Indi_HighestHigh(lookback, 1);
      lo = Indi_LowestLow(lookback, 1);
   }
   else if(_29_BoxType == 1) // Standard Deviation / Bollinger Bands
   {
      double sum = 0.0;
      for(int b = 1; b <= lookback; b++) sum += iClose(_Symbol, _Period, b);
      double ma = sum / lookback;
      double var = 0.0;
      for(int b = 1; b <= lookback; b++) { double diff = iClose(_Symbol, _Period, b) - ma; var += diff * diff; }
      double sd = MathSqrt(var / lookback);
      hi = ma + _29_SdMult * sd;
      lo = ma - _29_SdMult * sd;
   }
   else if(_29_BoxType == 2) // Keltner / ATR Bands
   {
      double sum = 0.0;
      for(int b = 1; b <= lookback; b++) sum += iClose(_Symbol, _Period, b);
      double ma = sum / lookback;
      double atr = Indi_ATR(1);
      if(atr <= 0.0) atr = 500.0 * Indi_Point();
      hi = ma + _29_SdMult * atr;
      lo = ma - _29_SdMult * atr;
   }
   
   if(hi <= 0.0 || lo <= 0.0) return false;
   
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return false;
   
   // 2. Trend Filter check
   bool allowBuy = true;
   bool allowSell = true;
   if(_29_TrendFilter == 1)
   {
      int emaHandle = iMA(_Symbol, _Period, _29_FilterEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(emaHandle != INVALID_HANDLE)
      {
         double emaBuf[];
         if(CopyBuffer(emaHandle, 0, 1, 1, emaBuf) > 0)
         {
            double emaVal = emaBuf[0];
            if(t.bid < emaVal) allowBuy = false;
            if(t.ask > emaVal) allowSell = false;
         }
         IndicatorRelease(emaHandle);
      }
   }
   
   double point = Indi_Point();
   double stopLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   double spread = t.ask - t.bid;
   double minDistance = MathMax(stopLevel, spread * 1.5);
   
   double buyBase = hi + _29_BufferPoints * point;
   double sellBase = lo - _29_BufferPoints * point;
   
   // Protect against placing stops too close to market price
   if(buyBase <= t.ask + minDistance) buyBase = t.ask + minDistance;
   if(sellBase >= t.bid - minDistance) sellBase = t.bid - minDistance;
   
   datetime expireTime = 0;
   if(_29_ExpireMinutes > 0)
      expireTime = TimeCurrent() + (datetime)(_29_ExpireMinutes * 60);
      
   double lot = _29_LotSize;
   if(lot <= 0.0) lot = 0.01;
   
   // Volatility Regime calculation
   int  activeRecovery = _29_RecoveryMode;
   int  activeLotMode  = _29_LotMode;
   int  activeLegs     = _29_LadderLegs;
   
   double atr = Indi_ATR(1);
   if(atr <= 0.0) atr = point * 500.0;
   
   if(_29_AutoRegime)
   {
      double sumRange = 0.0;
      int baseBars = 50;
      for(int b = 1; b <= baseBars; b++)
         sumRange += (iHigh(_Symbol, _Period, b) - iLow(_Symbol, _Period, b));
      double baseAtr = (baseBars > 0 ? sumRange / baseBars : atr);
      if(baseAtr <= 0.0) baseAtr = atr;
      double atrRatio = (baseAtr > 0.0 ? atr / baseAtr : 1.0);
      
      if(atrRatio >= _29_RegimeAtrThreshold)
      {
         activeRecovery = 0; // Pure breakout ladder
         activeLotMode  = 2; // Inverted pyramid
         activeLegs     = 4;
      }
      else
      {
         activeRecovery = 1; // Pullback recovery
         activeLotMode  = 0;
         activeLegs     = 1;
      }
   }
   else
   {
      activeLegs = (activeRecovery == 1 || _29_HedgeMode == 1 || _29_HedgeMode == 2)
                   ? 1
                   : (_29_LadderLegs >= 1 ? _29_LadderLegs : 1);
   }
   
   double step   = (_29_UseATR || _29_SpacingMode == 1 ? NormalizeDouble(atr * _29_AtrStepMult, _Digits)
                                                       : (_29_StepPoints > 0.0 ? _29_StepPoints * point : 500.0 * point));
   double slDist = (_29_UseATR ? NormalizeDouble(atr * _29_AtrSlMult, _Digits)
                               : (_29_SlPoints > 0.0 ? _29_SlPoints * point : 500.0 * point));
   double tpDist = (_29_UseATR ? NormalizeDouble(atr * _29_AtrTpMult, _Digits)
                               : (_29_TpPoints > 0.0 ? _29_TpPoints * point : 2000.0 * point));
   
   // Place Buy Stop Ladder
   if(allowBuy)
   {
      for(int k = 0; k < activeLegs; k++)
      {
         double kDist = k * step;
         if(_29_SpacingMode == 2) kDist = k * step * (1.0 + k * 0.3); // Widening
         
         double legLot = lot;
         if(activeLotMode == 1) legLot = Exec_NormalizeLot(lot * (1.0 + k * 0.5));
         else if(activeLotMode == 2) legLot = Exec_NormalizeLot(lot * (1.0 + (activeLegs - 1 - k) * 0.5));
         
         double legTP = tpDist;
         if(_29_ExitMode == 3) legTP = (1000.0 + k * 500.0) * point; // Staged TP
         
         double legPrice = NormalizeDouble(buyBase + kDist, _Digits);
         double legSL    = NormalizeDouble(legPrice - slDist, _Digits);
         double legFinalTP = (legTP > 0.0 ? NormalizeDouble(legPrice + legTP, _Digits) : 0.0);
         string comment  = "PB_BUY_L" + IntegerToString(k + 1);
         PB_PlacePending(1, true, legLot, legPrice, legSL, legFinalTP, expireTime, comment, INTENT_TREND_ENTRY);
      }
   }
   
   // Place Sell Stop Ladder
   if(allowSell)
   {
      for(int k = 0; k < activeLegs; k++)
      {
         double kDist = k * step;
         if(_29_SpacingMode == 2) kDist = k * step * (1.0 + k * 0.3); // Widening
         
         double legLot = lot;
         if(activeLotMode == 1) legLot = Exec_NormalizeLot(lot * (1.0 + k * 0.5));
         else if(activeLotMode == 2) legLot = Exec_NormalizeLot(lot * (1.0 + (activeLegs - 1 - k) * 0.5));
         
         double legTP = tpDist;
         if(_29_ExitMode == 3) legTP = (1000.0 + k * 500.0) * point; // Staged TP
         
         double legPrice = NormalizeDouble(sellBase - kDist, _Digits);
         double legSL    = NormalizeDouble(legPrice + slDist, _Digits);
         double legFinalTP = (legTP > 0.0 ? NormalizeDouble(legPrice - legTP, _Digits) : 0.0);
         string comment  = "PB_SELL_L" + IntegerToString(k + 1);
         PB_PlacePending(2, true, legLot, legPrice, legSL, legFinalTP, expireTime, comment, INTENT_TREND_ENTRY);
      }
   }
   
   return true;
}

void PB_ManageTrailingStop(const double trailPts)
{
   if(trailPts <= 0.0) return;
   double point = Indi_Point();
   double trailDist = trailPts * point;
   
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsDirectional(i)) continue;
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      long type        = PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL     = PositionGetDouble(POSITION_SL);
      double curTP     = PositionGetDouble(POSITION_TP);
      
      if(type == POSITION_TYPE_BUY)
      {
         if(t.bid - openPrice >= trailDist)
         {
            double newSL = NormalizeDouble(t.bid - trailDist, _Digits);
            if(curSL == 0.0 || newSL > curSL + point * 5.0)
            {
               Exec_ModifyPosition(ticket, newSL, curTP);
            }
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         if(openPrice - t.ask >= trailDist)
         {
            double newSL = NormalizeDouble(t.ask + trailDist, _Digits);
            if(curSL == 0.0 || newSL < curSL - point * 5.0)
            {
               Exec_ModifyPosition(ticket, newSL, curTP);
            }
         }
      }
   }
}

void PB_ManageBreakEvenLock()
{
   if(_29_BeTriggerPts <= 0.0) return;
   double point = Indi_Point();
   double trigDist = _29_BeTriggerPts * point;
   double lockDist = _29_BeLockPts * point;
   
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsMine(i)) continue;
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      long type        = PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL     = PositionGetDouble(POSITION_SL);
      double curTP     = PositionGetDouble(POSITION_TP);
      
      if(type == POSITION_TYPE_BUY)
      {
         if(t.bid - openPrice >= trigDist)
         {
            double beSL = NormalizeDouble(openPrice + lockDist, _Digits);
            if(curSL == 0.0 || beSL > curSL + point * 2.0)
            {
               Exec_ModifyPosition(ticket, beSL, curTP);
            }
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         if(openPrice - t.ask >= trigDist)
         {
            double beSL = NormalizeDouble(openPrice - lockDist, _Digits);
            if(curSL == 0.0 || beSL < curSL - point * 2.0)
            {
               Exec_ModifyPosition(ticket, beSL, curTP);
            }
         }
      }
   }
}

void PB_ManageStagedExits()
{
   double point = Indi_Point();
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return;
   
   // (A) Partial Close at _29_PartialTpPts
   if(_29_PartialTpPts > 0.0 && _29_PartialClosePct > 0.0)
   {
      double trigDist = _29_PartialTpPts * point;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!Exec_PosIsMine(i)) continue;
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         
         double vol = PositionGetDouble(POSITION_VOLUME);
         double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         if(vol <= minLot) continue;
         
         long type        = PositionGetInteger(POSITION_TYPE);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double curSL     = PositionGetDouble(POSITION_SL);
         double curTP     = PositionGetDouble(POSITION_TP);
         string comment   = PositionGetString(POSITION_COMMENT);
         
         if(StringFind(comment, "_PCLOSE") >= 0) continue;
         // A10 C2 review fix: nothing ever set the _PCLOSE marker, so a profitable position was
         // partially closed again on every tick. Record each ticket once it has been staged.
         if(Exec_TicketInList(ticket, g_pb_partial_done)) continue;

         bool trigger = false;
         if(type == POSITION_TYPE_BUY && (t.bid - openPrice >= trigDist)) trigger = true;
         if(type == POSITION_TYPE_SELL && (openPrice - t.ask >= trigDist)) trigger = true;
         
         if(trigger)
         {
            double closeVol = Exec_NormalizeLot(vol * (_29_PartialClosePct / 100.0));
            if(closeVol > 0.0 && closeVol < vol)
            {
               // Latch completion only on a CONFIRMED reduction: a server-accepted retcode
               // (Exec_ClosePartialTicket) AND the position re-read with less volume. Otherwise
               // nothing is recorded and the next tick retries.
               bool reduced = false;
               if(Exec_ClosePartialTicket(ticket, closeVol))
                  reduced = (DryRun || (PositionSelectByTicket(ticket) && PositionGetDouble(POSITION_VOLUME) < vol));
               if(reduced)
               {
                  int pn = ArraySize(g_pb_partial_done);
                  ArrayResize(g_pb_partial_done, pn + 1);
                  g_pb_partial_done[pn] = ticket;
                  PrintFormat("[PB_STAGED] Partial TP closed %.2f lots of ticket %d (remaining=%.2f)",
                              closeVol, ticket, vol - closeVol);
                  double lockDist = (_29_BeLockPts > 0.0 ? _29_BeLockPts * point : 20.0 * point);
                  double beSL = (type == POSITION_TYPE_BUY ? openPrice + lockDist : openPrice - lockDist);
                  Exec_ModifyPosition(ticket, NormalizeDouble(beSL, _Digits), curTP);
               }
            }
         }
      }
   }
   
   // (B) Chandelier ATR Trailing Stop (ExitMode == 2)
   if(_29_ExitMode == 2)
   {
      double atr = Indi_ATR(1);
      if(atr <= 0.0) atr = point * 500.0;
      double chanDist = NormalizeDouble(atr * _29_ChandelierMult, _Digits);
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!Exec_PosIsMine(i)) continue;
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         
         long type    = PositionGetInteger(POSITION_TYPE);
         double curSL = PositionGetDouble(POSITION_SL);
         double curTP = PositionGetDouble(POSITION_TP);
         
         if(type == POSITION_TYPE_BUY)
         {
            double hi = Indi_HighestHigh(10, 1);
            double newSL = NormalizeDouble(hi - chanDist, _Digits);
            if(newSL > curSL + point * 5.0 && newSL < t.bid - point * 10.0)
            {
               Exec_ModifyPosition(ticket, newSL, curTP);
            }
         }
         else if(type == POSITION_TYPE_SELL)
         {
            double lo = Indi_LowestLow(10, 1);
            double newSL = NormalizeDouble(lo + chanDist, _Digits);
            if((curSL == 0.0 || newSL < curSL - point * 5.0) && newSL > t.ask + point * 10.0)
            {
               Exec_ModifyPosition(ticket, newSL, curTP);
            }
         }
      }
   }
}

void PB_ManageAsymmetricHedge()
{
   int buyPos  = Exec_CountDirectionalDir(1);
   int sellPos = Exec_CountDirectionalDir(2);
   if(buyPos == 0 && sellPos == 0) return;
   
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return;
   double point = Indi_Point();
   
   // 1. If both Main and Hedge are active -> Basket PnL check
   if(buyPos > 0 && sellPos > 0)
   {
      double netProfit = 0.0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!Exec_PosIsMine(i)) continue;
         netProfit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      }
      if(netProfit >= 2.0)
      {
         PrintFormat("[PB_ASYM_HEDGE] Basket net profit reached $%.2f -> Closing all positions", netProfit);
         Exec_CloseAll();
         return;
      }
   }
   
   // 2. If Buy is active and Flat on Sell -> ensure counter-hedge Sell Stops exist
   if(buyPos > 0 && sellPos == 0)
   {
      int hedgePendings = 0;
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         if(!Exec_OrdIsMine(i)) continue;
         if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP)
         {
            string comm = OrderGetString(ORDER_COMMENT);
            if(StringFind(comm, "PB_HEDGE_SELL") >= 0) hedgePendings++;
         }
      }
      
      if(hedgePendings == 0)
      {
         double initialOpen = 0.0;
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            if(!Exec_PosIsMine(i)) continue;
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
               initialOpen = PositionGetDouble(POSITION_PRICE_OPEN);
               break;
            }
         }
         
         if(initialOpen > 0.0)
         {
            double atr = Indi_ATR(1);
            if(atr <= 0.0) atr = point * 500.0;
            double hStep = (_29_SpacingMode == 1 ? atr * _29_AtrStepMult : _29_HedgeStepPts * point);
            for(int k = 1; k <= _29_HedgeLegs; k++)
            {
               double hPrice = NormalizeDouble(initialOpen - k * hStep, _Digits);
               double hLot   = Exec_NormalizeLot(_29_HedgeStartLot * k); // Linear: 0.01, 0.02, 0.03...
               if(hLot > 0.0 && hPrice < t.bid - 50.0 * point)
               {
                  string comm = "PB_HEDGE_SELL_L" + IntegerToString(k);
                  PB_PlacePending(2, true, hLot, hPrice, 0.0, 0.0, 0, comm, INTENT_HEDGE_OPEN);
               }
            }
         }
      }
   }
   // 3. If Sell is active and Flat on Buy -> ensure counter-hedge Buy Stops exist
   else if(sellPos > 0 && buyPos == 0)
   {
      int hedgePendings = 0;
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         if(!Exec_OrdIsMine(i)) continue;
         if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP)
         {
            string comm = OrderGetString(ORDER_COMMENT);
            if(StringFind(comm, "PB_HEDGE_BUY") >= 0) hedgePendings++;
         }
      }
      
      if(hedgePendings == 0)
      {
         double initialOpen = 0.0;
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            if(!Exec_PosIsMine(i)) continue;
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            {
               initialOpen = PositionGetDouble(POSITION_PRICE_OPEN);
               break;
            }
         }
         
         if(initialOpen > 0.0)
         {
            double atr = Indi_ATR(1);
            if(atr <= 0.0) atr = point * 500.0;
            double hStep = (_29_SpacingMode == 1 ? atr * _29_AtrStepMult : _29_HedgeStepPts * point);
            for(int k = 1; k <= _29_HedgeLegs; k++)
            {
               double hPrice = NormalizeDouble(initialOpen + k * hStep, _Digits);
               double hLot   = Exec_NormalizeLot(_29_HedgeStartLot * k); // Linear: 0.01, 0.02, 0.03...
               if(hLot > 0.0 && hPrice > t.ask + 50.0 * point)
               {
                  string comm = "PB_HEDGE_BUY_L" + IntegerToString(k);
                  PB_PlacePending(1, true, hLot, hPrice, 0.0, 0.0, 0, comm, INTENT_HEDGE_OPEN);
               }
            }
         }
      }
   }
}

void PB_ManagePullbackRecovery()
{
   int buyPos  = Exec_CountDirectionalDir(1);
   int sellPos = Exec_CountDirectionalDir(2);
   if(buyPos == 0 && sellPos == 0) return;
   
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return;
   double point = Indi_Point();

   double atr = Indi_ATR(1);
   if(atr <= 0.0) atr = point * 500.0;
   double stepPts = (_29_UseATR || _29_SpacingMode == 1 ? atr / point * _29_AtrStepMult : _29_PullbackStepPts);
   if(stepPts <= 0.0) stepPts = 500.0;
   double stepDist = stepPts * point;

   if(buyPos > 0)
   {
      double initialOpen = 0.0;
      double lowestOpen  = 9999999.0;
      double totalVol    = 0.0;
      double sumPV       = 0.0;
      datetime earliestTime = 0;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!Exec_PosIsMine(i)) continue;
         if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY) continue;
         double vol = PositionGetDouble(POSITION_VOLUME);
         double pr  = PositionGetDouble(POSITION_PRICE_OPEN);
         datetime tm = (datetime)PositionGetInteger(POSITION_TIME);
         totalVol += vol;
         sumPV += pr * vol;
         if(pr < lowestOpen) lowestOpen = pr;
         if(earliestTime == 0 || tm < earliestTime)
         {
            earliestTime = tm;
            initialOpen = pr;
         }
      }
      
      double avgPrice = (totalVol > 0.0 ? sumPV / totalVol : initialOpen);
      
      // Check Basket TP (when recovery positions exist)
      if(buyPos > 1)
      {
         double basketTpPrice = avgPrice + _29_PullbackTpPts * point;
         if(t.bid >= basketTpPrice)
         {
            PrintFormat("[PB_RECOVERY] Buy Basket TP hit (avg=%.2f, cur=%.2f, vol=%.2f, pos=%d) -> Closing all",
                        avgPrice, t.bid, totalVol, buyPos);
            Exec_CloseAll();
            return;
         }
      }
      
      // Check Basket Hard SL
      if(_29_PullbackSlPts > 0.0)
      {
         double basketSlPrice = initialOpen - _29_PullbackSlPts * point;
         if(t.bid <= basketSlPrice)
         {
            PrintFormat("[PB_RECOVERY] Buy Basket Hard SL hit (initial=%.2f, cur=%.2f, pos=%d) -> Closing all",
                        initialOpen, t.bid, buyPos);
            Exec_CloseAll();
            return;
         }
      }
      
      // Check if we should add a pullback recovery step
      int recoveryStepsAdded = buyPos - 1; // initial trade is step 0
      if(recoveryStepsAdded < _29_MaxPullbackSteps)
      {
         // Next pullback level is lowestOpen - stepDist
         if(t.ask <= lowestOpen - stepDist)
         {
            double mult = MathPow(_29_PullbackMult, (double)(recoveryStepsAdded + 1));
            double nextLot = Exec_NormalizeLot(_29_LotSize * mult);
            if(nextLot > 0.0 && RiskControl_AllowNewOrder() && Exec_SpreadOK())
            {
               string comment = "PB_BUY_PB" + IntegerToString(recoveryStepsAdded + 1);
               if(Exec_OpenIntent(INTENT_GRID_ADD, 1, nextLot, 0.0, 0.0, comment, t.ask))
               {
                  PrintFormat("[PB_RECOVERY] Opened Buy pullback recovery leg %d lot=%.2f at %.2f",
                              recoveryStepsAdded + 1, nextLot, t.ask);
               }
            }
         }
      }
   }
   else if(sellPos > 0)
   {
      double initialOpen = 0.0;
      double highestOpen = 0.0;
      double totalVol    = 0.0;
      double sumPV       = 0.0;
      datetime earliestTime = 0;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!Exec_PosIsMine(i)) continue;
         if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL) continue;
         double vol = PositionGetDouble(POSITION_VOLUME);
         double pr  = PositionGetDouble(POSITION_PRICE_OPEN);
         datetime tm = (datetime)PositionGetInteger(POSITION_TIME);
         totalVol += vol;
         sumPV += pr * vol;
         if(pr > highestOpen) highestOpen = pr;
         if(earliestTime == 0 || tm < earliestTime)
         {
            earliestTime = tm;
            initialOpen = pr;
         }
      }
      
      double avgPrice = (totalVol > 0.0 ? sumPV / totalVol : initialOpen);
      
      // Check Basket TP (when recovery positions exist)
      if(sellPos > 1)
      {
         double basketTpPrice = avgPrice - _29_PullbackTpPts * point;
         if(t.ask <= basketTpPrice)
         {
            PrintFormat("[PB_RECOVERY] Sell Basket TP hit (avg=%.2f, cur=%.2f, vol=%.2f, pos=%d) -> Closing all",
                        avgPrice, t.ask, totalVol, sellPos);
            Exec_CloseAll();
            return;
         }
      }
      
      // Check Basket Hard SL
      if(_29_PullbackSlPts > 0.0)
      {
         double basketSlPrice = initialOpen + _29_PullbackSlPts * point;
         if(t.ask >= basketSlPrice)
         {
            PrintFormat("[PB_RECOVERY] Sell Basket Hard SL hit (initial=%.2f, cur=%.2f, pos=%d) -> Closing all",
                        initialOpen, t.ask, sellPos);
            Exec_CloseAll();
            return;
         }
      }
      
      // Check if we should add a pullback recovery step
      int recoveryStepsAdded = sellPos - 1; // initial trade is step 0
      if(recoveryStepsAdded < _29_MaxPullbackSteps)
      {
         // Next pullback level is highestOpen + stepDist
         if(t.bid >= highestOpen + stepDist)
         {
            double mult = MathPow(_29_PullbackMult, (double)(recoveryStepsAdded + 1));
            double nextLot = Exec_NormalizeLot(_29_LotSize * mult);
            if(nextLot > 0.0 && RiskControl_AllowNewOrder() && Exec_SpreadOK())
            {
               string comment = "PB_SELL_PB" + IntegerToString(recoveryStepsAdded + 1);
               if(Exec_OpenIntent(INTENT_GRID_ADD, 2, nextLot, 0.0, 0.0, comment, t.bid))
               {
                  PrintFormat("[PB_RECOVERY] Opened Sell pullback recovery leg %d lot=%.2f at %.2f",
                              recoveryStepsAdded + 1, nextLot, t.bid);
               }
            }
         }
      }
   }
}

bool PendingBreakout_OnTick()
{
   // (1) Hard Kill & DD Checks FIRST
   if(RiskControl_CheckDD()) return true;
   if(RiskControl_IsHalted()) return true;
   
   int buyPos   = Exec_CountDirectionalDir(1);
   int sellPos  = Exec_CountDirectionalDir(2);
   int totalPos = buyPos + sellPos;
   
   int buyPend  = PB_CountPendingDir(1);
   int sellPend = PB_CountPendingDir(2);
   
   // (2) OCO Logic: When one side triggers into position, cancel opposite pendings immediately
   // (Bypassed if Delta Neutral Straddle Lock is active: _29_HedgeMode == 3)
   if(_29_UseOCO && _29_HedgeMode != 3)
   {
      if(buyPos > 0 && sellPend > 0)
      {
         // If Asymmetric counter-hedge is active, do not cancel hedge pendings!
         for(int i = OrdersTotal() - 1; i >= 0; i--)
         {
            if(!Exec_OrdIsMine(i)) continue;
            ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            string comm = OrderGetString(ORDER_COMMENT);
            if((type == ORDER_TYPE_SELL_STOP || type == ORDER_TYPE_SELL_LIMIT) && StringFind(comm, "PB_HEDGE_") < 0)
            {
               ulong tk = OrderGetTicket(i);
               if(tk > 0) Exec_CancelOrderTicket(tk);
            }
         }
      }
      if(sellPos > 0 && buyPend > 0)
      {
         for(int i = OrdersTotal() - 1; i >= 0; i--)
         {
            if(!Exec_OrdIsMine(i)) continue;
            ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            string comm = OrderGetString(ORDER_COMMENT);
            if((type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_BUY_LIMIT) && StringFind(comm, "PB_HEDGE_") < 0)
            {
               ulong tk = OrderGetTicket(i);
               if(tk > 0) Exec_CancelOrderTicket(tk);
            }
         }
      }
   }
   
   // (2.4) Asymmetric Counter-Hedge Management
   if(_29_HedgeMode == 2 && totalPos > 0)
   {
      PB_ManageAsymmetricHedge();
   }
   
   // (2.5) Pullback Recovery Management
   if((_29_RecoveryMode == 1 || _29_HedgeMode == 1 || _29_AutoRegime) && totalPos > 0)
   {
      PB_ManagePullbackRecovery();
   }
   
   // (2.6) Break-Even Lock Management
   if(_29_ExitMode == 1 && totalPos > 0)
   {
      PB_ManageBreakEvenLock();
   }
   
   // (2.7) Staged Partial Close & Chandelier ATR Trailing
   if(totalPos > 0)
   {
      PB_ManageStagedExits();
   }
   
   // (3) Trailing Stop for open positions
   if(totalPos > 0 && _29_TrailPoints > 0.0)
   {
      PB_ManageTrailingStop(_29_TrailPoints);
   }
   
   // (4) Basket Management / Exits if configured
   Exit_ManageBasket();
   
   // (5) When Flat: manage resting pendings or arm new ladder
   if(totalPos == 0)
   {
      // Clean up any remaining hedge pendings
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         if(!Exec_OrdIsMine(i)) continue;
         string comm = OrderGetString(ORDER_COMMENT);
         if(StringFind(comm, "PB_HEDGE_") >= 0)
         {
            ulong tk = OrderGetTicket(i);
            if(tk > 0) Exec_CancelOrderTicket(tk);
         }
      }
      
      datetime barTime = iTime(_Symbol, _Period, 0);
      bool isNewBar = (barTime != g_pb_last_bar);
      if(isNewBar) g_pb_last_bar = barTime;
      
      // If no pendings exist at all -> arm fresh ladder!
      if(buyPend == 0 && sellPend == 0)
      {
         PB_ArmLadder();
      }
      // If pendings exist, but price remained flat in range:
      else if(_29_RefreshOnNewBar && isNewBar)
      {
         int lookback = (_29_LookbackBars >= 2 ? _29_LookbackBars : 30);
         double hi = 0.0, lo = 0.0;
         if(_29_BoxType == 0)
         {
            hi = Indi_HighestHigh(lookback, 1);
            lo = Indi_LowestLow(lookback, 1);
         }
         else if(_29_BoxType == 1)
         {
            double sum = 0.0;
            for(int b = 1; b <= lookback; b++) sum += iClose(_Symbol, _Period, b);
            double ma = sum / lookback;
            double var = 0.0;
            for(int b = 1; b <= lookback; b++) { double diff = iClose(_Symbol, _Period, b) - ma; var += diff * diff; }
            double sd = MathSqrt(var / lookback);
            hi = ma + _29_SdMult * sd;
            lo = ma - _29_SdMult * sd;
         }
         else if(_29_BoxType == 2)
         {
            double sum = 0.0;
            for(int b = 1; b <= lookback; b++) sum += iClose(_Symbol, _Period, b);
            double ma = sum / lookback;
            double atr = Indi_ATR(1);
            if(atr <= 0.0) atr = 500.0 * Indi_Point();
            hi = ma + _29_SdMult * atr;
            lo = ma - _29_SdMult * atr;
         }
         
         if(hi > 0.0 && lo > 0.0)
         {
            double point = Indi_Point();
            double newBuyBase = hi + _29_BufferPoints * point;
            double newSellBase = lo - _29_BufferPoints * point;
            
            double currBuyPrice = 0.0;
            double currSellPrice = 0.0;
            for(int i = OrdersTotal() - 1; i >= 0; i--)
            {
               if(!Exec_OrdIsMine(i)) continue;
               ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
               double op = OrderGetDouble(ORDER_PRICE_OPEN);
               if(ot == ORDER_TYPE_BUY_STOP && (currBuyPrice == 0.0 || op < currBuyPrice)) currBuyPrice = op;
               if(ot == ORDER_TYPE_SELL_STOP && (currSellPrice == 0.0 || op > currSellPrice)) currSellPrice = op;
            }
            
            double atr = Indi_ATR(1);
            if(atr <= 0.0) atr = 500.0 * point;
            double step = (_29_UseATR || _29_SpacingMode == 1 ? NormalizeDouble(atr * _29_AtrStepMult, _Digits)
                                                              : (_29_StepPoints > 0.0 ? _29_StepPoints * point : 500.0 * point));
            if(MathAbs(newBuyBase - currBuyPrice) >= step * 0.5 || MathAbs(newSellBase - currSellPrice) >= step * 0.5)
            {
               Print("[PB] Range shifted on new bar -> refreshing pending ladder");
               PB_CancelPendingDir(0);
               // A10 C2 review fix: re-arm only once the broker shows the old ladder gone. A
               // rejected delete would otherwise leave BOTH ladders executable.
               if(PB_CountPendingDir(0) == 0) PB_ArmLadder();
               else Print("[PB] old pending ladder not fully cancelled -> refresh skipped this bar");
            }
         }
      }
   }
   
   return true; // Entry 29 owns its tick execution
}

#endif // BOSS_LAB_ENTRY_PENDING_BREAKOUT_MQH
