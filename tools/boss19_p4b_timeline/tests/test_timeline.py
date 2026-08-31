import csv, importlib.util, tempfile, unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

MOD=Path(__file__).resolve().parents[1]/"build_timeline.py"
spec=importlib.util.spec_from_file_location("p4tl",MOD); p4=importlib.util.module_from_spec(spec); spec.loader.exec_module(p4)

class TimelineTests(unittest.TestCase):
    def test_fenwick_nearest_rank(self):
        f=p4.Fenwick([1,2,3,4,5])
        for x in [1,2,3,4,5]: f.add(x,1)
        self.assertEqual(f.quantile(.2),1); self.assertEqual(f.quantile(.6),3); self.assertEqual(f.quantile(.95),5)
        f.add(1,-1); self.assertEqual(f.quantile(.2),2)

    def make_bars(self,n=400):
        t=datetime(2019,1,1,tzinfo=timezone.utc); out=[]
        for i in range(n):
            c=100+i*.01; out.append({"open_time":t+timedelta(hours=i),"close_time":t+timedelta(hours=i+1),
                                      "open":c-.01,"high":c+.05,"low":c-.05,"close":c})
        return out

    def test_local_quantile_is_strictly_prior(self):
        a=self.make_bars(); b=[dict(x) for x in a]; b[350]["close"]+=50; b[350]["high"]=b[350]["close"]+.05
        ea=p4.local_indicator_events(a); eb=p4.local_indicator_events(b)
        self.assertEqual(ea[350][1]["local_qtrend"],eb[350][1]["local_qtrend"])

    def test_transition_zero_boundary(self):
        bars=self.make_bars(320)
        ev=p4.local_indicator_events(bars)
        self.assertEqual(len(ev),320)
        self.assertTrue(all(x[0]==bars[i]["close_time"] for i,x in enumerate(ev)))

    def test_macro_stale_boundary_is_strictly_older_than_120h(self):
        eligible=datetime(2025,1,1,tzinfo=timezone.utc)
        stale=p4.macro_stale_event_time(eligible)
        self.assertEqual(stale,eligible+timedelta(hours=120,seconds=1))
        self.assertLess(eligible+timedelta(hours=120),stale)

    def test_quarantine_covers_full_transition_server_dates(self):
        with tempfile.TemporaryDirectory() as td:
            q=Path(td)/"q.csv"
            q.write_text("time_server,open,high,low,close,tick_volume,spread,real_volume,reason\n2025.03.09 12:00:00,1,1,1,1,0,0,0,UNKNOWN_DST_TRANSITION\n2025.11.02 12:00:00,1,1,1,1,0,0,0,UNKNOWN_DST_TRANSITION\n",encoding="utf-8")
            self.assertEqual(p4.quarantine_intervals(q),[
                (datetime(2025,3,8,21,0,tzinfo=timezone.utc),datetime(2025,3,9,22,0,tzinfo=timezone.utc)),
                (datetime(2025,11,1,21,0,tzinfo=timezone.utc),datetime(2025,11,2,22,0,tzinfo=timezone.utc))])

    def test_quarantine_suppresses_internal_events_and_restores_at_end(self):
        start=datetime(2025,3,8,21,0,tzinfo=timezone.utc); end=datetime(2025,3,9,22,0,tzinfo=timezone.utc)
        before=start-timedelta(minutes=15); inside=start+timedelta(minutes=15); last_inside=end-timedelta(minutes=15); after=end+timedelta(minutes=15)
        mk=lambda state:{"local_state":state,"local_bar_close_utc":"x","local_d":1,"local_qtrend":1,"vol_state":"NORMAL","vol_bar_close_utc":"x","vol_natr_pct":1,"vol_q20":1,"vol_q80":1,"vol_q95":1,"local_unknown_reason":""}
        out=p4.apply_quarantine_intervals([(before,mk("BEFORE")),(inside,mk("INSIDE")),(last_inside,mk("RESTORE")),(after,mk("AFTER"))],[(start,end)])
        mapping=dict(out)
        self.assertNotIn(inside,mapping); self.assertNotIn(last_inside,mapping)
        self.assertEqual(mapping[start]["local_state"],"UNKNOWN")
        self.assertEqual(mapping[start]["local_unknown_reason"],"DST_QUARANTINE_ENVELOPE")
        self.assertEqual(mapping[end]["local_state"],"RESTORE")
        self.assertEqual(mapping[after]["local_state"],"AFTER")

    def test_unknown_macro_and_local_are_fail_closed(self):
        self.assertEqual(p4.unknown_macro()["macro_state"],"UNKNOWN")
        self.assertTrue(p4.unknown_macro()["macro_partial"])
        self.assertEqual(p4.unknown_local()["local_state"],"UNKNOWN")
        self.assertEqual(p4.unknown_local()["vol_state"],"UNKNOWN")

    def test_mris_output_ri_matches_three_decimal_source_contract(self):
        self.assertEqual(p4.mris_output_ri(5/13), 0.385)
        self.assertEqual(p4.mris_output_ri(-7/13), -0.538)
        self.assertIsNone(p4.mris_output_ri(None))

    def test_macro_signals_frozen_examples(self):
        row={"close":100.0,"sma200":101.0,"atr20":1.0,"r5":-4.0,"usable":True}
        self.assertEqual(p4.macro_signal("AUDJPY",row,None)[0],-2.0)
        self.assertEqual(p4.macro_signal("BTCUSD",row,None)[0],-2.0)
        v=dict(row,close=31.0,sma200=30.0,r5=0.0); self.assertEqual(p4.macro_signal("VIX",v,None)[0],-2.0)

if __name__=="__main__": unittest.main(verbosity=2)
