//+------------------------------------------------------------------+
//| BasketGuard_Test.mq5 - drives the pure half of the guard through |
//| the cases that would otherwise only ever be exercised by a real  |
//| account losing real money.                                       |
//|                                                                  |
//| Run it in the Strategy Tester on any symbol/period; it asserts   |
//| in OnInit and reports PASS/FAIL, so no trading data is needed.   |
//| A single FAIL line means the guard must not be armed.            |
//|                                                                  |
//| The cases below are chosen for the ways this specific guard      |
//| could hurt someone: firing when it must not, and NOT firing when |
//| it must. Boundary equality is tested in both directions because  |
//| ">=" vs ">" here is the difference between a cut at the limit    |
//| and a cut that never comes.                                      |
//+------------------------------------------------------------------+
#property copyright "EA_LAB"
#property version   "1.00"

#include "BasketGuard_Core.mqh"

int g_pass = 0;
int g_fail = 0;

void Check(const bool cond, const string name)
{
   if(cond) { g_pass++; Print("PASS  ", name); }
   else     { g_fail++; Print("FAIL  ", name); }
}

void CheckD(const double got, const double want, const string name)
{
   Check(MathAbs(got - want) < 1e-9, StringFormat("%s (got %.6f want %.6f)", name, got, want));
}

int OnInit()
{
   //--- BG_LossLimitAbs: an invalid config must DISARM, never cut at zero
   CheckD(BG_LossLimitAbs(1000.0, 15.0), 150.0, "limit: 15% of 1000 = 150");
   CheckD(BG_LossLimitAbs(0.0,    15.0),   0.0, "limit: zero baseline disarms");
   CheckD(BG_LossLimitAbs(-500.0, 15.0),   0.0, "limit: negative baseline disarms");
   CheckD(BG_LossLimitAbs(1000.0,  0.0),   0.0, "limit: zero pct disarms");
   CheckD(BG_LossLimitAbs(1000.0, -5.0),   0.0, "limit: negative pct disarms");
   CheckD(BG_LossLimitAbs(1000.0, 91.0),   0.0, "limit: pct above 90 refused");
   CheckD(BG_LossLimitAbs(1000.0, 90.0), 900.0, "limit: pct exactly 90 allowed");

   //--- BG_Decide: the one comparison
   Check(BG_Decide(0,  -9999.0, 150.0, false) == BG_ACTION_NONE, "decide: no positions never acts");
   Check(BG_Decide(0,  -9999.0, 150.0, true ) == BG_ACTION_NONE, "decide: halted but flat is quiet");
   Check(BG_Decide(3,    -10.0, 150.0, false) == BG_ACTION_NONE, "decide: small loss holds");
   Check(BG_Decide(3,   -149.99,150.0, false) == BG_ACTION_NONE, "decide: just under the limit holds");
   Check(BG_Decide(3,   -150.0, 150.0, false) == BG_ACTION_CUT,  "decide: exactly at the limit CUTS");
   Check(BG_Decide(3,   -150.01,150.0, false) == BG_ACTION_CUT,  "decide: past the limit CUTS");
   Check(BG_Decide(3,   9999.0, 150.0, false) == BG_ACTION_NONE, "decide: profit never cuts");
   Check(BG_Decide(3,    -10.0,   0.0, false) == BG_ACTION_NONE, "decide: unarmed limit never cuts");
   Check(BG_Decide(3,   9999.0, 150.0, true ) == BG_ACTION_HOLD, "decide: halted closes re-entry even in profit");
   Check(BG_Decide(1,     -1.0, 150.0, true ) == BG_ACTION_HOLD, "decide: halt outranks the limit");

   //--- BG_UsagePct: only for logs, but a wrong sign here hides a real breach
   CheckD(BG_UsagePct(  -75.0, 150.0),  50.0, "usage: half way");
   CheckD(BG_UsagePct( -150.0, 150.0), 100.0, "usage: at the limit");
   CheckD(BG_UsagePct( -300.0, 150.0), 200.0, "usage: past the limit is not clamped");
   CheckD(BG_UsagePct(   50.0, 150.0),   0.0, "usage: profit reads zero");
   CheckD(BG_UsagePct(  -50.0,   0.0),   0.0, "usage: unarmed limit reads zero, not infinity");

   //--- status line must carry the firing count; a guard that cannot
   //--- report its own firings cannot be held to the doctrine bar
   string line = BG_StatusLine(D'2026.07.26 10:00:00', 1524, 3, -75.0, 150.0, false, true, 100, 0);
   Check(StringFind(line, ",1524,3,-75.00,150.00,50.0,ARMED,DRYRUN,100,0") >= 0,
         "status: line carries magic, state, mode and counters");

   PrintFormat("BasketGuard_Test: %d passed, %d FAILED", g_pass, g_fail);
   if(g_fail > 0) Print("BasketGuard_Test: DO NOT ARM THE GUARD");
   // Succeed even on FAIL so the tester completes and writes a report; the
   // verdict is the "%d FAILED" line above, not the exit code. Returning
   // INIT_FAILED here would abort the run and take the assertion output
   // with it -- a test that hides its own result when it fails.
   return INIT_SUCCEEDED;
}

void OnTick() {}
