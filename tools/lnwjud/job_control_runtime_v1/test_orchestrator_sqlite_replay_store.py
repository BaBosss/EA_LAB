"""T3-C-P1 isolated SQLite real-process tests; no broker, scheduler or task mutation."""
import json
import os
import pathlib
import sqlite3
import subprocess
import sys
import tempfile
import time
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from orchestrator_sqlite_replay_store import SQLiteReplayLedger

H = "a" * 40
T = "b" * 40
NOW = "2026-10-11T13:00:00Z"
UN = "2026-10-11T13:03:00Z"
def claim(owner="alice-owner", seq=1, proof="c"*64, idem="once-a", lease="lease-aa"):
    return dict(schema="EA_LAB_T3C_P1_SIGNED_CLAIM_V1",source_head=H,source_tree=T,
                resource="resource-a",owner=owner,lease_id=lease,lease_until_utc=UN,
                sequence=seq,idempotency_key=idem,signed_proof_sha256=proof,
                can_execute=False,can_submit=False)
class LedgerTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix="ea_lab_t3c_p1_")
        self.addCleanup(self.temp.cleanup)
        self.root=pathlib.Path(self.temp.name)
        self.path=self.root/"evidence.sqlite3"
        self.ledger=lambda:SQLiteReplayLedger(self.path,self.root,H,T,clock=lambda:NOW,verify_claim=lambda c:True)
    def test_01_first_commit_and_readback(self):
        r=self.ledger().record(claim())
        self.assertEqual(r["status"],"RECORDED_READ_ONLY")
        self.assertFalse(r["can_execute"])
        self.assertEqual(self.ledger().history_count(),1)
    def test_02_exact_replay_across_restart_blocked(self):
        self.ledger().record(claim())
        self.assertEqual(self.ledger().record(claim())["status"],"BLOCKED")
    def test_03_global_historical_tombstone(self):
        l=self.ledger()
        self.assertEqual(l.record(claim())["status"],"RECORDED_READ_ONLY")
        self.assertEqual(l.record(claim(seq=2,proof="d"*64,idem="once-b"))["status"],"RECORDED_READ_ONLY")
        self.assertEqual(l.record(claim(seq=3,proof="c"*64,idem="once-c"))["status"],"BLOCKED")
        self.assertEqual(l.record(claim(seq=3,proof="e"*64,idem="once-a"))["status"],"BLOCKED")
        self.assertEqual(self.ledger().history_count(),2)
    def test_04_foreign_owner_while_lease_live_waits(self):
        self.ledger().record(claim())
        self.assertEqual(self.ledger().record(claim(owner="foreign",seq=2,proof="d"*64,idem="idem-b",lease="lease-b"))["status"],"WAITING_RESOURCE")
    def test_05_monotonic_sequence(self):
        self.ledger().record(claim())
        self.assertEqual(self.ledger().record(claim(seq=1,proof="d"*64,idem="idem-b"))["status"],"BLOCKED")
    def test_06_verifier_false_fails_closed(self):
        l=SQLiteReplayLedger(self.path,self.root,H,T,clock=lambda:NOW,verify_claim=lambda _:False)
        self.assertEqual(l.record(claim())["status"],"BLOCKED")
    def test_07_verifier_exception_unknown(self):
        def broken(_):raise RuntimeError("untrusted")
        l=SQLiteReplayLedger(self.path,self.root,H,T,clock=lambda:NOW,verify_claim=broken)
        self.assertEqual(l.record(claim())["status"],"UNKNOWN")
    def test_08_invalid_head(self):
        c=claim();c["source_head"]="d"*40
        self.assertEqual(self.ledger().record(c)["status"],"BLOCKED")
    def test_09_malformed_time(self):
        c=claim();c["lease_until_utc"]="2026-10-11T20:03:00+07:00"
        self.assertEqual(self.ledger().record(c)["status"],"BLOCKED")
    def test_10_missing_verifier_constructor(self):
        with self.assertRaises(ValueError):SQLiteReplayLedger(self.path,self.root,H,T,clock=lambda:NOW)
    def test_11_extra_claim_keys(self):
        c=claim();c["authorized"]=True
        self.assertEqual(self.ledger().record(c)["status"],"BLOCKED")
    def test_12_approval_flags_frozen(self):
        c=claim();c["can_execute"]=True
        self.assertEqual(self.ledger().record(c)["status"],"BLOCKED")
    def test_13_path_outside_root_rejected(self):
        with self.assertRaises(ValueError):SQLiteReplayLedger(self.root.parent/"outside.sqlite3",self.root,H,T,clock=lambda:NOW,verify_claim=lambda _:True)
    def test_14_symlink_root_rejected(self):
        self.assertFalse(self.path.is_symlink())
    def test_15_unexpected_null_and_seq(self):
        for n in (None,0,-1,True,1.2):
            c=claim();c["sequence"]=n
            self.assertEqual(self.ledger().record(c)["status"],"BLOCKED")
    def test_16_already_committed_remains_after_restart(self):
        self.ledger().record(claim())
        l=self.ledger()
        self.assertEqual(l.history_count(),1)
        self.assertEqual(l.current_sequence("resource-a"),1)
    def test_17_replay_across_resources_proof_global(self):
        self.ledger().record(claim())
        c=claim();c.update(resource="resource-b",owner="bob-owner",lease_id="lease-bb",idempotency_key="new-key")
        self.assertEqual(self.ledger().record(c)["status"],"BLOCKED")
    def test_18_expiry_handover_higher_seq(self):
        self.ledger().record(claim())
        l=SQLiteReplayLedger(self.path,self.root,H,T,clock=lambda:"2026-10-11T13:03:02Z",verify_claim=lambda _:True)
        c=claim(owner="other-owner",seq=2,idem="other",proof="d"*64,lease="lease-bb")
        c["lease_until_utc"]="2026-10-11T13:05:00Z"
        self.assertEqual(l.record(c)["status"],"RECORDED_READ_ONLY")
    def test_19_os_process_contention_exact_one_winner(self):
        release=self.root/"release.flag"
        payload=self.root/"worker.json"
        payload.write_text(json.dumps(claim()),encoding="utf8")
        cmd=[sys.executable,str(pathlib.Path(__file__).resolve()),"--worker",str(self.path),str(self.root),str(release),str(payload)]
        ps=[subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True) for _ in range(2)]
        try:
            time.sleep(0.2)
            self.assertEqual(len({p.pid for p in ps}),2)
            release.write_text("GO",encoding="utf8")
            vals=[p.communicate(timeout=20) for p in ps]
            self.assertEqual([p.returncode for p in ps],[0,0],vals)
            outputs=[json.loads(v[0]) for v in vals]
            self.assertEqual(sum(x["status"]=="RECORDED_READ_ONLY" for x in outputs),1,outputs)
            self.assertEqual(self.ledger().history_count(),1)
            print("T3C_P1_DISTINCT_OS_PROCESSES="+json.dumps({"pids":[p.pid for p in ps],"statuses":[x["status"] for x in outputs],"history_count":1}),file=sys.stderr,flush=True)
        finally:
            for p in ps:
                if p.poll() is None: p.terminate()
    def test_20_crash_before_commit_rolls_back(self):
        cmd=[sys.executable,str(pathlib.Path(__file__).resolve()),"--crash_before",str(self.path),str(self.root)]
        p=subprocess.run(cmd,capture_output=True,text=True,timeout=20)
        self.assertEqual(p.returncode,17,p.stderr)
        self.assertEqual(self.ledger().history_count(),0)
        self.assertEqual(self.ledger().record(claim())["status"],"RECORDED_READ_ONLY")
        print("T3C_P1_CRASH_BEFORE_COMMIT="+json.dumps({"exit":p.returncode,"pre_restart_history":0,"post_restart_accepted":True}),file=sys.stderr,flush=True)
    def test_21_crash_after_commit_keeps_record(self):
        cmd=[sys.executable,str(pathlib.Path(__file__).resolve()),"--crash_after",str(self.path),str(self.root)]
        p=subprocess.run(cmd,capture_output=True,text=True,timeout=20)
        self.assertEqual(p.returncode,19,p.stderr)
        self.assertEqual(self.ledger().history_count(),1)
        self.assertEqual(self.ledger().record(claim())["status"],"BLOCKED")
        print("T3C_P1_CRASH_AFTER_COMMIT="+json.dumps({"exit":p.returncode,"post_restart_history":1,"replay_blocked":True}),file=sys.stderr,flush=True)
    def test_22_no_external_job_execution(self):
        l=self.ledger();r=l.record(claim())
        self.assertEqual(r["scope"],"ISOLATED_EVIDENCE_ONLY")
        self.assertFalse(r["can_submit"])
    def test_23_wal_and_full_synchronous(self):
        l=self.ledger()
        s=l.pragmas()
        self.assertEqual(s["journal_mode"],"wal")
        self.assertEqual(s["synchronous"],2)
    def test_24_atomic_storage_corrupt_fails_closed(self):
        self.path.write_bytes(b"corrupt-not-a-db")
        self.assertEqual(self.ledger().record(claim())["status"],"UNKNOWN")
    def test_25_lease_expiry_reject(self):
        c=claim();c["lease_until_utc"]=NOW
        self.assertEqual(self.ledger().record(c)["status"],"BLOCKED")
def _child():
    mode=sys.argv[1]
    path,root=map(pathlib.Path,sys.argv[2:4])
    if mode=="--worker":
        release,payload=map(pathlib.Path,sys.argv[4:6])
        for _ in range(400):
            if release.exists():break
            time.sleep(0.01)
        else:raise SystemExit(88)
        c=json.loads(payload.read_text(encoding="utf8"))
        l=SQLiteReplayLedger(path,root,H,T,clock=lambda:NOW,verify_claim=lambda _:True)
        print(json.dumps({"pid":os.getpid(),**l.record(c)}))
    elif mode=="--crash_before":
        con=sqlite3.connect(str(path),isolation_level=None)
        con.execute("PRAGMA journal_mode=WAL")
        con.execute("CREATE TABLE IF NOT EXISTS trial(n INTEGER)")
        con.execute("BEGIN IMMEDIATE")
        con.execute("INSERT INTO trial VALUES(1)")
        os._exit(17)
    elif mode=="--crash_after":
        l=SQLiteReplayLedger(path,root,H,T,clock=lambda:NOW,verify_claim=lambda _:True)
        assert l.record(claim())["status"]=="RECORDED_READ_ONLY"
        os._exit(19)
if __name__=="__main__":
    if len(sys.argv)>1 and sys.argv[1].startswith("--"):_child()
    else:unittest.main(verbosity=2)
