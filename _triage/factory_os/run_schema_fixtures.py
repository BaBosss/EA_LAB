"""
run_schema_fixtures.py - REAL JSON Schema validation of _triage/factory_os/schemas.json.

WHY THIS EXISTS
  Three audits in one day kept landing on the same complaint: the schema appendix had
  never been run through a JSON Schema implementation. check_schema_structure.py is a
  linter - it reads the schema as a dictionary and asserts things about its shape. It
  cannot tell you whether a real instance validates, and the third audit proved the gap
  is not theoretical: it would have caught 0 of the 7 semantic regressions it was built
  for, and it reported STRUCTURE OK on a commit where the design and the schema
  contradicted each other about the run model.

  This runs `ajv` (Draft 2020-12) over one instance per audit finding. Every case names
  the finding it guards. A negative case that stops failing is a contract that quietly
  disappeared.

  THE RULE THIS ENFORCES, from the third audit's own recommendation:
  do not call a finding fixed until a negative fixture for that specific defect fails
  before the fix and passes after.

REQUIRES  ajv-cli  (npm install -g ajv-cli)
USAGE     python _triage/factory_os/run_schema_fixtures.py
EXIT      0 = every case behaved as declared · 1 = at least one did not
"""
import json, os, subprocess, sys, tempfile

SCHEMA = '_triage/factory_os/schemas.json'

OWNER = {"entity": "OwnerRef", "owner_type": "taskboard_order", "path": "AGENT_TASKBOARD.md",
         "commit_oid": "a" * 40, "blob_oid": "b" * 40, "raw_sha256": "c" * 64}

HYP = {"entity": "Hypothesis", "hypothesis_id": "B14-H01", "boss_family": 14, "revision": 1,
       "architecture_digest": "0" * 16,
       "module_set": [{"token": "LAB_CAP_STACK", "module_version": "1", "stability": "CERTIFIABLE"}],
       "coupling_class": "COUPLED", "experimental": False, "status": "REGISTERED",
       "preregistration_ref": OWNER}


def case(name, guards, expect, instance):
    return {"name": name, "guards": guards, "expect": expect, "instance": instance}


def without(d, *keys):
    out = json.loads(json.dumps(d))
    for k in keys:
        out.pop(k, None)
    return out


def with_(d, **kw):
    out = json.loads(json.dumps(d))
    out.update(kw)
    return out


CASES = [
    # ---- the original P0: a root that accepted anything -------------------------
    case("empty-object", "audit-1 P0 root accepted almost anything", "fail", {}),
    case("unknown-entity", "audit-1 P0 discriminator", "fail", {"entity": "NotAThing"}),
    case("valid-hypothesis", "baseline - a correct instance must pass", "pass", HYP),
    case("hypothesis-extra-prop", "audit-1 P0 unevaluatedProperties", "fail",
         with_(HYP, sneaky="value")),

    # ---- audit-1 #9: experimental was defaulted, and defaults do not populate ----
    case("hypothesis-missing-experimental", "audit-1 #9 EXPERIMENTAL evidence reaching promotion",
         "fail", without(HYP, "experimental")),

    # ---- audit-1 #5: candidate id inside the object it hashes -------------------
    case("candidate-payload-carrying-id", "audit-1 #5 self-referential candidate hash", "fail",
         {"entity": "CandidateManifest", "candidate_id": "CAND-0123456789ab",
          "candidate_digest": "d" * 64, "scorecard_ref": OWNER,
          "payload": {"hypothesis_revision": "B14-H01-r1",
                      "module_set": [{"token": "LAB_CAP_STACK", "module_version": "1", "stability": "CERTIFIABLE"}],
                      "experimental": False, "logical_symbol": "XAUUSD", "tf": "H4",
                      "parameters": {"a": 1}, "profiles": {k: "e" * 64 for k in
                                                           ("instrument", "exit", "sizing", "safety", "execution")},
                      "evidence": [{"window": "MAIN", "pf": 1.5, "trades": 100, "dd_pct": 3.0,
                                    "run_id": "RUN-20260730-001", "lane": "MT5_LANE_1",
                                    "data_fingerprint": "f1", "model": 1}],
                      "ex5_sha256": "f" * 64, "source_sha256": "0" * 64, "allowlist_sha256": "1" * 64,
                      "generator_version": "1", "effective_config_hash": "2" * 64,
                      "universe_version": "v1", "trial_count": 10,
                      "candidate_id": "CAND-0123456789ab"}}),

    # ---- audit-2 P0-A: the ownership fork ---------------------------------------
    case("receipt-with-order-and-title", "audit-2 P0-A Receipt duplicating taskboard facts", "fail",
         {"entity": "WorkReceipt", "receipt_id": "WRK-20260730-001", "source_agent": "claude",
          "requested_at": "2026-07-30T00:00:00Z", "order_ref": OWNER, "title": "copied from the board"}),
    case("receipt-standalone-valid", "a chat commitment with no Order legitimately owns its fields",
         "pass", {"entity": "WorkReceipt", "receipt_id": "WRK-20260730-002", "source_agent": "claude",
                  "requested_at": "2026-07-30T00:00:00Z", "title": "t", "owner": "claude",
                  "status": "IN_PROGRESS"}),

    # ---- audit-1 #21: WAITING used anyOf, so one field sufficed ------------------
    case("waiting-without-wake-condition", "audit-1 #21 indefinitely parked work", "fail",
         {"entity": "WorkReceipt", "receipt_id": "WRK-20260730-003", "source_agent": "claude",
          "requested_at": "2026-07-30T00:00:00Z", "title": "t", "owner": "claude",
          "status": "WAITING", "waiting_for": "user"}),

    # ---- audit-2 #15 + audit-3: the privacy surface -----------------------------
    case("safe-projection-leaking-raw-finding-id", "audit-3 raw finding_id can embed an account",
         "fail", {"entity": "SafeProjection", "build_id": "b1", "generated_at": "2026-07-30T00:00:00Z",
                  "accounts": [{"account_masked": "***454", "sensor_state": "FRESH", "dd_pct_band": "OK"}],
                  "findings": [{"finding_id": "FND-sensor-159503454", "severity": "WARN", "state": "OPEN"}]}),
    case("safe-projection-valid", "the projection with only opaque ids must pass", "pass",
         {"entity": "SafeProjection", "build_id": "b1", "generated_at": "2026-07-30T00:00:00Z",
          "accounts": [{"account_masked": "***454", "sensor_state": "FRESH", "dd_pct_band": "OK"}],
          "findings": [{"public_id": "FP-0123456789", "severity": "WARN", "state": "OPEN"}]}),
    case("safe-projection-with-money", "an exact money amount must not be expressible", "fail",
         {"entity": "SafeProjection", "build_id": "b1", "generated_at": "2026-07-30T00:00:00Z",
          "accounts": [{"account_masked": "***454", "sensor_state": "FRESH", "dd_pct_band": "OK",
                        "equity": 100000}],
          "findings": []}),

    # ---- audit-2 P0-A: finding must pin the owner of detector state -------------
    case("finding-without-detector-ref", "audit-3 SystemFinding as a second drifting copy", "fail",
         {"entity": "SystemFinding", "finding_id": "FND-x-y", "public_id": "FP-0123456789",
          "detector": "d", "class": "RUNTIME", "first_seen": "t", "last_seen": "t",
          "state": "OPEN", "severity": "WARN", "material_revision": 0}),

    # ---- audit-1 #8: idempotency key that could not tell two runs apart ---------
    case("execution-key-missing-deposit", "audit-1 #8 wrong cached evidence served", "fail",
         {"entity": "RunTransition", "run_id": "RUN-20260730-001", "cell_id": "c", "attempt": 1,
          "transition": "QUEUED", "at": "t",
          "execution_key": {"expert": "e", "symbol": "XAUUSD", "tf": "H4", "from_date": "2023.01.01",
                            "to_date": "2025.12.31", "model": 1, "currency": "USD", "leverage": 100,
                            "set_hash": "0" * 64, "ini_hash": "1" * 64, "ex5_hash": "2" * 64,
                            "effective_config_hash": "3" * 64, "data_fingerprint": "f", "lane": "MT5_LANE_1"}}),

    # ---- audit-3: the legacy magic set ------------------------------------------
    case("legacy-magic-without-accounts", "audit-3 legacy exception not actually closed", "fail",
         {"entity": "MagicAllocation", "magic": 991001, "scope": "LEGACY_ACCOUNT_SCOPED",
          "status": "ASSIGNED", "allocated_at_commit": "a" * 40, "legacy_exception": True}),

    # ---- audit-1 #13: automation advancing a deployment -------------------------
    case("attestation-reassigned-by-automation", "audit-1 #13 deployment auto-advanced", "fail",
         {"entity": "DeploymentAttestationEvent", "event_id": "e1", "account": "159503454",
          "magic": 991001, "event_type": "CANDIDATE_REASSIGNED", "at": "t", "actor": "automation",
          "deployment_ref": OWNER}),

    # ---- coverage: a reason is not optional -------------------------------------
    case("not-applicable-without-reason", "design 3.4 NOT_APPLICABLE needs a written reason", "fail",
         {"entity": "CoverageCell", "cell_id": "c", "hypothesis_revision": "B14-H01-r1",
          "logical_symbol": "XAUUSD", "tf": "H4", "universe_version": "v1",
          "state": "NOT_APPLICABLE", "metrics": [], "trial_count": 0}),
]


def run(schema, instance):
    fd, path = tempfile.mkstemp(suffix='.json')
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as f:
            json.dump(instance, f)
        p = subprocess.run(['ajv', 'validate', '-s', schema, '-d', path, '--spec=draft2020',
                            '--strict=false', '--errors=line'],
                           capture_output=True, text=True, shell=True)
        return p.returncode == 0, (p.stdout + p.stderr).strip()
    finally:
        os.unlink(path)


def main():
    print("=== real JSON Schema validation (ajv, draft 2020-12) ===")
    print("schema: %s\n" % SCHEMA)
    bad = 0
    for c in CASES:
        ok, out = run(SCHEMA, c['instance'])
        got = 'pass' if ok else 'fail'
        good = got == c['expect']
        if not good:
            bad += 1
        print("  [%s] %-42s expect=%s got=%s   (%s)"
              % ('OK ' if good else 'BAD', c['name'], c['expect'], got, c['guards']))
        if not good and out:
            print("        %s" % out.splitlines()[0][:160])

    print("\n--- the real snapshot, validated against the schema that claims to describe it ---")
    ok, out = run(SCHEMA, json.load(open('portfolio/control_room_snapshot.json', encoding='utf-8')))
    print("  portfolio/control_room_snapshot.json -> %s" % ('PASSES' if ok else 'FAILS'))
    print("  This is EXPECTED to fail today and is not counted as a failure: the committed snapshot is")
    print("  v3/v4 and carries no `entity`, while ControlRoomSnapshotV5 describes the v5 target. It is")
    print("  printed because audit-3 found the schema does not carry meta fields the real file has")
    print("  (stale_bar_hours, decision_bar_trades, counting_method) nor its real source-row shape.")
    print("  Slice S4 is not done until this line reads PASSES.")

    print("\n=== %s ===" % ('ALL %d CASES BEHAVED AS DECLARED' % len(CASES) if bad == 0
                            else '%d CASE(S) DID NOT' % bad))
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
