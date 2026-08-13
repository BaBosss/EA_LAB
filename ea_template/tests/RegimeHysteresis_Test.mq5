//+------------------------------------------------------------------+
//| RegimeHysteresis_Test.mq5 - asserts for core\Regime.mqh AAM        |
//| Module 4.3/4.6 additions (Regime_ClassifyStable / Regime_Suggest   |
//| ExitMode). Runs with compiled defaults (_50_RegimeMode=0 off) - no |
//| .set needed. Same convention/limitation as Hedge_Test.mq5: this   |
//| proves config sanity, the OnInit reset path, and the disabled-     |
//| regime accessor contract are well-defined. The live confirm-bar    |
//| commit under real ADX data needs bars + an enabled regime and is   |
//| exercised indirectly by tpl_regression.ps1 / a future A/B sweep,   |
//| not by this OnInit-only harness.                                   |
//+------------------------------------------------------------------+
#include "../core/Regime.mqh"

int OnInit()
{
   int fail = 0;

   // config sanity: exit threshold must sit strictly below the entry
   // threshold, else Regime_ClassifyRawHyst() would re-enter trend on the
   // same tick it just left it (same class of check Hedge_Test makes for
   // _H_ReleaseDDPct < _H_TriggerDDPct).
   if(!(_50_ADX_TrendMin_Exit < _50_ADX_TrendMin))
   {
      PrintFormat("[FAIL] config sanity: _50_ADX_TrendMin_Exit(%.2f) must be < _50_ADX_TrendMin(%.2f)",
                  _50_ADX_TrendMin_Exit, _50_ADX_TrendMin);
      fail++;
   }

   if(_50_RegimeConfirmBars <= 0)
   { PrintFormat("[FAIL] _50_RegimeConfirmBars default (%d) must be > 0", _50_RegimeConfirmBars); fail++; }

   // Regime_Init() must reset the additive hysteresis state block, not just
   // the pre-existing g_regime_* block - a stale candidate/confirm count
   // leaking across OnInit re-runs would corrupt the very first classification.
   g_regime_stable_state     = REGIME_TREND_UP;
   g_regime_stable_candidate = REGIME_TREND_DOWN;
   g_regime_stable_confirm   = 7;
   g_regime_stable_has_cache = true;
   g_regime_stable_last_bar  = 123456;
   if(!Regime_Init()) { Print("[FAIL] Regime_Init() returned false"); fail++; }
   if(g_regime_stable_state != REGIME_RANGE || g_regime_stable_candidate != REGIME_RANGE ||
      g_regime_stable_confirm != 0 || g_regime_stable_has_cache != false || g_regime_stable_last_bar != 0)
   { Print("[FAIL] Regime_Init() did not reset the hysteresis state block to defaults"); fail++; }

   // default config (_50_RegimeMode=0, off): Regime_ClassifyStable() must be
   // a safe no-op returning REGIME_RANGE without touching any indicator
   // handle - mirrors Regime_Current()'s existing !Regime_Enabled() early-return.
   if(Regime_ClassifyStable() != REGIME_RANGE)
   { Print("[FAIL] Regime_ClassifyStable() with _50_RegimeMode=0 must return REGIME_RANGE"); fail++; }

   // Regime_SuggestExitMode() must be deterministic under the disabled
   // default: REGIME_RANGE maps to EXIT_ATR_TP (spec 4.4 RANGE row - "SMART
   // TP, no runner"). This is an advisory-only function (never called from
   // any default OnTick path in this order); this only proves the mapping
   // table itself is correct.
   if(Regime_SuggestExitMode() != EXIT_ATR_TP)
   { Print("[FAIL] Regime_SuggestExitMode() on REGIME_RANGE must return EXIT_ATR_TP"); fail++; }

   if(fail == 0) Print("[PASS] RegimeHysteresis_Test: all 5 asserts OK");
   else          PrintFormat("[FAIL] RegimeHysteresis_Test: %d assert(s) failed", fail);
   return INIT_SUCCEEDED;
}

void OnTick() {}
