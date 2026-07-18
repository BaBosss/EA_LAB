//+------------------------------------------------------------------+
//| (Boss)_AdaptiveGrid_Oil_rev01.mq5                                 |
//|                                                                    |
//| ORIGIN: independent implementation of an "Adaptive Grid Trading   |
//| System" idea described in a public Facebook post (mean-reversion  |
//| grid for WTI oil). No source code was provided or used — only the |
//| conceptual 6-component description. This is an original build.    |
//| chain_id: EA_ADAPTGRID_OIL_20260717_01                            |
//|                                                                    |
//| THE 6 COMPONENTS FROM THE SOURCE IDEA (mapped to code):            |
//|   1. Trend filter via Linear Regression on EMA slope  → [01]       |
//|   2. Dynamic grid spacing via ATR                     → [03]       |
//|   3. Refresh-rate delay between grid adds             → [03]       |
//|   4. Overlap-prevention filter (min distance)         → [03]       |
//|   5. Volume-weighted dynamic basket exit (VWAP+ATR)   → [04]       |
//|   6. Emergency circuit breaker (equity-DD)            → [07]       |
//|                                                                    |
//| RISK CLASSIFICATION (strategy-and-risk rubric):                   |
//|   Grid only, FIXED lot (no martingale, no hedge) = L3, allowed    |
//|   with hard caps. Caps checked before EVERY OrderSend.            |
//|                                                                    |
//| KEY DESIGN CHOICES vs the marketing post:                         |
//|   - Mean-reversion seeding: first leg is a MARKET entry, grid      |
//|     ADDS as price moves AGAINST the basket (average toward VWAP).  |
//|     (Zeus template used a breakout buy-stop seed — deliberately    |
//|     different here because this concept is mean-reversion.)        |
//|   - Per-order stop loss is OPTIONAL and OFF by default to stay     |
//|     faithful to the source (which had none). The circuit breaker  |
//|     + max_positions + max_total_lot are the mandatory protection.  |
//|     Turn _06_UsePerOrderSl=true in the build-on phase to test the  |
//|     with-SL variant (recommended before any live money).          |
//|   - Every claimed metric (PF 5x / DD -16%) is UNVERIFIED. Validate |
//|     on our own both-window + holdout before any verdict.          |
//|                                                                    |
//| NAMING: (Boss)_<strategy>_rev01.mq5 | Magic 990201+ (standalone)  |
//| STATUS: NEW — smoke -> IS/OOS -> artifact -> MC BEFORE demo/live. |
//+------------------------------------------------------------------+
#property strict
#property description "(Boss)_AdaptiveGrid_Oil_rev01 — LinReg-gated ATR mean-reversion grid"
#property description "Symbol: WTI/USOIL  TF: H1  Validated: NOT YET — smoke/IS/OOS/MC pending"

#include <Trade\Trade.mqh>
#include "STANDALONE_RISK_BUNDLE.mqh"

//--------------------------------------------------------------------
// [00] TESTER / OPTIMIZER
//--------------------------------------------------------------------
input string _g00_             = "── [00] TESTER / OPTIMIZER ────────────────";
input bool   _00_OptimizeMode  = false;

//--------------------------------------------------------------------
// [01] TREND FILTER — Linear Regression slope on EMA (component #1)
//   Fits a straight line to the last _01_LrLookback EMA values, takes
//   its slope (price/bar), normalizes by ATR. A BUY grid is paused when
//   norm_slope < -thresh (strong downtrend); a SELL grid when
//   norm_slope > +thresh (strong uptrend). Only NEW baskets are gated.
//--------------------------------------------------------------------
input string _g01_             = "── [01] TREND FILTER (LinReg on EMA) ──────";
input bool   _01_UseTrendFilter = true;
input int    _01_EmaPeriod     = 50;
input int    _01_LrLookback    = 20;     // # of EMA points fitted by the regression
input double _01_SlopeThresh   = 0.05;   // normalized slope gate (|slope|/ATR per bar)

//--------------------------------------------------------------------
// [02] ATR — shared source for spacing, exit target, slope normalization
//--------------------------------------------------------------------
input string _g02_             = "── [02] ATR ───────────────────────────────";
input int    _02_AtrPeriod     = 14;

//--------------------------------------------------------------------
// [03] GRID DISTANCE — ATR spacing (#2) + overlap floor (#4) + refresh delay (#3)
//--------------------------------------------------------------------
input string _g03_             = "── [03] GRID DISTANCE ─────────────────────";
input double _03_DistAtrMult   = 1.0;    // grid spacing = ATR * mult
input double _03_MinDistPips   = 40.0;   // overlap floor — spacing never below this
input int    _03_RefreshDelayBars = 1;   // min bars between grid adds / re-seeds

//--------------------------------------------------------------------
// [04] BASKET EXIT — volume-weighted average + ATR target (component #5)
//   target = VWAP +/- ATR * mult. Whole basket closes at target.
//   Optional partial close on the way (off by default = faithful to source).
//--------------------------------------------------------------------
input string _g04_             = "── [04] BASKET EXIT (VWAP + ATR) ──────────";
input double _04_BasketTpAtrMult = 1.0;  // target distance from VWAP, in ATR
input bool   _04_UsePartialClose = false;
input double _04_PartialPct    = 50.0;   // at this % of the way to target...
input double _04_PartialFrac   = 0.30;   // ...close this fraction of each leg

//--------------------------------------------------------------------
// [05] LOT SIZING — FIXED (keeps EA at L3; no martingale/LOG)
//--------------------------------------------------------------------
input string _g05_             = "── [05] LOT SIZING (FIXED) ────────────────";
input double _05_BaseLot       = 0.10;   // source used 0.3 on $2k; scale to test acct

//--------------------------------------------------------------------
// [06] STOP LOSS — OPTIONAL per-order (OFF by default = faithful to source)
//--------------------------------------------------------------------
input string _g06_             = "── [06] STOP LOSS (optional) ──────────────";
input bool   _06_UsePerOrderSl = false;
input double _06_SlAtrMult     = 6.0;
input double _06_SlMaxPips     = 300.0;

//--------------------------------------------------------------------
// [07] RISK CAPS — hard, checked before EVERY OrderSend (component #6)
//--------------------------------------------------------------------
input string _g07_             = "── [07] RISK CAPS / CIRCUIT BREAKER ───────";
input int    _07_MaxPositions  = 10;     // max grid legs (hard depth cap)
input double _07_MaxTotalLot   = 1.0;    // hard exposure ceiling
input double _07_DailyLossPct  = 5.0;    // halt new trades for the day past this
input double _07_EmergencyDdPct= 25.0;   // circuit breaker: close all + halt

//--------------------------------------------------------------------
// [08] SYSTEM
//--------------------------------------------------------------------
input string _g08_             = "── [08] SYSTEM ────────────────────────────";
enum ENUM_DIR { DIR_BUY = 1, DIR_SELL = -1 };
input ENUM_DIR _08_Direction   = DIR_BUY;   // BUY = long mean-reversion grid
input long   _08_Magic         = 990201;
input ulong  _08_Deviation     = 30;
input bool   _08_AllowLive     = false;     // real orders ONLY when true (keep false in tester too? no — tester auto-allowed)

//--------------------------------------------------------------------
// Globals
//--------------------------------------------------------------------
static bool     g_suppress_log      = false;
static int      g_atr_handle        = INVALID_HANDLE;
static int      g_ema_handle        = INVALID_HANDLE;
static datetime g_last_bar          = 0;
static CTrade   g_trade;
static double   g_day_start_balance = 0.0;
static datetime g_day_stamp         = 0;
static bool     g_halted_today      = false;
static long     g_bar_count         = 0;     // monotonic bar counter (refresh-delay clock)
static long     g_last_add_bar      = -100000;
static bool     g_partial_done      = false;

//--------------------------------------------------------------------
// Pip helper (digit-aware — see CODE SAFETY RULES)
//--------------------------------------------------------------------
double PipSize(const string symbol)
{
   int    digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point  = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(digits == 5 || digits == 3) return point * 10.0;
   return point;   // WTI/indices/metals: 1 point move as configured
}

double GetATR(const int shift)
{
   double buf[1];
   if(g_atr_handle == INVALID_HANDLE) return 0.0;
   if(CopyBuffer(g_atr_handle, 0, shift, 1, buf) < 1) return 0.0;
   return buf[0];
}

//--------------------------------------------------------------------
// Component #1 — Linear Regression slope of the EMA, normalized by ATR.
//   Returns normalized slope (price/bar / ATR). +ve = EMA rising.
//   Returns 0.0 (neutral, passes gate) if data not ready.
//--------------------------------------------------------------------
double NormalizedEmaSlope(const double atr)
{
   const int N = _01_LrLookback;
   if(N < 2 || atr <= 0.0) return 0.0;

   double ema[];
   ArraySetAsSeries(ema, true);
   if(CopyBuffer(g_ema_handle, 0, 1, N, ema) < N) return 0.0;

   // Reorder oldest→newest so x=0..N-1 increases with time; slope sign
   // then matches an up/down trend directly.
   double sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumXX = 0.0;
   for(int j = 0; j < N; j++)
   {
      double x = (double)j;
      double y = ema[N - 1 - j];   // ema[N-1] = oldest, ema[0] = newest
      sumX  += x;
      sumY  += y;
      sumXY += x * y;
      sumXX += x * x;
   }
   double denom = (N * sumXX - sumX * sumX);
   if(MathAbs(denom) < 1e-12) return 0.0;
   double slope = (N * sumXY - sumX * sumY) / denom;   // price per bar
   return slope / atr;
}

// Gate a NEW basket by trend-filter direction. Grid-adds/exits are NOT gated.
bool TrendFilterAllowsSeed(const double atr)
{
   if(!_01_UseTrendFilter) return true;
   double ns = NormalizedEmaSlope(atr);
   if(_08_Direction == DIR_BUY)  return (ns > -_01_SlopeThresh);  // pause longs in strong downtrend
   else                          return (ns <  _01_SlopeThresh);  // pause shorts in strong uptrend
}

//--------------------------------------------------------------------
// Basket introspection — OWN positions identified by MAGIC only
//--------------------------------------------------------------------
bool IsOwn()
{
   return (PositionGetString(POSITION_SYMBOL) == _Symbol &&
           PositionGetInteger(POSITION_MAGIC) == _08_Magic);
}

int BasketPositionCount()
{
   int n = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(IsOwn()) n++;
   }
   return n;
}

double BasketTotalLot()
{
   double lot = 0.0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(IsOwn()) lot += PositionGetDouble(POSITION_VOLUME);
   }
   return lot;
}

double BasketFloatingProfit()
{
   double p = 0.0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(IsOwn()) p += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return p;
}

// Volume-weighted average entry price of the basket (component #5).
double BasketVWAP()
{
   double num = 0.0, den = 0.0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(!IsOwn()) continue;
      double v = PositionGetDouble(POSITION_VOLUME);
      num += PositionGetDouble(POSITION_PRICE_OPEN) * v;
      den += v;
   }
   return (den > 0.0) ? num / den : 0.0;
}

// Extreme fill = lowest open (BUY basket) / highest open (SELL basket).
// Used by the grid-add "price moved further against us" trigger.
double BasketExtremeOpen()
{
   double extreme = 0.0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(!IsOwn()) continue;
      double op = PositionGetDouble(POSITION_PRICE_OPEN);
      if(extreme == 0.0) { extreme = op; continue; }
      if(_08_Direction == DIR_BUY)  extreme = MathMin(extreme, op);
      else                          extreme = MathMax(extreme, op);
   }
   return extreme;
}

void CloseWholeBasket()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(IsOwn()) g_trade.PositionClose(t);
   }
   g_partial_done = false;
}

void PartialCloseFraction(const double frac)
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(!IsOwn()) continue;
      double vol      = PositionGetDouble(POSITION_VOLUME);
      double closeVol = SRB_NormalizeLot(vol * frac);
      if(closeVol <= 0.0 || closeVol >= vol) continue;
      g_trade.PositionClosePartial(t, closeVol);
   }
}

//--------------------------------------------------------------------
// Component #6 — hard caps, checked before EVERY entry.
//--------------------------------------------------------------------
bool RiskCapsOk(const double addLot)
{
   if(g_halted_today) return false;

   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance > 0.0)
   {
      double dd_pct = (balance - equity) / balance * 100.0;
      if(dd_pct >= _07_EmergencyDdPct) return false;
   }
   if(g_day_start_balance > 0.0)
   {
      double day_loss_pct = (g_day_start_balance - equity) / g_day_start_balance * 100.0;
      if(day_loss_pct >= _07_DailyLossPct) { g_halted_today = true; return false; }
   }
   if(BasketPositionCount() >= _07_MaxPositions) return false;
   if(BasketTotalLot() + addLot > _07_MaxTotalLot + 1e-9) return false;
   return true;
}

//--------------------------------------------------------------------
// Open one leg (market). Applies optional per-order SL. Returns true on
// success (or dry-run pass). allow=false → dry-run log only.
//--------------------------------------------------------------------
bool OpenLeg(const bool allow, const double lot, const double slPips, const string tag)
{
   const int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double pip     = PipSize(_Symbol);
   const double ask     = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid     = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double slDist  = _06_UsePerOrderSl ? slPips * pip : 0.0;

   if(!allow)
   {
      if(!g_suppress_log) PrintFormat("DRYRUN %s %s lot=%.2f", tag, _08_Direction==DIR_BUY?"BUY":"SELL", lot);
      return true;
   }

   bool ok;
   if(_08_Direction == DIR_BUY)
   {
      double sl = (slDist > 0.0) ? NormalizeDouble(ask - slDist, digits) : 0.0;
      ok = g_trade.Buy(lot, _Symbol, ask, sl, 0.0, tag);
   }
   else
   {
      double sl = (slDist > 0.0) ? NormalizeDouble(bid + slDist, digits) : 0.0;
      ok = g_trade.Sell(lot, _Symbol, bid, sl, 0.0, tag);
   }
   if(!ok && !g_suppress_log)
      PrintFormat("%s FAILED: %d %s", tag, g_trade.ResultRetcode(), g_trade.ResultComment());
   return ok;
}

//--------------------------------------------------------------------
// Lifecycle
//--------------------------------------------------------------------
int OnInit()
{
   g_suppress_log = _00_OptimizeMode || (bool)MQLInfoInteger(MQL_OPTIMIZATION);

   g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, _02_AtrPeriod);
   g_ema_handle = iMA(_Symbol, PERIOD_CURRENT, _01_EmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(g_atr_handle == INVALID_HANDLE || g_ema_handle == INVALID_HANDLE)
   {
      Print("AdaptiveGrid_Oil: indicator handle failed");
      return INIT_FAILED;
   }

   SRB_Init(_Symbol, _07_MaxTotalLot);
   SRB_SetVerbose(!g_suppress_log);

   g_trade.SetExpertMagicNumber(_08_Magic);
   g_trade.SetDeviationInPoints(_08_Deviation);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);

   g_last_bar          = 0;
   g_bar_count         = 0;
   g_last_add_bar      = -100000;
   g_partial_done      = false;
   g_day_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_day_stamp         = 0;
   g_halted_today      = false;

   if(!g_suppress_log)
      PrintFormat("AdaptiveGrid_Oil init | magic=%d dir=%s trendFilter=%s AllowLive=%s",
                  _08_Magic, _08_Direction==DIR_BUY?"BUY":"SELL",
                  _01_UseTrendFilter?"ON":"OFF", _08_AllowLive?"YES":"NO");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_atr_handle != INVALID_HANDLE) { IndicatorRelease(g_atr_handle); g_atr_handle = INVALID_HANDLE; }
   if(g_ema_handle != INVALID_HANDLE) { IndicatorRelease(g_ema_handle); g_ema_handle = INVALID_HANDLE; }
}

double OnTester()
{
   double trades = TesterStatistics(STAT_TRADES);
   if(trades < 30) return -1.0;
   double dd = TesterStatistics(STAT_EQUITY_DDREL_PERCENT);
   double pf = TesterStatistics(STAT_PROFIT_FACTOR);
   if(dd <= 0.0) return -1.0;
   return pf / (1.0 + dd / 100.0);   // reward PF, penalize DD — grid-stress fitness
}

void CheckNewDay()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   datetime day_stamp = (datetime)(dt.year * 10000 + dt.mon * 100 + dt.day);
   if(day_stamp != g_day_stamp)
   {
      g_day_stamp         = day_stamp;
      g_day_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_halted_today      = false;
   }
}

//--------------------------------------------------------------------
// OnTick — bar-open gated
//--------------------------------------------------------------------
void OnTick()
{
   CheckNewDay();

   const datetime cur_bar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(cur_bar == g_last_bar) return;
   g_last_bar = cur_bar;
   g_bar_count++;

   const double atr = GetATR(1);
   if(atr <= 0.0) return;

   const double pip       = PipSize(_Symbol);
   const double distPrice = MathMax(atr * _03_DistAtrMult, _03_MinDistPips * pip);
   const double slPips    = MathMin(_06_SlAtrMult * atr / pip, _06_SlMaxPips);

   // ── Component #6: emergency circuit breaker ──────────────────────
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance > 0.0)
   {
      double dd_pct = (balance - equity) / balance * 100.0;
      if(dd_pct >= _07_EmergencyDdPct)
      {
         if(BasketPositionCount() > 0)
         {
            if(!g_suppress_log) PrintFormat("CIRCUIT BREAKER: DD %.2f%% >= %.2f%% -> close all", dd_pct, _07_EmergencyDdPct);
            CloseWholeBasket();
         }
         g_halted_today = true;
         return;
      }
   }

   const bool allow = _08_AllowLive || (bool)MQLInfoInteger(MQL_TESTER);
   const int  posCount = BasketPositionCount();

   //================================================================
   // A) Manage an OPEN basket: exit (VWAP+ATR) → partial → grid-add
   //================================================================
   if(posCount > 0)
   {
      const double vwap   = BasketVWAP();
      const double tpDist = atr * _04_BasketTpAtrMult;
      const double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      // Component #5: whole-basket exit at VWAP +/- ATR*mult.
      double target, progress;
      if(_08_Direction == DIR_BUY)
      {
         target   = vwap + tpDist;
         progress = (tpDist > 0.0) ? (bid - vwap) / tpDist : 0.0;
         if(bid >= target)
         {
            if(!g_suppress_log) PrintFormat("BASKET TP (BUY): bid=%.5f >= target=%.5f (vwap=%.5f)", bid, target, vwap);
            CloseWholeBasket();
            return;
         }
      }
      else
      {
         target   = vwap - tpDist;
         progress = (tpDist > 0.0) ? (vwap - ask) / tpDist : 0.0;
         if(ask <= target)
         {
            if(!g_suppress_log) PrintFormat("BASKET TP (SELL): ask=%.5f <= target=%.5f (vwap=%.5f)", ask, target, vwap);
            CloseWholeBasket();
            return;
         }
      }

      // Optional partial close on the way to target.
      if(_04_UsePartialClose && !g_partial_done && progress * 100.0 >= _04_PartialPct)
      {
         PartialCloseFraction(_04_PartialFrac);
         g_partial_done = true;
      }

      // Grid-add: price moved another distPrice AGAINST the basket
      // (component #2 spacing + #3 refresh delay + #4 overlap floor).
      if(posCount < _07_MaxPositions &&
         (g_bar_count - g_last_add_bar) >= _03_RefreshDelayBars)
      {
         const double extreme = BasketExtremeOpen();
         bool trigger = (_08_Direction == DIR_BUY)
            ? (bid <= extreme - distPrice)
            : (ask >= extreme + distPrice);

         if(trigger)
         {
            double lot = SRB_NormalizeLot(_05_BaseLot);
            if(lot > 0.0 && RiskCapsOk(lot))
            {
               if(OpenLeg(allow, lot, slPips, "GRID_ADD"))
               {
                  g_last_add_bar = g_bar_count;
                  g_partial_done = false;   // basket VWAP changed → re-arm partial
               }
            }
         }
      }
      return;
   }

   //================================================================
   // B) No basket open: seed leg 1 (mean-reversion market entry),
   //    gated by the LinReg trend filter (component #1) + refresh delay.
   //================================================================
   if((g_bar_count - g_last_add_bar) < _03_RefreshDelayBars) return;
   if(!TrendFilterAllowsSeed(atr)) return;

   double lot = SRB_NormalizeLot(_05_BaseLot);
   if(lot <= 0.0) return;
   if(!RiskCapsOk(lot)) return;

   if(OpenLeg(allow, lot, slPips, "SEED"))
   {
      g_last_add_bar = g_bar_count;
      g_partial_done = false;
   }
}

//+------------------------------------------------------------------+
//| DEPLOYMENT NOTES (write presets as .set files, not hardcoded)    |
//|                                                                    |
//| To run BOTH directions (the post implies a long-biased grid, but  |
//| oil mean-reverts both ways): attach the SAME compiled EA twice —  |
//|   long.set : _08_Direction=BUY  _08_Magic=990201                  |
//|   short.set: _08_Direction=SELL _08_Magic=990202                  |
//| Different magics keep the two baskets independent. Check          |
//| correlation with corr_monthly.py before running both live.        |
//|                                                                    |
//| PRIMARY LEVERS TO SWEEP (VERDICT GATE requires >=3 swept):        |
//|   _01_SlopeThresh · _01_LrLookback · _03_DistAtrMult ·            |
//|   _03_MinDistPips · _04_BasketTpAtrMult · _07_MaxPositions        |
//| Test on BOTH windows (trend year + recent) + a holdout before     |
//| any verdict. Then try _06_UsePerOrderSl=true (with-SL variant).   |
//+------------------------------------------------------------------+
