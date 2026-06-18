//+------------------------------------------------------------------+
//| Recovery.mqh (V2) - gated. 80 None active; 81/82/83 reserved.    |
//| When built: adds are still clamped by RiskControl_MaxLevels()    |
//| and RC_RecMultMax (cage governs recovery - cannot exceed KillDD).|
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_RECOVERY_MQH
#define BOSS_LAB_RECOVERY_MQH
#include "Inputs.mqh"

bool Recovery_Enabled() { return (RecoveryMode != REC_NONE); }

void Recovery_OnTick()
{
   if(RecoveryMode == REC_NONE) return;
   // 81 LIGHT / 82 ADAPTIVE / 83 AGGRESSIVE: reserved for a later phase.
}

#endif // BOSS_LAB_RECOVERY_MQH
