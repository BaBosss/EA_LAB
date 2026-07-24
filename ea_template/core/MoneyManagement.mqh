//+------------------------------------------------------------------+
//| MoneyManagement.mqh (V2) - lot sizing.                           |
//|  first order : 41 Fixed / 42 Risk% (risk / SL distance)          |
//|  progression : 50 None / 51 Lin / 52 Mult / 53 Plus / 54 Log     |
//|  All clamped by RiskControl (RC_MaxLot) + Exec normalize.        |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_MM_MQH
#define BOSS_LAB_MM_MQH
#include "Inputs.mqh"
#include "RiskControl.mqh"

double MM_MoneyPerPointPerLot()
{
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(tickSize <= 0.0) return 0.0;
   return tickVal * (point / tickSize);
}

// additive (2026-07-23): convert a "% of balance" input into an absolute money figure in
// ACCOUNT CURRENCY. The one shared helper behind every _*_BalPct input, so all of them
// resolve identically and there is a single place to audit.
//
// Why percent instead of absolute money: a bare "25" means $25 on a USD account but $0.25
// on a cent account - the same .set silently trades a 100x different target. A percentage
// of balance is unitless, so it means the same thing on both, AND it scales as the account
// grows (no re-tuning a hard-coded money target after a deposit).
//
// Returns 0.0 when pct <= 0 (caller treats 0 as "feature off" and falls back to its legacy
// absolute input), or when balance is unavailable/non-positive - fail-safe: a broken
// balance read disables the percentage target rather than inventing one.
double MM_BalancePct(const double pct)
{
   if(pct <= 0.0) return 0.0;
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0.0) return 0.0;
   return balance * pct / 100.0;
}

// additive: DD-adaptive first-lot multiplier (Zeus GridLog _05_DdAdaptive port).
// Applied ONLY to the first order of a new basket, tiered on current floating
// account DD%, always clamped by _4_DdHardCapMult. OFF by default (returns 1.0).
double MM_DdAdaptiveMultiplier()
{
   if(!_4_DdAdaptiveOn) return 1.0;
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0.0) return 1.0;
   double ddPct = (balance - equity) / balance * 100.0;
   double mult = 1.0;
   if(ddPct >= _4_DdTier2Pct) mult = _4_DdTier2Mult;
   else if(ddPct >= _4_DdTier1Pct) mult = _4_DdTier1Mult;
   if(_4_DdHardCapMult > 0.0 && mult > _4_DdHardCapMult) mult = _4_DdHardCapMult;
   return mult;
}

// MM-SAFETY-001 (Codex review 2026-07-24): config-time validation of the sizing mode,
// called once from OnInit. A sizing mode whose ingredients are missing is a CONFIG bug -
// it must brick the attach, not quietly become a different mode at the first order. The
// old code degraded 42/43 to _41_FixedLot with no log at all, so a .set asking for
// "1% risk" could trade a flat 0.01 lot forever and look like it worked.
// Returns false -> caller returns INIT_FAILED.
bool MM_ConfigValid()
{
#ifdef LAB_ENTRY_16
   // Kangaroo owns the entire lot law (_16_BaseLot -> Kangaroo_NextLot) and LabCore
   // short-circuits into it before MM_FirstLot can ever run. Every FirstLotMode is
   // therefore inert here - warn (an inert dial is not a safety promise), never fail:
   // the pinned Boss_16 regression set must keep loading.
   if(FirstLotMode != FIRSTLOT_FIXED)
      PrintFormat("[INIT] WARN: FirstLotMode=%d has NO EFFECT on Boss_16/Kangaroo - the base lot comes from _16_BaseLot / _16_BaseLotMode (see MM_ConfigValid)", FirstLotMode);
   // ORDER-190: entry 16's own opt-in scaler borrows the chassis mode-43 anchor pair, so
   // it needs the same config-time validation - an unusable anchor must brick the attach
   // here too, not surface later as skipped orders.
   if(_16_BaseLotMode == 1 && (_43_BalanceAnchor <= 0.0 || _43_LotPerAnchor <= 0.0))
   {
      PrintFormat("[INIT] FATAL: _16_BaseLotMode=1 (balance-scaled) needs _43_BalanceAnchor > 0 and _43_LotPerAnchor > 0 (got %.2f / %.4f)",
                  _43_BalanceAnchor, _43_LotPerAnchor);
      return false;
   }
   if(_16_BaseLotMode != 0 && _16_BaseLotMode != 1)
   {
      PrintFormat("[INIT] FATAL: _16_BaseLotMode=%d is not a defined mode (0=flat, 1=balance-scaled)", _16_BaseLotMode);
      return false;
   }
   return true;
#else
   if(FirstLotMode == FIRSTLOT_RISK)
   {
      if(_42_RiskPct <= 0.0)
      {
         Print("[INIT] FATAL: FirstLotMode=42 (risk%) with _42_RiskPct <= 0 - nothing to size from");
         return false;
      }
      // 42 divides by an SL distance. SL_NONE(30) and SL_MONEY(32) publish no per-order
      // distance, so the division has no input - that combination is unsizeable, not
      // "fall back to fixed".
      bool slGivesDistance = (SLMode == SL_FIXED_POINTS || SLMode == SL_ATR || SLMode == SL_SD ||
                              SLMode == SL_STRUCT_DONCHIAN || SLMode == SL_STRUCT_SR);
      bool structProvides = false;
#ifdef LAB_ENTRY_17
      // Wave5 publishes its own structural distance (ExitManager guard G3), which is a
      // valid distance source regardless of SLMode.
      if(_17_UseStructLevels) { slGivesDistance = true; structProvides = true; }
#endif
      if(!slGivesDistance)
      {
         PrintFormat("[INIT] FATAL: FirstLotMode=42 needs a per-order SL distance but SLMode=%d yields none (30 NONE / 32 MONEY) - use SLMode 31/33/34/35/36, or FirstLotMode 41/43", SLMode);
         return false;
      }
      // ORDER-194b (Codex audit, medium): picking the right SLMode CATEGORY is not enough -
      // that mode's own parameter still has to produce a positive distance. SLMode=31 with
      // _31_SL_Pip=0 used to attach cleanly and then skip every single signal forever, which
      // contradicts the whole point of validating configuration at OnInit: the operator sees
      // a healthy attach and an EA that never trades.
      // ORDER-194c (Codex review 2): only meaningful when SLMode is the distance SOURCE.
      // Exit_SLDistancePoints returns the published Wave5 structural distance BEFORE it
      // ever reaches the SLMode switch, so on build 17 with struct levels on, SLMode's own
      // parameter is never read - and rejecting the attach over it (e.g. SLMode=31 with
      // _31_SL_Pip=0, a perfectly workable config there) is a false alarm this check
      // introduced. Skip it when the structural source is in force.
      bool slParamOK = true;
      string slWhy = "";
      if(structProvides) { slParamOK = true; }
      else {
      if(SLMode == SL_FIXED_POINTS    && _31_SL_Pip      <= 0.0) { slParamOK = false; slWhy = "_31_SL_Pip <= 0"; }
      if(SLMode == SL_ATR             && _33_SL_ATRmult  <= 0.0) { slParamOK = false; slWhy = "_33_SL_ATRmult <= 0"; }
      if(SLMode == SL_SD              && (_36_SD_Mult <= 0.0 || _36_SD_Period <= 0)) { slParamOK = false; slWhy = "_36_SD_Mult/_36_SD_Period <= 0"; }
      if(SLMode == SL_STRUCT_DONCHIAN && _34_DonchianBars <= 0) { slParamOK = false; slWhy = "_34_DonchianBars <= 0"; }
      if(SLMode == SL_STRUCT_SR       && _35_SRBars       <= 0) { slParamOK = false; slWhy = "_35_SRBars <= 0"; }
      }
      if(!slParamOK)
      {
         PrintFormat("[INIT] FATAL: FirstLotMode=42 with SLMode=%d cannot produce a distance (%s) - every order would be skipped", SLMode, slWhy);
         return false;
      }
      return true;
   }
   if(FirstLotMode == FIRSTLOT_BALANCE)
   {
      if(_43_BalanceAnchor <= 0.0 || _43_LotPerAnchor <= 0.0)
      {
         PrintFormat("[INIT] FATAL: FirstLotMode=43 needs _43_BalanceAnchor > 0 and _43_LotPerAnchor > 0 (got %.2f / %.4f)", _43_BalanceAnchor, _43_LotPerAnchor);
         return false;
      }
      return true;
   }
   // ORDER-194b (Codex audit): anything reaching here that is not 41 is an undefined mode -
   // a hand-edited or corrupted .set carrying e.g. FirstLotMode=44. The runtime switch in
   // MM_FirstLot branches only on 42/43, so such a value would silently trade _41_FixedLot:
   // the same "you asked for one thing and got another" failure this whole change removes.
   if(FirstLotMode != FIRSTLOT_FIXED)
   {
      PrintFormat("[INIT] FATAL: FirstLotMode=%d is not a defined mode (41 fixed / 42 risk%% / 43 balance-scaled)", FirstLotMode);
      return false;
   }
   if(_41_FixedLot <= 0.0)
   {
      PrintFormat("[INIT] FATAL: FirstLotMode=41 with _41_FixedLot=%.4f - no lot to trade", _41_FixedLot);
      return false;
   }
   return true;
#endif
}

// MM-SAFETY-001: one throttled "cannot size" log plus the 0.0 that makes every caller
// skip the order (Exec_NormalizeLot already returns 0 below the broker minimum and
// Exec_Open refuses lot <= 0). Returning 0.0 rather than _41_FixedLot is the whole
// point: a runtime data failure must cost a missed trade, never a differently-sized one.
// reason slots for MM_SizingUnavailable's throttle - one timestamp each, so a fault that
// alternates with another still gets its own 60s window.
#define MM_WHY_NO_SL_DIST   0
#define MM_WHY_NO_TICKVAL   1
#define MM_WHY_NO_BALANCE   2
#define MM_WHY_SLOTS        3

double MM_SizingUnavailable(const int reasonId, const string why)
{
   // ORDER-194b (Codex audit, low): one shared timestamp let a "no SL distance" message
   // swallow a "tick value unreadable" ten seconds later - two different faults, one never
   // seen.
   // ORDER-194c (Codex review 2): the first repair keyed the throttle on "did the reason
   // CHANGE", which is not the same thing: reasons alternating A-B-A-B differ from their
   // immediate predecessor every single time, so every call logged and the 60s window did
   // nothing. Genuine per-reason throttling needs one timestamp PER reason.
   static datetime mm_last_log[MM_WHY_SLOTS];
   if(reasonId < 0 || reasonId >= MM_WHY_SLOTS) return 0.0;   // unreachable; keeps the index safe
   datetime now = TimeCurrent();
   if(now - mm_last_log[reasonId] >= 60)
   {
      mm_last_log[reasonId] = now;
      PrintFormat("[MM] first-lot sizing unavailable (%s) - order skipped, NO fallback to _41_FixedLot", why);
   }
   return 0.0;
}

// first-order lot. Returns 0.0 = "could not size this order" -> caller skips.
// Config errors are already dead at OnInit (MM_ConfigValid); what remains here is
// runtime data failure (unreadable balance / tick value, or an SL distance the exit
// side could not produce this tick).
double MM_FirstLot(const double slDistancePoints)
{
   double lot = _41_FixedLot;
   if(FirstLotMode == FIRSTLOT_RISK)
   {
      double riskMoney = MM_BalancePct(_42_RiskPct);   // same math as before, shared helper
      double perPoint  = MM_MoneyPerPointPerLot();
      if(slDistancePoints <= 0.0)
         return MM_SizingUnavailable(MM_WHY_NO_SL_DIST, "mode 42: no SL distance this tick");
      if(perPoint <= 0.0)
         return MM_SizingUnavailable(MM_WHY_NO_TICKVAL, "mode 42: tick value/size unreadable");
      if(riskMoney <= 0.0)
         return MM_SizingUnavailable(MM_WHY_NO_BALANCE, "mode 42: account balance unreadable");
      lot = riskMoney / (slDistancePoints * perPoint);
   }
   // additive (2026-07-23): balance-scaled sizing that does NOT need an SL distance, so
   // grid/basket entries (no per-order SL) can also scale with account size - FIRSTLOT_RISK
   // cannot size those at all, which is the gap this closes.
   //   lot = _43_LotPerAnchor x (balance / _43_BalanceAnchor)
   // Ratio is unitless -> identical behavior on cent and USD accounts PROVIDED the anchor
   // is expressed in the units that account displays (a $1,000 cent account reads 100000,
   // so its anchor is 100000 - see the Account Profile table in EA_CORE_AND_TEMPLATE_GUIDE).
   // Anchor/lot-per-anchor validity is enforced at OnInit, so only balance can fail here.
   else if(FirstLotMode == FIRSTLOT_BALANCE)
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      if(balance <= 0.0)
         return MM_SizingUnavailable(MM_WHY_NO_BALANCE, "mode 43: account balance unreadable");
      lot = _43_LotPerAnchor * (balance / _43_BalanceAnchor);
   }
   lot *= MM_DdAdaptiveMultiplier();   // no-op unless _4_DdAdaptiveOn
   return RiskControl_ClampLot(lot);
}

// lot for stacked order at given level (0 = first).
double MM_NextLot(const double firstLot, const int level)
{
   // MM-SAFETY-001: propagate a failed first-lot sizing. Every multiplicative branch
   // already yields 0 from 0, but PROG_PLUS is additive - firstLot=0 at level 3 would
   // invent a lot of 3 x _53_PlusLot out of a sizing FAILURE. Refuse explicitly.
   if(firstLot <= 0.0) return 0.0;

   int lv    = level;
   int maxLv = RiskControl_MaxLevels();
   if(lv > maxLv) lv = maxLv;

   double lot = firstLot;
   switch(LotProg)
   {
      case PROG_LINEAR:
         lot = firstLot * (1.0 + _51_ProgFactor * lv);
         break;
      case PROG_MULTIPLIER:
      {
         double m = _52_ProgMult;
         if(RC_RecMultMax > 0.0 && m > RC_RecMultMax) m = RC_RecMultMax;
         lot = firstLot * MathPow(m, lv);
         break;
      }
      case PROG_PLUS:
         lot = firstLot + _53_PlusLot * lv;
         break;
      case PROG_LOG:
         lot = firstLot * (1.0 + _51_ProgFactor * MathLog((double)(lv + 1)));
         break;
      case PROG_LOG_POWER:
      {
         // Zeus GridLog port (14): lot = baseLot * factor^(ln orderN) [or log10],
         // orderN = lv+1 (1-indexed, so level 0 -> orderN 1 -> exponent 0 -> lot=firstLot).
         double orderN   = (double)(lv + 1);
         double exponent = (_55_UseLnNotLog10 ? MathLog(orderN) : MathLog10(orderN));
         lot = firstLot * MathPow(_55_LogPowerFactor, exponent);
         break;
      }
      case PROG_FIBONACCI:
      {
         // corpus EX191: fib = 1,2,3,5,8,13,... (fib(0)=1, fib(1)=2, ...),
         // lot(lv) = firstLot * fib(lv). Capped at the multiplier reached at
         // _56_FibMaxStep - beyond the cap, HOLD the capped multiplier instead
         // of continuing to grow (this is the anti-martingale point). Computed
         // iteratively, no recursion; level index guarded >= 0.
         int cap = (_56_FibMaxStep >= 0 ? _56_FibMaxStep : 0);
         int idx = lv;
         if(idx < 0) idx = 0;
         if(idx > cap) idx = cap;
         double fibPrev = 1.0, fibCur = 1.0; // fib(0)=1
         for(int i = 1; i <= idx; i++)
         {
            double next = fibPrev + fibCur;
            fibPrev = fibCur;
            fibCur  = next;
         }
         lot = firstLot * fibCur;
         break;
      }
      case PROG_NONE:
      default:
         lot = firstLot;
         break;
   }
   return RiskControl_ClampLot(lot);
}

#endif // BOSS_LAB_MM_MQH
