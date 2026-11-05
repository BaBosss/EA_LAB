#!/usr/bin/env python3
"""
Unit test suite for W5 Option B Scope B (Causal Trace Verifier) and Scope C (Stage Bundle Verifier):
Covers Q03 (Trust Anchor & Signatures), Q04 (Atomic Stage Commit), Q05 (106 Census), and Q07 (Multi-Input Causal DAG).
"""

import copy
import hashlib
import os
import sys
import unittest

TOOLS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "tools", "w5_engineering_observability"))
sys.path.insert(0, TOOLS_DIR)

from verifier_v3 import (
    CausalTraceVerifier,
    CausalGraphAuditor,
    ERR_CAUSAL_ORPHAN_DECISION,
    ERR_CAUSAL_VALUE_DIVERGENCE,
    ERR_CAUSAL_DANGLING_READ,
)
from stage_verifier_v3 import (
    StageBundleVerifier,
    SYNTHETIC_106_PATHS,
    CANONICAL_106_PATHS,
    HISTORICAL_3_DRIFT_PATHS,
    CENSUS_ASSURANCE_LEVEL,
    ERR_STAGE_CHAIN_ORDER,
    ERR_PATH_CENSUS_MISMATCH,
    ERR_UNVERIFIED_AUTHORITATIVE_CUSTODY_CLAIM,
    ERR_LEGACY_WAIVER_PROHIBITED,
    ERR_COMMISSION_ZERO_COERCION,
    ERR_RAW_BUNDLE_INCOMPLETE,
    ERR_INVALID_SIGNATURE,
    ERR_UNKNOWN_ISSUER,
    ERR_LEGACY_IDENTITY_MISMATCH,
)
from canonical_v3 import (
    compute_digest,
    EventChainValidator,
    ERR_UNPAIRED_READ_RETURN,
    ERR_EVENT_CHAIN_BROKEN,
)


def make_clean_causal_stream(schema_path: str) -> list:
    """Constructs a mathematically closed 5-event causal chain."""
    # 1. HANDLE_CREATE
    ev1 = {
        "schema_version": "W5_ENG_OBS_V3_0",
        "lineage_id": "ENGINEERING_ONLY_TRACK_E",
        "trust_domain": "SYNTHETIC_FIXTURE_TEST_ONLY",
        "event_id": "RUN01:STREAM_MAIN:0:HND_CREATE:1",
        "parent_event_id": None,
        "run_id": "RUN01",
        "stream_id": "STREAM_MAIN",
        "emitter_generation": 0,
        "event_type": "HANDLE_CREATE",
        "local_counter": 1,
        "recorded_utc": "2026-11-04T00:00:00.000000Z",
        "strategy_bar_time": "2026-11-04T02:00:00Z",
        "call_site": {"file": "Entry_Wave5.mqh", "function": "OnInit", "line": 1299},
        "sensor_payload": {
            "symbol": "XAUUSD", "timeframe": 16385, "indicator_kind": "ATR", "period": 14,
            "handle_id": "HND_001", "handle_generation": 1, "buffer_id": 0, "start_pos": 0,
            "requested_count": 1, "returned_count": 1, "raw_value": "0", "error_code": 0
        },
        "causality_link": {"consumed_in_decision": False, "decision_id": None, "edge_type": "OBSERVATION_ONLY"},
        "assurance_class": {"trace_internal_closed": True, "static_scope_instrumented": True, "actual_api_calls_witnessed": "UNKNOWN"},
        "prev_event_digest": "0" * 64
    }
    d1 = compute_digest(ev1)

    # 2. READ_REQUEST
    ev2 = copy.deepcopy(ev1)
    ev2["event_id"] = "RUN01:STREAM_MAIN:0:READ_REQ:2"
    ev2["event_type"] = "READ_REQUEST"
    ev2["local_counter"] = 2
    ev2["parent_event_id"] = ev1["event_id"]
    ev2["call_site"] = {"file": "Entry_Wave5.mqh", "function": "B17_ReadATR", "line": 1033}
    ev2["prev_event_digest"] = d1
    d2 = compute_digest(ev2)

    # 3. READ_RETURN
    ev3 = copy.deepcopy(ev2)
    ev3["event_id"] = "RUN01:STREAM_MAIN:0:READ_RET:3"
    ev3["event_type"] = "READ_RETURN"
    ev3["local_counter"] = 3
    ev3["parent_event_id"] = ev2["event_id"]
    ev3["sensor_payload"]["returned_count"] = 1
    ev3["sensor_payload"]["raw_value"] = "14.50000000"
    ev3["prev_event_digest"] = d2
    d3 = compute_digest(ev3)

    # 4. VALUE_USED
    ev4 = copy.deepcopy(ev3)
    ev4["event_id"] = "RUN01:STREAM_MAIN:0:VAL_USED:4"
    ev4["event_type"] = "VALUE_USED"
    ev4["local_counter"] = 4
    ev4["parent_event_id"] = ev3["event_id"]
    ev4["call_site"] = {"file": "Entry_Wave5.mqh", "function": "B17_ProcessLevel", "line": 1438}
    ev4["causality_link"] = {"consumed_in_decision": True, "decision_id": "DEC_001", "edge_type": "DECISION_DEPENDENCY"}
    ev4["prev_event_digest"] = d3
    d4 = compute_digest(ev4)

    # 5. DECISION
    ev5 = copy.deepcopy(ev4)
    ev5["event_id"] = "RUN01:STREAM_MAIN:0:DECISION:5"
    ev5["event_type"] = "DECISION"
    ev5["local_counter"] = 5
    ev5["parent_event_id"] = ev4["event_id"]
    ev5["call_site"] = {"file": "Entry_Wave5.mqh", "function": "B17_PlaceOrder", "line": 1500}
    ev5["causality_link"] = {"consumed_in_decision": True, "decision_id": "DEC_001", "edge_type": "DECISION_DEPENDENCY"}
    ev5["prev_event_digest"] = d4

    return [ev1, ev2, ev3, ev4, ev5]


class TestW5CausalAndStageVerifier(unittest.TestCase):

    def setUp(self):
        self.schema_path = os.path.join(TOOLS_DIR, "schema_v3.json")
        self.causal_verifier = CausalTraceVerifier(trust_domain="SYNTHETIC_FIXTURE_TEST_ONLY", schema_path=self.schema_path)
        self.stage_verifier = StageBundleVerifier(trust_domain="SYNTHETIC_FIXTURE_TEST_ONLY", expected_symbol="XAUUSD")

    # --- Scope B Tests (Q07 Multi-Input DAG) ---

    def test_scope_b_causal_chain_clean(self):
        """Scope B: Clean single-parent 5-event stream is verified clean."""
        stream = make_clean_causal_stream(self.schema_path)
        summary = self.causal_verifier.verify_stream(stream, allow_unconsumed_reads=False)
        self.assertEqual(summary.verdict, "VERIFIED_CLEAN")
        self.assertEqual(summary.total_events, 5)
        self.assertEqual(summary.decisions_verified, 1)
        self.assertEqual(summary.causal_chains_closed, 1)
        self.assertEqual(summary.dangling_reads, 0)
        self.assertEqual(len(summary.anomalies), 0)

    def test_scope_b_multi_input_dag(self):
        """Scope B (Q07): Multi-input DAG with 2 indicator reads feeding 1 decision."""
        # Event 1: HND_CREATE ATR
        ev1 = {
            "schema_version": "W5_ENG_OBS_V3_0", "lineage_id": "ENGINEERING_ONLY_TRACK_E",
            "trust_domain": "SYNTHETIC_FIXTURE_TEST_ONLY", "event_id": "RUN01:STREAM_MAIN:0:HND_CREATE:1",
            "parent_event_id": None, "run_id": "RUN01", "stream_id": "STREAM_MAIN", "emitter_generation": 0,
            "event_type": "HANDLE_CREATE", "local_counter": 1, "recorded_utc": "2026-11-04T00:00:00Z",
            "strategy_bar_time": "2026-11-04T02:00:00Z",
            "call_site": {"file": "Entry_Wave5.mqh", "function": "OnInit", "line": 1299},
            "sensor_payload": {
                "symbol": "XAUUSD", "timeframe": 16385, "indicator_kind": "ATR", "period": 14,
                "handle_id": "HND_001", "handle_generation": 1, "buffer_id": 0, "start_pos": 0,
                "requested_count": 1, "returned_count": 1, "raw_value": "0", "error_code": 0
            },
            "causality_link": {"consumed_in_decision": False, "decision_id": None, "edge_type": "OBSERVATION_ONLY"},
            "assurance_class": {"trace_internal_closed": True, "static_scope_instrumented": True, "actual_api_calls_witnessed": "UNKNOWN"},
            "prev_event_digest": "0" * 64
        }
        d1 = compute_digest(ev1)

        # Event 2: READ_REQ 1
        ev2 = copy.deepcopy(ev1)
        ev2["event_id"] = "RUN01:STREAM_MAIN:0:READ_REQ:2"
        ev2["event_type"] = "READ_REQUEST"
        ev2["local_counter"] = 2
        ev2["parent_event_id"] = ev1["event_id"]
        ev2["prev_event_digest"] = d1
        d2 = compute_digest(ev2)

        # Event 3: READ_RET 1 (ATR = 15.0)
        ev3 = copy.deepcopy(ev2)
        ev3["event_id"] = "RUN01:STREAM_MAIN:0:READ_RET:3"
        ev3["event_type"] = "READ_RETURN"
        ev3["local_counter"] = 3
        ev3["parent_event_id"] = ev2["event_id"]
        ev3["sensor_payload"]["raw_value"] = "15.00000000"
        ev3["prev_event_digest"] = d2
        d3 = compute_digest(ev3)

        # Event 4: READ_REQ 2
        ev4 = copy.deepcopy(ev3)
        ev4["event_id"] = "RUN01:STREAM_MAIN:0:READ_REQ:4"
        ev4["event_type"] = "READ_REQUEST"
        ev4["local_counter"] = 4
        ev4["parent_event_id"] = ev1["event_id"]
        ev4["prev_event_digest"] = d3
        d4 = compute_digest(ev4)

        # Event 5: READ_RET 2 (ATR = 16.0)
        ev5 = copy.deepcopy(ev4)
        ev5["event_id"] = "RUN01:STREAM_MAIN:0:READ_RET:5"
        ev5["event_type"] = "READ_RETURN"
        ev5["local_counter"] = 5
        ev5["parent_event_id"] = ev4["event_id"]
        ev5["sensor_payload"]["raw_value"] = "16.00000000"
        ev5["prev_event_digest"] = d4
        d5 = compute_digest(ev5)

        # Event 6: VAL_USED 1
        ev6 = copy.deepcopy(ev5)
        ev6["event_id"] = "RUN01:STREAM_MAIN:0:VAL_USED:6"
        ev6["event_type"] = "VALUE_USED"
        ev6["local_counter"] = 6
        ev6["parent_event_id"] = ev3["event_id"]
        ev6["sensor_payload"]["raw_value"] = "15.00000000"
        ev6["prev_event_digest"] = d5
        d6 = compute_digest(ev6)

        # Event 7: VAL_USED 2
        ev7 = copy.deepcopy(ev6)
        ev7["event_id"] = "RUN01:STREAM_MAIN:0:VAL_USED:7"
        ev7["event_type"] = "VALUE_USED"
        ev7["local_counter"] = 7
        ev7["parent_event_id"] = ev5["event_id"]
        ev7["sensor_payload"]["raw_value"] = "16.00000000"
        ev7["prev_event_digest"] = d6
        d7 = compute_digest(ev7)

        # Event 8: Multi-Parent DECISION (Q07)
        ev8 = copy.deepcopy(ev7)
        ev8["event_id"] = "RUN01:STREAM_MAIN:0:DECISION:8"
        ev8["event_type"] = "DECISION"
        ev8["local_counter"] = 8
        ev8["parent_event_id"] = ev6["event_id"]
        ev8["parent_event_ids"] = [ev6["event_id"], ev7["event_id"]]  # Multi-parent!
        ev8["causality_link"] = {"consumed_in_decision": True, "decision_id": "MULTI_DEC_01", "edge_type": "DECISION_DEPENDENCY"}
        ev8["prev_event_digest"] = d7

        stream = [ev1, ev2, ev3, ev4, ev5, ev6, ev7, ev8]
        summary = self.causal_verifier.verify_stream(stream, allow_unconsumed_reads=False)
        self.assertEqual(summary.verdict, "VERIFIED_CLEAN")
        self.assertEqual(summary.decisions_verified, 1)
        self.assertEqual(summary.causal_chains_closed, 2)

    def test_scope_b_orphan_decision_fails(self):
        stream = make_clean_causal_stream(self.schema_path)
        stream[4]["parent_event_id"] = "RUN01:STREAM_MAIN:0:VAL_USED:999"
        stream[4]["prev_event_digest"] = compute_digest(stream[3])
        summary = self.causal_verifier.verify_stream(stream)
        self.assertEqual(summary.verdict, "FAILED")
        self.assertTrue(any(ERR_CAUSAL_ORPHAN_DECISION in a for a in summary.anomalies))

    def test_scope_b_value_divergence_fails(self):
        stream = make_clean_causal_stream(self.schema_path)
        stream[3]["sensor_payload"]["raw_value"] = "99.99999999"
        stream[3]["prev_event_digest"] = compute_digest(stream[2])
        stream[4]["prev_event_digest"] = compute_digest(stream[3])
        summary = self.causal_verifier.verify_stream(stream)
        self.assertEqual(summary.verdict, "FAILED")
        self.assertTrue(any(ERR_CAUSAL_VALUE_DIVERGENCE in a for a in summary.anomalies))

    def test_scope_b_dangling_read_fails(self):
        stream = make_clean_causal_stream(self.schema_path)
        truncated_stream = stream[:3]
        summary = self.causal_verifier.verify_stream(truncated_stream, allow_unconsumed_reads=False)
        self.assertEqual(summary.verdict, "FAILED")
        self.assertTrue(any(ERR_CAUSAL_DANGLING_READ in a for a in summary.anomalies))

    # --- Scope C Tests ---

    def test_scope_c_stage_sequence_clean(self):
        stages = ["S0", "PREPROBE", "S1", "EXECUTION", "S2", "POSTPROBE", "S3"]
        last_d = "0" * 64
        for idx, sname in enumerate(stages):
            sdata = {
                "stage_name": sname,
                "nonce": f"NONCE_{sname}_{idx}",
                "issuer_id": "ISSUER_DEV",
                "key_fingerprint": "KEY_DEV",
                "process_identity": {"pid": 1234, "birth_timestamp": "2026-11-04T00:00:00Z"},
                "prev_stage_digest": last_d
            }
            last_d = self.stage_verifier.verify_stage_envelope(sdata)
            self.assertEqual(len(last_d), 64)

    def test_scope_c_stage_out_of_order_fails(self):
        sdata = {
            "stage_name": "S1", "nonce": "NONCE_S1_0", "issuer_id": "ISSUER_DEV",
            "key_fingerprint": "KEY_DEV", "process_identity": {"pid": 1234, "birth_timestamp": "2026-11-04T00:00:00Z"},
            "prev_stage_digest": "0" * 64
        }
        with self.assertRaises(ValueError) as ctx:
            self.stage_verifier.verify_stage_envelope(sdata)
        self.assertIn(ERR_STAGE_CHAIN_ORDER, str(ctx.exception))

    def test_scope_c_106_census_clean(self):
        manifest = {p: "hash" for p in CANONICAL_106_PATHS}
        ok, anomalies = self.stage_verifier.verify_106_path_census(manifest, claim_clean_all=False)
        self.assertTrue(ok)
        self.assertEqual(len(anomalies), 0)

    def test_scope_c_106_census_mismatch_fails(self):
        manifest = {p: "hash" for p in list(CANONICAL_106_PATHS)[:100]}
        ok, anomalies = self.stage_verifier.verify_106_path_census(manifest, claim_clean_all=False)
        self.assertFalse(ok)
        self.assertTrue(any(ERR_PATH_CENSUS_MISMATCH in a for a in anomalies))

    def test_scope_c_prohibited_waiver_fails(self):
        manifest = {p: "hash" for p in CANONICAL_106_PATHS}
        ok, anomalies = self.stage_verifier.verify_106_path_census(manifest, claim_clean_all=True)
        self.assertFalse(ok)
        self.assertTrue(any(ERR_LEGACY_WAIVER_PROHIBITED in a for a in anomalies))

    def test_scope_c_commission_zero_coercion_fails(self):
        deal = {"symbol": "XAUUSD", "commission": 0.0, "s2_broker_authenticated": False}
        with self.assertRaises(ValueError) as ctx:
            self.stage_verifier.verify_broker_economics(deal)
        self.assertIn(ERR_COMMISSION_ZERO_COERCION, str(ctx.exception))

    def test_scope_c_incomplete_bundle_fails(self):
        bundle = {"deal_journal": "journal.log", "report_html": "report.html"}
        with self.assertRaises(ValueError) as ctx:
            self.stage_verifier.verify_bundle_completeness(bundle)
        self.assertIn(ERR_RAW_BUNDLE_INCOMPLETE, str(ctx.exception))

    def test_scope_c_rqa_02_synthetic_census_only_rejects_authoritative_claim(self):
        """RQA-02: Manifest is SYNTHETIC_106_CENSUS_ONLY. Authoritative claims must be rejected."""
        self.assertEqual(CENSUS_ASSURANCE_LEVEL, "SYNTHETIC_106_CENSUS_ONLY")
        manifest = {p: "hash" for p in SYNTHETIC_106_PATHS}

        # Calling with claim_authoritative=True must fail
        ok, anomalies = self.stage_verifier.verify_106_path_census(manifest, claim_authoritative=True)
        self.assertFalse(ok)
        self.assertTrue(any(ERR_UNVERIFIED_AUTHORITATIVE_CUSTODY_CLAIM in a for a in anomalies))

        # Standard synthetic census succeeds
        ok_syn, anomalies_syn = self.stage_verifier.verify_106_path_census(manifest, claim_authoritative=False)
        self.assertTrue(ok_syn)
        self.assertEqual(len(anomalies_syn), 0)

    def test_scope_c_rqa_03_signed_mode_enforcement(self):
        """RQA-03: Strict signed-stage mode requires valid signatures and registered trust anchors."""
        signed_verifier = StageBundleVerifier(trust_domain="SYNTHETIC_FIXTURE_TEST_ONLY", require_signatures=True)
        secret = b"STRICT_SIGNED_TEST_KEY_SECRET_32B"
        key_fp = "KEY_PROD_STRICT_01"
        signed_verifier.register_trusted_key("ISSUER_PROD", key_fp, secret)

        stage_s0 = {
            "stage_name": "S0",
            "nonce": "NONCE_STRICT_01",
            "issuer_id": "ISSUER_PROD",
            "key_fingerprint": key_fp,
            "prev_stage_digest": "0" * 64
        }

        # 1. Reject missing signature in signed-stage mode
        envelope_no_sig = dict(stage_s0)
        with self.assertRaises(ValueError) as ctx:
            signed_verifier.verify_stage_envelope(envelope_no_sig)
        self.assertIn(ERR_INVALID_SIGNATURE, str(ctx.exception))

        # 2. Reject empty signature in signed-stage mode
        envelope_empty_sig = {"stage_data": stage_s0, "signature_hex": "   "}
        with self.assertRaises(ValueError) as ctx:
            signed_verifier.verify_stage_envelope(envelope_empty_sig)
        self.assertIn(ERR_INVALID_SIGNATURE, str(ctx.exception))

        # 3. Reject unknown / unregistered key_fingerprint
        stage_bad_issuer = dict(stage_s0)
        stage_bad_issuer["key_fingerprint"] = "UNKNOWN_KEY_FP"
        envelope_unknown = {"stage_data": stage_bad_issuer, "signature_hex": "deadbeef" * 8}
        with self.assertRaises(ValueError) as ctx:
            signed_verifier.verify_stage_envelope(envelope_unknown)
        self.assertIn(ERR_UNKNOWN_ISSUER, str(ctx.exception))

        # 4. Valid signature accepted in signed-stage mode
        valid_sig = signed_verifier.trust_registry.sign_stage(key_fp, stage_s0)
        envelope_valid = {"stage_data": stage_s0, "signature_hex": valid_sig}
        digest = signed_verifier.verify_stage_envelope(envelope_valid)
        self.assertEqual(len(digest), 64)

    def test_scope_c_rqa_03_native_unsigned_rejected(self):
        """RQA-03 / H1: NATIVE_AUTHENTIC_PROD_ONLY must require signatures by default and reject unsigned envelopes."""
        native_verifier = StageBundleVerifier(trust_domain="NATIVE_AUTHENTIC_PROD_ONLY")
        env = {"stage_data": {"stage_name": "S0", "nonce": "n1", "prev_stage_digest": "0" * 64}}
        with self.assertRaises(ValueError) as ctx:
            native_verifier.verify_stage_envelope(env)
        self.assertTrue(ERR_INVALID_SIGNATURE in str(ctx.exception) or ERR_UNKNOWN_ISSUER in str(ctx.exception))

    def test_scope_c_commission_missing_or_non_numeric_rejected(self):
        """H2: Commission missing, None, or string '0' must be rejected."""
        verifier = StageBundleVerifier()
        for rec in ({"symbol": "XAUUSD"}, {"symbol": "XAUUSD", "commission": None}, {"symbol": "XAUUSD", "commission": "0"}):
            with self.assertRaises(ValueError) as ctx:
                verifier.verify_broker_economics(rec)
            self.assertIn(ERR_COMMISSION_ZERO_COERCION, str(ctx.exception))

    def test_scope_c_legacy_ex5_empty_sha_rejected(self):
        """H3: Empty file SHA-256 must be rejected as original legacy EX5 identity."""
        verifier = StageBundleVerifier()
        empty_sha = hashlib.sha256(b"").hexdigest()
        with self.assertRaises(ValueError) as ctx:
            verifier.verify_legacy_ex5_identity(empty_sha)
        self.assertIn(ERR_LEGACY_IDENTITY_MISMATCH, str(ctx.exception))

    def test_scope_b_open_read_request_flagged(self):
        """H4: Open READ_REQUEST never closed by return or failure must be flagged."""
        auditor = CausalGraphAuditor()
        auditor.ingest_event({"event_id": "REQ_01", "event_type": "READ_REQUEST", "sensor_payload": {}})
        ok, anomalies = auditor.audit_causality(allow_unconsumed_reads=True)
        self.assertFalse(ok)
        self.assertTrue(any(ERR_UNPAIRED_READ_RETURN in a for a in anomalies))

    def test_scope_b_orphan_decision_consumed_false_flagged(self):
        """H4: DECISION with consumed_in_decision=False and no parents must be flagged."""
        auditor = CausalGraphAuditor()
        auditor.ingest_event({
            "event_id": "DEC_01",
            "event_type": "DECISION",
            "causality_link": {"consumed_in_decision": False, "edge_type": "DECISION_DEPENDENCY"},
            "sensor_payload": {}
        })
        ok, anomalies = auditor.audit_causality()
        self.assertFalse(ok)
        self.assertTrue(any(ERR_CAUSAL_ORPHAN_DECISION in a for a in anomalies))

    def test_event_chain_atomic_validation_unpoisoned(self):
        """M1: A rejected forged event must not poison validator state or block genuine event."""
        chain_v = EventChainValidator()
        stream = make_clean_causal_stream("atomic_test")
        chain_v.validate_event(stream[0])

        bad = copy.deepcopy(stream[1])
        bad["prev_event_digest"] = "f" * 64
        with self.assertRaises(ValueError):
            chain_v.validate_event(bad)

        # Genuine event with same id and counter must succeed
        digest = chain_v.validate_event(stream[1])
        self.assertEqual(len(digest), 64)


class TestIndependentD4NegativeRegressions(unittest.TestCase):
    """Negative cases derived from exact-HEAD independent FAIL on 0a782d48."""

    def test_wrong_issuer_rejected_even_with_valid_hmac(self):
        from canonical_v3 import ERR_UNKNOWN_ISSUER
        verifier = StageBundleVerifier(trust_domain="NATIVE_AUTHENTIC_PROD_ONLY")
        verifier.register_trusted_key("ISSUER_A", "KEY_A", b"test-secret-not-a-real-issuer")
        stage = {"stage_name": "S0", "nonce": "NONCE_A",
                 "issuer_id": "ISSUER_B", "key_fingerprint": "KEY_A",
                 "prev_stage_digest": "0" * 64}
        forged_claim_sig = verifier.trust_registry.sign_stage("KEY_A", stage)
        with self.assertRaises(ValueError) as caught:
            verifier.verify_stage_envelope({"stage_data": stage, "signature_hex": forged_claim_sig})
        self.assertIn(ERR_UNKNOWN_ISSUER, str(caught.exception))
        self.assertEqual(verifier.current_stage_idx, -1)

    def test_stage_persistence_failure_does_not_advance_state(self):
        import tempfile
        from canonical_v3 import ERR_REPLAY_NONCE_COLLISION
        with tempfile.TemporaryDirectory() as d:
            ledger_path = os.path.join(d, "ledger.json")
            verifier = StageBundleVerifier(replay_ledger_file=ledger_path)
            s0 = {"stage_name": "S0", "nonce": "NONCE_S0",
                  "issuer_id": "ISSUER_A", "key_fingerprint": "KEY_A",
                  "process_identity": {"pid": 77, "birth_timestamp": "T1"},
                  "prev_stage_digest": "0" * 64}
            original = verifier.replay_ledger._persist
            def fail_persist():
                raise OSError("synthetic disk failure")
            verifier.replay_ledger._persist = fail_persist
            with self.assertRaises(OSError):
                verifier.verify_stage_envelope(s0)
            self.assertEqual(verifier.current_stage_idx, -1)
            self.assertEqual(verifier.last_stage_digest, "0" * 64)
            self.assertEqual(verifier.known_pids, {})
            verifier.replay_ledger._persist = original
            digest = verifier.verify_stage_envelope(s0)
            self.assertEqual(len(digest), 64)
            self.assertEqual(verifier.current_stage_idx, 0)

    def test_multi_instance_nonce_race_rejected_and_first_retained(self):
        import tempfile
        from canonical_v3 import ReplayLedger, ERR_REPLAY_NONCE_COLLISION
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "ledger.json")
            a, b = ReplayLedger(path), ReplayLedger(path)
            a.record_and_verify("V3", "SYN", "ISS_A", "FP_A", "NONCE_X")
            with self.assertRaises(ValueError) as caught:
                b.record_and_verify("V3", "SYN", "ISS_A", "FP_A", "NONCE_X")
            self.assertIn(ERR_REPLAY_NONCE_COLLISION, str(caught.exception))
            b.record_and_verify("V3", "SYN", "ISS_A", "FP_A", "NONCE_Y")
            c = ReplayLedger(path)
            for n in ("NONCE_X", "NONCE_Y"):
                with self.assertRaises(ValueError):
                    c.record_and_verify("V3", "SYN", "ISS_A", "FP_A", n)

    def test_bad_broker_fee_flags_nonfinite_swap_and_unauthenticated_zero(self):
        verifier = StageBundleVerifier()
        cases = [
            {"symbol": "XAUUSD", "commission": 0, "swap": 1, "s2_broker_authenticated": "false"},
            {"symbol": "XAUUSD", "commission": float("nan"), "swap": 1, "s2_broker_authenticated": False},
            {"symbol": "XAUUSD", "commission": float("inf"), "swap": 1, "s2_broker_authenticated": False},
            {"symbol": "XAUUSD", "commission": 1, "swap": 0, "s2_broker_authenticated": False},
            {"symbol": "XAUUSD", "commission": 1, "s2_broker_authenticated": False},
        ]
        for case in cases:
            with self.subTest(case=str(case)):
                with self.assertRaises(ValueError):
                    verifier.verify_broker_economics(case)
        verifier.verify_broker_economics({"symbol": "XAUUSD", "commission": -1.5,
                                          "swap": 0.0, "s2_broker_authenticated": True})

    def test_request_return_mismatched_symbol_or_context_rejected(self):
        stream = make_clean_causal_stream("")
        stream[2]["sensor_payload"]["symbol"] = "EURUSD"
        from canonical_v3 import compute_digest
        for i in range(3, len(stream)):
            stream[i]["prev_event_digest"] = compute_digest(stream[i-1])
        verifier = CausalTraceVerifier()
        result = verifier.verify_stream(stream)
        self.assertEqual(result.verdict, "FAILED")
        self.assertTrue(any("ERR_UNPAIRED_READ_RETURN" in err for err in result.anomalies))

    def test_future_read_cannot_justify_earlier_value_used(self):
        stream = make_clean_causal_stream("")
        used = copy.deepcopy(stream[3])
        returned = copy.deepcopy(stream[2])
        used["event_id"] = "RUN01:STREAM_MAIN:0:VAL_USED:3"
        used["local_counter"] = 3
        used["parent_event_id"] = "RUN01:STREAM_MAIN:0:READ_RET:4"
        returned["event_id"] = "RUN01:STREAM_MAIN:0:READ_RET:4"
        returned["local_counter"] = 4
        stream = [stream[0], stream[1], used, returned, stream[4]]
        stream[-1]["parent_event_id"] = used["event_id"]
        from canonical_v3 import compute_digest
        for i in range(2, len(stream)):
            stream[i]["prev_event_digest"] = compute_digest(stream[i-1])
        result = CausalTraceVerifier().verify_stream(stream)
        self.assertEqual(result.verdict, "FAILED")
        self.assertTrue(any("prior" in err or "precede" in err for err in result.anomalies))

    def test_metadata_value_use_cannot_drive_decision(self):
        stream = make_clean_causal_stream("")
        stream[3]["causality_link"]["edge_type"] = "BAR_ASSOCIATION"
        from canonical_v3 import compute_digest
        stream[4]["prev_event_digest"] = compute_digest(stream[3])
        result = CausalTraceVerifier().verify_stream(stream)
        self.assertEqual(result.verdict, "FAILED")
        self.assertTrue(any("ERR_METADATA_TIME_NOT_DECISION" in err for err in result.anomalies))

    def test_read_failure_with_silenced_last_error_rejected(self):
        stream = make_clean_causal_stream("")[:3]
        stream[2]["event_id"] = "RUN01:STREAM_MAIN:0:READ_FAIL:3"
        stream[2]["event_type"] = "READ_FAILURE"
        stream[2]["sensor_payload"]["returned_count"] = 0
        stream[2]["sensor_payload"]["error_code"] = 0
        result = CausalTraceVerifier().verify_stream(stream)
        self.assertEqual(result.verdict, "FAILED")
        self.assertTrue(any("ERR_UNPRESERVED_LAST_ERROR" in err for err in result.anomalies))

    def test_mql5_source_probe_does_not_claim_unverified_digest_or_compile(self):
        from pathlib import Path
        root = Path(__file__).resolve().parents[1]
        header = (root / "tools/w5_engineering_observability/W5_TelemetrySensor.mqh").read_text(encoding="utf-8")
        probe = (root / "ea_template/tests/W5_ObservabilitySensor_Test.mq5").read_text(encoding="utf-8")
        self.assertIn("W5_ParentIDsToJSON", header)
        self.assertIn("parent_event_ids_pipe", header)
        self.assertIn("W5_FormatRawValueJSON", header)
        self.assertIn('StringFormat("%.17g", value)', header)
        self.assertIn('StringFormat("\\\\u%04X"', header)
        self.assertNotIn('raw_value\\":%.8f', header)
        self.assertIn("TimeGMT()", probe)
        self.assertIn("chain NOT_VERIFIED", probe)
        self.assertIn("trace_internal_closed       = false", probe)
        self.assertIn("static_scope_instrumented   = false", probe)
        self.assertNotIn("36b72f574b6f96e3805d775469f29f7db952194bb5f973549d5157d3459b6264", probe)

    def test_schema_strict_types_and_event_id_binding(self):
        from canonical_v3 import EventChainValidator, validate_draft07_invariants
        import importlib.util
        suite_path = os.path.join(os.path.dirname(__file__), "test_w5_obs_schema_canonical_v3.py")
        spec = importlib.util.spec_from_file_location("w5_schema_fixture", suite_path)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        for key, value in (
            ("parent_event_ids", None),
            ("sensor_payload", {"raw_value": {"bad": 1}}),
            ("causality_link", {"decision_id": {"bad": 1}}),
        ):
            ev = mod.get_base_event()
            if key == "parent_event_ids":
                ev[key] = value
            else:
                ev[key].update(value)
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate_draft07_invariants(ev)
        ev = mod.get_base_event()
        ev["run_id"] = "RUN_DIFFERENT"
        with self.assertRaises(ValueError) as caught:
            EventChainValidator().validate_event(ev)
        self.assertIn("ERR_EVENT_ID_COLLISION", str(caught.exception))
        ev = mod.get_base_event()
        ev["event_id"] = "RUN01:STREAM_MAIN:0:HND_CREATE:\u0661"
        with self.assertRaises(ValueError):
            EventChainValidator().validate_event(ev)


if __name__ == "__main__":
    unittest.main()
