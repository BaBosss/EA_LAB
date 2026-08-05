//+------------------------------------------------------------------+
//| PairSpread_StatArb.mq5                                          |
//| ORDER-098-F — Pairs-spread mean-reversion (stat-arb).           |
//|   IDEA extracted from the fxDreema Jobot "Arbitrage N-Pairs"     |
//|   course family (correlated-basket) — REBUILT with a real SL     |
//|   cage (the course files were NO_SL / uncapped, unshippable).    |
//|                                                                  |
//| Mechanism: two correlated symbols A,B. spread = log(A) - log(B). |
//| Rolling z-score over N closed bars. When the spread stretches    |
//| (|z| > entry), fade it: z>+entry → SELL A + BUY B (A rich vs B); |
//| z<-entry → BUY A + SELL B. Exit when it reverts (|z| < exit) OR  |
//| the SL cage fires (|z| > stop = the divergence kept going — the  |
//| stat-arb tail risk the course ignored). Equal flat lots, hedged, |
//| one basket at a time. NO grid, NO martingale.                   |
//|                                                                  |
//| Needs a HEDGING account (holds long one symbol + short another). |
//| Runs on chart = symbol A; reads symbol B. Both histories must be |
//| present in the tester.                                          |
//+------------------------------------------------------------------+
#property strict
#property description "(EXP)_PairSpread_StatArb — correlated pairs-spread mean-reversion, ORDER-098-F"

#include <Trade\Trade.mqh>

//--------------------------------------------------------------------
// [00] TESTER / OPTIMIZER
//--------------------------------------------------------------------
input bool   _00_OptimizeMode  = false;

//--------------------------------------------------------------------
// [01] PAIR + SPREAD Z-SCORE
//--------------------------------------------------------------------
input string _01_SymbolA       = "EURUSD";  // leg A (chart symbol should equal this)
input string _01_SymbolB       = "GBPUSD";  // leg B (correlated)
input int    _01_ZWindow       = 100;       // rolling bars for spread mean/std
input double _01_EntryZ        = 2.0;       // enter when |z| exceeds this
input double _01_ExitZ         = 0.5;       // take-profit: exit when |z| falls below this (mean revert)
input double _01_StopZ         = 3.5;       // SL cage: exit when |z| exceeds this (divergence ran away)
input bool   _01_AllowLongA    = true;      // allow the BUY-A/SELL-B basket
input bool   _01_AllowShortA   = true;      // allow the SELL-A/BUY-B basket

//--------------------------------------------------------------------
// [05] TRADE MANAGEMENT — equal flat lots, one basket, no grid/MM
//--------------------------------------------------------------------
input double _05_LotA          = 0.10;
input double _05_LotB          = 0.10;

//--------------------------------------------------------------------
// [06] SYSTEM
//--------------------------------------------------------------------
input long   _06_Magic         = 990984;
input ulong  _06_Deviation     = 20;
input bool   _06_AllowLive      = false;    // SAFETY GATE

//--------------------------------------------------------------------
// Globals
//--------------------------------------------------------------------
static bool     g_suppress_log   = false;
static datetime g_last_bar_time  = 0;
static bool     g_bar_checked    = false;
static CTrade   g_trade;

//--------------------------------------------------------------------
// Spread z-score over closed bars [1 .. ZWindow]. false if data missing.
//--------------------------------------------------------------------
bool SpreadZ(double &z_out, double &spread_now)
{
   // need ZWindow+1 closed bars of both symbols
   double sum = 0.0, sumsq = 0.0;
   int    n   = 0;
   for(int s = 1; s <= _01_ZWindow; s++)
   {
      double a = iClose(_01_SymbolA, PERIOD_CURRENT, s);
      double b = iClose(_01_SymbolB, PERIOD_CURRENT, s);
      if(a <= 0.0 || b <= 0.0) return false;   // fail-closed on any missing bar
      double sp = MathLog(a) - MathLog(b);
      sum   += sp;
      sumsq += sp * sp;
      n++;
   }
   if(n < _01_ZWindow) return false;
   double mean = sum / n;
   double var  = (sumsq / n) - (mean * mean);
   if(var <= 0.0) return false;
   double sd = MathSqrt(var);

   // current spread from the just-closed bar (shift 1)
   double a1 = iClose(_01_SymbolA, PERIOD_CURRENT, 1);
   double b1 = iClose(_01_SymbolB, PERIOD_CURRENT, 1);
   if(a1 <= 0.0 || b1 <= 0.0) return false;
   spread_now = MathLog(a1) - MathLog(b1);
   z_out = (spread_now - mean) / sd;
   return true;
}

//--------------------------------------------------------------------
// Basket state — magic-scoped across the two symbols.
// Returns: 0 = flat, +1 = long-A basket (BUY A / SELL B), -1 = short-A basket.
//--------------------------------------------------------------------
int BasketState()
{
   bool longA = false, shortA = false, longB = false, shortB = false;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != _06_Magic) continue;
      string sym = PositionGetString(POSITION_SYMBOL);
      long   ty  = PositionGetInteger(POSITION_TYPE);
      if(sym == _01_SymbolA) { if(ty == POSITION_TYPE_BUY) longA = true; else shortA = true; }
      if(sym == _01_SymbolB) { if(ty == POSITION_TYPE_BUY) longB = true; else shortB = true; }
   }
   if(longA && shortB) return  1;
   if(shortA && longB) return -1;
   if(longA || shortA || longB || shortB) return 2;   // partial/broken basket → treat as "in position, close all"
   return 0;
}

void CloseAllMine()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != _06_Magic) continue;
      string sym = PositionGetString(POSITION_SYMBOL);
      if(sym == _01_SymbolA || sym == _01_SymbolB) g_trade.PositionClose(t);
   }
}

// Opens a basket. dir=+1 → BUY A / SELL B ; dir=-1 → SELL A / BUY B.
void OpenBasket(const int dir)
{
   const bool allow = _06_AllowLive || (bool)MQLInfoInteger(MQL_TESTER);
   if(!allow) { if(!g_suppress_log) PrintFormat("DRYRUN basket dir=%d", dir); return; }

   double askA = SymbolInfoDouble(_01_SymbolA, SYMBOL_ASK);
   double bidA = SymbolInfoDouble(_01_SymbolA, SYMBOL_BID);
   double askB = SymbolInfoDouble(_01_SymbolB, SYMBOL_ASK);
   double bidB = SymbolInfoDouble(_01_SymbolB, SYMBOL_BID);
   if(askA <= 0 || bidA <= 0 || askB <= 0 || bidB <= 0) return;

   // silent-rejection guard: a lot below the broker minimum is refused by the server with NO visible
   // error, which reads as "no signal" (0 trades) in the tester -- see PostNewsReversion rev01 bug.
   const double minLotA = SymbolInfoDouble(_01_SymbolA, SYMBOL_VOLUME_MIN);
   const double minLotB = SymbolInfoDouble(_01_SymbolB, SYMBOL_VOLUME_MIN);
   if(_05_LotA < minLotA || _05_LotB < minLotB)
   {
      if(!g_suppress_log) PrintFormat("PairSpreadArb: LotA %.3f/min %.3f or LotB %.3f/min %.3f -- every order would silently reject, refusing to trade",_05_LotA,minLotA,_05_LotB,minLotB);
      return;
   }

   bool ok = true;
   if(dir == 1)   // BUY A / SELL B
   {
      ok = g_trade.Buy (_05_LotA, _01_SymbolA, askA, 0.0, 0.0, "PSARB_LA");
      ok = g_trade.Sell(_05_LotB, _01_SymbolB, bidB, 0.0, 0.0, "PSARB_SB") && ok;
   }
   else           // SELL A / BUY B
   {
      ok = g_trade.Sell(_05_LotA, _01_SymbolA, bidA, 0.0, 0.0, "PSARB_SA");
      ok = g_trade.Buy (_05_LotB, _01_SymbolB, askB, 0.0, 0.0, "PSARB_LB") && ok;
   }
   // If only one leg filled, the basket is broken (naked directional risk) → close everything mine.
   if(!ok || BasketState() == 2)
   {
      if(!g_suppress_log) Print("basket open incomplete → closing all mine (no naked leg)");
      CloseAllMine();
   }
}

//--------------------------------------------------------------------
// Lifecycle
//--------------------------------------------------------------------
int OnInit()
{
   g_suppress_log = _00_OptimizeMode || (bool)MQLInfoInteger(MQL_OPTIMIZATION);

   if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
   {
      Print("PairSpread_StatArb init FAILED: requires a HEDGING account (holds long + short legs)");
      return INIT_FAILED;
   }
   if(_01_SymbolA == _01_SymbolB)
   {
      Print("PairSpread_StatArb init FAILED: SymbolA == SymbolB");
      return INIT_FAILED;
   }
   // touch symbol B so the tester/terminal loads its series
   if(SymbolInfoDouble(_01_SymbolB, SYMBOL_BID) <= 0.0 && !(bool)MQLInfoInteger(MQL_TESTER))
      Print("PairSpread_StatArb WARNING: symbol B ", _01_SymbolB, " not in Market Watch");

   g_trade.SetExpertMagicNumber(_06_Magic);
   g_trade.SetDeviationInPoints(_06_Deviation);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);

   g_last_bar_time = 0;
   g_bar_checked   = false;

   if(!g_suppress_log)
      PrintFormat("PairSpread_StatArb init | %s/%s Zwin=%d entry=%.1f exit=%.1f stop=%.1f magic=%d",
                  _01_SymbolA, _01_SymbolB, _01_ZWindow, _01_EntryZ, _01_ExitZ, _01_StopZ, (int)_06_Magic);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {}

double OnTester()
{
   double trades = TesterStatistics(STAT_TRADES);
   if(trades < 15) return -1.0;
   double sharpe = TesterStatistics(STAT_SHARPE_RATIO);
   return (sharpe > 0 ? sharpe : -1.0);
}

//--------------------------------------------------------------------
// OnTick — bar-open gated on chart TF
//--------------------------------------------------------------------
void OnTick()
{
   const datetime bar1_time = iTime(_Symbol, PERIOD_CURRENT, 1);
   if(bar1_time != g_last_bar_time)
   {
      g_last_bar_time = bar1_time;
      g_bar_checked   = false;
   }
   if(g_bar_checked) return;
   g_bar_checked = true;

   double z, sp;
   if(!SpreadZ(z, sp)) return;   // fail-closed if either symbol's data isn't ready

   const int state = BasketState();

   if(state == 2) { CloseAllMine(); return; }   // broken basket → flatten, re-assess next bar

   if(state == 0)
   {
      // flat → look for an entry
      if(z >=  _01_EntryZ && _01_AllowShortA) OpenBasket(-1);   // spread rich → SELL A / BUY B
      else if(z <= -_01_EntryZ && _01_AllowLongA) OpenBasket( 1);   // spread cheap → BUY A / SELL B
      return;
   }

   // in a basket → manage exit
   const double az = MathAbs(z);
   if(az <= _01_ExitZ)      { CloseAllMine(); return; }   // reverted to mean → take profit
   if(az >= _01_StopZ)      { CloseAllMine(); return; }   // SL cage → divergence ran away, cut
   // (else hold)
}
