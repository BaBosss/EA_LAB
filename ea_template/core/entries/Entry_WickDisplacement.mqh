//+------------------------------------------------------------------+
//| Entry_WickDisplacement.mqh (V0) - EA_LAB independent derivation.|
//| Closed-bar wick rejection (shift 2) followed by displacement    |
//| confirmation (shift 1). No original-Ziplor fidelity is claimed. |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_ENTRY_WICKDISPLACEMENT_MQH
#define BOSS_LAB_ENTRY_WICKDISPLACEMENT_MQH
#include "IEntry.mqh"

bool ZL22_ValidBar(const double o,const double h,const double l,const double c)
{
   if(!MathIsValidNumber(o) || !MathIsValidNumber(h) ||
      !MathIsValidNumber(l) || !MathIsValidNumber(c)) return false;
   if(h <= l) return false;
   if(h < MathMax(o,c) || l > MathMin(o,c)) return false;
   if(MathAbs(c-o) <= 0.0) return false;
   return true;
}

int ZL22_EvaluateBars(const double rOpen,const double rHigh,
                      const double rLow,const double rClose,
                      const double dOpen,const double dHigh,
                      const double dLow,const double dClose,
                      const double wickBodyRatio,
                      const double displacementBodyFraction,
                      double &strength,double &confidence)
{   strength=0.0;
   confidence=0.0;
   if(!MathIsValidNumber(wickBodyRatio) ||
      !MathIsValidNumber(displacementBodyFraction) ||
      wickBodyRatio <= 0.0 || displacementBodyFraction <= 0.0 ||
      displacementBodyFraction > 1.0) return 0;
   if(!ZL22_ValidBar(rOpen,rHigh,rLow,rClose) ||
      !ZL22_ValidBar(dOpen,dHigh,dLow,dClose)) return 0;

   double rBody=MathAbs(rClose-rOpen);
   double lowerWick=MathMin(rOpen,rClose)-rLow;
   double upperWick=rHigh-MathMax(rOpen,rClose);
   double dRange=dHigh-dLow;
   double dBody=MathAbs(dClose-dOpen);
   if(rBody <= 0.0 || dRange <= 0.0) return 0;

   double displacementFraction=dBody/dRange;
   if(!MathIsValidNumber(displacementFraction) ||
      displacementFraction < displacementBodyFraction) return 0;

   bool buyReject=(lowerWick > upperWick && lowerWick >= wickBodyRatio*rBody);
   bool sellReject=(upperWick > lowerWick && upperWick >= wickBodyRatio*rBody);
   if(buyReject && dClose > dOpen && dClose > rHigh)
   {
      strength=lowerWick/rBody;
      confidence=displacementFraction;
      return 1;
   }
   if(sellReject && dClose < dOpen && dClose < rLow)
   {
      strength=upperWick/rBody;
      confidence=displacementFraction;
      return 2;
   }
   return 0;
}
void Entry_WickDisplacement_Init()
{
   // Stateless closed-bar signal; no indicator handle or broker state.
}

EntrySignal Entry_Evaluate()
{
   double rOpen=iOpen(_Symbol,_Period,2);
   double rHigh=iHigh(_Symbol,_Period,2);
   double rLow=iLow(_Symbol,_Period,2);
   double rClose=iClose(_Symbol,_Period,2);
   double dOpen=iOpen(_Symbol,_Period,1);
   double dHigh=iHigh(_Symbol,_Period,1);
   double dLow=iLow(_Symbol,_Period,1);
   double dClose=iClose(_Symbol,_Period,1);
   double strength=0.0;
   double confidence=0.0;
   int dir=ZL22_EvaluateBars(rOpen,rHigh,rLow,rClose,
                            dOpen,dHigh,dLow,dClose,
                            _22_WickBodyRatio,_22_DisplacementBodyFraction,
                            strength,confidence);
   if(dir==0) return Entry_MakeNone("WickDisplacement neutral/invalid");

   EntrySignal s;
   s.direction=dir;
   s.strength=strength;
   s.confidence=confidence;
   s.valid=true;
   s.reason=(dir==1 ? "WickDisplacement buy" : "WickDisplacement sell");
   return s;
}

#endif // BOSS_LAB_ENTRY_WICKDISPLACEMENT_MQH
