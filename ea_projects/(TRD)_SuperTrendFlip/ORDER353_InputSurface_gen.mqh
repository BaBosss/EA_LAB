//+------------------------------------------------------------------+
//| InputSurface_gen.mqh - GENERATED FILE, DO NOT EDIT BY HAND.       |
//| generator : _triage/factory_os/gen_input_surface.py
//| source    : ea_projects/(TRD)_SuperTrendFlip/(TRD)_SuperTrendFlip_rev05_ri01.mq5
//| generator : canonical _triage/factory_os/gen_input_surface.py (adapter profile)
//|                                                                   |
//| ORDER-710. One block per build tag; the wrapper defines exactly    |
//| one, so exactly one compiles. The strings below are the preimage   |
//| preset.py hashes -- see _fingerprint() there. Editing either side  |
//| alone does not break the build, it breaks the COMPARISON, which is |
//| why check_input_surface_gen.py regenerates this file on every      |
//| commit that touches either one.                                    |
//+------------------------------------------------------------------+
#ifndef BOSS_INPUT_SURFACE_GEN_MQH
#define BOSS_INPUT_SURFACE_GEN_MQH

#include "..\..\ea_template\core\ConfigFingerprint.mqh"

#ifdef LAB_ENTRY_ORDER353_RI01
#define CFG_SURFACE_ENUMERATED
string CFG_BuildTag()    { return("LAB_ENTRY_ORDER353_RI01"); }
int    CFG_SurfaceKeys() { return(48); }
string CFG_SurfacePreimage()
  {
   string s = "scope=" + CFG_FP_SCOPE + "\nbuild=LAB_ENTRY_ORDER353_RI01";
   s += "\n_g00_=" + CFG_CanonString(_g00_);
   s += "\n_00_OptimizeMode=" + CFG_CanonBool(_00_OptimizeMode);
   s += "\n_g01_=" + CFG_CanonString(_g01_);
   s += "\n_01_AtrPeriod=" + CFG_CanonLong((long)_01_AtrPeriod);
   s += "\n_01_Mult=" + CFG_CanonDouble(_01_Mult);
   s += "\n_01_Lookback=" + CFG_CanonLong((long)_01_Lookback);
   s += "\n_g01b_=" + CFG_CanonString(_g01b_);
   s += "\n_01_UseDonchian=" + CFG_CanonBool(_01_UseDonchian);
   s += "\n_01_DonBars=" + CFG_CanonLong((long)_01_DonBars);
   s += "\n_g02_=" + CFG_CanonString(_g02_);
   s += "\n_02_ExitMode=" + CFG_CanonLong((long)_02_ExitMode);
   s += "\n_02_TpAtrMult=" + CFG_CanonDouble(_02_TpAtrMult);
   s += "\n_02_SlAtrMult=" + CFG_CanonDouble(_02_SlAtrMult);
   s += "\n_02_SlBufferAtr=" + CFG_CanonDouble(_02_SlBufferAtr);
   s += "\n_g03_=" + CFG_CanonString(_g03_);
   s += "\n_03_UseEma=" + CFG_CanonBool(_03_UseEma);
   s += "\n_03_EmaPeriod=" + CFG_CanonLong((long)_03_EmaPeriod);
   s += "\n_g03b_=" + CFG_CanonString(_g03b_);
   s += "\n_03_UseER=" + CFG_CanonBool(_03_UseER);
   s += "\n_03_ErPeriod=" + CFG_CanonLong((long)_03_ErPeriod);
   s += "\n_03_ErMin=" + CFG_CanonDouble(_03_ErMin);
   s += "\n_g07_=" + CFG_CanonString(_g07_);
   s += "\n_07_UsePyramid=" + CFG_CanonBool(_07_UsePyramid);
   s += "\n_07_MaxAdds=" + CFG_CanonLong((long)_07_MaxAdds);
   s += "\n_07_AddAtAtr=" + CFG_CanonDouble(_07_AddAtAtr);
   s += "\n_07_AddLotFactor=" + CFG_CanonDouble(_07_AddLotFactor);
   s += "\n_07_BasketMaxLossPct=" + CFG_CanonDouble(_07_BasketMaxLossPct);
   s += "\n_g08_=" + CFG_CanonString(_g08_);
   s += "\n_08_ReMode=" + CFG_CanonLong((long)_08_ReMode);
   s += "\n_08_MaxReEntries=" + CFG_CanonLong((long)_08_MaxReEntries);
   s += "\n_08_PbAtrMult=" + CFG_CanonDouble(_08_PbAtrMult);
   s += "\n_08_StoK=" + CFG_CanonLong((long)_08_StoK);
   s += "\n_08_StoD=" + CFG_CanonLong((long)_08_StoD);
   s += "\n_08_StoSlow=" + CFG_CanonLong((long)_08_StoSlow);
   s += "\n_08_StoLevel=" + CFG_CanonDouble(_08_StoLevel);
   s += "\n_08_SrBars=" + CFG_CanonLong((long)_08_SrBars);
   s += "\n_08_SrAtrMult=" + CFG_CanonDouble(_08_SrAtrMult);
   s += "\n_g04_=" + CFG_CanonString(_g04_);
   s += "\n_04_Buys=" + CFG_CanonBool(_04_Buys);
   s += "\n_04_Sells=" + CFG_CanonBool(_04_Sells);
   s += "\n_04_LotSize=" + CFG_CanonDouble(_04_LotSize);
   s += "\n_g05_=" + CFG_CanonString(_g05_);
   s += "\n_05_DailyLossPct=" + CFG_CanonDouble(_05_DailyLossPct);
   s += "\n_05_EmergencyDdPct=" + CFG_CanonDouble(_05_EmergencyDdPct);
   s += "\n_g06_=" + CFG_CanonString(_g06_);
   s += "\n_06_Magic=" + CFG_CanonLong((long)_06_Magic);
   s += "\n_06_Deviation=" + CFG_CanonLong((long)_06_Deviation);
   s += "\n_06_AllowLive=" + CFG_CanonBool(_06_AllowLive);
   return(s);
  }
#endif

#ifndef CFG_SURFACE_ENUMERATED
// No LAB_ENTRY_* tag was defined by the time this file was included. Inputs.mqh falls
// back to LAB_ENTRY_11 when the wrapper defines none, so reaching here means this file
// was included BEFORE Inputs.mqh.
string CFG_BuildTag()    { return("NO_BUILD_TAG"); }
int    CFG_SurfaceKeys() { return(-1); }
string CFG_SurfacePreimage() { return("UNENUMERATED"); }
#endif

// ORDER-730 MOVED CFG_Fingerprint() OUT OF THIS FILE, into LockedConstants_gen.mqh.
// It now hashes the surface AND the locked constants, and the constant macros are
// defined by headers LabCore includes AFTER this one -- so an entry point here could
// not name them. Not a preference: a reference to an undefined macro does not compile.
//
// THE UNENUMERATED BRANCH RETURNS A NON-HEX SENTINEL, NOT A HASH, and that rule moved
// with it. An earlier version hashed the string "UNENUMERATED" and the comment claimed
// the result "cannot be mistaken for a real fingerprint" -- it is a perfectly ordinary
// 64-character lowercase digest, and the claim was the opposite of what the code did.

#endif // BOSS_INPUT_SURFACE_GEN_MQH
