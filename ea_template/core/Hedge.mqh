//+------------------------------------------------------------------+
//| Hedge.mqh (V2) - defensive opposite-direction lock.              |
//|  0 HEDGE_OFF (default, early-return, identical to old stub)       |
//|  1 HEDGE_LOCK: when basket floating DD% >= _H_TriggerDDPct, open  |
//|    ONE opposite-direction hedge sized _H_Ratio x net exposed lots |
//|    (capped by RC_MaxLot + deposit-load cage). Release (close the  |
//|    hedge) when DD recovers past _H_ReleaseDDPct.                   |
//|                                                                   |
//|  Hedge positions carry the EA magic + a "H" comment tag so they   |
//|  are identifiable and never double-counted as directional legs.   |
//|  All orders go through Exec_Open (dry-run + broker lot normalize  |
//|  + RC_MaxLot final ceiling). No direct OrderSend.                 |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_HEDGE_MQH
#define BOSS_LAB_HEDGE_MQH
#include "Inputs.mqh"
#include "Execution.mqh"
#include "RiskControl.mqh"

#define HEDGE_TAG "H"   // comment marker: LAB_ENTRY_TAG + " H"

bool Hedge_Enabled() { return (HedgeMode != HEDGE_OFF); }

// is this position one of our hedge legs? (magic-scoped + comment tag)
bool Hedge_PosIsHedge(const int index)
{
   return Exec_PosIsHedge(index);
}

// count our live hedge legs
int Hedge_Count()
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(Hedge_PosIsHedge(i)) n++;
   return n;
}

// net directional lots EXCLUDING hedge legs (buy vol - sell vol)
double Hedge_NetDirectionalLots()
{
   double net = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsMine(i)) continue;
      if(Hedge_PosIsHedge(i)) continue;   // skip our own hedge legs
      double v    = PositionGetDouble(POSITION_VOLUME);
      long   type = PositionGetInteger(POSITION_TYPE);
      net += (type == POSITION_TYPE_BUY ? v : -v);
   }
   return net;
}

// close every live hedge leg (release)
void Hedge_CloseAll()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Hedge_PosIsHedge(i)) continue;
      ulong tk = PositionGetInteger(POSITION_TICKET);
      if(!DryRun) g_trade.PositionClose(tk);
   }
}

// basket floating DD% of balance (positive number when losing)
double Hedge_BasketDDPct()
{
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal <= 0.0) return 0.0;
   double p = Exec_BasketProfit();
   if(p >= 0.0) return 0.0;
   return 100.0 * (-p) / bal;
}

void Hedge_OnTick()
{
   if(HedgeMode == HEDGE_OFF) return;   // OFF path, identical to old stub

   int hedgeLegs = Hedge_Count();
   double ddPct  = Hedge_BasketDDPct();

   // RELEASE: basket recovered past the release threshold -> unwind hedge
   if(hedgeLegs > 0)
   {
      double rel = (_H_ReleaseDDPct > 0.0 ? _H_ReleaseDDPct : 0.0);
      if(ddPct <= rel) Hedge_CloseAll();
      return;   // one hedge action per tick; never stack hedges
   }

   // OPEN: only when floating DD breaches the trigger
   if(_H_TriggerDDPct <= 0.0) return;
   if(ddPct < _H_TriggerDDPct) return;

   double net = Hedge_NetDirectionalLots();
   if(MathAbs(net) < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) return;

   // hedge is opposite the net exposure, sized as a ratio of it (capped)
   int    dir     = (net > 0.0 ? 2 : 1);   // net long -> sell hedge, net short -> buy hedge
   double ratio   = (_H_Ratio > 0.0 ? _H_Ratio : 1.0);
   double hedgeLot = MathAbs(net) * ratio;

   // caps: deposit-load cage gate + explicit hedge ceiling; RC_MaxLot + broker
   // normalize happen inside Exec_Open. _H_MaxLot=0 means "use RC_MaxLot only".
   if(!RiskControl_AllowNewOrder()) return;
   if(_H_MaxLot > 0.0 && hedgeLot > _H_MaxLot) hedgeLot = _H_MaxLot;

   // no SL/TP on the hedge leg - it is released by the DD logic above
   Exec_Open(dir, hedgeLot, 0.0, 0.0, LAB_ENTRY_TAG + " " + HEDGE_TAG);
}

#endif // BOSS_LAB_HEDGE_MQH
