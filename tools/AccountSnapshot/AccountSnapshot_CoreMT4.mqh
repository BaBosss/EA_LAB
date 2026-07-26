//+------------------------------------------------------------------+
//| AccountSnapshot_CoreMT4.mqh - floating-risk snapshot core (MT4)   |
//| Extracted verbatim from the tested AccountSnapshotExporter.mq4    |
//| (ORDER-092) so a combined monitor EA (OrdersExporterMT4) can emit |
//| the floating snapshot too without the operator attaching a second |
//| EA. Only the snapshot logic lives here - the standalone exporter  |
//| keeps its own OnInit/OnTimer. Include this and call Snapshot_Run  |
//| from your own timer. READ-ONLY: no trade function of any kind.    |
//| Writes EA_LAB_snapshot_<login>.csv to the COMMON Files folder,    |
//| same 18-column ACCOUNT/MAGIC/SYMBOL layout as the MT5 twin.       |
//+------------------------------------------------------------------+

//--- per-magic aggregation (parallel arrays, mirrors AccountSnapshot_Core.mqh)
long     snap_magic[];
double   snap_mFloat[];
double   snap_mLots[];
int      snap_mPos[];
datetime snap_mOldest[];
int      snap_mPend[];
string   snap_mSymbols[];
//--- per-symbol aggregation
string   snap_symbol[];
double   snap_sFloat[];
double   snap_sLots[];
int      snap_sPos[];

string Snap_FileName()
{
   return "EA_LAB_snapshot_" + IntegerToString(AccountNumber()) + ".csv";
}

int Snap_MagicIdx(const long magic)
{
   int n = ArraySize(snap_magic);
   for(int i = 0; i < n; i++) if(snap_magic[i] == magic) return i;
   ArrayResize(snap_magic,   n + 1); snap_magic[n]   = magic;
   ArrayResize(snap_mFloat,  n + 1); snap_mFloat[n]  = 0.0;
   ArrayResize(snap_mLots,   n + 1); snap_mLots[n]   = 0.0;
   ArrayResize(snap_mPos,    n + 1); snap_mPos[n]    = 0;
   ArrayResize(snap_mOldest, n + 1); snap_mOldest[n] = 0;
   ArrayResize(snap_mPend,   n + 1); snap_mPend[n]   = 0;
   ArrayResize(snap_mSymbols,n + 1); snap_mSymbols[n]= "";
   return n;
}

int Snap_SymbolIdx(const string sym)
{
   int n = ArraySize(snap_symbol);
   for(int i = 0; i < n; i++) if(snap_symbol[i] == sym) return i;
   ArrayResize(snap_symbol, n + 1); snap_symbol[n] = sym;
   ArrayResize(snap_sFloat, n + 1); snap_sFloat[n] = 0.0;
   ArrayResize(snap_sLots,  n + 1); snap_sLots[n]  = 0.0;
   ArrayResize(snap_sPos,   n + 1); snap_sPos[n]   = 0;
   return n;
}

void Snap_AddSymbolToList(string &list, const string sym)
{
   if(StringLen(list) == 0) { list = sym; return; }
   if(StringFind(";" + list + ";", ";" + sym + ";") >= 0) return;
   list = list + ";" + sym;
}

//--- gather open positions (type 0/1) + pendings (type 2..5) from the trade pool
void Snap_Collect()
{
   ArrayResize(snap_magic, 0);   ArrayResize(snap_mFloat, 0);  ArrayResize(snap_mLots, 0);
   ArrayResize(snap_mPos, 0);    ArrayResize(snap_mOldest, 0); ArrayResize(snap_mPend, 0);
   ArrayResize(snap_mSymbols, 0);
   ArrayResize(snap_symbol, 0);  ArrayResize(snap_sFloat, 0);  ArrayResize(snap_sLots, 0);
   ArrayResize(snap_sPos, 0);

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;   // read-only select
      int type = OrderType();
      long magic = OrderMagicNumber();
      string sym = OrderSymbol();
      int m = Snap_MagicIdx(magic);

      if(type == OP_BUY || type == OP_SELL)          // open market position
      {
         double fl   = OrderProfit() + OrderSwap() + OrderCommission();
         double lots = OrderLots();
         snap_mFloat[m] += fl;
         snap_mLots[m]  += lots;
         snap_mPos[m]++;
         if(snap_mOldest[m] == 0 || OrderOpenTime() < snap_mOldest[m]) snap_mOldest[m] = OrderOpenTime();
         Snap_AddSymbolToList(snap_mSymbols[m], sym);

         int s = Snap_SymbolIdx(sym);
         snap_sFloat[s] += fl;
         snap_sLots[s]  += lots;
         snap_sPos[s]++;
      }
      else if(type >= OP_BUYLIMIT && type <= OP_SELLSTOP)   // pending order
      {
         snap_mPend[m]++;
         Snap_AddSymbolToList(snap_mSymbols[m], sym);
      }
   }
}

//--- write header + all rows to an already-open CSV handle
void Snap_WriteRows(const int fh)
{
   string login = IntegerToString(AccountNumber());
   string stime = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
   string soMode = (AccountStopoutMode() == 0) ? "PERCENT" : "MONEY";
   double marginLevel = 0.0;
   if(AccountMargin() > 0) marginLevel = AccountEquity() / AccountMargin() * 100.0;

   FileWrite(fh, "row_type", "login", "server_time", "currency",
                 "equity", "balance", "margin", "free_margin", "margin_level_pct",
                 "stopout_mode", "stopout_level",
                 "magic", "symbols", "float_pl", "open_lots", "open_positions",
                 "oldest_open_hours", "pending_orders");
   FileWrite(fh, "ACCOUNT", login, stime, AccountCurrency(),
                 DoubleToString(AccountEquity(), 2),
                 DoubleToString(AccountBalance(), 2),
                 DoubleToString(AccountMargin(), 2),
                 DoubleToString(AccountFreeMargin(), 2),
                 DoubleToString(marginLevel, 1),
                 soMode,
                 DoubleToString(AccountStopoutLevel(), 1),
                 "", "", "", "", "", "", "");
   for(int m = 0; m < ArraySize(snap_magic); m++)
   {
      double ageH = 0.0;
      if(snap_mOldest[m] > 0) ageH = (double)(TimeCurrent() - snap_mOldest[m]) / 3600.0;
      FileWrite(fh, "MAGIC", login, stime, "", "", "", "", "", "", "", "",
                    IntegerToString(snap_magic[m]),
                    snap_mSymbols[m],
                    DoubleToString(snap_mFloat[m], 2),
                    DoubleToString(snap_mLots[m], 2),
                    IntegerToString(snap_mPos[m]),
                    DoubleToString(ageH, 1),
                    IntegerToString(snap_mPend[m]));
   }
   for(int s = 0; s < ArraySize(snap_symbol); s++)
   {
      FileWrite(fh, "SYMBOL", login, stime, "", "", "", "", "", "", "", "",
                    "",
                    snap_symbol[s],
                    DoubleToString(snap_sFloat[s], 2),
                    DoubleToString(snap_sLots[s], 2),
                    IntegerToString(snap_sPos[s]),
                    "", "");
   }
}

//--- write one snapshot CSV (atomic-ish: tmp then FileMove)
void Snapshot_Run()
{
   if(AccountNumber() == 0)   // terminal not authorized yet - a _0 file is garbage
   {
      Print("[SNAP] login=0 (not authorized yet) - snapshot skipped");
      return;
   }
   Snap_Collect();

   string fname = Snap_FileName();
   string tmp = fname + ".tmp";
   int fh = FileOpen(tmp, FILE_WRITE | FILE_CSV | FILE_COMMON | FILE_ANSI, ',');
   if(fh == INVALID_HANDLE)
   {
      Print("[SNAP] FileOpen(", tmp, ") failed err=", GetLastError());
      return;
   }
   Snap_WriteRows(fh);
   FileClose(fh);

   if(!FileMove(tmp, FILE_COMMON, fname, FILE_COMMON | FILE_REWRITE))
   {
      int err = GetLastError();
      FileDelete(tmp, FILE_COMMON);
      // fallback (noted per ORDER-092): direct in-place rewrite. Non-atomic, but the
      // cycle means a torn read self-heals one cycle later; log makes it visible.
      Print("[SNAP] FileMove failed err=", err, " - falling back to in-place rewrite of ", fname);
      int fh2 = FileOpen(fname, FILE_WRITE | FILE_CSV | FILE_COMMON | FILE_ANSI, ',');
      if(fh2 == INVALID_HANDLE)
      {
         Print("[SNAP] fallback FileOpen(", fname, ") failed err=", GetLastError(), " - skipped this cycle");
         return;
      }
      Snap_WriteRows(fh2);
      FileClose(fh2);
   }
   Print("[SNAP] ", ArraySize(snap_magic), " magic row(s), ", ArraySize(snap_symbol),
         " symbol row(s) -> Common\\Files\\", fname);
}
