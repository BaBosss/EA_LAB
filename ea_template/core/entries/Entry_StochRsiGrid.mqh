// new_entry.py: build 30, copied from Entry_StochRsiGrid.mqh (sha256 8f8d9a7b5a87dbbe013196004c2691ee661b1f1e9d9b833c306223e6a27afee2)
//+------------------------------------------------------------------+
//| Entry_StochRsiGrid.mqh (V2) - entry 30: StochRSI turn + flat     |
//| two-sided adverse grid with weighted basket TP.                  |
//|                                                                  |
//| Port of AGY GrandModular S18 (Eval_S18_StochRsiConvergence) run  |
//| under recovery R02 + lot L01 (flat), as configured by AGY preset |
//| PORT01 S18 StochRSI Safe. Phase 0 (2026-11-06) showed the signal |
//| alone (single shot, ATR SL/TP) is PF < 1 on EURUSD H1; the edge  |
//| exists only with this basket engine, so the build owns its whole |
//| pipeline (TrendRider/27 pattern) instead of mapping onto the     |
//| shared Stack/Exit path, which differs in three ways that matter: |
//|   - the shared chassis holds one basket direction at a time;     |
//|     here the buy and sell baskets are independent;               |
//|   - multi-layer TP is a distance from the volume-weighted open,  |
//|     which ExitManager has no mode for;                           |
//|   - the account cut closes everything and RESUMES after the bar, |
//|     where the shared hard kill halts for good.                   |
//| The shared hard kill (ProtectLevel) still runs first as the      |
//| outer cage and halts as usual.                                   |
//|                                                                  |
//| Per tick, in the source's order:                                 |
//|  1. account cut: (balance - equity) / balance >= _30_CutDDPct    |
//|     -> close all own positions, pause for the rest of the bar;   |
//|  2. per side: close the basket on                                |
//|     one layer  : _30_InitTP_Points from its open,                |
//|     more layers: _30_WeightedTP_Points from the weighted open,   |
//|     any size   : net P/L (profit + swap) >= _30_BasketTP_Per001  |
//|                  x (first lot / 0.01);                           |
//|  3. spread / hour filters gate everything below;                 |
//|  4. the signal is read once per bar (first tick of a new bar);   |
//|     a flat side opens layer 1 on its signal; an open side adds   |
//|     a layer when price is a step beyond its extreme open:        |
//|     step = max(_30_StepPoints, ATR(closed bar) x _30_StepAtrMult)|
//|     at most _30_MaxLayers, at most one add per side per bar.     |
//| Lots are flat (MM_FirstLot, normally _41_FixedLot). No per-order |
//| SL: the account cut and the shared hard kill are the stops.      |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_ENTRY_STOCH_RSI_GRID_MQH
#define BOSS_LAB_ENTRY_STOCH_RSI_GRID_MQH
#include "IEntry.mqh"

static int      g_srg_sto = INVALID_HANDLE;
static int      g_srg_rsi = INVALID_HANDLE;
static int      g_srg_atr = INVALID_HANDLE;
static datetime g_srg_last_bar      = 0;
static datetime g_srg_last_cut_bar  = 0;
static datetime g_srg_last_add_bar[3];   // index 1 = buy, 2 = sell
static int      g_srg_cuts          = 0;
static int      g_srg_tp_closes     = 0;

struct SrgSide
{
   int    count;
   double vol;
   double pnl;          // profit + swap
   double wopen;        // volume-weighted open
   double extreme;      // lowest buy open / highest sell open
};

// -1.0 = copy failed (callers treat it as "no signal")
double SRG_Buf(const int h, const int buf, const int sh)
{
   if(h == INVALID_HANDLE) return -1.0;
   double v[1];
   if(CopyBuffer(h, buf, sh, 1, v) != 1) return -1.0;
   return v[0];
}

void StochRsiGrid_Init()
{
   g_srg_sto = iStochastic(_Symbol, PERIOD_CURRENT, _30_StochK, _30_StochD, _30_StochSlowing, MODE_SMA, STO_LOWHIGH);
   g_srg_rsi = iRSI(_Symbol, PERIOD_CURRENT, _30_RsiPeriod, PRICE_CLOSE);
   g_srg_atr = iATR(_Symbol, PERIOD_CURRENT, _30_AtrPeriod);
   g_srg_last_bar = 0;
   g_srg_last_cut_bar = 0;
   g_srg_last_add_bar[0] = 0; g_srg_last_add_bar[1] = 0; g_srg_last_add_bar[2] = 0;
   g_srg_cuts = 0;
   g_srg_tp_closes = 0;
   if(g_srg_sto == INVALID_HANDLE || g_srg_rsi == INVALID_HANDLE || g_srg_atr == INVALID_HANDLE)
      Print("[30] indicator handle failed - no new baskets will open");
}

void StochRsiGrid_Deinit()
{
   PrintFormat("[30] SUMMARY account_cuts=%d basket_tp_closes=%d", g_srg_cuts, g_srg_tp_closes);
   if(g_srg_sto != INVALID_HANDLE) { IndicatorRelease(g_srg_sto); g_srg_sto = INVALID_HANDLE; }
   if(g_srg_rsi != INVALID_HANDLE) { IndicatorRelease(g_srg_rsi); g_srg_rsi = INVALID_HANDLE; }
   if(g_srg_atr != INVALID_HANDLE) { IndicatorRelease(g_srg_atr); g_srg_atr = INVALID_HANDLE; }
}

EntrySignal Entry_Evaluate()
{
   return Entry_MakeNone("StochRsiGrid self-contained");
}

// 1 = buy, -1 = sell, 0 = none. Closed bars only (shift 1 and 2).
int SRG_Signal()
{
   double k1 = SRG_Buf(g_srg_sto, 0, 1), k2 = SRG_Buf(g_srg_sto, 0, 2);
   double d1 = SRG_Buf(g_srg_sto, 1, 1), d2 = SRG_Buf(g_srg_sto, 1, 2);
   double rsi = SRG_Buf(g_srg_rsi, 0, 1);
   if(k1 < 0.0 || k2 < 0.0 || d1 < 0.0 || d2 < 0.0 || rsi < 0.0) return 0;
   if(k2 <= d2 && k1 > d1 && k1 <= _30_KBuyMax && rsi <= _30_RsiBuyMax) return 1;
   if(k2 >= d2 && k1 < d1 && k1 >= _30_KSellMin && rsi >= _30_RsiSellMin) return -1;
   return 0;
}

double SRG_Atr()
{
   double a = SRG_Buf(g_srg_atr, 0, 1);
   if(a <= 0.0) a = SRG_Buf(g_srg_atr, 0, 0);
   return a;
}

// dir 1 = buy basket, 2 = sell basket (directional legs only)
void SRG_Inspect(const int dir, SrgSide &s)
{
   s.count = 0; s.vol = 0.0; s.pnl = 0.0; s.wopen = 0.0; s.extreme = 0.0;
   double wsum = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsDirectional(i)) continue;
      long type = PositionGetInteger(POSITION_TYPE);
      if((dir == 1 && type != POSITION_TYPE_BUY) || (dir == 2 && type != POSITION_TYPE_SELL)) continue;
      double vol = PositionGetDouble(POSITION_VOLUME);
      double op  = PositionGetDouble(POSITION_PRICE_OPEN);
      s.count++;
      s.vol += vol;
      s.pnl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      wsum  += vol * op;
      if(s.extreme == 0.0 || (dir == 1 ? op < s.extreme : op > s.extreme)) s.extreme = op;
   }
   if(s.vol > 0.0) s.wopen = wsum / s.vol;
}

void SRG_CloseSide(const int dir)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsDirectional(i)) continue;
      long type = PositionGetInteger(POSITION_TYPE);
      if((dir == 1 && type != POSITION_TYPE_BUY) || (dir == 2 && type != POSITION_TYPE_SELL)) continue;
      ulong tk = PositionGetInteger(POSITION_TICKET);
      if(!Exec_CloseTicket(tk))
         PrintFormat("[30] basket close FAILED %I64u retcode=%d", tk, (int)g_trade.ResultRetcode());
   }
}

// step 2: basket TP for one side
void SRG_ManageSide(const int dir, const double firstLot)
{
   SrgSide s;
   SRG_Inspect(dir, s);
   if(s.count <= 0) return;
   double pt  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double gain = (dir == 1 ? bid - s.wopen : s.wopen - ask);
   bool hit = false;
   if(s.count == 1 && _30_InitTP_Points > 0 && gain >= _30_InitTP_Points * pt) hit = true;
   if(s.count > 1 && _30_WeightedTP_Points > 0 && gain >= _30_WeightedTP_Points * pt) hit = true;
   double tpUsd = _30_BasketTP_Per001 * (firstLot / 0.01);
   if(tpUsd > 0.0 && s.pnl >= tpUsd) hit = true;
   if(!hit) return;
   SRG_CloseSide(dir);
   g_srg_tp_closes++;
}

bool SRG_FiltersOK()
{
   if(_30_MaxSpreadPoints > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > _30_MaxSpreadPoints) return false;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(_30_StartHour <= _30_EndHour) return (dt.hour >= _30_StartHour && dt.hour <= _30_EndHour);
   return (dt.hour >= _30_StartHour || dt.hour <= _30_EndHour);
}

// step 4: seed or add one layer on one side
void SRG_SeedOrAdd(const int dir, const int sig, const double firstLot, const datetime bar)
{
   SrgSide s;
   SRG_Inspect(dir, s);
   bool open = false;
   if(s.count == 0)
      open = (dir == 1 ? sig == 1 : sig == -1);
   else if(s.count < _30_MaxLayers && s.extreme > 0.0)
   {
      double atr  = SRG_Atr();
      double step = _30_StepPoints * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(atr > 0.0 && atr * _30_StepAtrMult > step) step = atr * _30_StepAtrMult;
      double px   = (dir == 1 ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID));
      double away = (dir == 1 ? s.extreme - px : px - s.extreme);
      open = (away >= step && (!_30_AddBarDelay || g_srg_last_add_bar[dir] != bar));
   }
   if(!open) return;
   if(!RiskControl_AllowNewOrder()) return;
   double lot = Exec_NormalizeLot(RiskControl_ClampLot(firstLot));
   if(lot <= 0.0) return;
   string cmt = StringFormat("%s L%d %s", LAB_ENTRY_TAG, s.count + 1, (dir == 1 ? "BUY" : "SELL"));
   if(Exec_Open(dir, lot, 0.0, 0.0, cmt)) g_srg_last_add_bar[dir] = bar;
}

bool StochRsiGrid_OnTick()
{
   // 0. shared hard kill (outer cage) always first
   if(RiskControl_CheckDD()) return true;
   if(RiskControl_IsHalted()) return true;

   const datetime bar = iTime(_Symbol, _Period, 0);
   const bool newBar = (bar != g_srg_last_bar);
   if(newBar) g_srg_last_bar = bar;

   // 1. account cut, then pause for the rest of the bar
   if(_30_CutDDPct > 0.0)
   {
      double bal = AccountInfoDouble(ACCOUNT_BALANCE);
      double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
      if(bal > 0.0 && (bal - eq) / bal * 100.0 >= _30_CutDDPct && Exec_CountAll() > 0)
      {
         PrintFormat("[30] ACCOUNT CUT: (balance-equity)/balance %.2f%% >= %.2f%% -> close all", (bal - eq) / bal * 100.0, _30_CutDDPct);
         if(!Exec_CloseAll()) Print("[30] account cut: residual exposure remains - retrying next tick");
         g_srg_cuts++;
         g_srg_last_cut_bar = bar;
         return true;
      }
   }
   if(_30_PauseBarAfterCut && bar == g_srg_last_cut_bar) return true;

   double firstLot = MM_FirstLot(0.0);
   if(firstLot <= 0.0) return true;

   // 2. basket TP per side
   SRG_ManageSide(1, firstLot);
   SRG_ManageSide(2, firstLot);

   // 3. filters gate seeds and adds
   if(!SRG_FiltersOK()) return true;

   // 4. signal once per bar; seeds and adds per side
   int sig = (newBar ? SRG_Signal() : 0);
   if(sig != 0 && !RiskControl_AcctGateOK()) sig = 0;   // acct-DD gate (first entries only, no-op when off)
   if(sig == 1 && !Regime_AllowsEntryDirection(1)) sig = 0;
   if(sig == -1 && !Regime_AllowsEntryDirection(2)) sig = 0;
   SRG_SeedOrAdd(1, sig, firstLot, bar);
   SRG_SeedOrAdd(2, sig, firstLot, bar);
   return true;
}

#endif // BOSS_LAB_ENTRY_STOCH_RSI_GRID_MQH
