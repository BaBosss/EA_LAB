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

WHY THIS IS STILL NOT IN THE PRE-COMMIT TIER, and what changed 2026-07-30
  It used to be excluded because it cost 11.5s -- one ajv process per case, 35 spawns. Codex audit 6
  (MAJOR 7) pointed out what that meant: the 35 cases everyone quotes are enforced by nothing
  automatic, so a schema edit can trigger the fast tier, run the computation suite with
  NO_SCHEMA_CHECK, and never reach the authoritative closed-object and nonnegative checks.
  Batching all cases into ONE ajv process took it to **1.8s, measured**.

  It is STILL not wired, and the reason is now different and worth stating plainly: the fast tier
  measures 14.1-15.2s against a 15.0s ADVISORY budget, so there is no room for 1.8s. The blocker
  moved from "this suite is too slow" to "the tier runs all 12 suites whenever any guarded path is
  staged". The fix is per-path suite selection driven by $SUITE_GUARDS in run_fast_cages.ps1 -- a
  schema edit should not pay 5.8s of optimize-guard cases. Until that exists, this suite is
  manual, and that sentence is the honest status rather than a cost excuse.

REQUIRES  ajv-cli  (npm install -g ajv-cli)
USAGE     python _triage/factory_os/run_schema_fixtures.py
EXIT      0 = every case behaved as declared · 1 = at least one did not
"""
import io, json, os, re, shutil, subprocess, sys, tempfile

SCHEMA = '_triage/factory_os/schemas.json'

OWNER = {"entity": "OwnerRef", "owner_type": "taskboard_order", "path": "AGENT_TASKBOARD.md",
         "commit_oid": "a" * 40, "blob_oid": "b" * 40, "raw_sha256": "c" * 64}

HYP = {"entity": "Hypothesis", "hypothesis_id": "B14-H01", "boss_family": 14, "revision": 1,
       "architecture_digest": "0" * 16,
       "module_set": [{"token": "LAB_CAP_STACK", "module_version": "1", "stability": "CERTIFIABLE"}],
       "coupling_class": "COUPLED", "experimental": False, "status": "REGISTERED",
       "preregistration_ref": OWNER}


def case(name, guards, expect, instance, says=None):
    """`says`: error specs that must each match at least one ajv error. See why_says below."""
    return {"name": name, "guards": guards, "expect": expect, "instance": instance,
            "says": says or []}


# WHY `says` HAD TO EXIST (ORDER-601 part 2, measured 2026-07-30)
#   The root of this schema is a oneOf over 19 entities, so ajv reports the first error from
#   EVERY branch: validating a malformed ControlRoomSnapshotV5 yields 20 errors, and the first
#   one is `#/$defs/OwnerRef/required missingProperty owner_type` -- an entity that has nothing
#   to do with the instance. Any assertion on ajv's first line, or a grep over its whole
#   output, can therefore be satisfied by a branch the fixture never intended to reach.
#   `expect=fail` alone has the same weakness in a subtler form: it cannot distinguish "the
#   rule I am testing rejected this" from "something else did".
#
#   So a `says` spec matches against the PARSED error array: keyword, instancePath, and any
#   params key (missingProperty, unevaluatedProperty, ...). ORDER-601's acceptance asks for
#   "the ajv error path/keyword naming that property", and this is what makes that checkable
#   instead of asserted.
def ajv_errors(out):
    m = re.search(r'\[\{.*\}\]', out, re.S)
    if not m:
        return None
    try:
        return json.loads(m.group(0))
    except ValueError:
        return None


def unmet_says(out, says):
    errors = ajv_errors(out)
    if errors is None:
        return ['ajv printed no parsable error array, so no error could be asserted against']
    unmet = []
    for spec in says:
        for err in errors:
            params = err.get('params') or {}
            if all((err.get(k) == v if k in ('keyword', 'instancePath')
                    else params.get(k) == v) for k, v in spec.items()):
                break
        else:
            unmet.append('no ajv error matched %s' % json.dumps(spec, sort_keys=True))
    return unmet


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

# ---------------------------------------------------------------------------------------
# ORDER-601 -- the builder/persisted boundary.
#
# Every case below is a ONE-FIELD DELTA from BUILDER_OK. Audit 5's finding was that a
# negative fixture which is also invalid for an unrelated reason gets credited to the rule
# it names while never reaching it: ajv returns nonzero either way. So the positive is
# defined once, and each negative is `dict(BUILDER_OK, **{one_thing})`.
#
# These cover only what JSON SCHEMA can decide. Whether `reconciliation_clear` is COMPUTED correctly is
# not a schema property and is not tested here -- that is snapshot_validator's own suite, and
# claiming otherwise would be the "x-enforced-by names a validator nobody wrote" defect.

EVIDENCE_OK = {
    "discovered": 3, "categorized": 3,
    "categories": {"actionable": 0, "running": 1, "waiting": 1, "review_audit": 0,
                   "completed": 1, "cancelled_by_user": 0},
    "coverage": {"cells_in_universe": 4, "tested": 2, "untested": 2, "not_applicable": 0},
    "duplicates": 0, "conflicts": 0, "unclassified": 0,
}

META_OK = {
    "schema": "ControlRoomSnapshot", "version": 5, "build_id": "b1",
    "generated_at": "2026-07-30T00:00:00Z",
    "stale_bar_hours": 26, "decision_bar_trades": 30, "counting_method": "closed_deals",
    "mandatory_sources": ["live_deals"],
    "sources": [{"name": "live_deals", "mandatory": True, "read_ok": True,
                 "fresh": True, "age_hours": 1.0}],
    "reconciliation": EVIDENCE_OK,
}

BUILDER_OK = {
    "entity": "SnapshotBuilderInput", "meta": META_OK,
    "system_health": [], "floating_risk": [], "deployments": {}, "unknown_magics": [],
    "attestation": [], "judge_readiness": [], "judge_cohorts": {}, "summary": {},
}


def builder(**delta):
    """BUILDER_OK with exactly one thing changed. The whole point of the minimal pair."""
    out = json.loads(json.dumps(BUILDER_OK))
    for k, v in delta.items():
        out[k] = v
    return out


def with_meta(**delta):
    m = json.loads(json.dumps(META_OK))
    for k, v in delta.items():
        m[k] = v
    return builder(meta=m)


def with_evidence(**delta):
    e = json.loads(json.dumps(EVIDENCE_OK))
    for k, v in delta.items():
        e[k] = v
    return with_meta(reconciliation=e)


CASES += [
    case("builder-input-valid", "the positive the negatives below are one delta away from", "pass",
         BUILDER_OK),
    case("builder-input-carrying-all-clear",
         "ORDER-601: a supplied verdict must be refused BY THE SCHEMA, not by code, and the "
         "error must NAME the property", "fail",
         with_evidence(reconciliation_clear=True),
         says=[{"keyword": "unevaluatedProperties", "instancePath": "/meta/reconciliation",
                "unevaluatedProperty": "reconciliation_clear"}]),
    case("builder-input-carrying-verdict-object",
         "ORDER-601: the builder root is closed, so it cannot acquire a verdict either", "fail",
         builder(verdict={"reconciliation_clear": True, "reasons": []})),
    case("builder-input-dropping-a-compat-domain",
         "audit-5: a validator that emits only {entity,meta,system_health,summary} must not validate",
         "fail",
         {"entity": "SnapshotBuilderInput", "meta": META_OK, "system_health": [], "summary": {}}),
    case("evidence-negative-category-count",
         "audit-5: actionable=-1 running=1 balances every equation and used to validate", "fail",
         with_evidence(categories={"actionable": -1, "running": 2, "waiting": 1,
                                   "review_audit": 0, "completed": 1, "cancelled_by_user": 0})),
    case("evidence-negative-coverage-count",
         "audit-5: the same balanced-negative attack on the coverage totals", "fail",
         with_evidence(coverage={"cells_in_universe": 4, "tested": -1, "untested": 5,
                                 "not_applicable": 0})),
    case("evidence-negative-conflicts",
         "audit-5: conflicts/unclassified/duplicates carried no lower bound either", "fail",
         with_evidence(conflicts=-1)),
    case("meta-empty-mandatory-registry",
         "an empty registry makes every missing source unexpected, which is how 0==0 passed", "fail",
         with_meta(mandatory_sources=[])),
    case("snapshot-output-without-verdict",
         "ORDER-601: the persisted document must carry the computed verdict", "fail",
         {"entity": "ControlRoomSnapshotV5", "meta": META_OK,
          "system_health": [], "floating_risk": [], "deployments": {}, "unknown_magics": [],
          "attestation": [], "judge_readiness": [], "judge_cohorts": {}, "summary": {}}),
    case("snapshot-output-verdict-free-text-reason",
         "a false verdict must be explained in a CLOSED code, not prose nobody parses", "fail",
         {"entity": "ControlRoomSnapshotV5", "meta": META_OK,
          "verdict": {"reconciliation_clear": False, "reasons": [{"code": "something went wrong"}]},
          "system_health": [], "floating_risk": [], "deployments": {}, "unknown_magics": [],
          "attestation": [], "judge_readiness": [], "judge_cohorts": {}, "summary": {}}),
    case("snapshot-output-valid",
         "the persisted positive - without it the negatives above could pass for any reason", "pass",
         {"entity": "ControlRoomSnapshotV5", "meta": META_OK,
          "verdict": {"reconciliation_clear": True, "reasons": []},
          "system_health": [], "floating_risk": [], "deployments": {}, "unknown_magics": [],
          "attestation": [], "judge_readiness": [], "judge_cohorts": {}, "summary": {}}),
]

# ---------------------------------------------------------------------------------------
# ORDER-601 part 2 -- the CLOSED root, and the v4 source-row metadata.
#
# The root was `additionalProperties: true` on the argument that the snapshot versions
# additively. Those two facts do not imply each other: additive versioning means no field is
# REMOVED or RENAMED, and declaring each new domain satisfies it. An open root let a whole
# top-level domain appear that no contract described -- the same shape as the source array
# that silently dropped a file which did not exist.
#
# Each of the three removals below is asserted INDEPENDENTLY and by error path, because
# "expect=fail" on a 19-branch oneOf is satisfied by any of 20 errors (see why_says above).

SNAP_OK = {"entity": "ControlRoomSnapshotV5", "meta": META_OK,
           "verdict": {"reconciliation_clear": True, "reasons": []},
           "system_health": [], "floating_risk": [], "deployments": {}, "unknown_magics": [],
           "attestation": [], "judge_readiness": [], "judge_cohorts": {}, "summary": {}}

COMPAT_ROW = {"name": "live_deals", "mandatory": True, "read_ok": True, "fresh": True,
              "age_hours": 1.0, "path": "portfolio\\DEPLOYMENTS.csv", "sha256": "a" * 64,
              "mtime": "2026-07-28T23:44:11"}

CASES += [
    case("snapshot-output-undeclared-top-level-domain",
         "ORDER-601: the root is CLOSED, so a domain no contract describes cannot be bolted "
         "on. This case fails only because of the closing - it passed before it", "fail",
         with_(SNAP_OK, brand_new_domain={"a": 1}),
         says=[{"keyword": "unevaluatedProperties", "instancePath": "",
                "unevaluatedProperty": "brand_new_domain"}]),
    case("snapshot-output-missing-entity",
         "ORDER-601: removing `entity` must fail AT THE ROOT - without the discriminator the "
         "document cannot even be routed to a contract", "fail",
         without(SNAP_OK, "entity"),
         says=[{"keyword": "required", "instancePath": "", "missingProperty": "entity"}]),
    case("snapshot-output-missing-system-health",
         "ORDER-601: asserted independently of the other two removals", "fail",
         without(SNAP_OK, "system_health"),
         says=[{"keyword": "required", "instancePath": "", "missingProperty": "system_health"}]),
    case("snapshot-output-missing-summary",
         "ORDER-601: asserted independently of the other two removals", "fail",
         without(SNAP_OK, "summary"),
         says=[{"keyword": "required", "instancePath": "", "missingProperty": "summary"}]),
    case("meta-registry-with-duplicate-entries",
         "a registry naming the same source twice makes its own cardinality unreadable. This "
         "half IS expressible in JSON Schema (uniqueItems); a duplicate in the `sources` "
         "OBJECT array is not, and is snapshot_validator's DUPLICATE_SOURCE_NAME instead",
         "fail", with_meta(mandatory_sources=["live_deals", "live_deals"]),
         says=[{"keyword": "uniqueItems", "instancePath": "/meta/mandatory_sources"}]),
    case("source-row-carrying-the-real-v4-metadata",
         "ORDER-601: the real rows are {path, sha256, mtime, age_hours} (control_room_snapshot"
         ".ps1 FileMeta). The closed row had nowhere to put them, so the boundary could not "
         "preserve what it does not accept - this positive is what makes that testable",
         "pass", with_meta(sources=[COMPAT_ROW])),
    case("source-row-with-an-undeclared-field",
         "the row stays CLOSED after widening it: adding three compatibility fields must not "
         "turn it into a bag", "fail",
         with_meta(sources=[with_(COMPAT_ROW, bogus=1)]),
         says=[{"keyword": "unevaluatedProperties", "instancePath": "/meta/sources/0",
                "unevaluatedProperty": "bogus"}]),
]


VALID, INVALID, ERROR = 'pass', 'fail', 'ERROR'


def check_validator_schema_gate():
    """snapshot_validator's ajv gate -- exercised HERE because this suite already has ajv.

    /scrutinize 2026-07-30 found `ajv_schema_validator` had zero coverage: grep returned its own
    definition and one call in __main__, nothing else. It is the function `x-enforced-by` points
    at when it says "refuses to compute from an input that does not validate", so an untested
    version of it is the same defect one level down -- x-enforced-by naming a validator nobody
    TESTED rather than one nobody wrote. The computation suite cannot cover it: that suite is in
    the pre-commit tier and must not spawn ajv.
    """
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import snapshot_validator as SV

    problems = []

    # 1. A valid builder input passes the gate and produces a document.
    try:
        out = SV.build_snapshot(BUILDER_OK, SV.ajv_schema_validator)
        if out.get('entity') != SV.OUTPUT_ENTITY:
            problems.append('the gate passed a valid input but the output entity is %r'
                            % out.get('entity'))
    except SV.SnapshotRefusal as exc:
        problems.append('the gate REFUSED a builder input that ajv accepts: %s' % exc)

    # 2. An input ajv rejects must be refused BEFORE any verdict is computed. The instance below
    #    carries `reconciliation_clear` in the evidence -- schema-invalid, and semantically healthy, so a
    #    validator that skipped the gate would happily return reconciliation_clear=true for it.
    supplied = with_evidence(reconciliation_clear=True)
    try:
        SV.build_snapshot(supplied, SV.ajv_schema_validator)
        problems.append('the gate ACCEPTED an instance ajv rejects (evidence carrying reconciliation_clear) '
                        '- the schema gate is not wired into build_snapshot')
    except SV.SnapshotRefusal as exc:
        if 'reconciliation_clear' not in str(exc):
            problems.append('refused, but the message never names the offending property: %s' % exc)

    # 3. The same instance with NO_SCHEMA_CHECK must reach the code path that refuses a supplied
    #    verdict on its own -- otherwise item 2 proves only that ajv works, not that skipping the
    #    gate is survivable. This is the honest scope of the sentinel.
    try:
        SV.build_snapshot(supplied, SV.NO_SCHEMA_CHECK)
        problems.append('with NO_SCHEMA_CHECK, an evidence object carrying reconciliation_clear was accepted '
                        'and a verdict computed for it')
    except SV.SnapshotRefusal:
        pass

    # 5. The refusal must name a NESTED defect, not just a top-level one. /scrutinize round 2:
    #    the schema root is a 19-branch oneOf, so validating against it made the refusal for
    #    `duplicates: -1` read "required at '' -> owner_type; ... hypothesis_id" -- errors from
    #    entities the instance was never meant to be. The heuristic filter could not fix that,
    #    because a nested error lives under #/$defs/ReconciliationEvidence, not under the builder's
    #    own $def. ajv_schema_validator now validates against the focused $def instead.
    nested = with_evidence(duplicates=-1)
    try:
        SV.build_snapshot(nested, SV.ajv_schema_validator)
        problems.append('the gate accepted a negative count that the schema forbids')
    except SV.SnapshotRefusal as exc:
        msg = str(exc)
        if 'duplicates' not in msg:
            problems.append('a NESTED violation was refused without naming the field: %s' % msg[:110])
        if 'owner_type' in msg or 'hypothesis_id' in msg:
            problems.append('the refusal quotes errors from unrelated oneOf branches: %s' % msg[:110])

    # 4. Tool failure must NOT read as rejection. Point the module at a schema that is not there
    #    and confirm the refusal says so rather than reporting the instance invalid -- the exact
    #    three-state discipline this file was rewritten for in 3812d72c.
    saved = SV.SCHEMA_PATH
    SV.SCHEMA_PATH = '_triage/factory_os/does_not_exist.json'
    try:
        SV.build_snapshot(BUILDER_OK, SV.ajv_schema_validator)
        problems.append('with the schema file absent the gate reported SUCCESS')
    except SV.SnapshotRefusal as exc:
        if 'could not run' not in str(exc):
            problems.append('with the schema absent the gate said %r -- a tool failure reported '
                            'as a verdict about the instance' % str(exc)[:80])
    finally:
        SV.SCHEMA_PATH = saved

    return problems


def run_batch(schema, cases):
    """Validate every case in ONE ajv process. -> {name: (state, out)}

    WHY (Codex audit 6, MAJOR 7): this suite measured 11.5s, essentially all of it ajv process
    startup -- one spawn per case, 35 spawns. That cost is the only reason the suite is not in the
    pre-commit tier, which means the 35 cases everyone quotes are enforced by nothing automatic: a
    schema edit could trigger the fast tier, run the computation suite with NO_SCHEMA_CHECK, and
    never touch the authoritative closed-object and nonnegative checks.

    ajv's multi `-d` output is per file and attributable, MEASURED on this machine:
      valid   -> stdout: "<path> valid"
      invalid -> stderr: "<path> invalid" followed by the JSON error array on the next line
    Attribution is by BASENAME because ajv echoes the path with a backslash before the filename
    even when given forward slashes.

    The three-state discipline is preserved and is arguably stronger here: a case for which ajv
    printed NEITHER line is ERROR, explicitly. That is what makes "the tool did not read this"
    impossible to confuse with "the contract rejected this".
    """
    tmpdir = tempfile.mkdtemp(prefix='ajvbatch_')
    try:
        names = {}
        cmd = ['ajv', 'validate', '-s', schema, '--spec=draft2020', '--strict=false',
               '--errors=line']
        for i, c in enumerate(cases):
            base = 'case_%03d.json' % i
            p = os.path.join(tmpdir, base)
            with io.open(p, 'w', encoding='utf-8') as fh:
                fh.write(json.dumps(c['instance']))
            names[base] = c['name']
            cmd += ['-d', p]
        proc = subprocess.run(cmd, capture_output=True, text=True, shell=True)
        combined = (proc.stdout or '') + '\n' + (proc.stderr or '')

        results = {}
        lines = combined.splitlines()
        for idx, line in enumerate(lines):
            stripped = line.strip()
            for base, name in names.items():
                if base not in stripped:
                    continue
                if stripped.endswith(' valid'):
                    results[name] = (VALID, stripped)
                elif stripped.endswith(' invalid'):
                    detail = lines[idx + 1].strip() if idx + 1 < len(lines) else ''
                    results[name] = (INVALID, stripped + '\n' + detail)
                break
        for base, name in names.items():
            if name not in results:
                results[name] = (ERROR, 'ajv printed no verdict line for this case (exit %s): %s'
                                 % (proc.returncode, combined.strip().splitlines()[:1]))
        return results
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def run(schema, instance):
    fd, path = tempfile.mkstemp(suffix='.json')
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as f:
            json.dump(instance, f)
        p = subprocess.run(['ajv', 'validate', '-s', schema, '-d', path, '--spec=draft2020',
                            '--strict=false', '--errors=line'],
                           capture_output=True, text=True, shell=True)
        out = (p.stdout + p.stderr).strip()
        # AUDIT-5: this used to `return p.returncode == 0`, so EVERY nonzero exit read as
        # "the instance was rejected" -- including ajv missing, the schema being unreadable,
        # or a $ref that does not resolve. Every negative case would then pass for a reason
        # that has nothing to do with the rule it names, and the suite would print
        # "ALL 17 CASES BEHAVED AS DECLARED" while validating nothing at all. That is this
        # repo's most expensive defect class, in the file written to prevent it.
        # Measured on this machine: exit 1 + " invalid" in the output = a real validation
        # failure; exit 2 = tool/schema error.
        if p.returncode == 0:
            return VALID, out
        if p.returncode == 1 and ' invalid' in out:
            return INVALID, out
        return ERROR, out
    finally:
        os.unlink(path)


def main():
    print("=== real JSON Schema validation (ajv, draft 2020-12) ===")
    print("schema: %s\n" % SCHEMA)
    bad = 0
    batch = run_batch(SCHEMA, CASES)
    for c in CASES:
        got, out = batch[c['name']]
        # An ERROR never satisfies an expectation, not even `expect=fail`. "The tool could
        # not read its input" and "the contract rejected this instance" are different facts
        # and must never share an outcome.
        good = got != ERROR and got == c['expect']
        notes = []
        if c['says']:
            if c['expect'] != INVALID:
                # A `says` spec on a case expected to PASS can never be met, and a check that
                # cannot be met is worse than absent: it reads as coverage.
                notes.append('a `says` spec is meaningless on an expect=pass case')
            elif good:
                notes = unmet_says(out, c['says'])
        if notes:
            good = False
        if not good:
            bad += 1
        print("  [%s] %-42s expect=%s got=%-5s (%s)"
              % ('OK ' if good else 'BAD', c['name'], c['expect'], got, c['guards']))
        for n in notes:
            print("        -> %s" % n)
        if not good and not notes and out:
            print("        %s" % out.splitlines()[0][:160])

    print("\n--- snapshot_validator's ajv gate (x-enforced-by's actual claim) ---")
    gate = check_validator_schema_gate()
    print("  [%s] a valid input passes, an ajv-rejected input is refused naming the property, "
          "and a\n       missing schema is refused as TOOL FAILURE rather than as rejection"
          % ('OK ' if not gate else 'BAD'))
    for p in gate:
        print("        -> %s" % p)
    bad += len(gate)

    print("\n--- the real snapshot, validated against the schema that claims to describe it ---")
    got, out = run(SCHEMA, json.load(open('portfolio/control_room_snapshot.json', encoding='utf-8')))
    if got == ERROR:
        # Distinguish "the schema says no" from "the tool fell over" here too -- otherwise the
        # S4 acceptance line could read FAILS forever for a reason nobody is tracking.
        print("  portfolio/control_room_snapshot.json -> TOOL ERROR, not a verdict: %s"
              % out.splitlines()[0][:120])
        bad += 1
    print("  portfolio/control_room_snapshot.json -> %s" % ('PASSES' if got == VALID else 'FAILS'))
    print("  This is EXPECTED to fail today and is not counted as a failure: ControlRoomSnapshotV5")
    print("  describes the v5 TARGET and the committed file is a v3 artifact (meta.version == 3,")
    print("  though control_room_snapshot.ps1 at HEAD writes 4 -- the file predates its own writer).")
    print("  MEASURED gap, 2026-07-30, so this line stops being a vague 'needs migrating':")
    print("    root missing  entity, verdict        <- the discriminator and the computed verdict")
    print("    meta missing  build_id, mandatory_sources, reconciliation")
    print("    row  missing  name, mandatory, read_ok, fresh   <- real rows are {path,sha256,mtime,age_hours}")
    print("  The three meta compatibility fields audit-3 found dropped (stale_bar_hours,")
    print("  decision_bar_trades, counting_method) are now carried, and ORDER-601 part 2 added")
    print("  path/sha256/mtime to the source row, so the REAL row metadata is now expressible at")
    print("  the boundary. What remains above is identity and evidence, which is S4's migration:")
    print("  reconciling `path` with `name` needs a decision about which one is the identity, and")
    print("  that decision belongs with the readers. Slice S4 is not done until this line PASSES.")

    print("\n=== %s ===" % ('ALL %d CASES BEHAVED AS DECLARED' % len(CASES) if bad == 0
                            else '%d CASE(S) DID NOT' % bad))
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
