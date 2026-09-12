import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
from tools.control_center.guard_adapters import feeds as f

SHA = "b0df07ee776acd8450c1d06deba37cb63fbeb02f"
NOW = "2026-09-12T12:00:00Z"
NEWS = b'BkkTime,Currency,Title,TimeRaw,Forecast,Previous\n2026.09.12 19:00,USD,CPI,ignored,,\n'
MACRO = b'datetime,state,ri,flags\n2026.09.11 12:00,NEUTRAL,0.2,\n'


def snapshot(**changes):
    value = dict(generated_utc=NOW, state="RISK_OFF", risk_index=-0.3, bias="ignored", confidence="HIGH",
                 confidence_frac=0.8, active_count=8, flags=[], data_pending=[], barometers=[])
    return json.dumps({**value, **changes}).encode()


class FeedsTests(unittest.TestCase):
    def read(self, key="news_calendar", raw=NEWS, **extra):
        return f.project_feed(key, raw, sha=SHA, as_of=NOW, **extra)

    def test_news_event_time_not_feed_health(self):
        row = self.read()
        self.assertEqual("2026-09-12T12:00:00Z", row["payload"]["events"][0]["event_at_utc"])
        self.assertEqual("High", row["payload"]["events"][0]["importance"])
        self.assertEqual("UNKNOWN", row["state"])
        self.assertEqual("UNKNOWN", row["block_observation"])

    def test_macro_snapshot_age_without_universal_ttl(self):
        row = self.read("mris_snapshot", snapshot(generated_utc="2026-09-01T12:00:00Z"))
        self.assertEqual(11*86400, row["source"]["age_seconds"])
        self.assertEqual("HISTORICAL", row["source"]["freshness"])
        self.assertEqual("UNKNOWN", row["state"])
        self.assertEqual("RISK_OFF", row["payload"]["regime_state"])

    def test_new_mtime_cannot_refresh_old_bytes(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "macro.json"
            path.write_bytes(snapshot(generated_utc="2020-01-01T00:00:00Z"))
            before = self.read("mris_snapshot", path.read_bytes())
            os.utime(path, (0, 0))
            self.assertEqual(before, self.read("mris_snapshot", path.read_bytes()))

    def test_missing_news_value_is_not_allow(self):
        row = self.read(raw=None)
        self.assertEqual("MISSING", row["state"])
        self.assertEqual("UNKNOWN", row["block_observation"])

    def test_stale_macro_value_not_effective(self):
        row = self.read("macro_timeline", MACRO.replace(b"2026.09.11", b"2020.01.01"))
        self.assertIsNone(row["lot_multiplier_observation"])
        self.assertEqual("UNKNOWN", row["runtime_effectiveness"])

    def test_malformed_numeric(self):
        for value in ["bad", True, float("nan"), None]:
            with self.subTest(value=value):
                self.assertEqual("MALFORMED", self.read("mris_snapshot", snapshot(risk_index=value))["state"])

    def test_missing_timestamp(self):
        self.assertEqual("MALFORMED", self.read("mris_snapshot", snapshot(generated_utc=None))["state"])

    def test_unknown_dst_basis(self):
        for stamp in ["2026-09-12 12:00:00", "2026-09-12T12:00:00 EST", "2026-09-12T12:00:00+02:00"]:
            with self.subTest(stamp=stamp):
                self.assertEqual("MALFORMED", self.read("mris_snapshot", snapshot(generated_utc=stamp))["state"])

    def test_duplicate_event(self):
        raw = NEWS + NEWS.splitlines(keepends=True)[1]
        self.assertEqual("MALFORMED", self.read(raw=raw)["state"])

    def test_out_of_order_event(self):
        self.assertEqual("MALFORMED", self.read(raw=NEWS + b'2026.09.11 19:00,USD,CPI,ignored,,\n')["state"])

    def test_duplicate_and_out_of_order_timeline(self):
        for extra in [b'2026.09.11 12:00,STRESS,-1,\n', b'2026.09.10 12:00,STRESS,-1,\n']:
            self.assertEqual("MALFORMED", self.read("macro_timeline", MACRO + extra)["state"])

    def test_disabled_field_cannot_invent_disabled_runtime(self):
        row = self.read("mris_snapshot", snapshot(enabled=False))
        self.assertEqual("MALFORMED", row["state"])
        self.assertEqual("UNKNOWN", row["enabled"])

    def test_runtime_source_unbound(self):
        row = self.read("mris_snapshot", snapshot(), producer_bound=False)
        self.assertEqual("UNKNOWN", row["state"])
        self.assertEqual({}, row["payload"])
        self.assertEqual("PRODUCER_VERSION_UNQUALIFIED", row["reason"])

    def test_future_snapshot(self):
        row = self.read("mris_snapshot", snapshot(generated_utc="2026-09-13T12:00:00Z"))
        self.assertEqual("FUTURE", row["source"]["freshness"])
        self.assertEqual({}, row["payload"])

    def test_future_timeline_rows_withheld(self):
        row = self.read("macro_timeline", MACRO + b'2026.09.13 12:00,STRESS,-1,\n')
        self.assertEqual("NEUTRAL", row["payload"]["latest_as_of_row"]["regime_state"])
        self.assertEqual(1, row["payload"]["future_rows_withheld"])

    def test_sensitive_title_refused_without_echo(self):
        row = self.read(raw=NEWS.replace(b"CPI", b"password=hidden-value"))
        self.assertEqual("MALFORMED", row["state"])
        self.assertNotIn("hidden-value", json.dumps(row))

    def test_future_events_are_calendar_not_future_observation(self):
        row = self.read(raw=NEWS.replace(b"2026.09.12", b"2026.09.13"))
        self.assertEqual("HISTORICAL", row["source"]["freshness"])
        self.assertEqual(1, row["payload"]["event_count"])

    def test_actions_remain_separate_unknown(self):
        row = self.read()
        self.assertEqual(8, len(row["action_effectiveness"]))
        self.assertEqual({"UNKNOWN"}, set(row["action_effectiveness"].values()))

    def test_real_canonical_sources(self):
        result = f.build_guard_projection(ROOT, SHA, NOW)
        self.assertEqual(3, len(result["observations"]))
        self.assertEqual({"PINNED_SOURCE"}, {o["producer_binding"] for o in result["observations"]})
        self.assertEqual({"UNKNOWN"}, {o["state"] for o in result["observations"]})


if __name__ == "__main__": unittest.main()
