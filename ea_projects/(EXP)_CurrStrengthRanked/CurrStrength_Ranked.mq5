//+------------------------------------------------------------------+
//| CurrStrength_Ranked.mq5                                          |
//| ORDER-098-E — Currency-strength BUILD-ON: strongest-vs-weakest   |
//|   ranking + selectable exit modes.                              |
//|                                                                  |
//| Build-on of ORDER-098-D (naked fixed-chart probe = PF 1.01/1.01  |
//| both-window EURJPY H4, marginal). This version implements the    |
//| user's vision: ONE instance scans a universe of crosses each bar,|
//| and trades only the SINGLE most extreme strength-differential    |
//| pair (highest conviction) instead of a fixed chart — should lift |
//| win% off the ~42% breakeven line. Exit tricks are selectable     |
//| ENUM inputs so each is a sweepable lever.                       |
//|                                                                  |
//| Strength core reused from 098-D: 7-pair USD-major basket, each   |
//| currency's momentum vs USD. Runs single-instance multi-symbol:   |
//| trades other symbols via CTrade(symbol), manages positions by    |
//| magic across all symbols. Real ATR SL. Flat lot base (+ optional |
//| capped pyramid). NO uncapped martingale.                        |
//+------------------------------------------------------------------+
#property strict
#property description "(EXP)_CurrStrength_Ranked — strength ranking + selectable exits, ORDER-098-E"

#include <Trade\Trade.mqh>

//--------------------------------------------------------------------
// [00] TESTER / OPTIMIZER
//--------------------------------------------------------------------
input bool   _00_OptimizeMode  = false;

//--------------------------------------------------------------------
// [01] STRENGTH METER + RANKING
//--------------------------------------------------------------------
input string _01_Universe       = "EURJPY,GBPJPY,EURGBP,EURAUD,GBPAUD,EURCAD,CADJPY,GBPCHF";
input int    _01_LookbackBars   = 24;     // momentum lookback for the strength meter
input double _01_EntryThreshold = 0.010;  // top pair's |strength diff| must exceed this
input int    _01_MaxConcurrent  = 3;      // max simultaneous open positions (magic-scoped) — cap
input bool   _01_AllowBuy       = true;
input bool   _01_AllowSell      = true;

//--------------------------------------------------------------------
// [02] SL / TP (ATR-based)
//--------------------------------------------------------------------
input int    _02_AtrPeriod      = 14;
input double _02_SlAtrMult       = 2.0;
input double _02_TpAtrMult       = 3.0;   // used by FIXED_ATR & as the far target otherwise

//--------------------------------------------------------------------
// [04] EXIT MODE (selectable — each a sweepable lever)
//--------------------------------------------------------------------
enum ENUM_EXIT_MODE
{
   EXIT_FIXED_ATR = 0,   // set SL/TP at entry, no management (098-D baseline)
   EXIT_TRAILING  = 1,   // ATR trailing stop, no fixed TP
   EXIT_PARTIAL_BE= 2    // partial-close at R1 then move SL to break-even, TP at far target
};
input ENUM_EXIT_MODE _04_ExitMode = EXIT_FIXED_ATR;
input double _04_TrailAtrMult   = 2.0;    // TRAILING: SL trails this * ATR behind price
input double _04_PartialAtR     = 1.0;    // PARTIAL_BE: take partial at this * initial-risk (R)
input double _04_PartialFrac    = 0.50;   // PARTIAL_BE: fraction of volume to close at R1

//--------------------------------------------------------------------
// [05] PYRAMID (optional, capped — NOT martingale: adds only while in profit & strength persists)
//--------------------------------------------------------------------
input bool   _05_PyramidOn      = false;
input int    _05_PyramidMaxAdds = 2;      // hard cap on added legs per pair
input double _05_PyramidStepAtR = 1.0;    // add a leg every this * R of favourable move
input double _05_LotSize        = 0.01;   // base flat lot per leg (NEVER escalated in size)

//--------------------------------------------------------------------
// [06] SYSTEM
//--------------------------------------------------------------------
input long   _06_Magic          = 990983;
input ulong  _06_Deviation      = 20;
input bool   _06_AllowLive       = false;  // SAFETY GATE

//--------------------------------------------------------------------
// Globals
//--------------------------------------------------------------------
static bool     g_suppress_log   = false;
static datetime g_last_bar_time  = 0;
static bool     g_bar_checked    = false;
static CTrade   g_trade;

#define UNI_CAP 16
static string   g_uni[UNI_CAP];
static int      g_uni_atr[UNI_CAP];   // ATR handle per universe symbol
static int      g_uni_n = 0;

//--------------------------------------------------------------------
// Strength core (reused from 098-D — 7-pair USD-major basket)
//--------------------------------------------------------------------
bool Momentum(const string symbol, double &mom_out)
{
   double c_new = iClose(symbol, PERIOD_CURRENT, 1);
   double c_old = iClose(symbol, PERIOD_CURRENT, 1 + _01_LookbackBars);
   if(c_new <= 0.0 || c_old <= 0.0) return false;
   mom_out = (c_new / c_old) - 1.0;
   return true;
}

bool CurrencyStrength(const string ccy, double &s_out)
{
   if(ccy == "USD") { s_out = 0.0; return true; }
   double m;
   if(ccy == "EUR") { if(!Momentum("EURUSD", m)) return false; s_out =  m; return true; }
   if(ccy == "GBP") { if(!Momentum("GBPUSD", m)) return false; s_out =  m; return true; }
   if(ccy == "AUD") { if(!Momentum("AUDUSD", m)) return false; s_out =  m; return true; }
   if(ccy == "NZD") { if(!Momentum("NZDUSD", m)) return false; s_out =  m; return true; }
   if(ccy == "JPY") { if(!Momentum("USDJPY", m)) return false; s_out = -m; return true; }
   if(ccy == "CHF") { if(!Momentum("USDCHF", m)) return false; s_out = -m; return true; }
   if(ccy == "CAD") { if(!Momentum("USDCAD", m)) return false; s_out = -m; return true; }
   return false;
}

// strength(base) - strength(quote) for a 6-char pair. false if either leg unavailable/unknown.
bool PairDiff(const string pair, double &diff_out)
{
   if(StringLen(pair) < 6) return false;
   double sb, sq;
   if(!CurrencyStrength(StringSubstr(pair, 0, 3), sb)) return false;
   if(!CurrencyStrength(StringSubstr(pair, 3, 3), sq)) return false;
   diff_out = sb - sq;
   return true;
}

//--------------------------------------------------------------------
// Position helpers (magic-scoped, ACROSS all symbols — single instance manages many)
//--------------------------------------------------------------------
int CountMyPositions()
{
   int n = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) == _06_Magic) n++;
   }
   return n;
}

bool HasPositionOn(const string symbol, int &adds_out)
{
   adds_out = 0;
   bool found = false;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != _06_Magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
      found = true;
      adds_out++;   // counts legs on this symbol (for pyramid cap)
   }
   return found;
}

int UniIndex(const string symbol)
{
   for(int i = 0; i < g_uni_n; i++) if(g_uni[i] == symbol) return i;
   return -1;
}

bool AtrOf(const string symbol, double &atr_out)
{
   int idx = UniIndex(symbol);
   if(idx < 0 || g_uni_atr[idx] == INVALID_HANDLE) return false;
   double buf[];
   if(CopyBuffer(g_uni_atr[idx], 0, 1, 1, buf) < 1) return false;
   atr_out = buf[0];
   return (atr_out > 0.0);
}

//--------------------------------------------------------------------
// Universe parsing
//--------------------------------------------------------------------
void ParseUniverse()
{
   g_uni_n = 0;
   string parts[];
   int k = StringSplit(_01_Universe, ',', parts);
   for(int i = 0; i < k && g_uni_n < UNI_CAP; i++)
   {
      string s = parts[i];
      StringTrimLeft(s); StringTrimRight(s);
      if(StringLen(s) < 6) continue;
      g_uni[g_uni_n] = s;
      g_uni_atr[g_uni_n] = iATR(s, PERIOD_CURRENT, _02_AtrPeriod);
      g_uni_n++;
   }
}

//--------------------------------------------------------------------
// Entry: find the single most-extreme pair over threshold with no existing position
//--------------------------------------------------------------------
void TryRankedEntry()
{
   if(CountMyPositions() >= _01_MaxConcurrent) return;

   string best_pair = "";
   double best_abs  = 0.0;
   int    best_dir  = 0;

   for(int i = 0; i < g_uni_n; i++)
   {
      double diff;
      if(!PairDiff(g_uni[i], diff)) continue;        // fail-closed: skip pairs missing basket data
      double a = MathAbs(diff);
      if(a <= _01_EntryThreshold) continue;
      int adds;
      if(HasPositionOn(g_uni[i], adds)) continue;     // one entry per pair (pyramid handled elsewhere)
      if(a > best_abs) { best_abs = a; best_pair = g_uni[i]; best_dir = (diff > 0) ? 1 : -1; }
   }

   if(best_pair == "") return;
   if(best_dir ==  1 && !_01_AllowBuy)  return;
   if(best_dir == -1 && !_01_AllowSell) return;

   OpenLeg(best_pair, best_dir);
}

void OpenLeg(const string pair, const int dir)
{
   double atr;
   if(!AtrOf(pair, atr)) return;   // fail-closed

   const int    digits = (int)SymbolInfoInteger(pair, SYMBOL_DIGITS);
   const double ask    = SymbolInfoDouble(pair, SYMBOL_ASK);
   const double bid    = SymbolInfoDouble(pair, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0) return;

   const double sl_dist = _02_SlAtrMult * atr;
   const double tp_dist = _02_TpAtrMult * atr;
   const bool   use_tp  = (_04_ExitMode != EXIT_TRAILING);   // trailing carries no fixed TP

   double sl_price, tp_price;
   if(dir == 1)
   {
      sl_price = NormalizeDouble(ask - sl_dist, digits);
      tp_price = use_tp ? NormalizeDouble(ask + tp_dist, digits) : 0.0;
   }
   else
   {
      sl_price = NormalizeDouble(bid + sl_dist, digits);
      tp_price = use_tp ? NormalizeDouble(bid - tp_dist, digits) : 0.0;
   }

   const bool allow = _06_AllowLive || (bool)MQLInfoInteger(MQL_TESTER);
   if(!allow)
   {
      if(!g_suppress_log) PrintFormat("DRYRUN %s %s atr=%.5f", pair, dir==1?"BUY":"SELL", atr);
      return;
   }

   // silent-rejection guard: a lot below the broker minimum is refused by the server with NO visible
   // error, which reads as "no signal" (0 trades) in the tester -- see PostNewsReversion rev01 bug.
   // (multi-symbol EA -- minlot must be checked per traded pair, not per _Symbol)
   const double minLot = SymbolInfoDouble(pair, SYMBOL_VOLUME_MIN);
   if(_05_LotSize < minLot){ if(!g_suppress_log) PrintFormat("CurrStrengthRanked: LotSize %.3f < %s broker min %.3f -- every order would silently reject, refusing to trade",_05_LotSize,pair,minLot); return; }

   bool ok = (dir == 1)
      ? g_trade.Buy (_05_LotSize, pair, ask, sl_price, tp_price, "CSTRK")
      : g_trade.Sell(_05_LotSize, pair, bid, sl_price, tp_price, "CSTRK");
   if(!ok && !g_suppress_log)
      PrintFormat("ORDER FAILED %s: %d %s", pair, g_trade.ResultRetcode(), g_trade.ResultComment());
}

//--------------------------------------------------------------------
// Position management: trailing / partial-BE / pyramid (per open leg, magic-scoped)
//--------------------------------------------------------------------
void ManagePositions()
{
   if(_04_ExitMode == EXIT_FIXED_ATR && !_05_PyramidOn) return;   // nothing to manage

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != _06_Magic) continue;

      const string sym   = PositionGetString(POSITION_SYMBOL);
      const long   ptype = PositionGetInteger(POSITION_TYPE);
      const double open  = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl    = PositionGetDouble(POSITION_SL);
      const double vol   = PositionGetDouble(POSITION_VOLUME);
      const int    dig   = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

      double atr;
      if(!AtrOf(sym, atr)) continue;
      const double risk = _02_SlAtrMult * atr;   // initial 1R distance
      const double bid  = SymbolInfoDouble(sym, SYMBOL_BID);
      const double ask  = SymbolInfoDouble(sym, SYMBOL_ASK);
      const double px   = (ptype == POSITION_TYPE_BUY) ? bid : ask;   // current MTM side

      // --- TRAILING: pull SL to trail_dist behind current price, only in the tighten direction ---
      if(_04_ExitMode == EXIT_TRAILING)
      {
         const double td = _04_TrailAtrMult * atr;
         if(ptype == POSITION_TYPE_BUY)
         {
            double newsl = NormalizeDouble(px - td, dig);
            if(newsl > sl || sl == 0.0) g_trade.PositionModify(t, newsl, 0.0);
         }
         else
         {
            double newsl = NormalizeDouble(px + td, dig);
            if(newsl < sl || sl == 0.0) g_trade.PositionModify(t, newsl, 0.0);
         }
      }

      // --- PARTIAL_BE: at +PartialAtR of favourable move, close a fraction once & move SL to BE ---
      if(_04_ExitMode == EXIT_PARTIAL_BE && risk > 0.0)
      {
         const double move = (ptype == POSITION_TYPE_BUY) ? (px - open) : (open - px);
         const bool   atBE = (ptype == POSITION_TYPE_BUY) ? (sl >= open) : (sl <= open && sl != 0.0);
         const double cur_tp = PositionGetDouble(POSITION_TP);   // capture BEFORE partial close (selection can go stale after)
         if(move >= _04_PartialAtR * risk && !atBE)
         {
            // Move SL to break-even FIRST: once this succeeds, atBE gates this block next bar,
            // so a failed partial can't trigger repeated partial-closes (C3 robustness).
            g_trade.PositionModify(t, NormalizeDouble(open, dig), cur_tp);   // SL → break-even, keep TP
            double closeVol = NormalizeDouble(vol * _04_PartialFrac, 2);
            double vmin = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
            if(closeVol >= vmin && (vol - closeVol) >= vmin)
               g_trade.PositionClosePartial(t, closeVol);
         }
      }
   }

   if(_05_PyramidOn) TryPyramid();
}

// Adds a capped leg on a pair we already hold, only while in profit AND strength still extreme
// in the same direction. Size is NOT escalated (flat _05_LotSize) → capped pyramid, not martingale.
void TryPyramid()
{
   if(CountMyPositions() >= _01_MaxConcurrent) return;
   for(int i = 0; i < g_uni_n; i++)
   {
      const string pair = g_uni[i];
      int adds;
      if(!HasPositionOn(pair, adds)) continue;
      if(adds >= _05_PyramidMaxAdds + 1) continue;   // +1 = the original leg

      double diff;
      if(!PairDiff(pair, diff)) continue;
      if(MathAbs(diff) <= _01_EntryThreshold) continue;
      int dir = (diff > 0) ? 1 : -1;

      double atr;
      if(!AtrOf(pair, atr)) continue;

      // require the price to have moved PyramidStepAtR*R in favour since the last leg's open
      // (approx: compare current px vs the most-recent same-symbol position open)
      double lastOpen = 0; datetime lastTime = 0;
      for(int j = 0; j < PositionsTotal(); j++)
      {
         ulong t = PositionGetTicket(j);
         if(!PositionSelectByTicket(t)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != _06_Magic) continue;
         if(PositionGetString(POSITION_SYMBOL) != pair) continue;
         datetime ot = (datetime)PositionGetInteger(POSITION_TIME);
         if(ot >= lastTime) { lastTime = ot; lastOpen = PositionGetDouble(POSITION_PRICE_OPEN); }
      }
      if(lastOpen <= 0) continue;
      const double bid = SymbolInfoDouble(pair, SYMBOL_BID);
      const double ask = SymbolInfoDouble(pair, SYMBOL_ASK);
      const double px  = (dir == 1) ? bid : ask;
      const double fav = (dir == 1) ? (px - lastOpen) : (lastOpen - px);
      if(fav >= _05_PyramidStepAtR * _02_SlAtrMult * atr)
         OpenLeg(pair, dir);
   }
}

//--------------------------------------------------------------------
// Lifecycle
//--------------------------------------------------------------------
int OnInit()
{
   g_suppress_log = _00_OptimizeMode || (bool)MQLInfoInteger(MQL_OPTIMIZATION);

   g_trade.SetExpertMagicNumber(_06_Magic);
   g_trade.SetDeviationInPoints(_06_Deviation);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);

   g_last_bar_time = 0;
   g_bar_checked   = false;

   // Pyramid stacks multiple same-direction legs on ONE symbol → needs a HEDGING account
   // (on a netting account those legs net into a single position and the per-leg management
   // is meaningless). Base/exit modes are one-position-per-symbol and are netting-safe.
   if(_05_PyramidOn &&
      (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
   {
      Print("CurrStrength_Ranked init FAILED: _05_PyramidOn requires a HEDGING account");
      return INIT_FAILED;
   }

   ParseUniverse();
   if(g_uni_n == 0) { Print("CurrStrength_Ranked init FAILED: empty universe"); return INIT_FAILED; }
   for(int i = 0; i < g_uni_n; i++)
      if(g_uni_atr[i] == INVALID_HANDLE)
      { PrintFormat("init FAILED: ATR handle for %s", g_uni[i]); return INIT_FAILED; }

   if(!g_suppress_log)
      PrintFormat("CurrStrength_Ranked init | uni=%d thr=%.4f exit=%d maxPos=%d pyramid=%s magic=%d",
                  g_uni_n, _01_EntryThreshold, (int)_04_ExitMode, _01_MaxConcurrent,
                  _05_PyramidOn ? "ON" : "off", (int)_06_Magic);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   for(int i = 0; i < g_uni_n; i++)
      if(g_uni_atr[i] != INVALID_HANDLE) { IndicatorRelease(g_uni_atr[i]); g_uni_atr[i] = INVALID_HANDLE; }
}

double OnTester()
{
   double trades = TesterStatistics(STAT_TRADES);
   if(trades < 15) return -1.0;
   double sharpe = TesterStatistics(STAT_SHARPE_RATIO);
   return (sharpe > 0 ? sharpe : -1.0);
}

//--------------------------------------------------------------------
// OnTick — bar-open gated on the CHART symbol's TF (the scan clock)
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

   ManagePositions();   // trailing/partial/pyramid on existing legs first
   TryRankedEntry();    // then a fresh top-ranked entry if capacity allows
}
