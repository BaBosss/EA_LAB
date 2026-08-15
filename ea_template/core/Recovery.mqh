//+------------------------------------------------------------------+
//| Recovery.mqh (V2) - offensive add-into-loss layer (8x).          |
//|  80 None (default, early-return) / 81 Light / 82 Adaptive /       |
//|  83 Aggressive. Fires only when the basket is LOSING and price    |
//|  has run adverse >= _8_TriggerATR x Risk-ATR beyond the worst     |
//|  entry, then adds one order per _8_StepATR of further adverse     |
//|  travel. Distinct from Stack (which adds on distance+confirm      |
//|  regardless of P&L); Recovery adds *because* the basket is red.   |
//|                                                                   |
//|  CAGE RULE: every add is clamped by RiskControl_MaxLevels()       |
//|  (RC_MaxRecSteps + _9_MaxLevels), RC_RecMultMax and RC_MaxLot,    |
//|  and RiskControl_AllowNewOrder() (deposit load). Recovery adds    |
//|  share the SAME position-count cap as Stack adds, so total        |
//|  exposure can never exceed the cage -> cannot breach KillDD.      |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_RECOVERY_MQH
#define BOSS_LAB_RECOVERY_MQH
#include "Inputs.mqh"
#include "Indicators.mqh"
#include "Execution.mqh"
#include "RiskControl.mqh"
#include "MoneyManagement.mqh"
#include "ExitManager.mqh"

// recompile-safe state (reset in Recovery_Init from OnInit, not silent static)
datetime g_rec_last_bar = 0;   // one recovery add per bar (anti-spam)

void Recovery_Init()
{
   g_rec_last_bar = 0;
}

bool Recovery_Enabled() { return (RecoveryMode != REC_NONE); }

// lot for a recovery add at recovery-step `rstep` (>=1). base = current first lot.
double Recovery_AddLot(const double baseLot, const int rstep, const double basketDD)
{
   double lot = baseLot;
   switch(RecoveryMode)
   {
      case REC_LIGHT:
         // 81: fixed modest add - no escalation, just base first-lot each step.
         lot = baseLot;
         break;

      case REC_ADAPTIVE:
      {
         // 82: size scales with current basket DD, hard-clamped by RC_RecMultMax.
         // deeper DD (relative to the reference) -> larger add, capped at mult.
         // additive (2026-07-23): _8_DDRefBalPct (% of balance) wins over the absolute
         // _8_DDRefMoney when set - portable across cent/USD accounts and scales with
         // account size, so the escalation curve does not silently steepen after a
         // deposit (a fixed $100 reference is a much deeper DD on a small account).
         double ddRef = MM_BalancePct(_8_DDRefBalPct);
         if(ddRef <= 0.0) ddRef = _8_DDRefMoney;
         double mult = 1.0;
         if(ddRef > 0.0 && basketDD > 0.0)
            mult = 1.0 + (basketDD / ddRef);
         double cap = (RC_RecMultMax > 0.0 ? RC_RecMultMax : 1.0);
         if(mult > cap) mult = cap;
         if(mult < 1.0) mult = 1.0;
         lot = baseLot * mult;
         break;
      }

      case REC_AGGRESSIVE:
      {
         // 83: multi-step escalation via 5x progression on the recovery step,
         //     multiplier still clamped by RC_RecMultMax (cage governs).
         double m = (_8_RecMult > 0.0 ? _8_RecMult : 1.0);
         double cap = (RC_RecMultMax > 0.0 ? RC_RecMultMax : 1.0);
         if(m > cap) m = cap;
         lot = baseLot * MathPow(m, rstep);
         break;
      }

      default:
         lot = baseLot;
         break;
   }
   return RiskControl_ClampLot(lot);
}

// open one recovery add in the basket direction (sanctioned Exec path).
void Recovery_OpenAdd(const int dir, const int level, const double lot)
{
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return;
   double entry = (dir == 1 ? t.ask : t.bid);
   double sl    = Exit_InitialSL(dir, entry);
   if(Exit_StructSLMissing(sl)) return;   // MM-SAFETY-001: same fail-closed rule as the flat entry
   double tp    = Exit_InitialTP(dir, entry);
   Exec_Open(dir, lot, sl, tp, LAB_ENTRY_TAG + " R" + IntegerToString(level));
}

void Recovery_OnTick()
{
   if(RecoveryMode == REC_NONE) return;   // 80: OFF path, identical to stub

   // need an existing single-direction basket in the red
   int haveBuy  = Exec_CountDirectionalDir(1);
   int haveSell = Exec_CountDirectionalDir(2);
   int have     = haveBuy + haveSell;
   if(have <= 0) return;                       // nothing to recover
   if(haveBuy > 0 && haveSell > 0) return;     // mixed (hedged) basket - skip
   int dir = (haveBuy > 0 ? 1 : 2);

   double basketProfit = Exec_BasketProfit();
   if(basketProfit >= 0.0) return;             // recover only when losing

   // cage: recovery adds share the same position-count cap as stack adds
   if(have >= RiskControl_MaxLevels()) return;
   if(!RiskControl_AllowNewOrder()) return;

   // adverse-excursion trigger measured from the worst (last) entry in dir
   double atr = Exit_RiskATR_Scaled();
   if(atr <= 0.0) return;
   double trigDist = (_8_TriggerATR > 0.0 ? _8_TriggerATR : 1.0) * atr;
   double stepDist = (_8_StepATR    > 0.0 ? _8_StepATR    : 1.0) * atr;
   if(stepDist <= 0.0) return;

   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return;
   double last = Exec_LastDirectionalPriceDir(dir); // most-recent directional entry in dir
   if(last <= 0.0) return;

   // adverse travel of current price vs the last entry, in price units
   double adverse = (dir == 1 ? (last - t.ask) : (t.bid - last));
   if(adverse < trigDist) return;              // not deep enough yet

   // one add per bar (anti-spam; recompile-safe via g_rec_last_bar)
   datetime barT = iTime(_Symbol, _Period, 0);
   if(barT == g_rec_last_bar) return;

   // recovery step index = how many step-distances past the trigger we are (>=1)
   int rstep = 1 + (int)MathFloor((adverse - trigDist) / stepDist);
   if(rstep < 1) rstep = 1;

   double baseLot   = MM_FirstLot(Exit_SLDistancePoints());
   double addLot    = Recovery_AddLot(baseLot, rstep, -basketProfit);
   if(addLot <= 0.0) return;

   Recovery_OpenAdd(dir, have, addLot);        // level = current count (matches cage)
   g_rec_last_bar = barT;
}

#endif // BOSS_LAB_RECOVERY_MQH
