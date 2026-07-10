//+------------------------------------------------------------------+
//| NewsGuard_Test_MT4.mq4 - assert harness for (Boss)_NewsGuard_MT4  |
//| (ORDER-083B). MQL4 port of ea_template\tests\NewsGuard_Test.mq5   |
//| (same phase pattern). Includes NewsGuard_Core_MT4.mqh from the    |
//| same directory (run_mt4_tests.ps1 deploys both side by side).     |
//|                                                                   |
//| Flow (MT4 tester, XAUUSD M5 Model 0, one day):                    |
//|  P0 first tick: unit asserts (time parse both formats, staleness  |
//|     decision, ccy relevance, ParseConfig incl. the MT4 B->N       |
//|     downgrade), write fake news CSV in the tester sandbox         |
//|     (2 events: irrelevant NZD @t0+1h, USD @t0+2h), open 4 dummy   |
//|     BUYs with magics C/B/N/X (X = NOT in GuardConfig).            |
//|  P1 NZD window: irrelevant event -> NO action. Pre-USD-window:    |
//|     still all quiet. In-window: C closed; B (downgraded to N),    |
//|     N and unlisted X all untouched.                               |
//|  P2 post-window: B/N/X still open. Then delete the CSV ->         |
//|     fail-safe: reopened C order must survive, no action, Alert    |
//|     only (Alert presence checked by the runner via journal grep). |
//|  P3 fail-safe soak 15 min -> final asserts -> verdict.            |
//| Verdict "[PASS]/[FAIL] NewsGuard_Test_MT4" printed once at end.   |
//+------------------------------------------------------------------+
#property copyright "EA_LAB"
#property version   "1.00"
#property strict

#include "NewsGuard_Core_MT4.mqh"

#define MAGIC_C   917201
#define MAGIC_B   917202
#define MAGIC_N   917203
#define MAGIC_X   917204   // NOT in GuardConfig - must never be touched
#define NEWS_FILE "NG4_TEST_news.csv"

int      g_fail  = 0;
int      g_phase = 0;   // 0=setup 1=pre-window 2=in-window done 3=fail-safe 5=done
bool     g_nzdChecked = false, g_preChecked = false;
datetime g_t0 = 0, g_ev = 0, g_winA = 0, g_winB = 0, g_fsStart = 0;

void TFail(const string m) { Print("[NG-TEST FAIL] ", m); g_fail++; }

int CountMagic(const long magic)
{
   int n = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderType() > OP_SELL) continue;
      if((long)OrderMagicNumber() == magic) n++;
   }
   return n;
}

void CloseMagicLocal(const long magic)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if((long)OrderMagicNumber() != magic) continue;
      int type = OrderType();
      if(type > OP_SELL) continue;
      RefreshRates();
      double px = (type == OP_BUY ? MarketInfo(OrderSymbol(), MODE_BID)
                                  : MarketInfo(OrderSymbol(), MODE_ASK));
      if(!OrderClose(OrderTicket(), OrderLots(), px, 50, clrNONE))
         PrintFormat("[NG-TEST] local close failed ticket %d err=%d", OrderTicket(), GetLastError());
   }
}

bool OpenWithMagic(const long magic)
{
   RefreshRates();
   double lot = MarketInfo(_Symbol, MODE_MINLOT);
   if(lot <= 0) lot = 0.01;
   int tk = OrderSend(_Symbol, OP_BUY, lot, Ask, 50, 0, 0, "NGtest", (int)magic, 0, clrNONE);
   if(tk < 0) PrintFormat("[NG-TEST] OrderSend magic=%I64d failed err=%d", magic, GetLastError());
   return (tk >= 0);
}

int FindMagicIdx(const long magic)
{
   for(int i = 0; i < ng_count; i++)
      if(ng_magic[i] == magic) return i;
   return -1;
}

void WriteNewsFile()
{
   int h = FileOpen(NEWS_FILE, FILE_WRITE | FILE_TXT | FILE_ANSI);   // tester sandbox (NOT Common)
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
   if(g_fail == 0) Print("[PASS] NewsGuard_Test_MT4: all asserts OK");
   else            PrintFormat("[FAIL] NewsGuard_Test_MT4: %d assert(s) failed", g_fail);
   g_phase = 5;
}

int OnInit() { return INIT_SUCCEEDED; }

void OnDeinit(const int reason)
{
   if(g_phase != 5) PrintFormat("[FAIL] NewsGuard_Test_MT4: incomplete run (phase %d)", g_phase);
}

void OnTick()
{
   if(g_phase == 5) return;
   datetime now = TimeCurrent();

   if(g_phase == 0)
   {
      g_t0   = now;
      g_ev   = g_t0 + 7200;                       // USD event 2h in
      NG_Setup(30, 15, 4, 48);                    // pre 30 / post 15 / Bkk=server+4 / stale 48h
      g_winA = g_ev - 30 * 60;
      g_winB = g_ev + 15 * 60;

      // ---- unit asserts: config parse + MT4 B->N downgrade --------------
      if(NG_ParseConfig("917201:C; 917202:B ;917203:N;junk;0:C;1:X") != 3)
         TFail("ParseConfig: expected exactly 3 accepted entries");
      if(ng_bDowngraded != 1)
         TFail("ParseConfig: exactly 1 B token must be downgraded on MT4");
      int idxB = FindMagicIdx(MAGIC_B);
      if(idxB < 0 || ng_policy[idxB] != NG_POLICY_NONE)
         TFail("ParseConfig: policy B must be stored as NONE on MT4 (downgrade)");
      int idxC = FindMagicIdx(MAGIC_C);
      if(idxC < 0 || ng_policy[idxC] != NG_POLICY_CLOSE)
         TFail("ParseConfig: policy C must stay CLOSE_ALL");

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
      if(_Symbol == "XAUUSD" && !NG_CcyMatchesSymbol("XAU", _Symbol))
         TFail("CcyMatchesSymbol XAU/XAUUSD");
      if(_Symbol == "XAUUSD" && NG_CcyMatchesSymbol("EUR", _Symbol))
         TFail("CcyMatchesSymbol EUR must not match XAUUSD");

      // ---- fake news + dummy orders -------------------------------------
      WriteNewsFile();
      if(!NG_LoadNews(NEWS_FILE, false)) TFail("LoadNews on fresh fake CSV failed");
      if(ng_evCount != 2) TFail(StringFormat("expected 2 events, got %d", ng_evCount));

      if(!OpenWithMagic(MAGIC_C) || !OpenWithMagic(MAGIC_B) ||
         !OpenWithMagic(MAGIC_N) || !OpenWithMagic(MAGIC_X))
         TFail("could not open dummy orders");
      if(CountMagic(MAGIC_C) != 1 || CountMagic(MAGIC_B) != 1 ||
         CountMagic(MAGIC_N) != 1 || CountMagic(MAGIC_X) != 1)
         TFail("dummy order count wrong after open");

      // ---- unit asserts: relevance (needs open orders) -------------------
      if(!NG_EventRelevant("USD", MAGIC_C)) TFail("USD must always be relevant");
      if(NG_EventRelevant("NZD", MAGIC_C))  TFail("NZD must be irrelevant while holding XAUUSD only");

      g_phase = 1;
   }

   NG_Tick(now);   // the watchdog pass under test (every tick >> generous 10s throttle)

   if(g_phase == 1)
   {
      // inside the irrelevant NZD window: nothing may happen
      if(!g_nzdChecked && now >= g_t0 + 3600 && now <= g_t0 + 3600 + 600)
      {
         g_nzdChecked = true;
         if(CountMagic(MAGIC_C) != 1) TFail("NZD window: C order was touched (irrelevant event)");
      }
      // shortly before the USD window opens: still all quiet
      if(!g_preChecked && now >= g_winA - 600 && now < g_winA - 60)
      {
         g_preChecked = true;
         if(CountMagic(MAGIC_C) != 1 || CountMagic(MAGIC_B) != 1 ||
            CountMagic(MAGIC_N) != 1 || CountMagic(MAGIC_X) != 1)
            TFail("pre-window: dummy orders already touched");
      }
      if(now >= g_winA + 120)
      {
         if(!g_nzdChecked) TFail("test plumbing: NZD checkpoint never reached");
         if(!g_preChecked) TFail("test plumbing: pre-window checkpoint never reached");
         // in-window asserts (2 min grace after window open)
         if(CountMagic(MAGIC_C) != 0)
            TFail("in-window: C-magic orders NOT closed");
         if(CountMagic(MAGIC_B) != 1)
            TFail("in-window: B-magic order was closed (B must act as N on MT4)");
         if(CountMagic(MAGIC_N) != 1) TFail("in-window: N-magic order was touched");
         if(CountMagic(MAGIC_X) != 1) TFail("in-window: UNLISTED-magic order was touched");
         g_phase = 2;
      }
   }
   else if(g_phase == 2)
   {
      if(now >= g_winB + 120)
      {
         if(CountMagic(MAGIC_B) != 1) TFail("post-window: B-magic order gone");
         if(CountMagic(MAGIC_N) != 1) TFail("post-window: N-magic order gone");
         if(CountMagic(MAGIC_X) != 1) TFail("post-window: unlisted-magic order gone");
         // ---- fail-safe: missing file => guard INACTIVE, no action --------
         FileDelete(NEWS_FILE);
         if(NG_LoadNews(NEWS_FILE, false)) TFail("fail-safe: LoadNews on missing file must fail");
         if(ng_newsOK) TFail("fail-safe: ng_newsOK must be false after missing file");
         if(!OpenWithMagic(MAGIC_C)) TFail("fail-safe: could not reopen C order");
         g_fsStart = now;
         g_phase = 3;
      }
   }
   else if(g_phase == 3)
   {
      if(now >= g_fsStart + 900)
      {
         if(CountMagic(MAGIC_C) != 1)
            TFail("fail-safe: C order was closed with missing news data (must take NO action)");
         CloseMagicLocal(MAGIC_C); CloseMagicLocal(MAGIC_B);
         CloseMagicLocal(MAGIC_N); CloseMagicLocal(MAGIC_X);
         Verdict();
      }
   }
}
