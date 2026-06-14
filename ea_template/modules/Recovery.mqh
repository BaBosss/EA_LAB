//+------------------------------------------------------------------+
//| Recovery.mqh - gated. enum NONE/LIGHT/ADAPTIVE/AGGRESSIVE.       |
//| Phase 3a: NONE active; others reserved (hook is a safe no-op).   |
//| Full recovery logic lands in a later phase (see plan out-of-scope)|
//+------------------------------------------------------------------+
#ifndef EA_LAB_RECOVERY_MQH
#define EA_LAB_RECOVERY_MQH
#include "Inputs.mqh"

bool Recovery_Enabled() { return (InpRecoveryMode != REC_NONE); }

void Recovery_OnTick()
{
   if(InpRecoveryMode == REC_NONE) return;
   // LIGHT / ADAPTIVE / AGGRESSIVE: reserved for a later phase.
}

#endif // EA_LAB_RECOVERY_MQH
