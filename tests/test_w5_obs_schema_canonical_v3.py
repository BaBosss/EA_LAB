#!/usr/bin/env python3
"""
Exhaustive Unit Test Suite for W5 Option B Scope A Offline Tooling:
Covers Q01 (RFC 8785 JCS Conformance), Q02 (Draft-07 Invariants), Q03 (Trust Anchor & Signatures),
Q04 (Atomic Stage Commit & Persistent Replay), Q05 (Exact 106 Census), and Q08 (F01–F69 Matrix).
"""

import copy
import json
import math
import os
import shutil
import sys
import tempfile
import unittest

TOOLS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "tools", "w5_engineering_observability"))
sys.path.insert(0, TOOLS_DIR)

from canonical_v3 import (
    EventChainValidator,
    HandleLifecycleTracker,
    ReplayLedger,
    canonicalize_jcs,
    compute_digest,
    compute_domain_digest,
    serialize_ecmascript_number,
    utf16_sort_key,
    verify_jcs_key_sort,
    validate_draft07_invariants,
    STAGE_DOMAIN,
    ACTION_DOMAIN,
    ERR_EVENT_ID_COLLISION,
    ERR_EVENT_CHAIN_BROKEN,
    ERR_UNPAIRED_READ_RETURN,
    ERR_REPLAY_NONCE_COLLISION,
    ERR_REPLAY_LEDGER_CORRUPTED,
    ERR_RECYCLED_HANDLE_COLLISION,
    ERR_METADATA_TIME_NOT_DECISION,
    ERR_MISSING_TIME_DECISION_EDGE,
    ERR_UNVERIFIED_COVERAGE_CLAIM,
    ERR_UNPRESERVED_LAST_ERROR,
    ERR_NATIVE_IDENTITY_SPOOF,
    ERR_INVALID_SIGNATURE,
    ERR_KEY_REVOKED,
    ERR_KEY_EXPIRED,
    ERR_UNKNOWN_ISSUER,
    ERR_STAGE_CHAIN_ORDER,
    ERR_PATH_CENSUS_MISMATCH,
    ERR_UNVERIFIED_AUTHORITATIVE_CUSTODY_CLAIM,
    ERR_COVERAGE_GAP_DETECTED,
    ERR_LEGACY_IDENTITY_MISMATCH,
    ERR_STATIC_CALLSITE_OMITTED,
    ERR_JCS_KEY_SORT_ORDER,
    ERR_LEGACY_WAIVER_PROHIBITED,
    ERR_COMMISSION_ZERO_COERCION,
    ERR_RAW_BUNDLE_INCOMPLETE,
    ERR_SCHEMA_MISSING_REQUIRED_KEY,
    ERR_SCHEMA_ADDITIONAL_PROPERTY,
    ERR_SCHEMA_TYPE_MISMATCH,
    ERR_SCHEMA_INVALID_PATTERN,
    ERR_SCHEMA_VALUE_OUT_OF_RANGE,
    ERR_SCHEMA_MISSING_NESTED_KEY,
    ERR_INVALID_SCHEMA_VERSION,
    ERR_INVALID_LINEAGE_ID,
    ERR_INVALID_TRUST_DOMAIN,
    ERR_INVALID_EVENT_TYPE,
    ERR_INVALID_INDICATOR_KIND,
    ERR_INVALID_EDGE_TYPE,
    ERR_INVALID_WITNESS_ENUM,
)
from stage_verifier_v3 import (
    StageBundleVerifier,
    TrustAnchorRegistry,
    SYNTHETIC_106_PATHS,
    CANONICAL_106_PATHS,
    HISTORICAL_3_DRIFT_PATHS,
    CENSUS_ASSURANCE_LEVEL,
)


def get_base_event() -> dict:
    return {
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
        "call_site": {
            "file": "Entry_Wave5.mqh",
            "function": "OnInit",
            "line": 1299
        },
        "sensor_payload": {
            "symbol": "XAUUSD",
            "timeframe": 16385,
            "indicator_kind": "ATR",
            "period": 14,
            "handle_id": "HND_001",
            "handle_generation": 1,
            "buffer_id": 0,
            "start_pos": 0,
            "requested_count": 1,
            "returned_count": 1,
            "raw_value": "0",
            "error_code": 0
        },
        "causality_link": {
            "consumed_in_decision": False,
            "decision_id": None,
            "edge_type": "OBSERVATION_ONLY"
        },
        "assurance_class": {
            "trace_internal_closed": True,
            "static_scope_instrumented": True,
            "actual_api_calls_witnessed": "UNKNOWN"
        },
        "prev_event_digest": "0" * 64
    }


class TestRFC8785JCSConformance(unittest.TestCase):
    """Q01: RFC 8785 JCS Conformance Vectors."""

    def test_unicode_strings_unmodified(self):
        # RFC 8785 Section 3.2.2.2: Strings are serialized as given WITHOUT NFC/NFD normalization!
        decomposed = "e\u0301"  # 'e' + combining acute accent (NFD)
        precomposed = "\u00e9"  # single code point (NFC)
        # In JCS, these must remain distinct and preserve exact byte representation!
        s_dec = canonicalize_jcs(decomposed)
        s_pre = canonicalize_jcs(precomposed)
        self.assertNotEqual(s_dec, s_pre)
        self.assertIn("\u0301", s_dec)
        self.assertIn("\u00e9", s_pre)

    def test_ecmascript_number_serialization(self):
        # Integers
        self.assertEqual(serialize_ecmascript_number(123), "123")
        self.assertEqual(serialize_ecmascript_number(123.0), "123")
        # Negative zero must serialize as '0'
        self.assertEqual(serialize_ecmascript_number(-0.0), "0")
        # Floats
        self.assertEqual(serialize_ecmascript_number(12.345), "12.345")
        # Non-finites forbidden
        with self.assertRaises(ValueError):
            serialize_ecmascript_number(float("nan"))
        with self.assertRaises(ValueError):
            serialize_ecmascript_number(float("inf"))

    def test_ecmascript_float_serialization_binary64(self):
        """RQA-04: ECMA-262 7.1.12.1 ToString conformance and exact binary64 shortest round-trip."""
        cases = [
            (0.0, "0"),
            (-0.0, "0"),
            (1.0, "1"),
            (-1.0, "-1"),
            (1.2345678901234567, "1.2345678901234567"),
            (0.0001, "0.0001"),
            (1e-5, "0.00001"),
            (1e-6, "0.000001"),
            (1e-7, "1e-7"),
            (1e20, "100000000000000000000"),
            (1e21, "1e+21"),
            (1e22, "1e+22"),
            (1.23e-10, "1.23e-10"),
            (5e-324, "5e-324"),
            (1.7976931348623157e308, "1.7976931348623157e+308"),
        ]
        for val, expected_str in cases:
            s = serialize_ecmascript_number(val)
            self.assertEqual(s, expected_str, f"Mismatch for float {val!r}")
            # Binary64 round-trip verification
            if val != 0.0 and val != -0.0:
                self.assertEqual(float(s), val, f"Round-trip failed for {val!r} -> {s}")
            else:
                self.assertEqual(float(s), 0.0)

    def test_utf16_surrogate_key_ordering(self):
        # Non-BMP U+1D11E (surrogates D834 DD1E) must sort before BMP U+FFFE (FFFE)
        obj = {"\uFFFE": 1, "\U0001D11E": 2}
        jcs = canonicalize_jcs(obj)
        keys = list(json.loads(jcs).keys())
        self.assertEqual(keys[0], "\U0001D11E")
        self.assertEqual(keys[1], "\uFFFE")

    def test_schema_pattern_rejects_trailing_newline(self):
        """L1: Verify regexes reject strings with trailing newlines."""
        ev = get_base_event()
        ev["run_id"] = "RUN01\n"
        with self.assertRaises(ValueError) as ctx:
            validate_draft07_invariants(ev)
        self.assertIn(ERR_SCHEMA_INVALID_PATTERN, str(ctx.exception))


class TestFileBackedDraft07Contract(unittest.TestCase):
    """The published schema JSON must actually govern runtime admission."""

    def test_runtime_schema_change_is_enforced_fail_closed(self):
        ev = get_base_event()
        validator = EventChainValidator()
        self.assertEqual(len(validator.validate_event(copy.deepcopy(ev))), 64)
        path = os.path.join(TOOLS_DIR, "schema_v3.json")
        with open(path, "r", encoding="utf-8") as handle:
            doc = json.load(handle)
        with tempfile.TemporaryDirectory() as d:
            filename = os.path.join(d, "test_schema.json")
            doc["properties"]["event_type"]["enum"] = ["RUN_CLOSE"]
            with open(filename, "w", encoding="utf-8") as handle:
                json.dump(doc, handle)
            with self.assertRaisesRegex(ValueError, "ERR_SCHEMA_VALUE_OUT_OF_RANGE"):
                EventChainValidator(schema_path=filename).validate_event(copy.deepcopy(ev))
            doc["properties"]["event_type"]["enum"].append("HANDLE_CREATE")
            doc["properties"]["event_type"]["const"] = "DISALLOWED_UNSUPPORTED_KEYWORD"
            with open(filename, "w", encoding="utf-8") as handle:
                json.dump(doc, handle)
            with self.assertRaisesRegex(ValueError, "unsupported_schema_keywords"):
                EventChainValidator(schema_path=filename).validate_event(copy.deepcopy(ev))
            os.remove(filename)
            with self.assertRaisesRegex(ValueError, "schema_v3_unavailable_or_invalid"):
                EventChainValidator(schema_path=filename).validate_event(copy.deepcopy(ev))

class TestTrustedVerifierTime(unittest.TestCase):
    """R12: neither signed metadata nor public time overrides renew expired keys."""

    def test_expired_action_and_stage_reject_backdated_payload_and_override(self):
        from datetime import datetime, timedelta, timezone
        import hmac
        import hashlib
        now = datetime.now(timezone.utc)
        iso = lambda dt: dt.strftime("%Y-%m-%dT%H:%M:%SZ")
        start = iso(now - timedelta(days=400))
        expired = iso(now - timedelta(days=30))
        fake_past = iso(now - timedelta(days=120))
        reg = TrustAnchorRegistry()
        key = b"synthetic-only-expired-key"
        reg.register_key("ISS_1", "FP_1", key, valid_from=start, valid_to=expired)
        for domain, label in ((ACTION_DOMAIN, "ACTION"), (STAGE_DOMAIN, "STAGE")):
            payload = {
                "issuer_id": "ISS_1", "key_fingerprint": "FP_1",
                "recorded_utc": fake_past, "strategy_bar_time": fake_past,
                "nonce": label + "_NONCE",
            }
            import json
            signed = hmac.new(
                key,
                domain.encode("utf-8") + canonicalize_jcs(payload).encode("utf-8"),
                hashlib.sha256,
            ).hexdigest()
            signer = reg.sign_action if label == "ACTION" else reg.sign_stage
            verifier = reg.verify_action_signature if label == "ACTION" else reg.verify_stage_signature
            with self.subTest(domain=label):
                with self.assertRaisesRegex(ValueError, ERR_KEY_EXPIRED):
                    signer("FP_1", payload)
                with self.assertRaisesRegex(ValueError, ERR_KEY_EXPIRED):
                    verifier("FP_1", payload, signed)
                # The public time override is NOT an authenticated archival witness.
                with self.assertRaisesRegex(ValueError, ERR_KEY_EXPIRED):
                    verifier("FP_1", payload, signed, current_time_iso=fake_past)

    def test_active_keys_verify_from_runtime_utc_not_untrusted_metadata(self):
        from datetime import datetime, timedelta, timezone
        now = datetime.now(timezone.utc)
        iso = lambda dt: dt.strftime("%Y-%m-%dT%H:%M:%SZ")
        reg = TrustAnchorRegistry()
        reg.register_key(
            "ISS_2", "FP_2", b"synthetic-only-current-key",
            valid_from=iso(now - timedelta(days=30)),
            valid_to=iso(now + timedelta(days=365)),
        )
        payload = {
            "issuer_id": "ISS_2", "key_fingerprint": "FP_2",
            "recorded_utc": iso(now - timedelta(days=3000)),
            "strategy_bar_time": iso(now - timedelta(days=3000)),
            "nonce": "CURRENT_NONCE",
        }
        reg.verify_action_signature("FP_2", payload, reg.sign_action("FP_2", payload))
        reg.verify_stage_signature("FP_2", payload, reg.sign_stage("FP_2", payload))
        for verifier, signature in (
            (reg.verify_action_signature, reg.sign_action("FP_2", payload)),
            (reg.verify_stage_signature, reg.sign_stage("FP_2", payload)),
        ):
            with self.assertRaisesRegex(ValueError, ERR_KEY_EXPIRED):
                verifier("FP_2", payload, signature, current_time_iso=iso(now))
        # Broken trust anchor timestamps must also fail closed.
        reg.register_key("ISS_3", "FP_3", b"synthetic-only-invalid-dates",
                         valid_from="NOT_A_TIME", valid_to="9999-01-01T00:00:00Z")
        with self.assertRaisesRegex(ValueError, ERR_KEY_EXPIRED):
            reg.sign_stage("FP_3", {"issuer_id": "ISS_3", "key_fingerprint": "FP_3"})


class TestPersistentReplayLedger(unittest.TestCase):
    """Q04: Persistent Replay Ledger tests."""

    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.ledger_file = os.path.join(self.temp_dir, "replay.json")

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_persistence_and_reload(self):
        ledger1 = ReplayLedger(self.ledger_file)
        ledger1.record_and_verify("V3_0", "SYNTHETIC", "ISSUER_A", "KEY_A", "NONCE_001")
        self.assertTrue(os.path.exists(self.ledger_file))

        # Reload in a new ledger instance
        ledger2 = ReplayLedger(self.ledger_file)
        with self.assertRaises(ValueError) as ctx:
            ledger2.record_and_verify("V3_0", "SYNTHETIC", "ISSUER_A", "KEY_A", "NONCE_001")
        self.assertEqual(str(ctx.exception), ERR_REPLAY_NONCE_COLLISION)

    def test_stage_and_rollback(self):
        ledger = ReplayLedger(self.ledger_file)
        ledger.stage_nonce("V3_0", "SYNTHETIC", "ISSUER_A", "KEY_A", "NONCE_STAGED")
        ledger.rollback()
        # Should be able to record again since it was rolled back
        ledger.record_and_verify("V3_0", "SYNTHETIC", "ISSUER_A", "KEY_A", "NONCE_STAGED")

    def test_replay_ledger_fail_closed_on_corruption(self):
        """RQA-05: Replay Ledger must fail-closed on corrupted, non-JSON or invalid-shape files."""
        # 1. Corrupted JSON syntax
        with open(self.ledger_file, "w", encoding="utf-8") as f:
            f.write("{\ninvalid json: [")
        with self.assertRaises(IOError) as ctx:
            ReplayLedger(self.ledger_file)
        self.assertIn(ERR_REPLAY_LEDGER_CORRUPTED, str(ctx.exception))

        # 2. JSON object instead of array
        with open(self.ledger_file, "w", encoding="utf-8") as f:
            f.write(json.dumps({"not": "a list"}))
        with self.assertRaises(IOError) as ctx:
            ReplayLedger(self.ledger_file)
        self.assertIn(ERR_REPLAY_LEDGER_CORRUPTED, str(ctx.exception))

        # 3. List with wrong element tuple shape
        with open(self.ledger_file, "w", encoding="utf-8") as f:
            f.write(json.dumps([["only", "two", "items"]]))
        with self.assertRaises(IOError) as ctx:
            ReplayLedger(self.ledger_file)
        self.assertIn(ERR_REPLAY_LEDGER_CORRUPTED, str(ctx.exception))


class TestStageVerifierSignaturesAndCensus(unittest.TestCase):
    """Q03, Q04, Q05: Stage Verifier Trust Anchor, Atomic Commit & 106 Census."""

    def setUp(self):
        self.verifier = StageBundleVerifier(trust_domain="SYNTHETIC_FIXTURE_TEST_ONLY")
        self.secret = b"TEST_SECRET_KEY_123456789012345678"
        self.verifier.register_trusted_key("ISSUER_DEV", "KEY_DEV_01", self.secret)

    def test_q03_q04_atomic_signed_stage(self):
        stage_data = {
            "stage_name": "S0",
            "nonce": "NONCE_S0_01",
            "issuer_id": "ISSUER_DEV",
            "key_fingerprint": "KEY_DEV_01",
            "process_identity": {"pid": 5555, "birth_timestamp": "2026-11-04T00:00:00Z"},
            "prev_stage_digest": "0" * 64
        }
        sig = self.verifier.trust_registry.sign_stage("KEY_DEV_01", stage_data)

        # 1. Valid signed envelope
        d = self.verifier.verify_stage_envelope({"stage_data": stage_data, "signature_hex": sig})
        self.assertEqual(len(d), 64)
        self.assertEqual(self.verifier.current_stage_idx, 0)

        # 2. Forged signature fails and preserves stage index
        stage_data_bad = {
            "stage_name": "PREPROBE",
            "nonce": "NONCE_PRE_01",
            "issuer_id": "ISSUER_DEV",
            "key_fingerprint": "KEY_DEV_01",
            "process_identity": {"pid": 5555, "birth_timestamp": "2026-11-04T00:00:00Z"},
            "prev_stage_digest": d
        }
        with self.assertRaises(ValueError) as ctx:
            self.verifier.verify_stage_envelope({"stage_data": stage_data_bad, "signature_hex": "bad_sig_hex"})
        self.assertIn(ERR_INVALID_SIGNATURE, str(ctx.exception))
        # Stage index was rolled back / not committed
        self.assertEqual(self.verifier.current_stage_idx, 0)

    def test_q05_exact_106_census(self):
        # 1. Exact match against CANONICAL_106_PATHS
        manifest = {p: "hash" for p in CANONICAL_106_PATHS}
        ok, anomalies = self.verifier.verify_106_path_census(manifest, claim_clean_all=False)
        self.assertTrue(ok)
        self.assertEqual(len(anomalies), 0)

        # 2. Substituted path (count=106 but 1 foreign path)
        bad_manifest = dict(manifest)
        first_key = list(bad_manifest.keys())[0]
        del bad_manifest[first_key]
        bad_manifest["unauthorized/foreign_path.dat"] = "hash"
        self.assertEqual(len(bad_manifest), 106)
        ok2, anomalies2 = self.verifier.verify_106_path_census(bad_manifest, claim_clean_all=False)
        self.assertFalse(ok2)
        self.assertTrue(any(ERR_PATH_CENSUS_MISMATCH in a for a in anomalies2))


class TestF01ThroughF69Matrix(unittest.TestCase):
    """Q08: Exhaustive execution of all F01 through F69 fixture specifications."""

    @classmethod
    def setUpClass(cls):
        spec_path = os.path.join(TOOLS_DIR, "fixture_spec_v3.json")
        with open(spec_path, "r", encoding="utf-8") as f:
            cls.spec = json.load(f)

    def setUp(self):
        self.validator = EventChainValidator(trust_domain="SYNTHETIC_FIXTURE_TEST_ONLY")

    def test_full_69_matrix_execution(self):
        cases = self.spec.get("cases", [])
        self.assertEqual(len(cases), 69, "Must contain exactly 69 case objects (F01–F69)")

        passed_count = 0
        fixture_results = {}
        for c in cases:
            cid = c["id"]
            expected_code = c.get("error_code")

            # Base event
            ev = get_base_event()

            if cid == "F01":
                d = self.validator.validate_event(ev)
                self.assertEqual(len(d), 64)
                fixture_results[cid] = "PASS"
                passed_count += 1
                continue

            # Mutate event according to target case
            mutated = copy.deepcopy(ev)
            target = c.get("target_property")

            if cid == "F02":
                # Forged signature
                reg = TrustAnchorRegistry()
                reg.register_key("ISS_1", "KEY_1", b"secret")
                with self.assertRaises(ValueError) as ctx:
                    reg.verify_stage_signature("KEY_1", {"data": 1, "issuer_id": "ISS_1", "key_fingerprint": "KEY_1"}, "deadbeef")
                self.assertEqual(str(ctx.exception), expected_code)

            elif cid == "F03":
                ledger = ReplayLedger()
                ledger.record_and_verify("V3_0", "SYNTHETIC", "ISS_1", "KEY_1", "NONCE_REUSE")
                with self.assertRaises(ValueError) as ctx:
                    ledger.record_and_verify("V3_0", "SYNTHETIC", "ISS_1", "KEY_1", "NONCE_REUSE")
                self.assertEqual(str(ctx.exception), expected_code)

            elif cid == "F59":
                # Cross-domain cryptographic proof, not a relabeled F03:
                # independently sign/verify STAGE and ACTION payloads under
                # different domain prefixes, then enforce their common nonce.
                reg = TrustAnchorRegistry()
                reg.register_key("ISS_1", "KEY_1", b"synthetic-shared-key")
                stage = {"issuer_id": "ISS_1", "key_fingerprint": "KEY_1",
                         "nonce": "SHARED_NONCE", "kind": "STAGE"}
                action = {"issuer_id": "ISS_1", "key_fingerprint": "KEY_1",
                          "nonce": "SHARED_NONCE", "kind": "ACTION"}
                signed_stage = reg.sign_stage("KEY_1", stage)
                signed_action = reg.sign_action("KEY_1", action)
                self.assertNotEqual(signed_stage, signed_action)
                reg.verify_stage_signature("KEY_1", stage, signed_stage)
                reg.verify_action_signature("KEY_1", action, signed_action)
                with self.assertRaises(ValueError) as bad_domain:
                    reg.verify_action_signature("KEY_1", action, reg.sign_stage("KEY_1", action))
                self.assertEqual(str(bad_domain.exception), ERR_INVALID_SIGNATURE)
                ledger = ReplayLedger()
                ledger.record_and_verify("V3_0", "SYNTHETIC", "ISS_1", "KEY_1", stage["nonce"])
                with self.assertRaises(ValueError) as ctx:
                    ledger.record_and_verify("V3_0", "SYNTHETIC", "ISS_1", "KEY_1", action["nonce"])
                self.assertEqual(str(ctx.exception), expected_code)

            elif cid == "F04":
                sbv = StageBundleVerifier()
                s1 = {"stage_name": "S0", "nonce": "N1", "process_identity": {"pid": 11, "birth_timestamp": "T1"}, "prev_stage_digest": "0"*64}
                sbv.verify_stage_envelope(s1)
                s2 = {"stage_name": "PREPROBE", "nonce": "N2", "process_identity": {"pid": 11, "birth_timestamp": "T2_MISMATCH"}, "prev_stage_digest": sbv.last_stage_digest}
                with self.assertRaises(ValueError) as ctx:
                    sbv.verify_stage_envelope(s2)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F05":
                sbv = StageBundleVerifier()
                s_bad = {"stage_name": "S2", "nonce": "N1", "prev_stage_digest": "0"*64}
                with self.assertRaises(ValueError) as ctx:
                    sbv.verify_stage_envelope(s_bad)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F06":
                sbv = StageBundleVerifier()
                ok, errs = sbv.verify_106_path_census({"incomplete": "1"})
                self.assertFalse(ok)
                self.assertTrue(any(expected_code in e for e in errs))

            elif cid == "F07":
                sbv = StageBundleVerifier()
                with self.assertRaises(ValueError) as ctx:
                    sbv.verify_broker_economics({"symbol": "XAUUSDx"})
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F08":
                sbv = StageBundleVerifier()
                with self.assertRaises(ValueError) as ctx:
                    sbv.verify_temporal_coverage(start_year=2023, end_year=2026, warmup_complete=False)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F09":
                v = EventChainValidator()
                v.validate_event(ev)
                ev_ret = copy.deepcopy(ev)
                ev_ret["event_id"] = "RUN01:STREAM_MAIN:0:READ_RET:2"
                ev_ret["event_type"] = "READ_RETURN"
                ev_ret["local_counter"] = 2
                ev_ret["parent_event_id"] = "RUN01:STREAM_MAIN:0:READ_REQ:999"
                ev_ret["prev_event_digest"] = v.last_digest
                with self.assertRaises(ValueError) as ctx:
                    v.validate_event(ev_ret)
                self.assertEqual(str(ctx.exception), expected_code)

            elif cid == "F10":
                sbv = StageBundleVerifier()
                with self.assertRaises(ValueError) as ctx:
                    sbv.verify_broker_economics({"symbol": "XAUUSD", "commission": 0.0, "s2_broker_authenticated": False})
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F11":
                sbv = StageBundleVerifier()
                with self.assertRaises(ValueError) as ctx:
                    sbv.verify_bundle_completeness({"deal_journal": "log.txt"})
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F12":
                sbv = StageBundleVerifier()
                with self.assertRaises(ValueError) as ctx:
                    sbv.verify_legacy_ex5_identity(claimed_sha256="deadbeef" * 8)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F13":
                v13 = EventChainValidator(trust_domain="SYNTHETIC_FIXTURE_TEST_ONLY")
                d_first = v13.validate_event(ev)
                ev2 = copy.deepcopy(ev)
                ev2["event_id"] = "RUN01:STREAM_MAIN:0:READ_REQ:2"
                ev2["event_type"] = "READ_REQUEST"
                ev2["local_counter"] = 2
                ev2["prev_event_digest"] = "f" * 64
                with self.assertRaises(ValueError) as ctx:
                    v13.validate_event(ev2)
                self.assertEqual(str(ctx.exception), expected_code)

            elif cid == "F14":
                sbv = StageBundleVerifier()
                manifest = {p: "hash" for p in CANONICAL_106_PATHS}
                ok, errs = sbv.verify_106_path_census(manifest, claim_clean_all=True)
                self.assertFalse(ok)
                self.assertTrue(any(expected_code in e for e in errs))

            # F15 to F57: Schema and Invariant checks
            elif cid == "F15":
                del mutated["schema_version"]
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F16":
                mutated["schema_version"] = "INVALID_VER"
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F17":
                del mutated["lineage_id"]
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F18":
                mutated["lineage_id"] = "INVALID_LINEAGE"
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F19":
                mutated["trust_domain"] = "INVALID_TRUST_DOMAIN"
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F20":
                mutated["event_id"] = "malformed:id"
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F21":
                mutated["emitter_generation"] = -1
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F22":
                mutated["event_type"] = "INVALID_EVENT_TYPE"
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F23":
                mutated["local_counter"] = -5
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F24":
                mutated["recorded_utc"] = "not_an_iso_timestamp"
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F25":
                mutated["strategy_bar_time"] = "bad_time_string"
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F26":
                del mutated["call_site"]["file"]
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F27":
                del mutated["call_site"]["function"]
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F28":
                mutated["call_site"]["line"] = 0
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F29":
                del mutated["sensor_payload"]["symbol"]
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F30":
                del mutated["sensor_payload"]["timeframe"]
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F31":
                mutated["sensor_payload"]["indicator_kind"] = "INVALID_INDICATOR"
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F32":
                mutated["sensor_payload"]["period"] = 0
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F33":
                del mutated["sensor_payload"]["handle_id"]
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F34":
                mutated["sensor_payload"]["handle_generation"] = -1
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F35":
                mutated["sensor_payload"]["buffer_id"] = -1
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F36":
                mutated["sensor_payload"]["start_pos"] = -1
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F37":
                mutated["sensor_payload"]["requested_count"] = 0
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F38":
                mutated["sensor_payload"]["error_code"] = -10
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F39":
                del mutated["causality_link"]["consumed_in_decision"]
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F40":
                mutated["causality_link"]["edge_type"] = "INVALID_EDGE"
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F41":
                del mutated["assurance_class"]["trace_internal_closed"]
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F42":
                del mutated["assurance_class"]["static_scope_instrumented"]
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F43":
                mutated["assurance_class"]["actual_api_calls_witnessed"] = "INVALID_WITNESS"
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F44":
                mutated["prev_event_digest"] = "short_hash"
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F45":
                mutated["prev_event_digest"] = "z" * 64
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F46":
                mutated["unauthorized_top_key"] = True
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F47":
                mutated["call_site"]["unauthorized_nested"] = True
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F48":
                mutated["sensor_payload"]["unauthorized_nested"] = True
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F49":
                mutated["causality_link"]["unauthorized_nested"] = True
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F50":
                mutated["assurance_class"]["unauthorized_nested"] = True
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F51":
                mutated["sensor_payload"]["timeframe"] = -1
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F52":
                mutated["sensor_payload"]["symbol"] = ""
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F53":
                mutated["sensor_payload"]["handle_id"] = ""
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F54":
                mutated["sensor_payload"] = None
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F55":
                mutated["call_site"] = None
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F56":
                mutated["assurance_class"] = None
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F57":
                mutated["causality_link"] = None
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F58":
                v = EventChainValidator()
                v.validate_event(ev)
                with self.assertRaises(ValueError) as ctx:
                    v.validate_event(ev)
                self.assertEqual(str(ctx.exception), expected_code)

            elif cid == "F60":
                v = EventChainValidator()
                d = v.validate_event(ev)
                ev_dec = copy.deepcopy(ev)
                ev_dec["event_id"] = "RUN01:STREAM_MAIN:0:DECISION:2"
                ev_dec["event_type"] = "DECISION"
                ev_dec["local_counter"] = 2
                ev_dec["causality_link"]["consumed_in_decision"] = True
                ev_dec["causality_link"]["edge_type"] = "BAR_ASSOCIATION"
                ev_dec["prev_event_digest"] = d
                with self.assertRaises(ValueError) as ctx:
                    v.validate_event(ev_dec)
                self.assertEqual(str(ctx.exception), expected_code)

            elif cid == "F61":
                v = EventChainValidator()
                d = v.validate_event(ev)
                ev_dec = copy.deepcopy(ev)
                ev_dec["event_id"] = "RUN01:STREAM_MAIN:0:DECISION:2"
                ev_dec["event_type"] = "DECISION"
                ev_dec["local_counter"] = 2
                ev_dec["causality_link"]["consumed_in_decision"] = True
                ev_dec["causality_link"]["edge_type"] = "DECISION_DEPENDENCY"
                ev_dec["prev_event_digest"] = d
                with self.assertRaises(ValueError) as ctx:
                    v.validate_event(ev_dec, time_filter_active=True)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F62":
                ht = HandleLifecycleTracker()
                ht.create("HND_A", 1)
                ht.release("HND_A")
                with self.assertRaises(ValueError) as ctx:
                    ht.verify_active("HND_A", 1)
                self.assertEqual(str(ctx.exception), expected_code)

            elif cid == "F63":
                sbv = StageBundleVerifier()
                declared = ["CS_OnInit_01", "CS_OnTick_02", "CS_TradeExecute_03"]
                telemetry = ["CS_OnInit_01", "CS_OnTick_02"]  # Omitted CS_TradeExecute_03
                with self.assertRaises(ValueError) as ctx:
                    sbv.verify_callsite_static_coverage(declared, telemetry)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F64":
                v64 = EventChainValidator(trust_domain="SYNTHETIC_FIXTURE_TEST_ONLY")
                mutated["assurance_class"]["actual_api_calls_witnessed"] = "CONFIRMED_EXTERNAL_WITNESS"
                with self.assertRaises(ValueError) as ctx:
                    v64.validate_event(mutated, external_witness_present=False)
                self.assertEqual(str(ctx.exception), expected_code)

            elif cid == "F65":
                mutated["local_counter"] = 1.5
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F66":
                # In Unicode code points: '\uFFFF' < '\U00010000'.
                # But in UTF-16 code units: '\U00010000' is surrogate pair '\uD800\uDC00'.
                # Because 0xD800 < 0xFFFF, RFC 8785 requires '\U00010000' BEFORE '\uFFFF'.
                # Thus ['\uFFFF', '\U00010000'] is improperly sorted and must be rejected.
                bad_order_keys = ["\uFFFF", "\U00010000"]
                with self.assertRaises(ValueError) as ctx:
                    verify_jcs_key_sort(bad_order_keys)
                self.assertIn(expected_code, str(ctx.exception))

            elif cid == "F67":
                v = EventChainValidator()
                d = v.validate_event(ev)
                ev_req = copy.deepcopy(ev)
                ev_req["event_id"] = "RUN01:STREAM_MAIN:0:READ_REQ:2"
                ev_req["event_type"] = "READ_REQUEST"
                ev_req["local_counter"] = 2
                ev_req["parent_event_id"] = ev["event_id"]
                ev_req["prev_event_digest"] = d
                d2 = v.validate_event(ev_req)

                ev_ret = copy.deepcopy(ev_req)
                ev_ret["event_id"] = "RUN01:STREAM_MAIN:0:READ_RET:3"
                ev_ret["event_type"] = "READ_RETURN"
                ev_ret["local_counter"] = 3
                ev_ret["parent_event_id"] = ev_req["event_id"]
                ev_ret["sensor_payload"]["returned_count"] = 0
                ev_ret["sensor_payload"]["error_code"] = 0
                ev_ret["prev_event_digest"] = d2
                with self.assertRaises(ValueError) as ctx:
                    v.validate_event(ev_ret)
                self.assertEqual(str(ctx.exception), expected_code)

            elif cid == "F68":
                mutated["trust_domain"] = "NATIVE_AUTHENTIC_PROD_ONLY"
                with self.assertRaises(ValueError) as ctx:
                    self.validator.validate_event(mutated)
                self.assertEqual(str(ctx.exception), expected_code)

            elif cid == "F69":
                reg = TrustAnchorRegistry()
                reg.register_key("ISS_1", "KEY_REVOKED_01", b"secret", revoked=True)
                with self.assertRaises(ValueError) as ctx:
                    reg.sign_stage("KEY_REVOKED_01", {"data": 1})
                self.assertEqual(str(ctx.exception), expected_code)

            else:
                self.fail(f"Unhandled fixture case: {cid} has no execution branch or assertion!")

            fixture_results[cid] = "PASS"
            passed_count += 1

        self.assertEqual(passed_count, 69, "All 69 cases must be executed and pass exact assertion")
        self.assertEqual(len(fixture_results), 69, "All 69 cases must have recorded PASS")
        self.__class__.fixture_results = fixture_results

        # Dynamic receipt generation and validation (RQA-01, L3)
        receipt_path = os.path.join(os.path.dirname(__file__), "w5_f01_f69_matrix_receipt.json")
        receipt_list = []
        for c in cases:
            cid = c["id"]
            receipt_list.append({
                "id": cid,
                "description": c.get("description"),
                "target_property": c.get("target_property"),
                "expected_result": c.get("expected_result"),
                "error_code": c.get("error_code"),
                "actual_status": "PASS"
            })
        with open(receipt_path, "w", encoding="utf-8") as rf:
            json.dump(receipt_list, rf, indent=2)

        self.assertTrue(os.path.exists(receipt_path))
        with open(receipt_path, "r", encoding="utf-8") as rf:
            loaded_receipt = json.load(rf)
        self.assertEqual(len(loaded_receipt), 69)


if __name__ == "__main__":
    unittest.main()
