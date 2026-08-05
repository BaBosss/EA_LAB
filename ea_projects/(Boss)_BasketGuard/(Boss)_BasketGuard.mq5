//+------------------------------------------------------------------+
//| (Boss)_BasketGuard.mq5 - single-magic basket loss guard.        |
//|                                                                  |
//| Built for NuiIndy (magic 1524) on real account 159475669, which  |
//| shares that account with GoldReaper, MatchaGrid, LondonConso and |
//| EA_BREAKOUT_XAU. An account-level equity stop would liquidate    |
//| all of them to bound one. This guard touches EXACTLY ONE magic,  |
//| across every symbol, and is blind to everything else.            |
//|                                                                  |
//| It places no trades of its own. Attach ONE instance per magic,   |
//| on any chart/timeframe - it is timer-driven, so the chart symbol |
//| and whether that symbol ticks are both irrelevant.               |
//|                                                                  |
//| 🔴 THIS IS A SENSOR, NOT A BOUND. Do not describe it as one.     |
//| (Owner decision 2026-07-27, after the Codex audit.)              |
//|                                                                  |
//| It sums only positions OPEN AT THIS INSTANT. A loss realized     |
//| between two polls -- by a broker stop-out, or by the guarded EA  |
//| closing its own legs -- disappears from the comparison, and the  |
//| next poll reports ARMED after the episode has already blown      |
//| through the configured percentage several times over. Worse,     |
//| Exness stop-out is magic-blind: a 1524 blow-up that reaches it   |
//| liquidates the other magics anyway, the exact outcome per-magic  |
//| scope was chosen to prevent. The broker acts first and nothing   |
//| here can outrun it.                                              |
//|                                                                  |
//| The REAL bound is structural and lives outside this file: give   |
//| magic 1524 its own cent account funded with what the owner will  |
//| accept losing outright. That is the plan of record. This EA is   |
//| the interim early-warning sensor, and its value is the usage     |
//| percentage in the status file, not the cut. Full finding list:   |
//| AUDIT_2026-07-27_CODEX.md                                        |
//|                                                                  |
//| WHY THIS EXISTS: NuiIndy's edge is escalation, not signal - it   |
//| earns by surviving adverse excursions, so its own CutLoss_Percent|
//| has never fired and cannot be relied on to bound the account.    |
//| An unfired switch is an untested switch. This guard is the       |
//| external number that makes the worst case computable.            |
//|                                                                  |
//| WHAT IT DOES NOT DO: it does not improve the strategy, reduce    |
//| its drawdown, or make it safe to size up. It converts an         |
//| unbounded tail into a known, chosen loss. That is all.           |
//|                                                                  |
//| DEFAULTS TO DRY RUN. In dry run it logs and alerts exactly as it |
//| would in live mode but closes nothing, so you can watch it for a |
//| few sessions and see the usage percentage move before handing it |
//| the trigger. Flip InpDryRun=false only once you believe it.      |
//+------------------------------------------------------------------+
#property copyright "EA_LAB"
#property version   "1.00"
#property description "Closes ONE magic's basket at a chosen % of balance, then blocks its re-entry until a human clears the halt."

#include <Trade\Trade.mqh>
#include "BasketGuard_Core.mqh"

//--- Pinned at COMPILE TIME, deliberately not inputs.
//--- A .set file or a saved chart profile can supply any input value, and an
//--- old one supplying InpMagic=8001 would point this EA at GoldReaper and it
//--- would faithfully liquidate it. Inputs cannot be trusted to name the
//--- target when the whole purpose is "touch this one thing and nothing else".
//--- Retargeting therefore requires editing and recompiling, which is a
//--- deliberate act that leaves a diff. (Codex audit 2026-07-27, P0-2.)
#define BG_PINNED_MAGIC     1524
#define BG_PINNED_ACCOUNT   159475669

input long   InpMagic          = 1524;    // must equal the compile-time pin, or the EA refuses to start
input double InpMaxLossPct     = 15.0;    // cut when this magic's floating loss reaches this % of the baseline
input bool   InpUseFixedBase   = false;   // false = live balance (self-scaling) / true = InpFixedBaseline
input double InpFixedBaseline  = 0.0;     // account-currency baseline when InpUseFixedBase=true
input bool   InpDryRun         = true;    // TRUE = log only, close nothing. Start here.
input int    InpTimerSeconds   = 5;       // poll period
input int    InpHeartbeatMin   = 30;      // write a status line at least every N minutes
input int    InpCloseRetries   = 5;       // passes over the basket per cut attempt
input int    InpSlippage       = 30;      // points
input string InpStatusFile     = "EA_LAB_basketguard.csv";  // Common\Files, for the monitoring chain

CTrade   g_trade;
bool     g_halted        = false;
long     g_checks        = 0;
//--- fires counts REAL close attempts only. would_fire counts dry-run
//--- breaches. Keeping them apart is the whole point: this lab's bar reads a
//--- guard with fires=0 as UNTESTED, so a counter that ticks up during a dry
//--- run would manufacture evidence that the kill path had been exercised
//--- when nothing was ever sent to the broker. (Codex audit 2026-07-27, P1-6.)
long     g_fires         = 0;
long     g_wouldFire     = 0;
long     g_reentries     = 0;   // times the guarded EA opened again AFTER the halt
datetime g_lastHeartbeat = 0;
datetime g_lastAlert     = 0;
string   g_haltGvName    = "";
string   g_haltFile      = "";

//+------------------------------------------------------------------+
//| Halt persistence.                                                |
//|                                                                  |
//| Two independent stores on purpose. The GlobalVariable survives a |
//| terminal restart but is invisible outside MT5 and expires after  |
//| four weeks untouched; the file in Common\Files is visible to the |
//| monitoring chain and to a human over RDP, and does not expire.   |
//| A halt that quietly lapses back to ARMED would be worse than no  |
//| halt at all, because the log would still read HALTED in history. |
//+------------------------------------------------------------------+
bool BG_LoadHalt()
{
   if(GlobalVariableCheck(g_haltGvName)) return true;
   if(FileIsExist(g_haltFile, FILE_COMMON)) return true;
   return false;
}

void BG_PersistHalt()
{
   GlobalVariableSet(g_haltGvName, (double)TimeCurrent());
   int h = FileOpen(g_haltFile, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(h != INVALID_HANDLE)
   {
      FileWrite(h, StringFormat("HALTED %s magic=%I64d account=%I64d",
                                TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
                                InpMagic, AccountInfoInteger(ACCOUNT_LOGIN)));
      FileWrite(h, "Delete this file AND the BG_HALT global variable to re-arm.");
      FileClose(h);
   }
   else
      Print("BasketGuard: could not write halt file ", g_haltFile,
            " err=", GetLastError(), " - GlobalVariable halt still stands");
}

//+------------------------------------------------------------------+
void BG_AlertThrottled(const string msg)
{
   Print("BasketGuard: ", msg);
   if(TimeLocal() - g_lastAlert < BG_ALERT_THROTTLE_SEC) return;
   g_lastAlert = TimeLocal();
   Alert("BasketGuard: ", msg);
}

//+------------------------------------------------------------------+
//| Walk every open position, count and sum ONLY the watched magic.  |
//|                                                                  |
//| Profit + swap, NOT commission. Closing fees are not visible on an |
//| open position, so this number reads slightly BETTER than what     |
//| would actually land in the balance -- the bias is toward cutting  |
//| LATE, never early. On this Exness Standard Cent account trading   |
//| commission is zero, so today the gap is only slippage.            |
//|                                                                  |
//| It also sees only what is OPEN RIGHT NOW. Anything the guarded EA |
//| or a broker stop-out already realized is invisible here, which is |
//| the structural limit of this whole design -- see                  |
//| AUDIT_2026-07-27_CODEX.md, finding P0-1.                          |
//+------------------------------------------------------------------+
double BG_BasketFloating(int &positions, double &lots)
{
   double total = 0.0;
   positions = 0;
   lots = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      positions++;
      lots  += PositionGetDouble(POSITION_VOLUME);
      total += PositionGetDouble(POSITION_PROFIT)
             + PositionGetDouble(POSITION_SWAP);   // NOT commission - see AUDIT_2026-07-27_CODEX.md
   }
   return total;
}

//+------------------------------------------------------------------+
//| Close every position of the watched magic. Returns how many are  |
//| still open afterwards - 0 means the basket is gone.              |
//|                                                                  |
//| Retries because a hedging account can hold dozens of legs across |
//| several symbols and a single pass will lose races against fills, |
//| requotes, and the EA itself opening one more while we work.      |
//+------------------------------------------------------------------+
int BG_CloseBasket()
{
   for(int pass = 0; pass < InpCloseRetries; pass++)
   {
      bool any = false;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;   // the only filter that matters
         any = true;
         if(!g_trade.PositionClose(ticket, InpSlippage))
            Print("BasketGuard: close failed ticket=", ticket,
                  " ret=", g_trade.ResultRetcode(), " ", g_trade.ResultRetcodeDescription());
      }
      if(!any) break;
      Sleep(300);
   }

   int left = 0;
   double lots = 0.0;
   BG_BasketFloating(left, lots);
   return left;
}

//+------------------------------------------------------------------+
//| positionsNow is what is open AT THE MOMENT OF WRITING, not what was
//| open when the poll started. After a cut that matters: passing the
//| pre-cut count would stamp CUT_FAILED on a cut that actually worked.
void BG_WriteStatus(const int positionsNow, const double floatingPL, const double limitAbs)
{
   int h = FileOpen(InpStatusFile, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(h == INVALID_HANDLE) return;
   if(FileSize(h) == 0) FileWrite(h, BG_StatusHeader());
   FileSeek(h, 0, SEEK_END);
   FileWrite(h, BG_StatusLine(TimeCurrent(), InpMagic, positionsNow, floatingPL, limitAbs,
                              g_halted, InpDryRun, g_checks, g_fires, g_wouldFire, g_reentries));
   FileClose(h);
}

//+------------------------------------------------------------------+
int OnInit()
{
   //--- Pin checks first. Everything below is only meaningful once we know
   //--- this instance is pointed at the thing it was built for.
   if(InpMagic != BG_PINNED_MAGIC)
   {
      PrintFormat("BasketGuard: InpMagic=%I64d but this build is pinned to %d. "
                  "Refusing to start - a stale .set must never be able to aim this EA at another magic.",
                  InpMagic, BG_PINNED_MAGIC);
      return INIT_PARAMETERS_INCORRECT;
   }
   long login = AccountInfoInteger(ACCOUNT_LOGIN);
   if(login != BG_PINNED_ACCOUNT)
   {
      PrintFormat("BasketGuard: account %I64d is not the pinned account %d. Refusing to start - "
                  "magic %d on a different account is a different EA's positions.",
                  login, BG_PINNED_ACCOUNT, BG_PINNED_MAGIC);
      return INIT_PARAMETERS_INCORRECT;
   }
   if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
   {
      Print("BasketGuard: this account is not HEDGING. Refusing to start - under netting a single "
            "position can carry deals from several magics, so closing by ticket would take out "
            "magics this EA must never touch.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(BG_LossLimitAbs(1000.0, InpMaxLossPct) <= 0.0)
   {
      Print("BasketGuard: InpMaxLossPct=", InpMaxLossPct,
            " is not a limit that can bound anything (must be >0 and <=90). Refusing to start.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpUseFixedBase && InpFixedBaseline <= 0.0)
   {
      Print("BasketGuard: InpUseFixedBase=true needs a positive InpFixedBaseline. Refusing to start.");
      return INIT_PARAMETERS_INCORRECT;
   }

   g_haltGvName = StringFormat("BG_HALT_%I64d_%I64d", AccountInfoInteger(ACCOUNT_LOGIN), InpMagic);
   g_haltFile   = StringFormat("EA_LAB_bg_halt_%I64d_%I64d.txt", AccountInfoInteger(ACCOUNT_LOGIN), InpMagic);
   g_halted     = BG_LoadHalt();

   g_trade.SetAsyncMode(false);
   g_trade.SetExpertMagicNumber(0);          // this EA opens nothing; it never stamps a magic

   //--- OnTimer is the ONLY thing that ever runs. If registration fails and we
   //--- ignore it, this EA sits on the chart doing literally nothing while its
   //--- startup line says "armed" -- an inert guard that reads as a live one.
   if(!EventSetTimer(InpTimerSeconds < 1 ? 1 : InpTimerSeconds))
   {
      PrintFormat("BasketGuard: EventSetTimer failed (err=%d). Refusing to start - "
                  "OnTimer is the only trigger, so a failed timer means a guard that watches nothing.",
                  GetLastError());
      return INIT_FAILED;
   }

   PrintFormat("BasketGuard armed: magic=%I64d limit=%.1f%% of %s mode=%s state=%s",
               InpMagic, InpMaxLossPct,
               (InpUseFixedBase ? "fixed baseline" : "live balance"),
               (InpDryRun ? "DRY RUN (closes nothing)" : "LIVE"),
               (g_halted ? "HALTED (clear the halt file/GV to re-arm)" : "ARMED"));
   if(InpDryRun)
      Print("BasketGuard: DRY RUN - it will log and alert exactly as if live, but will NOT close anything.");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   PrintFormat("BasketGuard stopped (reason=%d). checks=%I64d fires=%I64d would_fire=%I64d reentries=%I64d state=%s",
               reason, g_checks, g_fires, g_wouldFire, g_reentries, (g_halted ? "HALTED" : "ARMED"));
}

//+------------------------------------------------------------------+
void OnTimer()
{
   g_checks++;

   int    positions = 0;
   double lots      = 0.0;
   double floating  = BG_BasketFloating(positions, lots);

   double baseline  = InpUseFixedBase ? InpFixedBaseline : AccountInfoDouble(ACCOUNT_BALANCE);
   double limitAbs  = BG_LossLimitAbs(baseline, InpMaxLossPct);

   if(limitAbs <= 0.0 && positions > 0)
      BG_AlertThrottled(StringFormat("baseline %.2f gives no usable limit - guard is INERT, not safe", baseline));

   BG_Action action = BG_Decide(positions, floating, limitAbs, g_halted);

   if(action == BG_ACTION_CUT)
   {
      string head = StringFormat("magic %I64d floating %.2f reached %.1f%% limit (%.2f of %.2f baseline), %d positions %.2f lots",
                                 InpMagic, floating, InpMaxLossPct, limitAbs, baseline, positions, lots);
      if(InpDryRun)
      {
         g_wouldFire++;
         BG_AlertThrottled("DRY RUN would CUT: " + head + " - nothing closed");
      }
      else
      {
         g_fires++;
         BG_AlertThrottled("CUT: " + head);
         int left = BG_CloseBasket();
         g_halted = true;          // halt regardless: a failed cut is not a reason to re-arm
         BG_PersistHalt();
         if(left > 0)
         {
            // NOT throttled. This is the one message that means the guard
            // tried and did not succeed -- AutoTrading off, market closed,
            // trade context busy. Throttling it would hide the exact case
            // where the account is unprotected and nobody knows.
            Alert(StringFormat("BasketGuard CUT FAILED: %d position(s) of magic %I64d still open - close them by hand NOW",
                               left, InpMagic));
            PrintFormat("BasketGuard: CUT FAILED, %d position(s) of magic %I64d survived", left, InpMagic);
         }
         else
            Print("BasketGuard: basket closed, halt persisted. Clear ", g_haltFile,
                  " and global variable ", g_haltGvName, " to re-arm.");
         positions = left;         // report what is open NOW, not what was open before the cut
      }
      BG_WriteStatus(positions, floating, limitAbs);
      g_lastHeartbeat = TimeCurrent();
      return;
   }

   if(action == BG_ACTION_HOLD)
   {
      // The guarded EA opened again after we halted it. We can only close
      // after the fact, so this repeats until a human removes that EA from
      // its chart. Every cycle costs a spread; the counter is what makes
      // that cost visible instead of letting it accumulate silently.
      g_reentries++;
      if(InpDryRun)
         BG_AlertThrottled(StringFormat("DRY RUN: halted, and %d position(s) of magic %I64d are open - would close them (re-entry #%I64d)",
                                        positions, InpMagic, g_reentries));
      else
      {
         int left = BG_CloseBasket();
         BG_AlertThrottled(StringFormat("halted: magic %I64d re-entered and was closed again (#%I64d, %d left). It will keep doing this until you remove that EA from its chart.",
                                        InpMagic, g_reentries, left));
         positions = left;
      }
      BG_WriteStatus(positions, floating, limitAbs);
      g_lastHeartbeat = TimeCurrent();
      return;
   }

   if(TimeCurrent() - g_lastHeartbeat >= (datetime)(InpHeartbeatMin * 60))
   {
      g_lastHeartbeat = TimeCurrent();
      BG_WriteStatus(positions, floating, limitAbs);
      PrintFormat("BasketGuard heartbeat: magic=%I64d pos=%d lots=%.2f floating=%.2f limit=%.2f usage=%.1f%% checks=%I64d fires=%I64d would_fire=%I64d",
                  InpMagic, positions, lots, floating, limitAbs,
                  BG_UsagePct(floating, limitAbs), g_checks, g_fires, g_wouldFire);
   }
}
