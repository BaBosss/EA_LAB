//+------------------------------------------------------------------+
//| (EXP)_EmaStoRev_OB.mq5                                           |
//| ORDER-098-L — SMC×STO Stage-1: EmaStoRev + Order-Block gate.     |
//|   Copy of the confirmed EURUSD-H1 candidate (StoK/OS/ADX) with    |
//|   an added OB-zone confluence gate (default OFF = identical to    |
//|   the Stage-0 candidate). Gate: only take the STO reversion entry |
//|   if the current bar is retesting a FRESH (untouched) order block |
//|   aligned with trade direction. Tests whether the SMC zone (the   |
//|   piece stripped in Stage-0) lifts PF above the 1.50/1.24 base.   |
//+------------------------------------------------------------------+
#property strict
#property description "(EXP)_EmaStoRev_OB — SMC×STO Stage-1 (EmaStoRev + Order-Block gate)"

#include <Trade\Trade.mqh>

input bool   _00_OptimizeMode = false;
input ENUM_TIMEFRAMES _01_EmaTF   = PERIOD_H1;
input int    _01_EmaPeriod        = 100;
input int    _02_StoK             = 5;
input int    _02_StoD             = 3;
input int    _02_StoSlow          = 3;
input double _02_OverSold         = 20.0;
input double _02_OverBought       = 80.0;
input double _02_BEatLevel        = 50.0;
input double _03_SlAtrMult        = 2.0;
input int    _03_AtrPeriod        = 14;
input double _03_TpAtrMult        = 0.0;
input bool   _08_UseAdxFilter     = false;
input int    _08_AdxPeriod        = 14;
input double _08_AdxMax           = 25.0;
//--- [09] Order-Block confluence gate (Stage-1 SMC piece; default OFF = Stage-0 behavior)
input bool   _09_UseObGate        = false;  // true = require fresh OB retest aligned with entry
input int    _09_ObLookback       = 30;     // bars scanned back for the order block
input double _05_LotSize          = 0.01;
input long   _06_Magic            = 991071; // distinct from Stage-0 candidate 991070
input ulong  _06_Deviation        = 20;
input bool   _06_AllowLive        = false;

static bool     g_suppress_log   = false;
static int      g_adx_handle     = INVALID_HANDLE;
static int      g_sto_handle     = INVALID_HANDLE;
static int      g_ema_handle     = INVALID_HANDLE;
static int      g_atr_handle     = INVALID_HANDLE;
static datetime g_last_bar       = 0;
static CTrade   g_trade;

bool StoAt(const int shift, double &k, double &d)
{
   double bk[], bd[];
   if(g_sto_handle == INVALID_HANDLE) return false;
   if(CopyBuffer(g_sto_handle, 0, shift, 1, bk) < 1) return false;
   if(CopyBuffer(g_sto_handle, 1, shift, 1, bd) < 1) return false;
   k = bk[0]; d = bd[0]; return true;
}
double EmaAt(const int shift)
{ double b[]; if(g_ema_handle==INVALID_HANDLE) return 0.0; if(CopyBuffer(g_ema_handle,0,shift,1,b)<1) return 0.0; return b[0]; }
double AtrAt(const int shift)
{ double b[]; if(g_atr_handle==INVALID_HANDLE) return 0.0; if(CopyBuffer(g_atr_handle,0,shift,1,b)<1) return 0.0; return b[0]; }

int TrendDir()
{
   const double ema = EmaAt(1); if(ema <= 0.0) return 0;
   const double c = iClose(_Symbol, _01_EmaTF, 1); if(c <= 0.0) return 0;
   return (c > ema) ? 1 : -1;
}

// --- Order-Block gate ------------------------------------------------
// Bullish OB (demand): a bearish candle at s followed by an up-displacement
// (close[s-1] breaks above high[s]); zone = [low[s], high[s]]; FRESH if no later
// candle closed below the zone; ALIGNED if the current bar (1) is retesting it.
bool InBullObZone()
{
   const int n=_09_ObLookback+3;
   double op[],hi[],lo[],cl[]; ArraySetAsSeries(op,true);ArraySetAsSeries(hi,true);ArraySetAsSeries(lo,true);ArraySetAsSeries(cl,true);
   if(CopyOpen(_Symbol,PERIOD_CURRENT,0,n,op)<n||CopyHigh(_Symbol,PERIOD_CURRENT,0,n,hi)<n||
      CopyLow(_Symbol,PERIOD_CURRENT,0,n,lo)<n||CopyClose(_Symbol,PERIOD_CURRENT,0,n,cl)<n) return false;
   for(int s=2; s<=_09_ObLookback; s++){
      if(cl[s]>=op[s]) continue;              // need a bearish origin candle
      if(cl[s-1]<=hi[s]) continue;            // need up-displacement right after
      double zlo=lo[s], zhi=hi[s];
      bool violated=false;
      for(int j=s-2;j>=1;j--){ if(cl[j]<zlo){ violated=true; break; } }
      if(violated) continue;
      if(lo[1]<=zhi && lo[1]>=zlo) return true;   // fresh demand zone tapped now
   }
   return false;
}
bool InBearObZone()
{
   const int n=_09_ObLookback+3;
   double op[],hi[],lo[],cl[]; ArraySetAsSeries(op,true);ArraySetAsSeries(hi,true);ArraySetAsSeries(lo,true);ArraySetAsSeries(cl,true);
   if(CopyOpen(_Symbol,PERIOD_CURRENT,0,n,op)<n||CopyHigh(_Symbol,PERIOD_CURRENT,0,n,hi)<n||
      CopyLow(_Symbol,PERIOD_CURRENT,0,n,lo)<n||CopyClose(_Symbol,PERIOD_CURRENT,0,n,cl)<n) return false;
   for(int s=2; s<=_09_ObLookback; s++){
      if(cl[s]<=op[s]) continue;              // need a bullish origin candle
      if(cl[s-1]>=lo[s]) continue;            // need down-displacement right after
      double zlo=lo[s], zhi=hi[s];
      bool violated=false;
      for(int j=s-2;j>=1;j--){ if(cl[j]>zhi){ violated=true; break; } }
      if(violated) continue;
      if(hi[1]>=zlo && hi[1]<=zhi) return true;   // fresh supply zone tapped now
   }
   return false;
}

bool GetMyPosition(ulong &ticket, long &type, double &open_price, double &sl)
{
   for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=_06_Magic) continue;
      ticket=t; type=PositionGetInteger(POSITION_TYPE); open_price=PositionGetDouble(POSITION_PRICE_OPEN); sl=PositionGetDouble(POSITION_SL); return true; }
   return false;
}

int OnInit()
{
   g_suppress_log = _00_OptimizeMode || (bool)MQLInfoInteger(MQL_OPTIMIZATION);
   g_sto_handle = iStochastic(_Symbol, PERIOD_CURRENT, _02_StoK, _02_StoD, _02_StoSlow, MODE_SMA, STO_LOWHIGH);
   g_ema_handle = iMA(_Symbol, _01_EmaTF, _01_EmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, _03_AtrPeriod);
   if(g_sto_handle==INVALID_HANDLE||g_ema_handle==INVALID_HANDLE||g_atr_handle==INVALID_HANDLE){ Print("EmaStoRev_OB: handle failed"); return INIT_FAILED; }
   if(_08_UseAdxFilter){ g_adx_handle=iADX(_Symbol,PERIOD_CURRENT,_08_AdxPeriod); if(g_adx_handle==INVALID_HANDLE){ Print("iADX failed"); return INIT_FAILED; } }
   g_trade.SetExpertMagicNumber(_06_Magic); g_trade.SetDeviationInPoints(_06_Deviation); g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_last_bar = 0; return INIT_SUCCEEDED;
}
void OnDeinit(const int reason)
{
   if(g_sto_handle!=INVALID_HANDLE) IndicatorRelease(g_sto_handle);
   if(g_ema_handle!=INVALID_HANDLE) IndicatorRelease(g_ema_handle);
   if(g_atr_handle!=INVALID_HANDLE) IndicatorRelease(g_atr_handle);
   if(g_adx_handle!=INVALID_HANDLE) IndicatorRelease(g_adx_handle);
}
double OnTester(){ double t=TesterStatistics(STAT_TRADES); if(t<15) return -1.0; double s=TesterStatistics(STAT_SHARPE_RATIO); return s>0?s:-1.0; }

void OnTick()
{
   const datetime cur = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(cur == g_last_bar) return; g_last_bar = cur;

   double k1,d1,k2,d2;
   if(!StoAt(1,k1,d1) || !StoAt(2,k2,d2)) return;

   ulong ticket; long ptype; double popen,psl;
   if(GetMyPosition(ticket,ptype,popen,psl))
   {
      const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
      const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      if(ptype==POSITION_TYPE_BUY){
         if(k1>=_02_BEatLevel && psl<popen && bid>popen) g_trade.PositionModify(ticket,NormalizeDouble(popen,digits),PositionGetDouble(POSITION_TP));
         if(k2>=d2 && k1<d1 && k1>=_02_OverBought) g_trade.PositionClose(ticket);
      } else {
         if(k1<=(100.0-_02_BEatLevel) && (psl>popen||psl==0.0) && ask<popen) g_trade.PositionModify(ticket,NormalizeDouble(popen,digits),PositionGetDouble(POSITION_TP));
         if(k2<=d2 && k1>d1 && k1<=_02_OverSold) g_trade.PositionClose(ticket);
      }
      return;
   }

   const int dir = TrendDir(); if(dir==0) return;
   if(_08_UseAdxFilter && g_adx_handle!=INVALID_HANDLE){ double adx[]; if(CopyBuffer(g_adx_handle,0,1,1,adx)<1) return; if(adx[0]>=_08_AdxMax) return; }

   const double atr = AtrAt(1); if(atr<=0.0) return;
   bool buy_sig  = (dir==1)  && (k2<=d2 && k1>d1) && (k1<_02_OverSold);
   bool sell_sig = (dir==-1) && (k2>=d2 && k1<d1) && (k1>_02_OverBought);
   if(!buy_sig && !sell_sig) return;

   // [09] Order-Block confluence gate
   if(_09_UseObGate){
      if(buy_sig  && !InBullObZone()) return;
      if(sell_sig && !InBearObZone()) return;
   }

   const bool allow=_06_AllowLive||(bool)MQLInfoInteger(MQL_TESTER); if(!allow) return;
   const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK), bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double sl_dist=atr*_03_SlAtrMult; const double tp_dist=(_03_TpAtrMult>0.0)?atr*_03_TpAtrMult:0.0;
   if(buy_sig){
      double sl=NormalizeDouble(ask-sl_dist,digits); double tp=(tp_dist>0.0)?NormalizeDouble(ask+tp_dist,digits):0.0;
      g_trade.Buy(_05_LotSize,_Symbol,ask,sl,tp,"EMASTOOB_BUY");
   } else {
      double sl=NormalizeDouble(bid+sl_dist,digits); double tp=(tp_dist>0.0)?NormalizeDouble(bid-tp_dist,digits):0.0;
      g_trade.Sell(_05_LotSize,_Symbol,bid,sl,tp,"EMASTOOB_SELL");
   }
}
