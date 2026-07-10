//+------------------------------------------------------------------+
//| AccountSnapshotExporter.mq5 - floating-risk snapshot (ORDER-092)  |
//| Attach to ONE chart on the monitored account (demo/live/real).    |
//| Every 60s writes the CURRENT account state - equity, margin, and  |
//| per-magic floating baskets (the risk DealsExporter's closed-deal  |
//| history can never see) - as CSV to the COMMON Files folder:       |
//|   <Common>\Files\EA_LAB_snapshot_<login>.csv                      |
//| Column layout + atomic tmp->FileMove write live in                |
//| AccountSnapshot_Core.mqh (shared with the tester assert harness). |
//| No trade functions anywhere in this EA or its include - it cannot |
//| touch the account. Full-snapshot overwrite each cycle=idempotent. |
//+------------------------------------------------------------------+
#property strict
#include "AccountSnapshot_Core.mqh"

input int InpPeriodSeconds = 60;   // snapshot interval (seconds)

void Snapshot_Run()
{
   long login = AccountInfoInteger(ACCOUNT_LOGIN);
   if(login == 0)   // terminal not authorized yet - a _0 file is garbage, never write it
   {
      Print("[SNAP] login=0 (not authorized yet) - snapshot skipped");
      return;
   }
   Snap_Export(Snap_FileName());
}

int OnInit()
{
   EventSetTimer(MathMax(10, InpPeriodSeconds));
   Snapshot_Run();   // snapshot immediately on attach (proof it works)
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { EventKillTimer(); }

void OnTimer() { Snapshot_Run(); }

void OnTick() {}
