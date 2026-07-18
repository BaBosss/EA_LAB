//+------------------------------------------------------------------+
//| Entry_JumStoch.mqh (V2) - entry 18: LWMA-displacement + Stoch    |
//| filter. Port of the JUMSTOCH "Trend" block (Jum69 JUMSTOCH_      |
//| FIXEDLOT.mq4, ORDER-091C-D1; MT5 std port (EXP)_JUMSTOCH_MT5).   |
//|                                                                  |
//| ONLY the SEED SIGNAL is ported here - the grid/DCA, SL, TP, BEP  |
//| shift and trailing all come from the Boss V2 chassis (StackMode  |
//| 92 DCA in the wrapper .set), NOT from the standalone. This keeps  |
//| one exit owner (ExitManager) and lets every chassis lever         |
//| (_9_RegimeGateAdds, StackConfirm, MacroGate) apply.               |
//|                                                                  |
//| ⚠ DIRECTION MAPPING IS A/B-SWITCHED (_18_DirMode) - the two       |
//| readings are exact BUY<->SELL mirrors and the lab did NOT settle  |
//| which is right (2026-07-18, user: "build & A/B both"):            |
//|   DirMode 1 = FAITHFUL (momentum-join, the standalone's ACTUAL    |
//|     call-site mapping that produced the EURUSD-H1 PF1.18          |
//|     baseline): BUY when Close[1] > LWMA AND stoch < up_level      |
//|     (price above MA, not overbought -> JOIN the uptrend);         |
//|     SELL when Close[1] < LWMA AND stoch > lo_level.               |
//|   DirMode 2 = REVERSION (the Lane-A brief as written):            |
//|     BUY when Close[1] < LWMA AND stoch > lo_level;                |
//|     SELL when Close[1] > LWMA AND stoch < up_level.               |
//| Right home differs by mode (momentum->trender, reversion->ranger) |
//| - the A/B on EURUSD/AUDUSD H1 measures both empirically.          |
//|                                                                  |
//| Fixed direction per instance (_18_Direction, Boss_14/16 pattern): |
//| bidirectional = two chart instances with their own magics, never  |
//| one dual-engine. Stateless signal (shift 1 = last CLOSED bar); the |
//| bar-open gate + stack law live in LabCore/Stack.                  |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_ENTRY_JUMSTOCH_MQH
#define BOSS_LAB_ENTRY_JUMSTOCH_MQH
#include "IEntry.mqh"
#include "../Indicators.mqh"

void Entry_JumStoch_Init()
{
   // stateless entry - nothing to reset (kept for OnInit symmetry with 14/15/16)
}

EntrySignal Entry_Evaluate()
{
   int want = (_18_Direction == 1 ? 1 : 2);   // fixed instance direction, never both

   double close1 = iClose(_Symbol, _Period, 1);          // last CLOSED bar
   if(close1 <= 0.0) return Entry_MakeNone("no close");

   double lwma  = Indi_LWMA18(1);                          // LWMA on closed bar
   double stoch = Indi_StochJum18(1);                      // main %K line, closed bar
   if(lwma <= 0.0 || stoch < 0.0) return Entry_MakeNone("indi not ready");

   bool above = (close1 > lwma);
   int  sigDir = 0;   // 0=none 1=BUY 2=SELL

   if(_18_DirMode == 1)
   {
      // FAITHFUL momentum-join (validated source mapping)
      if(above  && stoch < _18_UpLevel) sigDir = 1;   // BUY: above MA, not overbought
      if(!above && stoch > _18_LoLevel) sigDir = 2;   // SELL: below MA, not oversold
   }
   else
   {
      // REVERSION (brief as written) - exact mirror of the above
      if(!above && stoch > _18_LoLevel) sigDir = 1;   // BUY: below MA, not oversold
      if(above  && stoch < _18_UpLevel) sigDir = 2;   // SELL: above MA, not overbought
   }

   if(sigDir == 0 || sigDir != want) return Entry_MakeNone("JumStoch neutral/off-direction");

   EntrySignal s;
   s.direction  = want;
   s.strength   = stoch;
   s.confidence = 1.0;
   s.valid      = true;
   s.reason     = (want == 1 ? "JumStoch buy" : "JumStoch sell");
   return s;
}

#endif // BOSS_LAB_ENTRY_JUMSTOCH_MQH
