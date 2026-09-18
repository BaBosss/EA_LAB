//+------------------------------------------------------------------+
//| WickDisplacement_Test.mq5 - ZL-EA-067 independent V0 helpers.   |
//| Pure OHLC fixtures only; no broker/order/runtime claim.          |
//+------------------------------------------------------------------+
#property strict
#define LAB_ENTRY_22
#define LAB_ENTRY_TAG "22_WickDisplacement_Test"
#define OnInit LabCore_OnInit
#define OnTick LabCore_OnTick
#define OnDeinit LabCore_OnDeinit
#include "../core/LabCore.mqh"
#undef OnInit
#undef OnTick
#undef OnDeinit

void WD_Check(const bool ok,const string name,int &fail)
{
   if(ok) Print("[PASS] ",name);
   else { fail++; Print("[FAIL] ",name); }
}

int WD_Dir(const double ro,const double rh,const double rl,const double rc,
           const double dO,const double dh,const double dl,const double dc,
           const double ratio,const double frac)
{
   double strength=0.0, confidence=0.0;
   return ZL22_EvaluateBars(ro,rh,rl,rc,dO,dh,dl,dc,ratio,frac,strength,confidence);
}
int OnInit()
{
   int fail=0;
   WD_Check(WD_Dir(100,101,94,100.5,100.5,104,100,103.5,2.0,0.65)==1,
            "bullish rejection + displacement => BUY",fail);
   WD_Check(WD_Dir(100,106,99,99.5,99.5,100,96,96.5,2.0,0.65)==2,
            "bearish rejection + displacement => SELL",fail);
   WD_Check(WD_Dir(100,101,99.2,100.5,100.5,104,100,103.5,2.0,0.65)==0,
            "wick/body below threshold => NONE",fail);
   WD_Check(WD_Dir(100,101,94,100.5,100.5,104.5,100.5,102.0,2.0,0.65)==0,
            "displacement body/range below threshold => NONE",fail);
   WD_Check(WD_Dir(100,101,94,100.5,100.0,101.0,100.0,100.8,2.0,0.65)==0,
            "confirmation close not beyond rejection high => NONE",fail);
   WD_Check(WD_Dir(100,105,95,100,100,104,100,103.5,2.0,0.65)==0,
            "zero-body rejection => NONE",fail);
   WD_Check(WD_Dir(100,99,95,98,98,101,97,100.8,2.0,0.65)==0,
            "malformed OHLC => NONE",fail);
   WD_Check(WD_Dir(100,101,94,100.5,100.5,104,100,103.5,0.0,0.65)==0 &&
            WD_Dir(100,101,94,100.5,100.5,104,100,103.5,2.0,1.2)==0,
            "invalid strategy thresholds fail closed",fail);

   double strength=0.0, confidence=0.0;
   int dir=ZL22_EvaluateBars(100,101,94,100.5,100.5,104,100,103.5,
                            2.0,0.65,strength,confidence);
   WD_Check(dir==1 && strength>=2.0 && confidence>=0.65,
            "signal exposes measured strength/confidence",fail);
   if(fail==0) Print("[PASS] WickDisplacement_Test: 9 cases green");
   else PrintFormat("[FAIL] WickDisplacement_Test: %d assert(s) failed",fail);
   return INIT_SUCCEEDED;
}

void OnTick() {}

void OnDeinit(const int reason)
{
   Indi_Deinit();
}
