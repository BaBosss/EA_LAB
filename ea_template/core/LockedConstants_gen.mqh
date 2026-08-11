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
int    CFG_ConstKeys() { return(23); }
string CFG_ConstPreimage()
  {
   string s = "";
   s += "\nconst:CFG_FP_SCOPE=" + CFG_CanonString(CFG_FP_SCOPE);
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
int    CFG_ConstKeys() { return(23); }
string CFG_ConstPreimage()
  {
   string s = "";
   s += "\nconst:CFG_FP_SCOPE=" + CFG_CanonString(CFG_FP_SCOPE);
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
int    CFG_ConstKeys() { return(23); }
string CFG_ConstPreimage()
  {
   string s = "";
   s += "\nconst:CFG_FP_SCOPE=" + CFG_CanonString(CFG_FP_SCOPE);
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
int    CFG_ConstKeys() { return(23); }
string CFG_ConstPreimage()
  {
   string s = "";
   s += "\nconst:CFG_FP_SCOPE=" + CFG_CanonString(CFG_FP_SCOPE);
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
int    CFG_ConstKeys() { return(23); }
string CFG_ConstPreimage()
  {
   string s = "";
   s += "\nconst:CFG_FP_SCOPE=" + CFG_CanonString(CFG_FP_SCOPE);
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
int    CFG_ConstKeys() { return(23); }
string CFG_ConstPreimage()
  {
   string s = "";
   s += "\nconst:CFG_FP_SCOPE=" + CFG_CanonString(CFG_FP_SCOPE);
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
int    CFG_ConstKeys() { return(24); }
string CFG_ConstPreimage()
  {
   string s = "";
   s += "\nconst:CFG_FP_SCOPE=" + CFG_CanonString(CFG_FP_SCOPE);
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
int    CFG_ConstKeys() { return(23); }
string CFG_ConstPreimage()
  {
   string s = "";
   s += "\nconst:CFG_FP_SCOPE=" + CFG_CanonString(CFG_FP_SCOPE);
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
