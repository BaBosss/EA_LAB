//+------------------------------------------------------------------+
//| LockedConstants_gen.mqh - GENERATED FILE, DO NOT EDIT BY HAND.    |
//| generator : _triage/factory_os/gen_locked_constants.py
//| source    : the #include closure of each ea_template/Boss_*.mq5 wrapper
//| regenerate: tools\python312\python.exe _triage/factory_os/gen_locked_constants.py --write
//|                                                                   |
//| ORDER-730 -- the LOCKED-CONSTANT half of design section 5.6. Every |
//| valued #define that reaches this build, canonicalised the same way |
//| preset.py canonicalises it. Each line reads the MACRO, not a copy  |
//| of its value, which is what makes the digest evidence about the    |
//| BINARY rather than a second transcription of the source.           |
//|                                                                   |
//| Included LAST by LabCore.mqh, after every header that defines one  |
//| of these macros - an enumeration placed before them would not      |
//| merely be wrong, it would not compile.                             |
//| @CFG_METADATA declarations remain compile-visible but are excluded |
//| from this semantic preimage by the source-level metadata marker.    |
//+------------------------------------------------------------------+
#ifndef BOSS_LOCKED_CONSTANTS_GEN_MQH
#define BOSS_LOCKED_CONSTANTS_GEN_MQH

#include "ConfigFingerprint.mqh"

#ifdef LAB_ENTRY_11
#define CFG_CONSTANTS_ENUMERATED
int    CFG_ConstKeys() { return(24); }
string CFG_ConstPreimage()
  {
   string s = "";
   s += "\nconst:CFG_FP_SCOPE=" + CFG_CanonString(CFG_FP_SCOPE);
   s += "\nconst:EVTBUS_PREFIX=" + CFG_CanonString(EVTBUS_PREFIX);
   s += "\nconst:HEDGE_TAG=" + CFG_CanonString(HEDGE_TAG);
   s += "\nconst:LAB_ENTRY_TAG=" + CFG_CanonString(LAB_ENTRY_TAG);
   s += "\nconst:MACROGATE_GV_MAX_AGE_SEC=" + CFG_CanonLong((long)MACROGATE_GV_MAX_AGE_SEC);
   s += "\nconst:MG_ALERT_THROTTLE_SEC=" + CFG_CanonLong((long)MG_ALERT_THROTTLE_SEC);
   s += "\nconst:MG_BLOCK_PREFIX=" + CFG_CanonString(MG_BLOCK_PREFIX);
   s += "\nconst:MG_LOTMULT_PREFIX=" + CFG_CanonString(MG_LOTMULT_PREFIX);
   s += "\nconst:MG_MAX_MAGICS=" + CFG_CanonLong((long)MG_MAX_MAGICS);
   s += "\nconst:MG_MAX_ROWS=" + CFG_CanonLong((long)MG_MAX_ROWS);
   s += "\nconst:MG_ST_NEUTRAL=" + CFG_CanonLong((long)MG_ST_NEUTRAL);
   s += "\nconst:MG_ST_RISK_OFF=" + CFG_CanonLong((long)MG_ST_RISK_OFF);
   s += "\nconst:MG_ST_RISK_ON=" + CFG_CanonLong((long)MG_ST_RISK_ON);
   s += "\nconst:MG_ST_STRESS=" + CFG_CanonLong((long)MG_ST_STRESS);
   s += "\nconst:MG_ST_UNKNOWN=" + CFG_CanonLong((long)MG_ST_UNKNOWN);
   s += "\nconst:MM_WHY_NO_BALANCE=" + CFG_CanonLong((long)MM_WHY_NO_BALANCE);
   s += "\nconst:MM_WHY_NO_SL_DIST=" + CFG_CanonLong((long)MM_WHY_NO_SL_DIST);
   s += "\nconst:MM_WHY_NO_TICKVAL=" + CFG_CanonLong((long)MM_WHY_NO_TICKVAL);
   s += "\nconst:MM_WHY_SLOTS=" + CFG_CanonLong((long)MM_WHY_SLOTS);
   s += "\nconst:RC_DEPOSIT_LOAD_UNKNOWN=" + CFG_CanonDouble(RC_DEPOSIT_LOAD_UNKNOWN);
   s += "\nconst:RC_STATE_HALTED=" + CFG_CanonDouble(RC_STATE_HALTED);
   s += "\nconst:RC_STATE_KILL_PENDING=" + CFG_CanonDouble(RC_STATE_KILL_PENDING);
   s += "\nconst:RC_STATE_RUNNING=" + CFG_CanonDouble(RC_STATE_RUNNING);
   s += "\nconst:STACK_MAX_LEGS=" + CFG_CanonLong((long)STACK_MAX_LEGS);
   return(s);
  }
#endif

#ifdef LAB_ENTRY_12
#define CFG_CONSTANTS_ENUMERATED
int    CFG_ConstKeys() { return(24); }
string CFG_ConstPreimage()
  {
   string s = "";
   s += "\nconst:CFG_FP_SCOPE=" + CFG_CanonString(CFG_FP_SCOPE);
   s += "\nconst:EVTBUS_PREFIX=" + CFG_CanonString(EVTBUS_PREFIX);
   s += "\nconst:HEDGE_TAG=" + CFG_CanonString(HEDGE_TAG);
   s += "\nconst:LAB_ENTRY_TAG=" + CFG_CanonString(LAB_ENTRY_TAG);
   s += "\nconst:MACROGATE_GV_MAX_AGE_SEC=" + CFG_CanonLong((long)MACROGATE_GV_MAX_AGE_SEC);
   s += "\nconst:MG_ALERT_THROTTLE_SEC=" + CFG_CanonLong((long)MG_ALERT_THROTTLE_SEC);
   s += "\nconst:MG_BLOCK_PREFIX=" + CFG_CanonString(MG_BLOCK_PREFIX);
   s += "\nconst:MG_LOTMULT_PREFIX=" + CFG_CanonString(MG_LOTMULT_PREFIX);
   s += "\nconst:MG_MAX_MAGICS=" + CFG_CanonLong((long)MG_MAX_MAGICS);
   s += "\nconst:MG_MAX_ROWS=" + CFG_CanonLong((long)MG_MAX_ROWS);
   s += "\nconst:MG_ST_NEUTRAL=" + CFG_CanonLong((long)MG_ST_NEUTRAL);
   s += "\nconst:MG_ST_RISK_OFF=" + CFG_CanonLong((long)MG_ST_RISK_OFF);
   s += "\nconst:MG_ST_RISK_ON=" + CFG_CanonLong((long)MG_ST_RISK_ON);
   s += "\nconst:MG_ST_STRESS=" + CFG_CanonLong((long)MG_ST_STRESS);
   s += "\nconst:MG_ST_UNKNOWN=" + CFG_CanonLong((long)MG_ST_UNKNOWN);
   s += "\nconst:MM_WHY_NO_BALANCE=" + CFG_CanonLong((long)MM_WHY_NO_BALANCE);
   s += "\nconst:MM_WHY_NO_SL_DIST=" + CFG_CanonLong((long)MM_WHY_NO_SL_DIST);
   s += "\nconst:MM_WHY_NO_TICKVAL=" + CFG_CanonLong((long)MM_WHY_NO_TICKVAL);
   s += "\nconst:MM_WHY_SLOTS=" + CFG_CanonLong((long)MM_WHY_SLOTS);
   s += "\nconst:RC_DEPOSIT_LOAD_UNKNOWN=" + CFG_CanonDouble(RC_DEPOSIT_LOAD_UNKNOWN);
   s += "\nconst:RC_STATE_HALTED=" + CFG_CanonDouble(RC_STATE_HALTED);
   s += "\nconst:RC_STATE_KILL_PENDING=" + CFG_CanonDouble(RC_STATE_KILL_PENDING);
   s += "\nconst:RC_STATE_RUNNING=" + CFG_CanonDouble(RC_STATE_RUNNING);
   s += "\nconst:STACK_MAX_LEGS=" + CFG_CanonLong((long)STACK_MAX_LEGS);
   return(s);
  }
#endif

#ifdef LAB_ENTRY_13
#define CFG_CONSTANTS_ENUMERATED
int    CFG_ConstKeys() { return(24); }
string CFG_ConstPreimage()
  {
   string s = "";
   s += "\nconst:CFG_FP_SCOPE=" + CFG_CanonString(CFG_FP_SCOPE);
   s += "\nconst:EVTBUS_PREFIX=" + CFG_CanonString(EVTBUS_PREFIX);
   s += "\nconst:HEDGE_TAG=" + CFG_CanonString(HEDGE_TAG);
   s += "\nconst:LAB_ENTRY_TAG=" + CFG_CanonString(LAB_ENTRY_TAG);
   s += "\nconst:MACROGATE_GV_MAX_AGE_SEC=" + CFG_CanonLong((long)MACROGATE_GV_MAX_AGE_SEC);
   s += "\nconst:MG_ALERT_THROTTLE_SEC=" + CFG_CanonLong((long)MG_ALERT_THROTTLE_SEC);
   s += "\nconst:MG_BLOCK_PREFIX=" + CFG_CanonString(MG_BLOCK_PREFIX);
   s += "\nconst:MG_LOTMULT_PREFIX=" + CFG_CanonString(MG_LOTMULT_PREFIX);
   s += "\nconst:MG_MAX_MAGICS=" + CFG_CanonLong((long)MG_MAX_MAGICS);
   s += "\nconst:MG_MAX_ROWS=" + CFG_CanonLong((long)MG_MAX_ROWS);
   s += "\nconst:MG_ST_NEUTRAL=" + CFG_CanonLong((long)MG_ST_NEUTRAL);
   s += "\nconst:MG_ST_RISK_OFF=" + CFG_CanonLong((long)MG_ST_RISK_OFF);
   s += "\nconst:MG_ST_RISK_ON=" + CFG_CanonLong((long)MG_ST_RISK_ON);
   s += "\nconst:MG_ST_STRESS=" + CFG_CanonLong((long)MG_ST_STRESS);
   s += "\nconst:MG_ST_UNKNOWN=" + CFG_CanonLong((long)MG_ST_UNKNOWN);
   s += "\nconst:MM_WHY_NO_BALANCE=" + CFG_CanonLong((long)MM_WHY_NO_BALANCE);
   s += "\nconst:MM_WHY_NO_SL_DIST=" + CFG_CanonLong((long)MM_WHY_NO_SL_DIST);
   s += "\nconst:MM_WHY_NO_TICKVAL=" + CFG_CanonLong((long)MM_WHY_NO_TICKVAL);
   s += "\nconst:MM_WHY_SLOTS=" + CFG_CanonLong((long)MM_WHY_SLOTS);
   s += "\nconst:RC_DEPOSIT_LOAD_UNKNOWN=" + CFG_CanonDouble(RC_DEPOSIT_LOAD_UNKNOWN);
   s += "\nconst:RC_STATE_HALTED=" + CFG_CanonDouble(RC_STATE_HALTED);
   s += "\nconst:RC_STATE_KILL_PENDING=" + CFG_CanonDouble(RC_STATE_KILL_PENDING);
   s += "\nconst:RC_STATE_RUNNING=" + CFG_CanonDouble(RC_STATE_RUNNING);
   s += "\nconst:STACK_MAX_LEGS=" + CFG_CanonLong((long)STACK_MAX_LEGS);
   return(s);
  }
#endif

#ifdef LAB_ENTRY_14
#define CFG_CONSTANTS_ENUMERATED
int    CFG_ConstKeys() { return(24); }
string CFG_ConstPreimage()
  {
   string s = "";
   s += "\nconst:CFG_FP_SCOPE=" + CFG_CanonString(CFG_FP_SCOPE);
   s += "\nconst:EVTBUS_PREFIX=" + CFG_CanonString(EVTBUS_PREFIX);
   s += "\nconst:HEDGE_TAG=" + CFG_CanonString(HEDGE_TAG);
   s += "\nconst:LAB_ENTRY_TAG=" + CFG_CanonString(LAB_ENTRY_TAG);
   s += "\nconst:MACROGATE_GV_MAX_AGE_SEC=" + CFG_CanonLong((long)MACROGATE_GV_MAX_AGE_SEC);
   s += "\nconst:MG_ALERT_THROTTLE_SEC=" + CFG_CanonLong((long)MG_ALERT_THROTTLE_SEC);
   s += "\nconst:MG_BLOCK_PREFIX=" + CFG_CanonString(MG_BLOCK_PREFIX);
   s += "\nconst:MG_LOTMULT_PREFIX=" + CFG_CanonString(MG_LOTMULT_PREFIX);
   s += "\nconst:MG_MAX_MAGICS=" + CFG_CanonLong((long)MG_MAX_MAGICS);
   s += "\nconst:MG_MAX_ROWS=" + CFG_CanonLong((long)MG_MAX_ROWS);
   s += "\nconst:MG_ST_NEUTRAL=" + CFG_CanonLong((long)MG_ST_NEUTRAL);
   s += "\nconst:MG_ST_RISK_OFF=" + CFG_CanonLong((long)MG_ST_RISK_OFF);
   s += "\nconst:MG_ST_RISK_ON=" + CFG_CanonLong((long)MG_ST_RISK_ON);
   s += "\nconst:MG_ST_STRESS=" + CFG_CanonLong((long)MG_ST_STRESS);
   s += "\nconst:MG_ST_UNKNOWN=" + CFG_CanonLong((long)MG_ST_UNKNOWN);
   s += "\nconst:MM_WHY_NO_BALANCE=" + CFG_CanonLong((long)MM_WHY_NO_BALANCE);
   s += "\nconst:MM_WHY_NO_SL_DIST=" + CFG_CanonLong((long)MM_WHY_NO_SL_DIST);
   s += "\nconst:MM_WHY_NO_TICKVAL=" + CFG_CanonLong((long)MM_WHY_NO_TICKVAL);
   s += "\nconst:MM_WHY_SLOTS=" + CFG_CanonLong((long)MM_WHY_SLOTS);
   s += "\nconst:RC_DEPOSIT_LOAD_UNKNOWN=" + CFG_CanonDouble(RC_DEPOSIT_LOAD_UNKNOWN);
   s += "\nconst:RC_STATE_HALTED=" + CFG_CanonDouble(RC_STATE_HALTED);
   s += "\nconst:RC_STATE_KILL_PENDING=" + CFG_CanonDouble(RC_STATE_KILL_PENDING);
   s += "\nconst:RC_STATE_RUNNING=" + CFG_CanonDouble(RC_STATE_RUNNING);
   s += "\nconst:STACK_MAX_LEGS=" + CFG_CanonLong((long)STACK_MAX_LEGS);
   return(s);
  }
#endif

#ifdef LAB_ENTRY_15
#define CFG_CONSTANTS_ENUMERATED
int    CFG_ConstKeys() { return(24); }
string CFG_ConstPreimage()
  {
   string s = "";
   s += "\nconst:CFG_FP_SCOPE=" + CFG_CanonString(CFG_FP_SCOPE);
   s += "\nconst:EVTBUS_PREFIX=" + CFG_CanonString(EVTBUS_PREFIX);
   s += "\nconst:HEDGE_TAG=" + CFG_CanonString(HEDGE_TAG);
   s += "\nconst:LAB_ENTRY_TAG=" + CFG_CanonString(LAB_ENTRY_TAG);
   s += "\nconst:MACROGATE_GV_MAX_AGE_SEC=" + CFG_CanonLong((long)MACROGATE_GV_MAX_AGE_SEC);
   s += "\nconst:MG_ALERT_THROTTLE_SEC=" + CFG_CanonLong((long)MG_ALERT_THROTTLE_SEC);
   s += "\nconst:MG_BLOCK_PREFIX=" + CFG_CanonString(MG_BLOCK_PREFIX);
   s += "\nconst:MG_LOTMULT_PREFIX=" + CFG_CanonString(MG_LOTMULT_PREFIX);
   s += "\nconst:MG_MAX_MAGICS=" + CFG_CanonLong((long)MG_MAX_MAGICS);
   s += "\nconst:MG_MAX_ROWS=" + CFG_CanonLong((long)MG_MAX_ROWS);
   s += "\nconst:MG_ST_NEUTRAL=" + CFG_CanonLong((long)MG_ST_NEUTRAL);
   s += "\nconst:MG_ST_RISK_OFF=" + CFG_CanonLong((long)MG_ST_RISK_OFF);
   s += "\nconst:MG_ST_RISK_ON=" + CFG_CanonLong((long)MG_ST_RISK_ON);
   s += "\nconst:MG_ST_STRESS=" + CFG_CanonLong((long)MG_ST_STRESS);
   s += "\nconst:MG_ST_UNKNOWN=" + CFG_CanonLong((long)MG_ST_UNKNOWN);
   s += "\nconst:MM_WHY_NO_BALANCE=" + CFG_CanonLong((long)MM_WHY_NO_BALANCE);
   s += "\nconst:MM_WHY_NO_SL_DIST=" + CFG_CanonLong((long)MM_WHY_NO_SL_DIST);
   s += "\nconst:MM_WHY_NO_TICKVAL=" + CFG_CanonLong((long)MM_WHY_NO_TICKVAL);
   s += "\nconst:MM_WHY_SLOTS=" + CFG_CanonLong((long)MM_WHY_SLOTS);
   s += "\nconst:RC_DEPOSIT_LOAD_UNKNOWN=" + CFG_CanonDouble(RC_DEPOSIT_LOAD_UNKNOWN);
   s += "\nconst:RC_STATE_HALTED=" + CFG_CanonDouble(RC_STATE_HALTED);
   s += "\nconst:RC_STATE_KILL_PENDING=" + CFG_CanonDouble(RC_STATE_KILL_PENDING);
   s += "\nconst:RC_STATE_RUNNING=" + CFG_CanonDouble(RC_STATE_RUNNING);
   s += "\nconst:STACK_MAX_LEGS=" + CFG_CanonLong((long)STACK_MAX_LEGS);
   return(s);
  }
#endif

#ifdef LAB_ENTRY_16
#define CFG_CONSTANTS_ENUMERATED
int    CFG_ConstKeys() { return(24); }
string CFG_ConstPreimage()
  {
   string s = "";
   s += "\nconst:CFG_FP_SCOPE=" + CFG_CanonString(CFG_FP_SCOPE);
   s += "\nconst:EVTBUS_PREFIX=" + CFG_CanonString(EVTBUS_PREFIX);
   s += "\nconst:HEDGE_TAG=" + CFG_CanonString(HEDGE_TAG);
   s += "\nconst:LAB_ENTRY_TAG=" + CFG_CanonString(LAB_ENTRY_TAG);
   s += "\nconst:MACROGATE_GV_MAX_AGE_SEC=" + CFG_CanonLong((long)MACROGATE_GV_MAX_AGE_SEC);
   s += "\nconst:MG_ALERT_THROTTLE_SEC=" + CFG_CanonLong((long)MG_ALERT_THROTTLE_SEC);
   s += "\nconst:MG_BLOCK_PREFIX=" + CFG_CanonString(MG_BLOCK_PREFIX);
   s += "\nconst:MG_LOTMULT_PREFIX=" + CFG_CanonString(MG_LOTMULT_PREFIX);
   s += "\nconst:MG_MAX_MAGICS=" + CFG_CanonLong((long)MG_MAX_MAGICS);
   s += "\nconst:MG_MAX_ROWS=" + CFG_CanonLong((long)MG_MAX_ROWS);
   s += "\nconst:MG_ST_NEUTRAL=" + CFG_CanonLong((long)MG_ST_NEUTRAL);
   s += "\nconst:MG_ST_RISK_OFF=" + CFG_CanonLong((long)MG_ST_RISK_OFF);
   s += "\nconst:MG_ST_RISK_ON=" + CFG_CanonLong((long)MG_ST_RISK_ON);
   s += "\nconst:MG_ST_STRESS=" + CFG_CanonLong((long)MG_ST_STRESS);
   s += "\nconst:MG_ST_UNKNOWN=" + CFG_CanonLong((long)MG_ST_UNKNOWN);
   s += "\nconst:MM_WHY_NO_BALANCE=" + CFG_CanonLong((long)MM_WHY_NO_BALANCE);
   s += "\nconst:MM_WHY_NO_SL_DIST=" + CFG_CanonLong((long)MM_WHY_NO_SL_DIST);
   s += "\nconst:MM_WHY_NO_TICKVAL=" + CFG_CanonLong((long)MM_WHY_NO_TICKVAL);
   s += "\nconst:MM_WHY_SLOTS=" + CFG_CanonLong((long)MM_WHY_SLOTS);
   s += "\nconst:RC_DEPOSIT_LOAD_UNKNOWN=" + CFG_CanonDouble(RC_DEPOSIT_LOAD_UNKNOWN);
   s += "\nconst:RC_STATE_HALTED=" + CFG_CanonDouble(RC_STATE_HALTED);
   s += "\nconst:RC_STATE_KILL_PENDING=" + CFG_CanonDouble(RC_STATE_KILL_PENDING);
   s += "\nconst:RC_STATE_RUNNING=" + CFG_CanonDouble(RC_STATE_RUNNING);
   s += "\nconst:STACK_MAX_LEGS=" + CFG_CanonLong((long)STACK_MAX_LEGS);
   return(s);
  }
#endif

#ifdef LAB_ENTRY_17
#define CFG_CONSTANTS_ENUMERATED
int    CFG_ConstKeys() { return(25); }
string CFG_ConstPreimage()
  {
   string s = "";
   s += "\nconst:CFG_FP_SCOPE=" + CFG_CanonString(CFG_FP_SCOPE);
   s += "\nconst:EVTBUS_PREFIX=" + CFG_CanonString(EVTBUS_PREFIX);
   s += "\nconst:HEDGE_TAG=" + CFG_CanonString(HEDGE_TAG);
   s += "\nconst:LAB_ENTRY_TAG=" + CFG_CanonString(LAB_ENTRY_TAG);
   s += "\nconst:MACROGATE_GV_MAX_AGE_SEC=" + CFG_CanonLong((long)MACROGATE_GV_MAX_AGE_SEC);
   s += "\nconst:MG_ALERT_THROTTLE_SEC=" + CFG_CanonLong((long)MG_ALERT_THROTTLE_SEC);
   s += "\nconst:MG_BLOCK_PREFIX=" + CFG_CanonString(MG_BLOCK_PREFIX);
   s += "\nconst:MG_LOTMULT_PREFIX=" + CFG_CanonString(MG_LOTMULT_PREFIX);
   s += "\nconst:MG_MAX_MAGICS=" + CFG_CanonLong((long)MG_MAX_MAGICS);
   s += "\nconst:MG_MAX_ROWS=" + CFG_CanonLong((long)MG_MAX_ROWS);
   s += "\nconst:MG_ST_NEUTRAL=" + CFG_CanonLong((long)MG_ST_NEUTRAL);
   s += "\nconst:MG_ST_RISK_OFF=" + CFG_CanonLong((long)MG_ST_RISK_OFF);
   s += "\nconst:MG_ST_RISK_ON=" + CFG_CanonLong((long)MG_ST_RISK_ON);
   s += "\nconst:MG_ST_STRESS=" + CFG_CanonLong((long)MG_ST_STRESS);
   s += "\nconst:MG_ST_UNKNOWN=" + CFG_CanonLong((long)MG_ST_UNKNOWN);
   s += "\nconst:MM_WHY_NO_BALANCE=" + CFG_CanonLong((long)MM_WHY_NO_BALANCE);
   s += "\nconst:MM_WHY_NO_SL_DIST=" + CFG_CanonLong((long)MM_WHY_NO_SL_DIST);
   s += "\nconst:MM_WHY_NO_TICKVAL=" + CFG_CanonLong((long)MM_WHY_NO_TICKVAL);
   s += "\nconst:MM_WHY_SLOTS=" + CFG_CanonLong((long)MM_WHY_SLOTS);
   s += "\nconst:RC_DEPOSIT_LOAD_UNKNOWN=" + CFG_CanonDouble(RC_DEPOSIT_LOAD_UNKNOWN);
   s += "\nconst:RC_STATE_HALTED=" + CFG_CanonDouble(RC_STATE_HALTED);
   s += "\nconst:RC_STATE_KILL_PENDING=" + CFG_CanonDouble(RC_STATE_KILL_PENDING);
   s += "\nconst:RC_STATE_RUNNING=" + CFG_CanonDouble(RC_STATE_RUNNING);
   s += "\nconst:STACK_MAX_LEGS=" + CFG_CanonLong((long)STACK_MAX_LEGS);
   s += "\nconst:WAVE5_DIVERG_DEPTH=" + CFG_CanonLong((long)WAVE5_DIVERG_DEPTH);
   return(s);
  }
#endif

#ifdef LAB_ENTRY_18
#define CFG_CONSTANTS_ENUMERATED
int    CFG_ConstKeys() { return(24); }
string CFG_ConstPreimage()
  {
   string s = "";
   s += "\nconst:CFG_FP_SCOPE=" + CFG_CanonString(CFG_FP_SCOPE);
   s += "\nconst:EVTBUS_PREFIX=" + CFG_CanonString(EVTBUS_PREFIX);
   s += "\nconst:HEDGE_TAG=" + CFG_CanonString(HEDGE_TAG);
   s += "\nconst:LAB_ENTRY_TAG=" + CFG_CanonString(LAB_ENTRY_TAG);
   s += "\nconst:MACROGATE_GV_MAX_AGE_SEC=" + CFG_CanonLong((long)MACROGATE_GV_MAX_AGE_SEC);
   s += "\nconst:MG_ALERT_THROTTLE_SEC=" + CFG_CanonLong((long)MG_ALERT_THROTTLE_SEC);
   s += "\nconst:MG_BLOCK_PREFIX=" + CFG_CanonString(MG_BLOCK_PREFIX);
   s += "\nconst:MG_LOTMULT_PREFIX=" + CFG_CanonString(MG_LOTMULT_PREFIX);
   s += "\nconst:MG_MAX_MAGICS=" + CFG_CanonLong((long)MG_MAX_MAGICS);
   s += "\nconst:MG_MAX_ROWS=" + CFG_CanonLong((long)MG_MAX_ROWS);
   s += "\nconst:MG_ST_NEUTRAL=" + CFG_CanonLong((long)MG_ST_NEUTRAL);
   s += "\nconst:MG_ST_RISK_OFF=" + CFG_CanonLong((long)MG_ST_RISK_OFF);
   s += "\nconst:MG_ST_RISK_ON=" + CFG_CanonLong((long)MG_ST_RISK_ON);
   s += "\nconst:MG_ST_STRESS=" + CFG_CanonLong((long)MG_ST_STRESS);
   s += "\nconst:MG_ST_UNKNOWN=" + CFG_CanonLong((long)MG_ST_UNKNOWN);
   s += "\nconst:MM_WHY_NO_BALANCE=" + CFG_CanonLong((long)MM_WHY_NO_BALANCE);
   s += "\nconst:MM_WHY_NO_SL_DIST=" + CFG_CanonLong((long)MM_WHY_NO_SL_DIST);
   s += "\nconst:MM_WHY_NO_TICKVAL=" + CFG_CanonLong((long)MM_WHY_NO_TICKVAL);
   s += "\nconst:MM_WHY_SLOTS=" + CFG_CanonLong((long)MM_WHY_SLOTS);
   s += "\nconst:RC_DEPOSIT_LOAD_UNKNOWN=" + CFG_CanonDouble(RC_DEPOSIT_LOAD_UNKNOWN);
   s += "\nconst:RC_STATE_HALTED=" + CFG_CanonDouble(RC_STATE_HALTED);
   s += "\nconst:RC_STATE_KILL_PENDING=" + CFG_CanonDouble(RC_STATE_KILL_PENDING);
   s += "\nconst:RC_STATE_RUNNING=" + CFG_CanonDouble(RC_STATE_RUNNING);
   s += "\nconst:STACK_MAX_LEGS=" + CFG_CanonLong((long)STACK_MAX_LEGS);
   return(s);
  }
#endif

#ifdef LAB_ENTRY_19
#define CFG_CONSTANTS_ENUMERATED
int    CFG_ConstKeys() { return(24); }
string CFG_ConstPreimage()
  {
   string s = "";
   s += "\nconst:CFG_FP_SCOPE=" + CFG_CanonString(CFG_FP_SCOPE);
   s += "\nconst:EVTBUS_PREFIX=" + CFG_CanonString(EVTBUS_PREFIX);
   s += "\nconst:HEDGE_TAG=" + CFG_CanonString(HEDGE_TAG);
   s += "\nconst:LAB_ENTRY_TAG=" + CFG_CanonString(LAB_ENTRY_TAG);
   s += "\nconst:MACROGATE_GV_MAX_AGE_SEC=" + CFG_CanonLong((long)MACROGATE_GV_MAX_AGE_SEC);
   s += "\nconst:MG_ALERT_THROTTLE_SEC=" + CFG_CanonLong((long)MG_ALERT_THROTTLE_SEC);
   s += "\nconst:MG_BLOCK_PREFIX=" + CFG_CanonString(MG_BLOCK_PREFIX);
   s += "\nconst:MG_LOTMULT_PREFIX=" + CFG_CanonString(MG_LOTMULT_PREFIX);
   s += "\nconst:MG_MAX_MAGICS=" + CFG_CanonLong((long)MG_MAX_MAGICS);
   s += "\nconst:MG_MAX_ROWS=" + CFG_CanonLong((long)MG_MAX_ROWS);
   s += "\nconst:MG_ST_NEUTRAL=" + CFG_CanonLong((long)MG_ST_NEUTRAL);
   s += "\nconst:MG_ST_RISK_OFF=" + CFG_CanonLong((long)MG_ST_RISK_OFF);
   s += "\nconst:MG_ST_RISK_ON=" + CFG_CanonLong((long)MG_ST_RISK_ON);
   s += "\nconst:MG_ST_STRESS=" + CFG_CanonLong((long)MG_ST_STRESS);
   s += "\nconst:MG_ST_UNKNOWN=" + CFG_CanonLong((long)MG_ST_UNKNOWN);
   s += "\nconst:MM_WHY_NO_BALANCE=" + CFG_CanonLong((long)MM_WHY_NO_BALANCE);
   s += "\nconst:MM_WHY_NO_SL_DIST=" + CFG_CanonLong((long)MM_WHY_NO_SL_DIST);
   s += "\nconst:MM_WHY_NO_TICKVAL=" + CFG_CanonLong((long)MM_WHY_NO_TICKVAL);
   s += "\nconst:MM_WHY_SLOTS=" + CFG_CanonLong((long)MM_WHY_SLOTS);
   s += "\nconst:RC_DEPOSIT_LOAD_UNKNOWN=" + CFG_CanonDouble(RC_DEPOSIT_LOAD_UNKNOWN);
   s += "\nconst:RC_STATE_HALTED=" + CFG_CanonDouble(RC_STATE_HALTED);
   s += "\nconst:RC_STATE_KILL_PENDING=" + CFG_CanonDouble(RC_STATE_KILL_PENDING);
   s += "\nconst:RC_STATE_RUNNING=" + CFG_CanonDouble(RC_STATE_RUNNING);
   s += "\nconst:STACK_MAX_LEGS=" + CFG_CanonLong((long)STACK_MAX_LEGS);
   return(s);
  }
#endif

#ifdef LAB_ENTRY_20
#define CFG_CONSTANTS_ENUMERATED
int    CFG_ConstKeys() { return(2); }
string CFG_ConstPreimage()
  {
   string s = "";
   s += "\nconst:CFG_FP_SCOPE=" + CFG_CanonString(CFG_FP_SCOPE);
   s += "\nconst:LAB_ENTRY_TAG=" + CFG_CanonString(LAB_ENTRY_TAG);
   return(s);
  }
#endif

#ifdef LAB_ENTRY_21
#define CFG_CONSTANTS_ENUMERATED
int    CFG_ConstKeys() { return(78); }
string CFG_ConstPreimage()
  {
   string s = "";
   s += "\nconst:CFG_FP_SCOPE=" + CFG_CanonString(CFG_FP_SCOPE);
   s += "\nconst:EMERGENCY_STOPS_ADD=" + CFG_CanonLong((long)EMERGENCY_STOPS_ADD);
   s += "\nconst:EMERGENCY_STOPS_REL=" + CFG_CanonLong((long)EMERGENCY_STOPS_REL);
   s += "\nconst:ENABLE_EVENT_TICK=" + CFG_CanonLong((long)ENABLE_EVENT_TICK);
   s += "\nconst:ENABLE_EVENT_TIMER=" + CFG_CanonLong((long)ENABLE_EVENT_TIMER);
   s += "\nconst:ENABLE_EVENT_TRADE=" + CFG_CanonLong((long)ENABLE_EVENT_TRADE);
   s += "\nconst:ENABLE_SPREAD_METER=" + CFG_CanonLong((long)ENABLE_SPREAD_METER);
   s += "\nconst:ENABLE_STATUS=" + CFG_CanonLong((long)ENABLE_STATUS);
   s += "\nconst:ENABLE_TEST_INDICATORS=" + CFG_CanonLong((long)ENABLE_TEST_INDICATORS);
   s += "\nconst:EVTBUS_PREFIX=" + CFG_CanonString(EVTBUS_PREFIX);
   s += "\nconst:HEDGE_TAG=" + CFG_CanonString(HEDGE_TAG);
   s += "\nconst:LAB_ENTRY_TAG=" + CFG_CanonString(LAB_ENTRY_TAG);
   s += "\nconst:MACROGATE_GV_MAX_AGE_SEC=" + CFG_CanonLong((long)MACROGATE_GV_MAX_AGE_SEC);
   s += "\nconst:MG_ALERT_THROTTLE_SEC=" + CFG_CanonLong((long)MG_ALERT_THROTTLE_SEC);
   s += "\nconst:MG_BLOCK_PREFIX=" + CFG_CanonString(MG_BLOCK_PREFIX);
   s += "\nconst:MG_LOTMULT_PREFIX=" + CFG_CanonString(MG_LOTMULT_PREFIX);
   s += "\nconst:MG_MAX_MAGICS=" + CFG_CanonLong((long)MG_MAX_MAGICS);
   s += "\nconst:MG_MAX_ROWS=" + CFG_CanonLong((long)MG_MAX_ROWS);
   s += "\nconst:MG_ST_NEUTRAL=" + CFG_CanonLong((long)MG_ST_NEUTRAL);
   s += "\nconst:MG_ST_RISK_OFF=" + CFG_CanonLong((long)MG_ST_RISK_OFF);
   s += "\nconst:MG_ST_RISK_ON=" + CFG_CanonLong((long)MG_ST_RISK_ON);
   s += "\nconst:MG_ST_STRESS=" + CFG_CanonLong((long)MG_ST_STRESS);
   s += "\nconst:MG_ST_UNKNOWN=" + CFG_CanonLong((long)MG_ST_UNKNOWN);
   s += "\nconst:MM_WHY_NO_BALANCE=" + CFG_CanonLong((long)MM_WHY_NO_BALANCE);
   s += "\nconst:MM_WHY_NO_SL_DIST=" + CFG_CanonLong((long)MM_WHY_NO_SL_DIST);
   s += "\nconst:MM_WHY_NO_TICKVAL=" + CFG_CanonLong((long)MM_WHY_NO_TICKVAL);
   s += "\nconst:MM_WHY_SLOTS=" + CFG_CanonLong((long)MM_WHY_SLOTS);
   s += "\nconst:MODE_ASK=" + CFG_CanonLong((long)MODE_ASK);
   s += "\nconst:MODE_BID=" + CFG_CanonLong((long)MODE_BID);
   s += "\nconst:MODE_DIGITS=" + CFG_CanonLong((long)MODE_DIGITS);
   s += "\nconst:MODE_HISTORY=" + CFG_CanonLong((long)MODE_HISTORY);
   s += "\nconst:MODE_LOTSIZE=" + CFG_CanonLong((long)MODE_LOTSIZE);
   s += "\nconst:MODE_LOTSTEP=" + CFG_CanonLong((long)MODE_LOTSTEP);
   s += "\nconst:MODE_MARGINREQUIRED=" + CFG_CanonLong((long)MODE_MARGINREQUIRED);
   s += "\nconst:MODE_MAXLOT=" + CFG_CanonLong((long)MODE_MAXLOT);
   s += "\nconst:MODE_MINLOT=" + CFG_CanonLong((long)MODE_MINLOT);
   s += "\nconst:MODE_POINT=" + CFG_CanonLong((long)MODE_POINT);
   s += "\nconst:MODE_TICKSIZE=" + CFG_CanonLong((long)MODE_TICKSIZE);
   s += "\nconst:MODE_TICKVALUE=" + CFG_CanonLong((long)MODE_TICKVALUE);
   s += "\nconst:MODE_TRADEALLOWED=" + CFG_CanonLong((long)MODE_TRADEALLOWED);
   s += "\nconst:MODE_TRADES=" + CFG_CanonLong((long)MODE_TRADES);
   s += "\nconst:OBJPROP_BARSHIFT1=" + CFG_CanonLong((long)OBJPROP_BARSHIFT1);
   s += "\nconst:OBJPROP_BARSHIFT2=" + CFG_CanonLong((long)OBJPROP_BARSHIFT2);
   s += "\nconst:OBJPROP_BARSHIFT3=" + CFG_CanonLong((long)OBJPROP_BARSHIFT3);
   s += "\nconst:OBJPROP_FIBOPRICEVALUE=" + CFG_CanonLong((long)OBJPROP_FIBOPRICEVALUE);
   s += "\nconst:OBJPROP_FIBOVALUE=" + CFG_CanonLong((long)OBJPROP_FIBOVALUE);
   s += "\nconst:OBJPROP_FIRSTLEVEL=" + CFG_CanonLong((long)OBJPROP_FIRSTLEVEL);
   s += "\nconst:OBJPROP_PRICE1=" + CFG_CanonLong((long)OBJPROP_PRICE1);
   s += "\nconst:OBJPROP_PRICE2=" + CFG_CanonLong((long)OBJPROP_PRICE2);
   s += "\nconst:OBJPROP_PRICE3=" + CFG_CanonLong((long)OBJPROP_PRICE3);
   s += "\nconst:OBJPROP_TIME1=" + CFG_CanonLong((long)OBJPROP_TIME1);
   s += "\nconst:OBJPROP_TIME2=" + CFG_CanonLong((long)OBJPROP_TIME2);
   s += "\nconst:OBJPROP_TIME3=" + CFG_CanonLong((long)OBJPROP_TIME3);
   s += "\nconst:OBJPROP_TL_PRICE_BY_SHIFT=" + CFG_CanonLong((long)OBJPROP_TL_PRICE_BY_SHIFT);
   s += "\nconst:OBJPROP_TL_SHIFT_BY_PRICE=" + CFG_CanonLong((long)OBJPROP_TL_SHIFT_BY_PRICE);
   s += "\nconst:ON_TIMER_PERIOD=" + CFG_CanonLong((long)ON_TIMER_PERIOD);
   s += "\nconst:ON_TRADE_REALTIME=" + CFG_CanonLong((long)ON_TRADE_REALTIME);
   s += "\nconst:OP_BUY=" + CFG_CanonLong((long)OP_BUY);
   s += "\nconst:OP_BUYLIMIT=" + CFG_CanonLong((long)OP_BUYLIMIT);
   s += "\nconst:OP_BUYSTOP=" + CFG_CanonLong((long)OP_BUYSTOP);
   s += "\nconst:OP_SELL=" + CFG_CanonLong((long)OP_SELL);
   s += "\nconst:OP_SELLLIMIT=" + CFG_CanonLong((long)OP_SELLLIMIT);
   s += "\nconst:OP_SELLSTOP=" + CFG_CanonLong((long)OP_SELLSTOP);
   s += "\nconst:POINT_FORMAT_RULES=" + CFG_CanonString(POINT_FORMAT_RULES);
   s += "\nconst:PROJECT_ID=" + CFG_CanonString(PROJECT_ID);
   s += "\nconst:RC_DEPOSIT_LOAD_UNKNOWN=" + CFG_CanonDouble(RC_DEPOSIT_LOAD_UNKNOWN);
   s += "\nconst:RC_STATE_HALTED=" + CFG_CanonDouble(RC_STATE_HALTED);
   s += "\nconst:RC_STATE_KILL_PENDING=" + CFG_CanonDouble(RC_STATE_KILL_PENDING);
   s += "\nconst:RC_STATE_RUNNING=" + CFG_CanonDouble(RC_STATE_RUNNING);
   s += "\nconst:SELECT_BY_POS=" + CFG_CanonLong((long)SELECT_BY_POS);
   s += "\nconst:SELECT_BY_TICKET=" + CFG_CanonLong((long)SELECT_BY_TICKET);
   s += "\nconst:SEL_CURRENT=" + CFG_CanonLong((long)SEL_CURRENT);
   s += "\nconst:SEL_INITIAL=" + CFG_CanonLong((long)SEL_INITIAL);
   s += "\nconst:STACK_MAX_LEGS=" + CFG_CanonLong((long)STACK_MAX_LEGS);
   s += "\nconst:TLOBJPROP_TIME1=" + CFG_CanonLong((long)TLOBJPROP_TIME1);
   s += "\nconst:USE_EMERGENCY_STOPS=" + CFG_CanonString(USE_EMERGENCY_STOPS);
   s += "\nconst:VIRTUAL_STOPS_ENABLED=" + CFG_CanonLong((long)VIRTUAL_STOPS_ENABLED);
   s += "\nconst:VIRTUAL_STOPS_TIMEOUT=" + CFG_CanonLong((long)VIRTUAL_STOPS_TIMEOUT);
   return(s);
  }
#endif

#ifndef CFG_CONSTANTS_ENUMERATED
// Reached only when no LAB_ENTRY_* tag was defined -- the same unenumerated case
// InputSurface_gen.mqh handles, and it returns the same kind of visible sentinel rather
// than an empty string that would hash to a perfectly ordinary-looking digest.
int    CFG_ConstKeys() { return(-1); }
string CFG_ConstPreimage() { return("\nconst:UNENUMERATED"); }
#endif

// The entry point LabCore prints. It lives HERE rather than in InputSurface_gen.mqh
// because it now calls BOTH halves, and this is the file that is included late enough
// for every constant macro to exist.
string CFG_Fingerprint()
  {
   if(CFG_SurfaceKeys() < 0 || CFG_ConstKeys() < 0)
      return("UNENUMERATED-NO-BUILD-TAG");
   return(CFG_Sha256Hex(CFG_SurfacePreimage() + CFG_ConstPreimage()));
  }

#endif // BOSS_LOCKED_CONSTANTS_GEN_MQH
