"""Offline positive and adversarial fixtures; no market/runtime access."""
from pathlib import Path
import tempfile
import unittest

from tools.control_center.contracts.observations import ProjectionError, digest
from tools.control_center.forward_alpha import Ledger, canonical, summarize, decay, hypotheses, snapshot
from tools.control_center.forward_alpha.sidecar import DIMENSIONS, MODULE


def obs(identity="obs-one", **changes):
    result = dict(schema="forward_observation/1", observation_id=identity,
                  observed_at="2026-01-01T00:00:00Z", symbol="EURUSD", timeframe="H1",
                  strategy="trend", family="family-a", variant="variant-a", regime="trend-up",
                  direction="UP", horizon={"kind": "ELAPSED_SECONDS", "seconds": 3600},
                  config_sha256="UNKNOWN", authority="RESEARCH_ONLY", snapshot_sha256="a" * 64,
                  reference_price=100)
    result.update(changes)
    return result


def pack(payload, available="2026-01-01T00:00:00Z", **changes):
    envelope = dict(source_id="fixture-feed", ref="fixtures/market.json", canonical_sha="b" * 40,
                    available_at=available, payload=payload)
    envelope.update(changes)
    raw = canonical(envelope)
    expected = {k: envelope[k] for k in ("source_id", "ref", "canonical_sha")}
    expected["sha256"] = digest(raw)
    return raw, expected


def query(**changes):
    result = dict(group_by=list(DIMENSIONS), omitted_dimensions=[],
                  start_at="2026-01-01T00:00:00Z", end_at="2026-01-03T00:00:00Z",
                  as_of="2026-01-04T00:00:00Z", filters={})
    result.update(changes)
    return result


class ForwardAlphaTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="fixture-", dir=MODULE)
        self.addCleanup(self.temp.cleanup)
        self.ledger = Ledger(Path(self.temp.name) / "ledger")

    def observe(self, payload=None, available="2026-01-01T00:00:00Z", **changes):
        raw, expected = pack(payload or obs(), available, **changes)
        return self.ledger.observe(raw, expected_source=expected)

    def settle(self, identity="obs-one", price=90, **changes):
        observations, _, _ = self.ledger.read()
        payload = dict(schema="forward_settlement/1", observation_id=identity,
                       observation_sha256=observations.get(identity, {}).get("record_sha256", "c" * 64),
                       end_at="2026-01-01T01:00:00Z", end_price=price)
        payload.update(changes)
        raw, expected = pack(payload, "2026-01-03T00:00:00Z")
        return self.ledger.settle(raw, expected_source=expected)

    def group(self):
        return summarize(self.ledger, query())["groups"][0]

    def test_future_observation_source_refused(self):
        with self.assertRaisesRegex(ProjectionError, "LOOK_AHEAD"):
            self.observe(available="2026-01-01T00:00:01Z")

    def test_unsafe_source_paths_refused(self):
        for ref in ("../escape.json", "D:/outside.json", "a\\b", "https://example.com/x", "NUL.json"):
            with self.subTest(ref=ref), self.assertRaises(ProjectionError):
                self.observe(ref=ref)

    def test_unsafe_source_id_refused(self):
        with self.assertRaises(ProjectionError):
            self.observe(source_id="<script>")

    def test_invalid_source_hash_refused(self):
        raw, expected = pack(obs())
        expected["sha256"] = "not-a-hash"
        with self.assertRaises(ProjectionError):
            self.ledger.observe(raw, expected_source=expected)

    def test_wrong_source_hash_refused(self):
        raw, expected = pack(obs())
        expected["sha256"] = "0" * 64
        with self.assertRaisesRegex(ProjectionError, "SOURCE_HASH_MISMATCH"):
            self.ledger.observe(raw, expected_source=expected)

    def test_source_identity_mismatch_refused(self):
        for key, value in (("source_id", "other"), ("ref", "other.json"), ("canonical_sha", "d" * 40)):
            raw, expected = pack(obs())
            expected[key] = value
            with self.subTest(key=key), self.assertRaisesRegex(ProjectionError, "PROVENANCE"):
                self.ledger.observe(raw, expected_source=expected)

    def test_canonical_sha_explicitly_not_applicable(self):
        self.observe(canonical_sha=None)
        self.assertIsNone(self.group()["evidence"][0]["observation"]["source"]["canonical_sha"])

    def test_exact_observation_duplicate_is_noop(self):
        first = self.observe()
        before = self.ledger.path.read_bytes()
        self.assertEqual(first, self.observe())
        self.assertEqual(before, self.ledger.path.read_bytes())

    def test_divergent_observation_refused(self):
        self.observe()
        with self.assertRaisesRegex(ProjectionError, "DIVERGENT"):
            self.observe(obs(regime="sideways"))

    def test_same_payload_different_source_bytes_refused(self):
        self.observe()
        raw, expected = pack(obs())
        raw += b" "
        expected["sha256"] = digest(raw)
        with self.assertRaisesRegex(ProjectionError, "DIVERGENT"):
            self.ledger.observe(raw, expected_source=expected)

    def test_unknown_settlement_refused(self):
        with self.assertRaisesRegex(ProjectionError, "UNKNOWN_OBSERVATION"):
            self.settle()

    def test_bad_horizon_endpoints_refused(self):
        self.observe()
        for end in ("2025-12-31T23:00:00Z", "2026-01-01T00:00:00Z", "2026-01-01T00:59:59Z", "2026-01-01T01:00:01Z"):
            with self.subTest(end=end), self.assertRaisesRegex(ProjectionError, "HORIZON"):
                self.settle(end_at=end)

    def test_outcome_source_before_endpoint_refused(self):
        pinned = self.observe()
        raw, expected = pack(dict(schema="forward_settlement/1", observation_id="obs-one",
                                  observation_sha256=pinned, end_at="2026-01-01T01:00:00Z", end_price=90))
        with self.assertRaisesRegex(ProjectionError, "OUTCOME_NOT_YET_AVAILABLE"):
            self.ledger.settle(raw, expected_source=expected)

    def test_settlement_wrong_observation_hash_refused(self):
        self.observe()
        with self.assertRaisesRegex(ProjectionError, "OBSERVATION_PROVENANCE"):
            self.settle(observation_sha256="0" * 64)

    def test_exact_settlement_duplicate_is_noop(self):
        self.observe()
        first = self.settle()
        before = self.ledger.path.read_bytes()
        self.assertEqual(first, self.settle())
        self.assertEqual(before, self.ledger.path.read_bytes())

    def test_divergent_settlement_refused(self):
        self.observe()
        self.settle()
        with self.assertRaisesRegex(ProjectionError, "DIVERGENT"):
            self.settle(price=110)

    def test_negative_positive_zero_and_open_preserved(self):
        for identity, price in (("loss", 90), ("win", 120), ("zero", 100), ("open", None)):
            self.observe(obs(identity))
            if price is not None:
                self.settle(identity, price)
        group = self.group()
        self.assertEqual((group["sample_count"], group["negative_count"], group["positive_count"],
                          group["zero_count"], group["open_count"]), (3, 1, 1, 1, 1))
        self.assertAlmostEqual(group["mean_signed_outcome"], 0.1 / 3)
        self.assertEqual(group["median_signed_outcome"], 0)
        self.assertEqual(len(self.ledger.read()[1]), 3)
        self.assertEqual(group["hit_rate"], 1 / 3)

    def test_identity_dimensions_never_silently_mix(self):
        self.observe()
        for key in ("symbol", "timeframe", "strategy", "family", "variant", "regime"):
            self.observe(obs(key, **{key: "another"}))
        self.assertEqual(len(summarize(self.ledger, query())["groups"]), 7)
        with self.assertRaisesRegex(ProjectionError, "OMISSION"):
            summarize(self.ledger, query(group_by=["symbol"]))
        merged = summarize(self.ledger, query(group_by=[], omitted_dimensions=list(DIMENSIONS)))
        self.assertEqual(merged["groups"][0]["open_count"], 7)
        self.assertEqual(merged["query"]["omitted_dimensions"], list(DIMENSIONS))

    def test_minimum_sample_preserves_nonqualifying_groups(self):
        self.observe()
        self.settle()
        result = summarize(self.ledger, query(minimum_sample=20))
        self.assertEqual(result["minimum_sample_origin"], "CALLER_SUPPLIED")
        self.assertFalse(result["groups"][0]["caller_minimum_sample_met"])
        self.assertEqual(result["groups"][0]["negative_count"], 1)

    def test_as_of_hides_later_settlement_as_open(self):
        self.observe()
        self.settle()
        result = summarize(self.ledger, query(end_at="2026-01-02T00:00:00Z", as_of="2026-01-02T00:00:00Z"))
        self.assertEqual(result["groups"][0]["open_count"], 1)
        self.assertIsNone(result["groups"][0]["evidence"][0]["outcome"])

    def test_filter_and_half_open_window_explicit(self):
        self.observe()
        self.observe(obs("later", observed_at="2026-01-02T00:00:00Z"))
        result = summarize(self.ledger, query(end_at="2026-01-02T00:00:00Z"))
        self.assertEqual(result["groups"][0]["open_count"], 1)
        self.assertEqual(summarize(self.ledger, query(filters={"symbol": ["XAUUSD"]}))["groups"], [])

    def test_unsigned_has_no_invented_hit_or_signed_metrics(self):
        self.observe(obs(direction="UNSIGNED"))
        self.settle()
        group = self.group()
        self.assertEqual(group["sample_count"], 1)
        self.assertEqual(group["signed_sample_count"], 0)
        self.assertIsNone(group["hit_rate"])
        self.assertIsNone(group["mean_signed_outcome"])

    def test_down_direction_and_extrema(self):
        self.observe(obs(direction="DOWN"))
        self.settle(high_price=110, low_price=80)
        group = self.group()
        self.assertEqual(group["mean_signed_outcome"], 0.1)
        self.assertEqual(group["mfe"]["mean"], 0.2)
        self.assertEqual(group["mae"]["mean"], -0.1)

    def test_invalid_extrema_refused(self):
        self.observe()
        for fields in ({"high_price": 110}, {"low_price": 80, "high_price": 95}, {"low_price": 95, "high_price": 110}):
            with self.subTest(fields=fields), self.assertRaises(ProjectionError):
                self.settle(**fields)

    def test_nonfinite_boolean_and_nonpositive_prices_refused(self):
        for price in (float("nan"), float("inf"), True, 0, -1):
            with self.subTest(price=price), self.assertRaises(ProjectionError):
                self.observe(obs(reference_price=price))

    def test_malformed_horizon_and_timestamp_refused(self):
        for horizon in ({"kind": "BARS", "seconds": 1}, {"kind": "ELAPSED_SECONDS", "seconds": True},
                        {"kind": "ELAPSED_SECONDS", "seconds": -1}):
            with self.subTest(horizon=horizon), self.assertRaises(ProjectionError):
                self.observe(obs(horizon=horizon))
        with self.assertRaises(ProjectionError):
            self.observe(obs(observed_at="2026-01-01T00:00:00+00:00"))

    def test_snapshot_hash_and_required_identity_refused(self):
        for fields in ({"snapshot_sha256": "bad"}, {"family": "UNKNOWN"}, {"config_sha256": "bad"}):
            with self.subTest(fields=fields), self.assertRaises(ProjectionError):
                self.observe(obs(**fields))

    def test_authoritative_input_fields_refused(self):
        for fields in ({"grade": "A"}, {"Candidate": True}, {"authority": "LIVE"}, {"pf": 2}):
            with self.subTest(fields=fields), self.assertRaises(ProjectionError):
                self.observe(obs(**fields))

    def test_duplicate_json_key_refused(self):
        raw, expected = pack(obs())
        raw = raw.replace(b'"direction":"UP"', b'"direction":"UP","direction":"DOWN"')
        expected["sha256"] = digest(raw)
        with self.assertRaises(ProjectionError):
            self.ledger.observe(raw, expected_source=expected)

    def test_mutated_ledger_refused(self):
        self.observe()
        raw = self.ledger.path.read_bytes().replace(b'"previous_sha256":"0', b'"previous_sha256":"1')
        self.ledger.path.write_bytes(raw)
        with self.assertRaisesRegex(ProjectionError, "LEDGER_HASH"):
            self.ledger.read()

    def test_truncated_ledger_refused(self):
        self.observe()
        self.ledger.path.write_bytes(self.ledger.path.read_bytes()[:-1])
        with self.assertRaisesRegex(ProjectionError, "INCOMPLETE_LEDGER"):
            self.ledger.read()

    def test_busy_ledger_refused(self):
        self.observe()
        lock = self.ledger.directory / "writer.lock"
        lock.write_bytes(b"")
        with self.assertRaisesRegex(ProjectionError, "LEDGER_BUSY"):
            self.observe(obs("another"))
        lock.unlink()

    def test_outside_module_ledger_refused(self):
        with self.assertRaisesRegex(ProjectionError, "OUTSIDE_MODULE"):
            Ledger(MODULE.parent / "contracts")

    def test_deterministic_snapshot_and_no_decision_fields(self):
        self.observe()
        self.settle()
        result = snapshot(self.ledger, query())
        self.assertEqual(canonical(result), canonical(snapshot(self.ledger, query())))
        forbidden = {"grade", "candidate", "live", "pass", "verdict", "promotion", "pf"}
        def walk(value):
            if isinstance(value, dict):
                self.assertFalse({k.lower() for k in value} & forbidden)
                for child in value.values():
                    walk(child)
            elif isinstance(value, list):
                for child in value:
                    walk(child)
        walk(result)
        self.assertEqual(result["trading"], "REAL_TRADING_OFF")

    def test_hypothesis_keeps_counter_evidence_and_unselected_groups(self):
        self.observe()
        self.settle()
        self.observe(obs("another", symbol="XAUUSD"))
        key = next(g["group_id"] for g in summarize(self.ledger, query())["groups"] if g["negative_count"])
        result = hypotheses(self.ledger, query=query(), selected_group_ids=[key])
        self.assertEqual(result["proposals"][0]["counter_evidence_ids"], ["obs-one"])
        self.assertEqual(len(result["summary"]["groups"]), 2)
        self.assertEqual(result["proposals"][0]["group"]["negative_count"], 1)
        with self.assertRaisesRegex(ProjectionError, "UNKNOWN_GROUP"):
            hypotheses(self.ledger, query=query(), selected_group_ids=["0" * 64])

    def test_decay_raw_deltas_and_missing_groups(self):
        self.observe()
        self.settle(price=110)
        self.observe(obs("later", observed_at="2026-01-02T00:00:00Z"))
        self.settle("later", 90, end_at="2026-01-02T01:00:00Z")
        prior = query(end_at="2026-01-02T00:00:00Z")
        recent = query(start_at="2026-01-02T00:00:00Z")
        result = decay(self.ledger, prior=prior, recent=recent)
        self.assertAlmostEqual(result["deltas"][0]["mean_signed_outcome_delta"], -0.2)
        self.assertEqual(result["interpretation"], "DESCRIPTIVE_ONLY")
        with self.assertRaisesRegex(ProjectionError, "INCOMPARABLE"):
            decay(self.ledger, prior=query(), recent=recent)

    def test_bad_query_refused(self):
        for changes in ({"minimum_sample": True}, {"filters": {"grade": ["A"]}},
                        {"group_by": list(DIMENSIONS) + ["symbol"]}, {"as_of": "2025-01-01T00:00:00Z"}):
            with self.subTest(changes=changes), self.assertRaises(ProjectionError):
                summarize(self.ledger, query(**changes))

    def test_extreme_finite_median_stays_serializable(self):
        for identity in ("large-one", "large-two"):
            self.observe(obs(identity, reference_price=1))
            self.settle(identity, 1e308, high_price=1e308, low_price=1)
        group = self.group()
        self.assertEqual(group["median_signed_outcome"], 1e308)
        self.assertEqual(group["mfe"]["median"], 1e308)
        canonical(snapshot(self.ledger, query()))

    def test_unhashable_selection_and_huge_integer_refused(self):
        with self.assertRaises(ProjectionError):
            hypotheses(self.ledger, query=query(), selected_group_ids=[[]])
        with self.assertRaises(ProjectionError):
            self.observe(obs(reference_price=10 ** 400))

    def test_overflow_decay_refuses(self):
        self.observe(obs(reference_price=1))
        self.settle(price=1e308)
        self.observe(obs("later", reference_price=1, direction="DOWN", observed_at="2026-01-02T00:00:00Z"))
        self.settle("later", 1e308, end_at="2026-01-02T01:00:00Z")
        grouped = [key for key in DIMENSIONS if key != "direction"]
        prior = query(group_by=grouped, omitted_dimensions=["direction"], end_at="2026-01-02T00:00:00Z")
        recent = query(group_by=grouped, omitted_dimensions=["direction"], start_at="2026-01-02T00:00:00Z")
        with self.assertRaisesRegex(ProjectionError, "INVALID_NUMBER"):
            decay(self.ledger, prior=prior, recent=recent)


if __name__ == "__main__":
    unittest.main()
