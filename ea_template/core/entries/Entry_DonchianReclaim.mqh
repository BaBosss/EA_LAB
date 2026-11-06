// new_entry.py: build 32, copied from Entry_DonchianReclaim.mqh (sha256 e42cd70f849d5e584c2935696c74b40d6022509cb8d3e1f60e04698ec52a26db)
//+------------------------------------------------------------------+
//| Entry_DonchianReclaim.mqh (V2) - entry 32: Donchian breakout     |
//| then an EMA pullback reclaim, single shot with ATR SL/TP and     |
//| breakeven.                                                       |
//|                                                                  |
//| Port of AGY GrandModular S04 (Eval_S04_DonchianPullback) under   |
//| recovery R01 (single shot) and lot L01 (flat). The build owns    |
//| its pipeline for the same reasons as entry 31 (breakeven at 1R,  |
//| signal read only while flat at a new bar).                       |
//|                                                                  |
//| The signal keeps state, exactly as the source does: a close      |
//| beyond the Donchian channel of bars 2..N+1 and beyond the slow   |
//| EMA arms a direction and resets its age; the age grows by one on |
//| every call made on a new bar. Calls happen only while flat, past |
//| the filters, so the age counts evaluated bars, not clock bars.   |
//| An armed direction fires when, within 12 evaluated bars and with |
//| ADX >= _32_AdxMin, the last closed bar touched the fast EMA and  |
//| closed back across it, no more than _32_MaxDistAtr x ATR away.   |
//| Firing disarms (age 999).                                        |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_ENTRY_DONCHIAN_RECLAIM_MQH
#define BOSS_LAB_ENTRY_DONCHIAN_RECLAIM_MQH
#include "IEntry.mqh"

static int      g_dr_emaF = INVALID_HANDLE;
static int      g_dr_emaS = INVALID_HANDLE;
static int      g_dr_adx  = INVALID_HANDLE;
static int      g_dr_atr  = INVALID_HANDLE;
static datetime g_dr_last_bar     = 0;
static datetime g_dr_last_cut_bar = 0;
static int      g_dr_break_dir = 0;
static int      g_dr_break_age = 999;
static int      g_dr_cuts = 0;
static int      g_dr_be_moves = 0;

double DR_Buf(const int h, const int buf, const int sh)
{
   if(h == INVALID_HANDLE) return 0.0;
   double v[1];
   if(CopyBuffer(h, buf, sh, 1, v) != 1) return 0.0;
   return v[0];
}

void DonchianReclaim_Init()
{
   g_dr_emaF = iMA(_Symbol, PERIOD_CURRENT, _32_EmaFast, 0, MODE_EMA, PRICE_CLOSE);
   g_dr_emaS = iMA(_Symbol, PERIOD_CURRENT, _32_EmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   g_dr_adx  = iADX(_Symbol, PERIOD_CURRENT, _32_AdxPeriod);
   g_dr_atr  = iATR(_Symbol, PERIOD_CURRENT, _32_AtrPeriod);
   g_dr_last_bar = 0;
   g_dr_last_cut_bar = 0;
   g_dr_break_dir = 0;
   g_dr_break_age = 999;
   g_dr_cuts = 0;
   g_dr_be_moves = 0;
   if(g_dr_emaF == INVALID_HANDLE || g_dr_emaS == INVALID_HANDLE || g_dr_adx == INVALID_HANDLE || g_dr_atr == INVALID_HANDLE)
      Print("[32] indicator handle failed - no new positions will open");
}

void DonchianReclaim_Deinit()
{
   PrintFormat("[32] SUMMARY account_cuts=%d breakeven_moves=%d", g_dr_cuts, g_dr_be_moves);
   if(g_dr_emaF != INVALID_HANDLE) { IndicatorRelease(g_dr_emaF); g_dr_emaF = INVALID_HANDLE; }
   if(g_dr_emaS != INVALID_HANDLE) { IndicatorRelease(g_dr_emaS); g_dr_emaS = INVALID_HANDLE; }
   if(g_dr_adx  != INVALID_HANDLE) { IndicatorRelease(g_dr_adx);  g_dr_adx  = INVALID_HANDLE; }
   if(g_dr_atr  != INVALID_HANDLE) { IndicatorRelease(g_dr_atr);  g_dr_atr  = INVALID_HANDLE; }
}

EntrySignal Entry_Evaluate()
{
   return Entry_MakeNone("DonchianReclaim self-contained");
}

double DR_Atr()
{
   double a = DR_Buf(g_dr_atr, 0, 1);
   if(a <= 0.0) a = DR_Buf(g_dr_atr, 0, 0);
   return a;
}

// 1 = buy, -1 = sell, 0 = none. Stateful (see header); call once per evaluated bar.
int DR_Signal(const bool newBar)
{
   if(newBar && g_dr_break_age < 999) g_dr_break_age++;
   double c1  = iClose(_Symbol, PERIOD_CURRENT, 1);
   double c2  = iClose(_Symbol, PERIOD_CURRENT, 2);
   double ef1 = DR_Buf(g_dr_emaF, 0, 1);
   double ef2 = DR_Buf(g_dr_emaF, 0, 2);
   double es1 = DR_Buf(g_dr_emaS, 0, 1);
   double atr = DR_Atr();
   double adx = DR_Buf(g_dr_adx, 0, 1);
   if(atr <= 0.0 || ef1 <= 0.0 || es1 <= 0.0) return 0;

   int n = MathMax(10, _32_DonchianBars);
   double hi = iHigh(_Symbol, PERIOD_CURRENT, 2), lo = iLow(_Symbol, PERIOD_CURRENT, 2);
   for(int b = 3; b <= n + 1; b++)
   {
      hi = MathMax(hi, iHigh(_Symbol, PERIOD_CURRENT, b));
      lo = MathMin(lo, iLow(_Symbol, PERIOD_CURRENT, b));
   }
   if(c1 > hi && c1 > es1)      { g_dr_break_dir = 1;  g_dr_break_age = 0; }
   else if(c1 < lo && c1 < es1) { g_dr_break_dir = -1; g_dr_break_age = 0; }

   if(g_dr_break_age > _32_MaxBreakAge || g_dr_break_dir == 0) return 0;
   if(adx < _32_AdxMin) return 0;
   int trend = g_dr_break_dir;
   bool touched = (trend == 1 ? iLow(_Symbol, PERIOD_CURRENT, 1) <= ef1 : iHigh(_Symbol, PERIOD_CURRENT, 1) >= ef1);
   bool reclaim = (trend == 1 ? (c2 <= ef2 && c1 > ef1) : (c2 >= ef2 && c1 < ef1));
   if(!touched || !reclaim) return 0;
   if(trend * (c1 - ef1) / atr > _32_MaxDistAtr) return 0;
   g_dr_break_age = 999;
   return trend;
}

bool DR_FiltersOK()
{
   if(_32_MaxSpreadPoints > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > _32_MaxSpreadPoints) return false;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(_32_StartHour <= _32_EndHour) return (dt.hour >= _32_StartHour && dt.hour <= _32_EndHour);
   return (dt.hour >= _32_StartHour || dt.hour <= _32_EndHour);
}

void DR_Breakeven()
{
   if(!_32_UseBreakeven) return;
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
      if(type == POSITION_TYPE_BUY && (cur - op) >= _32_BreakevenR * risk && sl < op)
      {
         if(Exec_ModifyPosition(tk, NormalizeDouble(op + _32_BeLockPoints * pt, _Digits), tp)) g_dr_be_moves++;
      }
      else if(type == POSITION_TYPE_SELL && (op - cur) >= _32_BreakevenR * risk && sl > op)
      {
         if(Exec_ModifyPosition(tk, NormalizeDouble(op - _32_BeLockPoints * pt, _Digits), tp)) g_dr_be_moves++;
      }
   }
}

bool DonchianReclaim_OnTick()
{
   // 0. shared hard kill (outer cage) always first
   if(RiskControl_CheckDD()) return true;
   if(RiskControl_IsHalted()) return true;

   const datetime bar = iTime(_Symbol, _Period, 0);
   const bool newBar = (bar != g_dr_last_bar);
   if(newBar) g_dr_last_bar = bar;

   // 1. account cut, then pause for the rest of the bar
   if(_32_CutDDPct > 0.0)
   {
      double bal = AccountInfoDouble(ACCOUNT_BALANCE);
      double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
      if(bal > 0.0 && (bal - eq) / bal * 100.0 >= _32_CutDDPct && Exec_CountAll() > 0)
      {
         PrintFormat("[32] ACCOUNT CUT: (balance-equity)/balance %.2f%% >= %.2f%% -> close all", (bal - eq) / bal * 100.0, _32_CutDDPct);
         if(!Exec_CloseAll()) Print("[32] account cut: residual exposure remains - retrying next tick");
         g_dr_cuts++;
         g_dr_last_cut_bar = bar;
         return true;
      }
   }
   if(_32_PauseBarAfterCut && bar == g_dr_last_cut_bar) return true;

   // 2. breakeven, 3. one position at a time; the signal is read only here (it keeps state)
   DR_Breakeven();
   if(Exec_CountDirectionalDir(0) > 0) return true;
   if(!newBar) return true;
   if(!DR_FiltersOK()) return true;

   int sig = DR_Signal(newBar);
   if(sig == 0) return true;
   int dir = (sig == 1 ? 1 : 2);
   if(!Regime_AllowsEntryDirection(dir)) return true;
   if(!RiskControl_AcctGateOK()) return true;
   if(!RiskControl_AllowNewOrder()) return true;

   // 4. one position with ATR SL and R-multiple TP
   double atr = DR_Atr();
   if(atr <= 0.0) return true;
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double slDist = _32_SL_ATR * atr;
   double tpDist = slDist * _32_TP_RR;
   double lot = Exec_NormalizeLot(RiskControl_ClampLot(MM_FirstLot(pt > 0.0 ? slDist / pt : 0.0)));
   if(lot <= 0.0) return true;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK), bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(dir == 1)
      Exec_Open(1, lot, NormalizeDouble(ask - slDist, _Digits), NormalizeDouble(ask + tpDist, _Digits), LAB_ENTRY_TAG + " BUY");
   else
      Exec_Open(2, lot, NormalizeDouble(bid + slDist, _Digits), NormalizeDouble(bid - tpDist, _Digits), LAB_ENTRY_TAG + " SELL");
   return true;
}

#endif // BOSS_LAB_ENTRY_DONCHIAN_RECLAIM_MQH
