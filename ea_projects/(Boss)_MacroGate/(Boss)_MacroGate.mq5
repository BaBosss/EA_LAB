//+------------------------------------------------------------------+
//| (Boss)_MacroGate.mq5 - ORDER-073 Phase-3 macro-regime watchdog.   |
//| Thin wrapper: owns inputs + timer; all logic in MacroGate_Core.   |
//| Reduces new-entry lot (x LotMult) and optionally blocks NEW orders |
//| on the configured carry-leg magics while the MRIS regime timeline  |
//| reads RISK_OFF / STRESS. NEVER closes a position. Fail-safe clears  |
//| every GlobalVariable it owns on stale/missing data.                |
//| Attach ONE instance on any chart; it gates every listed magic.     |
//+------------------------------------------------------------------+
#property copyright "EA_LAB"
#property version   "1.00"
#property strict

// canonical core lives in the chassis template (so LabCore self-gate + this standalone
// share one source of truth); resolves at compile time from this project folder.
#include "../../ea_template/core/MacroGate_Core.mqh"

input string InpRegimeFile      = "EA_LAB_mris_regime.csv"; // regime timeline CSV (Common\Files)
input bool   InpRegimeInCommon  = true;                     // read from Common\Files (rclone target)
input string InpMagicsCsv       = "";                       // carry magics to gate, e.g. "990201,990203,990110"
input double InpLotMult         = 0.5;                      // new-order lot multiplier while gated (0<..<1)
input bool   InpBlockNew        = true;                     // also veto new orders while gated
input bool   InpTriggerRiskOff  = true;                     // gate on RISK_OFF too (false = STRESS only)
input int    InpOffsetHours     = 0;                        // server = CSV time + N hours (daily: usually 0)
input int    InpStaleMaxHours   = 48;                       // regime file older than this -> fail-safe
input int    InpRowStaleMaxHours= 48;                       // newest usable row older than this -> fail-safe
input int    InpTimerSeconds    = 300;                      // watchdog pass cadence
input int    InpReloadMinutes   = 240;                      // re-read the regime file every N minutes (server clock)

datetime g_lastLoad = 0;

int OnInit()
{
   if(InpLotMult <= 0.0 || InpLotMult >= 1.0)
      Print("[MACROGATE] NOTE LotMult outside (0,1) - the chassis will treat it as no-op (1.0)");
   MG_Setup(InpLotMult, InpBlockNew, InpTriggerRiskOff, InpOffsetHours,
            InpStaleMaxHours, InpRowStaleMaxHours);
   MG_ParseMagics(InpMagicsCsv);
   MG_LoadRegime(InpRegimeFile, InpRegimeInCommon);
   g_lastLoad = TimeCurrent();
   EventSetTimer(InpTimerSeconds < 1 ? 1 : InpTimerSeconds);
   MG_Tick(TimeCurrent());   // act immediately on attach
   return(INIT_SUCCEEDED);
}

void OnTimer()
{
   datetime now = TimeCurrent();
   // periodic reload so the live daily-chain update is picked up (and staleness re-checked)
   if(now - g_lastLoad >= (datetime)(InpReloadMinutes * 60))
   {
      MG_LoadRegime(InpRegimeFile, InpRegimeInCommon);
      g_lastLoad = now;
   }
   MG_Tick(now);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   MG_Deinit();
}

// no per-tick trading logic; the watchdog runs entirely on the timer
void OnTick() { }
