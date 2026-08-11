// ORDER-353 RI01 adapter generated with the canonical zero-constant profile.
// The standalone strategy source has no valued locked constants in its compiled closure;
// metadata macros are intentionally outside the semantic fingerprint surface.
#ifndef ORDER353_LOCKED_CONSTANTS_GEN_MQH
#define ORDER353_LOCKED_CONSTANTS_GEN_MQH
#include "..\..\ea_template\core\ConfigFingerprint.mqh"
int CFG_ConstKeys() { return(0); }
string CFG_ConstPreimage() { return(""); }
string CFG_Fingerprint()
  {
   if(CFG_SurfaceKeys() < 0 || CFG_ConstKeys() < 0)
      return("UNENUMERATED-NO-BUILD-TAG");
   return(CFG_Sha256Hex(CFG_SurfacePreimage() + CFG_ConstPreimage()));
  }
#endif
