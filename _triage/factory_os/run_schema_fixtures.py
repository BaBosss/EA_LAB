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

HOW IT GOT INTO THE PRE-COMMIT TIER -- ORDER-611, 2026-07-31
  It used to be excluded because it cost 11.5s -- one ajv process per case, 35 spawns. Codex audit 6
  (MAJOR 7) pointed out what that meant: the 35 cases everyone quotes were enforced by nothing
  automatic, so a schema edit could trigger the fast tier, run the computation suite with
  NO_SCHEMA_CHECK, and never reach the authoritative closed-object and nonnegative checks.
  Batching all cases into ONE ajv process took it to 1.8s, measured.

  It then stayed unwired for a different reason, stated honestly at the time: the tier ran all 12
  suites whenever ANY guarded path was staged, so 1.8s came out of a budget already at 15.2s.
  `BACKLOG-D32` removed that reason -- per-path selection means a schema edit now pays only the
  suites that guard schemas. So it is wired. MEASURED 2026-07-31 with ORDER-611's 54 extra cases:
  2.2s standalone, three batched ajv processes (root cases, per-entity isolation, harness probes).

ORDER-611: what "every entity" means here
  S3's acceptance says every entity must reject at least one crafted bad instance. Measured on
  2026-07-31, before the order was written: 15 of the 27 entities THAT EXISTED THEN had NO
  negative and only 5 had ANY positive -- including `OwnerRef`, the pin primitive every other
  entity references. The per-entity half runs against an ISOLATION HARNESS rather than the real
  root, because the real root is a `oneOf` over every routed entity, where one malformed instance
  yields an error from each branch it has nothing to do with. See build_isolation_schema for the
  measurement that killed the first, pattern-matching design.

ORDER-1264 #2, 2026-08-03: THE COUNTS IN THIS HEADER WERE STALE AND NOTHING NOTICED
  The S3 blind audit re-measured them: 29 `$defs` against a header saying 27, a 21-branch root
  against a stated 19. Every present-tense arity in this file is therefore now either derived at
  runtime or declared once in HEADER_COUNTS and CHECKED by check_header_counts(), which runs
  first in main(). Numbers that appear in prose below with a DATE are historical measurements and
  are true of that date -- they are deliberately not rewritten to today's values, because a
  historical measurement rewritten to match the present stops being evidence of anything.

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


def case(name, guards, expect, instance, says=None, covers=None):
    """`says`: error specs that must each match at least one ajv error. See why_says below.

    `covers` is carried for symmetry with ENTITY_CASES; the per-entity criterion is measured on
    those, against the isolation harness, not on this list.
    """
    return {"name": name, "guards": guards, "expect": expect, "instance": instance,
            "says": says or [], "covers": covers or (instance or {}).get("entity")}


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


# The ajv `params` keys this matcher understands. Closed on purpose: an unknown key used to make
# a spec look discriminating while matching nothing, and `params.get(unknown)` returns None, which
# then compared equal to a `null` in the spec. Adding a key here is a reviewable act.
KNOWN_PARAM_KEYS = ('missingProperty', 'unevaluatedProperty', 'additionalProperty', 'allowedValues',
                    'allowedValue', 'pattern', 'limit', 'type', 'format', 'comparison',
                    'deps', 'i', 'j', 'failingKeyword', 'propertyName')


def spec_is_discriminating(spec):
    """A `says` spec must actually assert something. Codex audit, Standards 4.

    `_err_matches(err, {})` iterates zero conditions and returns True, so an empty spec matches the
    FIRST error of ANY failing instance -- and `entity_coverage` only required the list to be
    non-empty. `says=[{}]` therefore earned coverage with nothing asserted. That re-opened the
    under-specified-`says` hole ORDER-611's own acceptance B2 was written to close, and which was
    dropped when the isolation harness replaced the schemaPath scheme.

    Discriminating = names WHERE (`instancePath`) or WHAT (`keyword`/a params key). A spec carrying
    only `schemaPath_startswith` is provenance with no claim, which was B2's original complaint.

    ROUND 2 defeated the first version of this: `says=[{"bogus": null}]` passed, because "has a key
    other than schemaPath_startswith" was satisfied by a key nothing looks at, and `_err_matches`
    then matched an unrelated error through `params.get('bogus') != None` -> `None != None` is
    False. Two separate holes wearing one coat.

    So the vocabulary is CLOSED at both ends now: the key must be one this matcher actually
    evaluates, and `None` is not an assertable value -- `params.get()` returns it for every key that
    is absent, so asserting it asserts nothing.
    """
    for k, v in spec.items():
        if k == 'schemaPath_startswith':
            continue
        if k in ('keyword', 'instancePath'):
            return True
        if k in KNOWN_PARAM_KEYS and v is not None:
            return True
    return False


def _err_matches(err, spec):
    params = err.get('params') or {}
    for k, v in spec.items():
        if k == 'schemaPath_startswith':
            if not str(err.get('schemaPath') or '').startswith(v):
                return False
        elif k in ('keyword', 'instancePath'):
            if err.get(k) != v:
                return False
        elif k not in KNOWN_PARAM_KEYS:
            # a key this matcher does not evaluate must never be treated as satisfied
            return False
        elif params.get(k) != v:
            return False
    return True


def unmet_says(out, says):
    errors = ajv_errors(out)
    if errors is None:
        return ['ajv printed no parsable error array, so no error could be asserted against']
    unmet = []
    for spec in says:
        if not any(_err_matches(err, spec) for err in errors):
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
         "fail", {"entity": "SafeProjection", "build_id": "b7b0c1826bece6b3", "generated_at": "2026-07-30T00:00:00",
                  "accounts": [{"account_masked": "***454", "sensor_state": "FRESH", "dd_pct_band": "OK"}],
                  "findings": [{"finding_id": "FND-sensor-159503454", "severity": "WARN", "state": "OPEN"}]}),
    case("safe-projection-valid", "the projection with only opaque ids must pass", "pass",
         {"entity": "SafeProjection", "build_id": "b7b0c1826bece6b3", "generated_at": "2026-07-30T00:00:00",
          "accounts": [{"account_masked": "***454", "sensor_state": "FRESH", "dd_pct_band": "OK"}],
          "findings": [{"public_id": "FP-0123456789", "severity": "WARN", "state": "OPEN"}]}),
    case("safe-projection-with-money", "an exact money amount must not be expressible", "fail",
         {"entity": "SafeProjection", "build_id": "b7b0c1826bece6b3", "generated_at": "2026-07-30T00:00:00",
          "accounts": [{"account_masked": "***454", "sensor_state": "FRESH", "dd_pct_band": "OK",
                        "equity": 100000}],
          "findings": []}),

    # ---- S12 (ORDER-1180): the two entities that carry the alert path -----------
    # AlertEvent is the ONLY thing that crosses the seam to a channel, so its closed shape is
    # what stops a field arriving on the wire because somebody added it upstream.
    case("alert-event-valid", "the thin event with only opaque ids must pass", "pass",
         {"entity": "AlertEvent", "kind": "ALERT", "channel": "EMERGENCY",
          "public_id": "FP-0123456789", "severity": "CRITICAL", "state": "OPEN",
          "class": "RUNTIME", "material_revision": 2,
          "dedupe_key": "FP-0123456789|OPEN|CRITICAL|2", "build_id": "b1", "text": "t"}),
    case("alert-event-carrying-the-internal-id",
         "the internal finding_id may embed an account and must not be expressible here", "fail",
         {"entity": "AlertEvent", "kind": "ALERT", "channel": "EMERGENCY",
          "public_id": "FP-0123456789", "severity": "CRITICAL", "state": "OPEN",
          "class": "RUNTIME", "material_revision": 2,
          "dedupe_key": "FP-0123456789|OPEN|CRITICAL|2", "build_id": "b1", "text": "t",
          "finding_id": "FND-sensor-159503454"}),
    case("alert-event-without-material-revision",
         "dedupe on (id,state,severity) alone swallows a payload change, so the field is required",
         "fail",
         {"entity": "AlertEvent", "kind": "ALERT", "channel": "EMERGENCY",
          "public_id": "FP-0123456789", "severity": "CRITICAL", "state": "OPEN",
          "class": "RUNTIME", "dedupe_key": "FP-0123456789|OPEN|CRITICAL",
          "build_id": "b1", "text": "t"}),
    case("alert-delivery-valid", "a receipted delivery line must pass", "pass",
         {"entity": "AlertDelivery", "dedupe_key": "k", "channel": "EMERGENCY",
          "kind": "DELIVERY_PROBE", "outcome": "DELIVERED", "receipt": "1234",
          "at": "2026-08-02T00:00:00", "openclaw": "NOT_RUNNING", "detail": ""}),
    case("alert-delivery-carrying-a-chat-id",
         "a chat id is a delivery credential - the ledger names a CHANNEL, never a chat", "fail",
         {"entity": "AlertDelivery", "dedupe_key": "k", "channel": "EMERGENCY",
          "kind": "DELIVERY_PROBE", "outcome": "DELIVERED", "receipt": "1234",
          "at": "2026-08-02T00:00:00", "openclaw": "NOT_RUNNING", "detail": "",
          "chat_id": "123456789"}),
    case("alert-delivery-inventing-an-outcome",
         "a fifth outcome would be a fifth meaning nothing in deliver() can produce", "fail",
         {"entity": "AlertDelivery", "dedupe_key": "k", "channel": "EMERGENCY",
          "kind": "ALERT", "outcome": "PROBABLY_SENT", "receipt": None,
          "at": "2026-08-02T00:00:00", "openclaw": "UNKNOWN", "detail": ""}),

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
                            "set_hash": "0" * 64, "ex5_hash": "2" * 64,
                            "effective_config_hash": "3" * 64, "data_fingerprint": "f", "lane": "MT5_LANE_1"}}),

    # ---- audit-3: the legacy magic set ------------------------------------------
    case("legacy-magic-without-accounts", "audit-3 legacy exception not actually closed", "fail",
         {"entity": "MagicAllocation", "magic": 991001, "scope": "LEGACY_ACCOUNT_SCOPED",
          "status": "ASSIGNED", "allocated_at_commit": "a" * 40, "legacy_exception": True}),

    # ---- audit-1 #13: automation advancing a deployment -------------------------
    case("attestation-reassigned-by-automation", "audit-1 #13 deployment auto-advanced", "fail",
         {"entity": "DeploymentAttestationEvent", "event_id": "e1", "account": "159503454",
          "magic": 991001, "event_type": "CANDIDATE_REASSIGNED", "at": "t", "actor": "automation",
          "deployment_ref": OWNER, "prev_hash": "0" * 64}),

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
    "attestation": [], "judge_readiness": [], "judge_cohorts": [], "summary": {},
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
          "attestation": [], "judge_readiness": [], "judge_cohorts": [], "summary": {}}),
    case("snapshot-output-verdict-free-text-reason",
         "a false verdict must be explained in a CLOSED code, not prose nobody parses", "fail",
         {"entity": "ControlRoomSnapshotV5", "meta": META_OK,
          "verdict": {"reconciliation_clear": False, "reasons": [{"code": "something went wrong"}]},
          "system_health": [], "floating_risk": [], "deployments": {}, "unknown_magics": [],
          "attestation": [], "judge_readiness": [], "judge_cohorts": [], "summary": {}}),
    case("snapshot-output-valid",
         "the persisted positive - without it the negatives above could pass for any reason", "pass",
         {"entity": "ControlRoomSnapshotV5", "meta": META_OK,
          "verdict": {"reconciliation_clear": True, "reasons": []},
          "system_health": [], "floating_risk": [], "deployments": {}, "unknown_magics": [],
          "attestation": [], "judge_readiness": [], "judge_cohorts": [], "summary": {}}),
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
           "attestation": [], "judge_readiness": [], "judge_cohorts": [], "summary": {}}

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

# =======================================================================================
# ORDER-611 -- S3's first acceptance clause: EVERY entity rejects a crafted bad instance.
#
# MEASURED before writing any of this (2026-07-31): 35 cases against 27 `$defs` entities.
# 15 entities had NO negative at all and only 5 had ANY positive. `OwnerRef` -- the pin
# primitive every other entity references -- had never been validated in either direction.
#
# These cases run against the ISOLATION HARNESS (build_isolation_schema), not against the
# real root. The real root is a `oneOf` over 19 branches, so one malformed instance yields
# 20 errors and ajv's paths are relative to whichever branch produced them -- attribution by
# pattern-match does not survive contact with that. Validating each instance against its own
# `$def` makes attribution structural: only one contract is in play.
#
# Every case is a MINIMAL PAIR: a positive that validates, and a negative one delta away.
# A negative with no positive proves nothing -- the instance may be failing for a reason
# that has nothing to do with the rule under test.
#
# `instancePath` in a `says` is relative to the envelope, so it starts with `/instance`.
# =======================================================================================

ENTITY_CASES = []

D40 = "d" * 40
H64 = "e" * 64

MODULE_OK = {"token": "LAB_CAP_STACK", "module_version": "1", "stability": "CERTIFIABLE"}
METRIC_OK = {"window": "MAIN", "pf": 1.31, "pf_state": "DEFINED", "trades": 84, "dd_pct": 7.4,
             "run_id": "RUN-20260731-001", "lane": "MT5-A", "data_fingerprint": "df1", "model": 1}
# ORDER-1250. The cell that forced the schema change: USDJPY H1, 99 trades, 99 winners,
# gross_loss = 0, so the profit factor has no denominator at all.
METRIC_UNDEF_OK = {"window": "MAIN", "pf": None, "pf_state": "UNDEFINED_NO_LOSSES", "trades": 99,
                   "dd_pct": 1.9, "run_id": "RUN-20260803-016", "lane": "MT5-A",
                   "data_fingerprint": "df1", "model": 1}
EXECKEY_OK = {"expert": "Boss_14", "symbol": "XAUUSD", "tf": "H1", "from_date": "2023.01.01",
              "to_date": "2025.12.31", "model": 1, "deposit": 10000.0, "currency": "USD",
              "leverage": 100, "set_hash": H64, "ex5_hash": H64,
              "effective_config_hash": H64, "data_fingerprint": "df1", "lane": "MT5-A"}
ATTEMPT_OK = {"attempt": 1, "transition": "QUEUED", "at": "2026-07-31T00:00:00Z"}

RUNTIME_IDENTITY_OK = {
    "schema": "runtime_identity/1", "account_login": "100000001", "magic": "900001",
    "ea_logical_identity": "EA_X_TEST", "build_receipt": "br-" + "a" * 32,
    "config_fingerprint": "c" * 64, "config_fingerprint_version": "cfgfp-v1",
    "symbol": "EURUSDm", "timeframe": "PERIOD_H1", "attach_epoch": "epoch-1",
    "first_trade_epoch": None, "evidence_timestamp": "2026-08-11T00:00:00",
    "evidence_source": "EA_RUNTIME_COMMON_FILE",
}
RUNTIME_IDENTITY_RECORD_OK = with_(RUNTIME_IDENTITY_OK, validation_state="PASS", validation_reasons=[])
RUNTIME_IDENTITY_SUMMARY_OK = {"state": "PASS", "records": 1, "reasons": []}


def ecase(entity, name, guards, expect, instance, says=None):
    ENTITY_CASES.append({
        "name": "%s-%s" % (entity.lower(), name), "guards": guards, "expect": expect,
        "covers": entity, "says": says or [],
        "instance": {"case_entity": entity, "instance": instance},
    })


def epair(entity, positive, negative, guards, says, name='core'):
    ecase(entity, name + '-valid',
          'ORDER-611: the positive the negative below is one delta from', 'pass', positive)
    ecase(entity, name + '-negative', guards, 'fail', negative,
          says=[dict(s, instancePath='/instance' + s.get('instancePath', ''))
                for s in says])


PAYLOAD_OK = {"hypothesis_revision": "B14-H01-r1", "module_set": [MODULE_OK],
              "logical_symbol": "XAUUSD", "tf": "H1", "build_tag": "LAB_ENTRY_14",
              "parameters": {"GridStepATR": 1.5},
              "profiles": {"instrument": H64, "exit": H64, "sizing": H64, "safety": H64,
                           "execution": H64},
              "evidence": [METRIC_OK], "ex5_sha256": H64, "source_sha256": H64,
              "allowlist_sha256": H64, "generator_version": "1.0", "effective_config_hash": H64,
              "universe_version": "v1", "trial_count": 12, "experimental": False}

# ORDER-1267 Part 2: `build_id` and `generated_at` were `"b1"` and `"...T00:00:00Z"` -- neither is
# a value either producer can emit (compute_build_id returns sha256[:16]; control_room_snapshot.ps1
# writes ToString('s'), which has no zone). They were placeholders standing where a shape belongs,
# and they went green only because the schema declared both fields as unconstrained strings, which
# is the leak this order closed. Realistic values now, so the positive case exercises the pattern
# rather than sitting one delta away from it.
SAFEPROJ_OK = {"entity": "SafeProjection", "build_id": "b7b0c1826bece6b3",
               "generated_at": "2026-07-31T00:00:00",
               "accounts": [{"account_masked": "***454", "sensor_state": "FRESH",
                             "dd_pct_band": "OK"}],
               "findings": [{"public_id": "FP-0123456789", "severity": "WARN", "state": "OPEN"}]}

epair('OwnerRef', OWNER, with_(OWNER, raw_sha256="NOT-A-SHA"),
      'ORDER-611: OwnerRef is the pin primitive EVERY other entity references, and nothing had '
      'ever validated one in either direction. A pin whose raw_sha256 is not a hash resolves to '
      'nothing, so a C4-style recompute has no counterpart to compare against',
      [{'keyword': 'pattern', 'instancePath': '/raw_sha256'}])

epair('EvidenceRef',
      {"entity": "EvidenceRef", "evidence_id": "evd_sha256_" + "f" * 64, "kind": "REPORT",
       "path": "_mt5_auto/report.htm", "commit_oid": D40, "raw_sha256": H64},
      {"entity": "EvidenceRef", "evidence_id": "evd_md5_" + "f" * 32, "kind": "REPORT",
       "path": "_mt5_auto/report.htm", "commit_oid": D40, "raw_sha256": H64},
      'ORDER-611: the evidence id encodes WHICH digest was taken; a non-sha256 id would let two '
      'different artifacts share one identity',
      [{'keyword': 'pattern', 'instancePath': '/evidence_id'}])

epair('RuntimeIdentityObserved', RUNTIME_IDENTITY_OK,
      with_(RUNTIME_IDENTITY_OK, magic="0"),
      'runtime identity account/magic/build/config/symbol/timeframe evidence is closed and a malformed magic must fail',
      [{'keyword': 'pattern', 'instancePath': '/magic'}])

epair('RuntimeIdentityRecord', RUNTIME_IDENTITY_RECORD_OK,
      with_(RUNTIME_IDENTITY_RECORD_OK, validation_state="UNKNOWN"),
      'the collection boundary may emit only a canonical runtime identity validation state',
      [{'keyword': 'enum', 'instancePath': '/validation_state'}])

epair('RuntimeIdentitySummary', RUNTIME_IDENTITY_SUMMARY_OK,
      with_(RUNTIME_IDENTITY_SUMMARY_OK, records=-1),
      'a runtime identity summary cannot report a negative record count',
      [{'keyword': 'minimum', 'instancePath': '/records'}])

epair('IdeaRef',
      {"entity": "IdeaRef", "idea_id": "IDEA-0001", "received_at": "2026-07-31T00:00:00Z",
       "source": "telegram", "status": "NEW", "intake_ref": OWNER},
      {"entity": "IdeaRef", "idea_id": "IDEA-0001", "received_at": "2026-07-31T00:00:00Z",
       "source": "smoke-signal", "status": "NEW", "intake_ref": OWNER},
      'ORDER-611: an unknown intake source means an idea cannot be traced back to a channel '
      'anybody controls',
      [{'keyword': 'enum', 'instancePath': '/source'}])

epair('InstrumentProfile',
      {"entity": "InstrumentProfile", "profile_id": "GOLD_BASE", "profile_version": 1,
       "content_hash": H64, "layer": "ASSET_CLASS", "asset_class": "GOLD", "values": {},
       "semantics_ref": OWNER},
      {"entity": "InstrumentProfile", "profile_id": "GOLD_BASE", "profile_version": 0,
       "content_hash": H64, "layer": "ASSET_CLASS", "asset_class": "GOLD", "values": {},
       "semantics_ref": OWNER},
      'ORDER-611: version 0 is not a version. A profile editable without its version moving is a '
      'profile whose content_hash means nothing to the candidate that pinned it',
      [{'keyword': 'minimum', 'instancePath': '/profile_version'}])

epair('LogicalSymbol',
      {"entity": "LogicalSymbol", "logical": "XAUUSD", "asset_class": "GOLD",
       "broker_map": {"MT5-A": "XAUUSD"}, "swap_mode": "POINTS"},
      {"entity": "LogicalSymbol", "logical": "XAUUSD", "asset_class": "GOLD",
       "broker_map": {"MT5-A": "XAUUSD"}, "swap_mode": "ROLLOVER"},
      'ORDER-611: swap_mode was MEASURED, not assumed -- the tester charges POINTS swap and does '
      'NOT charge INTEREST swap (memory tester-charges-points-swap-not-interest-swap), so an '
      'invented third mode silently means "financing unknown"',
      [{'keyword': 'enum', 'instancePath': '/swap_mode'}])

epair('ParameterBinding',
      {"entity": "ParameterBinding", "hypothesis_revision": "B14-H01-r1",
       "parameter": "GridStepATR", "role": "TUNABLE", "surface": "RESEARCH",
       "definition_ref": OWNER},
      {"entity": "ParameterBinding", "hypothesis_revision": "B14-H01-r1",
       "parameter": "GridStepATR", "role": "TUNABLE", "surface": "SEMI_HIDDEN",
       "definition_ref": OWNER},
      'ORDER-611: the surface decides who is shown a parameter. A fourth, undeclared surface is a '
      'parameter with no answer to "should the operator see this?"',
      [{'keyword': 'enum', 'instancePath': '/surface'}])

# ORDER-672 G1. The positive carries the tag in its OWN FIELD; the negative carries the SAME fact
# encoded inside `parameter`, which is the shape that produced F1. Both rows describe the identical
# binding -- the delta is purely the encoding, which is what makes this a test of G1 rather than of
# anything else.
epair('ParameterBinding',
      {"entity": "ParameterBinding", "hypothesis_revision": "B14-H01-r1",
       "parameter": "StackMode", "build_tag": "LAB_ENTRY_16",
       "role": "TUNABLE", "surface": "RESEARCH", "definition_ref": OWNER},
      {"entity": "ParameterBinding", "hypothesis_revision": "B14-H01-r1",
       "parameter": "StackMode[LAB_ENTRY_16]",
       "role": "TUNABLE", "surface": "RESEARCH", "definition_ref": OWNER},
      'ORDER-672: a build tag INSIDE `parameter` is two facts in the join key. Accepting it '
      'alongside the new field would leave two encodings of one fact live at once -- which is the '
      'defect, not a migration path',
      [{'keyword': 'not', 'instancePath': '/parameter'}],
      name='buildtag')

epair('TestUniverse',
      {"entity": "TestUniverse", "universe_version": "v1", "kind": "PILOT",
       "symbols": ["XAUUSD"], "timeframes": ["H1"], "created_commit": D40},
      {"entity": "TestUniverse", "universe_version": "v1", "kind": "PILOT",
       "symbols": ["XAUUSD"], "timeframes": ["M1"], "created_commit": D40},
      'ORDER-611: M1 is not in the closed timeframe list. A universe naming a timeframe nothing '
      'else understands produces cells no runner can execute',
      [{'keyword': 'enum', 'instancePath': '/timeframes/0'}])

RUNJOURNAL_OK = {"entity": "RunJournal", "run_id": "RUN-20260731-001", "cell_id": "c1",
                 "execution_key": EXECKEY_OK, "attempts": [ATTEMPT_OK], "event_log_ref": OWNER}
epair('RunJournal', RUNJOURNAL_OK, with_(RUNJOURNAL_OK, run_id="RUN-2026-07-31-1"),
      'ORDER-611: the run id is the execution identity; a free-form id cannot be matched back to '
      'an event or a report',
      [{'keyword': 'pattern', 'instancePath': '/run_id'}])

CAND_OK = {"entity": "CandidateManifest", "candidate_id": "CAND-0123456789ab",
           "candidate_digest": H64, "payload": PAYLOAD_OK, "scorecard_ref": OWNER}
epair('CandidateManifest', CAND_OK, with_(CAND_OK, candidate_id="CAND-XYZ"),
      'ORDER-611: the candidate id carries the digest prefix, so a malformed one breaks the '
      'recompute-on-read check S10 is built around',
      [{'keyword': 'pattern', 'instancePath': '/candidate_id'}])

COVCELL_OK = {"entity": "CoverageCell", "cell_id": "c1", "hypothesis_revision": "B14-H01-r1",
              "logical_symbol": "XAUUSD", "tf": "H1", "universe_version": "v1",
              "state": "UNTESTED", "metrics": [METRIC_OK], "trial_count": 0, "backlog_ref": OWNER}
epair('CoverageCell', COVCELL_OK, with_(COVCELL_OK, tf="M1"),
      'ORDER-611: a cell naming a timeframe outside the closed list cannot be reconciled against '
      'the universe it claims to cover',
      [{'keyword': 'enum', 'instancePath': '/tf'}])

epair('MagicAllocation',
      {"entity": "MagicAllocation", "magic": 992017, "scope": "GLOBAL", "status": "RESERVED",
       "allocated_at_commit": D40},
      {"entity": "MagicAllocation", "magic": 0, "scope": "GLOBAL", "status": "RESERVED",
       "allocated_at_commit": D40},
      'ORDER-611: magic 0 is the MT5 "no magic" value, so allocating it would claim every '
      'unowned order on the account',
      [{'keyword': 'minimum', 'instancePath': '/magic'}])

epair('RunTransition',
      {"entity": "RunTransition", "run_id": "RUN-20260731-001", "cell_id": "c1", "attempt": 1,
       "transition": "QUEUED", "at": "2026-07-31T00:00:00Z", "event_log_ref": OWNER},
      {"entity": "RunTransition", "run_id": "RUN-20260731-001", "cell_id": "c1", "attempt": 0,
       "transition": "QUEUED", "at": "2026-07-31T00:00:00Z", "event_log_ref": OWNER},
      'ORDER-611: attempts are 1-based; attempt 0 makes "resume re-runs zero completed attempts" '
      '(S9) unanswerable',
      [{'keyword': 'minimum', 'instancePath': '/attempt'}])

SYSFIND_OK = {"entity": "SystemFinding", "finding_id": "FND-stale_binary-Boss_14",
              "public_id": "FP-0123456789", "detector": "check_stale_binaries",
              "detector_ref": OWNER, "class": "RUNTIME", "first_seen": "2026-07-31T00:00:00Z",
              "last_seen": "2026-07-31T00:00:00Z", "state": "OPEN", "severity": "WARN",
              "material_revision": 0}
epair('SystemFinding', SYSFIND_OK, with_(SYSFIND_OK, severity="NOISY"),
      'ORDER-611: severity drives escalation and dedupe. An undeclared severity is a finding the '
      'notifier cannot rank, which is how an escalation gets swallowed',
      [{'keyword': 'enum', 'instancePath': '/severity'}])

DEPEV_OK = {"entity": "DeploymentAttestationEvent", "event_id": "e1", "account": "159503454",
            "magic": 991001, "event_type": "OBSERVED", "at": "2026-07-31T00:00:00Z",
            "actor": "automation", "deployment_ref": OWNER, "prev_hash": "0" * 64}
epair('DeploymentAttestationEvent', DEPEV_OK, with_(DEPEV_OK, actor="cron"),
      'ORDER-611: the actor decides whether a human authorization is required. An actor outside '
      'the closed list escapes that conditional entirely',
      [{'keyword': 'enum', 'instancePath': '/actor'}])

# ---- the eight entities that are not routable at the root -----------------------------
# The isolation harness reaches them DIRECTLY, so they need no parent instance and no label to
# be believed: the contract under evaluation is the one named.

epair('ModuleUse', MODULE_OK, with_(MODULE_OK, token="STACK"),
      'ORDER-611: the LAB_CAP_ prefix is what distinguishes a capability token from a free '
      'string; without it the architecture digest hashes something nobody can resolve',
      [{'keyword': 'pattern', 'instancePath': '/token'}])

epair('MetricRef', METRIC_OK, with_(METRIC_OK, model=3),
      'ORDER-611: model 3 does not exist in the tester. A metric that cannot name which fill '
      'model produced it is a number with no provenance -- the Model-2 ban rests on this field',
      [{'keyword': 'enum', 'instancePath': '/model'}])

# ---- ORDER-1250: the UNDEFINED profit factor, owner-ratified 2026-08-03 --------------------
# Four cases, because a nullable `pf` on its own would make the undefined case REPRESENTABLE and
# leave it FAKEABLE, and the whole point of the ratified design is that the reason travels with
# the number and is bound to it in both directions.
#
#   1  the undefined cell VALIDATES               (pf: null + UNDEFINED_NO_LOSSES)
#   2  null while claiming DEFINED is REFUSED     <- the negative BOX 1a names by name
#   3  a number while claiming UNDEFINED is REFUSED  <- the other direction; without it a run
#                                                      could carry pf: 0 under the undefined
#                                                      label, which is the exact inversion
#                                                      ORDER-1230 had to repair
#   4  omitting pf_state entirely is REFUSED      <- otherwise every pre-1250 row keeps
#                                                    validating and the field is optional in
#                                                    practice while `required` says it is not
epair('MetricRef', METRIC_UNDEF_OK, with_(METRIC_UNDEF_OK, pf_state="DEFINED"),
      'ORDER-1250: a null profit factor labelled DEFINED is a metric whose own explanation '
      'contradicts it. The pilot cell that forced this change (99 trades, 99 winners, '
      'gross_loss = 0) has NO denominator, and the tester prints 0 for it -- so the label is the '
      'only thing standing between "undefined" and the most invertible number in the table',
      [{'keyword': 'type', 'instancePath': '/pf'}], name='pf-undefined')

ecase('MetricRef', 'pf-defined-cannot-be-undefined-labelled',
      'ORDER-1250: the reverse direction. A real number under UNDEFINED_NO_LOSSES would let a '
      'pf of 0 be filed as "no denominator", which is the inversion this whole field exists to '
      'stop -- 0 is a REAL profit factor and must never be reachable as a synonym for absent',
      'fail', with_(METRIC_OK, pf_state="UNDEFINED_NO_LOSSES"),
      says=[{'keyword': 'type', 'instancePath': '/instance/pf'}])

ecase('MetricRef', 'pf-state-is-not-optional',
      'ORDER-1250: pf_state is REQUIRED, not merely available. Without this case every row '
      'written before the change keeps validating, and a field nothing forces you to fill is '
      'optional however the required list is worded',
      'fail', without(METRIC_UNDEF_OK, 'pf_state'),
      says=[{'keyword': 'required', 'instancePath': '/instance',
             'missingProperty': 'pf_state'}])

epair('CandidatePayload', PAYLOAD_OK, without(PAYLOAD_OK, "trial_count"),
      'ORDER-611: trial_count is what makes discovery risk computable at all (design 6.7); a '
      'payload without it silently reports "no trials"',
      [{'keyword': 'required', 'instancePath': '', 'missingProperty': 'trial_count'}])

# ORDER-1268. Two deltas, because `build_tag` fails in two different places and only one of them
# is this schema's to catch. ABSENT is a `required` failure and belongs here. A tag naming a build
# Inputs.mqh does not declare is NOT expressible as a schema rule -- no pattern knows which builds
# exist -- and is `candidate.py`'s C10 resolution instead; run_s10_tests attacks it there. The
# split is stated so a later reader does not add a build enum here, which would be a second, and
# immediately stale, list of the builds.
epair('CandidatePayload', PAYLOAD_OK, without(PAYLOAD_OK, "build_tag"),
      'ORDER-1268: `parameters` is contractually the FULL surface, and a surface belongs to ONE '
      'build. Without build_tag the only enforceable reading of that rule is non-emptiness, which '
      'is what let a one-key parameter map validate clean',
      [{'keyword': 'required', 'instancePath': '', 'missingProperty': 'build_tag'}],
      name='build-tag-absent')

epair('CandidatePayload', PAYLOAD_OK, with_(PAYLOAD_OK, build_tag='entry14'),
      'ORDER-1268: a build_tag that is not a LAB_ENTRY_ tag cannot name a surface, so the '
      'full-surface rule has nothing to be full of',
      [{'keyword': 'pattern', 'instancePath': '/build_tag'}],
      name='build-tag-malformed')

epair('ExecutionKey', EXECKEY_OK, with_(EXECKEY_OK, model=3),
      'ORDER-611: the execution key is the cache key for evidence reuse. A model outside {1,2,4} '
      'means two different runs could share a key (audit-1 #8, the wrong cached evidence served)',
      [{'keyword': 'enum', 'instancePath': '/model'}])

epair('RunAttempt', ATTEMPT_OK, with_(ATTEMPT_OK, failure_class="WEIRD"),
      'ORDER-611: the failure class decides whether a resume is safe. An undeclared class leaves '
      'the recovery decision undefined, which is what S9 must not permit',
      [{'keyword': 'enum', 'instancePath': '/failure_class'}])

epair('SnapshotMeta', META_OK, without(META_OK, "build_id"),
      'ORDER-611: without a build id two snapshots cannot be told apart, and "which build said '
      'ALL CLEAR?" has no answer',
      [{'keyword': 'required', 'instancePath': '', 'missingProperty': 'build_id'}])

epair('SnapshotVerdict', {"reconciliation_clear": True, "reasons": []},
      {"reconciliation_clear": "true", "reasons": []},
      'ORDER-611: the verdict is a boolean the reader RECOMPUTES. The string "true" is truthy in '
      'both PowerShell and JavaScript, so a string here reads as clear to every consumer that '
      'does not type-check -- the same defect as stale_pin_acknowledged carrying "false" (audit 8)',
      [{'keyword': 'type', 'instancePath': '/reconciliation_clear'}])

epair('ReconciliationEvidence', EVIDENCE_OK, with_(EVIDENCE_OK, discovered=-1),
      'ORDER-611: a negative discovered count balances every equation the reconciliation checks '
      '(audit-5 found exactly this on three other counters)',
      [{'keyword': 'minimum', 'instancePath': '/discovered'}])

# ---- the five that already had a positive, given an attributed negative ---------------

epair('SnapshotBuilderInput', BUILDER_OK, with_(BUILDER_OK, entity="SnapshotBuilderInputV2"),
      'ORDER-611: the nine existing builder negatives had no positive one delta away inside the '
      'isolation harness; this pair is that baseline',
      [{'keyword': 'const', 'instancePath': '/entity'}])

epair('Hypothesis', HYP, with_(HYP, coupling_class="SORT_OF_COUPLED"),
      'ORDER-611: the coupling class decides whether a module change invalidates the '
      'evidence of a hypothesis; an undeclared class means that question has no answer',
      [{'keyword': 'enum', 'instancePath': '/coupling_class'}])

epair('SafeProjection', SAFEPROJ_OK, with_(SAFEPROJ_OK, account="159503454"),
      'ORDER-611: the projection is what Telegram is allowed to read. A raw account number as a '
      'top-level field is the leak the closed DTO exists to prevent',
      [{'keyword': 'unevaluatedProperties', 'instancePath': ''}])

ALERT_EVENT_OK = {"entity": "AlertEvent", "kind": "ALERT", "channel": "EMERGENCY",
                  "public_id": "FP-0123456789", "severity": "CRITICAL", "state": "OPEN",
                  "class": "RUNTIME", "material_revision": 2,
                  "dedupe_key": "FP-0123456789|OPEN|CRITICAL|2", "build_id": "b1",
                  "text": "[EA LAB] CRITICAL"}

ALERT_DELIVERY_OK = {"entity": "AlertDelivery", "dedupe_key": "FP-0123456789|OPEN|CRITICAL|2",
                     "channel": "EMERGENCY", "kind": "ALERT", "outcome": "DELIVERED",
                     "receipt": "4471", "at": "2026-08-02T00:00:00",
                     "openclaw": "NOT_RUNNING", "detail": ""}

epair('AlertEvent', ALERT_EVENT_OK, with_(ALERT_EVENT_OK, finding_id="FND-sensor-159503454"),
      'ORDER-1180 (S12): an AlertEvent is the ONLY thing that crosses the seam to a channel, and '
      'the internal finding_id may embed an account, a magic or an EA name. The closed object is '
      'what stops it arriving on the wire because somebody added it upstream',
      [{'keyword': 'unevaluatedProperties', 'instancePath': ''}])

epair('AlertDelivery', ALERT_DELIVERY_OK, with_(ALERT_DELIVERY_OK, outcome="PROBABLY_SENT"),
      'ORDER-1180 (S12): the ledger answers "did this arrive". A fifth outcome would be a fifth '
      'meaning that nothing in deliver() can produce, and the one it would most likely be '
      'confused with is DELIVERED',
      [{'keyword': 'enum', 'instancePath': '/outcome'}])

epair('ControlRoomSnapshotV5', SNAP_OK, with_(SNAP_OK, verdict={"reasons": []}),
      'ORDER-611: a snapshot whose verdict carries no reconciliation_clear cannot answer the '
      'only question it is read for',
      [{'keyword': 'required', 'instancePath': '/verdict',
        'missingProperty': 'reconciliation_clear'}])

WORKRECEIPT_OK = {"entity": "WorkReceipt", "receipt_id": "WRK-20260731-001",
                  "source_agent": "claude", "requested_at": "2026-07-31T00:00:00Z",
                  "title": "a chat commitment", "owner": "claude", "status": "IN_PROGRESS"}
epair('WorkReceipt', WORKRECEIPT_OK, with_(WORKRECEIPT_OK, source_agent="nobody"),
      'ORDER-611: the source agent is the provenance of the receipt; an unknown agent makes the '
      'duplicate detection S14 needs undecidable',
      [{'keyword': 'enum', 'instancePath': '/source_agent'}])



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


def schema_entities():
    schema = json.load(io.open(SCHEMA, encoding='utf-8'))
    return sorted((schema.get('$defs') or {}).keys()), schema


def build_isolation_schema(schema, path):
    """A harness schema that validates ONE instance against ONE named `$def`, in isolation.

    WHY THIS EXISTS, measured 2026-07-31.
      The first attempt at ORDER-611 attributed each negative to its entity by matching ajv's
      `schemaPath` against `#/$defs/<Entity>/`. That does not work, and the measurement is the
      reason: the real schema's root is a `oneOf` over 19 branches, so ONE malformed instance
      produces **20 errors**, and ajv reports the branch actually being evaluated with paths
      RELATIVE to that branch -- `#/properties/tf/enum`, with no `$defs/CoverageCell` prefix --
      while nested `$ref`s keep the absolute form. So the prefix that looked like provenance was
      present for the wrong errors and absent for the right ones.

      Validating against the entity's own `$def` removes the problem instead of working around it:
      only one contract is in play, so every error IS that entity's, by construction rather than by
      pattern-match. It also drops the noise from 20 errors to the one or two that are real, which
      is what makes a `says` spec readable.

      The envelope is `{case_entity, instance}` with one `if/then` per entity. An `if` that does not
      match contributes no errors, so exactly one contract evaluates. `case_entity` is additionally
      constrained to the closed entity list, because a typo that matched no branch would otherwise
      make every instance valid -- a harness that passes everything is worse than no harness.
    """
    defs = schema['$defs']
    ents = sorted(defs.keys())
    harness = {
        '$schema': schema.get('$schema', 'https://json-schema.org/draft/2020-12/schema'),
        '$defs': defs,
        'type': 'object',
        'required': ['case_entity', 'instance'],
        'properties': {'case_entity': {'enum': ents}},
        'allOf': [{'if': {'properties': {'case_entity': {'const': e}},
                          'required': ['case_entity']},
                   'then': {'properties': {'instance': {'$ref': '#/$defs/%s' % e}}}}
                  for e in ents],
    }
    io.open(path, 'w', encoding='utf-8').write(json.dumps(harness))
    return path


def entity_coverage(entity_cases, results):
    """ORDER-611 B1/B2: every `$defs` entity must be exercised in BOTH directions.

    The entity list is READ FROM THE SCHEMA. A hand-maintained list here would be `BACKLOG-D29`'s
    failure mode relocated into a test file: right on the day it was written and quietly wrong
    afterwards, and the only moment anybody reads it is the moment it matters. Adding a 28th `$def`
    must redden this suite in the same commit that adds it.

    Attribution is structural (see build_isolation_schema), so `covers` is not a claim that needs
    checking -- it selects the contract. What still has to be checked is that a negative names a
    SPECIFIC failure: `expect=fail` alone cannot distinguish "the rule I am testing rejected this"
    from "I made the instance unparseable".
    """
    problems = []
    try:
        entities, _ = schema_entities()
    except (IOError, ValueError) as exc:
        return ['TOOL FAILURE: cannot read %s to derive the entity list: %s' % (SCHEMA, exc)]
    if not entities:
        return ['TOOL FAILURE: %s declares no $defs, so coverage cannot be derived' % SCHEMA]

    passing, failing = set(), set()
    for c in entity_cases:
        ent = c['covers']
        if ent not in entities:
            problems.append('case %r covers %r, which is not a $defs entity' % (c['name'], ent))
            continue
        state = (results.get(c['name']) or (ERROR, ''))[0]
        if c['expect'] == VALID and state == VALID:
            passing.add(ent)
        elif c['expect'] == INVALID and state == INVALID:
            useful = [s for s in c['says'] if spec_is_discriminating(s)]
            if not useful:
                problems.append('case %r is a negative whose `says` asserts nothing (%s), so it '
                                'proves only that SOMETHING was wrong with the instance. An empty '
                                'spec matches the first error of any failing instance.'
                                % (c['name'], json.dumps(c['says'], sort_keys=True)))
                continue
            failing.add(ent)

    for ent in entities:
        if ent not in passing:
            problems.append('%s has NO case that validates. A negative with no positive cannot be '
                            'interpreted: the instance may be failing for a reason unrelated to '
                            'the rule under test.' % ent)
        if ent not in failing:
            problems.append('%s has NO negative case that names its failure. S3 is not done until '
                            'every entity rejects at least one crafted bad instance.' % ent)
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
        base_cmd = ['ajv', 'validate', '-s', schema, '--spec=draft2020', '--strict=false',
                    '--errors=line']
        # 🔴 CHUNKED, because Windows caps a command line at ~8191 characters and this batch is no
        # longer a fixed 35 fixtures -- it also validates the LIVE registry stores, which went from
        # 2 rows to 234 the day ORDER-1020 landed. Unchunked, the command reached ~19k characters
        # and cmd.exe answered "The command line is too long." for the WHOLE batch. The three-state
        # discipline held -- every case came back ERROR rather than VALID, so the tool failing was
        # not reported as the contract passing -- but 234 rows were reported as defects when every
        # one of them validates. The budget is deliberately well under 8191: the paths are absolute
        # and the temp prefix is host-dependent, so the headroom absorbs a longer TEMP than this
        # machine's.
        CMDLINE_BUDGET = 7000
        _fixed = sum(len(a) + 3 for a in base_cmd)
        chunks, current, current_len = [], [], _fixed
        for i, c in enumerate(cases):
            base = 'case_%03d.json' % i
            p = os.path.join(tmpdir, base)
            with io.open(p, 'w', encoding='utf-8') as fh:
                fh.write(json.dumps(c['instance']))
            names[base] = c['name']
            cost = len(p) + 6
            if current and current_len + cost > CMDLINE_BUDGET:
                chunks.append(current)
                current, current_len = [], _fixed
            current.append(p)
            current_len += cost
        if current:
            chunks.append(current)

        combined_parts = []
        rc_last = 0
        for chunk in chunks:
            cmd = list(base_cmd)
            for path in chunk:
                cmd += ['-d', path]
            proc = subprocess.run(cmd, capture_output=True, text=True, shell=True)
            combined_parts.append((proc.stdout or '') + '\n' + (proc.stderr or ''))
            if proc.returncode:
                rc_last = proc.returncode

        class _BatchProc(object):
            returncode = rc_last
        proc = _BatchProc()
        combined = '\n'.join(combined_parts)

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


# ----------------------------------------------------------------------- ORDER-1264 #2
# These counts used to live in the header as prose, and the S3 blind audit found every one of
# them stale: it re-measured 29 `$defs` and a 21-branch root against a header claiming 27 and 19.
# Nothing noticed, because a hand-typed measurement has no harness -- the repo has paid for that
# lesson three times (memory `measurement-table-needs-its-harness`). They are declared here and
# CHECKED below, so adding an entity or a fixture reddens this suite in the same commit instead
# of quietly ageing a sentence nobody re-reads. If a number below is wrong, the schema is not the
# thing to change: update the number, in the commit that changed the thing it counts.
HEADER_COUNTS = {
    'defs': 32,
    'root_branches': 21,
    'root_cases': 41,
    'entity_cases': 74,
    'entity_negatives': 38,
    'entities_with_a_negative': 32,
}


def measured_counts():
    doc = json.loads(io.open(SCHEMA, encoding='utf-8').read())
    negatives = [c for c in ENTITY_CASES if c['expect'] == INVALID]
    return {
        'defs': len(doc['$defs']),
        'root_branches': len(doc['oneOf']),
        'root_cases': len(CASES),
        'entity_cases': len(ENTITY_CASES),
        'entity_negatives': len(negatives),
        'entities_with_a_negative': len({c.get('covers') for c in negatives if c.get('covers')}),
    }


def check_header_counts():
    """Return the number of counts that have drifted, having printed each one."""
    live = measured_counts()
    drifted = 0
    for key in sorted(HEADER_COUNTS):
        ok = live[key] == HEADER_COUNTS[key]
        if not ok:
            drifted += 1
        print("  [%s] %-26s declared=%-4d measured=%d%s"
              % ('OK ' if ok else 'BAD', key, HEADER_COUNTS[key], live[key],
                 '' if ok else '   <- update HEADER_COUNTS in this file, not the schema'))
    # `entities_with_a_negative` is the S3 acceptance itself, so it gets a second, absolute
    # assertion rather than only an equality against a number I typed: EVERY entity must have
    # one. A declared 29 that matched a measured 29 would still be green if the schema grew to
    # 30 entities and the 30th had no negative -- the equality above catches that through
    # `defs`, but only while both numbers are maintained together, and this does not depend on
    # my having remembered to maintain either.
    covered = live['entities_with_a_negative'] == live['defs']
    if not covered:
        drifted += 1
    print("  [%s] every $defs entity has at least one NEGATIVE fixture (%d of %d)"
          % ('OK ' if covered else 'BAD', live['entities_with_a_negative'], live['defs']))
    return drifted


def main():
    print("=== real JSON Schema validation (ajv, draft 2020-12) ===")
    print("schema: %s\n" % SCHEMA)
    bad = 0
    print("COUNTS THIS SUITE CLAIMS ABOUT ITSELF (ORDER-1264 #2)")
    bad += check_header_counts()
    print("")
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

    print("\n--- ORDER-611: every $defs entity, against its own contract in isolation ---")
    entities, schema_doc = schema_entities()
    tmpdir = tempfile.mkdtemp(prefix='isoschema_')
    try:
        harness = build_isolation_schema(schema_doc, os.path.join(tmpdir, 'isolation.json'))
        ebatch = run_batch(harness, ENTITY_CASES)
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)
    ebad = 0
    for c in ENTITY_CASES:
        got, out = ebatch[c['name']]
        good = got != ERROR and got == c['expect']
        notes = unmet_says(out, c['says']) if (good and c['says'] and c['expect'] == INVALID) else []
        if notes:
            good = False
        if not good:
            ebad += 1
            print("  [BAD] %-46s expect=%s got=%-5s (%s)"
                  % (c['name'], c['expect'], got, c['guards'][:90]))
            for n in notes:
                print("        -> %s" % n)
            if not notes and out:
                print("        %s" % out.splitlines()[-1][:200])
    bad += ebad
    print("  %d entity case(s), %d behaved as declared, %d did not"
          % (len(ENTITY_CASES), len(ENTITY_CASES) - ebad, ebad))

    # THE HARNESS MUST NOT BE ABLE TO PASS EVERYTHING. Its whole shape is `if case_entity == X
    # then instance matches $defs/X`, and an `if` that does not match contributes no errors -- so
    # a harness whose branches never fire would report every case valid, including all 27
    # negatives. Two probes, run against the same generated schema the cases used:
    #   1. an unroutable case_entity must be REJECTED by the closed enum, not silently ignored;
    #   2. a well-formed instance of one entity, presented as ANOTHER, must be REJECTED -- that is
    #      the proof the branches actually route rather than all matching.
    tmpdir = tempfile.mkdtemp(prefix='isoprobe_')
    try:
        harness = build_isolation_schema(schema_doc, os.path.join(tmpdir, 'isolation.json'))
        probes = [
            {'name': 'harness-unknown-entity', 'expect': INVALID, 'says': [],
             'instance': {'case_entity': 'NotAnEntity', 'instance': OWNER}},
            {'name': 'harness-routes-to-the-named-contract', 'expect': INVALID, 'says': [],
             'instance': {'case_entity': 'TestUniverse', 'instance': OWNER}},
            {'name': 'harness-control-same-entity-validates', 'expect': VALID, 'says': [],
             'instance': {'case_entity': 'OwnerRef', 'instance': OWNER}},
        ]
        pbatch = run_batch(harness, probes)
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)
    for pr in probes:
        got = pbatch[pr['name']][0]
        ok = got != ERROR and got == pr['expect']
        if not ok:
            bad += 1
        print("  [%s] %-46s expect=%s got=%s"
              % ('OK ' if ok else 'BAD', pr['name'], pr['expect'], got))

    cov = entity_coverage(ENTITY_CASES, ebatch)
    if cov:
        print("  [BAD] %d entity-coverage problem(s):" % len(cov))
        for p in cov:
            print("        -> %s" % p)
        bad += len(cov)
    else:
        print("  [OK ] all %d $defs entities have a case that VALIDATES and a negative that names "
              "its\n        own failure" % len(entities))

    # ...and the claim on the line above -- "the list is read from $defs, so a 28th entity would
    # redden this" -- is a claim, so it is checked rather than printed. Without this, a coverage
    # criterion that had silently stopped enumerating would report OK forever.
    # Codex audit, Standards 4: `says=[{}]` used to earn coverage, because an empty spec matches
    # every error and the criterion only checked the list was non-empty. Probed here permanently,
    # against a real passing case, so the repair cannot quietly come undone.
    _victim = next(c for c in ENTITY_CASES if c['expect'] == INVALID)
    _saved = _victim['says']
    # Codex round 2, Standards 4: `[{}]` was closed, but `[{"bogus": null}]` walked straight
    # through -- an unknown key made the spec look discriminating, and then matched an unrelated
    # error because `params.get("bogus")` is None and the spec's value was None too. Both shapes
    # are probed now, and so is a key whose value is null, which asserts nothing by construction.
    for label, spec in (('`{}`', [{}]),
                        ('an UNKNOWN key (`{"bogus": null}`)', [{'bogus': None}]),
                        ('an unknown key with a value', [{'bogus': 'x'}]),
                        ('a known key whose value is null', [{'missingProperty': None}]),
                        ('only `schemaPath_startswith`',
                         [{'schemaPath_startswith': '#/$defs/OwnerRef/'}])):
        try:
            _victim['says'] = spec
            _probe = entity_coverage(ENTITY_CASES, ebatch)
        finally:
            _victim['says'] = _saved
        if any(_victim['name'] in p for p in _probe):
            print("  [OK ] CONTROL a negative whose `says` is %s asserts nothing -> refused" % label)
        else:
            print("  [BAD] CONTROL `says=%s` still earns coverage" % spec)
            bad += 1

    _real = globals()['schema_entities']
    try:
        globals()['schema_entities'] = lambda: (sorted(list(entities) + ['A28thEntity']), schema_doc)
        probe = entity_coverage(ENTITY_CASES, ebatch)
    finally:
        globals()['schema_entities'] = _real
    named = [p for p in probe if 'A28thEntity' in p]
    if len(named) == 2:      # one for the missing positive, one for the missing negative
        print("  [OK ] CONTROL a 28th entity added to $defs is reported missing in BOTH "
              "directions")
    else:
        print("  [BAD] CONTROL a 28th entity produced %d complaint(s), expected 2 -- the coverage "
              "criterion is not enumerating what it claims to" % len(named))
        bad += 1

    print("\n--- snapshot_validator's ajv gate (x-enforced-by's actual claim) ---")
    gate = check_validator_schema_gate()
    print("  [%s] a valid input passes, an ajv-rejected input is refused naming the property, "
          "and a\n       missing schema is refused as TOOL FAILURE rather than as rejection"
          % ('OK ' if not gate else 'BAD'))
    for p in gate:
        print("        -> %s" % p)
    bad += len(gate)

    # --- the LIVE registry rows, against their typed contracts ------------------------------
    # BLIND AUDIT 2026-07-31: check_registries' R5 checks required-key PRESENCE only, so an
    # InstrumentProfile with every required value set to `null` plus an unknown field passed R5
    # while ajv rejected the same object. R5's own text says "required-field floor, not full
    # validation" -- which is honest, and leaves the live rows bound to nothing typed.
    #
    # This is where that binding belongs: ajv already runs here, so the node budget is paid, and
    # the fast tier stays as it is. R5 remains the fast-path floor; THIS is the contract.
    print("\n--- the LIVE registry stores, each row against its own entity contract ---")
    import registry as _reg
    import evidence as _ev
    # ORDER-670: these two blocks judge REAL inputs (the live stores, the committed snapshot),
    # so they read through the evidence source -- the index in hook mode. Everything above this
    # line is synthetic fixtures (category C) and stays exactly as it is.
    try:
        _src = _ev.EvidenceSource.for_run()
    except _ev.ToolFailure as _exc:
        print("  TOOL FAILURE: %s" % _exc)
        return 2
    print("  " + _src.marker('run_schema_fixtures.py'))
    _live = 0
    try:
        _stores = _reg.load_all(source=_src)
    except _reg.RegistryRefusal as _exc:
        print("  TOOL FAILURE: %s" % _exc)
        bad += 1
        _stores = {}
    # 🔴 BATCHED, and the measurement is the reason. This loop called `run()` -- ONE AJV SPAWN PER
    # ROW -- which is the identical defect `run_batch`'s own docstring records being fixed for the
    # fixture cases (11.5s of pure process startup, 35 spawns). It was invisible here for as long
    # as the live stores were empty: three of five carried no rows, so the loop spawned nothing.
    # MEASURED the day ORDER-1020 landed 232 ParameterBinding rows: this suite went
    # **2.3s -> 77.2s**, and took `run_contract_binding_tests.ps1` (which runs it) to 100.9s and
    # the whole per-path tier to 160.7s against a 65.0s budget. That is ~0.32s per row, LINEAR in
    # the size of a store the Factory OS design intends to grow by an order of magnitude -- 2,000
    # rows would be an eleven-minute pre-commit hook, which is how a tier earns `--no-verify`.
    _cases = []
    for _rel in sorted(_stores):
        _meta, _rows = _stores[_rel]
        for _n, _rec in _rows:
            # ORDER-610's imported coverage rows predate the `entity` discriminator and are pinned
            # to a source blob; they are not CoverageCell objects yet and routing them to that
            # contract would report a migration that has not happened as a defect. Named here
            # rather than skipped silently, and it ends when S5's real CoverageCell rows land.
            if _rec.get('entity') is None and _rel == 'factory/coverage.jsonl':
                continue
            _cases.append({'name': '%s:%d' % (_rel, _n), 'instance': _rec})
    _live = len(_cases)
    if _cases:
        _results = run_batch(SCHEMA, _cases)
        for _c in _cases:
            _got, _out = _results[_c['name']]
            if _got != VALID:
                _rel, _n = _c['name'].rsplit(':', 1)
                print("  [BAD] %s line %s does not validate as %s"
                      % (_rel, _n, _reg.STORES[_rel]))
                print("        %s" % (_out.splitlines()[1][:220] if len(_out.splitlines()) > 1
                                      else _out[:220]))
                bad += 1
    print("  %d live registry row(s) validated against their declared entity" % _live)
    if _live == 0:
        # The guard rule, applied here: a run that validated nothing proves nothing, and must say
        # so rather than printing a clean line. Three of the five stores are empty by design.
        print("  0 rows means this check is UNTESTED by this run, not that the stores are clean")

    # --- ORDER-1500: the committed scheduler recovery journals -----------------------------
    # `factory/runs/*.jsonl` is deliberately NOT added to registry.STORES. It is an unbounded
    # append-only journal whose persisted entity is one RunTransition per line. The validator
    # below is beside this AJV live-input pass so the existing schema-tool invocation is reused.
    # Three owner-approved historical manifests are accepted only by exact path + ID + bytes;
    # every other row must pass the current RunTransition contract normally.
    print("\n--- ORDER-1500 committed scheduler recovery journals ---")
    import run_journal_validator as _journal_validator
    try:
        _journal_report = _journal_validator.validate_run_journals(_src, SCHEMA)
    except _journal_validator.JournalInfrastructureError as _exc:
        print("  TOOL FAILURE: %s" % _exc)
        bad += 1
    else:
        _legacy = sum(1 for _r in _journal_report.rows
                      if _r['state'] == _journal_validator.LEGACY_EXCEPTION)
        _valid = sum(1 for _r in _journal_report.rows
                     if _r['state'] == _journal_validator.VALID)
        _invalid = _journal_report.invalid_rows
        for _r in _invalid:
            print("  [BAD] %s:%s (%s) %s" % (_r['file'], _r['line'], _r['state'],
                                               _r['detail'][:220]))
        if _invalid:
            bad += len(_invalid)
        print("  %d row(s) VALID, %d row(s) LEGACY_EXCEPTION, %d row(s) INVALID" %
              (_valid, _legacy, len(_invalid)))
        if _journal_report.legacy_files:
            print("  legacy files: %s" % ', '.join(sorted(_journal_report.legacy_files)))
        print("  retention wake: prune only after the corresponding event-log occurrence is durable; "
              "no automatic deletion is performed")

    print("\n--- the real snapshot, validated against the schema that claims to describe it ---")
    # C1 is a claim about the artifact THIS COMMIT contains (design section 2: the
    # commit-vintage claim about a builder's output is made by a checker, never the builder).
    try:
        _real = json.loads(_src.read_committed('portfolio/control_room_snapshot.json'))
    except _ev.ToolFailure as _exc:
        print("  portfolio/control_room_snapshot.json -> TOOL ERROR, not a verdict: %s"
              % str(_exc)[:160])
        bad += 1
        _real = None
    got, out = (ERROR, '') if _real is None else run(SCHEMA, _real)
    if _real is None:
        pass  # unreadable: already reported and counted at the read
    elif got == ERROR:
        # Distinguish "the schema says no" from "the tool fell over" here too -- otherwise the
        # S4 acceptance line could read FAILS forever for a reason nobody is tracking.
        print("  portfolio/control_room_snapshot.json -> TOOL ERROR, not a verdict: %s"
              % out.splitlines()[0][:120])
        bad += 1
    elif got != VALID:
        # ORDER-612 (S4) CLOSED THIS. Until 2026-07-31 this line PRINTED its result and did not
        # count it, because the real file was a v3 artifact and the schema described the v5 target.
        # That made it a report, not a check -- and a report is exactly what nothing notices when
        # it changes. It is an assertion now: the writer emits v5 through snapshot_build.py, so a
        # real snapshot that stops validating is a REGRESSION, not a known gap.
        print("  portfolio/control_room_snapshot.json -> FAILS")
        print("  This is COUNTED AS A FAILURE (ORDER-612 / S4). The committed snapshot is written")
        print("  by scripts/control_room_snapshot.ps1 -> _triage/factory_os/snapshot_build.py,")
        print("  which validates against ControlRoomSnapshotV5 before it replaces the file. So a")
        print("  FAILS here means one of: the writer regressed, the schema and the writer drifted")
        print("  apart, or somebody hand-edited the canonical snapshot. ajv said:")
        # NOT out.splitlines()[0]: that is ajv's "<tempfile> invalid" banner, naming a file that is
        # already deleted and nothing else. Observed on this exact line while proving the assertion
        # can go red.
        #
        # But the error ARRAY on the next line is no better here, and that was observed too: this
        # validates against the REAL ROOT, whose `oneOf` has 19 branches, so ajv reports the first
        # error of every branch and the output opened with `missingProperty: owner_type`. The cause
        # was `meta.version: 4`. Filtering that noise by entity name is the heuristic
        # snapshot_validator._describe_ajv_errors already documents as unworkable, so instead the
        # same instance is asked a SECOND, focused question -- validate it against
        # #/$defs/ControlRoomSnapshotV5 alone -- which is precise by construction. The root run
        # keeps the discriminator; the focused run names the property.
        import snapshot_validator as _sv
        try:
            _sv.ajv_schema_validator(_real, 'ControlRoomSnapshotV5')
            print("    (the root `oneOf` rejected it but the focused entity accepted it -- that is")
            print("     a DISCRIMINATOR failure: `entity` does not select this branch.)")
        except _sv.SnapshotRefusal as _exc:
            print("    %s" % str(_exc)[:400])
        bad += 1
    else:
        print("  portfolio/control_room_snapshot.json -> PASSES")
        print("  This is the ORDER-612 / S4 acceptance (C1), and it is ASSERTED, not reported:")
        print("  the line above was a printed observation until 2026-07-31 and is now counted, so")
        print("  the suite goes red if the real document stops matching the contract that claims")
        print("  to describe it. The migration it was waiting on: root `entity` + `verdict`,")
        print("  meta.build_id + mandatory_sources + reconciliation, and source rows carrying BOTH")
        print("  identities -- `path` physical (hashed, stat-ed, re-derivable) and `name` logical")
        print("  (what mandatory_sources enumerates and the reconciliation joins on).")

    # The count is DERIVED from both lists. It read "ALL %d CASES" % len(CASES) after ORDER-611
    # added 54 more, which would have reported 35 while running 89 -- the same drift as the
    # "24 mutations" label in run_s2a_gate.py that was already 27.
    print("\n=== %s ===" % ('ALL %d CASES BEHAVED AS DECLARED (%d root + %d per-entity)'
                            % (len(CASES) + len(ENTITY_CASES), len(CASES), len(ENTITY_CASES))
                            if bad == 0 else '%d CASE(S) DID NOT' % bad))
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
