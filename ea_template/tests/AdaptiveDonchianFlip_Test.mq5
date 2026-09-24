//+------------------------------------------------------------------+
//| AdaptiveDonchianFlip_Test.mq5 - FB-A01 deterministic helpers.   |
//| Formula/state tests only; no broker, tester-performance or edge  |
//| claim is made by this fixture.                                   |
//+------------------------------------------------------------------+
#property strict
#define ADAPTIVE_DONCHIAN_FLIP_TEST
#include "../core/entries/Entry_AdaptiveDonchianFlip.mqh"

int adf_checks=0;
int adf_failures=0;

void ADF_Check(const bool ok,const string name)
{
   adf_checks++;
   if(ok) Print("[PASS] ",name);
   else { adf_failures++; Print("[FAIL] ",name); }
}

bool ADF_CloseEnough(const double a,const double b)
{
   return MathAbs(a-b)<=1.0e-9;
}

int OnInit()
{
   double highs[3]={10.0,11.0,12.0};
   double lows[3]={5.0,6.0,7.0};
   double upper=0.0,lower=0.0;
   ADF_Check(ADF_Donchian(highs,lows,3,upper,lower) &&
             upper==12.0 && lower==5.0,
             "Donchian uses supplied prior bars only (decision bar excluded)");
   ADF_Check(ADF_Breakout(12.0,12.0,5.0,0.0,ADF_TREND_UP)==0,
             "Donchian equality is not a BUY breakout");
   ADF_Check(ADF_Breakout(5.0,12.0,5.0,0.0,ADF_TREND_DOWN)==0,
             "Donchian equality is not a SELL breakout");
   ADF_Check(ADF_Breakout(12.01,12.0,5.0,0.0,ADF_TREND_UP)==1 &&
             ADF_Breakout(4.99,12.0,5.0,0.0,ADF_TREND_DOWN)==2,
             "Donchian strict inequality admits only true crossings");

   double pct_hist[4]={1.0,2.0,2.0,3.0};
   double pct=0.0;
   ADF_Check(ADF_Percentile(2.0,pct_hist,4,pct) &&
             ADF_CloseEnough(pct,75.0),
             "ATR percentile ties count as less-than-or-equal");
   double missing_hist[4]={1.0,2.0,0.0,3.0};
   ADF_Check(!ADF_Percentile(2.0,missing_hist,4,pct),
             "ATR percentile missing/nonpositive history fails closed");
   ADF_Check(!ADF_Percentile(0.0,pct_hist,4,pct),
             "ATR percentile nonpositive current value fails closed");
   ADF_Check(ADF_Regime(19.999,20.0,80.0,95.0)==ADF_REGIME_LOW &&
             ADF_Regime(20.0,20.0,80.0,95.0)==ADF_REGIME_NORMAL &&
             ADF_Regime(80.0,20.0,80.0,95.0)==ADF_REGIME_HIGH &&
             ADF_Regime(95.0,20.0,80.0,95.0)==ADF_REGIME_EXTREME,
             "ATR percentile bounds map LOW/NORMAL/HIGH/EXTREME exactly");

   double st_h[4]={10.0,11.0,9.0,12.0};
   double st_l[4]={8.0,9.0,7.0,10.0};
   double st_c[4]={9.0,11.0,7.0,12.0};
   double st_a[4]={1.0,1.0,1.0,1.0};
   int trend=0;
   double st_upper=0.0,st_lower=0.0;
   ADF_Check(ADF_SuperTrend(st_h,st_l,st_c,st_a,4,1.0,
                            trend,st_upper,st_lower) &&
             trend==ADF_TREND_UP &&
             ADF_CloseEnough(st_upper,9.0) &&
             ADF_CloseEnough(st_lower,10.0),
             "SuperTrend seeds, carries bands, transitions DOWN then UP");
   double seed_h[1]={10.0},seed_l[1]={8.0},seed_c[1]={8.5},seed_a[1]={1.0};
   ADF_Check(ADF_SuperTrend(seed_h,seed_l,seed_c,seed_a,1,2.0,
                            trend,st_upper,st_lower) &&
             trend==ADF_TREND_DOWN &&
             ADF_CloseEnough(st_upper,11.0) &&
             ADF_CloseEnough(st_lower,7.0),
             "SuperTrend warmup seed uses Close >= HL2 else DOWN");

   double spreads50[50];
   for(int i=0;i<50;i++) spreads50[i]=(double)(i+1);
   ADF_Check(!ADF_SpreadPass(10.0,spreads50,49,50,3.0,0.10,400.0),
             "spread gate blocks during 50-sample warmup");
   double median=0.0;
   ADF_Check(ADF_Median(spreads50,50,median) &&
             ADF_CloseEnough(median,25.5),
             "even 50-sample spread median averages middle pair");
   ADF_Check(ADF_SpreadPass(30.0,spreads50,50,50,3.0,0.10,400.0),
             "spread gate passes median and ATR ceilings");
   ADF_Check(!ADF_SpreadPass(80.0,spreads50,50,50,3.0,0.10,1000.0),
             "spread median ceiling blocks");
   ADF_Check(!ADF_SpreadPass(41.0,spreads50,50,50,3.0,0.10,400.0),
             "spread ATR cap blocks");
   spreads50[0]=0.0;
   ADF_Check(!ADF_SpreadPass(10.0,spreads50,50,50,3.0,0.10,400.0),
             "invalid spread baseline fails closed");

   ADF_Check(ADF_CloseEnough(ADF_InitialSL(1,100.0,3.0,2.0),94.0) &&
             ADF_CloseEnough(ADF_InitialSL(2,100.0,3.0,2.0),106.0),
             "initial SL distance is placed in the protective direction");
   ADF_Check(ADF_TrailTightens(1,95.0,96.0) &&
             !ADF_TrailTightens(1,95.0,94.0) &&
             ADF_TrailTightens(2,105.0,104.0) &&
             !ADF_TrailTightens(2,105.0,106.0),
             "closed-bar SuperTrend trail tightens and never loosens");

   ADF_Check(ADF_Owns("EURUSD",240024,"EURUSD",240024) &&
             !ADF_Owns("GBPUSD",240024,"EURUSD",240024) &&
             !ADF_Owns("EURUSD",240025,"EURUSD",240024),
             "ownership is isolated by chart symbol and strategy magic");

   ADF_Fsm fsm;
   ADF_FsmReset(fsm);
   fsm.state=ADF_STATE_LONG;
   ADF_Check(ADF_FsmStep(fsm,100,true,1,true,1,1,0,false)==ADF_ACTION_NONE,
             "same-direction qualified signal is a no-op");
   ADF_Check(ADF_FsmStep(fsm,101,true,2,true,1,1,0,false)==ADF_ACTION_CLOSE &&
             fsm.pending_direction==2 && fsm.pending_bar==101,
             "opposite signal latches reverse and requests close first");
   ADF_Check(ADF_FsmStep(fsm,101,false,0,true,1,1,0,false)==ADF_ACTION_CLOSE,
             "partial close remains close-only and cannot overlap reverse");
   ADF_Check(ADF_FsmStep(fsm,101,false,0,true,1,1,0,false)==ADF_ACTION_CLOSE,
             "broker close error remains fail-closed and retryable");
   ADF_Check(ADF_FsmStep(fsm,101,false,0,true,0,0,0,false)==ADF_ACTION_OPEN &&
             fsm.reverse_attempted,
             "reverse opens only after exact flat verification");
   ADF_Check(ADF_FsmStep(fsm,101,false,0,true,0,0,0,false)==ADF_ACTION_NONE,
             "latched reverse has one open attempt only");
   ADF_Check(ADF_FsmStep(fsm,101,false,0,true,1,2,0,false)==ADF_ACTION_NONE &&
             fsm.pending_direction==0 && fsm.state==ADF_STATE_SHORT,
             "successful reverse ownership reconciles without duplicate");

   ADF_FsmReset(fsm);
   ADF_Check(ADF_FsmStep(fsm,150,true,1,false,0,0,0,false)==ADF_ACTION_HALT &&
             fsm.state==ADF_STATE_HALTED && fsm.pending_direction==0 &&
             fsm.pending_bar==0 && !fsm.reverse_attempted,
             "invalid ownership view halts even when reported flat");
   ADF_Check(ADF_FsmStep(fsm,151,true,1,true,0,0,0,false)==ADF_ACTION_NONE &&
             fsm.state==ADF_STATE_HALTED,
             "later valid ownership and fresh signal cannot auto-clear halt");

   for(int owned_direction=1;owned_direction<=2;owned_direction++)
   {
      ADF_FsmReset(fsm);
      int reverse_direction=(owned_direction==1 ? 2 : 1);
      ADF_Check(ADF_FsmStep(fsm,160,true,reverse_direction,true,1,
                            owned_direction,0,false)==ADF_ACTION_CLOSE &&
                fsm.pending_direction==reverse_direction && fsm.pending_bar==160,
                "ownership fixture arms pending reverse in both directions");
      ADF_Check(ADF_FsmStep(fsm,160,false,0,false,1,owned_direction,0,false)==ADF_ACTION_HALT &&
                fsm.state==ADF_STATE_HALTED && fsm.pending_direction==0 &&
                fsm.pending_bar==0 && !fsm.reverse_attempted,
                "stale ownership view halts and cancels pending reverse");
      ADF_Check(ADF_FsmStep(fsm,160,false,0,true,0,0,0,false)==ADF_ACTION_NONE &&
                fsm.state==ADF_STATE_HALTED,
                "later stable flat view cannot resume halted reverse");
      ADF_Check(ADF_FsmStep(fsm,161,true,reverse_direction,true,1,
                            owned_direction,0,false)==ADF_ACTION_NONE &&
                fsm.state==ADF_STATE_HALTED,
                "new-bar opposite signal cannot escape ownership halt");
   }

   ADF_FsmReset(fsm);
   ADF_FsmStep(fsm,170,true,2,true,1,1,0,false);
   ADF_FsmStep(fsm,170,false,0,true,0,0,0,false);
   ADF_Check(fsm.reverse_attempted && fsm.pending_direction==2,
             "ownership fixture includes an already-attempted pending reverse");
   ADF_Check(ADF_FsmStep(fsm,170,false,0,false,0,0,0,false)==ADF_ACTION_HALT &&
             fsm.state==ADF_STATE_HALTED && fsm.pending_direction==0 &&
             fsm.pending_bar==0 && !fsm.reverse_attempted,
             "unstable ownership clears pending reverse attempt state on halt");
   ADF_Check(ADF_FsmStep(fsm,171,true,1,true,0,0,0,false)==ADF_ACTION_NONE &&
             fsm.state==ADF_STATE_HALTED,
             "valid ownership after attempted reverse cannot clear halt");

   ADF_FsmReset(fsm);
   fsm.state=ADF_STATE_LONG;
   ADF_FsmStep(fsm,200,true,2,true,1,1,0,false);
   ADF_Check(ADF_FsmStep(fsm,201,true,0,true,1,1,0,false)==ADF_ACTION_NONE &&
             fsm.pending_direction==0,
             "bar change cancels pending reverse without a fresh signal");

   ADF_FsmReset(fsm);
   ADF_Check(ADF_FsmStep(fsm,300,true,1,true,0,0,0,false)==ADF_ACTION_OPEN &&
             ADF_FsmStep(fsm,300,false,0,true,0,0,0,false)==ADF_ACTION_NONE,
             "flat open refusal or broker error gets no same-bar retry");

   ADF_FsmReset(fsm);
   ADF_Check(ADF_FsmStep(fsm,400,true,0,true,2,1,0,false)==ADF_ACTION_HALT,
             "multiple owned positions fail closed");
   ADF_FsmReset(fsm);
   ADF_Check(ADF_FsmStep(fsm,401,true,0,true,0,0,1,false)==ADF_ACTION_HALT,
             "unexpected owned pending order fails closed");
   ADF_FsmReset(fsm);
   ADF_Check(ADF_FsmStep(fsm,500,true,1,true,0,0,0,true)==ADF_ACTION_HALT &&
             ADF_FsmStep(fsm,501,true,1,true,0,0,0,false)==ADF_ACTION_NONE &&
             fsm.state==ADF_STATE_HALTED,
             "shared-risk halt wins and never self-clears");

   PrintFormat("FB-A01: %d checks, %d failures",adf_checks,adf_failures);
   return adf_failures==0 ? INIT_SUCCEEDED : INIT_FAILED;
}

void OnTick() {}
