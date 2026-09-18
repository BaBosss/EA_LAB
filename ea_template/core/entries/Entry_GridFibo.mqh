#ifndef EA_LAB_ENTRY_GRIDFIBO_MQH
#define EA_LAB_ENTRY_GRIDFIBO_MQH

// Whole source-native engine, not a generic EntrySignal. Single instance.
#ifdef LAB_ENTRY_21
bool g_df03_ready = false;

bool DF03_B21ConfigValid()
{
   if(DryRun || _0_Magic != (long)_21_DF03_MagicStart || _MG_SelfGate)
   {
      Print("[INIT] B21 refuses DryRun, magic mismatch or unsupported _MG_SelfGate");
      return false;
   }
   return true;
}

// The source timer must continue after a refused simulated tick, so this
// guard reports permission instead of returning from DF03_SourceOnTimer.
bool DF03_B21PreTick()
{
   RuntimeIdentity_Update();
   if(RiskControl_CheckDD()) return false;
   if(RiskControl_IsHalted()) return false;
   return true;
}

// Called only at the native BuyNow/SellNow send seam, once per send attempt.
// No source close/modify operation enters this hook. Heat needs no init state.
bool DF03_B21NewOrder(const string symbol, const long magic, const int type, double &lot)
{
   if(!g_df03_ready || !Exec_IdentityIsMine(symbol, magic)) return false;
   if(type != 0 && type != 1) return false; // native OP_BUY / OP_SELL only
   if(Exec_NewsBlocked() || Exec_MacroBlocked() || !Exec_SpreadOK()) return false;
   if(!RiskControl_AllowNewOrder()) return false;
   if(Exec_CountAll() == 0 && Exec_CountPending() == 0 && !RiskControl_AcctGateOK()) return false;
   if(!MathIsValidNumber(lot) || lot <= 0.0) return false;
   double minv = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxv = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(!MathIsValidNumber(minv) || !MathIsValidNumber(maxv) || !MathIsValidNumber(step)
      || minv <= 0.0 || maxv < minv || step <= 0.0) return false;
   lot = Exec_NormalizeLot(RiskControl_ClampLot(lot * Exec_MacroLotMult()));
   if(!MathIsValidNumber(lot) || lot <= 0.0) return false;
   return Basket_HeatCheckPass(symbol, lot);
}

#include "../../compat/df03/DF03_TemplateEngine.mqh"
#else
// Raw compatibility probe keeps the original generated control.
#include "../../compat/df03/DF03_Generated.mqh"
#endif

void DF03_AdapterInit() { DF03_SourceOnInit(); }
void DF03_AdapterTick() { DF03_SourceOnTick(); }
void DF03_AdapterTrade() { DF03_SourceOnTrade(); }
void DF03_AdapterTimer() { DF03_SourceOnTimer(); }
void DF03_AdapterChartEvent(const int id, const long& lparam,
                          const double& dparam, const string& sparam)
{
   DF03_SourceOnChartEvent(id, lparam, dparam, sparam);
}
void DF03_AdapterDeinit(const int reason) { DF03_SourceOnDeinit(reason); }

#endif
