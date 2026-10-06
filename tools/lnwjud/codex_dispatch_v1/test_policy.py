from __future__ import annotations

import copy
import hashlib
import json
import unittest

from policy import CodexDispatchPolicy, DispatchRefusal, profile_hash


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


class Lock:
    def __enter__(self): return self
    def __exit__(self, *args): return False


class Audit:
    kind = "DURABLE_AUDIT_STORE_V1"
    def __init__(self): self.rows = {}; self.fail_finalize = False
    def with_lock(self): return Lock()
    def get(self, key): return copy.deepcopy(self.rows.get(key))
    def prepare(self, key, request_hash, payload):
        if key in self.rows: raise AssertionError("duplicate prepare")
        self.rows[key] = {"status": "PREPARED", "request_sha256": request_hash, "payload": copy.deepcopy(payload)}
    def finalize(self, key, request_hash, receipt):
        if self.fail_finalize:
            self.fail_finalize = False
            raise DispatchRefusal("INJECTED_LOST_ACK")
        row = self.rows[key]; assert row["request_sha256"] == request_hash
        row["status"] = "FINAL"; row["receipt"] = copy.deepcopy(receipt)


class LaneReader:
    def __init__(self):
        self.lane = {"lane_id":"lane-a","state":"RUNNING","head_sha":"a"*40,"worktree":r"D:\EA_LAB_CONTROL\w\lane-a","branch":"ct/lane-a","clean":True,"path_identity_verified":True,"budget_available":True}
    def get_lane(self, lane_id):
        if lane_id != self.lane["lane_id"]: raise DispatchRefusal("LANE_MISSING")
        return copy.deepcopy(self.lane)


class ContractReader:
    def __init__(self, data): self.data=data
    def get_contract_bytes(self, digest): return self.data


class Catalog:
    def __init__(self, profiles): self.profiles=profiles
    def get_profile(self, profile_id): return copy.deepcopy(self.profiles.get(profile_id))


class Executor:
    kind = "TYPED_CODEX_EXECUTOR_V1"
    def __init__(self): self.jobs={}; self.calls=[]; self.fail_after_dispatch=False
    def find_existing(self, dispatch_id): return copy.deepcopy(self.jobs.get(dispatch_id))
    def dispatch(self, plan):
        self.calls.append(copy.deepcopy(plan)); receipt={"dispatch_id":plan["dispatch_id"],"job_id":"job-"+str(len(self.calls))};self.jobs[plan["dispatch_id"]]=copy.deepcopy(receipt)
        if self.fail_after_dispatch:
            self.fail_after_dispatch=False
            raise DispatchRefusal("INJECTED_LOST_ACK")
        return receipt


def make_profile(profile_id, kind, runner, sandbox, source_mutation, states):
    body={"profile_id":profile_id,"kind":kind,"runner":runner,"model":"gpt-approved-server-profile","reasoning_effort":"high","sandbox_policy":sandbox,"max_timeout_seconds":900,"allowed_states":states,"source_mutation_allowed":source_mutation}
    return {**body,"profile_sha256":profile_hash(body)}


def fixture(kind="SOURCE_OWNER_SIDE"):
    contract=b"frozen codex dispatch contract\n"; contract_sha=sha(contract)
    source=make_profile("source-owner-v1","SOURCE_OWNER_SIDE","JOB_CONTROL_FIXED_CODEX_SOURCE","OWNER_SIDE_NO_CODEX_SANDBOX",True,["RUNNING"])
    review=make_profile("review-ro-v1","REVIEW_READ_ONLY","CONTROL_TOWER_RELAY_READ_ONLY","READ_ONLY",False,["REVIEW"])
    lane=LaneReader(); audit=Audit(); source_exec=Executor(); review_exec=Executor(); now=lambda:"2026-10-06T10:00:00Z"
    policy=CodexDispatchPolicy(lane_reader=lane,contract_reader=ContractReader(contract),profile_catalog=Catalog({source["profile_id"]:source,review["profile_id"]:review}),audit=audit,executors={"JOB_CONTROL_FIXED_CODEX_SOURCE":source_exec,"CONTROL_TOWER_RELAY_READ_ONLY":review_exec},now_utc=now)
    profile=source if kind=="SOURCE_OWNER_SIDE" else review
    if kind=="REVIEW_READ_ONLY": lane.lane["state"]="REVIEW"
    prompt="Inspect exact task; do not broaden scope."
    req={"schema":"LNWJUD_CODEX_DISPATCH_REQUEST_V1","request_id":"req-1","idempotency_key":"key-1","actor":"ChatGPT-MainCT","lane_id":"lane-a","expected_head":"a"*40,"contract_sha256":contract_sha,"profile_id":profile["profile_id"],"prompt":prompt,"prompt_sha256":sha(prompt.encode()),"timeout_seconds":600,"created_utc":"2026-10-06T09:59:59Z"}
    return policy,req,lane,audit,source_exec,review_exec,source,review


class PolicyTests(unittest.TestCase):
    def refusal(self, code, fn):
        with self.assertRaises(DispatchRefusal) as cm: fn()
        self.assertEqual(cm.exception.code,code)

    def test_source_dispatch_uses_server_profile_and_exact_lane(self):
        p,r,_,_,src,_,profile,_=fixture();out=p.dispatch(r);self.assertEqual(out["outcome"],"DISPATCHED");self.assertEqual(len(src.calls),1);plan=src.calls[0];self.assertEqual(plan["head_sha"],"a"*40);self.assertEqual(plan["worktree"],r"D:\EA_LAB_CONTROL\w\lane-a");self.assertEqual(plan["model"],profile["model"]);self.assertEqual(plan["sandbox_policy"],"OWNER_SIDE_NO_CODEX_SANDBOX")

    def test_review_dispatch_is_read_only_profile(self):
        p,r,_,_,_,review,_,profile=fixture("REVIEW_READ_ONLY");out=p.dispatch(r);self.assertEqual(out["profile_id"],profile["profile_id"]);self.assertEqual(review.calls[0]["sandbox_policy"],"READ_ONLY")

    def test_exact_replay_returns_same_receipt_no_redispatch(self):
        p,r,_,_,src,_,_,_=fixture();a=p.dispatch(r);b=p.dispatch(copy.deepcopy(r));self.assertEqual(a,b);self.assertEqual(len(src.calls),1)

    def test_lost_ack_after_dispatch_adopts_existing_without_duplicate(self):
        p,r,_,audit,src,_,_,_=fixture();audit.fail_finalize=True;self.refusal("INJECTED_LOST_ACK",lambda:p.dispatch(r));self.assertEqual(len(src.calls),1);out=p.dispatch(r);self.assertEqual(out["outcome"],"ADOPTED_EXISTING");self.assertEqual(len(src.calls),1)

    def test_unknown_client_execution_fields_refused(self):
        p,r,_,_,src,_,_,_=fixture();r["executable"]="powershell.exe";self.refusal("MALFORMED_REQUEST",lambda:p.dispatch(r));self.assertEqual(src.calls,[])

    def test_client_cannot_choose_model_or_sandbox(self):
        p,r,_,_,src,_,_,_=fixture();r["model"]="surprise-paid-route";self.refusal("MALFORMED_REQUEST",lambda:p.dispatch(r));self.assertEqual(src.calls,[])

    def test_prompt_hash_mismatch_refused(self):
        p,r,_,_,src,_,_,_=fixture();r["prompt"]+=" drift";self.refusal("PROMPT_HASH_MISMATCH",lambda:p.dispatch(r));self.assertEqual(src.calls,[])

    def test_stale_head_refused(self):
        p,r,lane,_,src,_,_,_=fixture();lane.lane["head_sha"]="c"*40;self.refusal("STALE_LANE_IDENTITY",lambda:p.dispatch(r));self.assertEqual(src.calls,[])

    def test_dirty_worktree_refused(self):
        p,r,lane,_,src,_,_,_=fixture();lane.lane["clean"]=False;self.refusal("WORKTREE_IDENTITY_UNPROVEN",lambda:p.dispatch(r));self.assertEqual(src.calls,[])

    def test_budget_exhaustion_refused(self):
        p,r,lane,_,src,_,_,_=fixture();lane.lane["budget_available"]=False;self.refusal("BUDGET_EXHAUSTED",lambda:p.dispatch(r));self.assertEqual(src.calls,[])

    def test_wrong_lane_state_for_profile_refused(self):
        p,r,lane,_,src,_,_,_=fixture();lane.lane["state"]="WAITING";self.refusal("PROFILE_STATE_REFUSED",lambda:p.dispatch(r));self.assertEqual(src.calls,[])

    def test_timeout_above_profile_refused(self):
        p,r,_,_,src,_,_,_=fixture();r["timeout_seconds"]=901;self.refusal("TIMEOUT_EXCEEDS_PROFILE",lambda:p.dispatch(r));self.assertEqual(src.calls,[])

    def test_future_request_refused(self):
        p,r,_,_,src,_,_,_=fixture();r["created_utc"]="2027-01-01T00:00:00Z";self.refusal("INVALID_OR_FUTURE_TIME",lambda:p.dispatch(r));self.assertEqual(src.calls,[])

    def test_idempotency_drift_refused(self):
        p,r,_,_,src,_,_,_=fixture();p.dispatch(r);r2=copy.deepcopy(r);r2["request_id"]="req-2";self.refusal("IDEMPOTENCY_DRIFT",lambda:p.dispatch(r2));self.assertEqual(len(src.calls),1)

    def test_contract_mismatch_refused(self):
        p,r,_,_,src,_,_,_=fixture();r["contract_sha256"]="f"*64;self.refusal("CONTRACT_MISMATCH",lambda:p.dispatch(r));self.assertEqual(src.calls,[])

    def test_tampered_profile_hash_refused(self):
        p,r,_,_,src,_,source,_=fixture();source["model"]="tampered";p.profile_catalog.profiles[source["profile_id"]]=source;self.refusal("PROFILE_HASH_MISMATCH",lambda:p.dispatch(r));self.assertEqual(src.calls,[])

    def test_review_profile_cannot_claim_source_mutation(self):
        p,r,_,_,_,review,_,profile=fixture("REVIEW_READ_ONLY");profile["source_mutation_allowed"]=True;body=dict(profile);body.pop("profile_sha256");profile["profile_sha256"]=profile_hash(body);p.profile_catalog.profiles[profile["profile_id"]]=profile;self.refusal("PROFILE_AUTHORITY_MISMATCH",lambda:p.dispatch(r));self.assertEqual(review.calls,[])

    def test_source_profile_must_use_job_control_fixed_runner(self):
        p,r,_,_,src,_,profile,_=fixture();profile["runner"]="CONTROL_TOWER_RELAY_READ_ONLY";body=dict(profile);body.pop("profile_sha256");profile["profile_sha256"]=profile_hash(body);p.profile_catalog.profiles[profile["profile_id"]]=profile;self.refusal("PROFILE_AUTHORITY_MISMATCH",lambda:p.dispatch(r));self.assertEqual(src.calls,[])


if __name__ == "__main__":
    suite=unittest.defaultTestLoader.loadTestsFromTestCase(PolicyTests)
    result=unittest.TextTestRunner(verbosity=2).run(suite)
    print(json.dumps({"suite":"LNWJUD_CODEX_DISPATCH_V1","total":result.testsRun,"passed":result.testsRun-len(result.failures)-len(result.errors),"failed":len(result.failures)+len(result.errors),"real_codex_launches":0,"runtime_activated":False},sort_keys=True))
    raise SystemExit(0 if result.wasSuccessful() else 1)
