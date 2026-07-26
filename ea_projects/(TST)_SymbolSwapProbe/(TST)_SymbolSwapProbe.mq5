//+------------------------------------------------------------------+
//| (TST)_SymbolSwapProbe.mq5                                        |
//|                                                                  |
//| Diagnostic only — places no orders. Prints the swap/contract      |
//| specification the STRATEGY TESTER itself is using for the symbol  |
//| it runs on, so "the backtest counts swap as 0" stops being lore   |
//| and becomes a measured number (or is disproven).                  |
//| Created 2026-07-26 to price the swap drag on the BTCUSD H4        |
//| pyramid candidate before spending the 2026H1 holdout.             |
//+------------------------------------------------------------------+
#property strict
#property description "(TST)_SymbolSwapProbe — prints tester-side swap/contract specs, trades nothing"

string SwapModeName(const long m)
{
   switch((ENUM_SYMBOL_SWAP_MODE)m)
   {
      case SYMBOL_SWAP_MODE_DISABLED:         return "DISABLED (no swap charged)";
      case SYMBOL_SWAP_MODE_POINTS:           return "POINTS";
      case SYMBOL_SWAP_MODE_CURRENCY_SYMBOL:  return "CURRENCY_SYMBOL";
      case SYMBOL_SWAP_MODE_CURRENCY_MARGIN:  return "CURRENCY_MARGIN";
      case SYMBOL_SWAP_MODE_CURRENCY_DEPOSIT: return "CURRENCY_DEPOSIT";
      case SYMBOL_SWAP_MODE_INTEREST_CURRENT: return "INTEREST_CURRENT (annual %)";
      case SYMBOL_SWAP_MODE_INTEREST_OPEN:    return "INTEREST_OPEN (annual %)";
      case SYMBOL_SWAP_MODE_REOPEN_CURRENT:   return "REOPEN_CURRENT";
      case SYMBOL_SWAP_MODE_REOPEN_BID:       return "REOPEN_BID";
   }
   return "UNKNOWN("+IntegerToString(m)+")";
}

int OnInit()
{
   const double swLong  = SymbolInfoDouble(_Symbol,SYMBOL_SWAP_LONG);
   const double swShort = SymbolInfoDouble(_Symbol,SYMBOL_SWAP_SHORT);
   const long   mode    = SymbolInfoInteger(_Symbol,SYMBOL_SWAP_MODE);
   const long   rollover= SymbolInfoInteger(_Symbol,SYMBOL_SWAP_ROLLOVER3DAYS);
   const double contract= SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE);
   const double tickVal = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   const double point   = SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   const double bid     = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double minLot  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);

   PrintFormat("SWAPPROBE %s | mode=%s | swap_long=%.6f swap_short=%.6f | rollover3days=%s",
               _Symbol, SwapModeName(mode), swLong, swShort, EnumToString((ENUM_DAY_OF_WEEK)rollover));
   PrintFormat("SWAPPROBE %s | contract_size=%.2f tick_value=%.6f point=%.6f bid=%.2f min_lot=%.4f",
               _Symbol, contract, tickVal, point, bid, minLot);

   // What one day of holding minLot actually costs, per swap mode. Only the modes this
   // broker might use are computed; anything else is reported as needing a manual read.
   double dailyLong = 0.0, dailyShort = 0.0; string basis = "n/a";
   if(mode == SYMBOL_SWAP_MODE_POINTS)
   { dailyLong = swLong*point*contract*minLot; dailyShort = swShort*point*contract*minLot; basis = "points x point x contract x lot"; }
   else if(mode == SYMBOL_SWAP_MODE_INTEREST_CURRENT || mode == SYMBOL_SWAP_MODE_INTEREST_OPEN)
   { dailyLong = swLong/100.0/360.0*bid*contract*minLot; dailyShort = swShort/100.0/360.0*bid*contract*minLot; basis = "annual%/360 x notional"; }
   else if(mode == SYMBOL_SWAP_MODE_CURRENCY_SYMBOL || mode == SYMBOL_SWAP_MODE_CURRENCY_DEPOSIT || mode == SYMBOL_SWAP_MODE_CURRENCY_MARGIN)
   { dailyLong = swLong*minLot; dailyShort = swShort*minLot; basis = "currency per lot x lot"; }

   PrintFormat("SWAPPROBE %s | est per-day cost at %.4f lot: long=%.4f short=%.4f (basis: %s)",
               _Symbol, minLot, dailyLong, dailyShort, basis);
   PrintFormat("SWAPPROBE %s | notional at %.4f lot = %.2f (bid x contract x lot)",
               _Symbol, minLot, bid*contract*minLot);
   return INIT_FAILED;   // diagnostic: stop the run immediately, never trade
}

void OnTick(){}
