//+------------------------------------------------------------------+
//|  (EXP)_JUMSTOCH_MT5.mq5                                          |
//|  MT5 port of Jum69's JUMSTOCH_FIXEDLOT.mq4 (ORDER-091C-D1e,      |
//|  2026-07-11). Source (read-only): D:\Forex\01_INBOX_NEW\         |
//|  2.1 review EA\MT4 good\JUMSTOCH_FIXEDLOT.mq4 (472 lines,        |
//|  decompiled-style MT4 EA, obfuscated symbol names f0_N/Gd_N).    |
//|                                                                   |
//|  MECHANISM (confirmed by reading the decompiled source, not a    |
//|  paraphrase): 4 independent magic-scoped fixed-lot averaging     |
//|  grids on ONE symbol/chart-TF, up to Level_Max legs @ Range-pip  |
//|  spacing, each leg SL-protected, TP shifts to basket-average +   |
//|  Tp_from_Bep once a basket reaches Star_ModifTp_Bep legs (BEP    |
//|  shift). DiMarti is DECLARED but NEVER wired into any lot calc   |
//|  in the source (confirmed in ORDER-091C-D1) - flat-lot grid, not |
//|  martingale. Lot_mode/Fix_lot/Manage_Lot are ALSO dead in the    |
//|  source (every OrderSend uses the plain `Fixed_Lot` extern, never|
//|  the Lot_mode-computed G_lots_392) - dropped here; this port has |
//|  ONE lot input (`Fixed_Lot`) used everywhere, which is exactly   |
//|  what the source actually does.                                 |
//|                                                                   |
//|  NON-OBVIOUS FINDING (verified line-by-line against the source,  |
//|  ORDER-091C-D1e): the "Trend" block (Buy_Trend/Sell_Trend) is    |
//|  NOT mean-reversion despite the LWMA+Stochastic-filter look - the|
//|  call sites invert the naive reading:                            |
//|    BUY_Trend  fires on Close[1] > LWMA AND stoch < up_level      |
//|                 (price above MA, not overbought -> JOIN the      |
//|                 uptrend; matches the "Trend" naming)             |
//|    SELL_Trend fires on Close[1] < LWMA AND stoch > lo_level      |
//|                 (price below MA, not oversold  -> JOIN the       |
//|                 downtrend)                                       |
//|  The "Counter" block (Buy_Counter/Sell_Counter) IS mean-reversion|
//|  (pure Stochastic band, no MA): stoch<lolevel -> BUY (oversold), |
//|  stoch>uplevel -> SELL (overbought). Ported EXACTLY as coded     |
//|  (same call-site direction mapping) - this is what produced the  |
//|  ORDER-091C-D1 MT4 baseline (EURUSD H1 PF 1.18/7052t), so the    |
//|  "faithful" port must keep it, not "fix" it to the naive reading.|
//|                                                                   |
//|  Digit-aware pip sizing mirrors the source's init() adjustment   |
//|  (Digits==3||5 -> pip = tick_size*10) so Range/SL/TP/Trailing/   |
//|  Tp_from_Bep (all specified in PIPS, not raw MT5 points) convert |
//|  correctly on 5-digit FX and 3-digit JPY-quote symbols alike.    |
//|                                                                   |
//|  HEDGING REQUIRED: 4 independent baskets on one symbol can hold  |
//|  opposing directions simultaneously (Trend vs Counter can        |
//|  disagree) -> netting would merge/corrupt them. Guarded in       |
//|  OnInit.                                                          |
//|                                                                   |
//|  Cosmetic MT4 features intentionally DROPPED (zero effect on     |
//|  trading behavior, confirmed by reading the source): the on-     |
//|  chart Comment()/ObjectLabel dashboard (f0_2/f0_5) and the dead   |
//|  Lot_mode/Fix_lot/Manage_Lot compound-lot machinery.             |
//+------------------------------------------------------------------+
#property copyright "EA_LAB port (2026-07-11) of Jum69 JUMSTOCH_FIXEDLOT.mq4"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
CTrade g_trade;

//====================================================================
//  INPUTS  (mirrors the MT4 externs; Lot_mode/Fix_lot/Manage_Lot
//  dropped as confirmed-dead code - see header)
//====================================================================
input string _i00_ = "== LOT ====================================";
input double Fixed_Lot         = 0.01;   // lot used for EVERY leg, every chain (flat, no escalation)

input string _i01_ = "== PANIC / MANUAL CLOSE ====================";
input bool   Close_Panic       = false;
input bool   Close_Buy_Trend   = false;
input bool   Close_Sell_Trend  = false;
input bool   Close_Buy_Counter = false;
input bool   Close_Sell_Counter= false;

input string _i02_ = "== GLOBAL EQUITY TARGET / RISK ==============";
input bool   Risk_In_Money     = false;
input double Risk_in_money     = 1000.0;
input double Target_Persen     = 1000.0;  // % equity growth vs OnInit balance -> close-all-and-halt-tick

input string _i03_ = "== TREND BLOCK (Buy_Trend/Sell_Trend) =======";
input int    StartHour         = 0;
input int    StopHour          = 24;
input bool   Buy_Trend         = true;
input bool   Sell_Trend        = true;

input string _i04_ = "== COUNTER BLOCK (Buy_Counter/Sell_Counter) ==";
input int    Start_Hour        = 0;
input int    Stop_Hour         = 24;
input bool   Buy_Counter       = true;
input bool   Sell_Counter      = true;

input string _i05_ = "== GRID ======================================";
input int    Magic              = 69;
input double Range              = 21.0;   // leg spacing, PIPS (digit-adjusted)
input int    Level_Max           = 12;     // max legs per basket
input double DiMarti             = 1.7;   // DECLARED, NOT WIRED into lot calc - matches source (confirmed ORDER-091C-D1)
input double SL                  = 253.0; // per-leg SL, PIPS
input double TP                  = 30.0;  // per-leg TP before BEP shift, PIPS
input int    Star_ModifTp_Bep    = 3;     // leg count threshold -> switch TP to basket-avg + Tp_from_Bep
input double Tp_from_Bep         = 11.0;  // PIPS from basket-avg once BEP mode active
input bool   Tp_In_money         = false;
input double Tp_in_money         = 7.0;

input string _i06_ = "== TRAILING ===================================";
input bool   Dtrailing           = true;
input int    StartTrail          = 10;    // PIPS profit (vs basket avg) before trailing arms
input int    Trailing            = 7;     // PIPS trailing distance

input string _i07_ = "== TREND STOCH + LWMA (Indi_Seting) ===========";
input int    kperiod             = 32;
input int    dperiod             = 12;
input int    slowing             = 12;
input int    lo_level            = 25;
input int    up_level            = 75;
input int    maPereode           = 25;

input string _i08_ = "== COUNTER STOCH (Indi_Stoch_2) ================";
input int    k_period            = 32;
input int    d_period             = 12;
input int    s_lowing             = 12;
input int    lolevel               = 30;
input int    uplevel                = 70;

input string _i09_ = "== LIVE SAFETY =================================";
input bool   AllowLive             = false; // tester-gate: must be true to open positions outside Strategy Tester

//====================================================================
//  GLOBALS
//====================================================================
double g_pip;             // Gd_376 equivalent: digit-adjusted pip size in price units
double g_stopLevelPips;    // Gd_384 equivalent: broker min-stop distance, in pips
double g_SL, g_TP, g_Trailing;   // clamped effective values (mirrors init()'s "too tight" re-assignment)
double g_startBalance;
bool   g_quiet = false;

int h_lwma          = INVALID_HANDLE;
int h_stochTrend    = INVALID_HANDLE;
int h_stochCounter  = INVALID_HANDLE;

ulong MAGIC_BUY_TREND, MAGIC_SELL_TREND, MAGIC_BUY_COUNTER, MAGIC_SELL_COUNTER;
string TAG_BUY_TREND    = "JumT-BuyTrend-";
string TAG_SELL_TREND   = "JumT-SellTrend-";
string TAG_BUY_COUNTER  = "JumT-BuyCtr-";
string TAG_SELL_COUNTER = "JumT-SellCtr-";

//====================================================================
//  MARKET / MATH HELPERS
//====================================================================
int HourOf(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour;
}

double NormalizeLot(const double lot)
{
   double minv = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxv = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0) step = 0.01;
   double l = MathRound(lot / step) * step;
   l = MathMax(minv, MathMin(maxv, l));
   return NormalizeDouble(l, 2);
}

// f0_10: compare two prices rounded to broker Points (avoid needless OrderModify/PositionModify spam)
bool SamePoint(const double a, const double b)
{
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pt <= 0.0) return (a == b);
   return (long)MathRound(a / pt) == (long)MathRound(b / pt);
}

// f0_11: anchor +/- N pips depending on direction (BUY adds, SELL subtracts)
double TpFromAnchor(const ENUM_POSITION_TYPE type, const double pips, const double anchor)
{
   if(pips == 0.0) return 0.0;
   if(type == POSITION_TYPE_BUY) return anchor + g_pip * pips;
   return anchor - g_pip * pips;
}

//====================================================================
//  POSITION HELPERS (all scoped to _Symbol + magic; hedging account)
//====================================================================
bool PosIsMine(const int idx, const ulong magic)
{
   ulong tk = PositionGetTicket(idx);
   if(tk == 0) return false;
   if(PositionGetString(POSITION_SYMBOL) != _Symbol) return false;
   if((ulong)PositionGetInteger(POSITION_MAGIC) != magic) return false;
   return true;
}

// f0_13
int CountMagic(const ulong magic)
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(PosIsMine(i, magic)) n++;
   return n;
}

// f0_6
double SumProfitMagic(const ulong magic)
{
   double s = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(PosIsMine(i, magic)) s += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   return s;
}

// f0_3 (positions only - the source's pending-order-delete branch is unreachable dead code:
// this EA only ever opens market orders, never places pending orders)
void CloseAllMagic(const ulong magic)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PosIsMine(i, magic)) continue;
      ulong tk = PositionGetTicket(i);
      g_trade.SetExpertMagicNumber(magic);
      g_trade.PositionClose(tk);
   }
}

// f0_12: weighted-avg open price for one direction within a magic (0 if none open)
double AvgPrice(const ulong magic, const ENUM_POSITION_TYPE type)
{
   double sumPL = 0.0, sumLots = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PosIsMine(i, magic)) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != type) continue;
      double lots = PositionGetDouble(POSITION_VOLUME);
      sumPL   += PositionGetDouble(POSITION_PRICE_OPEN) * lots;
      sumLots += lots;
   }
   if(sumLots > 0.0) return NormalizeDouble(sumPL / sumLots, _Digits);
   return 0.0;
}

// most-recently-opened leg for a magic (grid spacing reference). Mirrors the source's
// scan-and-overwrite loop (ascending index, no break) which ends on the LAST match found -
// i.e. the chronologically newest leg, since MT4 order index and MT5 position index both
// run oldest-to-newest for tickets opened in sequence. Selecting explicitly by max
// POSITION_TIME is equivalent and more robust to any indexing surprises.
bool LastLeg(const ulong magic, ENUM_POSITION_TYPE &type, double &price)
{
   datetime best = 0;
   bool found = false;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(!PosIsMine(i, magic)) continue;
      datetime t = (datetime)PositionGetInteger(POSITION_TIME);
      if(!found || t >= best)
      {
         best  = t;
         type  = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         price = PositionGetDouble(POSITION_PRICE_OPEN);
         found = true;
      }
   }
   return found;
}

//====================================================================
//  ORDER OPEN
//====================================================================
bool OpenMarket(const ENUM_POSITION_TYPE dir, const ulong magic, const string comment)
{
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk)) return false;
   double lot = NormalizeLot(Fixed_Lot);
   if(lot <= 0.0) return false;

   bool allow = AllowLive || (bool)MQLInfoInteger(MQL_TESTER);
   if(!allow)
   {
      if(!g_quiet) PrintFormat("[JUMT5-DRY] open magic=%I64u dir=%d lot=%.2f %s", magic, (int)dir, lot, comment);
      return true;
   }
   g_trade.SetExpertMagicNumber(magic);
   g_trade.SetDeviationInPoints(3);
   // TP intentionally left at 0 here - mirrors the source (OrderSend's TP arg is always 0);
   // TP is set on the very next tick by ModifyBEP(), exactly like the source's f0_9.
   if(dir == POSITION_TYPE_BUY)
   {
      double sl = tk.ask - g_SL * g_pip;
      return g_trade.Buy(lot, _Symbol, 0.0, sl, 0.0, comment);
   }
   double sl = tk.bid + g_SL * g_pip;
   return g_trade.Sell(lot, _Symbol, 0.0, sl, 0.0, comment);
}

//====================================================================
//  GRID ADD  (f0_8)
//====================================================================
void GridAdd(const ulong magic, const string tagPrefix)
{
   int cnt = CountMagic(magic);
   if(cnt <= 0 || cnt >= Level_Max) return;

   ENUM_POSITION_TYPE type; double lastPrice;
   if(!LastLeg(magic, type, lastPrice)) return;

   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk)) return;

   if(type == POSITION_TYPE_BUY)
   {
      double trigger = lastPrice - Range * g_pip;
      if(tk.ask <= trigger) OpenMarket(POSITION_TYPE_BUY, magic, tagPrefix + IntegerToString(cnt));
   }
   else if(type == POSITION_TYPE_SELL)
   {
      double trigger = lastPrice + Range * g_pip;
      if(tk.bid >= trigger) OpenMarket(POSITION_TYPE_SELL, magic, tagPrefix + IntegerToString(cnt));
   }
}

//====================================================================
//  BEP / TP MODIFY  (f0_9)
//====================================================================
void ModifyBEP(const ulong magic)
{
   int cnt = CountMagic(magic);
   if(cnt == 0) return;
   if(Tp_from_Bep == 0.0 || g_TP == 0.0) return;

   double avgSell = AvgPrice(magic, POSITION_TYPE_SELL);
   double avgBuy  = AvgPrice(magic, POSITION_TYPE_BUY);
   double basket  = MathMax(avgSell, avgBuy);   // a chain only ever holds one direction, so this = that direction's avg

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PosIsMine(i, magic)) continue;
      ulong tk = PositionGetTicket(i);
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSl = PositionGetDouble(POSITION_SL);
      double curTp = PositionGetDouble(POSITION_TP);

      double newTp;
      if(cnt < Star_ModifTp_Bep) newTp = TpFromAnchor(type, g_TP, openPrice);
      else                       newTp = TpFromAnchor(type, Tp_from_Bep, basket);

      if(!SamePoint(newTp, curTp))
      {
         g_trade.SetExpertMagicNumber(magic);
         g_trade.PositionModify(tk, curSl, newTp);
      }
   }
}

//====================================================================
//  TRAILING  (f0_14) - the "break" below is a FAITHFUL port of the source's
//  quirk: once one leg's profit distance (vs basket avg) is under StartTrail,
//  the loop BREAKS entirely (not "continue"), skipping any remaining legs for
//  that magic this tick. Kept as-is per the port brief (replicate faithfully).
//====================================================================
void TrailingStop(const ulong magic)
{
   double avgBuy  = AvgPrice(magic, POSITION_TYPE_BUY);
   double avgSell = AvgPrice(magic, POSITION_TYPE_SELL);
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk)) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PosIsMine(i, magic)) continue;
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      ulong ticket = PositionGetTicket(i);
      double curSl = PositionGetDouble(POSITION_SL);
      double curTp = PositionGetDouble(POSITION_TP);

      if(type == POSITION_TYPE_BUY)
      {
         double distPips = (tk.bid - avgBuy) / g_pip;
         if(distPips < StartTrail) break;
         double newSl = NormalizeDouble(tk.bid - g_Trailing * g_pip, _Digits);
         if(curSl == 0.0 || newSl > curSl)
         {
            g_trade.SetExpertMagicNumber(magic);
            g_trade.PositionModify(ticket, newSl, curTp);
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         double distPips = (avgSell - tk.ask) / g_pip;
         if(distPips < StartTrail) break;
         double newSl = NormalizeDouble(tk.ask + g_Trailing * g_pip, _Digits);
         if(curSl == 0.0 || newSl < curSl)
         {
            g_trade.SetExpertMagicNumber(magic);
            g_trade.PositionModify(ticket, newSl, curTp);
         }
      }
   }
}

//====================================================================
//  SESSION GATES  (f0_0 = Trend block, f0_4 = Counter block)
//====================================================================
bool InTrendHours()
{
   int h = HourOf(TimeCurrent());
   if(StartHour > StopHour) return (h >= StartHour || h < StopHour);
   return (h >= StartHour && h < StopHour);
}

bool InCounterHours()
{
   int h = HourOf(TimeCurrent());
   if(Start_Hour > Stop_Hour) return (h >= Start_Hour || h < Stop_Hour);
   return (h >= Start_Hour && h < Stop_Hour);
}

//====================================================================
//  SIGNAL  (f0_1) - ported EXACTLY as coded, including the call-site
//  direction mapping documented in the file header. mode=1 -> Trend
//  block (LWMA + trend-stoch), mode=-1 -> Counter block (pure stoch band).
//  Returns 2 / -2 / 0 exactly matching the source's f0_1 return codes;
//  callers compare against these literal codes, not "buy"/"sell" names.
//====================================================================
int Signal(const int mode)
{
   if(mode == 1 && InTrendHours())
   {
      double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
      double lwma[1];
      if(CopyBuffer(h_lwma, 0, 0, 1, lwma) < 1) return 0;
      double ima = lwma[0];
      double st[1];
      if(CopyBuffer(h_stochTrend, 0, 0, 1, st) < 1) return 0;
      double stoch = st[0];
      if(close1 < ima && stoch > lo_level) return 2;
      if(close1 > ima && stoch < up_level) return -2;
   }
   if(mode == -1 && InCounterHours())
   {
      double st2[1];
      if(CopyBuffer(h_stochCounter, 0, 0, 1, st2) < 1) return 0;
      double stoch2 = st2[0];
      if(stoch2 > uplevel) return 2;
      if(stoch2 < lolevel) return -2;
   }
   return 0;
}

//====================================================================
//  LIFECYCLE
//====================================================================
int OnInit()
{
   // 4 independent magic-scoped baskets on one symbol can hold opposing
   // directions at once (Trend vs Counter can disagree) -> requires hedging.
   if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
   {
      Print("[JUMT5][FATAL] requires a HEDGING account (netting would merge the 4 baskets). INIT_FAILED.");
      return INIT_FAILED;
   }

   int    digits    = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double ticksize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(ticksize <= 0.0) ticksize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int li0 = 1;
   g_pip = ticksize;
   if(digits == 3 || digits == 5) { g_pip = ticksize * 10.0; li0 = 10; }

   double stopLevelRaw = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL); // points
   g_stopLevelPips = stopLevelRaw / li0;

   g_SL = SL; g_TP = TP; g_Trailing = Trailing;
   if(g_SL > 0.0 && g_SL < g_stopLevelPips)      { Print("[JUMT5] stoploss too tight, clamped to broker min: ", g_stopLevelPips); g_SL = g_stopLevelPips; }
   if(g_TP > 0.0 && g_TP < g_stopLevelPips)      { Print("[JUMT5] takeprofit too tight, clamped to broker min: ", g_stopLevelPips); g_TP = g_stopLevelPips; }
   if(g_Trailing < g_stopLevelPips)              { Print("[JUMT5] trailing too tight, clamped to broker min: ", g_stopLevelPips); g_Trailing = g_stopLevelPips; }

   MAGIC_BUY_TREND    = (ulong)(Magic + 9);
   MAGIC_SELL_TREND   = (ulong)(Magic + 99);
   MAGIC_BUY_COUNTER  = (ulong)(Magic + 999);
   MAGIC_SELL_COUNTER = (ulong)(Magic + 9999);

   h_lwma         = iMA(_Symbol, PERIOD_CURRENT, maPereode, 0, MODE_LWMA, PRICE_CLOSE);
   h_stochTrend   = iStochastic(_Symbol, PERIOD_CURRENT, kperiod, dperiod, slowing, MODE_SMA, STO_LOWHIGH);
   h_stochCounter = iStochastic(_Symbol, PERIOD_CURRENT, k_period, d_period, s_lowing, MODE_SMA, STO_LOWHIGH);
   if(h_lwma == INVALID_HANDLE || h_stochTrend == INVALID_HANDLE || h_stochCounter == INVALID_HANDLE)
   {
      Print("[JUMT5][FATAL] indicator handle init failed.");
      return INIT_FAILED;
   }

   g_startBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_quiet = (bool)MQLInfoInteger(MQL_OPTIMIZATION);
   g_trade.SetAsyncMode(false);
   g_trade.LogLevel(LOG_LEVEL_ERRORS);

   PrintFormat("[JUMT5][INIT] ok | pip=%.5f stopLevelPips=%.1f SL=%.1f TP=%.1f Trailing=%.1f Fixed_Lot=%.2f",
               g_pip, g_stopLevelPips, g_SL, g_TP, g_Trailing, Fixed_Lot);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(h_lwma != INVALID_HANDLE)         IndicatorRelease(h_lwma);
   if(h_stochTrend != INVALID_HANDLE)   IndicatorRelease(h_stochTrend);
   if(h_stochCounter != INVALID_HANDLE) IndicatorRelease(h_stochCounter);
}

void OnTick()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double targetAdd = g_startBalance * Target_Persen / 100.0;
   bool panicGlobal = (equity >= g_startBalance + targetAdd) ||
                      (Risk_In_Money && equity <= g_startBalance - Risk_in_money) ||
                      Close_Panic;
   if(panicGlobal)
   {
      CloseAllMagic(MAGIC_BUY_TREND);
      CloseAllMagic(MAGIC_SELL_TREND);
      CloseAllMagic(MAGIC_BUY_COUNTER);
      CloseAllMagic(MAGIC_SELL_COUNTER);
      return;
   }

   if(Close_Buy_Trend)    CloseAllMagic(MAGIC_BUY_TREND);
   if(Close_Sell_Trend)   CloseAllMagic(MAGIC_SELL_TREND);
   if(Close_Buy_Counter)  CloseAllMagic(MAGIC_BUY_COUNTER);
   if(Close_Sell_Counter) CloseAllMagic(MAGIC_SELL_COUNTER);

   if(Tp_In_money)
   {
      double tot = SumProfitMagic(MAGIC_BUY_TREND) + SumProfitMagic(MAGIC_SELL_TREND) +
                   SumProfitMagic(MAGIC_BUY_COUNTER) + SumProfitMagic(MAGIC_SELL_COUNTER);
      if(tot >= Tp_in_money)
      {
         CloseAllMagic(MAGIC_BUY_TREND);
         CloseAllMagic(MAGIC_SELL_TREND);
         CloseAllMagic(MAGIC_BUY_COUNTER);
         CloseAllMagic(MAGIC_SELL_COUNTER);
      }
   }

   GridAdd(MAGIC_BUY_TREND,    TAG_BUY_TREND);
   GridAdd(MAGIC_SELL_TREND,   TAG_SELL_TREND);
   GridAdd(MAGIC_BUY_COUNTER,  TAG_BUY_COUNTER);
   GridAdd(MAGIC_SELL_COUNTER, TAG_SELL_COUNTER);

   ModifyBEP(MAGIC_BUY_TREND);
   ModifyBEP(MAGIC_SELL_TREND);
   ModifyBEP(MAGIC_BUY_COUNTER);
   ModifyBEP(MAGIC_SELL_COUNTER);

   if(Dtrailing)
   {
      TrailingStop(MAGIC_BUY_TREND);
      TrailingStop(MAGIC_SELL_TREND);
      TrailingStop(MAGIC_BUY_COUNTER);
      TrailingStop(MAGIC_SELL_COUNTER);
   }

   if(!Close_Panic)
   {
      if(!Close_Buy_Trend    && Buy_Trend    && CountMagic(MAGIC_BUY_TREND)    == 0 && Signal(1)  == -2) OpenMarket(POSITION_TYPE_BUY,  MAGIC_BUY_TREND,    TAG_BUY_TREND + "0");
      if(!Close_Sell_Trend   && Sell_Trend   && CountMagic(MAGIC_SELL_TREND)   == 0 && Signal(1)  ==  2) OpenMarket(POSITION_TYPE_SELL, MAGIC_SELL_TREND,   TAG_SELL_TREND + "0");
      if(!Close_Buy_Counter  && Buy_Counter  && CountMagic(MAGIC_BUY_COUNTER)  == 0 && Signal(-1) == -2) OpenMarket(POSITION_TYPE_BUY,  MAGIC_BUY_COUNTER,  TAG_BUY_COUNTER + "0");
      if(!Close_Sell_Counter && Sell_Counter && CountMagic(MAGIC_SELL_COUNTER) == 0 && Signal(-1) ==  2) OpenMarket(POSITION_TYPE_SELL, MAGIC_SELL_COUNTER, TAG_SELL_COUNTER + "0");
   }
}

//====================================================================
//  OPTIMIZE CRITERION (optional convenience for the optimizer; not part
//  of the ported behavior) - profit factor gated by a minimum trade count
//  so thin/lucky passes don't top the optimizer results.
//====================================================================
double OnTester()
{
   double trades = TesterStatistics(STAT_TRADES);
   if(trades < 30) return -1.0;
   double pf = TesterStatistics(STAT_PROFIT_FACTOR);
   return (pf > 0 ? pf : -1.0);
}
//+------------------------------------------------------------------+
