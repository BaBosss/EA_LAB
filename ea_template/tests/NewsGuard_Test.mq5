//+------------------------------------------------------------------+
//| NewsGuard_Test.mq5 - assert harness for (Boss)_NewsGuard          |
//| (ORDER-083). Includes NewsGuard_Core.mqh (run_tests.ps1 copies it |
//| beside the deployed tests from ea_projects\(Boss)_NewsGuard\) and |
//| core Execution.mqh for the BLOCK_NEW GV bridge.                   |
//|                                                                   |
//| Flow (tester, XAUUSD H1 Model 1, a few days):                     |
//|  P0 first tick: unit asserts (time parse both formats, staleness  |
//|     decision, ccy relevance), write fake news CSV in the tester   |
//|     sandbox (2 events: irrelevant NZD @t0+1h, USD @t0+2h), open   |
//|     3 dummy BUYs with magics C/B/N, chassis-bridge asserts.       |
//|  P1 pre-window: NZD window must cause NO action; all 3 open,      |
//|     no GV.                                                        |
//|  P2 in-window: C closed, GV NEWSGUARD_BLOCK_<B>=1, B+N untouched. |
//|  P3 post-window: GV cleared, B+N untouched. Then delete the CSV   |
//|     -> fail-safe: reopened C position must survive, no GV, no     |
//|     action.                                                       |
//| Verdict "[PASS]/[FAIL] NewsGuard_Test" printed once at the end.   |
//+------------------------------------------------------------------+
#include "NewsGuard_Core.mqh"
#include "../core/Execution.mqh"

#define MAGIC_C   917101
#define MAGIC_B   917102
#define MAGIC_N   917103
#define NEWS_FILE "NG_TEST_news.csv"

int      g_fail  = 0;
int      g_phase = 0;   // 0=setup 1=pre-window 2=in-window 3=post/fail-safe 5=done
bool     g_nzdChecked = false, g_preChecked = false;
datetime g_t0 = 0, g_ev = 0, g_winA = 0, g_winB = 0, g_fsStart = 0;
CTrade   t_trade;

void TFail(const string m) { Print("[NG-TEST FAIL] ", m); g_fail++; }

int CountMagic(const long magic)
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) == magic) n++;
   }
   return n;
}

void CloseMagicLocal(const long magic)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      t_trade.PositionClose(tk);
   }
}

bool OpenWithMagic(const long magic)
{
   t_trade.SetExpertMagicNumber((ulong)magic);
   return t_trade.Buy(0.01, _Symbol, 0.0, 0.0, 0.0, "NGtest");
}

void WriteNewsFile()
{
   int h = FileOpen(NEWS_FILE, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE) { TFail("cannot write fake news CSV"); return; }
   int off = ng_offsetHours * 3600;
   FileWriteString(h, "\"BkkTime\",\"Currency\",\"Title\",\"TimeRaw\",\"Forecast\",\"Previous\"\r\n");
   // irrelevant event: NZD while we only hold XAUUSD (XAU/USD) -> must be ignored
   FileWriteString(h, "\"" + TimeToString(g_t0 + 3600 + off, TIME_DATE | TIME_MINUTES) +
                      "\",\"NZD\",\"TEST RBNZ Rate\",\"raw\",\"\",\"\"\r\n");
   // relevant event: USD (always relevant)
   FileWriteString(h, "\"" + TimeToString(g_ev + off, TIME_DATE | TIME_MINUTES) +
                      "\",\"USD\",\"TEST CPI, m/m\",\"raw\",\"0.3%\",\"0.2%\"\r\n");
   FileClose(h);
}

void Verdict()
{
   if(g_fail == 0) Print("[PASS] NewsGuard_Test: all asserts OK");
   else            PrintFormat("[FAIL] NewsGuard_Test: %d assert(s) failed", g_fail);
   g_phase = 5;
}

int OnInit() { return INIT_SUCCEEDED; }

void OnDeinit(const int reason)
{
   if(g_phase != 5) PrintFormat("[FAIL] NewsGuard_Test: incomplete run (phase %d)", g_phase);
}

void OnTick()
{
   if(g_phase == 5) return;
   datetime now = TimeCurrent();

   if(g_phase == 0)
   {
      // ---- environment: per-magic assertions need a hedging account -------
      if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE)
         != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      {
         TFail("tester account is NETTING - same-symbol multi-magic test impossible here");
         Verdict();
         return;
      }
      g_t0   = now;
      g_ev   = g_t0 + 7200;                       // USD event 2h in
      NG_Setup(30, 15, 4, 48);                    // pre 30 / post 15 / Bkk=server+4 / stale 48h
      g_winA = g_ev - 30 * 60;
      g_winB = g_ev + 15 * 60;

      // ---- unit asserts: config parse ---------------------------------
      if(NG_ParseConfig("917101:C; 917102:B ;917103:N;junk;0:C;1:X") != 3)
         TFail("ParseConfig: expected exactly 3 accepted entries");

      // ---- unit asserts: time parsing (both formats) -------------------
      if(NG_ParseTime("2026.07.10 20:30") != D'2026.07.10 20:30')
         TFail("ParseTime primary format failed");
      if(NG_ParseTime("7/7/2026 1:00:00 AM") != D'2026.07.07 01:00:00')
         TFail("ParseTime legacy AM failed");
      if(NG_ParseTime("7/7/2026 1:00:00 PM") != D'2026.07.07 13:00:00')
         TFail("ParseTime legacy PM failed");
      if(NG_ParseTime("12/31/2026 12:05:00 AM") != D'2026.12.31 00:05:00')
         TFail("ParseTime legacy 12AM failed");
      if(NG_ParseTime("") != 0 || NG_ParseTime("garbage") != 0)
         TFail("ParseTime must return 0 for junk");

      // ---- unit asserts: staleness decision ----------------------------
      if(!NG_IsStaleAge(49.0)) TFail("IsStaleAge(49h) must be stale (max 48)");
      if(NG_IsStaleAge(1.0))   TFail("IsStaleAge(1h) must be fresh");

      // ---- unit asserts: currency <-> symbol ----------------------------
      if(!NG_CcyMatchesSymbol("XAU", _Symbol) && _Symbol == "XAUUSD")
         TFail("CcyMatchesSymbol XAU/XAUUSD");
      if(NG_CcyMatchesSymbol("EUR", _Symbol) && _Symbol == "XAUUSD")
         TFail("CcyMatchesSymbol EUR must not match XAUUSD");

      // ---- fake news + dummy positions ---------------------------------
      WriteNewsFile();
      if(!NG_LoadNews(NEWS_FILE, false)) TFail("LoadNews on fresh fake CSV failed");
      if(ng_evCount != 2) TFail(StringFormat("expected 2 events, got %d", ng_evCount));

      if(!OpenWithMagic(MAGIC_C) || !OpenWithMagic(MAGIC_B) || !OpenWithMagic(MAGIC_N))
         TFail("could not open dummy positions");
      if(CountMagic(MAGIC_C) != 1 || CountMagic(MAGIC_B) != 1 || CountMagic(MAGIC_N) != 1)
         TFail("dummy position count wrong after open");

      // ---- unit asserts: relevance (needs open positions) ---------------
      if(!NG_EventRelevant("USD", MAGIC_C)) TFail("USD must always be relevant");
      if(NG_EventRelevant("NZD", MAGIC_C))  TFail("NZD must be irrelevant while holding XAUUSD only");

      // ---- chassis bridge asserts (core Execution.mqh, _0_Magic=990001) --
      Exec_Init();
      string bgv = "NEWSGUARD_BLOCK_" + IntegerToString(_0_Magic);
      GlobalVariableSet(bgv, 1.0);
      if(Exec_Open(1, 0.01, 0.0, 0.0, "bridge"))
         TFail("bridge: Exec_Open must be vetoed while GV=1");
      if(CountMagic(_0_Magic) != 0)
         TFail("bridge: position opened despite GV=1");
      if(Exec_PlacePending(1, false, 0.01, SymbolInfoDouble(_Symbol, SYMBOL_BID) * 0.5, 0.0, "bridge"))
         TFail("bridge: Exec_PlacePending must be vetoed while GV=1");
      GlobalVariableSet(bgv, 0.0);
      if(!Exec_Open(1, 0.01, 0.0, 0.0, "bridge"))
         TFail("bridge: Exec_Open must pass with GV=0 (inert)");
      GlobalVariableDel(bgv);
      if(!Exec_Open(1, 0.01, 0.0, 0.0, "bridge"))
         TFail("bridge: Exec_Open must pass with GV absent");
      if(CountMagic(_0_Magic) != 2)
         TFail("bridge: expected exactly 2 bridge positions");
      CloseMagicLocal(_0_Magic);

      g_phase = 1;
   }

   NG_Tick(now);   // the watchdog pass under test (every tick = generous 10s timer)
   string gvB = "NEWSGUARD_BLOCK_" + IntegerToString((long)MAGIC_B);

   if(g_phase == 1)
   {
      // inside the irrelevant NZD window: nothing may happen
      if(!g_nzdChecked && now >= g_t0 + 3600 && now <= g_t0 + 3600 + 600)
      {
         g_nzdChecked = true;
         if(CountMagic(MAGIC_C) != 1) TFail("NZD window: C position was touched (irrelevant event)");
         if(GlobalVariableCheck(gvB)) TFail("NZD window: GV set for irrelevant event");
      }
      // shortly before the USD window opens: still all quiet
      if(!g_preChecked && now >= g_winA - 300 && now < g_winA - 60)
      {
         g_preChecked = true;
         if(CountMagic(MAGIC_C) != 1 || CountMagic(MAGIC_B) != 1 || CountMagic(MAGIC_N) != 1)
            TFail("pre-window: dummy positions already touched");
         if(GlobalVariableCheck(gvB)) TFail("pre-window: GV set too early");
      }
      if(now >= g_winA + 120)
      {
         if(!g_nzdChecked) TFail("test plumbing: NZD checkpoint never reached");
         if(!g_preChecked) TFail("test plumbing: pre-window checkpoint never reached");
         // in-window asserts (2 min grace after window open, ticks are ~1/min)
         if(CountMagic(MAGIC_C) != 0)
            TFail("in-window: C-magic positions NOT closed");
         if(!GlobalVariableCheck(gvB) || GlobalVariableGet(gvB) < 0.5)
            TFail("in-window: BLOCK GV not set for B-magic");
         if(CountMagic(MAGIC_B) != 1) TFail("in-window: B-magic position was closed (must only block)");
         if(CountMagic(MAGIC_N) != 1) TFail("in-window: N-magic position was touched");
         g_phase = 2;
      }
   }
   else if(g_phase == 2)
   {
      if(now >= g_winB + 120)
      {
         if(GlobalVariableCheck(gvB)) TFail("post-window: BLOCK GV not cleared");
         if(CountMagic(MAGIC_B) != 1) TFail("post-window: B-magic position gone");
         if(CountMagic(MAGIC_N) != 1) TFail("post-window: N-magic position gone");
         // ---- fail-safe: missing file => guard INACTIVE, no action --------
         FileDelete(NEWS_FILE);
         if(NG_LoadNews(NEWS_FILE, false)) TFail("fail-safe: LoadNews on missing file must fail");
         if(ng_newsOK) TFail("fail-safe: ng_newsOK must be false after missing file");
         if(!OpenWithMagic(MAGIC_C)) TFail("fail-safe: could not reopen C position");
         g_fsStart = now;
         g_phase = 3;
      }
   }
   else if(g_phase == 3)
   {
      if(now >= g_fsStart + 900)
      {
         if(CountMagic(MAGIC_C) != 1)
            TFail("fail-safe: C position was closed with missing news data (must take NO action)");
         if(GlobalVariableCheck(gvB)) TFail("fail-safe: GV set with missing news data");
         CloseMagicLocal(MAGIC_C); CloseMagicLocal(MAGIC_B); CloseMagicLocal(MAGIC_N);
         Verdict();
      }
   }
}
