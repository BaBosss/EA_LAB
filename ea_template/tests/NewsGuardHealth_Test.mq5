// Deterministic health-notification regression test for NewsGuard.
#include "NewsGuard_Core.mqh"

#define MAGIC_H 917199
int fail = 0;
void TFail(const string m) { Print("[NGH-TEST FAIL] ", m); fail++; }

int OnInit()
{
   NG_Setup(30, 15, 4, 48);
   if(NG_ParseConfig("917199:B") != 1) TFail("config parse");
   string gv = NG_GVName(MAGIC_H);
   GlobalVariableSet(gv, 1.0);

   ng_newsOK = false;
   int n0 = ng_notificationAttempts;
   NG_Tick(TimeCurrent());
   if(ng_notificationAttempts != n0 + 1) TFail("initial outage must alert once");
   if(GlobalVariableCheck(gv)) TFail("outage must clear owned block GV");

   NG_Tick(TimeCurrent());
   if(ng_notificationAttempts != n0 + 1) TFail("steady outage must not spam immediately");

   ng_lastAlert = TimeLocal() - NG_HEALTH_REMINDER_SEC;
   NG_Tick(TimeCurrent());
   if(ng_notificationAttempts != n0 + 2) TFail("12h reminder must alert once");
   ng_newsOK = true;
   ng_evCount = 0;
   NG_Tick(TimeCurrent());
   if(ng_notificationAttempts != n0 + 3) TFail("recovery must notify once");
   if(!ng_healthWasOK) TFail("recovery state not latched healthy");

   NG_Tick(TimeCurrent());
   if(ng_notificationAttempts != n0 + 3) TFail("healthy steady state must stay quiet");

   NG_Deinit();
   if(fail == 0) Print("[PASS] NewsGuardHealth_Test: transition/reminder/recovery OK");
   else PrintFormat("[FAIL] NewsGuardHealth_Test: %d assert(s) failed", fail);
   return INIT_SUCCEEDED;
}
void OnTick() {}
