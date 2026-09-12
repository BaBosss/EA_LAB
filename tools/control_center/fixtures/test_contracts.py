import copy
import json
import unittest
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from tools.control_center.contracts import *

SHA = "a" * 40
NOW = "2026-09-12T12:00:00Z"


class ContractsTests(unittest.TestCase):
    def make(self, **overrides):
        args = dict(source_id="fixture", source_path="fixtures/example.json", canonical_sha=SHA,
                    raw=b"{}", as_of=NOW, observed_at=NOW, clock_basis="UTC",
                    policy="FIXTURE_ONLY", max_age_seconds=60)
        return observe(**{**args, **overrides})

    def test_current_roundtrip(self):
        item = self.make()
        self.assertEqual(item, SourceObservation.from_dict(json.loads(json.dumps(item.to_dict())), expected_source="fixture", expected_sha=SHA))
        self.assertEqual(Freshness.CURRENT, item.freshness)

    def test_missing(self): self.assertEqual(Freshness.MISSING, self.make(raw=None).freshness)
    def test_malformed(self): self.assertEqual(Freshness.MALFORMED, self.make(malformed=True).freshness)
    def test_stale(self): self.assertEqual(Freshness.STALE, self.make(observed_at="2026-09-12T11:00:00Z").freshness)
    def test_future(self): self.assertEqual(Freshness.FUTURE, self.make(observed_at="2026-09-12T12:00:01Z").freshness)
    def test_boundary(self): self.assertEqual(Freshness.CURRENT, self.make(observed_at="2026-09-12T11:59:00Z").freshness)
    def test_unknown_clock(self): self.assertEqual(Freshness.UNKNOWN, self.make(clock_basis="UNKNOWN").freshness)
    def test_no_universal_ttl(self): self.assertEqual(Freshness.UNKNOWN, self.make(max_age_seconds=None).freshness)
    def test_historical(self): self.assertEqual(Freshness.HISTORICAL, self.make(historical=True).freshness)
    def test_disabled(self): self.assertEqual(Freshness.DISABLED, self.make(disabled=True).freshness)

    def test_rejected_envelopes(self):
        for key, value in [("schema", "source_observation/2"), ("source_id", "wrong"), ("canonical_sha", "b"*40),
                           ("source_path", "../private"), ("reason", "password=abc"), ("reason", "463666728"),
                           ("observed_at", "2026-09-12 12:00:00"), ("clock_basis", "EST"),
                           ("age_seconds", True), ("age_seconds", float("nan")), ("freshness", "GREEN"),
                           ("extra", "value"), ("data_sha256", "not-a-hash"), ("quality", []),
                           ("observed_at", None)]:
            with self.subTest(key=key, value=value):
                item = self.make().to_dict()
                item[key] = value
                with self.assertRaises(ProjectionError):
                    SourceObservation.from_dict(item, expected_source="fixture", expected_sha=SHA)

    def test_unsafe_strings(self):
        for value in ["<script>", "https://example.invalid", "C:\\private", "bearer abc", "sk-abcdef", "user@example.invalid", "api_key=abc", "a\nline"]:
            with self.subTest(value=value), self.assertRaises(ProjectionError): safe_text(value)

    def test_unsafe_paths(self):
        for value in ["/tmp/a", "a/../b", "a//b", "a/CON.txt", "a/file.", "a\\b", "https://x", "a/%2e"]:
            with self.subTest(value=value), self.assertRaises(ProjectionError): safe_path(value)

    def test_malformed_json(self):
        for raw in [b"", b"[]", b'{"a":NaN}', b'{"a":1,"a":2}', b"\xff"]:
            with self.subTest(raw=raw), self.assertRaises(ProjectionError): parse_json(raw)

    def test_invalid_date(self):
        with self.assertRaises(ProjectionError): utc("2026-02-30T00:00:00Z")

    def test_unqualified_policy(self):
        with self.assertRaises(ProjectionError): self.make(policy="UNQUALIFIED")


if __name__ == "__main__": unittest.main()
