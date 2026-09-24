//+------------------------------------------------------------------+
//| Entry_AdaptiveDonchianFlip.mqh - FB-A01 research V0.             |
//| Dedicated full-pipeline owner; generic chassis lifecycle is inert.|
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_ENTRY_ADAPTIVE_DONCHIAN_FLIP_MQH
#define BOSS_LAB_ENTRY_ADAPTIVE_DONCHIAN_FLIP_MQH

enum ENUM_ADF_REGIME
{
   ADF_REGIME_INVALID = -1,
   ADF_REGIME_LOW = 0,
   ADF_REGIME_NORMAL = 1,
   ADF_REGIME_HIGH = 2,
   ADF_REGIME_EXTREME = 3
};

enum ENUM_ADF_TREND
{
   ADF_TREND_DOWN = -1,
   ADF_TREND_UP = 1
};

enum ENUM_ADF_STATE
{
   ADF_STATE_FLAT = 0,
   ADF_STATE_LONG = 1,
   ADF_STATE_SHORT = 2,
   ADF_STATE_CLOSING_FOR_REVERSE = 3,
   ADF_STATE_HALTED = 4
};

enum ENUM_ADF_ACTION
{
   ADF_ACTION_NONE = 0,
   ADF_ACTION_CLOSE = 1,
   ADF_ACTION_OPEN = 2,
   ADF_ACTION_HALT = 3
};

struct ADF_Fsm
{
   int state;
   int pending_direction;
   long pending_bar;
   bool reverse_attempted;
   long last_open_bar;
};

void ADF_FsmReset(ADF_Fsm &fsm)
{
   fsm.state = ADF_STATE_FLAT;
   fsm.pending_direction = 0;
   fsm.pending_bar = 0;
   fsm.reverse_attempted = false;
   fsm.last_open_bar = 0;
}

bool ADF_Owns(const string symbol,const long magic,
              const string chart_symbol,const long strategy_magic)
{
   return symbol == chart_symbol && magic == strategy_magic;
}

bool ADF_Donchian(const double &highs[],const double &lows[],const int count,
                  double &upper,double &lower)
{
   upper = 0.0;
   lower = 0.0;
   if(count <= 0 || ArraySize(highs) < count || ArraySize(lows) < count)
      return false;
   upper = -1.0e100;
   lower = 1.0e100;
   for(int i=0;i<count;i++)
   {
      if(!MathIsValidNumber(highs[i]) || !MathIsValidNumber(lows[i]) ||
         highs[i] < lows[i])
         return false;
      if(highs[i] > upper) upper = highs[i];
      if(lows[i] < lower) lower = lows[i];
   }
   return MathIsValidNumber(upper) && MathIsValidNumber(lower) && upper >= lower;
}

int ADF_Breakout(const double decision_close,const double upper,
                 const double lower,const double buffer,const int trend)
{
   if(!MathIsValidNumber(decision_close) || !MathIsValidNumber(upper) ||
      !MathIsValidNumber(lower) || !MathIsValidNumber(buffer) || buffer < 0.0)
      return 0;
   if(trend == ADF_TREND_UP && decision_close > upper + buffer) return 1;
   if(trend == ADF_TREND_DOWN && decision_close < lower - buffer) return 2;
   return 0;
}

bool ADF_Percentile(const double current,const double &history[],
                    const int lookback,double &pct)
{
   pct = 0.0;
   if(lookback <= 0 || ArraySize(history) < lookback ||
      !MathIsValidNumber(current) || current <= 0.0)
      return false;
   int at_or_below = 0;
   for(int i=0;i<lookback;i++)
   {
      double value = history[i];
      if(!MathIsValidNumber(value) || value <= 0.0) return false;
      if(value <= current) at_or_below++;
   }
   pct = 100.0 * (double)at_or_below / (double)lookback;
   return true;
}

int ADF_Regime(const double pct,const double low,
               const double high,const double extreme)
{
   if(!MathIsValidNumber(pct) || !MathIsValidNumber(low) ||
      !MathIsValidNumber(high) || !MathIsValidNumber(extreme) ||
      !(0.0 < low && low < high && high < extreme && extreme <= 100.0))
      return ADF_REGIME_INVALID;
   if(pct < low) return ADF_REGIME_LOW;
   if(pct < high) return ADF_REGIME_NORMAL;
   if(pct < extreme) return ADF_REGIME_HIGH;
   return ADF_REGIME_EXTREME;
}

bool ADF_SuperTrend(const double &highs[],const double &lows[],
                    const double &closes[],const double &atrs[],
                    const int count,const double mult,
                    int &trend,double &final_upper,double &final_lower)
{
   trend = 0;
   final_upper = 0.0;
   final_lower = 0.0;
   if(count <= 0 || mult <= 0.0 ||
      ArraySize(highs) < count || ArraySize(lows) < count ||
      ArraySize(closes) < count || ArraySize(atrs) < count)
      return false;

   for(int i=0;i<count;i++)
   {
      if(!MathIsValidNumber(highs[i]) || !MathIsValidNumber(lows[i]) ||
         !MathIsValidNumber(closes[i]) || !MathIsValidNumber(atrs[i]) ||
         highs[i] < lows[i] || closes[i] > highs[i] || closes[i] < lows[i] ||
         atrs[i] <= 0.0)
         return false;

      double hl2 = (highs[i] + lows[i]) / 2.0;
      double basic_upper = hl2 + mult * atrs[i];
      double basic_lower = hl2 - mult * atrs[i];
      if(i == 0)
      {
         final_upper = basic_upper;
         final_lower = basic_lower;
         trend = (closes[i] >= hl2 ? ADF_TREND_UP : ADF_TREND_DOWN);
         continue;
      }

      double prev_upper = final_upper;
      double prev_lower = final_lower;
      double prev_close = closes[i-1];
      final_upper = (basic_upper < prev_upper || prev_close > prev_upper)
                    ? basic_upper : prev_upper;
      final_lower = (basic_lower > prev_lower || prev_close < prev_lower)
                    ? basic_lower : prev_lower;

      if(trend == ADF_TREND_DOWN && closes[i] > prev_upper)
         trend = ADF_TREND_UP;
      else if(trend == ADF_TREND_UP && closes[i] < prev_lower)
         trend = ADF_TREND_DOWN;
   }
   return trend == ADF_TREND_UP || trend == ADF_TREND_DOWN;
}

bool ADF_Median(const double &values[],const int count,double &median)
{
   median = 0.0;
   if(count <= 0 || ArraySize(values) < count) return false;
   double sorted[];
   ArrayResize(sorted,count);
   for(int i=0;i<count;i++)
   {
      if(!MathIsValidNumber(values[i]) || values[i] <= 0.0) return false;
      sorted[i] = values[i];
   }
   ArraySort(sorted);
   if((count % 2) == 1)
      median = sorted[count/2];
   else
      median = (sorted[count/2-1] + sorted[count/2]) / 2.0;
   return MathIsValidNumber(median) && median > 0.0;
}

bool ADF_SpreadPass(const double current,const double &samples[],
                    const int count,const int required,const double median_mult,
                    const double atr_cap,const double atr)
{
   if(required <= 0 || count < required || ArraySize(samples) < required ||
      !MathIsValidNumber(current) || current <= 0.0 ||
      !MathIsValidNumber(median_mult) || median_mult <= 0.0 ||
      !MathIsValidNumber(atr_cap) || atr_cap <= 0.0 ||
      !MathIsValidNumber(atr) || atr <= 0.0)
      return false;
   double median = 0.0;
   if(!ADF_Median(samples,required,median)) return false;
   return current <= median_mult * median && current <= atr_cap * atr;
}

double ADF_InitialSL(const int direction,const double entry,
                     const double atr,const double atr_mult)
{
   if((direction != 1 && direction != 2) || entry <= 0.0 ||
      atr <= 0.0 || atr_mult <= 0.0)
      return 0.0;
   return direction == 1 ? entry - atr_mult * atr
                         : entry + atr_mult * atr;
}

bool ADF_TrailTightens(const int direction,const double old_sl,
                       const double candidate)
{
   if(candidate <= 0.0 || !MathIsValidNumber(candidate)) return false;
   if(old_sl <= 0.0) return true;
   if(direction == 1) return candidate > old_sl;
   if(direction == 2) return candidate < old_sl;
   return false;
}

int ADF_FsmStep(ADF_Fsm &fsm,const long decision_bar,
                const bool new_decision,const int signal_direction,
                const bool view_valid,const int owned_count,
                const int owned_direction,const int pending_count,
                const bool safety_halt)
{
   if(safety_halt)
   {
      fsm.state = ADF_STATE_HALTED;
      fsm.pending_direction = 0;
      fsm.pending_bar = 0;
      return ADF_ACTION_HALT;
   }
   if(fsm.state == ADF_STATE_HALTED) return ADF_ACTION_NONE;

   if(fsm.pending_direction != 0 && fsm.pending_bar != decision_bar)
   {
      fsm.pending_direction = 0;
      fsm.pending_bar = 0;
      fsm.reverse_attempted = false;
   }

   if(!view_valid)
   {
      fsm.state = ADF_STATE_HALTED;
      fsm.pending_direction = 0;
      fsm.pending_bar = 0;
      fsm.reverse_attempted = false;
      return ADF_ACTION_HALT;
   }
   if(owned_count < 0 || owned_count > 1 ||
      (owned_count == 1 && owned_direction != 1 && owned_direction != 2) ||
      pending_count < 0)
   {
      fsm.state = ADF_STATE_HALTED;
      return ADF_ACTION_HALT;
   }
   if(pending_count > 0 && fsm.pending_direction == 0)
   {
      fsm.state = ADF_STATE_HALTED;
      return ADF_ACTION_HALT;
   }

   fsm.state = (owned_count == 0 ? ADF_STATE_FLAT :
                (owned_direction == 1 ? ADF_STATE_LONG : ADF_STATE_SHORT));

   if(fsm.pending_direction != 0)
   {
      if(fsm.reverse_attempted && owned_count == 1 &&
         owned_direction == fsm.pending_direction && pending_count == 0)
      {
         fsm.pending_direction = 0;
         fsm.pending_bar = 0;
         fsm.reverse_attempted = false;
         return ADF_ACTION_NONE;
      }
      fsm.state = ADF_STATE_CLOSING_FOR_REVERSE;
      if(owned_count > 0 || pending_count > 0) return ADF_ACTION_CLOSE;
      if(fsm.reverse_attempted) return ADF_ACTION_NONE;
      fsm.reverse_attempted = true;
      fsm.last_open_bar = decision_bar;
      return ADF_ACTION_OPEN;
   }

   if(!new_decision || (signal_direction != 1 && signal_direction != 2))
      return ADF_ACTION_NONE;

   if(owned_count == 0)
   {
      if(fsm.last_open_bar == decision_bar) return ADF_ACTION_NONE;
      fsm.last_open_bar = decision_bar;
      return ADF_ACTION_OPEN;
   }
   if(owned_direction == signal_direction) return ADF_ACTION_NONE;

   fsm.pending_direction = signal_direction;
   fsm.pending_bar = decision_bar;
   fsm.reverse_attempted = false;
   fsm.state = ADF_STATE_CLOSING_FOR_REVERSE;
   return ADF_ACTION_CLOSE;
}

#ifndef ADAPTIVE_DONCHIAN_FLIP_TEST

struct ADF_View
{
   bool valid;
   int positions;
   int direction;
   int pendings;
   ulong ticket;
   double sl;
   double tp;
};

struct ADF_Decision
{
   bool ready;
   datetime bar;
   int direction;
   int regime;
   double atr;
   double st_upper;
   double st_lower;
};

ADF_Fsm g_adf_fsm;
int g_adf_atr_handle = INVALID_HANDLE;
int g_adf_st_atr_handle = INVALID_HANDLE;
datetime g_adf_chart_bar = 0;
double g_adf_spreads[];
int g_adf_spread_count = 0;
int g_adf_spread_next = 0;
double g_adf_latched_atr = 0.0;
int g_adf_latched_regime = ADF_REGIME_INVALID;
int g_adf_open_refusals = 0;
int g_adf_close_failures = 0;
int g_adf_trail_refusals = 0;

bool AdaptiveDonchianFlip_ConfigValid()
{
   bool numeric =
      _24_DonchianBars > 0 && _24_ST_ATRPeriod > 0 && _24_ST_Mult > 0.0 &&
      _24_ATRPeriod > 0 && _24_ATRPctLookback > 0 &&
      0.0 < _24_ATRPctLow && _24_ATRPctLow < _24_ATRPctHigh &&
      _24_ATRPctHigh < _24_ATRPctExtreme && _24_ATRPctExtreme <= 100.0 &&
      _24_BufferATR_Normal > 0.0 && _24_BufferATR_High > 0.0 &&
      _24_SL_ATR_Normal > 0.0 && _24_SL_ATR_High > 0.0 &&
      _24_FixedLot > 0.0 && _24_SpreadSamples > 0 &&
      _24_SpreadMedianMult > 0.0 && _24_SpreadATRCap > 0.0;
   if(!numeric)
   {
      Print("[FB-A01] INIT FATAL: invalid V0 parameter ordering/value");
      return false;
   }
   if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) !=
      ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
   {
      Print("[FB-A01] INIT FATAL: hedging account mode required; netting/exchange mode refused");
      return false;
   }
   if(DryRun || FirstLotMode != FIRSTLOT_FIXED || LotProg != PROG_NONE ||
      TradeDir != TRADEDIR_BOTH || TrendFilter != TFILTER_NONE ||
      RecoveryMode != REC_NONE || HedgeMode != HEDGE_OFF ||
      _9_PendingMode != 0 || _9_PendingLegs != 0 ||
      _2_PartialPct1 > 0.0 || _2_PartialPct2 > 0.0 ||
      _0_BarOpenOnly || _0_MaxSpread > 0 || _MG_SelfGate)
   {
      Print("[FB-A01] INIT FATAL: V0 requires fixed-lot/bidirectional/no-stack/no-recovery/no-hedge/no-pending/no-partial and its dedicated closed-bar/spread lifecycle");
      return false;
   }
   return true;
}

bool ADF_ReadViewOnce(ADF_View &view)
{
   view.valid = true;
   view.positions = 0;
   view.direction = 0;
   view.pendings = 0;
   view.ticket = 0;
   view.sl = 0.0;
   view.tp = 0.0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) { view.valid=false; return false; }
      if(!ADF_Owns(PositionGetString(POSITION_SYMBOL),
                   (long)PositionGetInteger(POSITION_MAGIC),_Symbol,_0_Magic))
         continue;
      view.positions++;
      int direction = PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY ? 1 : 2;
      if(view.positions > 1 ||
         (view.direction != 0 && view.direction != direction))
      {
         view.valid=false;
         return false;
      }
      view.direction = direction;
      view.ticket = ticket;
      view.sl = PositionGetDouble(POSITION_SL);
      view.tp = PositionGetDouble(POSITION_TP);
   }
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) { view.valid=false; return false; }
      if(ADF_Owns(OrderGetString(ORDER_SYMBOL),
                  (long)OrderGetInteger(ORDER_MAGIC),_Symbol,_0_Magic))
         view.pendings++;
   }
   return true;
}

bool ADF_ReadStableView(ADF_View &view)
{
   ADF_View first,second;
   if(!ADF_ReadViewOnce(first) || !ADF_ReadViewOnce(second)) return false;
   if(first.positions != second.positions || first.direction != second.direction ||
      first.pendings != second.pendings || first.ticket != second.ticket)
      return false;
   view = second;
   return view.valid;
}

void ADF_SampleSpread(const MqlTick &tick)
{
   double spread = tick.ask - tick.bid;
   if(!MathIsValidNumber(spread) || spread <= 0.0) return;
   g_adf_spreads[g_adf_spread_next] = spread;
   g_adf_spread_next = (g_adf_spread_next + 1) % _24_SpreadSamples;
   if(g_adf_spread_count < _24_SpreadSamples) g_adf_spread_count++;
}

bool ADF_LoadSuperTrend(int &trend,double &upper,double &lower)
{
   int calculated = BarsCalculated(g_adf_st_atr_handle);
   int count = calculated - 1;
   if(count <= _24_ST_ATRPeriod) return false;
   MqlRates rates[];
   double atrs[];
   ArraySetAsSeries(rates,false);
   ArraySetAsSeries(atrs,false);
   if(CopyRates(_Symbol,_Period,1,count,rates) != count ||
      CopyBuffer(g_adf_st_atr_handle,0,1,count,atrs) != count)
      return false;

   bool seeded=false;
   double prev_close=0.0;
   for(int i=0;i<count;i++)
   {
      double atr=atrs[i];
      if(!MathIsValidNumber(atr) || atr <= 0.0)
      {
         if(seeded) return false;
         continue;
      }
      if(rates[i].high < rates[i].low ||
         rates[i].close > rates[i].high || rates[i].close < rates[i].low)
         return false;
      double hl2=(rates[i].high+rates[i].low)/2.0;
      double basic_upper=hl2+_24_ST_Mult*atr;
      double basic_lower=hl2-_24_ST_Mult*atr;
      if(!seeded)
      {
         upper=basic_upper;
         lower=basic_lower;
         trend=(rates[i].close>=hl2 ? ADF_TREND_UP : ADF_TREND_DOWN);
         prev_close=rates[i].close;
         seeded=true;
         continue;
      }
      double prev_upper=upper;
      double prev_lower=lower;
      upper=(basic_upper<prev_upper || prev_close>prev_upper)
            ? basic_upper : prev_upper;
      lower=(basic_lower>prev_lower || prev_close<prev_lower)
            ? basic_lower : prev_lower;
      if(trend==ADF_TREND_DOWN && rates[i].close>prev_upper)
         trend=ADF_TREND_UP;
      else if(trend==ADF_TREND_UP && rates[i].close<prev_lower)
         trend=ADF_TREND_DOWN;
      prev_close=rates[i].close;
   }
   return seeded;
}

bool ADF_LoadDecision(ADF_Decision &decision)
{
   decision.ready=false;
   decision.bar=iTime(_Symbol,_Period,1);
   decision.direction=0;
   decision.regime=ADF_REGIME_INVALID;
   decision.atr=0.0;
   decision.st_upper=0.0;
   decision.st_lower=0.0;
   if(decision.bar <= 0) return false;

   int need=_24_ATRPctLookback+1;
   double values[];
   ArraySetAsSeries(values,false);
   if(CopyBuffer(g_adf_atr_handle,0,1,need,values) != need) return false;
   double current=values[need-1];
   double history[];
   ArrayResize(history,_24_ATRPctLookback);
   for(int i=0;i<_24_ATRPctLookback;i++) history[i]=values[i];
   double pct=0.0;
   if(!ADF_Percentile(current,history,_24_ATRPctLookback,pct)) return false;
   int regime=ADF_Regime(pct,_24_ATRPctLow,_24_ATRPctHigh,_24_ATRPctExtreme);
   if(regime==ADF_REGIME_INVALID) return false;

   double highs[],lows[];
   ArrayResize(highs,_24_DonchianBars);
   ArrayResize(lows,_24_DonchianBars);
   for(int i=0;i<_24_DonchianBars;i++)
   {
      highs[i]=iHigh(_Symbol,_Period,i+2);
      lows[i]=iLow(_Symbol,_Period,i+2);
   }
   double upper=0.0,lower=0.0;
   if(!ADF_Donchian(highs,lows,_24_DonchianBars,upper,lower)) return false;

   int trend=0;
   if(!ADF_LoadSuperTrend(trend,decision.st_upper,decision.st_lower)) return false;
   double close=iClose(_Symbol,_Period,1);
   if(!MathIsValidNumber(close) || close<=0.0) return false;
   if(regime==ADF_REGIME_NORMAL)
      decision.direction=ADF_Breakout(close,upper,lower,
                         _24_BufferATR_Normal*current,trend);
   else if(regime==ADF_REGIME_HIGH)
      decision.direction=ADF_Breakout(close,upper,lower,
                         _24_BufferATR_High*current,trend);
   decision.regime=regime;
   decision.atr=current;
   decision.ready=true;
   return true;
}

double ADF_NormalizeInitialStop(const int direction,const double entry,
                                const double raw)
{
   double tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double stop_distance=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
   if(tick_size<=0.0 || raw<=0.0) return 0.0;
   double normalized=(direction==1 ? MathFloor(raw/tick_size)
                                   : MathCeil(raw/tick_size))*tick_size;
   normalized=NormalizeDouble(normalized,_Digits);
   double distance=(direction==1 ? entry-normalized : normalized-entry);
   if(distance<=0.0 || distance+1.0e-12<stop_distance) return 0.0;
   return normalized;
}

bool ADF_Open(const int direction,const double atr,const int regime)
{
   if(direction!=1 && direction!=2) return false;
   if(regime!=ADF_REGIME_NORMAL && regime!=ADF_REGIME_HIGH) return false;
   if(Exec_NewsBlocked() || Exec_MacroBlocked() ||
      !RiskControl_AllowNewOrder())
      return false;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick)) return false;
   const double request_price=(direction==1 ? tick.ask : tick.bid);
   double mult=(regime==ADF_REGIME_NORMAL ? _24_SL_ATR_Normal
                                         : _24_SL_ATR_High);
   double sl=ADF_NormalizeInitialStop(direction,request_price,
                                     ADF_InitialSL(direction,request_price,atr,mult));
   if(sl<=0.0)
   {
      g_adf_open_refusals++;
      Print("[FB-A01] open refused: initial SL invalid after broker stop/tick normalization");
      return false;
   }
   double lot=Exec_NormalizeLot(_24_FixedLot);
   if(lot<=0.0)
   {
      g_adf_open_refusals++;
      return false;
   }
   bool sent=(direction==1
      ? g_trade.Buy(lot,_Symbol,request_price,sl,0.0,LAB_ENTRY_TAG)
      : g_trade.Sell(lot,_Symbol,request_price,sl,0.0,LAB_ENTRY_TAG));
   uint rc=g_trade.ResultRetcode();
   bool accepted=sent && rc==TRADE_RETCODE_DONE;
   if(!accepted)
   {
      g_adf_open_refusals++;
      PrintFormat("[FB-A01] open failed closed: dir=%d sent=%d retcode=%u; no same-bar retry",
                  direction,(sent?1:0),rc);
   }
   return accepted;
}

void ADF_Trail(const ADF_View &view,const ADF_Decision &decision,
               const MqlTick &tick)
{
   if(view.positions!=1 || view.ticket==0) return;
   double line=(view.direction==1 ? decision.st_lower : decision.st_upper);
   double tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double stop_distance=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
   if(!MathIsValidNumber(line) || line<=0.0 || tick_size<=0.0) return;
   double candidate=(view.direction==1 ? MathFloor(line/tick_size)
                                       : MathCeil(line/tick_size))*tick_size;
   candidate=NormalizeDouble(candidate,_Digits);
   double market=(view.direction==1 ? tick.bid : tick.ask);
   bool broker_valid=(view.direction==1
      ? candidate<market && market-candidate+1.0e-12>=stop_distance
      : candidate>market && candidate-market+1.0e-12>=stop_distance);
   if(!broker_valid)
   {
      g_adf_trail_refusals++;
      PrintFormat("[FB-A01] trail unchanged: candidate %.10f violates broker stop level",candidate);
      return;
   }
   if(!ADF_TrailTightens(view.direction,view.sl,candidate)) return;
   bool sent=g_trade.PositionModify(view.ticket,candidate,view.tp);
   uint rc=g_trade.ResultRetcode();
   if(!sent || (rc!=TRADE_RETCODE_DONE && rc!=TRADE_RETCODE_NO_CHANGES))
   {
      g_adf_trail_refusals++;
      PrintFormat("[FB-A01] trail modify failed closed: ticket=%I64u retcode=%u; prior SL retained",
                  view.ticket,rc);
   }
}

bool AdaptiveDonchianFlip_Init()
{
   ADF_FsmReset(g_adf_fsm);
   ArrayResize(g_adf_spreads,_24_SpreadSamples);
   ArrayInitialize(g_adf_spreads,0.0);
   g_adf_spread_count=0;
   g_adf_spread_next=0;
   g_adf_atr_handle=iATR(_Symbol,_Period,_24_ATRPeriod);
   g_adf_st_atr_handle=iATR(_Symbol,_Period,_24_ST_ATRPeriod);
   if(g_adf_atr_handle==INVALID_HANDLE || g_adf_st_atr_handle==INVALID_HANDLE)
   {
      Print("[FB-A01] INIT FATAL: ATR handle creation failed");
      return false;
   }
   int minimum=MathMax(_24_DonchianBars+2,_24_ATRPctLookback+2);
   minimum=MathMax(minimum,_24_ST_ATRPeriod+2);
   if(Bars(_Symbol,_Period)<minimum)
   {
      PrintFormat("[FB-A01] INIT FATAL: insufficient closed history (%d required)",minimum);
      return false;
   }
   ADF_Decision probe;
   if(!ADF_LoadDecision(probe))
   {
      Print("[FB-A01] INIT FATAL: required ATR/Donchian/SuperTrend history unavailable");
      return false;
   }
   ADF_View view;
   if(!ADF_ReadStableView(view) || view.positions>1 || view.pendings>0)
   {
      g_adf_fsm.state=ADF_STATE_HALTED;
      Print("[FB-A01] HALTED: ambiguous owned position/pending state at initialization");
   }
   else if(view.positions==1)
      g_adf_fsm.state=(view.direction==1 ? ADF_STATE_LONG : ADF_STATE_SHORT);
   g_adf_chart_bar=iTime(_Symbol,_Period,0);
   return true;
}

void AdaptiveDonchianFlip_SharedHalt()
{
   if(g_adf_fsm.state!=ADF_STATE_HALTED)
      Print("[FB-A01] HALTED by shared RiskControl; strategy will not self-clear");
   g_adf_fsm.state=ADF_STATE_HALTED;
   g_adf_fsm.pending_direction=0;
   g_adf_fsm.pending_bar=0;
}

void AdaptiveDonchianFlip_OnTick()
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick)) return;
   ADF_SampleSpread(tick);
   if(g_adf_fsm.state==ADF_STATE_HALTED) return;

   datetime chart_bar=iTime(_Symbol,_Period,0);
   datetime decision_bar=iTime(_Symbol,_Period,1);
   if(chart_bar<=0 || decision_bar<=0) return;
   bool new_decision=(chart_bar!=g_adf_chart_bar);
   ADF_Decision decision;
   decision.ready=false;
   decision.direction=0;
   if(new_decision)
   {
      g_adf_chart_bar=chart_bar;
      if(!ADF_LoadDecision(decision))
      {
         g_adf_fsm.state=ADF_STATE_HALTED;
         Print("[FB-A01] HALTED: required closed-bar indicator history became invalid");
         return;
      }
      if(decision.direction==1 || decision.direction==2)
      {
         g_adf_latched_atr=decision.atr;
         g_adf_latched_regime=decision.regime;
      }
   }

   ADF_View view;
   bool stable=ADF_ReadStableView(view);
   int action=ADF_FsmStep(g_adf_fsm,(long)decision_bar,new_decision,
                          (new_decision ? decision.direction : 0),
                          stable,(stable ? view.positions : 0),
                          (stable ? view.direction : 0),
                          (stable ? view.pendings : 0),false);
   if(action==ADF_ACTION_HALT)
   {
      Print("[FB-A01] HALTED: ownership ambiguity or unexpected owned pending order");
      return;
   }
   if(action==ADF_ACTION_CLOSE)
   {
      if(!Exec_CloseAll())
      {
         g_adf_close_failures++;
         Print("[FB-A01] close/flat verification incomplete; reverse remains blocked");
      }
      return;
   }
   if(action==ADF_ACTION_OPEN)
   {
      int direction=(g_adf_fsm.pending_direction!=0
                     ? g_adf_fsm.pending_direction : decision.direction);
      if(!ADF_SpreadPass(tick.ask-tick.bid,g_adf_spreads,
                         g_adf_spread_count,_24_SpreadSamples,
                         _24_SpreadMedianMult,_24_SpreadATRCap,
                         g_adf_latched_atr))
      {
         g_adf_open_refusals++;
         Print("[FB-A01] entry blocked by spread warmup/median/ATR cap; no same-bar retry");
         return;
      }
      ADF_Open(direction,g_adf_latched_atr,g_adf_latched_regime);
      return;
   }

   if(new_decision && stable && view.positions==1)
      ADF_Trail(view,decision,tick);
}

void AdaptiveDonchianFlip_Deinit()
{
   if(g_adf_atr_handle!=INVALID_HANDLE) IndicatorRelease(g_adf_atr_handle);
   if(g_adf_st_atr_handle!=INVALID_HANDLE) IndicatorRelease(g_adf_st_atr_handle);
   g_adf_atr_handle=INVALID_HANDLE;
   g_adf_st_atr_handle=INVALID_HANDLE;
   PrintFormat("[FB-A01] counters open_refusal=%d close_incomplete=%d trail_refusal=%d",
               g_adf_open_refusals,g_adf_close_failures,g_adf_trail_refusals);
}

#endif // ADAPTIVE_DONCHIAN_FLIP_TEST
#endif // BOSS_LAB_ENTRY_ADAPTIVE_DONCHIAN_FLIP_MQH
