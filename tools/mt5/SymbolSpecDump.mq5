//+------------------------------------------------------------------+
//| SymbolSpecDump.mq5 - writes broker specs of a symbol list to      |
//| Common\Files\EA_LAB_symbol_specs.csv, then stops. Read-only:      |
//| places no orders. Run once in the Strategy Tester.                |
//+------------------------------------------------------------------+
#property strict
input string InpSymbols = "XAUUSD,BTCUSD,ETHUSD,EURUSD,GBPUSD,EURGBP,USDJPY,EURJPY,AUDCAD,NZDCAD";

int OnInit()
{
   string list[];
   int n = StringSplit(InpSymbols, ',', list);
   int h = FileOpen("EA_LAB_symbol_specs.csv", FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(h == INVALID_HANDLE) { Print("SPECDUMP cannot open file err=", GetLastError()); return INIT_FAILED; }
   FileWrite(h, "symbol", "selected", "digits", "point", "tick_size", "tick_value", "contract_size",
             "volume_min", "volume_step", "volume_max", "currency_base", "currency_profit", "currency_margin",
             "trade_calc_mode", "stops_level", "spread", "account_currency", "server", "build");
   for(int i = 0; i < n; i++)
   {
      string s = list[i];
      StringTrimLeft(s); StringTrimRight(s);
      bool sel = SymbolSelect(s, true);
      FileWrite(h, s, (sel ? "1" : "0"),
                (int)SymbolInfoInteger(s, SYMBOL_DIGITS),
                DoubleToString(SymbolInfoDouble(s, SYMBOL_POINT), 10),
                DoubleToString(SymbolInfoDouble(s, SYMBOL_TRADE_TICK_SIZE), 10),
                DoubleToString(SymbolInfoDouble(s, SYMBOL_TRADE_TICK_VALUE), 10),
                DoubleToString(SymbolInfoDouble(s, SYMBOL_TRADE_CONTRACT_SIZE), 4),
                DoubleToString(SymbolInfoDouble(s, SYMBOL_VOLUME_MIN), 4),
                DoubleToString(SymbolInfoDouble(s, SYMBOL_VOLUME_STEP), 4),
                DoubleToString(SymbolInfoDouble(s, SYMBOL_VOLUME_MAX), 4),
                SymbolInfoString(s, SYMBOL_CURRENCY_BASE),
                SymbolInfoString(s, SYMBOL_CURRENCY_PROFIT),
                SymbolInfoString(s, SYMBOL_CURRENCY_MARGIN),
                (int)SymbolInfoInteger(s, SYMBOL_TRADE_CALC_MODE),
                (int)SymbolInfoInteger(s, SYMBOL_TRADE_STOPS_LEVEL),
                (int)SymbolInfoInteger(s, SYMBOL_SPREAD),
                AccountInfoString(ACCOUNT_CURRENCY),
                AccountInfoString(ACCOUNT_SERVER),
                (int)TerminalInfoInteger(TERMINAL_BUILD));
   }
   FileClose(h);
   Print("SPECDUMP wrote ", n, " symbols");
   return INIT_SUCCEEDED;
}

void OnTick() { ExpertRemove(); }
