"""EA_LAB W5 Build6230 prospective evidence gate reference (T0, offline ONLY).

No MT5/MQL5 imports, broker calls, filesystem mutation or source integration.
Never emits NATIVE_PASS or authorizes a tester run.
"""
import copy
import datetime
import hashlib
import json
import math
import os
from pathlib import Path, PurePosixPath

EXPECTED = {
    "source_head": "4f0254340d0f7610223eb8ee507bb0ed141bd323",
    "source_tree": "c521daad1119a69fec18060ec5c46d7aa0365e8d",
    "set_sha256": "c145f3f472c540aba9c9fd82fdd22034eba73e44f5de4d90199b1234e88ab6fd",
    "terminal_sha256": "f163b8069e3f34f5cb4556e02e06ba69b65816d6990e7dc360b01a9501616072",
    "ex5_off_sha256": "aa06cf4969139f13eee4c0c1c57cdc3d9f16d36b2de0e992d7f03d93b26c45ac",
    "ex5_on_sha256": "14a792616c0117d18e2f45d4b7969c1b041f13662647f18cd5f9cf5c75de7f88",
    "symbol": "XAUUSD", "timeframe": "H1", "model": 1,
    "broker": "ThinkMarkets-Live", "deposit": 10000,
    "leverage": 100,
}
ECON_FIELDS = (
    "contract_size", "tick_size", "tick_value", "margin_initial",
    "margin_maintenance", "margin_rate", "commission_value",
    "commission_type", "swap_long", "swap_short", "swap_mode",
    "spread_mode", "spread_fixed_or_default", "lot_min", "lot_step", "lot_max",
)
ACCOUNT_FIELDS = ("currency", "leverage", "trade_mode", "stopout_level", "stopout_mode")
CHANGED = (
    "history/XAUUSD/2026.hcc", "history/XAUUSD/cache/Daily.hc",
    "symbols/selected-146237.dat",
)
HISTORICAL_YEAR_SHA = {
    "2020": "9358537f5cb8ceec65dca87ec6022a5e7c59de8542413aaee838b65f4dcf8b68",
    "2021": "c0b73b9a160ed70d25cde86e39386c86867bfef0b5916cc563d412a62f8625ae",
    "2022": "d43c69c96dc687107ea1f5a01c62d16397e7974c8dd330dd7684eec5e6f5a70c",
    "2023": "7fa5297224b4324270b685f5cf1768187d621445c4b6dd3ebacf9bb34219d7a3",
    "2024": "845677192e0062183b058cd89f68481bd696b5b282664f929c5e83a0687203b0",
    "2025": "78f81d86765358555ab0947c6827f615c2114db857905175865738facb37d9fa",
}
HISTORICAL_DRIFT_SHA = {
    "history/XAUUSD/2026.hcc": (
        "13304c4dc16c4aff09cd99884a651e29ec95d9472d3cb7805361341e3cccca3c",
        "cfc4a85262e035e6d386b256b13028f170886453428ff7e545210e1428a3b74e",
    ),
    "history/XAUUSD/cache/Daily.hc": (
        "bbbc399e4d6251533d2a7d501aee45c5cea1584ee57e70b519e66c9aeb05f778",
        "6ba0e8af0ea90692823423f6c5bf7c5eeab7dea86e54cd1ed09df147467a4467",
    ),
    "symbols/selected-146237.dat": (
        "59e4c98adc78902afea75ada7c256b0be4c734c67a9704f1b014c4d7b8fcd7e3",
        "ad755009ffeae18507656a378f1b7d791c42c78ffc925c45b190246ed5c796bd",
    ),
}
HISTORICAL_PROVENANCE_SHA = {
    "manifest_sha256": "363b87cd22c8f7d68272980b04f855f4ff3efb99a01eda0d18efdb2f2086f47d",
    "audit_sha256": "dcf6aed1fe146eba7b6cd757e45b71d0d371ffec38d2c96226de4500f61d0b36",
    "result_sha256": "9670ea6fbce6fa1e96b2fdd066d84f4ea79732694769eed841d6f80732926bd0",
}

CHECKPOINTS = ("S0_BEFORE_PREPROBE", "S1_AFTER_PREPROBE_BEFORE_TESTER",
               "S2_AFTER_TESTER_BEFORE_POSTPROBE", "S3_AFTER_POSTPROBE")


def _hex64(value):
    return (isinstance(value, str) and len(value) == 64
            and any(c != "0" for c in value)
            and all(c in "0123456789abcdef" for c in value))


def _utc(t):
    """Strict, normalized UTC ISO8601 date/time (not just sortable strings)."""
    if not isinstance(t, str) or not t.endswith("Z") or "T" not in t:
        return None
    try:
        dt = datetime.datetime.fromisoformat(t[:-1] + "+00:00")
    except ValueError:
        return None
    if dt.utcoffset() != datetime.timedelta(0) or dt.year < 2020:
        return None
    return dt


def _valid_value(field, value):
    """Explicit typed values; null/bool/nonfinite placeholders are not evidence."""
    text_fields = {"commission_type", "swap_mode", "spread_mode",
                   "currency", "trade_mode", "stopout_mode"}
    if field in text_fields:
        return isinstance(value, str) and bool(value.strip()) and value.upper() not in {"UNKNOWN", "NA", "N/A", "NULL"}
    if field == "leverage":
        return type(value) is int and value > 0
    if type(value) not in (int, float) or not math.isfinite(value):
        return False
    if field in {"tick_size", "contract_size", "lot_min", "lot_step", "lot_max"}:
        return value > 0
    if field in {"margin_initial", "margin_maintenance", "margin_rate", "spread_fixed_or_default", "stopout_level"}:
        return value >= 0
    return True


def load_json_strict(src):
    """Reject duplicate keys and nonstandard NaN/Infinity before policy logic."""
    def no_dups(pairs):
        out = {}
        for key, val in pairs:
            if key in out:
                raise ValueError("DUPLICATE_JSON_KEY:" + key)
            out[key] = val
        return out
    def no_special(token):
        raise ValueError("NONFINITE_JSON:" + token)
    return json.loads(src, object_pairs_hook=no_dups, parse_constant=no_special)


def audit_manifest(root, manifest):
    """Read-only hash audit of bytes in a root; refuses symlinks and traversal.

    An audit has no process-liveness or transactional snapshot authority. A native
    stage must additionally prove capture provenance and an exclusive resource lease.
    """
    reasons, checked, seen = [], 0, set()
    base = Path(root)
    records = manifest.get("files") if isinstance(manifest, dict) else None
    if not isinstance(records, list) or not records:
        return {"all_match": False, "checked": 0, "reasons": ["MANIFEST_NOT_NONEMPTY_LIST"]}
    for row in records:
        if not isinstance(row, dict):
            reasons.append("INVALID_ROW")
            continue
        name = row.get("path")
        if not isinstance(name, str):
            reasons.append("INVALID_PATH")
            continue
        name = name.replace('\\', '/')
        parts = PurePosixPath(name).parts
        if not name or name.startswith('/') or ':' in name or not parts or any(z in ('..', '.') for z in parts) or '\x00' in name:
            reasons.append("UNSAFE_PATH:" + name)
            continue
        normalized = '/'.join(parts)
        if normalized in seen:
            reasons.append("DUPLICATE_PATH:" + normalized)
            continue
        seen.add(normalized)
        candidate = base.joinpath(*parts)
        if any((base.joinpath(*parts[:i])).is_symlink() for i in range(1, len(parts)+1)):
            reasons.append("SYMLINK_PATH:" + normalized)
            continue
        expected = row.get("sha256")
        if not _hex64(expected):
            reasons.append("INVALID_SHA:" + normalized)
            continue
        length = row.get("bytes")
        if type(length) is not int or length < 0:
            reasons.append("INVALID_BYTES:" + normalized)
            continue
        try:
            flags = os.O_RDONLY | getattr(os, 'O_NOFOLLOW', 0)
            fd = os.open(candidate, flags)
            with os.fdopen(fd, 'rb') as stream:
                h = hashlib.sha256()
                actual_bytes = 0
                for chunk in iter(lambda: stream.read(1024*1024), b''):
                    actual_bytes += len(chunk)
                    h.update(chunk)
        except (OSError, ValueError):
            reasons.append("MISSING_OR_UNREADABLE:" + normalized)
            continue
        checked += 1
        if h.hexdigest() != expected:
            reasons.append("HASH_MISMATCH:" + normalized)
        if actual_bytes != length:
            reasons.append("SIZE_MISMATCH:" + normalized)
    return {"all_match": not reasons and checked == len(records),
            "checked": checked, "reasons": sorted(set(reasons))}


def assess_historical(d):
    """Receipt-level consistency only; historical FAIL is unconditional."""
    reasons = []
    if not isinstance(d, dict):
        return {"historical_verdict": "POSTCONDITION_FAIL", "receipt_consistent": False,
                "reasons": ["HISTORICAL_PACKET_NOT_OBJECT"], "native_acceptance": False}
    if d.get("historical_postcondition") != "POSTCONDITION_FAIL":
        reasons.append("OLD_FAIL_RELABELED")
    if d.get("checked_count") != 106 or d.get("drift_count") != 3:
        reasons.append("AUDIT_COUNTS_CHANGED")
    drifts = d.get("drifts")
    if not isinstance(drifts, list) or len(drifts) != 3 or {z.get("path") for z in drifts if isinstance(z, dict)} != set(CHANGED):
        reasons.append("AUDIT_THREE_PATHS_CHANGED")
    else:
        for x in drifts:
            if (not _hex64(x.get("pre_sha256")) or not _hex64(x.get("post_sha256"))
                    or x["pre_sha256"] == x["post_sha256"]):
                reasons.append("DRIFT_SHA_INVALID_" + x["path"])
            if (x.get('pre_sha256'), x.get('post_sha256')) != HISTORICAL_DRIFT_SHA[x['path']]:
                reasons.append("DRIFT_PINNED_SHA_MISMATCH_" + x["path"])
    ys = d.get("source_years")
    if not isinstance(ys, dict) or set(ys) != {str(i) for i in range(2020, 2026)}:
        reasons.append("SOURCE_YEAR_INVENTORY_INCOMPLETE")
    else:
        for year, row in ys.items():
            if not isinstance(row, dict) or not _hex64(row.get("pre_sha256")) or row.get("post_sha256") != row.get("pre_sha256"):
                reasons.append("M1_YEAR_CHANGED_" + year)
            if (not isinstance(row, dict) or row.get('pre_sha256') != HISTORICAL_YEAR_SHA[year]):
                reasons.append('M1_YEAR_PINNED_SHA_MISMATCH_' + year)
    identity = d.get("identity") if isinstance(d.get("identity"), dict) else {}
    for k, v in EXPECTED.items():
        if identity.get(k) != v:
            reasons.append("IDENTITY_MISMATCH_" + k.upper())
    if d.get("executed_cells") != ["MAIN_OFF"]:
        reasons.append("HISTORICAL_CELL_COUNT_MISMATCH")
    if d.get("holdout_executed") is not False:
        reasons.append("HOLDOUT_STATUS_NOT_PROVEN")
    provenance = d.get('provenance') if isinstance(d.get('provenance'), dict) else {}
    for k, sha in HISTORICAL_PROVENANCE_SHA.items():
        if provenance.get(k) != sha:
            reasons.append('HISTORICAL_SOURCE_PIN_MISMATCH_' + k)
    return {"historical_verdict": "POSTCONDITION_FAIL", "receipt_consistent": not reasons,
            "reasons": sorted(set(reasons)), "native_acceptance": False}


def assess_prospective(p):
    """Assess completeness of a *future* packet. Structural result is never native acceptance."""
    if not isinstance(p, dict):
        return {"classification": "BLOCKED", "reasons": ["PACKET_NOT_OBJECT"],
                "native_acceptance": False, "t3_authorization_granted_by_this_tool": False}
    reasons = []
    if p.get("kind") != "PROSPECTIVE_NEW_LINEAGE":
        reasons.append("WRONG_PACKET_KIND")
    if p.get("independent_method_review") != "ACCEPTED_EXACT_VERSION":
        reasons.append("INDEPENDENT_REVIEW_MISSING")
    if p.get("owner_t3") != "EXACT_SCOPED_APPROVAL":
        reasons.append("OWNER_T3_MISSING")
    if p.get("exclusive_resource_lease") != "VERIFIED":
        reasons.append("LEASE_UNVERIFIED")
    if p.get("prior_fail_preserved") is not True:
        reasons.append("OLD_FAIL_NOT_PRESERVED")
    identity = p.get("identity") if isinstance(p.get("identity"), dict) else {}
    for k, v in EXPECTED.items():
        if identity.get(k) != v:
            reasons.append("IDENTITY_MISMATCH_" + k.upper())
    cell = p.get("cell")
    if cell not in {"MAIN_OFF", "MAIN_ON", "BWD_OFF", "BWD_ON"}:
        reasons.append("UNKNOWN_CELL")
    if cell in {"MAIN_ON", "BWD_OFF", "BWD_ON"} and p.get("prior_cell_accepted") is not True:
        reasons.append("PREVIOUS_CELL_NOT_ACCEPTED")
    if p.get("range") != (["2023.01.01", "2025.12.31"] if cell in ("MAIN_OFF", "MAIN_ON") else ["2020.01.01", "2022.12.31"]):
        reasons.append("WINDOW_MISMATCH")
    if p.get("basket_tf_enum") != 16385 or p.get("basket_tf_label") != "PERIOD_H1":
        reasons.append("TIMEFRAME_ENUM_ERROR")
    checkpoints = p.get("checkpoints", [])
    if not isinstance(checkpoints, list) or len(checkpoints) != 4 or any(not isinstance(x, dict) for x in checkpoints) or [x.get("stage") for x in checkpoints] != list(CHECKPOINTS):
        reasons.append("S0_S1_S2_S3_MISSING_OR_UNORDERED")
    else:
        times = [_utc(x.get("asof_utc")) for x in checkpoints]
        if any(t is None for t in times) or times != sorted(times) or len(set(times)) != 4:
            reasons.append("CHECKPOINT_TIMESTAMP_INVALID")
        for x in checkpoints:
            capture = x.get("capture")
            if (not isinstance(capture, dict) or type(capture.get("pid")) is not int
                    or capture.get("pid") <= 0 or _utc(capture.get("created_utc")) is None
                    or (_utc(x.get("asof_utc")) is not None
                        and _utc(capture.get("created_utc")) > _utc(x.get("asof_utc")))
                    or not _hex64(capture.get("exe_sha256"))):
                reasons.append("CHECKPOINT_CAPTURE_IDENTITY_MISSING")
                break
        identities = [x.get("resource_identity") for x in checkpoints]
        if any(not isinstance(z, str) or not z for z in identities) or len(set(identities)) != 1:
            reasons.append("CHECKPOINT_ACTOR_MISMATCH")
        if any(not _hex64(x.get("manifest_sha256")) or not _hex64(x.get("evidence_sha256")) for x in checkpoints):
            reasons.append("CHECKPOINT_HASH_UNBOUND")
    agent = p.get("agent", {})
    if not isinstance(agent, dict):
        agent = {}
    if agent.get("baseline_mode") not in {"EMPTY", "PINNED_NONEMPTY"}:
        reasons.append("AGENT_CACHE_MODE_AMBIGUOUS")
    if not _hex64(agent.get("pre_manifest_sha256")) or not _hex64(agent.get("post_manifest_sha256")):
        reasons.append("AGENT_PREPOST_MISSING")
    if agent.get("consumed_history_source_bound") is not True or not _hex64(agent.get("consumption_trace_sha256")):
        reasons.append("AGENT_CONSUMPTION_UNPROVEN")
    if agent.get("allowed_changes_predeclared") is not True:
        reasons.append("AGENT_ALLOWED_TRANSITIONS_UNDEFINED")
    if cell in ("BWD_OFF", "BWD_ON") and p.get("pre2020_warmup_reachability") != "PROVEN":
        reasons.append("BWD_2019_WARMUP_UNPROVEN")
    hist = p.get("effective_history", {})
    if not isinstance(hist, dict):
        hist = {}
    if hist.get("source_years_unchanged") is not True or hist.get("indicator_timeframes_consumed_bound") is not True:
        reasons.append("EFFECTIVE_PRICE_OR_HTF_TRACE_UNPROVEN")
    if not _hex64(hist.get("source_manifest_sha256")) or not _hex64(hist.get("agent_series_sha256")):
        reasons.append("EFFECTIVE_HISTORY_UNBOUND")
    economics = p.get("economics", {})
    if not isinstance(economics, dict):
        economics = {}
    if economics.get("producer_authenticated") is not True or not _hex64(economics.get("producer_proof_sha256")):
        reasons.append("ECONOMICS_PRODUCER_NOT_AUTHENTICATED")
    if economics.get("agent_effective_proven") is not True or not _hex64(economics.get("agent_evidence_sha256")):
        reasons.append("AGENT_EFFECTIVE_ECONOMICS_UNKNOWN")
    before, after = economics.get("pre"), economics.get("post")
    if not isinstance(before, dict) or not isinstance(after, dict):
        reasons.append("BROKER_ECON_PREPOST_MISSING")
    else:
        left_e, right_e = before.get("economics"), after.get("economics")
        left_a, right_a = before.get("account_configuration"), after.get("account_configuration")
        if not isinstance(left_e, dict): left_e = {}
        if not isinstance(right_e, dict): right_e = {}
        if not isinstance(left_a, dict): left_a = {}
        if not isinstance(right_a, dict): right_a = {}
        for field, l, r, prefix in (
                [(f, left_e, right_e, "BROKER_ECON") for f in ECON_FIELDS]
                + [(f, left_a, right_a, "ACCOUNT") for f in ACCOUNT_FIELDS]):
            if field not in l or field not in r:
                reasons.append(prefix + "_FIELD_MISSING_" + field)
            else:
                if not _valid_value(field, l[field]) or not _valid_value(field, r[field]):
                    reasons.append(prefix + "_FIELD_INVALID_" + field)
                if type(l[field]) is not type(r[field]) or l[field] != r[field]:
                    reasons.append(prefix + ("_CHANGED_" if prefix == "BROKER_ECON" else "_FIELD_CHANGED_") + field)
        if (isinstance(left_e.get('lot_min'), (float,int)) and
                isinstance(left_e.get('lot_max'), (float,int)) and
                left_e.get('lot_min') > left_e.get('lot_max')):
            reasons.append('BROKER_ECON_LOT_RANGE_INVALID')
    mutations = p.get("mutable_artifacts", {})
    if not isinstance(mutations, dict): mutations = {}
    for x in CHANGED:
        m = mutations.get(x, {})
        if not isinstance(m, dict): m = {}
        if not _hex64(m.get("full_preimage_sha256")) or not _hex64(m.get("full_postimage_sha256")):
            reasons.append("MUTABLE_PREPOST_UNBOUND_" + x)
        elif m["full_preimage_sha256"] != m["full_postimage_sha256"]:
            # A self-asserted causality string, or a hash pointing at an unseen
            # proof document, is not an authenticated proof or permission to waive.
            # Only a later independently accepted method may decide exceptions.
            reasons.append("UNCLASSIFIED_MUTATION_" + x)
    if p.get("native_report_and_trades_bound") is not True or not _hex64(p.get("native_report_sha256")):
        reasons.append("NATIVE_REPORT_INCOMPLETE")
    if p.get("tester_process_pid_creation_exe_proven") is not True:
        reasons.append("TESTER_PROCESS_PROVENANCE_MISSING")
    if p.get("holdout_executed") is not False:
        reasons.append("HOLDOUT_SCOPE_VIOLATION_OR_UNKNOWN")
    return {"classification": "BLOCKED" if reasons else "OFFLINE_STRUCTURAL_READY_NOT_NATIVE_ACCEPTED",
            "reasons": sorted(set(reasons)), "native_acceptance": False,
            "t3_authorization_granted_by_this_tool": False}


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Offline W5 B6230 evidence comparator; never authorizes MT5")
    parser.add_argument("mode", choices=["historical", "prospective", "audit"])
    parser.add_argument("file")
    parser.add_argument("--root", help="read-only root for audit mode; required for audit")
    args = parser.parse_args()
    v = load_json_strict(Path(args.file).read_text(encoding="utf-8"))
    if args.mode == "audit":
        if not args.root:
            parser.error("audit mode requires --root")
        result = audit_manifest(args.root, v)
    elif args.mode == "historical":
        result = assess_historical(v)
    else:
        result = assess_prospective(v)
    print(json.dumps(result, indent=2, sort_keys=True))
    # Exit 0 is ONLY for a byte-identical read-only file audit. For both
    # historical failed evidence and future offline-only structure, the CLI
    # explicitly refuses the zero exit code that a native gate might mistake
    # for an acceptance signal. 2=BLOCKED/FAIL, 3=OFFLINE_ONLY_NOT_NATIVE.
    if args.mode == "audit":
        raise SystemExit(0 if result["all_match"] else 2)
    if args.mode == "historical":
        raise SystemExit(2)
    if result["classification"] == "BLOCKED":
        raise SystemExit(2)
    raise SystemExit(3)
