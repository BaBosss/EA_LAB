//+------------------------------------------------------------------+
//| AccountSnapshot_Core.mqh - floating-risk snapshot core (ORDER-092)|
//| READ-ONLY: no trade function of any kind exists in this file.     |
//| Included by AccountSnapshotExporter.mq5 (production wrapper) and  |
//| ea_template\tests\AcctSnapshot_Test.mq5 (tester assert harness -  |
//| run_tests.ps1 copies this file beside the deployed tests).        |
//|                                                                   |
//| Writes EA_LAB_snapshot_<login>.csv to the COMMON Files folder.    |
//| One header + three row types sharing the 18 columns below:        |
//|   ACCOUNT - login, server time, currency, equity, balance,        |
//|             margin, free margin, margin level %, stop-out mode,   |
//|             stop-out level (magic columns blank)                  |
//|   MAGIC   - one row per magic WITH open positions or pendings     |
//|             (incl. magic 0 = manual trades): floating P&L         |
//|             (profit+swap), total open lots, open position count,  |
//|             oldest open position age (hours), pending count,      |
//|             ';'-joined symbols held                               |
//|   SYMBOL  - one row per symbol with open positions: floating P&L, |
//|             lots, position count (feeds the dashboard's cross-    |
//|             account XAU exposure aggregate)                       |
//| Atomicity: written to <name>.csv.tmp first, then FileMove with    |
//| FILE_REWRITE onto the final name so a collector never reads a     |
//| half-written file. If FileMove fails (rare - destination locked   |
//| by a reader), we fall back to a direct in-place rewrite and log   |
//| it; the 60s cycle makes any torn read self-healing.               |
//+------------------------------------------------------------------+

//--- per-magic aggregation (parallel arrays keep the MT4 twin identical)
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
   return "EA_LAB_snapshot_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + ".csv";
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
   list += ";" + sym;
}

//--- gather open positions + pending orders into the aggregation arrays
void Snap_Collect()
{
   ArrayResize(snap_magic, 0);   ArrayResize(snap_mFloat, 0);  ArrayResize(snap_mLots, 0);
   ArrayResize(snap_mPos, 0);    ArrayResize(snap_mOldest, 0); ArrayResize(snap_mPend, 0);
   ArrayResize(snap_mSymbols, 0);
   ArrayResize(snap_symbol, 0);  ArrayResize(snap_sFloat, 0);  ArrayResize(snap_sLots, 0);
   ArrayResize(snap_sPos, 0);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);              // read-only select
      if(tk == 0) continue;
      long     magic = PositionGetInteger(POSITION_MAGIC);
      double   fl    = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      double   lots  = PositionGetDouble(POSITION_VOLUME);
      datetime opent = (datetime)PositionGetInteger(POSITION_TIME);
      string   sym   = PositionGetString(POSITION_SYMBOL);

      int m = Snap_MagicIdx(magic);
      snap_mFloat[m] += fl;
      snap_mLots[m]  += lots;
      snap_mPos[m]++;
      if(snap_mOldest[m] == 0 || opent < snap_mOldest[m]) snap_mOldest[m] = opent;
      Snap_AddSymbolToList(snap_mSymbols[m], sym);

      int s = Snap_SymbolIdx(sym);
      snap_sFloat[s] += fl;
      snap_sLots[s]  += lots;
      snap_sPos[s]++;
   }
   for(int i = OrdersTotal() - 1; i >= 0; i--)      // pending orders
   {
      ulong tk = OrderGetTicket(i);                 // read-only select
      if(tk == 0) continue;
      long magic = OrderGetInteger(ORDER_MAGIC);
      int m = Snap_MagicIdx(magic);
      snap_mPend[m]++;
      Snap_AddSymbolToList(snap_mSymbols[m], OrderGetString(ORDER_SYMBOL));
   }
}

//--- write header + all rows to an already-open CSV handle
void Snap_WriteRows(const int fh)
{
   string login = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
   string stime = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
   string soMode = (AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE) == ACCOUNT_STOPOUT_MODE_PERCENT)
                   ? "PERCENT" : "MONEY";

   FileWrite(fh, "row_type", "login", "server_time", "currency",
                 "equity", "balance", "margin", "free_margin", "margin_level_pct",
                 "stopout_mode", "stopout_level",
                 "magic", "symbols", "float_pl", "open_lots", "open_positions",
                 "oldest_open_hours", "pending_orders");
   FileWrite(fh, "ACCOUNT", login, stime, AccountInfoString(ACCOUNT_CURRENCY),
                 DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2),
                 DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2),
                 DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN), 2),
                 DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 2),
                 DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_LEVEL), 1),
                 soMode,
                 DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_SO_SO), 1),
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

//--- write one snapshot CSV (atomic-ish: tmp then FileMove). fname = final name.
bool Snap_Export(const string fname)
{
   Snap_Collect();

   string tmp = fname + ".tmp";
   int fh = FileOpen(tmp, FILE_WRITE | FILE_CSV | FILE_COMMON | FILE_ANSI, ',');
   if(fh == INVALID_HANDLE)
   {
      PrintFormat("[SNAP] FileOpen(%s) failed err=%d", tmp, GetLastError());
      return false;
   }
   Snap_WriteRows(fh);
   FileClose(fh);

   // atomic-ish swap: collectors only ever see a complete file under the final name
   if(!FileMove(tmp, FILE_COMMON, fname, FILE_COMMON | FILE_REWRITE))
   {
      int err = GetLastError();
      FileDelete(tmp, FILE_COMMON);
      // fallback (noted per ORDER-092): direct in-place rewrite. Non-atomic, but the
      // 60s cycle means a torn read self-heals one cycle later; log makes it visible.
      PrintFormat("[SNAP] FileMove failed err=%d - falling back to in-place rewrite of %s", err, fname);
      int fh2 = FileOpen(fname, FILE_WRITE | FILE_CSV | FILE_COMMON | FILE_ANSI, ',');
      if(fh2 == INVALID_HANDLE)
      {
         PrintFormat("[SNAP] fallback FileOpen(%s) failed err=%d - skipped this cycle", fname, GetLastError());
         return false;
      }
      Snap_WriteRows(fh2);
      FileClose(fh2);
   }
   PrintFormat("[SNAP] %d magic row(s), %d symbol row(s) -> Common\\Files\\%s",
               ArraySize(snap_magic), ArraySize(snap_symbol), fname);
   return true;
}
