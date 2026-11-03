// A10 C2 port 2026-11-03: ported from the untracked local D:\EA_LAB file core/entries/Entry_TrendRider.mqh
// sha256 2865988077ef35401be852d2a6bde92fb829d2620a0eb799ef4f1ed527c25680; renumbered 21 -> 27 (inputs _21_* -> _27_*). Logic unchanged.
//+------------------------------------------------------------------+
//| Entry_TrendRider.mqh (V2) - Entry 27: TrendRider H4              |
//| Trend Pullback-Continuation with Chandelier Trailing Stop.       |
//|                                                                  |
//| Ported into Boss Lab V2 chassis (ORDER-TrendRider).              |
//| S1 Edge: Gold macro trends persist; pullbacks to EMA21 offer     |
//| high R:R continuation entries with defined structural risk.      |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_ENTRY_TRENDRIDER_MQH
#define BOSS_LAB_ENTRY_TRENDRIDER_MQH

#include "IEntry.mqh"
#include "../Indicators.mqh"
#include "../Execution.mqh"
#include "../RiskControl.mqh"
#include "../ExitManager.mqh"
#include "../MoneyManagement.mqh"
#include "../SignedVolatility.mqh"

// Parameters are declared in Inputs.mqh for this build.

static int      g_tr_emaF = INVALID_HANDLE;
static int      g_tr_emaS = INVALID_HANDLE;
static int      g_tr_emaP = INVALID_HANDLE;
static int      g_tr_adx  = INVALID_HANDLE;
static int      g_tr_atr  = INVALID_HANDLE;
static datetime g_tr_last_bar = 0;

double TR_Buf(const int h, const int b, const int sh)
{
   double a[1];
   if(h == INVALID_HANDLE) return 0.0;
   if(CopyBuffer(h, b, sh, 1, a) < 1) return 0.0;
   return a[0];
}

int TR_GmtHourOf(const datetime srv)
{
   MqlDateTime d;
   TimeToStruct(srv, d);
   return ((d.hour - _27_ServerGmtOffset) % 24 + 24) % 24;
}

void TrendRider_Init()
{
   g_tr_emaF = iMA(_Symbol, _Period, _27_EmaFast, 0, MODE_EMA, PRICE_CLOSE);
   g_tr_emaS = iMA(_Symbol, _Period, _27_EmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   g_tr_emaP = iMA(_Symbol, _Period, _27_EmaPull, 0, MODE_EMA, PRICE_CLOSE);
   g_tr_adx  = iADX(_Symbol, _Period, _27_AdxPeriod);
   g_tr_atr  = iATR(_Symbol, _Period, _27_AtrPeriod);
   g_tr_last_bar = 0;
   PrintFormat("[INIT] Entry 27 TrendRider | emaF=%d emaS=%d emaP=%d adxMin=%.1f sepAtr=%.2f slAtr=%.1f chAtr=%.1f",
               _27_EmaFast, _27_EmaSlow, _27_EmaPull, _27_AdxMin, _27_SepAtrMult, _27_SlAtrMult, _27_ChAtrMult);
}

void TrendRider_Deinit()
{
   if(g_tr_emaF != INVALID_HANDLE) { IndicatorRelease(g_tr_emaF); g_tr_emaF = INVALID_HANDLE; }
   if(g_tr_emaS != INVALID_HANDLE) { IndicatorRelease(g_tr_emaS); g_tr_emaS = INVALID_HANDLE; }
   if(g_tr_emaP != INVALID_HANDLE) { IndicatorRelease(g_tr_emaP); g_tr_emaP = INVALID_HANDLE; }
   if(g_tr_adx  != INVALID_HANDLE) { IndicatorRelease(g_tr_adx);  g_tr_adx  = INVALID_HANDLE; }
   if(g_tr_atr  != INVALID_HANDLE) { IndicatorRelease(g_tr_atr);  g_tr_atr  = INVALID_HANDLE; }
}

EntrySignal Entry_Evaluate()
{
   return Entry_MakeNone("TrendRider self-contained");
}

bool TrendRider_OnTick()
{
   // 1. Hard risk kill always runs first
   if(RiskControl_CheckDD()) return true;
   if(RiskControl_IsHalted()) return true;

   // 2. Bar-open gate
   const datetime cur = iTime(_Symbol, _Period, 0);
   if(cur == g_tr_last_bar) return true;
   g_tr_last_bar = cur;

   const double atr = TR_Buf(g_tr_atr, 0, 1);
   if(atr <= 0.0) return true;

   int haveBuy  = Exec_CountDirectionalDir(1);
   int haveSell = Exec_CountDirectionalDir(2);
   int have     = haveBuy + haveSell;

   // 3. Manage open position: Chandelier trail (tighten only)
   if(have > 0)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!Exec_PosIsDirectional(i)) continue;
         long   type  = PositionGetInteger(POSITION_TYPE);
         double curSL = PositionGetDouble(POSITION_SL);
         double curTP = PositionGetDouble(POSITION_TP);
         ulong  tk    = PositionGetInteger(POSITION_TICKET);

         if(type == POSITION_TYPE_BUY)
         {
            double hi = Indi_HighestHigh(_27_ChHighBars, 1);
            if(hi > 0.0)
            {
               double newSL = NormalizeDouble(hi - _27_ChAtrMult * atr, _Digits);
               if(curSL == 0.0 || newSL > curSL)
                  Exec_ModifyPosition(tk, newSL, curTP);
            }
         }
         else if(type == POSITION_TYPE_SELL)
         {
            double lo = Indi_LowestLow(_27_ChHighBars, 1);
            if(lo > 0.0)
            {
               double newSL = NormalizeDouble(lo + _27_ChAtrMult * atr, _Digits);
               if(curSL == 0.0 || newSL < curSL)
                  Exec_ModifyPosition(tk, newSL, curTP);
            }
         }
      }
      if(have >= _27_MaxOrders) return true;
   }

   // 4. Look for pullback continuation entry or scale-in in session
   const int gmtHour = TR_GmtHourOf(TimeCurrent());
   if(gmtHour < _27_StartGmt || gmtHour >= _27_EndGmt) return true;

   if(_27_LondonNYOverlapOnly)
   {
      // Restrict strictly to London/NY peak liquidity overlap (12:00 to 17:00 GMT)
      if(gmtHour < 12 || gmtHour > 17) return true;
   }

   const double emaF = TR_Buf(g_tr_emaF, 0, 1);
   const double emaS = TR_Buf(g_tr_emaS, 0, 1);
   const double emaP = TR_Buf(g_tr_emaP, 0, 1);
   const double adx  = TR_Buf(g_tr_adx,  0, 1);

   const double lo1 = iLow(_Symbol,   _Period, 1);
   const double hi1 = iHigh(_Symbol,  _Period, 1);
   const double c1  = iClose(_Symbol, _Period, 1);
   const double o1  = iOpen(_Symbol,  _Period, 1);
   const double sep = MathAbs(emaF - emaS);

   const bool upReg   = (emaF > emaS) && (adx >= _27_AdxMin) && (sep >= _27_SepAtrMult * atr);
   const bool dnReg   = (emaF < emaS) && (adx >= _27_AdxMin) && (sep >= _27_SepAtrMult * atr);

   bool pbLong  = false;
   bool pbShort = false;

   if(have == 0)
   {
      pbLong  = upReg && (lo1 <= emaP) && (c1 > emaP) && (c1 > o1);
      pbShort = dnReg && (hi1 >= emaP) && (c1 < emaP) && (c1 < o1);
   }
   else if(have < _27_MaxOrders)
   {
      MqlTick t0;
      if(SymbolInfoTick(_Symbol, t0))
      {
         if(haveBuy > 0 && haveSell == 0 && upReg)
         {
            double lastPrice = Exec_LastDirectionalPriceDir(1);
            if(lastPrice > 0.0 && t0.ask >= lastPrice + _27_ScaleInAtr * atr)
               pbLong = true;
         }
         else if(haveSell > 0 && haveBuy == 0 && dnReg)
         {
            double lastPrice = Exec_LastDirectionalPriceDir(2);
            if(lastPrice > 0.0 && t0.bid <= lastPrice - _27_ScaleInAtr * atr)
               pbShort = true;
         }
      }
   }

   if(!pbLong && !pbShort) return true;

   if(_27_EnableVolFilter)
   {
      if(pbLong  && !SignedVol_AllowsLong(_Symbol, _Period, 20, 0.25, true)) return true;
      if(pbShort && !SignedVol_AllowsShort(_Symbol, _Period, 20, 0.25, true)) return true;
   }

   // Pre-trade checks
   if(pbLong  && !Regime_AllowsEntryDirection(1)) return true;
   if(pbShort && !Regime_AllowsEntryDirection(2)) return true;
   if(!RiskControl_AcctGateOK()) return true;
   if(!RiskControl_AllowNewOrder()) return true;

   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return true;

   double pt = Exit_Point();
   double slDist = _27_SlAtrMult * atr;
   double slDistPoints = (pt > 0.0 ? slDist / pt : 0.0);
   double lot = MM_FirstLot(slDistPoints);
   if(_27_EnableVolFilter)
   {
      double scale = SignedVol_GetLotScale(_Symbol, _Period, 20, _27_BaselineVariance, true);
      lot *= scale;
      lot = Exec_NormalizeLot(lot);
   }
   if(lot <= 0.0) return true;

   if(pbLong)
   {
      double sl = NormalizeDouble(t.ask - slDist, _Digits);
      double tp = Exit_InitialTP(1, t.ask);
      Exec_OpenIntent((have > 0 ? INTENT_PYRAMID_ADD : INTENT_TREND_ENTRY), 1, lot, sl, tp, (have > 0 ? "TR_PYR_BUY" : "TR_BUY"));
   }
   else if(pbShort)
   {
      double sl = NormalizeDouble(t.bid + slDist, _Digits);
      double tp = Exit_InitialTP(2, t.bid);
      Exec_OpenIntent((have > 0 ? INTENT_PYRAMID_ADD : INTENT_TREND_ENTRY), 2, lot, sl, tp, (have > 0 ? "TR_PYR_SELL" : "TR_SELL"));
   }

   return true;
}

#endif // BOSS_LAB_ENTRY_TRENDRIDER_MQH
