// new_entry.py: build 31, copied from Entry_BBPinBar.mqh (sha256 59922cd901a8a6245e8dfa848e419c54d4fdf9071ce7d7722b14a90e04081c1a)
//+------------------------------------------------------------------+
//| Entry_BBPinBar.mqh (V2) - entry 31: long-tail pin bar that       |
//| pierces a Bollinger band, single shot with ATR SL/TP + breakeven.|
//|                                                                  |
//| Port of AGY GrandModular S10 (Eval_S10_KangarooTail) under       |
//| recovery R01 (single shot) and lot L01 (flat). The build owns    |
//| its pipeline: R01 moves the stop to entry +10 points at 1R, which|
//| the shared ExitManager has no mode for, and the signal is read   |
//| only while flat at a new bar, as in the source.                  |
//| The shared hard kill (ProtectLevel) runs first as the outer cage.|
//|                                                                  |
//| Per tick, in the source's order:                                 |
//|  1. account cut: (balance - equity) / balance >= _31_CutDDPct    |
//|     -> close all own positions, pause for the rest of the bar;   |
//|  2. breakeven: once price is _31_BreakevenR x risk in profit,    |
//|     the stop moves to entry +- 10 points;                        |
//|  3. any open position -> done; else only on a new bar, through   |
//|     the spread / hour filters, read the signal on the last       |
//|     closed bar: range >= 0.8 ATR, tail >= 2 x body and >= 55 %   |
//|     of the range, low below the lower band and a bull close      |
//|     (buy), or the mirror (sell);                                 |
//|  4. open one position, SL = _31_SL_ATR x ATR,                    |
//|     TP = SL x _31_TP_RR, lot = MM_FirstLot (flat).               |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_ENTRY_BB_PIN_BAR_MQH
#define BOSS_LAB_ENTRY_BB_PIN_BAR_MQH
#include "IEntry.mqh"

static int      g_bpb_bb  = INVALID_HANDLE;
static int      g_bpb_atr = INVALID_HANDLE;
static datetime g_bpb_last_bar     = 0;
static datetime g_bpb_last_cut_bar = 0;
static int      g_bpb_cuts = 0;
static int      g_bpb_be_moves = 0;

double BPB_Buf(const int h, const int buf, const int sh)
{
   if(h == INVALID_HANDLE) return 0.0;
   double v[1];
   if(CopyBuffer(h, buf, sh, 1, v) != 1) return 0.0;
   return v[0];
}

void BBPinBar_Init()
{
   g_bpb_bb  = iBands(_Symbol, PERIOD_CURRENT, _31_BBPeriod, 0, _31_BBDev, PRICE_CLOSE);
   g_bpb_atr = iATR(_Symbol, PERIOD_CURRENT, _31_AtrPeriod);
   g_bpb_last_bar = 0;
   g_bpb_last_cut_bar = 0;
   g_bpb_cuts = 0;
   g_bpb_be_moves = 0;
   if(g_bpb_bb == INVALID_HANDLE || g_bpb_atr == INVALID_HANDLE)
      Print("[31] indicator handle failed - no new positions will open");
}

void BBPinBar_Deinit()
{
   PrintFormat("[31] SUMMARY account_cuts=%d breakeven_moves=%d", g_bpb_cuts, g_bpb_be_moves);
   if(g_bpb_bb  != INVALID_HANDLE) { IndicatorRelease(g_bpb_bb);  g_bpb_bb  = INVALID_HANDLE; }
   if(g_bpb_atr != INVALID_HANDLE) { IndicatorRelease(g_bpb_atr); g_bpb_atr = INVALID_HANDLE; }
}

EntrySignal Entry_Evaluate()
{
   return Entry_MakeNone("BBPinBar self-contained");
}

double BPB_Atr()
{
   double a = BPB_Buf(g_bpb_atr, 0, 1);
   if(a <= 0.0) a = BPB_Buf(g_bpb_atr, 0, 0);
   return a;
}

// 1 = buy, -1 = sell, 0 = none (last closed bar)
int BPB_Signal()
{
   double up = BPB_Buf(g_bpb_bb, 1, 1);
   double lo = BPB_Buf(g_bpb_bb, 2, 1);
   double atr = BPB_Atr();
   if(atr <= 0.0 || up <= 0.0) return 0;
   double h1 = iHigh(_Symbol, PERIOD_CURRENT, 1), l1 = iLow(_Symbol, PERIOD_CURRENT, 1);
   double o1 = iOpen(_Symbol, PERIOD_CURRENT, 1), c1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double body = MathAbs(c1 - o1), range = h1 - l1;
   if(range < _31_MinRangeAtr * atr) return 0;
   double lowTail = MathMin(o1, c1) - l1;
   if(l1 < lo && lowTail >= _31_TailBodyMult * body && lowTail >= _31_TailRangeFrac * range && c1 > o1) return 1;
   double upTail = h1 - MathMax(o1, c1);
   if(h1 > up && upTail >= _31_TailBodyMult * body && upTail >= _31_TailRangeFrac * range && c1 < o1) return -1;
   return 0;
}

bool BPB_FiltersOK()
{
   if(_31_MaxSpreadPoints > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > _31_MaxSpreadPoints) return false;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(_31_StartHour <= _31_EndHour) return (dt.hour >= _31_StartHour && dt.hour <= _31_EndHour);
   return (dt.hour >= _31_StartHour || dt.hour <= _31_EndHour);
}

void BPB_Breakeven()
{
   if(!_31_UseBreakeven) return;
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsDirectional(i)) continue;
      long   type = PositionGetInteger(POSITION_TYPE);
      double op   = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      double cur  = PositionGetDouble(POSITION_PRICE_CURRENT);
      ulong  tk   = PositionGetInteger(POSITION_TICKET);
      if(sl <= 0.0) continue;
      double risk = MathAbs(op - sl);
      if(risk <= 0.0) continue;
      if(type == POSITION_TYPE_BUY && (cur - op) >= _31_BreakevenR * risk && sl < op)
      {
         if(Exec_ModifyPosition(tk, NormalizeDouble(op + _31_BeLockPoints * pt, _Digits), tp)) g_bpb_be_moves++;
      }
      else if(type == POSITION_TYPE_SELL && (op - cur) >= _31_BreakevenR * risk && sl > op)
      {
         if(Exec_ModifyPosition(tk, NormalizeDouble(op - _31_BeLockPoints * pt, _Digits), tp)) g_bpb_be_moves++;
      }
   }
}

bool BBPinBar_OnTick()
{
   // 0. shared hard kill (outer cage) always first
   if(RiskControl_CheckDD()) return true;
   if(RiskControl_IsHalted()) return true;

   const datetime bar = iTime(_Symbol, _Period, 0);
   const bool newBar = (bar != g_bpb_last_bar);
   if(newBar) g_bpb_last_bar = bar;

   // 1. account cut, then pause for the rest of the bar
   if(_31_CutDDPct > 0.0)
   {
      double bal = AccountInfoDouble(ACCOUNT_BALANCE);
      double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
      if(bal > 0.0 && (bal - eq) / bal * 100.0 >= _31_CutDDPct && Exec_CountAll() > 0)
      {
         PrintFormat("[31] ACCOUNT CUT: (balance-equity)/balance %.2f%% >= %.2f%% -> close all", (bal - eq) / bal * 100.0, _31_CutDDPct);
         if(!Exec_CloseAll()) Print("[31] account cut: residual exposure remains - retrying next tick");
         g_bpb_cuts++;
         g_bpb_last_cut_bar = bar;
         return true;
      }
   }
   if(_31_PauseBarAfterCut && bar == g_bpb_last_cut_bar) return true;

   // 2. breakeven, 3. one position at a time
   BPB_Breakeven();
   if(Exec_CountDirectionalDir(0) > 0) return true;
   if(!newBar) return true;
   if(!BPB_FiltersOK()) return true;

   int sig = BPB_Signal();
   if(sig == 0) return true;
   int dir = (sig == 1 ? 1 : 2);
   if(!Regime_AllowsEntryDirection(dir)) return true;
   if(!RiskControl_AcctGateOK()) return true;
   if(!RiskControl_AllowNewOrder()) return true;

   // 4. one position with ATR SL and R-multiple TP
   double atr = BPB_Atr();
   if(atr <= 0.0) return true;
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double slDist = _31_SL_ATR * atr;
   double tpDist = slDist * _31_TP_RR;
   double lot = Exec_NormalizeLot(RiskControl_ClampLot(MM_FirstLot(pt > 0.0 ? slDist / pt : 0.0)));
   if(lot <= 0.0) return true;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK), bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(dir == 1)
      Exec_Open(1, lot, NormalizeDouble(ask - slDist, _Digits), NormalizeDouble(ask + tpDist, _Digits), LAB_ENTRY_TAG + " BUY");
   else
      Exec_Open(2, lot, NormalizeDouble(bid + slDist, _Digits), NormalizeDouble(bid - tpDist, _Digits), LAB_ENTRY_TAG + " SELL");
   return true;
}

#endif // BOSS_LAB_ENTRY_BB_PIN_BAR_MQH
