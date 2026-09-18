// Source: (Boss) Gold Robot Scalping Time Bomb rev1.mq5
// SHA256 795c446093bc0ef888bad84f162646f94d303831e8becf10955d7e016ed1f93c
// FAMILY_NATIVE_PIPELINE_OR_EXPLICIT_ADAPTER. No shared Stack/MM/Exit ownership.
#ifndef BOSS_GOLD_TIME_BOMB_MQH
#define BOSS_GOLD_TIME_BOMB_MQH

// BEGIN DF02 DETERMINISTIC KERNEL
// This region is executed by the no-terminal test harness as well as by MQL5.
double GT_Pip(const double point)
{
   // Parent POINT_FORMAT_RULES (line 28), including six-digit quotes.
   if(point == 0.001) return 0.01;
   if(point == 0.00001 || point == 0.000001) return 0.0001;
   return point;
}

struct GT_Bomb
{
   double anchor;
   long stamp;
   long last_bar;
   void Reset() { anchor = 0; stamp = 0; last_bar = 0; }
   bool Trigger(const int side, const double quote, const long now,
                const double threshold, const double seconds, const double pip)
   {
      bool fire = false;
      bool reset = (anchor <= 0);
      if(anchor > 0)
      {
         double move = side * (quote - anchor);
         long elapsed = now - stamp;
         if(move / pip >= threshold && elapsed <= seconds)
         {
            fire = (move > 0);
            reset = true;
         }
         if(elapsed >= seconds) reset = true;
      }
      if(reset) { anchor = quote; stamp = now; }
      return fire;
   }
   bool Once(const long previous_bar)
   {
      // Parent MDL_OncePerBar reads shift 1, uses strictly increasing time.
      if(previous_bar <= last_bar) return false;
      last_bar = previous_bar;
      return true;
   }
};

struct GT_Grid
{
   double offset;
   void Reset() { offset = 0; }
   bool AddBranch(const int side, const bool favorable, const double close_price,
                  const double newest_open, const double grid)
   {
      double relation = side * (close_price - newest_open);
      bool pass = (favorable ? relation > 0 : relation < 0);
      // Write BEFORE nearby exclusion, even when no order follows.
      if(pass) offset = 2 * grid;
      return pass;
   }
};

bool GT_Flat(const int position_count) { return position_count == 0; }
bool GT_Nearby(const double quote, const double open_price, const double width)
{
   // Parent RangePosition=0: width/2 on EACH side, inclusive endpoints.
   return quote <= open_price + width / 2 && quote >= open_price - width / 2;
}
int GT_OrderKind(const int side, const double target, const double quote)
{
   // 0=market, 1=stop, -1=limit; parent BuyLater/SellLater compares prices.
   if(target == quote) return 0;
   return side * (target - quote) > 0 ? 1 : -1;
}
long GT_Today(const long now) { return (now / 86400 + 1) * 86400; }
double GT_Lots(const double percent, const double free_margin, const double margin_one,
               const double step, const double minimum, const double maximum,
               const bool margin_ok)
{
   // Parent DynamicLots + AlignLots: nearest step, then min/max (not floor).
   // Explicit fail-safe for unavailable/invalid margin and broker metadata.
   if(!margin_ok || !MathIsValidNumber(margin_one) || margin_one <= 0 ||
      !MathIsValidNumber(free_margin) || free_margin <= 0 ||
      !MathIsValidNumber(percent) || percent < 0 ||
      !MathIsValidNumber(step) || step <= 0 || !MathIsValidNumber(minimum) ||
      !MathIsValidNumber(maximum) || minimum <= 0 || maximum < minimum ||
      maximum < step) return 0;
   double raw = (percent / 100) * free_margin / margin_one;
   if(!MathIsValidNumber(raw)) return 0;
   double lots = MathRound(raw / step) * step;
   if(!MathIsValidNumber(lots)) return 0;
   lots = MathMax(MathMax(minimum, step), MathMin(maximum, lots));
   return lots;
}

struct GT_Trail
{
   double stop;
   string trades;
   bool reset_sl;
   void Reset() { stop = 0; trades = ""; reset_sl = false; }
   bool Update(const string tickets, const double net_lots, const double average,
               const double ask, const double bid, const double distance,
               const double step, const double pip)
   {
      reset_sl = (tickets != trades);
      if(reset_sl) { stop = 0; trades = tickets; }
      if(net_lots == 0) return false;
      int polarity = net_lots > 0 ? 1 : -1;
      double quote = polarity > 0 ? ask : bid;
      // Parent TrailingStartMode=none uses -EMPTY_VALUE, not breakeven/start=0.
      if(polarity * (quote - average) <= -2147483647.0 * pip) return false;
      if(stop == 0 || reset_sl || polarity * (quote - stop) >= distance + step)
      {
         stop = quote - polarity * distance;
         return true;
      }
      return false;
   }
};
double GT_TrailLimit(const int side, const double group_stop, const double opposite_quote,
                     const double stops_distance)
{
   double candidate = MathAbs(group_stop);
   return side > 0 ? MathMin(candidate, opposite_quote - stops_distance)
                   : MathMax(candidate, opposite_quote + stops_distance);
}
bool GT_ModifySL(const int side, const double old_sl, const double candidate, const bool reset_sl)
{
   return old_sl == 0 || reset_sl || side * (candidate - old_sl) > 0;
}
double GT_AlignSourceSL(const int side, const double group_stop, const double old_sl,
                        const double own_quote, const double exit_quote,
                        const double stops_distance, const double tick_size)
{
   // Parent AlignStopLoss (5162..5306), after the group decision:
   // a stop on the WRONG side is rejected, not clamped into a new stop.
   // This matters for a mixed-direction group. Only too-close valid stops align.
   double sl = group_stop > 0 ? group_stop : 0;
   if(sl == old_sl) return sl;
   if(sl > 0 && side * (sl - own_quote) > 0) return -1;
   double limit = exit_quote - side * stops_distance;
   if(sl > 0 && side * (sl - limit) > 0) return limit;
   return MathRound(sl / tick_size) * tick_size;
}
double GT_PreserveTP(const double existing_tp, const double inactive_ftTP)
{
   // Frozen contract: ftTP storage is non-causal; preserve each ticket's TP.
   return existing_tp;
}
// END DF02 DETERMINISTIC KERNEL

#ifndef GOLD_TIME_BOMB_TEST
GT_Bomb g_gt_buy, g_gt_sell;
GT_Grid g_gt_grid;
GT_Trail g_gt_trail;

double GT_Distance(const double pips)
{
   return NormalizeDouble(pips * GT_Pip(_Point), _Digits);
}
bool GT_OwnSelected()
{
   return PositionGetString(POSITION_SYMBOL) == _Symbol &&
          PositionGetInteger(POSITION_MAGIC) == _20_MagicStart;
}
int GT_Count(const int side)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
      if(PositionGetTicket(i) != 0 && GT_OwnSelected() &&
         (side == 0 || (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1) == side))
         count++;
   return count;
}
double GT_Newest(const int side)
{
   // Parent newest-to-oldest traversal uses reverse position enumeration.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
      if(PositionGetTicket(i) != 0 && GT_OwnSelected() &&
         (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1) == side)
         return PositionGetDouble(POSITION_PRICE_OPEN);
   return 0;
}
bool GT_HasNearby(const int side, const double quote)
{
   for(int i = PositionsTotal() - 1; i >= 0; --i)
      if(PositionGetTicket(i) != 0 && GT_OwnSelected() &&
         (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1) == side &&
         GT_Nearby(quote, PositionGetDouble(POSITION_PRICE_OPEN), GT_Distance(g_gt_grid.offset)))
         return true;
   return false;
}
ENUM_ORDER_TYPE_FILLING GT_Fill(const bool pending)
{
   long modes = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if(pending)
   {
      // Preserve the parent's pending branch, including its ORDER enum bit test.
      if((modes & ORDER_FILLING_RETURN) == ORDER_FILLING_RETURN) return ORDER_FILLING_RETURN;
      return ORDER_FILLING_FOK;
   }
   if((modes & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
   if((modes & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}
bool GT_Send(MqlTradeRequest &request, MqlTradeResult &result)
{
   bool sent = OrderSend(request, result);
   bool ok = sent && (result.retcode == TRADE_RETCODE_DONE ||
                      result.retcode == TRADE_RETCODE_PLACED ||
                      result.retcode == TRADE_RETCODE_DONE_PARTIAL);
   if(!ok) PrintFormat("[DF02] request failed: action=%d retcode=%u error=%d %s",
                       request.action, result.retcode, GetLastError(), result.comment);
   return ok;
}
string GT_ExpiryName(const ulong ticket)
{
   // Same chart-persistent marker identity used by the parent ExpirationWorker.
   return "#" + (string)ticket + " Expiration Marker";
}
void GT_Expire()
{
   // Parent OnTick runs ExpirationWorker before all blocks. Only initial
   // zero-offset market positions get markers; filled pending orders do not.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !GT_OwnSelected()) continue;
      string name = GT_ExpiryName(ticket);
      if(ObjectFind(0, name) < 0) continue;
      datetime expiry = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME);
      if(expiry <= 0 || TimeCurrent() < expiry) continue;
      MqlTick tick;
      if(!SymbolInfoTick(_Symbol, tick)) continue;
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      bool buy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      request.action = TRADE_ACTION_DEAL;
      request.position = ticket;
      request.symbol = _Symbol;
      request.magic = _20_MagicStart;
      request.volume = PositionGetDouble(POSITION_VOLUME);
      request.type = buy ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      request.price = buy ? tick.bid : tick.ask;
      request.type_filling = GT_Fill(false);
      request.deviation = (ulong)(4 * GT_Pip(_Point) / _Point);
      if(GT_Send(request, result) && !PositionSelectByTicket(ticket)) ObjectDelete(0, name);
   }
}
void GT_Open(const int side, const bool initial)
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;
   double margin_one = 0;
   // Parent calculates one-lot BUY margin at Ask for both order directions.
   bool margin_ok = OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, 1.0, tick.ask, margin_one);
   double lots = GT_Lots(_20_Freeze_lot, AccountInfoDouble(ACCOUNT_MARGIN_FREE), margin_one,
                         SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP),
                         SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN),
                         SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX), margin_ok);
   if(lots <= 0) { Print("[DF02] sizing unavailable; no order"); return; }
   double quote = side > 0 ? tick.ask : tick.bid;
   double target = quote + side * (initial ? GT_Distance(g_gt_grid.offset) : 0);
   int kind = GT_OrderKind(side, target, quote);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0) return;
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   request.action = kind == 0 ? TRADE_ACTION_DEAL : TRADE_ACTION_PENDING;
   request.type = side > 0 ? (kind == 0 ? ORDER_TYPE_BUY : (kind > 0 ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_BUY_LIMIT))
                           : (kind == 0 ? ORDER_TYPE_SELL : (kind > 0 ? ORDER_TYPE_SELL_STOP : ORDER_TYPE_SELL_LIMIT));
   request.symbol = _Symbol;
   request.magic = _20_MagicStart;
   request.volume = lots;
   request.price = NormalizeDouble(MathRound(target / tick_size) * tick_size, _Digits);
   request.deviation = (ulong)(4 * GT_Pip(_Point) / _Point);
   request.type_filling = GT_Fill(kind != 0);
   // Every source order starts without SL/TP. No chassis defaults reach here.
   request.sl = 0;
   request.tp = 0;
   datetime expiry = initial ? (datetime)GT_Today((long)TimeCurrent()) : 0;
   if(kind != 0)
   {
      long modes = SymbolInfoInteger(_Symbol, SYMBOL_EXPIRATION_MODE);
      request.type_time = (modes & SYMBOL_EXPIRATION_DAY) != 0 ? ORDER_TIME_DAY : ORDER_TIME_SPECIFIED;
      request.expiration = expiry;
   }
   MqlTradeCheckResult check = {};
   if(!OrderCheck(request, check))
   {
      PrintFormat("[DF02] order check refused: %u %s", check.retcode, check.comment);
      return;
   }
   if(!GT_Send(request, result)) return;
   if(initial && kind == 0 && expiry > 0 && PositionSelectByTicket(result.order))
   {
      string name = GT_ExpiryName(result.order);
      if(!ObjectCreate(0, name, OBJ_VLINE, 0, expiry, 0))
         PrintFormat("[DF02] expiration marker unavailable for %I64u", result.order);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }
}
void GT_Add(const int side, const bool favorable)
{
   if(GT_Count(side) == 0) return;
   double newest = GT_Newest(side);
   if(!g_gt_grid.AddBranch(side, favorable, iClose(_Symbol, PERIOD_CURRENT, 0), newest, _20_Grid_Distance)) return;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;
   if(!GT_HasNearby(side, side > 0 ? tick.ask : tick.bid)) GT_Open(side, false);
}
void GT_Initial(const int side)
{
   // Positions ONLY. Pending orders neither block nor reset a TimeBomb.
   if(!GT_Flat(GT_Count(side))) return;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;
   bool fire = side > 0 ? g_gt_buy.Trigger(1, tick.ask, (long)TimeCurrent(), _20_Pips_to_raise, _20_Time_to_wait, GT_Pip(_Point))
                        : g_gt_sell.Trigger(-1, tick.bid, (long)TimeCurrent(), _20_Pips_to_fall, _20_Time_to_wait, GT_Pip(_Point));
   if(!fire) return;
   long bar = (long)iTime(_Symbol, PERIOD_CURRENT, 1);
   bool pass = side > 0 ? g_gt_buy.Once(bar) : g_gt_sell.Once(bar);
   if(pass) GT_Open(side, true);
}
void GT_Trailing()
{
   if(GT_Count(0) == 0) return; // parent's If trade -> Count >= 1 gate
   double net = 0, load = 0;
   string tickets = "";
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !GT_OwnSelected()) continue;
      double signed_lots = PositionGetDouble(POSITION_VOLUME) *
                           (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1);
      net += signed_lots;
      load += signed_lots * PositionGetDouble(POSITION_PRICE_OPEN);
      tickets = (string)ticket + tickets;
   }
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;
   double average = net == 0 ? 0 : load / net;
   if(!g_gt_trail.Update(tickets, net, average, tick.ask, tick.bid,
                         GT_Distance(_20_Trailing_Stop), GT_Distance(_20_Trailing_step), GT_Pip(_Point))) return;
   double opposite = net > 0 ? tick.bid : tick.ask;
   double limit = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0) return;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !GT_OwnSelected()) continue;
      int side = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1;
      double candidate = GT_TrailLimit(side, g_gt_trail.stop, opposite, limit);
      double old_sl = PositionGetDouble(POSITION_SL);
      if(!GT_ModifySL(side, old_sl, candidate, g_gt_trail.reset_sl)) continue;
      // Broker alignment after the source's group-level decision.
      double executable = GT_AlignSourceSL(side, NormalizeDouble(g_gt_trail.stop, _Digits), old_sl,
                                           side > 0 ? tick.ask : tick.bid, side > 0 ? tick.bid : tick.ask,
                                           limit, tick_size);
      if(executable < 0) continue;
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      request.action = TRADE_ACTION_SLTP;
      request.position = ticket;
      request.symbol = _Symbol;
      request.sl = NormalizeDouble(MathRound(executable / tick_size) * tick_size, _Digits);
      request.tp = GT_PreserveTP(PositionGetDouble(POSITION_TP), 40.0);
      if(request.sl != old_sl) GT_Send(request, result);
   }
}
void GoldTimeBomb_Reset()
{
   g_gt_buy.Reset(); g_gt_sell.Reset(); g_gt_grid.Reset(); g_gt_trail.Reset();
   // Chart expiration markers survive restart, as in the source.
}
void GoldTimeBomb_OnTick()
{
   GT_Expire();
   // Frozen source root order {4,6,11,18,21,24,25,30}; 4 is display-only.
   GT_Add(1, true);
   GT_Add(-1, true);
   GT_Initial(1);
   GT_Trailing();
   GT_Initial(-1);
   GT_Add(1, false);
   GT_Add(-1, false);
}
#endif // GOLD_TIME_BOMB_TEST
#endif // BOSS_GOLD_TIME_BOMB_MQH
