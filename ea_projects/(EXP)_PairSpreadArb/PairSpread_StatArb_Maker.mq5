//+------------------------------------------------------------------+
//| PairSpread_StatArb_Maker.mq5                                     |
//| ORDER-098-K — maker-entry variant of PairSpread_StatArb.         |
//|   Build-on: the market-entry baseline pays 2x spread per basket   |
//|   (the cost-drag that thins the ExitZ0.3 edge). This variant      |
//|   enters both legs with LIMIT orders (maker fills, no spread).    |
//|   Fill-coordination guard: if only one leg fills, the other is    |
//|   market-completed next bar so there is never a lingering naked   |
//|   leg. Exit stays market (must act on the signal). Same z-score,  |
//|   SL cage, one-basket, hedged, no grid/MM as the baseline.        |
//+------------------------------------------------------------------+
#property strict
#property description "(EXP)_PairSpread_StatArb_Maker — pairs-spread stat-arb, LIMIT (maker) entry"

#include <Trade\Trade.mqh>

input bool   _00_OptimizeMode  = false;
input string _01_SymbolA       = "EURUSD";
input string _01_SymbolB       = "GBPUSD";
input int    _01_ZWindow       = 100;
input double _01_EntryZ        = 2.5;   // ExitZ0.3 locked config defaults
input double _01_ExitZ         = 0.3;
input double _01_StopZ         = 3.5;
input bool   _01_AllowLongA    = true;
input bool   _01_AllowShortA   = true;
input int    _01_PendingTTLbars= 1;     // cancel un-filled pendings after this many bars
input double _05_LotA          = 0.10;
input double _05_LotB          = 0.10;
input long   _06_Magic         = 990985; // distinct from baseline 990984
input ulong  _06_Deviation     = 20;
input bool   _06_AllowLive     = false;

static bool     g_suppress_log  = false;
static datetime g_last_bar_time = 0;
static bool     g_bar_checked   = false;
static datetime g_place_bar     = 0;    // bar time when pendings were placed
static CTrade   g_trade;

bool SpreadZ(double &z_out, double &spread_now)
{
   double sum=0.0, sumsq=0.0; int n=0;
   for(int s=1; s<=_01_ZWindow; s++){
      double a=iClose(_01_SymbolA,PERIOD_CURRENT,s), b=iClose(_01_SymbolB,PERIOD_CURRENT,s);
      if(a<=0.0||b<=0.0) return false;
      double sp=MathLog(a)-MathLog(b); sum+=sp; sumsq+=sp*sp; n++;
   }
   if(n<_01_ZWindow) return false;
   double mean=sum/n, var=(sumsq/n)-(mean*mean);
   if(var<=0.0) return false;
   double sd=MathSqrt(var);
   double a1=iClose(_01_SymbolA,PERIOD_CURRENT,1), b1=iClose(_01_SymbolB,PERIOD_CURRENT,1);
   if(a1<=0.0||b1<=0.0) return false;
   spread_now=MathLog(a1)-MathLog(b1);
   z_out=(spread_now-mean)/sd;
   return true;
}

// count my filled legs per symbol
void MyLegs(bool &longA,bool &shortA,bool &longB,bool &shortB)
{
   longA=shortA=longB=shortB=false;
   for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=_06_Magic) continue;
      string sym=PositionGetString(POSITION_SYMBOL); long ty=PositionGetInteger(POSITION_TYPE);
      if(sym==_01_SymbolA){ if(ty==POSITION_TYPE_BUY) longA=true; else shortA=true; }
      if(sym==_01_SymbolB){ if(ty==POSITION_TYPE_BUY) longB=true; else shortB=true; }
   }
}
int FilledLegCount(){ bool la,sa,lb,sb; MyLegs(la,sa,lb,sb); return (la||sa?1:0)+(lb||sb?1:0); }

int MyPendingCount()
{
   int c=0;
   for(int i=0;i<OrdersTotal();i++){ ulong t=OrderGetTicket(i); if(t==0) continue; if(!OrderSelect(t)) continue;
      if(OrderGetInteger(ORDER_MAGIC)!=_06_Magic) continue;
      string sym=OrderGetString(ORDER_SYMBOL);
      if(sym==_01_SymbolA||sym==_01_SymbolB) c++;
   }
   return c;
}
void DeleteMyPendings()
{
   for(int i=OrdersTotal()-1;i>=0;i--){ ulong t=OrderGetTicket(i); if(t==0) continue; if(!OrderSelect(t)) continue;
      if(OrderGetInteger(ORDER_MAGIC)!=_06_Magic) continue;
      string sym=OrderGetString(ORDER_SYMBOL);
      if(sym==_01_SymbolA||sym==_01_SymbolB) g_trade.OrderDelete(t);
   }
}
void CloseAllMine()
{
   for(int i=PositionsTotal()-1;i>=0;i--){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=_06_Magic) continue;
      string sym=PositionGetString(POSITION_SYMBOL);
      if(sym==_01_SymbolA||sym==_01_SymbolB) g_trade.PositionClose(t);
   }
   DeleteMyPendings();
}

// place BOTH legs as limit (maker). dir=+1 BUY A / SELL B ; dir=-1 SELL A / BUY B.
void PlaceMakerBasket(const int dir)
{
   const bool allow=_06_AllowLive||(bool)MQLInfoInteger(MQL_TESTER);
   if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN maker dir=%d",dir); return; }
   double askA=SymbolInfoDouble(_01_SymbolA,SYMBOL_ASK), bidA=SymbolInfoDouble(_01_SymbolA,SYMBOL_BID);
   double askB=SymbolInfoDouble(_01_SymbolB,SYMBOL_ASK), bidB=SymbolInfoDouble(_01_SymbolB,SYMBOL_BID);
   if(askA<=0||bidA<=0||askB<=0||bidB<=0) return;
   int dA=(int)SymbolInfoInteger(_01_SymbolA,SYMBOL_DIGITS), dB=(int)SymbolInfoInteger(_01_SymbolB,SYMBOL_DIGITS);
   if(dir==1){ // BUY A @ bid (maker), SELL B @ ask (maker)
      g_trade.BuyLimit (_05_LotA,NormalizeDouble(bidA,dA),_01_SymbolA,0,0,ORDER_TIME_GTC,0,"PSK_LA");
      g_trade.SellLimit(_05_LotB,NormalizeDouble(askB,dB),_01_SymbolB,0,0,ORDER_TIME_GTC,0,"PSK_SB");
   } else {    // SELL A @ ask, BUY B @ bid
      g_trade.SellLimit(_05_LotA,NormalizeDouble(askA,dA),_01_SymbolA,0,0,ORDER_TIME_GTC,0,"PSK_SA");
      g_trade.BuyLimit (_05_LotB,NormalizeDouble(bidB,dB),_01_SymbolB,0,0,ORDER_TIME_GTC,0,"PSK_LB");
   }
   g_place_bar=iTime(_Symbol,PERIOD_CURRENT,0);
}

// market-complete whichever leg is missing so the hedge is never naked
void CompleteMissingLeg(const int dir)
{
   bool la,sa,lb,sb; MyLegs(la,sa,lb,sb);
   bool aFilled=(la||sa), bFilled=(lb||sb);
   double askA=SymbolInfoDouble(_01_SymbolA,SYMBOL_ASK), bidA=SymbolInfoDouble(_01_SymbolA,SYMBOL_BID);
   double askB=SymbolInfoDouble(_01_SymbolB,SYMBOL_ASK), bidB=SymbolInfoDouble(_01_SymbolB,SYMBOL_BID);
   if(dir==1){ // want BUY A + SELL B
      if(!aFilled) g_trade.Buy (_05_LotA,_01_SymbolA,askA,0,0,"PSK_LA_mkt");
      if(!bFilled) g_trade.Sell(_05_LotB,_01_SymbolB,bidB,0,0,"PSK_SB_mkt");
   } else {
      if(!aFilled) g_trade.Sell(_05_LotA,_01_SymbolA,bidA,0,0,"PSK_SA_mkt");
      if(!bFilled) g_trade.Buy (_05_LotB,_01_SymbolB,askB,0,0,"PSK_LB_mkt");
   }
}

// current basket direction from filled legs: +1, -1, or 0 if not both filled
int BasketDir()
{
   bool la,sa,lb,sb; MyLegs(la,sa,lb,sb);
   if(la&&sb) return 1;
   if(sa&&lb) return -1;
   return 0;
}
// intended direction implied by any resting pending / partial (from the leg we DO have)
int PendingIntent()
{
   bool la,sa,lb,sb; MyLegs(la,sa,lb,sb);
   if(la||sb) return 1;   // have BUY A or SELL B → intended dir +1
   if(sa||lb) return -1;
   return 0;
}

int OnInit()
{
   g_suppress_log=_00_OptimizeMode||(bool)MQLInfoInteger(MQL_OPTIMIZATION);
   if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING){
      Print("Maker init FAILED: requires HEDGING account"); return INIT_FAILED; }
   if(_01_SymbolA==_01_SymbolB){ Print("Maker init FAILED: SymbolA==SymbolB"); return INIT_FAILED; }
   g_trade.SetExpertMagicNumber(_06_Magic); g_trade.SetDeviationInPoints(_06_Deviation); g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_last_bar_time=0; g_bar_checked=false; g_place_bar=0;
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason){}
double OnTester(){ double t=TesterStatistics(STAT_TRADES); if(t<15) return -1.0; double s=TesterStatistics(STAT_SHARPE_RATIO); return s>0?s:-1.0; }

void OnTick()
{
   const datetime bar1=iTime(_Symbol,PERIOD_CURRENT,1);
   if(bar1!=g_last_bar_time){ g_last_bar_time=bar1; g_bar_checked=false; }
   if(g_bar_checked) return; g_bar_checked=true;

   int filled=FilledLegCount();
   int pend=MyPendingCount();

   // ---- both legs filled: manage the basket (market exits) ----
   if(filled==2){
      DeleteMyPendings();                 // safety: no stray pendings while in a basket
      double z,sp; if(!SpreadZ(z,sp)) return;
      double az=MathAbs(z);
      if(az<=_01_ExitZ || az>=_01_StopZ) CloseAllMine();
      return;
   }

   // ---- exactly one leg filled: complete the hedge at market, cancel leftover pending ----
   if(filled==1){
      int dir=PendingIntent();
      DeleteMyPendings();
      if(dir!=0) CompleteMissingLeg(dir);
      return;
   }

   // ---- no fills yet but pendings resting: expire them after TTL ----
   if(filled==0 && pend>0){
      int elapsed=(int)((iTime(_Symbol,PERIOD_CURRENT,0)-g_place_bar)/ (PeriodSeconds(PERIOD_CURRENT)));
      if(elapsed>=_01_PendingTTLbars) DeleteMyPendings();
      return;
   }

   // ---- flat (no fills, no pendings): look for a new entry ----
   double z,sp; if(!SpreadZ(z,sp)) return;
   if(z>=_01_EntryZ && _01_AllowShortA)      PlaceMakerBasket(-1);
   else if(z<=-_01_EntryZ && _01_AllowLongA) PlaceMakerBasket( 1);
}
