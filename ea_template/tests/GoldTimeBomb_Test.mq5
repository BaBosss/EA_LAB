#property strict
#define GOLD_TIME_BOMB_TEST
#include "../core/entries/Entry_GoldTimeBomb.mqh"

// BEGIN DF02 TEST CASES
int gt_checks = 0;
int gt_failures = 0;
void GT_Check(const string name, const bool ok)
{
   gt_checks++;
   if(!ok) { gt_failures++; Print("FAIL " + name); }
}
bool GT_Equal(const double a, const double b) { return MathAbs(a - b) < 0.00000001; }
int GT_RunTests()
{
   gt_checks = 0; gt_failures = 0;
   GT_Bomb up;
   GT_Bomb down;
   up.Reset(); down.Reset();
   // Parent MDL_TimeBombUp/Down 775..911; no rolling-min/max anchor.
   GT_Check("up first observation anchors", !up.Trigger(1, 100, 100, 10, 10, 1));
   GT_Check("up below threshold", !up.Trigger(1, 109, 109, 10, 10, 1));
   GT_Check("up exact price and time boundary", up.Trigger(1, 110, 110, 10, 10, 1));
   GT_Check("trigger resets anchor and time", up.anchor == 110 && up.stamp == 110);
   GT_Check("up timeout does not fire", !up.Trigger(1, 130, 121, 10, 10, 1));
   GT_Check("timeout reanchors", up.anchor == 130 && up.stamp == 121);
   GT_Check("second window can fire", up.Trigger(1, 140, 122, 10, 10, 1));
   up.Reset();
   up.Trigger(1, 100, 100, 10, 10, 1);
   GT_Check("adverse move does not reanchor", !up.Trigger(1, 80, 105, 10, 10, 1) && up.anchor == 100);
   GT_Check("timeout boundary resets without movement", !up.Trigger(1, 90, 110, 10, 10, 1) && up.anchor == 90);
   GT_Check("down initializes independently", !down.Trigger(-1, 200, 100, 10, 10, 1));
   GT_Check("down exact threshold", down.Trigger(-1, 190, 110, 10, 10, 1));
   GT_Check("down reset", down.anchor == 190 && down.stamp == 110);
   GT_Check("down wrong direction", !down.Trigger(-1, 210, 111, 10, 10, 1));
   // Flat gate takes only position count; any number of pending orders is irrelevant.
   for(int pending = 0; pending <= 3; pending++)
      GT_Check("pending-only remains flat", GT_Flat(0));
   GT_Check("one position blocks", !GT_Flat(1));
   GT_Check("many positions block", !GT_Flat(7));
   GT_Check("bar zero fails closed", !up.Once(0));
   GT_Check("first prior bar passes", up.Once(60));
   GT_Check("same bar cannot repeat", !up.Once(60));
   GT_Check("history regression cannot repeat", !up.Once(30));
   GT_Check("new bar passes", up.Once(120));
   GT_Check("buy/sell bar gates independent", down.Once(60));
   up.Reset();
   GT_Check("restart clears bar gate", up.Once(60));
   GT_Grid grid;
   grid.Reset();
   GT_Check("restart grid zero", grid.offset == 0);
   GT_Check("initial BUY zero offset is market", GT_OrderKind(1, 100 + grid.offset, 100) == 0);
   GT_Check("initial SELL zero offset is market", GT_OrderKind(-1, 100 - grid.offset, 100) == 0);
   GT_Check("equal close does not write state", !grid.AddBranch(1, true, 100, 100, 60) && grid.offset == 0);
   GT_Check("BUY favorable writes 2x", grid.AddBranch(1, true, 101, 100, 60) && grid.offset == 120);
   GT_Check("nearby rejection retains written state", GT_Nearby(101, 100, grid.offset) && grid.offset == 120);
   GT_Check("flat cycle retains offset", GT_Flat(0) && grid.offset == 120);
   GT_Check("later BUY initial is stop", GT_OrderKind(1, 100 + grid.offset, 100) == 1);
   GT_Check("later SELL initial is stop", GT_OrderKind(-1, 100 - grid.offset, 100) == 1);
   GT_Check("BUY adverse branch", grid.AddBranch(1, false, 99, 100, 60));
   GT_Check("SELL favorable branch", grid.AddBranch(-1, true, 99, 100, 60));
   GT_Check("SELL adverse branch", grid.AddBranch(-1, false, 101, 100, 60));
   GT_Check("favorable and adverse not interchangeable", !grid.AddBranch(-1, true, 101, 100, 60));
   GT_Check("nearby upper edge included", GT_Nearby(160, 100, 120));
   GT_Check("nearby lower edge included", GT_Nearby(40, 100, 120));
   GT_Check("outside upper edge allowed", !GT_Nearby(160.01, 100, 120));
   GT_Check("outside lower edge allowed", !GT_Nearby(39.99, 100, 120));
   grid.Reset();
   GT_Check("restart after adds restores market consequence", GT_OrderKind(1, 100 + grid.offset, 100) == 0);
   GT_Check("today is next server midnight", GT_Today(172801) == 259200);
   GT_Check("midnight gets following midnight", GT_Today(172800) == 259200);
   GT_Check("three digit pip rule", GT_Equal(GT_Pip(0.001), 0.01));
   GT_Check("five digit pip rule", GT_Equal(GT_Pip(0.00001), 0.0001));
   GT_Check("six digit pip rule", GT_Equal(GT_Pip(0.000001), 0.0001));
   GT_Check("other point unchanged", GT_Equal(GT_Pip(0.01), 0.01));
   // Parent DynamicLots 6781, AlignLots 5129: 1% * 10000 / 1000 = 0.1.
   GT_Check("block free margin formula", GT_Equal(GT_Lots(1, 10000, 1000, 0.01, 0.01, 100, true), 0.1));
   GT_Check("free margin doubles volume", GT_Equal(GT_Lots(1, 20000, 1000, 0.01, 0.01, 100, true), 0.2));
   GT_Check("one-lot margin changes volume", GT_Equal(GT_Lots(1, 10000, 2000, 0.01, 0.01, 100, true), 0.05));
   GT_Check("Freeze_lot is not a fixed lot", GT_Equal(GT_Lots(0.0001, 10000, 1000, 0.01, 0.01, 100, true), 0.01));
   GT_Check("nearest rounding rounds up", GT_Equal(GT_Lots(1, 16600, 1000, 0.01, 0.01, 100, true), 0.17));
   GT_Check("nearest rounding rounds down", GT_Equal(GT_Lots(1, 16400, 1000, 0.01, 0.01, 100, true), 0.16));
   GT_Check("broker maximum clamps", GT_Equal(GT_Lots(100, 10000, 1000, 0.01, 0.01, 2, true), 2));
   GT_Check("lot step can raise minimum", GT_Equal(GT_Lots(0, 10000, 1000, 0.1, 0.01, 2, true), 0.1));
   GT_Check("margin read failure refuses", GT_Lots(1, 10000, 1000, 0.01, 0.01, 100, false) == 0);
   GT_Check("zero one-lot margin refuses", GT_Lots(1, 10000, 0, 0.01, 0.01, 100, true) == 0);
   GT_Check("invalid lot step refuses", GT_Lots(1, 10000, 1000, 0, 0.01, 100, true) == 0);
   GT_Check("no free margin refuses", GT_Lots(1, 0, 1000, 0.01, 0.01, 100, true) == 0);
   GT_Trail trail;
   trail.Reset();
   GT_Check("group trailing starts immediately below entry", trail.Update("1", 1, 200, 100, 99, 30, 1, 1) && trail.stop == 70);
   GT_Check("group trade-set change requests SL reset", trail.reset_sl);
   GT_Check("no update below step", !trail.Update("1", 1, 200, 100.9, 99.9, 30, 1, 1));
   GT_Check("exact step updates", trail.Update("1", 1, 200, 101, 100, 30, 1, 1) && trail.stop == 71);
   GT_Check("adverse quote alone does not loosen stop", !trail.Update("1", 1, 200, 80, 79, 30, 1, 1) && trail.stop == 71);
   GT_Check("new ticket resets and can loosen", trail.Update("12", 2, 180, 80, 79, 30, 1, 1) && trail.stop == 50 && trail.reset_sl);
   GT_Check("ticket removed resets", trail.Update("2", 1, 180, 70, 69, 30, 1, 1) && trail.stop == 40);
   GT_Check("equal hedged lots do not trail", !trail.Update("23", 0, 0, 70, 69, 30, 1, 1));
   GT_Check("net short uses bid", trail.Update("234", -1, 100, 81, 80, 30, 1, 1) && trail.stop == 110);
   GT_Check("short favorable step", trail.Update("234", -1, 100, 80, 79, 30, 1, 1) && trail.stop == 109);
   GT_Check("short adverse quote holds", !trail.Update("234", -1, 100, 90, 89, 30, 1, 1));
   GT_Check("buy SL broker limit", GT_TrailLimit(1, 100, 99, 2) == 97);
   GT_Check("sell SL broker limit", GT_TrailLimit(-1, 100, 101, 2) == 103);
   GT_Check("missing SL can be added", GT_ModifySL(1, 0, 70, false));
   GT_Check("buy improves only absent reset", GT_ModifySL(1, 70, 71, false) && !GT_ModifySL(1, 70, 69, false));
   GT_Check("sell improves only absent reset", GT_ModifySL(-1, 70, 69, false) && !GT_ModifySL(-1, 70, 71, false));
   GT_Check("trade change allows SL reset", GT_ModifySL(1, 70, 60, true));
   GT_Check("wrong-side buy group SL rejects", GT_AlignSourceSL(1, 110, 0, 101, 100, 2, 0.01) == -1);
   GT_Check("wrong-side sell group SL rejects", GT_AlignSourceSL(-1, 90, 0, 100, 101, 2, 0.01) == -1);
   GT_Check("too-close buy SL aligns", GT_AlignSourceSL(1, 100, 0, 101, 100, 2, 0.01) == 98);
   GT_Check("too-close sell SL aligns", GT_AlignSourceSL(-1, 101, 0, 100, 101, 2, 0.01) == 103);
   GT_Check("valid distant SL unchanged", GT_AlignSourceSL(1, 70, 0, 101, 100, 2, 0.01) == 70);
   GT_Check("same SL bypasses alignment", GT_AlignSourceSL(1, 110, 110, 101, 100, 2, 0.01) == 110);
   GT_Check("ftTP40 creates no TP", GT_PreserveTP(0, 40) == 0);
   GT_Check("different ftTP remains noncausal", GT_PreserveTP(0, 9999) == 0);
   GT_Check("existing TP preserved", GT_PreserveTP(123, 40) == 123);
   GT_Check("each TP independently preserved", GT_PreserveTP(456, 40) == 456);
   trail.Reset();
   GT_Check("restart clears group stop", trail.stop == 0 && trail.trades == "");
   return gt_failures;
}
// END DF02 TEST CASES

int OnInit()
{
   int failures = GT_RunTests();
   PrintFormat("DF02: %d checks, %d failures", gt_checks, failures);
   return failures == 0 ? INIT_SUCCEEDED : INIT_FAILED;
}
void OnTick() {}
