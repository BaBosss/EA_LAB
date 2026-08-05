//+------------------------------------------------------------------+
//| ConfigFingerprint.mqh (V2) - ORDER-710. The EA half of the        |
//| effective-configuration fingerprint (design section 5.6).          |
//|                                                                   |
//| WHAT THIS ANSWERS: "is the .set on this chart the .set we          |
//| validated?" A .set file is a REQUEST; what the binary ends up      |
//| holding is the answer, and until now nothing compared the two.     |
//| Every unlisted input is filled from the PER-TERMINAL tester cache  |
//| (memory mt5-tester-cache-nondeterminism), so two terminals can     |
//| load the same file and run different configurations.               |
//|                                                                   |
//| THE CONTRACT WITH THE PYTHON SIDE. The preimage built here must    |
//| be byte-identical to the one _triage/factory_os/preset.py hashes   |
//| in _fingerprint(). That is why doubles go in as their IEEE-754     |
//| BITS and not as text: Python's repr() and C's %g disagree about    |
//| `1.0` vs `1` and about exponent width, and a fingerprint that      |
//| depended on two printf implementations agreeing would be a claim   |
//| about formatting rather than about configuration.                  |
//|                                                                   |
//| Log-only. Nothing here may influence a trading decision.           |
//+------------------------------------------------------------------+
#ifndef BOSS_CONFIG_FINGERPRINT_MQH
#define BOSS_CONFIG_FINGERPRINT_MQH

// The scope label, and it is DERIVED FROM WHAT IS HASHED, not decoration: this preimage now
// covers every input the build exposes AND every locked constant that reaches it, which is what
// design section 5.6 asks for. ORDER-730 moved it here from "surface_only"; ORDER-710 had
// deliberately left it narrow while the constants were unenumerated, because an incomplete claim
// gets an incomplete name (memory name-it-honestly-when-you-cannot-prove-it).
//
// preset.py's _constant_scope() carries the same two names and picks between them by WHETHER IT
// WAS GIVEN CONSTANTS -- so this label and that one can only agree while both sides really do
// hash the same two halves. check_input_surface_gen.py G3 is what holds them together, and G5
// is what stops this line moving without the enumeration moving with it.
#define CFG_FP_SCOPE "surface+constants"

union CFG_DoubleBits
  {
   double            d;
   ulong             u;
  };

//+------------------------------------------------------------------+
//| lowercase hex, fixed width. Python writes '%016x' / '%02x'.       |
//+------------------------------------------------------------------+
string CFG_HexLower(const ulong value, const int digits)
  {
   string hex = "";
   for(int shift = (digits - 1) * 4; shift >= 0; shift -= 4)
      hex += StringSubstr("0123456789abcdef", (int)((value >> shift) & 0xF), 1);
   return(hex);
  }

//+------------------------------------------------------------------+
//| double -> "0x" + 16 hex digits of its IEEE-754 big-endian bits.   |
//| -0.0 is normalised to +0.0: the two compare equal and mean the    |
//| same lot size, but their bits differ, so leaving them apart would |
//| move the fingerprint without moving the configuration.            |
//+------------------------------------------------------------------+
string CFG_CanonDouble(const double v)
  {
   CFG_DoubleBits bits;
   bits.d = (v == 0.0) ? 0.0 : v;
   return("0x" + CFG_HexLower(bits.u, 16));
  }

string CFG_CanonLong(const long v)     { return(IntegerToString(v)); }
string CFG_CanonBool(const bool v)     { return(v ? "true" : "false"); }
string CFG_CanonString(const string v) { return(v); }

//+------------------------------------------------------------------+
//| sha256 of the UTF-8 bytes, lowercase hex - Python's hexdigest().  |
//| Returns "" on failure. An empty fingerprint is a VISIBLE failure; |
//| a hash of the empty string would be a valid-looking 64-char lie.  |
//+------------------------------------------------------------------+
string CFG_Sha256Hex(const string text)
  {
   uchar data[], key[], hash[];
   int n = StringToCharArray(text, data, 0, WHOLE_ARRAY, CP_UTF8);
   if(n <= 1)
      return("");
   ArrayResize(data, n - 1);        // drop the terminating NUL StringToCharArray appends
   ArrayResize(key, 0);
   if(CryptEncode(CRYPT_HASH_SHA256, data, key, hash) != 32)
      return("");
   string hex = "";
   for(int i = 0; i < 32; i++)
      hex += CFG_HexLower((ulong)hash[i], 2);
   return(hex);
  }

#endif // BOSS_CONFIG_FINGERPRINT_MQH
