//+------------------------------------------------------------------+
//| (Boss)_NewsGuard_MT4.mq4 - watchdog EA, MQL4 port (ORDER-083B).  |
//| Attach ONE chart per ACCOUNT (any symbol/TF - it guards every    |
//| magic in GuardConfig across all symbols). Places NO trades of    |
//| its own; it only closes other EAs' orders around high-impact     |
//| news. Built for the no-SL fleet on MT4 141049900 (Zeus 7777,     |
//| Kangaroo 1112-1115).                                             |
//|                                                                  |
//| News source: EA_LAB_news_week.csv in Terminal\Common\Files -     |
//| the SAME physical folder the MT5 terminals read (verified        |
//| 2026-07-11: %APPDATA%\MetaQuotes\Terminal\Common is a junction   |
//| onto D:\MetaTraderData\...\Common). daily_monitor.ps1 already    |
//| publishes it there; no extra copy step needed for MT4.           |
//|                                                                  |
//| MT4 differences vs the MT5 (Boss)_NewsGuard (see core header):   |
//|  - Policy B (BLOCK_NEW) unusable (locked .ex4, no GV bridge):    |
//|    parse warns + treats B as N. Use C for real protection.       |
//|  - Timer: OnTimer works live, but the MT4 tester never fires it  |
//|    -> OnTick fallback throttled to TimerSeconds (<=10 s).        |
//|  - Clock: MQL4 has no TimeTradeServer() -> TimeCurrent() (last   |
//|    known server tick time).                                      |
//|                                                                  |
//| ServerToBkkOffsetHours: Bangkok = server + N hours.              |
//|   How to check: open Market Watch, compare its clock to a        |
//|   Bangkok clock; N = Bkk hour - server hour. Exness is usually   |
//|   UTC+3 (summer) -> N = 4; UTC+2 (winter) -> N = 5.              |
//|   Re-check after US/EU DST switches.                             |
//|                                                                  |
//| Fail-safe: file missing/stale(>StaleMaxHours) = guard INACTIVE   |
//| (no action, throttled Alert). Every action logged [NEWSGUARD].   |
//+------------------------------------------------------------------+
#property copyright "EA_LAB"
#property version   "1.00"
#property description "Per-magic news watchdog (MT4): CLOSE_ALL / NONE around high-impact news (B downgrades to N)"
#property strict

#include "NewsGuard_Core_MT4.mqh"

input string GuardConfig            = "";                      // "magic:C;magic:B;magic:N"  C=CLOSE_ALL B->N on MT4 N=NONE
input int    PreNewsMin             = 30;                      // window opens N min before the event
input int    PostNewsMin            = 15;                      // window closes N min after the event
input string NewsFile               = "EA_LAB_news_week.csv";  // CSV name (see header)
input bool   UseCommonFiles         = true;                    // true = Terminal\Common\Files (daily chain target)
input int    ServerToBkkOffsetHours = 4;                       // Bangkok = server + N h (Exness UTC+3 -> 4; see header)
input int    StaleMaxHours          = 48;                      // file older than this = fail-safe (no action + Alert)
input int    TimerSeconds           = 10;                      // watchdog poll period (live timer + tick throttle)
input int    ReloadMinutes          = 15;                      // re-read the news file every N min

datetime g_ng_last_load = 0;
datetime g_ng_last_pass = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   NG_Setup(PreNewsMin, PostNewsMin, ServerToBkkOffsetHours, StaleMaxHours);
   if(NG_ParseConfig(GuardConfig) <= 0)
   {
      Print("[NEWSGUARD] INIT FAILED: GuardConfig is empty/invalid. Format: \"7777:C;1112:C;1113:N\"");
      return INIT_PARAMETERS_INCORRECT;
   }
   NG_LoadNews(NewsFile, UseCommonFiles);   // fail-safe handles a missing file
   g_ng_last_load = TimeLocal();
   EventSetTimer(MathMax(1, TimerSeconds)); // live only; tester falls back to OnTick throttle
   PrintFormat("[NEWSGUARD] armed (MT4): %d magic(s), window -%d/+%d min, file '%s' (%s), Bkk = server %+d h",
               ng_count, PreNewsMin, PostNewsMin, NewsFile,
               (UseCommonFiles ? "Common\\Files" : "MQL4\\Files"), ServerToBkkOffsetHours);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   NG_Deinit();
   Comment("");
}

//+------------------------------------------------------------------+
//| One watchdog pass. force=true (timer) skips the tick throttle.   |
//+------------------------------------------------------------------+
void NG_Pass(const bool force)
{
   datetime now = TimeCurrent();
   if(!force && now - g_ng_last_pass < (datetime)MathMax(1, TimerSeconds)) return;
   g_ng_last_pass = now;
   if(TimeLocal() - g_ng_last_load >= (datetime)(ReloadMinutes * 60))
   {
      NG_LoadNews(NewsFile, UseCommonFiles);
      g_ng_last_load = TimeLocal();
   }
   NG_Tick(now);
   NG_ShowStatus();
}

void OnTimer() { NG_Pass(true);  }   // live: fires every TimerSeconds
void OnTick()  { NG_Pass(false); }   // tester (no OnTimer) + live belt-and-braces

//+------------------------------------------------------------------+
//| tiny chart status (journal stays the audit trail)                |
//+------------------------------------------------------------------+
void NG_ShowStatus()
{
   string s = "(Boss)_NewsGuard_MT4 | " + (ng_newsOK
              ? StringFormat("ARMED  events=%d  file age %.1f h", ng_evCount, ng_fileAgeHours)
              : "FAIL-SAFE: news file missing/stale - NOT guarding");
   datetime now = TimeCurrent();
   datetime nextEv = 0;
   for(int e = 0; e < ng_evCount; e++)
      if(ng_evServer[e] + (datetime)(ng_postMin * 60) >= now &&
         (nextEv == 0 || ng_evServer[e] < nextEv))
         nextEv = ng_evServer[e];
   if(nextEv > 0) s += "\nnext event (server): " + TimeToString(nextEv, TIME_DATE | TIME_MINUTES);
   for(int i = 0; i < ng_count; i++)
      if(ng_winActive[i])
         s += StringFormat("\nIN WINDOW magic=%I64d (%s)", ng_magic[i], NG_PolicyName(ng_policy[i]));
   Comment(s);
}
