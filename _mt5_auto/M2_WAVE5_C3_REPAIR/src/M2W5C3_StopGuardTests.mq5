//+------------------------------------------------------------------+
//|                                         M2W5C3_StopGuardTests.mq5 |
//| Focused / self-adversarial checks for the Wave5 C3 stop guard.     |
//+------------------------------------------------------------------+
//| Drives the SHIPPED arithmetic (M2W5C3_StopGuard.mqh, the same file |
//| ExpertMACD_repaired.mq5 includes) with synthetic quotes, including |
//| cases the MACD strategy never generates on its own -- a stop on    |
//| the wrong side of the market, a stop exactly on the price, a stop  |
//| one tick inside the broker minimum. A guard whose failure branch   |
//| is never exercised is untested, not safe.                          |
//|                                                                    |
//| Two of the cases are the REAL rejected orders recovered from the   |
//| 2025 tester journal, replayed digit for digit, so the suite is     |
//| anchored to observed reality and not only to invented numbers.     |
//|                                                                    |
//| Prints one line per case and a final verdict line the runner greps.|
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2026, MetaQuotes Ltd."
#property version   "1.00"

#include "M2W5C3_StopGuard.mqh"

int g_pass=0;
int g_fail=0;

//--- NZDUSD-as-observed constants (journal: stops_level=1, freeze_level=0, digits=5)
#define PT     0.00001
#define TICK   0.00001
#define DIG    5
#define STOPS  1
#define FREEZE 0

//--- 30*0.00001 is 0.00030000000000000003 in binary, so `==` on a COMPUTED
//--- distance tests the floating-point unit, not the guard. Compare with a
//--- tolerance far below one tick and far above representation noise.
bool NEAR(const double a,const double b) { return(MathAbs(a-b)<1e-12); }

void CHECK(const bool cond,const string name)
  {
   if(cond)
     {
      g_pass++;
      Print("[TEST] PASS  ",name);
     }
   else
     {
      g_fail++;
      Print("[TEST] FAIL  ",name);
     }
  }
//+------------------------------------------------------------------+
void RunTests(void)
  {
   double need  =SG_MinStopDistance(PT,STOPS,FREEZE,TICK);   // NZDUSD as observed: 1 point
   double need30=SG_MinStopDistance(PT,30,0,TICK);           // a stricter broker, for boundaries
   bool   slb=false,tpb=false;

//================= min-distance derivation =========================
   CHECK(NEAR(need,0.00001),"minDist: stops_level=1 on a 1e-5 point yields 1 point");
   CHECK(NEAR(SG_MinStopDistance(PT,0,0,TICK),0.00001),
         "minDist: stops=0 and freeze=0 still floors at one tick, never zero");
   CHECK(NEAR(SG_MinStopDistance(PT,30,0,TICK),0.00030),
         "minDist: a 30-point stops_level is honoured");
   CHECK(NEAR(SG_MinStopDistance(PT,0,45,TICK),0.00045),
         "minDist: freeze_level is honoured when it exceeds stops_level");
   CHECK(NEAR(SG_MinStopDistance(PT,60,45,TICK),0.00060),
         "minDist: the larger of stops_level and freeze_level wins");
   CHECK(NEAR(SG_MinStopDistance(PT,0,0,0.0),0.00001),
         "minDist: a zero tick size falls back to point, not to zero");

//================= BUY: direction and validity =====================
//--- healthy 15-point spread, stop 200 points below the fill
   CHECK(SG_BuyStopsValid(0.59315,0.60015,0.59500,need,slb,tpb),
         "BUY: normal spread, stop below Bid and target above Bid is valid");

//--- REPLAY of the real rejection, 2025.05.28 00:02:00 (spread 250 pts)
   CHECK(!SG_BuyStopsValid(0.59445,0.60145,0.59395,need,slb,tpb),
         "BUY: journal replay 2025.05.28 -- 250pt spread makes the 200pt stop unplaceable");
   CHECK(slb && !tpb,
         "BUY: journal replay blames the STOP leg only, never the target");

//--- adversarial: a stop on the wrong side of the market
   CHECK(!SG_BuyStopsValid(0.59600,0.60015,0.59500,need,slb,tpb),
         "BUY: a stop ABOVE Bid is rejected (wrong-side stop)");
   CHECK(slb,"BUY: wrong-side stop is attributed to the stop leg");

//--- adversarial: a target on the wrong side of the market
   CHECK(!SG_BuyStopsValid(0.59315,0.59400,0.59500,need,slb,tpb),
         "BUY: a target BELOW Bid is rejected (wrong-side target)");
   CHECK(tpb,"BUY: wrong-side target is attributed to the target leg");

//--- Boundary cases use a 30-POINT stops_level, not NZDUSD's 1-point one.
//--- At need==1 tick, "one tick inside the minimum" and "exactly on the
//--- price" are the same input, so the pair would have discriminated
//--- nothing. At 30 points the boundary has an interior to test.
   CHECK(SG_BuyStopsValid(0.59470,0.59530,0.59500,need30,slb,tpb),
         "BUY: levels exactly at a 30-point minimum distance are accepted");
   CHECK(!SG_BuyStopsValid(0.59471,0.60015,0.59500,need30,slb,tpb),
         "BUY: a stop one point inside the 30-point minimum is rejected");

//--- a stop sitting exactly on the validating price is not placeable
   CHECK(!SG_BuyStopsValid(0.59500,0.60015,0.59500,need,slb,tpb),
         "BUY: a stop exactly ON Bid is rejected");

//--- 0.0 means "not requested" and must never be judged
   CHECK(SG_BuyStopsValid(0.0,0.60015,0.59500,need,slb,tpb),
         "BUY: sl=0 is treated as not-requested, not as a wrong-side stop");
   CHECK(SG_BuyStopsValid(0.59315,0.0,0.59500,need,slb,tpb),
         "BUY: tp=0 is treated as not-requested");

//================= SELL: mirror of every BUY case ==================
//--- ask 0.60716, stop 200 points above it, target 500 points below it
   CHECK(SG_SellStopsValid(0.60916,0.60216,0.60716,need,slb,tpb),
         "SELL: normal spread, stop above Ask and target below Ask is valid");

//--- REPLAY of the real rejection, 2025.06.17 00:02:30 (spread 233 pts)
   CHECK(!SG_SellStopsValid(0.60683,0.59983,0.60716,need,slb,tpb),
         "SELL: journal replay 2025.06.17 -- 233pt spread makes the 200pt stop unplaceable");
   CHECK(slb && !tpb,
         "SELL: journal replay blames the STOP leg only, never the target");

//--- adversarial: a stop on the wrong side of the market
   CHECK(!SG_SellStopsValid(0.60600,0.60216,0.60716,need,slb,tpb),
         "SELL: a stop BELOW Ask is rejected (wrong-side stop)");
   CHECK(slb,"SELL: wrong-side stop is attributed to the stop leg");

//--- adversarial: a target on the wrong side of the market
   CHECK(!SG_SellStopsValid(0.60916,0.60800,0.60716,need,slb,tpb),
         "SELL: a target ABOVE Ask is rejected (wrong-side target)");
   CHECK(tpb,"SELL: wrong-side target is attributed to the target leg");

//--- boundary cases
   CHECK(SG_SellStopsValid(0.60746,0.60686,0.60716,need30,slb,tpb),
         "SELL: levels exactly at a 30-point minimum distance are accepted");
   CHECK(!SG_SellStopsValid(0.60745,0.60216,0.60716,need30,slb,tpb),
         "SELL: a stop one point inside the 30-point minimum is rejected");
   CHECK(!SG_SellStopsValid(0.60716,0.60216,0.60716,need,slb,tpb),
         "SELL: a stop exactly ON Ask is rejected");
   CHECK(SG_SellStopsValid(0.0,0.60216,0.60716,need,slb,tpb),
         "SELL: sl=0 is treated as not-requested");
   CHECK(SG_SellStopsValid(0.60916,0.0,0.60716,need,slb,tpb),
         "SELL: tp=0 is treated as not-requested");

//================= price normalization =============================
   CHECK(SG_NormalizeToTick(0.59445,TICK,DIG)==0.59445,
         "normalize: an already-gridded price is returned unchanged (identity on NZDUSD)");
   CHECK(SG_NormalizeToTick(0.0,TICK,DIG)==0.0,
         "normalize: the 0.0 not-requested sentinel survives normalization");
   CHECK(SG_NormalizeToTick(0.594457,0.00005,DIG)==0.59445,
         "normalize: a price off a 5-point tick grid is rounded onto it");
   CHECK(SG_NormalizeToTick(0.5944567,0.0,DIG)==0.59446,
         "normalize: a zero tick size degrades to digit rounding, not to zero");

//================= frozen-semantics arithmetic =====================
//--- Stop=20 / TP=50 adjusted points on a 5-digit symbol must remain
//--- 200 / 500 raw points measured from the FILL price. This is the
//--- number the repair must not move.
   double adj=PT*10.0;
   CHECK(20*adj==0.00200,"semantics: StopLoss=20 is still 200 raw points (20 pips)");
   CHECK(50*adj==0.00500,"semantics: TakeProfit=50 is still 500 raw points (50 pips)");
   double fill=0.59645;
   CHECK(NormalizeDouble(fill-20*adj,DIG)==0.59445,
         "semantics: the replayed BUY stop is still exactly 20 pips below its fill");
   CHECK(NormalizeDouble(fill+50*adj,DIG)==0.60145,
         "semantics: the replayed BUY target is still exactly 50 pips above its fill");
  }
//+------------------------------------------------------------------+
int OnInit(void)
  {
   Print("[TEST] === M2W5C3 stop-guard focused tests ===");
   RunTests();
   if(g_fail==0)
      Print("[TEST] RESULT: PASS ",g_pass,"/",g_pass+g_fail);
   else
      Print("[TEST] RESULT: FAIL ",g_fail," of ",g_pass+g_fail," checks failed");
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
void OnTick(void)
  {
   ExpertRemove();
  }
//+------------------------------------------------------------------+
void OnDeinit(const int reason) { }
//+------------------------------------------------------------------+
