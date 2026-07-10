//+------------------------------------------------------------------+
//| (Boss)_NewsGuard.mq5 - watchdog EA (ORDER-083).                  |
//| Attach ONE chart per ACCOUNT (any symbol/TF - it guards every    |
//| magic in GuardConfig across all symbols). Places NO trades of    |
//| its own; it only closes/blocks other EAs around high-impact news.|
//|                                                                  |
//| News source: EA_LAB_news_week.csv in Terminal\Common\Files,      |
//| copied there daily by scripts\daily_monitor.ps1 from             |
//| portfolio\news_week.csv (scripts\news_calendar.ps1, ForexFactory |
//| high-impact week feed, times in Bangkok UTC+7).                  |
//|                                                                  |
//| ServerToBkkOffsetHours: Bangkok = server + N hours.              |
//|   How to check: open Market Watch, compare its clock to a        |
//|   Bangkok clock; N = Bkk hour - server hour. Exness MT5 is       |
//|   usually UTC+3 (summer) -> N = 4; UTC+2 (winter) -> N = 5.      |
//|   Re-check after US/EU DST switches.                             |
//|                                                                  |
//| Fail-safe: file missing/stale(>StaleMaxHours) = guard INACTIVE   |
//| (no action, blocks released, throttled Alert). Timer-driven      |
//| (10 s) - chart ticks are irrelevant to a watchdog.               |
//+------------------------------------------------------------------+
#property copyright "EA_LAB"
#property version   "1.00"
#property description "Per-magic news watchdog: CLOSE_ALL / BLOCK_NEW / NONE around high-impact news"

#include "NewsGuard_Core.mqh"

input string GuardConfig            = "";                      // "magic:C;magic:B;magic:N"  C=CLOSE_ALL B=BLOCK_NEW N=NONE
input int    PreNewsMin             = 30;                      // window opens N min before the event
input int    PostNewsMin            = 15;                      // window closes N min after the event
input string NewsFile               = "EA_LAB_news_week.csv";  // CSV name (see header)
input bool   UseCommonFiles         = true;                    // true = Terminal\Common\Files (daily chain target)
input int    ServerToBkkOffsetHours = 4;                       // Bangkok = server + N h (Exness UTC+3 -> 4; see header)
input int    StaleMaxHours          = 48;                      // file older than this = fail-safe (no action + Alert)
input int    TimerSeconds           = 10;                      // watchdog poll period
input int    ReloadMinutes          = 15;                      // re-read the news file every N min

datetime g_ng_last_load = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   NG_Setup(PreNewsMin, PostNewsMin, ServerToBkkOffsetHours, StaleMaxHours);
   if(NG_ParseConfig(GuardConfig) <= 0)
   {
      Print("[NEWSGUARD] INIT FAILED: GuardConfig is empty/invalid. Format: \"12345:C;23456:B;34567:N\"");
      return INIT_PARAMETERS_INCORRECT;
   }
   NG_LoadNews(NewsFile, UseCommonFiles);   // fail-safe handles a missing file
   g_ng_last_load = TimeLocal();
   EventSetTimer(MathMax(1, TimerSeconds));
   PrintFormat("[NEWSGUARD] armed: %d magic(s), window -%d/+%d min, file '%s' (%s), Bkk = server %+d h",
               ng_count, PreNewsMin, PostNewsMin, NewsFile,
               (UseCommonFiles ? "Common\\Files" : "MQL5\\Files"), ServerToBkkOffsetHours);
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
void OnTimer()
{
   if(TimeLocal() - g_ng_last_load >= (datetime)(ReloadMinutes * 60))
   {
      NG_LoadNews(NewsFile, UseCommonFiles);
      g_ng_last_load = TimeLocal();
   }
   NG_Tick(TimeTradeServer());
   NG_ShowStatus();
}

//+------------------------------------------------------------------+
//| tiny chart status (journal stays the audit trail)                |
//+------------------------------------------------------------------+
void NG_ShowStatus()
{
   string s = "(Boss)_NewsGuard | " + (ng_newsOK
              ? StringFormat("ARMED  events=%d  file age %.1f h", ng_evCount, ng_fileAgeHours)
              : "FAIL-SAFE: news file missing/stale - NOT guarding");
   datetime now = TimeTradeServer();
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

void OnTick() {}   // watchdog is timer-driven; chart ticks unused
