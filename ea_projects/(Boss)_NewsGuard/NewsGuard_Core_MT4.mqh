//+------------------------------------------------------------------+
//| NewsGuard_Core_MT4.mqh - MQL4 port of NewsGuard_Core.mqh          |
//| (ORDER-083B). Straight port of the validated ORDER-083 MT5 logic  |
//| for the no-SL fleet on MT4 141049900 (Zeus 7777, Kangaroo         |
//| 1112-1115). This file is a COPY - the MT5 canonical               |
//| NewsGuard_Core.mqh is untouched (order rule). Keep the two in     |
//| sync manually if the MT5 core ever changes.                       |
//|                                                                   |
//| Platform-mandated differences vs the MT5 core (everything else    |
//| is behavior-identical):                                           |
//|  1. Position API: OrdersTotal()/OrderSelect()/OrderClose() loop   |
//|     filtered by OrderMagicNumber(). Only OP_BUY/OP_SELL market    |
//|     orders are closed (= MT5 "positions"); pending orders are     |
//|     never touched, exactly like the MT5 version. Magic 0 (user's  |
//|     manual trades) and magics not in GuardConfig are NEVER        |
//|     touched: the loop matches the exact magic only.               |
//|  2. Policy B (BLOCK_NEW) is UNUSABLE on MT4: the guarded EAs are  |
//|     locked .ex4 with no GlobalVariable bridge. NG_ParseConfig     |
//|     accepts 'B' but prints a warning and downgrades it to N       |
//|     (NONE). All GV code is therefore removed from this port.      |
//|  3. No CTrade: OrderClose(ticket, lots, price, 50) with           |
//|     RefreshRates() + MarketInfo() bid/ask per order symbol.       |
//|  4. MQL4 string library differs (StringTrimLeft returns a copy,   |
//|     etc.) - local NG_Trim/NG_Upper helpers keep this file         |
//|     self-contained and warning-free.                              |
//|                                                                   |
//| Relevance rule (identical): an event affects a magic if event     |
//| Currency == USD (always), OR it matches the base/profit currency  |
//| of any symbol that magic currently holds open orders in.          |
//|                                                                   |
//| Fail-safe (identical): news file missing / unparsable / older     |
//| than StaleMaxHours -> guard INACTIVE: no closes, one throttled    |
//| Alert. The guard NEVER acts on stale data.                        |
//| No DLL, no WebRequest. Every action journal-logged [NEWSGUARD].   |
//|                                                                   |
//| Common\Files note (verified on this machine 2026-07-11): MT4      |
//| (%APPDATA%\MetaQuotes\Terminal\Common) is a junction onto the     |
//| same physical folder the MT5 terminals use                        |
//| (D:\MetaTraderData\Roaming\MetaQuotes\Terminal\Common) - a probe  |
//| file written via one path appears instantly via the other, and    |
//| EA_LAB_news_week.csv from the daily chain is already visible to   |
//| MT4. FILE_COMMON therefore reads the same news CSV on both        |
//| platforms with zero extra copying.                                |
//+------------------------------------------------------------------+
#ifndef BOSS_NEWSGUARD_CORE_MT4_MQH
#define BOSS_NEWSGUARD_CORE_MT4_MQH

#define NG_MAX_MAGICS          32
#define NG_MAX_EVENTS          512
#define NG_ALERT_THROTTLE_SEC  (4 * 3600)   // fail-safe Alert at most every 4h (real time)
#define NG_CLOSE_SLIPPAGE      50           // points (matches MT5 CTrade deviation)

#define NG_POLICY_NONE   0
#define NG_POLICY_CLOSE  1
#define NG_POLICY_BLOCK  2   // parse-time only on MT4: downgraded to NONE with a warning

// ---- settings (NG_Setup) --------------------------------------------------
int ng_preMin        = 30;   // window opens N min BEFORE the event
int ng_postMin       = 15;   // window closes N min AFTER the event
int ng_offsetHours   = 4;    // Bangkok = server + N hours (CSV times are Bkk)
int ng_staleMaxHours = 48;   // file older than this = stale -> fail-safe

// ---- per-magic guard table ------------------------------------------------
long ng_magic[NG_MAX_MAGICS];
int  ng_policy[NG_MAX_MAGICS];
bool ng_winActive[NG_MAX_MAGICS];   // in-window state (for ENTER/EXIT logging)
int  ng_windowActions[NG_MAX_MAGICS]; // closes/deletes in the current window
bool ng_churnAlerted[NG_MAX_MAGICS];
bool ng_seenFlat[NG_MAX_MAGICS];      // initial basket flattened; later actions are true re-entry
int  ng_count       = 0;
int  ng_bDowngraded = 0;            // how many B tokens were downgraded to N (MT4)

// ---- loaded news events (server time) --------------------------------------
datetime ng_evServer[NG_MAX_EVENTS];
string   ng_evCcy[NG_MAX_EVENTS];
string   ng_evTitle[NG_MAX_EVENTS];
int      ng_evCount = 0;

bool     ng_newsOK       = false;   // file found, fresh, parsed -> guard armed
double   ng_fileAgeHours = -1.0;    // last observed file age (local clock)
datetime ng_lastAlert    = 0;       // fail-safe Alert throttle (TimeLocal)
int      ng_notificationAttempts = 0; // observable in tester; SendNotification call count

void NG_ImportantAlert(const string msg)
{
   Print("[NEWSGUARD] ALERT: ", msg);
   Alert(msg);
   ResetLastError();
   ng_notificationAttempts++;
   if(!SendNotification(msg))
      PrintFormat("[NEWSGUARD] REMOTE ALERT unavailable/failed (err=%d): configure MetaQuotes ID in terminal Options > Notifications", GetLastError());
}

int NG_BkkOffsetFromClocks(const datetime serverNow, const datetime gmtNow,
                           const int fallback, bool &valid)
{
   int serverUtc = (int)MathRound((double)(serverNow - gmtNow) / 3600.0);
   valid = (serverNow > 0 && gmtNow > 0 && serverUtc >= -12 && serverUtc <= 14);
   return (valid ? 7 - serverUtc : fallback);
}

//+------------------------------------------------------------------+
void NG_Setup(const int preMin, const int postMin,
              const int serverToBkkOffsetHours, const int staleMaxHours)
{
   ng_preMin        = preMin;
   ng_postMin       = postMin;
   ng_offsetHours   = serverToBkkOffsetHours;
   ng_staleMaxHours = staleMaxHours;
}

string NG_PolicyName(const int p)
{
   if(p == NG_POLICY_CLOSE) return "CLOSE_ALL";
   if(p == NG_POLICY_BLOCK) return "BLOCK_NEW";
   return "NONE";
}

//+------------------------------------------------------------------+
//| MQL4-safe helpers (MQL4 StringTrimLeft/Right return a copy;      |
//| keep semantics explicit and identical to the MT5 core's intent). |
//+------------------------------------------------------------------+
string NG_Trim(const string s0)
{
   string s = s0;
   int a = 0, b = StringLen(s);
   while(a < b)
   {
      ushort c = StringGetCharacter(s, a);
      if(c == ' ' || c == '\t' || c == '\r' || c == '\n') a++; else break;
   }
   while(b > a)
   {
      ushort c = StringGetCharacter(s, b - 1);
      if(c == ' ' || c == '\t' || c == '\r' || c == '\n') b--; else break;
   }
   return StringSubstr(s, a, b - a);
}

string NG_Upper(const string s0)
{
   string s = s0;
   int n = StringLen(s);
   for(int i = 0; i < n; i++)
   {
      ushort c = StringGetCharacter(s, i);
      if(c >= 'a' && c <= 'z') StringSetCharacter(s, i, (ushort)(c - 32));
   }
   return s;
}

//+------------------------------------------------------------------+
//| Parse "magic:C;magic:B;magic:N". Returns entries accepted.       |
//| MT4 difference: policy B is downgraded to N with a warning       |
//| (locked .ex4 EAs cannot honor a BLOCK GlobalVariable).           |
//+------------------------------------------------------------------+
int NG_ParseConfig(const string cfg)
{
   ng_count       = 0;
   ng_bDowngraded = 0;
   string items[];
   int n = StringSplit(cfg, ';', items);
   for(int i = 0; i < n; i++)
   {
      string it = NG_Trim(items[i]);
      if(it == "") continue;
      int c = StringFind(it, ":");
      if(c <= 0)
      {
         PrintFormat("[NEWSGUARD] config token '%s' invalid (want magic:policy) - SKIPPED", it);
         continue;
      }
      long   m = (long)StringToInteger(StringSubstr(it, 0, c));
      string p = NG_Upper(NG_Trim(StringSubstr(it, c + 1)));
      int pol = -1;
      if(p == "C")      pol = NG_POLICY_CLOSE;
      else if(p == "B") pol = NG_POLICY_BLOCK;
      else if(p == "N") pol = NG_POLICY_NONE;
      if(m <= 0 || pol < 0)
      {
         PrintFormat("[NEWSGUARD] config token '%s' invalid (magic>0, policy C/B/N) - SKIPPED", it);
         continue;
      }
      if(pol == NG_POLICY_BLOCK)
      {
         // MT4: no GV bridge exists in the locked .ex4 EAs on this account -
         // a BLOCK GlobalVariable would be silently ignored. Never pretend to guard.
         PrintFormat("[NEWSGUARD] WARNING magic=%I64d: policy B (BLOCK_NEW) is NOT available on MT4 "
                     "(locked .ex4 EAs have no GV bridge) - treating as N (NONE). Use C for real protection.", m);
         pol = NG_POLICY_NONE;
         ng_bDowngraded++;
      }
      if(ng_count >= NG_MAX_MAGICS)
      {
         PrintFormat("[NEWSGUARD] too many magics (max %d) - remaining tokens ignored", NG_MAX_MAGICS);
         break;
      }
      ng_magic[ng_count]     = m;
      ng_policy[ng_count]    = pol;
      ng_winActive[ng_count] = false;
      ng_windowActions[ng_count] = 0;
      ng_churnAlerted[ng_count] = false;
      ng_seenFlat[ng_count] = false;
      PrintFormat("[NEWSGUARD] guard magic=%I64d policy=%s", m, NG_PolicyName(pol));
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
   string s = NG_Trim(s0);
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
                  fname, (common ? "Common\\Files" : "MQL4\\Files"));
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
      string ccy = NG_Upper(NG_Trim(f[1]));
      ng_evServer[ng_evCount] = bkk - (datetime)(ng_offsetHours * 3600);
      ng_evCcy[ng_evCount]    = ccy;
      ng_evTitle[ng_evCount]  = f[2];
      ng_evCount++;
   }
   FileClose(h);
   if(ng_evCount == 0)
   {
      PrintFormat("[NEWSGUARD] news file '%s' parsed ZERO valid events (%d row(s) skipped) - guard INACTIVE",
                  fname, skipped);
      return false;
   }
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
//| match a symbol this magic currently holds OPEN orders in.        |
//| (MT4: OrderSelect loop over MODE_TRADES; pendings hold no        |
//| exposure so only OP_BUY/OP_SELL count - same as MT5 positions.)  |
//+------------------------------------------------------------------+
bool NG_EventRelevant(const string ccy, const long magic)
{
   if(ccy == "USD") return true;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if((long)OrderMagicNumber() != magic) continue;
      if(OrderType() > OP_SELL) continue;
      if(NG_CcyMatchesSymbol(ccy, OrderSymbol())) return true;
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
//| Close every open order of a magic (all symbols). Journal-logs    |
//| each. ONLY the exact magic is touched - never magic 0 (manual    |
//| trades), never magics outside GuardConfig. Pendings untouched.   |
//+------------------------------------------------------------------+
int NG_CloseMagic(const long magic, const string reason)
{
   int closed = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if((long)OrderMagicNumber() != magic) continue;
      int type = OrderType();
      if(type > OP_SELL) continue;   // market orders only (MT5 core closes positions only)
      int    tk  = OrderTicket();
      string sym = OrderSymbol();
      double vol = OrderLots();
      RefreshRates();
      double px = (type == OP_BUY ? MarketInfo(sym, MODE_BID) : MarketInfo(sym, MODE_ASK));
      if(OrderClose(tk, vol, px, NG_CLOSE_SLIPPAGE, clrNONE))
      {
         PrintFormat("[NEWSGUARD] CLOSE_ALL magic=%I64d: closed ticket %d %s %.2f lot (%s)",
                     magic, tk, sym, vol, reason);
         closed++;
      }
      else
         PrintFormat("[NEWSGUARD] CLOSE_ALL magic=%I64d: close FAILED ticket %d err=%d - retry next pass",
                     magic, tk, GetLastError());
   }
   return closed;
}

int NG_DeletePendingMagic(const long magic, const string reason)
{
   int deleted = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if((long)OrderMagicNumber() != magic) continue;
      if(OrderType() <= OP_SELL) continue;
      int tk = OrderTicket();
      if(OrderDelete(tk, clrNONE))
      {
         PrintFormat("[NEWSGUARD] CLOSE_ALL magic=%I64d: deleted pending ticket %d %s (%s)",
                     magic, tk, OrderSymbol(), reason);
         deleted++;
      }
      else
         PrintFormat("[NEWSGUARD] CLOSE_ALL magic=%I64d: pending delete FAILED ticket %d err=%d - retry next pass",
                     magic, tk, GetLastError());
   }
   return deleted;
}

bool NG_HasMagicExposure(const long magic)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if((long)OrderMagicNumber() == magic) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Main watchdog pass. Call with the server clock (TimeCurrent).    |
//+------------------------------------------------------------------+
void NG_Tick(const datetime nowServer)
{
   if(!ng_newsOK)
   {
      // FAIL-SAFE: never act on missing/stale data. Warn (throttled), do
      // nothing else. (No BLOCK GVs exist on MT4 - nothing to release.)
      for(int i = 0; i < ng_count; i++)
         ng_winActive[i] = false;
      if(TimeLocal() - ng_lastAlert >= NG_ALERT_THROTTLE_SEC)
      {
         ng_lastAlert = TimeLocal();
         string msg = "NewsGuard INACTIVE: news file missing/stale - guarded EAs are UNPROTECTED";
         NG_ImportantAlert(msg);
      }
      return;
   }
   for(int i = 0; i < ng_count; i++)
   {
      int  ev     = NG_ActiveEventFor(nowServer, i);
      bool active = (ev >= 0);
      if(active && !ng_winActive[i])
      {
         ng_windowActions[i] = 0;
         ng_churnAlerted[i] = false;
         ng_seenFlat[i] = false;
         PrintFormat("[NEWSGUARD] window ENTER magic=%I64d policy=%s event='%s %s' @ server %s (-%d/+%d min)",
                     ng_magic[i], NG_PolicyName(ng_policy[i]), ng_evCcy[ev], ng_evTitle[ev],
                     TimeToString(ng_evServer[ev], TIME_DATE | TIME_MINUTES), ng_preMin, ng_postMin);
      }
      if(!active && ng_winActive[i])
         PrintFormat("[NEWSGUARD] window EXIT magic=%I64d", ng_magic[i]);
      ng_winActive[i] = active;

      if(ng_policy[i] == NG_POLICY_CLOSE)
      {
         // keep the magic flat for the whole window (owner EA re-opens after)
         if(active)
         {
            string why = ng_evCcy[ev] + " " + ng_evTitle[ev];
            int acted = NG_CloseMagic(ng_magic[i], why) + NG_DeletePendingMagic(ng_magic[i], why);
            if(ng_seenFlat[i]) ng_windowActions[i] += acted;
            if(!NG_HasMagicExposure(ng_magic[i])) ng_seenFlat[i] = true;
            if(ng_windowActions[i] > 5 && !ng_churnAlerted[i])
            {
               ng_churnAlerted[i] = true;
               NG_ImportantAlert(StringFormat("NewsGuard magic %I64d: owner EA re-entering during news window (%d close/delete actions)",
                                              ng_magic[i], ng_windowActions[i]));
            }
         }
      }
      // NG_POLICY_NONE (incl. downgraded B): never touched
   }
}

//+------------------------------------------------------------------+
//| Cleanup on EA removal. (MT4 port owns no GlobalVariables - kept  |
//| for API parity with the MT5 core so wrappers stay symmetric.)    |
//+------------------------------------------------------------------+
void NG_Deinit()
{
   // nothing to release on MT4 (no BLOCK GVs)
}

#endif // BOSS_NEWSGUARD_CORE_MT4_MQH
