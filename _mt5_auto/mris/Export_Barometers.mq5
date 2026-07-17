//+------------------------------------------------------------------+
//| Export_Barometers.mq5 - MRIS barometer feed (ORDER-073 Phase-2)   |
//| Utility EA/script: dumps a current snapshot of the barometer      |
//| symbols the broker HAS to barometer_snapshot.csv, in the exact     |
//| schema mris_classify.ps1 expects:                                  |
//|   symbol,spot,sma200,atr20,chg5d_pct,data_status,source_note       |
//| Attach to ONE chart (any symbol). It computes SMA200 + ATR20 +     |
//| 5-day % change per symbol from D1 bars and writes the CSV to       |
//| Terminal\Common\Files (synced to the lab PC via the same rclone    |
//| transport as the news feed).                                       |
//|                                                                    |
//| Symbols the broker does NOT carry (VIX, DXY, US10Y-JP10Y spread,   |
//| copper) are LEFT to a separate web feeder - this exporter only     |
//| writes what MetaTrader can price, and marks the rest untouched so  |
//| the classifier keeps them PENDING.                                 |
//+------------------------------------------------------------------+
#property copyright "EA_LAB"
#property version   "1.00"
#property description "MRIS: export broker-priced barometers (spot/SMA200/ATR20/chg5d) to CSV"

input string BarometerSymbols = "AUDJPY,USDJPY,XAUUSD,BTCUSD"; // broker symbols to export (comma-sep)
input string OutFile          = "barometer_snapshot_mt5.csv";  // written to Common\Files
input int    SMAPeriod        = 200;
input int    ATRPeriod        = 20;
input int    ChgDays          = 5;
input int    TimerSeconds     = 3600;                          // re-export hourly

//+------------------------------------------------------------------+
int OnInit()
{
   EventSetTimer(TimerSeconds);
   ExportOnce();
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason) { EventKillTimer(); }
void OnTimer() { ExportOnce(); }

//+------------------------------------------------------------------+
//| Resolve a broker symbol that may carry a suffix (AUDJPYm etc.)    |
//+------------------------------------------------------------------+
string ResolveSymbol(const string want)
{
   if(SymbolSelect(want, true)) return want;
   int total = SymbolsTotal(false);
   for(int i=0; i<total; i++)
   {
      string s = SymbolName(i, false);
      if(StringFind(s, want) == 0) { SymbolSelect(s, true); return s; } // prefix match -> suffixed variant
   }
   return ""; // not found
}

//+------------------------------------------------------------------+
bool ComputeMetrics(const string sym, double &spot, double &sma200, double &atr20, double &chg5d)
{
   int need = MathMax(SMAPeriod, MathMax(ATRPeriod, ChgDays)) + 5;
   double close[]; ArraySetAsSeries(close, true);
   if(CopyClose(sym, PERIOD_D1, 0, need, close) < need) return false;

   spot = close[0];

   // SMA200 of closes
   double sum = 0; for(int i=0; i<SMAPeriod; i++) sum += close[i];
   sma200 = sum / SMAPeriod;

   // ATR20 via built-in
   int h = iATR(sym, PERIOD_D1, ATRPeriod);
   double atrb[]; ArraySetAsSeries(atrb, true);
   if(h==INVALID_HANDLE || CopyBuffer(h, 0, 0, 1, atrb) < 1) { atr20 = 0; }
   else { atr20 = atrb[0]; }
   if(h!=INVALID_HANDLE) IndicatorRelease(h);

   // 5-day % change
   double past = close[ChgDays];
   chg5d = (past != 0) ? (spot - past) / past * 100.0 : 0.0;
   return true;
}

//+------------------------------------------------------------------+
void ExportOnce()
{
   string names[];
   int n = StringSplit(BarometerSymbols, ',', names);
   int fh = FileOpen(OutFile, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(fh == INVALID_HANDLE) { Print("MRIS export: cannot open ", OutFile, " err=", GetLastError()); return; }
   FileWrite(fh, "symbol", "spot", "sma200", "atr20", "chg5d_pct", "data_status", "source_note");

   for(int i=0; i<n; i++)
   {
      string want = names[i]; StringTrimLeft(want); StringTrimRight(want);
      if(want == "") continue;
      string sym = ResolveSymbol(want);
      if(sym == "")
      {
         FileWrite(fh, want, "NA", "NA", "NA", "NA", "PENDING", "broker has no such symbol");
         continue;
      }
      double spot, sma200, atr20, chg5d;
      if(!ComputeMetrics(sym, spot, sma200, atr20, chg5d))
      {
         FileWrite(fh, want, "NA", "NA", "NA", "NA", "PENDING", "insufficient D1 history");
         continue;
      }
      int dg = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      FileWrite(fh, want,
                DoubleToString(spot, dg),
                DoubleToString(sma200, dg),
                DoubleToString(atr20, dg),
                DoubleToString(chg5d, 2),
                "OK",
                "MT5 " + sym + " D1");
   }
   FileClose(fh);
   Print("MRIS export: wrote ", OutFile, " (", n, " symbols) to Common\\Files");
}
//+------------------------------------------------------------------+
