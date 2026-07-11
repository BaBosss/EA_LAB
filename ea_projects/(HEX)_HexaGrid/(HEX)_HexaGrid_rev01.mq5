//+------------------------------------------------------------------+
//|  (HEX)_HexaGrid_rev01.mq5                                         |
//|  6 independent magic-scoped trading systems sharing ONE grid      |
//|  recovery engine. Systems 1-4 = trend, 5-6 = sideways.            |
//|                                                                   |
//|  RISK CLASS: L4 (grid + CAPPED martingale x1.33). Accepted by     |
//|  user 2026-07-11 (informed: chose global equity cap after 60%     |
//|  worst-case DD was surfaced). Guards that make it L4 not L5:      |
//|   - martingale CAPPED at _G_MaxLevels (10) legs                   |
//|   - every leg carries a real server-side catastrophic SL         |
//|   - first leg requires a valid entry signal (entry edge)         |
//|   - global equity cap closes everything at _G_GlobalCapPct        |
//|  Buy/Sell run as two INDEPENDENT directional baskets (not a       |
//|  rescue-hedge) -> requires a HEDGING account (guard in OnInit).   |
//|                                                                   |
//|  Defaults are CONSERVATIVE, UNOPTIMIZED starting values (user     |
//|  could not run the optimizer). Backtest on real ticks before any  |
//|  demo/live use. See backtest-report-analyzer next.                |
//+------------------------------------------------------------------+
#property copyright "EA_LAB"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

CTrade g_trade;

//====================================================================
//  ENUMS
//====================================================================
enum ENUM_SLOPE_MODE
{
   SLOPE_ATR_NORM = 0,   // (dEMA/bar)/ATR >= threshold  (symbol/TF independent)
   SLOPE_POINTS   = 1,   // dEMA over N bars in POINTS   >= threshold
   SLOPE_DEGREE   = 2     // atan(deltaPips/bars)*57.3 deg >= threshold (needs scale)
};

enum ENUM_GRID_SPACING_MODE
{
   GRID_ATR    = 0,      // spacing = mult * ATR  (multi-symbol adaptive) <-- default
   GRID_POINTS = 1        // spacing = fixed points
};

enum ENUM_ENTRY_TYPE
{
   ENT_EMA14_CROSS = 1,  // sys1: price crosses EMA14
   ENT_STOCH_CROSS = 2,  // sys2: stoch touches 30/70 (trend)
   ENT_RSI_REV     = 3,  // sys3: RSI 30/70 + divergence (trend)
   ENT_DI_FLIP     = 4,  // sys4: DI flip while ADX rising
   ENT_STOCH_BAND  = 5,  // sys5: stoch 20/80 (range)
   ENT_RSI_BAND    = 6    // sys6: RSI 30/70 M15 + divergence (range)
};

//====================================================================
//  INPUTS
//====================================================================
input string _g00_ = "== [00] GLOBAL ENGINE =====================";
input double _G_LotMult          = 1.33;   // martingale multiplier per leg
input int    _G_MaxLevels        = 10;     // max legs per basket (cap)
input double _G_RiskPerBasketPct = 2.0;    // worst-case (full stack + SL) loss cap %/basket
input ENUM_GRID_SPACING_MODE _G_SpacingMode = GRID_ATR;
input double _G_SpacingATRmult   = 1.5;    // GRID_ATR: spacing = mult*ATR
input int    _G_SpacingPoints    = 1500;   // GRID_POINTS: fixed spacing (points)
input double _G_SL_ATRmult       = 12.0;   // catastrophic SL distance = mult*ATR (per leg)
input int    _G_SL_Points        = 12000;  // GRID_POINTS: catastrophic SL distance (points)
input int    _G_ATR_Period       = 14;
input ENUM_TIMEFRAMES _G_ATR_TF  = PERIOD_H1;

input string _g01_ = "== [01] GLOBAL RISK CAPS ==================";
input double _G_GlobalCapPct     = 18.0;   // total floating loss across all 6 -> close all + halt
input double _G_MaxTotalLot      = 20.0;   // hard ceiling on combined open lots
input double _G_TrailArmPct      = 3.0;    // basket float profit % to ARM trailing lock
input double _G_TrailGivebackPct = 30.0;   // give back this % of peak -> lock profit
input double _G_MaxLotClamp      = 5.0;    // per-order hard lot ceiling (0=off)

input string _g02_ = "== [02] REGIME (EMA224 slope) =============";
input int    _G_EMA224_Period    = 224;
input ENUM_SLOPE_MODE _G_SlopeMode = SLOPE_ATR_NORM;
input int    _G_SlopeLookback    = 20;     // bars for slope measurement
input double _G_SlopeThr_ATR      = 0.06;  // SLOPE_ATR_NORM threshold
input double _G_SlopeThr_Points   = 400;   // SLOPE_POINTS threshold (points over lookback)
input double _G_SlopeThr_Degree   = 20.0;  // SLOPE_DEGREE threshold (deg)
input double _G_DegPipPerBar       = 1.0;  // SLOPE_DEGREE only: pips-per-bar scale factor
input int    _G_ADX_Period        = 14;
input double _G_ADX_TrendMin       = 20.0; // ADX <= this = no-trend / range zone
input double _G_ADX_StrongDI       = 35.0; // sys4 "strong" DI threshold

input string _g03_ = "== [03] SIGNAL LEVELS ====================";
input double _G_Stoch_OS          = 30.0;  // stoch oversold (trend sys2)
input double _G_Stoch_OB          = 70.0;
input double _G_StochBand_OS       = 20.0; // stoch oversold (range sys5)
input double _G_StochBand_OB       = 80.0;
input double _G_RSI_OS             = 30.0;
input double _G_RSI_OB             = 70.0;
input double _G_RSI_ExitLo         = 20.0; // sys3 exit RSI 80/20
input double _G_RSI_ExitHi         = 80.0;
input int    _G_DivLookback        = 12;   // divergence confirm window (sys3,6)

input string _g04_ = "== [04] WEEKEND CUT ======================";
input bool   _G_WeekendCut        = true;  // Fri close + pause until Mon+2h
input int    _G_CutHourServer      = 12;   // server hour of Fri cut (adjust to =19:30 Thai)
input int    _G_CutMinServer       = 30;
input bool   _G_CutProfitOnly      = false;// true=close only profitable legs at cut
input int    _G_MonResumeHour      = 2;    // resume N hours after Monday market open (server 0h proxy)

input string _g05_ = "== [05] SYSTEM ENABLES ===================";
input bool   _S1_Enable = true;   // trend  EMA14 cross      H1
input bool   _S2_Enable = true;   // trend  Stoch 30/70      M5
input bool   _S3_Enable = true;   // trend  RSI+div          M5
input bool   _S4_Enable = true;   // trend  DI flip / ADX    (regime TF)
input bool   _S5_Enable = true;   // range  Stoch 20/80      M5
input bool   _S6_Enable = true;   // range  RSI+div          M15

input string _g06_ = "== [06] PER-BASKET EQUITY STOP (% port) ==";
input double _S1_EqStopPct = 20.0;
input double _S2_EqStopPct = 10.0;
input double _S3_EqStopPct = 10.0;
input double _S4_EqStopPct = 10.0;
input double _S5_EqStopPct = 5.0;
input double _S6_EqStopPct = 5.0;
input double _G23_GroupTPpct = 1.0;   // sys2+3 combined float profit % -> close both
input double _G56_NetTPpct   = 1.0;   // sys5/6 per-system net +% -> close
input double _G56_NetSLpct   = 2.0;   // sys5/6 per-system net -% -> close

input string _g07_ = "== [07] SYSTEM ============================";
input bool   _06_AllowLive = false;   // false = tester only unless toggled (safety)
input ulong  _06_Slippage  = 30;

//====================================================================
//  PER-SYSTEM CONFIG
//====================================================================
struct SysConfig
{
   long            magic;
   bool            enabled;
   ENUM_ENTRY_TYPE entry;
   ENUM_TIMEFRAMES entryTF;
   ENUM_TIMEFRAMES regimeTF;   // TF for EMA224 slope filter
   bool            needTrend;  // true = trade only in trend, false = only sideways
   bool            slopeGate;  // apply EMA224-slope regime? (sys4 = false, ADX-only)
   bool            useDiv;     // divergence confirm (sys3,6)
   bool            breakoutExit;
   bool            trade24h;    // true = ignore weekend cut (sys1)
   double          eqStopPct;
   // indicator handles
   int hEMA224, hEMA14, hStoch, hRSI, hADX, hATR;
   // runtime basket state (per direction: 0=buy,1=sell)
   double peakProfit[2];       // for trailing lock
   datetime lastBar;           // entryTF bar-open gate
};

SysConfig g_sys[6];
double    g_startBalance = 0.0;
datetime  g_pauseUntil   = 0;      // weekend pause end (server time)
bool      g_globalHalt   = false;  // set when global cap breached; clears when flat
bool      g_quiet        = false;  // true during optimize -> suppress runtime logs (D3)

//====================================================================
//  MARKET / MATH HELPERS
//====================================================================
double PipSize(const string sym)
{
   int    digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   double point  = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(digits == 5 || digits == 3) return point * 10.0;
   return point;
}

double MoneyPerPointPerLot(const string sym)
{
   double tv = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   double ts = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(ts <= 0.0) return tv;                 // fallback
   return tv * (pt / ts);                    // $ per 1 point per 1.0 lot
}

double NormalizeLot(const string sym, double lot)
{
   double minv = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double maxv = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   if(step <= 0.0) step = 0.01;
   if(_G_MaxLotClamp > 0.0 && lot > _G_MaxLotClamp) lot = _G_MaxLotClamp;
   if(lot > maxv) lot = maxv;
   if(lot < minv) lot = minv;
   lot = MathFloor(lot / step + 1e-7) * step;
   return NormalizeDouble(lot, 2);
}

// read one indicator buffer value at shift; returns false on failure
bool Buf(const int handle, const int buffer, const int shift, double &out)
{
   double b[];
   if(CopyBuffer(handle, buffer, shift, 1, b) < 1) return false;
   out = b[0];
   return true;
}

//====================================================================
//  GRID / BASKET ENGINE  (all scoped by magic)
//====================================================================
bool PosIsMine(const int index, const long magic)
{
   ulong tk = PositionGetTicket(index);
   if(tk == 0) return false;
   if(PositionGetString(POSITION_SYMBOL) != _Symbol) return false;
   if((long)PositionGetInteger(POSITION_MAGIC) != magic) return false;
   return true;
}

// dir: 0=any 1=buy 2=sell
int CountDir(const long magic, const int dir)
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PosIsMine(i, magic)) continue;
      long type = PositionGetInteger(POSITION_TYPE);
      if(dir == 0) n++;
      else if(dir == 1 && type == POSITION_TYPE_BUY)  n++;
      else if(dir == 2 && type == POSITION_TYPE_SELL) n++;
   }
   return n;
}

double BasketProfitDir(const long magic, const int dir)  // + swap, dir 0=any
{
   double p = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PosIsMine(i, magic)) continue;
      long type = PositionGetInteger(POSITION_TYPE);
      if(dir == 1 && type != POSITION_TYPE_BUY)  continue;
      if(dir == 2 && type != POSITION_TYPE_SELL) continue;
      p += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return p;
}

double TotalLotsAll()
{
   double lots = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      lots += PositionGetDouble(POSITION_VOLUME);
   }
   return lots;
}

double GlobalFloating()   // floating P/L across ALL our magics on this symbol
{
   double p = 0.0;
   for(int s = 0; s < 6; s++)
      p += BasketProfitDir(g_sys[s].magic, 0);
   return p;
}

// most-recent fill price in a direction (grid spacing reference)
double LastFillPrice(const long magic, const int dir)
{
   datetime best = 0; double price = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PosIsMine(i, magic)) continue;
      long type = PositionGetInteger(POSITION_TYPE);
      if(dir == 1 && type != POSITION_TYPE_BUY)  continue;
      if(dir == 2 && type != POSITION_TYPE_SELL) continue;
      datetime t = (datetime)PositionGetInteger(POSITION_TIME);
      if(t >= best) { best = t; price = PositionGetDouble(POSITION_PRICE_OPEN); }
   }
   return price;
}

// spacing / SL distance in POINTS (adaptive or fixed)
double SpacingPoints(const int hATR)
{
   if(_G_SpacingMode == GRID_POINTS) return (double)_G_SpacingPoints;
   double atr = 0.0;
   if(!Buf(hATR, 0, 1, atr) || atr <= 0.0) return (double)_G_SpacingPoints;
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return (_G_SpacingATRmult * atr) / pt;
}

double SLDistancePoints(const int hATR)
{
   if(_G_SpacingMode == GRID_POINTS) return (double)_G_SL_Points;
   double atr = 0.0;
   if(!Buf(hATR, 0, 1, atr) || atr <= 0.0) return (double)_G_SL_Points;
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return (_G_SL_ATRmult * atr) / pt;
}

// first-leg lot from worst-case: full stack, each leg hits its own SL.
// total loss = base * geomSum * slPts * moneyPerPoint <= risk% * balance
double FirstLotFromRisk(const int hATR)
{
   double bal   = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk  = (_G_RiskPerBasketPct / 100.0) * bal;
   double slPts = SLDistancePoints(hATR);
   double mpp   = MoneyPerPointPerLot(_Symbol);
   int    N     = MathMax(1, _G_MaxLevels);
   double m     = _G_LotMult;
   double geom  = (MathAbs(m - 1.0) < 1e-9) ? (double)N : (MathPow(m, N) - 1.0) / (m - 1.0);
   double denom = geom * slPts * mpp;
   if(denom <= 0.0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   return risk / denom;
}

double LegLot(const double firstLot, const int level)
{
   return firstLot * MathPow(_G_LotMult, (double)level);
}

// open one leg with catastrophic SL. dir 1=buy 2=sell
bool OpenLeg(const long magic, const int dir, const double lot, const int hATR, const string tag)
{
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return false;
   double slPts  = SLDistancePoints(hATR);
   double pt     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double entry  = (dir == 1 ? t.ask : t.bid);
   double sl     = (dir == 1 ? entry - slPts * pt : entry + slPts * pt);
   double nlot   = NormalizeLot(_Symbol, lot);
   if(nlot <= 0.0) return false;

   // hard ceiling on combined lots
   if(TotalLotsAll() + nlot > _G_MaxTotalLot)
   {
      if(!g_quiet) PrintFormat("[HEX] MaxTotalLot ceiling hit (%.2f) - leg skipped", _G_MaxTotalLot);
      return false;
   }

   bool allow = _06_AllowLive || (bool)MQLInfoInteger(MQL_TESTER);
   if(!allow)
   {
      PrintFormat("[HEX-DRY] open magic=%I64d dir=%d lot=%.2f sl=%.5f %s", magic, dir, nlot, sl, tag);
      return true;
   }
   g_trade.SetExpertMagicNumber((ulong)magic);
   g_trade.SetDeviationInPoints(_06_Slippage);
   if(dir == 1) return g_trade.Buy (nlot, _Symbol, 0.0, sl, 0.0, tag);
   if(dir == 2) return g_trade.Sell(nlot, _Symbol, 0.0, sl, 0.0, tag);
   return false;
}

// close one direction's basket (or dir 0 = all of this magic)
void CloseBasket(const long magic, const int dir, const bool profitOnly = false)
{
   bool allow = _06_AllowLive || (bool)MQLInfoInteger(MQL_TESTER);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PosIsMine(i, magic)) continue;
      long type = PositionGetInteger(POSITION_TYPE);
      if(dir == 1 && type != POSITION_TYPE_BUY)  continue;
      if(dir == 2 && type != POSITION_TYPE_SELL) continue;
      if(profitOnly && (PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP)) <= 0.0) continue;
      ulong tk = PositionGetInteger(POSITION_TICKET);
      if(!allow) { PrintFormat("[HEX-DRY] close ticket %I64u", tk); continue; }
      g_trade.SetExpertMagicNumber((ulong)magic);
      g_trade.PositionClose(tk);
   }
}

//====================================================================
//  REGIME (EMA224 slope) + ADX
//====================================================================
// returns slope "strength" signed; sign = up/down. Caller compares |val| to thr.
bool SlopeValue(const int hEMA, const int hATR, double &signedStrength, double &thr)
{
   double e0 = 0.0, eN = 0.0;
   if(!Buf(hEMA, 0, 1, e0) || !Buf(hEMA, 0, 1 + _G_SlopeLookback, eN)) return false;
   double pt      = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double dPoints = (e0 - eN) / pt;                     // signed, over lookback

   if(_G_SlopeMode == SLOPE_ATR_NORM)
   {
      double atr = 0.0;
      if(!Buf(hATR, 0, 1, atr) || atr <= 0.0) return false;
      double perBarPoints = (dPoints / (double)_G_SlopeLookback);
      signedStrength = perBarPoints * pt / atr;          // (dEMA/bar)/ATR
      thr = _G_SlopeThr_ATR;
   }
   else if(_G_SlopeMode == SLOPE_POINTS)
   {
      signedStrength = dPoints;
      thr = _G_SlopeThr_Points;
   }
   else // SLOPE_DEGREE
   {
      double pip      = PipSize(_Symbol);
      double dPips    = (e0 - eN) / pip;
      double perBar   = dPips / (double)_G_SlopeLookback;
      double angle    = MathArctan(perBar / MathMax(1e-9, _G_DegPipPerBar)) * 57.29578;
      signedStrength  = angle;
      thr = _G_SlopeThr_Degree;
   }
   return true;
}

double ADXval(const int hADX, const int buffer)  // 0=ADX 1=+DI 2=-DI
{
   double v = 0.0;
   if(!Buf(hADX, buffer, 1, v)) return -1.0;
   return v;
}

// regime gate: does market state permit this system's flat entry? also
// returns allowed direction bias (0=none,1=up/buy,2=down/sell,3=either).
int RegimeBias(const SysConfig &c)
{
   // sys4: ADX-only regime (no EMA224 slope). DI-flip + ADX-rising in
   // EntrySignal is the gate; direction comes from the DI cross itself.
   if(!c.slopeGate) return 3;

   double strength = 0.0, thr = 0.0;
   if(!SlopeValue(c.hEMA224, c.hATR, strength, thr)) return 0;
   bool isTrend = (MathAbs(strength) >= thr);
   double adx = ADXval(c.hADX, 0);

   if(c.needTrend)
   {
      if(!isTrend) return 0;
      return (strength > 0 ? 1 : 2);         // trade with the slope
   }
   else // sideways systems
   {
      if(isTrend) return 0;
      if(adx > _G_ADX_TrendMin) return 0;    // ADX must be in range zone
      return 3;                               // range: both directions ok
   }
}

//====================================================================
//  ENTRY SIGNALS   (returns 1=buy 2=sell 0=none)
//====================================================================
bool CrossedUp(const double prevA, const double prevB, const double a, const double b)
{ return (prevA <= prevB && a > b); }
bool CrossedDown(const double prevA, const double prevB, const double a, const double b)
{ return (prevA >= prevB && a < b); }

// bullish div: price lower-low over window but RSI higher-low. bearish opposite.
int Divergence(const SysConfig &c)
{
   int    w   = _G_DivLookback;
   double lowNow  = iLow (_Symbol, c.entryTF, 1);
   double lowPast = iLow (_Symbol, c.entryTF, 1 + w);
   double highNow = iHigh(_Symbol, c.entryTF, 1);
   double highPast= iHigh(_Symbol, c.entryTF, 1 + w);
   double rNow = 0.0, rPast = 0.0;
   if(!Buf(c.hRSI, 0, 1, rNow) || !Buf(c.hRSI, 0, 1 + w, rPast)) return 0;
   if(lowNow  < lowPast  && rNow > rPast) return 1;   // bullish divergence
   if(highNow > highPast && rNow < rPast) return 2;   // bearish divergence
   return 0;
}

int EntrySignal(const SysConfig &c)
{
   switch(c.entry)
   {
      case ENT_EMA14_CROSS:
      {
         double e0=0,e1=0;
         if(!Buf(c.hEMA14,0,1,e0) || !Buf(c.hEMA14,0,2,e1)) return 0;
         double c1 = iClose(_Symbol,c.entryTF,1);
         double c2 = iClose(_Symbol,c.entryTF,2);
         if(CrossedUp(c2,e1,c1,e0))   return 1;
         if(CrossedDown(c2,e1,c1,e0)) return 2;
         return 0;
      }
      case ENT_STOCH_CROSS:   // touch OS/OB (trend)
      {
         double k1=0,k2=0;
         if(!Buf(c.hStoch,0,1,k1) || !Buf(c.hStoch,0,2,k2)) return 0;
         if(k2 <= _G_Stoch_OS && k1 > _G_Stoch_OS) return 1;  // leaving oversold
         if(k2 >= _G_Stoch_OB && k1 < _G_Stoch_OB) return 2;
         return 0;
      }
      case ENT_RSI_REV:       // RSI 30/70 + divergence (trend)
      {
         double r1=0;
         if(!Buf(c.hRSI,0,1,r1)) return 0;
         int div = c.useDiv ? Divergence(c) : 3;
         if(r1 <= _G_RSI_OS && (div==1||div==3)) return 1;
         if(r1 >= _G_RSI_OB && (div==2||div==3)) return 2;
         return 0;
      }
      case ENT_DI_FLIP:       // DI flip while ADX rising
      {
         double adx0=ADXval(c.hADX,0), adx1=0.0;
         if(!Buf(c.hADX,0,2,adx1)) return 0;
         double pdi=ADXval(c.hADX,1), mdi=ADXval(c.hADX,2);
         double pdi2=0,mdi2=0;
         if(!Buf(c.hADX,1,2,pdi2) || !Buf(c.hADX,2,2,mdi2)) return 0;
         if(adx0 <= _G_ADX_TrendMin) return 0;       // no-trade zone
         bool rising = (adx0 > adx1);
         if(!rising) return 0;
         bool strong = (pdi >= _G_ADX_StrongDI || mdi >= _G_ADX_StrongDI);
         if(!strong) return 0;
         if(CrossedUp(pdi2,mdi2,pdi,mdi))   return 1;
         if(CrossedDown(pdi2,mdi2,pdi,mdi)) return 2;
         return 0;
      }
      case ENT_STOCH_BAND:    // stoch 20/80 (range)
      {
         double k1=0,k2=0;
         if(!Buf(c.hStoch,0,1,k1) || !Buf(c.hStoch,0,2,k2)) return 0;
         if(k2 <= _G_StochBand_OS && k1 > _G_StochBand_OS) return 1;
         if(k2 >= _G_StochBand_OB && k1 < _G_StochBand_OB) return 2;
         return 0;
      }
      case ENT_RSI_BAND:      // RSI 30/70 M15 + divergence (range)
      {
         double r1=0;
         if(!Buf(c.hRSI,0,1,r1)) return 0;
         int div = c.useDiv ? Divergence(c) : 3;
         if(r1 <= _G_RSI_OS && (div==1||div==3)) return 1;
         if(r1 >= _G_RSI_OB && (div==2||div==3)) return 2;
         return 0;
      }
   }
   return 0;
}

// exit signal for an open basket direction (true = close this direction)
bool ExitSignal(const SysConfig &c, const int dir)
{
   switch(c.entry)
   {
      case ENT_EMA14_CROSS:
      {
         double e0=0; if(!Buf(c.hEMA14,0,1,e0)) return false;
         double c1 = iClose(_Symbol,c.entryTF,1);
         if(dir==1 && c1 < e0) return true;      // price crossed back below
         if(dir==2 && c1 > e0) return true;
         return false;
      }
      case ENT_STOCH_CROSS:
      case ENT_STOCH_BAND:
      {
         double k1=0; if(!Buf(c.hStoch,0,1,k1)) return false;
         double ob = (c.entry==ENT_STOCH_BAND ? _G_StochBand_OB : _G_Stoch_OB);
         double os = (c.entry==ENT_STOCH_BAND ? _G_StochBand_OS : _G_Stoch_OS);
         if(dir==1 && k1 >= ob) return true;     // opposite band
         if(dir==2 && k1 <= os) return true;
         return false;
      }
      case ENT_RSI_REV:       // exit at RSI 80/20
      {
         double r1=0; if(!Buf(c.hRSI,0,1,r1)) return false;
         if(dir==1 && r1 >= _G_RSI_ExitHi) return true;
         if(dir==2 && r1 <= _G_RSI_ExitLo) return true;
         return false;
      }
      case ENT_RSI_BAND:
      {
         double r1=0; if(!Buf(c.hRSI,0,1,r1)) return false;
         if(dir==1 && r1 >= _G_RSI_OB) return true;
         if(dir==2 && r1 <= _G_RSI_OS) return true;
         return false;
      }
      case ENT_DI_FLIP:       // DI cross back OR ADX falls into zone
      {
         double adx0=ADXval(c.hADX,0);
         if(adx0 <= _G_ADX_TrendMin) return true;
         double pdi=ADXval(c.hADX,1), mdi=ADXval(c.hADX,2);
         if(dir==1 && mdi > pdi) return true;
         if(dir==2 && pdi > mdi) return true;
         return false;
      }
   }
   return false;
}

// breakout exit (sys5/6): EMA224 H1 slope breaks into a trend AGAINST basket
bool BreakoutExit(const SysConfig &c, const int dir)
{
   if(!c.breakoutExit) return false;
   double strength=0.0, thr=0.0;
   if(!SlopeValue(c.hEMA224, c.hATR, strength, thr)) return false;
   if(MathAbs(strength) < thr) return false;          // still ranging
   if(dir==1 && strength < 0) return true;            // long basket, trend broke down
   if(dir==2 && strength > 0) return true;            // short basket, trend broke up
   return false;
}

//====================================================================
//  BASKET MANAGEMENT (per direction)
//====================================================================
// returns true if the direction's basket was fully closed this pass
bool ManageDirection(SysConfig &c, const int dir, const double balance)
{
   int di = (dir == 1 ? 0 : 1);
   int n  = CountDir(c.magic, dir);
   if(n == 0) { c.peakProfit[di] = 0.0; return false; }

   double profit    = BasketProfitDir(c.magic, dir);
   double profitPct = 100.0 * profit / MathMax(1.0, balance);

   // (6) per-basket equity stop (hard)
   if(profitPct <= -c.eqStopPct)
   { CloseBasket(c.magic, dir); c.peakProfit[di]=0.0;
     if(!g_quiet) PrintFormat("[HEX] sys%I64d dir%d EQUITY-STOP %.2f%%", c.magic, dir, profitPct); return true; }

   // (2) breakout exit (sys5/6)
   if(BreakoutExit(c, dir))
   { CloseBasket(c.magic, dir); c.peakProfit[di]=0.0;
     if(!g_quiet) PrintFormat("[HEX] sys%I64d dir%d BREAKOUT-EXIT", c.magic, dir); return true; }

   // (3) trailing profit lock
   if(profitPct > c.peakProfit[di]) c.peakProfit[di] = profitPct;
   if(c.peakProfit[di] >= _G_TrailArmPct)
   {
      double peak     = c.peakProfit[di];
      double giveback = peak * (_G_TrailGivebackPct / 100.0);
      if(profitPct <= peak - giveback)
      { CloseBasket(c.magic, dir); c.peakProfit[di]=0.0;
        if(!g_quiet) PrintFormat("[HEX] sys%I64d dir%d TRAIL-LOCK peak=%.2f now=%.2f", c.magic, dir, peak, profitPct); return true; }
   }

   // (1) signal exit
   if(ExitSignal(c, dir))
   { CloseBasket(c.magic, dir); c.peakProfit[di]=0.0;
     if(!g_quiet) PrintFormat("[HEX] sys%I64d dir%d SIGNAL-EXIT", c.magic, dir); return true; }

   // grid add: price moved against last fill by >= spacing, and level cap not hit
   if(n < _G_MaxLevels)
   {
      double last = LastFillPrice(c.magic, dir);
      if(last > 0.0)
      {
         MqlTick t; if(!SymbolInfoTick(_Symbol, t)) return false;
         double pt      = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         double spacing = SpacingPoints(c.hATR) * pt;
         double px      = (dir == 1 ? t.bid : t.ask);
         bool   against = (dir == 1 ? (px <= last - spacing) : (px >= last + spacing));
         if(against)
         {
            double firstLot = FirstLotFromRisk(c.hATR);
            double lot      = LegLot(firstLot, n);            // level = current count
            OpenLeg(c.magic, dir, lot, c.hATR, "HEX s"+IntegerToString((int)(c.magic%100))+" L"+IntegerToString(n));
         }
      }
   }
   return false;
}

//====================================================================
//  WEEKEND CUT
//====================================================================
bool WeekendPaused()
{
   if(!_G_WeekendCut) return false;
   datetime now = TimeCurrent();
   if(g_pauseUntil > 0 && now < g_pauseUntil) return true;
   MqlDateTime dt; TimeToStruct(now, dt);
   // Friday cut: close baskets (non-24h systems) and set pause till Mon+resume
   if(dt.day_of_week == 5 &&
      (dt.hour > _G_CutHourServer || (dt.hour == _G_CutHourServer && dt.min >= _G_CutMinServer)))
   {
      // pause until Monday + resume hours (approx: +2 days + resume offset from Fri cut)
      g_pauseUntil = now + (datetime)((2 * 24 + (_G_MonResumeHour + (24 - _G_CutHourServer))) * 3600);
      return true;
   }
   return false;
}

//====================================================================
//  LIFECYCLE
//====================================================================
void ConfigureSystems()
{
   // sys1 - trend, EMA14 cross, H1, 24h
   g_sys[0].magic=20260707; g_sys[0].enabled=_S1_Enable; g_sys[0].entry=ENT_EMA14_CROSS;
   g_sys[0].entryTF=PERIOD_H1; g_sys[0].regimeTF=PERIOD_H1; g_sys[0].needTrend=true;
   g_sys[0].useDiv=false; g_sys[0].breakoutExit=false; g_sys[0].trade24h=true; g_sys[0].eqStopPct=_S1_EqStopPct;
   // sys2 - trend, Stoch M5, regime D1
   g_sys[1].magic=20260708; g_sys[1].enabled=_S2_Enable; g_sys[1].entry=ENT_STOCH_CROSS;
   g_sys[1].entryTF=PERIOD_M5; g_sys[1].regimeTF=PERIOD_D1; g_sys[1].needTrend=true;
   g_sys[1].useDiv=false; g_sys[1].breakoutExit=false; g_sys[1].trade24h=false; g_sys[1].eqStopPct=_S2_EqStopPct;
   // sys3 - trend, RSI M5 + div, regime H4
   g_sys[2].magic=20260710; g_sys[2].enabled=_S3_Enable; g_sys[2].entry=ENT_RSI_REV;
   g_sys[2].entryTF=PERIOD_M5; g_sys[2].regimeTF=PERIOD_H4; g_sys[2].needTrend=true;
   g_sys[2].useDiv=true; g_sys[2].breakoutExit=false; g_sys[2].trade24h=false; g_sys[2].eqStopPct=_S3_EqStopPct;
   // sys4 - trend, DI flip, regime H1
   g_sys[3].magic=20260711; g_sys[3].enabled=_S4_Enable; g_sys[3].entry=ENT_DI_FLIP;
   g_sys[3].entryTF=PERIOD_H1; g_sys[3].regimeTF=PERIOD_H1; g_sys[3].needTrend=true;
   g_sys[3].useDiv=false; g_sys[3].breakoutExit=false; g_sys[3].trade24h=false; g_sys[3].eqStopPct=_S4_EqStopPct;
   // sys5 - range, Stoch M5 20/80, regime H1
   g_sys[4].magic=20260712; g_sys[4].enabled=_S5_Enable; g_sys[4].entry=ENT_STOCH_BAND;
   g_sys[4].entryTF=PERIOD_M5; g_sys[4].regimeTF=PERIOD_H1; g_sys[4].needTrend=false;
   g_sys[4].useDiv=false; g_sys[4].breakoutExit=true; g_sys[4].trade24h=false; g_sys[4].eqStopPct=_S5_EqStopPct;
   // sys6 - range, RSI M15 + div, regime H1
   g_sys[5].magic=20260713; g_sys[5].enabled=_S6_Enable; g_sys[5].entry=ENT_RSI_BAND;
   g_sys[5].entryTF=PERIOD_M15; g_sys[5].regimeTF=PERIOD_H1; g_sys[5].needTrend=false;
   g_sys[5].useDiv=true; g_sys[5].breakoutExit=true; g_sys[5].trade24h=false; g_sys[5].eqStopPct=_S6_EqStopPct;

   // EMA224-slope regime applies to all EXCEPT sys4 (spec: sys4 = ADX-state only,
   // its DI-flip + ADX-rising logic in EntrySignal is the regime gate)
   for(int s=0;s<6;s++) g_sys[s].slopeGate = true;
   g_sys[3].slopeGate = false;

   for(int s=0;s<6;s++){ g_sys[s].peakProfit[0]=0; g_sys[s].peakProfit[1]=0; g_sys[s].lastBar=0;
      g_sys[s].hEMA224=g_sys[s].hEMA14=g_sys[s].hStoch=g_sys[s].hRSI=g_sys[s].hADX=g_sys[s].hATR=INVALID_HANDLE; }
}

bool InitHandles()
{
   for(int s=0;s<6;s++)
   {
      g_sys[s].hATR    = iATR(_Symbol, _G_ATR_TF, _G_ATR_Period);
      g_sys[s].hEMA224 = iMA(_Symbol, g_sys[s].regimeTF, _G_EMA224_Period, 0, MODE_EMA, PRICE_CLOSE);
      g_sys[s].hADX    = iADX(_Symbol, g_sys[s].regimeTF, _G_ADX_Period);
      if(g_sys[s].entry==ENT_EMA14_CROSS)
         g_sys[s].hEMA14 = iMA(_Symbol, g_sys[s].entryTF, 14, 0, MODE_EMA, PRICE_CLOSE);
      if(g_sys[s].entry==ENT_STOCH_CROSS || g_sys[s].entry==ENT_STOCH_BAND)
         g_sys[s].hStoch = iStochastic(_Symbol, g_sys[s].entryTF, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
      if(g_sys[s].entry==ENT_RSI_REV || g_sys[s].entry==ENT_RSI_BAND)
         g_sys[s].hRSI = iRSI(_Symbol, g_sys[s].entryTF, 14, PRICE_CLOSE);
      // sys4 uses regime hADX for its DI flip (entryTF == regimeTF here)

      if(g_sys[s].hATR==INVALID_HANDLE || g_sys[s].hEMA224==INVALID_HANDLE || g_sys[s].hADX==INVALID_HANDLE)
         return false;
   }
   return true;
}

int OnInit()
{
   // HARD guard: 6 independent baskets on one symbol REQUIRE a hedging account
   if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
   {
      Print("[HEX][FATAL] HexaGrid requires a HEDGING account (netting would merge all 6 baskets). INIT_FAILED.");
      return INIT_FAILED;
   }
   ConfigureSystems();
   if(!InitHandles())
   { Print("[HEX][FATAL] indicator handle init failed."); return INIT_FAILED; }

   g_startBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_globalHalt   = false;
   g_pauseUntil   = 0;
   g_quiet        = (bool)MQLInfoInteger(MQL_OPTIMIZATION);
   g_trade.SetAsyncMode(false);
   g_trade.LogLevel(LOG_LEVEL_ERRORS);
   PrintFormat("[HEX][INIT] ok | live=%s spacing=%s risk/basket=%.1f%% globalCap=%.1f%% maxLevels=%d mult=%.2f",
               (_06_AllowLive?"Y":"N"), (_G_SpacingMode==GRID_ATR?"ATR":"PTS"),
               _G_RiskPerBasketPct, _G_GlobalCapPct, _G_MaxLevels, _G_LotMult);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   for(int s=0;s<6;s++)
   {
      if(g_sys[s].hATR   !=INVALID_HANDLE) IndicatorRelease(g_sys[s].hATR);
      if(g_sys[s].hEMA224!=INVALID_HANDLE) IndicatorRelease(g_sys[s].hEMA224);
      if(g_sys[s].hEMA14 !=INVALID_HANDLE) IndicatorRelease(g_sys[s].hEMA14);
      if(g_sys[s].hStoch !=INVALID_HANDLE) IndicatorRelease(g_sys[s].hStoch);
      if(g_sys[s].hRSI   !=INVALID_HANDLE) IndicatorRelease(g_sys[s].hRSI);
      if(g_sys[s].hADX   !=INVALID_HANDLE) IndicatorRelease(g_sys[s].hADX);
   }
}

void OnTick()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   // ---- (0) GLOBAL EQUITY CAP (fastest, checked every tick) ----
   double gFloat = GlobalFloating();
   double gPct   = 100.0 * gFloat / MathMax(1.0, balance);
   if(g_globalHalt)
   {
      if(CountAllSystems() == 0) g_globalHalt = false;   // flat again -> release
      else return;
   }
   if(gPct <= -_G_GlobalCapPct)
   {
      if(!g_quiet) PrintFormat("[HEX][GLOBAL-CAP] float %.2f%% <= -%.2f%% -> flatten all + halt", gPct, _G_GlobalCapPct);
      for(int s=0;s<6;s++){ CloseBasket(g_sys[s].magic,0); g_sys[s].peakProfit[0]=0; g_sys[s].peakProfit[1]=0; }
      g_globalHalt = true;
      return;
   }

   // ---- weekend cut (skips 24h systems inside the per-system loop) ----
   bool weekendPause = WeekendPaused();

   // ---- (4/5) cross-system profit exits, computed once ----
   // Group TP sys2+3
   double grp23 = BasketProfitDir(g_sys[1].magic,0) + BasketProfitDir(g_sys[2].magic,0);
   if((CountDir(g_sys[1].magic,0)+CountDir(g_sys[2].magic,0))>0 &&
      100.0*grp23/MathMax(1.0,balance) >= _G23_GroupTPpct)
   {
      CloseBasket(g_sys[1].magic,0); CloseBasket(g_sys[2].magic,0);
      g_sys[1].peakProfit[0]=g_sys[1].peakProfit[1]=0;
      g_sys[2].peakProfit[0]=g_sys[2].peakProfit[1]=0;
      if(!g_quiet) PrintFormat("[HEX] GROUP-TP sys2+3 %.2f%%", 100.0*grp23/balance);
   }

   // ---- per-system pipeline ----
   for(int s=0;s<6;s++)
   {
      SysConfig c = g_sys[s];
      if(!c.enabled) continue;

      // (5) Net TP/SL for range systems (sys5,6) - whole system net Buy+Sell
      if(c.entry==ENT_STOCH_BAND || c.entry==ENT_RSI_BAND)
      {
         int cnt = CountDir(c.magic,0);
         if(cnt>0)
         {
            double netPct = 100.0 * BasketProfitDir(c.magic,0) / MathMax(1.0,balance);
            if(netPct >= _G56_NetTPpct || netPct <= -_G56_NetSLpct)
            {
               CloseBasket(c.magic,0);
               g_sys[s].peakProfit[0]=g_sys[s].peakProfit[1]=0;
               if(!g_quiet) PrintFormat("[HEX] sys%I64d NET %s %.2f%%", c.magic, (netPct>=0?"TP":"SL"), netPct);
               continue;
            }
         }
      }

      // manage each direction basket (exits + grid adds)
      ManageDirection(g_sys[s], 1, balance);
      ManageDirection(g_sys[s], 2, balance);
      // refresh local copy of peak state (ManageDirection wrote to g_sys[s])
      c = g_sys[s];

      // weekend cut for non-24h systems: close + no new entries
      if(weekendPause && !c.trade24h)
      {
         if(CountDir(c.magic,0)>0) CloseBasket(c.magic,0,_G_CutProfitOnly);
         continue;
      }

      // ---- new first-entry (bar-open gated on entryTF) ----
      datetime bt = iTime(_Symbol, c.entryTF, 0);
      if(bt == g_sys[s].lastBar) continue;      // one entry decision per bar
      // don't advance lastBar until we actually evaluate a flat basket, so a
      // mid-bar close still lets the next bar re-enter
      if(CountDir(c.magic,0) > 0) continue;     // basket already open: no new first leg
      g_sys[s].lastBar = bt;

      if(g_globalHalt) continue;

      int bias = RegimeBias(c);
      if(bias == 0) continue;

      int sig = EntrySignal(c);
      if(sig == 0) continue;
      if(bias != 3 && sig != bias) continue;    // trend systems: signal must match slope

      double firstLot = FirstLotFromRisk(c.hATR);
      OpenLeg(c.magic, sig, firstLot, c.hATR, "HEX s"+IntegerToString((int)(c.magic%100))+" L0");
   }
}

int CountAllSystems()
{
   int n=0;
   for(int s=0;s<6;s++) n += CountDir(g_sys[s].magic,0);
   return n;
}

double OnTester()
{
   double trades = TesterStatistics(STAT_TRADES);
   if(trades < 30) return -1.0;
   double sharpe = TesterStatistics(STAT_SHARPE_RATIO);
   return (sharpe > 0 ? sharpe : -1.0);
}
//+------------------------------------------------------------------+
