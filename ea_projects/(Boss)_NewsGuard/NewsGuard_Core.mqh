//+------------------------------------------------------------------+
//| NewsGuard_Core.mqh - (Boss)_NewsGuard watchdog logic (ORDER-083).|
//| Closes / blocks other EAs' trading around HIGH-impact news, one  |
//| policy per magic number. Pure module: the thin EA wrapper        |
//| ((Boss)_NewsGuard.mq5) owns inputs + timer; the test harness     |
//| (ea_template\tests\NewsGuard_Test.mq5) includes this directly    |
//| (run_tests.ps1 copies it beside the deployed tests).             |
//|                                                                  |
//| Policies:                                                        |
//|   C = CLOSE_ALL  close every position of that magic (all         |
//|                  symbols) for the whole news window; the owner   |
//|                  EA re-opens after the window on its own signal. |
//|   B = BLOCK_NEW  GlobalVariable NEWSGUARD_BLOCK_<magic> = 1      |
//|                  during the window; Boss V2 chassis              |
//|                  (core\Execution.mqh bridge, 2026-07-10+) skips  |
//|                  NEW orders while it exists - management/exits   |
//|                  untouched. Locked/non-chassis EAs IGNORE the GV.|
//|   N = NONE       explicitly unguarded (documents the decision).  |
//|                                                                  |
//| Relevance: an event affects a magic if event Currency == USD     |
//| (always), OR it matches the base/profit currency of any symbol   |
//| that magic currently holds positions in.                         |
//|                                                                  |
//| Fail-safe: news file missing / unparsable / older than           |
//| StaleMaxHours -> guard INACTIVE: no closes, every GV we own is   |
//| cleared (never leave an EA permanently blocked), one throttled   |
//| Alert. The guard NEVER acts on stale data.                       |
//| No DLL, no WebRequest. Every action is journal-logged.           |
//+------------------------------------------------------------------+
#ifndef BOSS_NEWSGUARD_CORE_MQH
#define BOSS_NEWSGUARD_CORE_MQH
#include <Trade/Trade.mqh>

#define NG_MAX_MAGICS          32
#define NG_MAX_EVENTS          512
#define NG_GV_PREFIX           "NEWSGUARD_BLOCK_"
#define NG_ALERT_THROTTLE_SEC  (4 * 3600)   // fail-safe Alert at most every 4h (real time)

#define NG_POLICY_NONE   0
#define NG_POLICY_CLOSE  1
#define NG_POLICY_BLOCK  2

// ---- settings (NG_Setup) --------------------------------------------------
int ng_preMin        = 30;   // window opens N min BEFORE the event
int ng_postMin       = 15;   // window closes N min AFTER the event
int ng_offsetHours   = 4;    // Bangkok = server + N hours (CSV times are Bkk)
int ng_staleMaxHours = 48;   // file older than this = stale -> fail-safe

// ---- per-magic guard table ------------------------------------------------
long ng_magic[NG_MAX_MAGICS];
int  ng_policy[NG_MAX_MAGICS];
bool ng_winActive[NG_MAX_MAGICS];   // in-window state (for ENTER/EXIT logging)
bool ng_blockSet[NG_MAX_MAGICS];    // we currently own a BLOCK GV for this magic
int  ng_count = 0;

// ---- loaded news events (server time) --------------------------------------
datetime ng_evServer[NG_MAX_EVENTS];
string   ng_evCcy[NG_MAX_EVENTS];
string   ng_evTitle[NG_MAX_EVENTS];
int      ng_evCount = 0;

bool     ng_newsOK       = false;   // file found, fresh, parsed -> guard armed
double   ng_fileAgeHours = -1.0;    // last observed file age (local clock)
datetime ng_lastAlert    = 0;       // fail-safe Alert throttle (TimeLocal)

CTrade ng_trade;

//+------------------------------------------------------------------+
void NG_Setup(const int preMin, const int postMin,
              const int serverToBkkOffsetHours, const int staleMaxHours)
{
   ng_preMin        = preMin;
   ng_postMin       = postMin;
   ng_offsetHours   = serverToBkkOffsetHours;
   ng_staleMaxHours = staleMaxHours;
   ng_trade.SetAsyncMode(false);
   ng_trade.SetDeviationInPoints(50);
   ng_trade.LogLevel(LOG_LEVEL_ERRORS);
}

string NG_GVName(const long magic) { return NG_GV_PREFIX + IntegerToString(magic); }

string NG_PolicyName(const int p)
{
   if(p == NG_POLICY_CLOSE) return "CLOSE_ALL";
   if(p == NG_POLICY_BLOCK) return "BLOCK_NEW";
   return "NONE";
}

//+------------------------------------------------------------------+
//| Parse "magic:C;magic:B;magic:N". Returns entries accepted.       |
//+------------------------------------------------------------------+
int NG_ParseConfig(const string cfg)
{
   ng_count = 0;
   string items[];
   int n = StringSplit(cfg, ';', items);
   for(int i = 0; i < n; i++)
   {
      string it = items[i];
      StringTrimLeft(it); StringTrimRight(it);
      if(it == "") continue;
      int c = StringFind(it, ":");
      if(c <= 0)
      {
         PrintFormat("[NEWSGUARD] config token '%s' invalid (want magic:policy) - SKIPPED", it);
         continue;
      }
      long   m = StringToInteger(StringSubstr(it, 0, c));
      string p = StringSubstr(it, c + 1);
      StringTrimLeft(p); StringTrimRight(p);
      StringToUpper(p);
      int pol = -1;
      if(p == "C")      pol = NG_POLICY_CLOSE;
      else if(p == "B") pol = NG_POLICY_BLOCK;
      else if(p == "N") pol = NG_POLICY_NONE;
      if(m <= 0 || pol < 0)
      {
         PrintFormat("[NEWSGUARD] config token '%s' invalid (magic>0, policy C/B/N) - SKIPPED", it);
         continue;
      }
      if(ng_count >= NG_MAX_MAGICS)
      {
         PrintFormat("[NEWSGUARD] too many magics (max %d) - remaining tokens ignored", NG_MAX_MAGICS);
         break;
      }
      ng_magic[ng_count]     = m;
      ng_policy[ng_count]    = pol;
      ng_winActive[ng_count] = false;
      ng_blockSet[ng_count]  = false;
      PrintFormat("[NEWSGUARD] guard magic=%I64d policy=%s", m, NG_PolicyName(pol));
      if(pol == NG_POLICY_BLOCK)
         PrintFormat("[NEWSGUARD] NOTE magic=%I64d: BLOCK_NEW only works for Boss V2 chassis EAs "
                     "(Execution.mqh GV bridge, 2026-07-10+). A locked/non-chassis EA ignores the GV - "
                     "use policy C for those.", m);
      ng_count++;
   }
   if(ng_count == 0) Print("[NEWSGUARD] config empty/invalid - nothing to guard");
   return ng_count;
}

//+------------------------------------------------------------------+
//| Staleness decision (age in hours, local clock). Unknown age (<0) |
//| = file exists but no mtime -> treated as fresh (fail-open on the |
//| metadata only; a truly missing file is caught before this).      |
//+------------------------------------------------------------------+
bool NG_IsStaleAge(const double ageHours)
{
   return (ng_staleMaxHours > 0 && ageHours > (double)ng_staleMaxHours);
}

//+------------------------------------------------------------------+
//| CSV field split with quote handling ("a","b, c","d").            |
//+------------------------------------------------------------------+
int NG_SplitCsv(const string line, string &fields[])
{
   int  cap = ArraySize(fields);
   int  n   = 0;
   bool inQ = false;
   string cur = "";
   int len = StringLen(line);
   for(int i = 0; i < len; i++)
   {
      ushort ch = StringGetCharacter(line, i);
      if(ch == '"') { inQ = !inQ; continue; }
      if(ch == ',' && !inQ)
      {
         if(n < cap) fields[n] = cur;
         n++; cur = "";
         continue;
      }
      cur += ShortToString(ch);
   }
   if(n < cap) fields[n] = cur;
   n++;
   return n;
}

//+------------------------------------------------------------------+
//| Parse a BkkTime string. Primary format (news_calendar.ps1 since  |
//| ORDER-083): "yyyy.MM.dd HH:mm" -> StringToTime direct. Fallback: |
//| legacy US-culture "M/d/yyyy h:mm:ss AM|PM" (old CSVs).           |
//| Returns 0 when unparsable.                                       |
//+------------------------------------------------------------------+
datetime NG_ParseTime(const string s0)
{
   string s = s0;
   StringTrimLeft(s); StringTrimRight(s);
   if(s == "") return 0;
   if(StringFind(s, "/") < 0)
   {
      datetime t = StringToTime(s);
      // StringToTime returns today's date for garbage - require the string to
      // actually carry a date (a '.' before the first space).
      int sp = StringFind(s, " ");
      if(sp < 0 || StringFind(StringSubstr(s, 0, sp), ".") < 0) return 0;
      return (t > 0 ? t : 0);
   }
   // legacy "M/d/yyyy h:mm:ss AM/PM"
   bool pm = (StringFind(s, "PM") >= 0);
   bool am = (StringFind(s, "AM") >= 0);
   string parts[];
   if(StringSplit(s, ' ', parts) < 2) return 0;
   string dp[];
   if(StringSplit(parts[0], '/', dp) != 3) return 0;
   string tp[];
   int nt = StringSplit(parts[1], ':', tp);
   if(nt < 2) return 0;
   MqlDateTime dt;
   ZeroMemory(dt);
   dt.mon  = (int)StringToInteger(dp[0]);
   dt.day  = (int)StringToInteger(dp[1]);
   dt.year = (int)StringToInteger(dp[2]);
   dt.hour = (int)StringToInteger(tp[0]);
   dt.min  = (int)StringToInteger(tp[1]);
   dt.sec  = (nt > 2 ? (int)StringToInteger(tp[2]) : 0);
   if(pm && dt.hour < 12) dt.hour += 12;
   if(am && dt.hour == 12) dt.hour = 0;
   if(dt.year < 2000 || dt.mon < 1 || dt.mon > 12 || dt.day < 1 || dt.day > 31) return 0;
   return StructToTime(dt);
}

//+------------------------------------------------------------------+
//| Load + validate the news CSV. Columns: BkkTime,Currency,Title,   |
//| TimeRaw,Forecast,Previous (header skipped). Sets ng_newsOK.      |
//+------------------------------------------------------------------+
bool NG_LoadNews(const string fname, const bool common)
{
   ng_evCount      = 0;
   ng_newsOK       = false;
   ng_fileAgeHours = -1.0;
   int cflag = (common ? FILE_COMMON : 0);
   if(!FileIsExist(fname, cflag))
   {
      PrintFormat("[NEWSGUARD] news file '%s' NOT FOUND (%s) - guard INACTIVE",
                  fname, (common ? "Common\\Files" : "MQL5\\Files"));
      return false;
   }
   long mod = FileGetInteger(fname, FILE_MODIFY_DATE, common);
   if(mod > 0) ng_fileAgeHours = (double)(TimeLocal() - (datetime)mod) / 3600.0;
   if(NG_IsStaleAge(ng_fileAgeHours))
   {
      PrintFormat("[NEWSGUARD] news file '%s' STALE (%.1f h old > %d h max) - guard INACTIVE",
                  fname, ng_fileAgeHours, ng_staleMaxHours);
      return false;
   }
   int h = FileOpen(fname, FILE_READ | FILE_TXT | FILE_ANSI | cflag, 0, CP_UTF8);
   if(h == INVALID_HANDLE)
   {
      PrintFormat("[NEWSGUARD] news file '%s' open failed (err %d) - guard INACTIVE",
                  fname, GetLastError());
      return false;
   }
   int line = 0, skipped = 0;
   while(!FileIsEnding(h) && ng_evCount < NG_MAX_EVENTS)
   {
      string l = FileReadString(h);
      line++;
      if(line == 1) continue;                 // header
      if(StringLen(l) < 5) continue;          // blank tail
      string f[8];
      if(NG_SplitCsv(l, f) < 3) { skipped++; continue; }
      datetime bkk = NG_ParseTime(f[0]);
      if(bkk <= 0) { skipped++; continue; }   // feed rows without a parseable time
      string ccy = f[1];
      StringTrimLeft(ccy); StringTrimRight(ccy);
      StringToUpper(ccy);
      ng_evServer[ng_evCount] = bkk - (datetime)(ng_offsetHours * 3600);
      ng_evCcy[ng_evCount]    = ccy;
      ng_evTitle[ng_evCount]  = f[2];
      ng_evCount++;
   }
   FileClose(h);
   ng_newsOK = true;
   PrintFormat("[NEWSGUARD] news loaded: %d event(s), %d row(s) skipped, file age %.1f h, Bkk = server %+d h",
               ng_evCount, skipped, ng_fileAgeHours, ng_offsetHours);
   return true;
}

//+------------------------------------------------------------------+
//| Does event currency touch this symbol? base/profit ccy match,    |
//| plus a symbol-name substring fallback: some brokers report e.g.  |
//| base="Gold" for XAUUSD, and symbols missing from Market Watch    |
//| have no info at all. Fallback errs protective (match = guard).   |
//+------------------------------------------------------------------+
bool NG_CcyMatchesSymbol(const string ccy, const string sym)
{
   if(ccy == SymbolInfoString(sym, SYMBOL_CURRENCY_BASE))   return true;
   if(ccy == SymbolInfoString(sym, SYMBOL_CURRENCY_PROFIT)) return true;
   return (StringFind(sym, ccy) >= 0);
}

//+------------------------------------------------------------------+
//| Event relevance per spec: USD always; otherwise the currency must|
//| match a symbol this magic currently holds positions in.          |
//+------------------------------------------------------------------+
bool NG_EventRelevant(const string ccy, const long magic)
{
   if(ccy == "USD") return true;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(NG_CcyMatchesSymbol(ccy, PositionGetString(POSITION_SYMBOL))) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Index of a relevant event whose window contains nowServer, else  |
//| -1. Window = [event - PreNewsMin, event + PostNewsMin].          |
//+------------------------------------------------------------------+
int NG_ActiveEventFor(const datetime nowServer, const int idx)
{
   for(int e = 0; e < ng_evCount; e++)
   {
      if(nowServer < ng_evServer[e] - (datetime)(ng_preMin * 60))  continue;
      if(nowServer > ng_evServer[e] + (datetime)(ng_postMin * 60)) continue;
      if(NG_EventRelevant(ng_evCcy[e], ng_magic[idx])) return e;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Close every position of a magic (all symbols). Journal-logs each.|
//+------------------------------------------------------------------+
int NG_CloseMagic(const long magic, const string reason)
{
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      string sym = PositionGetString(POSITION_SYMBOL);
      double vol = PositionGetDouble(POSITION_VOLUME);
      if(ng_trade.PositionClose(tk))
      {
         PrintFormat("[NEWSGUARD] CLOSE_ALL magic=%I64d: closed ticket %I64u %s %.2f lot (%s)",
                     magic, tk, sym, vol, reason);
         closed++;
      }
      else
         PrintFormat("[NEWSGUARD] CLOSE_ALL magic=%I64d: close FAILED ticket %I64u retcode=%d - retry next pass",
                     magic, tk, (int)ng_trade.ResultRetcode());
   }
   return closed;
}

//+------------------------------------------------------------------+
void NG_ClearBlock(const int idx, const string why)
{
   string gv = NG_GVName(ng_magic[idx]);
   if(GlobalVariableCheck(gv)) GlobalVariableDel(gv);
   ng_blockSet[idx] = false;
   PrintFormat("[NEWSGUARD] BLOCK_NEW CLEARED %s (%s)", gv, why);
}

//+------------------------------------------------------------------+
//| Main watchdog pass. Call from OnTimer with the server clock.     |
//+------------------------------------------------------------------+
void NG_Tick(const datetime nowServer)
{
   if(!ng_newsOK)
   {
      // FAIL-SAFE: never act on missing/stale data. Release any block we
      // own so no EA stays frozen, warn (throttled), do nothing else.
      for(int i = 0; i < ng_count; i++)
      {
         if(ng_blockSet[i]) NG_ClearBlock(i, "fail-safe: news data unavailable");
         ng_winActive[i] = false;
      }
      if(TimeLocal() - ng_lastAlert >= NG_ALERT_THROTTLE_SEC)
      {
         ng_lastAlert = TimeLocal();
         string msg = "NewsGuard INACTIVE: news file missing/stale - guarded EAs are UNPROTECTED";
         Print("[NEWSGUARD] ALERT: ", msg);
         Alert(msg);
      }
      return;
   }
   for(int i = 0; i < ng_count; i++)
   {
      int  ev     = NG_ActiveEventFor(nowServer, i);
      bool active = (ev >= 0);
      if(active && !ng_winActive[i])
         PrintFormat("[NEWSGUARD] window ENTER magic=%I64d policy=%s event='%s %s' @ server %s (-%d/+%d min)",
                     ng_magic[i], NG_PolicyName(ng_policy[i]), ng_evCcy[ev], ng_evTitle[ev],
                     TimeToString(ng_evServer[ev], TIME_DATE | TIME_MINUTES), ng_preMin, ng_postMin);
      if(!active && ng_winActive[i])
         PrintFormat("[NEWSGUARD] window EXIT magic=%I64d", ng_magic[i]);
      ng_winActive[i] = active;

      if(ng_policy[i] == NG_POLICY_CLOSE)
      {
         // keep the magic flat for the whole window (owner EA re-opens after)
         if(active) NG_CloseMagic(ng_magic[i], ng_evCcy[ev] + " " + ng_evTitle[ev]);
      }
      else if(ng_policy[i] == NG_POLICY_BLOCK)
      {
         if(active && !ng_blockSet[i])
         {
            string gv = NG_GVName(ng_magic[i]);
            GlobalVariableSet(gv, 1.0);
            ng_blockSet[i] = true;
            PrintFormat("[NEWSGUARD] BLOCK_NEW SET %s=1 (event '%s %s')", gv, ng_evCcy[ev], ng_evTitle[ev]);
         }
         if(!active && ng_blockSet[i]) NG_ClearBlock(i, "window ended");
      }
      // NG_POLICY_NONE: never touched
   }
}

//+------------------------------------------------------------------+
//| Cleanup on EA removal: never leave a stuck block behind.         |
//+------------------------------------------------------------------+
void NG_Deinit()
{
   for(int i = 0; i < ng_count; i++)
   {
      string gv = NG_GVName(ng_magic[i]);
      if(GlobalVariableCheck(gv))
      {
         GlobalVariableDel(gv);
         PrintFormat("[NEWSGUARD] deinit: removed %s", gv);
      }
      ng_blockSet[i] = false;
   }
}

#endif // BOSS_NEWSGUARD_CORE_MQH
