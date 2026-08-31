import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "mobile_report_hub"))
import build_index


SHA = "b7ac57ce5e1a74dc7d8a0ed5717c4853786fd4fa"
FIXED_TIME = "2026-08-30T00:00:00Z"


class MobileReportHubDataTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.out = Path(self.temp.name) / "out"

    def tearDown(self):
        self.temp.cleanup()

    def build(self):
        return build_index.build(ROOT, SHA, self.out, FIXED_TIME, SHA, None)

    def by_id(self, index, identity):
        return next(item for item in index["eas"] if item["id"] == identity)

    def test_exact_ref_repeatable_b16_h03_and_safe_artifacts(self):
        first = self.build()
        one = (self.out / "report_index.json").read_bytes()
        second_out = Path(self.temp.name) / "out2"
        build_index.build(ROOT, SHA, second_out, FIXED_TIME, SHA, None)
        self.assertEqual(one, (second_out / "report_index.json").read_bytes())
        self.assertEqual(first["project"]["canonical_sha"], SHA)
        b16 = self.by_id(first, "b16-h03-xauusd-h4")
        self.assertEqual(b16["verdict"], "POSITION_ENGINE_DEPENDENT_OR_UNKNOWN")
        self.assertEqual(b16["evidence"]["main"], {"pf": "4.08", "dd_pct": "6.27%", "trades": "79", "cycles": "42"})
        self.assertEqual(b16["evidence"]["bwd"], {"pf": "1.44", "dd_pct": "8.29%", "trades": "148", "cycles": "70"})
        self.assertIn("79.80%", b16["evidence"]["key_findings"][0])
        self.assertIn("H04 is NOT unlocked.", b16["evidence"]["key_findings"])
        self.assertTrue((self.out / b16["links"]["full_report"]).is_file())
        self.assertEqual(len(b16["provenance"][0]["sha256"]), 64)

    def test_boss19_is_environment_blocker_not_strategy_failure(self):
        boss19 = self.by_id(self.build(), "boss19-regime-attribution")
        self.assertEqual(boss19["verdict"], "BLOCKED(C DATA / environment prerequisite)")
        self.assertEqual(boss19["research_state"], "BLOCKED")
        self.assertIn("not a strategy finding", boss19["evidence"]["known_weaknesses"][0])
        self.assertEqual(boss19["evidence"]["main"]["pf"], "UNAVAILABLE")
        self.assertTrue((self.out / boss19["links"]["full_report"]).is_file())
        self.assertFalse(boss19["links"]["full_report"].startswith(("file:", "D:")))
        boss19_copy = (self.out / boss19["links"]["full_report"]).read_text(encoding="utf-8")
        self.assertIn("[LOCAL_PATH_REDACTED]", boss19_copy)
        self.assertNotRegex(boss19_copy, r"[A-Za-z]:\\")

    def test_h02_pair_is_compatible_and_unknown_not_zero(self):
        index = self.build()
        h03 = self.by_id(index, "b16-h03-xauusd-h4")
        h02_xau = self.by_id(index, "b16-h02-xauusd-h4")
        h02_jpy = self.by_id(index, "b16-h02-usdjpy-h1")
        self.assertNotEqual(h03["evidence"]["basis_id"], h02_xau["evidence"]["basis_id"])
        self.assertEqual(h02_xau["evidence"]["basis_id"], h02_jpy["evidence"]["basis_id"])
        self.assertEqual(h02_xau["evidence"]["main"]["pf"], "4.08")
        self.assertEqual(h02_jpy["evidence"]["bwd"]["dd_pct"], "2.40%")
        self.assertEqual(h02_jpy["evidence"]["main"]["cycles"], "UNKNOWN")
        self.assertNotEqual(h02_jpy["evidence"]["main"]["cycles"], "0")
        self.assertIn("basis_id is identical", index["compare"]["compatibility_rule"])

    def test_inventory_stale_and_secret_hygiene(self):
        index = self.build()
        self.assertTrue(any(x["status"] == "INVENTORY_ONLY" for x in index["eas"]))
        self.assertEqual(build_index.classify_current(index, SHA), "CURRENT")
        self.assertEqual(build_index.classify_current(index, "0" * 40), "STALE")
        blob = b"".join(path.read_bytes() for path in self.out.rglob("*") if path.is_file()).lower()
        for forbidden in (b"file:///", b"d:\\", b"463666728", b"146237", b'"password":', b'"api_key":', b'"secret":', b'"token":'):
            self.assertNotIn(forbidden, blob)

    def test_queue_source_kind_distinguishes_canonical_and_lane_registry(self):
        registry = Path(self.temp.name) / "lanes.json"
        registry.write_text(json.dumps({"lanes": [{
            "lane_id": "fixture-dynamic-lane", "state": "RUNNING", "blocker_class": "C",
            "objective": r"export exact fixture from D:\Meta 5",
            "direct_consumer": "fixture dynamic observation",
            "classification": "ACTIVE_CURRENT", "attention_required": False
        }]}), encoding="utf-8")
        index = build_index.build(ROOT, SHA, self.out, FIXED_TIME, SHA, registry)
        canonical = next(item for item in index["queue"] if item["id"] == "BOSS19-P4-REGIME-ATTRIBUTION")
        dynamic = next(item for item in index["queue"] if item["id"] == "fixture-dynamic-lane")
        self.assertEqual(canonical["source_kind"], "GIT_CANONICAL")
        self.assertEqual(dynamic["source_kind"], "LANE_REGISTRY_NONCANONICAL")
        self.assertEqual(dynamic["blocker_type"], "ENVIRONMENT")
        self.assertEqual(dynamic["summary"], "Noncanonical Lane Registry status: ACTIVE_CURRENT.")
        self.assertNotRegex(dynamic["summary"], r"[A-Za-z]:\\")

    def test_lane_summary_never_exports_registry_free_text(self):
        hostile = [r"path:D:\Meta 5", "raw alert account 463666728", "https://example.com/report", "safe consumer"]
        for text in hostile:
            summary = build_index.lane_summary({"objective":text,"direct_consumer":text,"classification":"ACTIVE_CURRENT"})
            self.assertEqual(summary, "Noncanonical Lane Registry status: ACTIVE_CURRENT.")
            self.assertNotIn(text, summary)
        self.assertEqual(build_index.lane_summary({"classification":"QUEUED_CURRENT"}), "Noncanonical Lane Registry status: QUEUED_CURRENT.")

    def test_monitor_health_projection_is_whitelisted_and_bound(self):
        monitor = Path(self.temp.name) / "monitor.json"
        payload = {
            "schema_version": "EA_LAB_MONITOR_HEALTH_V1",
            "source_kind": "LOCAL_MONITORING_NONCANONICAL",
            "authority": "READ_ONLY_NO_RUNTIME_AUTHORITY",
            "repo_head": SHA, "status": "DEGRADED",
            "generated_at_utc": "2026-08-30T00:00:00Z", "alert_present": True,
            "sources": [{"name": "live_evidence", "state": "STALE", "age_hours": 144.0,
                         "observed_at_utc": "2026-08-24T23:59:59Z",
                         "timestamp_basis": "latest_filename_date_upper_bound",
                         "account": "463666728", "path": r"D:\secret\data.csv"},
                        {"name":"control_room_snapshot","state":"STALE","age_hours":144.0,"observed_at_utc":"2026-08-24T23:59:59Z","timestamp_basis":"snapshot_meta_generated_at"},
                        {"name":"daily_monitor_success","state":"STALE","age_hours":144.0,"observed_at_utc":"2026-08-24T23:59:59Z","timestamp_basis":"success_marker_content"}],
            "coverage": {"state": "UNAVAILABLE_STALE_OR_INVALID", "deal_sensors_total": 6}
        }
        monitor.write_text(json.dumps(payload), encoding="utf-8")
        index = build_index.build(ROOT, SHA, self.out, FIXED_TIME, SHA, None, monitor)
        result = index["monitoring"]
        self.assertEqual(result["status"], "DEGRADED")
        self.assertEqual(result["binding_state"], "MATCHES_CANONICAL_SHA")
        self.assertEqual(result["sources"][0]["age_hours"], 144.0)
        self.assertEqual(result["coverage"]["deal_sensors_total"], "UNKNOWN")
        blob = json.dumps(result)
        self.assertNotIn("463666728", blob)
        self.assertNotIn(r"D:\secret", blob)

    def test_monitor_health_missing_or_invalid_is_fail_visible_not_fatal(self):
        index = self.build()
        self.assertEqual(index["monitoring"]["status"], "UNAVAILABLE")
        bad = Path(self.temp.name) / "bad-monitor.json"
        bad.write_text('{"schema_version":"WRONG","status":"CURRENT"}', encoding="utf-8")
        out = Path(self.temp.name) / "bad-out"
        index = build_index.build(ROOT, SHA, out, FIXED_TIME, SHA, None, bad)
        self.assertEqual(index["monitoring"]["status"], "UNAVAILABLE")
        self.assertEqual(index["monitoring"]["reason"], "INVALID_SCHEMA")

    def test_monitor_health_different_repo_head_is_explicit(self):
        monitor = Path(self.temp.name) / "monitor-other.json"
        payload = {"schema_version":"EA_LAB_MONITOR_HEALTH_V1",
                   "source_kind":"LOCAL_MONITORING_NONCANONICAL",
                   "authority":"READ_ONLY_NO_RUNTIME_AUTHORITY",
                   "repo_head":"0"*40,"status":"CURRENT",
                   "generated_at_utc":"2026-08-30T00:00:00Z","alert_present":False,
                   "sources":[{"name":"live_evidence","state":"CURRENT","age_hours":1,"observed_at_utc":"2026-08-30T00:00:00Z","timestamp_basis":"latest_filename_date_upper_bound"},
                              {"name":"control_room_snapshot","state":"CURRENT","age_hours":1,"observed_at_utc":"2026-08-30T00:00:00Z","timestamp_basis":"snapshot_meta_generated_at"},
                              {"name":"daily_monitor_success","state":"CURRENT","age_hours":1,"observed_at_utc":"2026-08-30T00:00:00Z","timestamp_basis":"success_marker_content"}],
                   "coverage":{"state":"UNAVAILABLE_STALE_OR_INVALID"}}
        monitor.write_text(json.dumps(payload), encoding="utf-8")
        index = build_index.build(ROOT, SHA, self.out, FIXED_TIME, SHA, None, monitor)
        self.assertEqual(index["monitoring"]["binding_state"], "DIFFERENT_REPO_HEAD")

    def test_lane_registry_audit_filters_stale_and_closed(self):
        registry = Path(self.temp.name) / "audit.json"
        records = [
            {"lane_id":"active","state":"RUNNING","classification":"ACTIVE_CURRENT","attention_required":False,"objective":"active work"},
            {"lane_id":"aged","state":"FROZEN","classification":"ACTIVE_AGED","attention_required":True,"objective":"aged work"},
            {"lane_id":"queued","state":"BLOCKED","classification":"QUEUED_CURRENT","attention_required":False,"objective":"queued work"},
            {"lane_id":"stale","state":"WAITING","classification":"STALE_NONACTIVE","attention_required":True,"objective":"stale work"},
            {"lane_id":"done","state":"DONE","classification":"CLOSED","attention_required":False,"objective":"done work"},
        ]
        registry.write_text(json.dumps({"result":"AUDIT","records":records}), encoding="utf-8")
        index = build_index.build(ROOT, SHA, self.out, FIXED_TIME, SHA, registry)
        dynamic = {item["id"]: item for item in index["queue"] if item.get("source_kind") == "LANE_REGISTRY_NONCANONICAL"}
        self.assertEqual(set(dynamic), {"active", "aged", "queued"})
        self.assertTrue(dynamic["aged"]["attention_required"])
        self.assertEqual(dynamic["aged"]["registry_classification"], "ACTIVE_AGED")

    def test_monitor_health_rejects_coercion_and_stale_coverage(self):
        monitor = Path(self.temp.name) / "monitor-adversarial.json"
        payload = {"schema_version":"EA_LAB_MONITOR_HEALTH_V1","source_kind":"LOCAL_MONITORING_NONCANONICAL",
                   "authority":"READ_ONLY_NO_RUNTIME_AUTHORITY","repo_head":SHA,"status":"CURRENT",
                   "generated_at_utc":"2026-08-30T00:00:00Z","alert_present":"false",
                   "sources":[{"name":"live_evidence","state":"CURRENT","age_hours":1,"observed_at_utc":"2026-08-30T00:00:00Z","timestamp_basis":"latest_filename_date_upper_bound"},
                              {"name":"control_room_snapshot","state":"STALE","age_hours":2,"observed_at_utc":"2026-08-30T00:00:00Z","timestamp_basis":"snapshot_meta_generated_at"},
                              {"name":"daily_monitor_success","state":"CURRENT","age_hours":1,"observed_at_utc":"2026-08-30T00:00:00Z","timestamp_basis":"success_marker_content"}],
                   "coverage":{"state":"AVAILABLE_CURRENT_SNAPSHOT","deal_sensors_total":True,"deal_sensors_fresh":1,"floating_sensors_total":2,"floating_sensors_fresh":1}}
        monitor.write_text(json.dumps(payload), encoding="utf-8")
        result = build_index.build(ROOT, SHA, self.out, FIXED_TIME, SHA, None, monitor)["monitoring"]
        self.assertEqual(result["status"], "DEGRADED")
        self.assertEqual(result["alert_present"], "UNKNOWN")
        self.assertEqual(result["coverage"]["state"], "UNAVAILABLE_STALE_OR_INVALID")
        self.assertEqual(result["coverage"]["deal_sensors_total"], "UNKNOWN")

    def test_monitor_health_rejects_duplicate_or_unknown_sources(self):
        monitor = Path(self.temp.name) / "monitor-source-set.json"
        valid = [{"name":"live_evidence","state":"CURRENT","age_hours":1,"observed_at_utc":"2026-08-30T00:00:00Z","timestamp_basis":"latest_filename_date_upper_bound"},
                 {"name":"control_room_snapshot","state":"CURRENT","age_hours":1,"observed_at_utc":"2026-08-30T00:00:00Z","timestamp_basis":"snapshot_meta_generated_at"},
                 {"name":"daily_monitor_success","state":"CURRENT","age_hours":1,"observed_at_utc":"2026-08-30T00:00:00Z","timestamp_basis":"success_marker_content"}]
        base={"schema_version":"EA_LAB_MONITOR_HEALTH_V1","source_kind":"LOCAL_MONITORING_NONCANONICAL","authority":"READ_ONLY_NO_RUNTIME_AUTHORITY","repo_head":SHA,"status":"CURRENT","generated_at_utc":"2026-08-30T00:00:00Z","alert_present":False,"coverage":{"state":"UNAVAILABLE_STALE_OR_INVALID"}}
        for sources in (valid+[dict(valid[0])], [valid[0],valid[1],dict(valid[1])], valid[:2]+[{"name":"unknown_source","state":"CURRENT","age_hours":1,"observed_at_utc":"2026-08-30T00:00:00Z","timestamp_basis":"success_marker_content"}]):
            payload=dict(base); payload["sources"]=sources; monitor.write_text(json.dumps(payload),encoding="utf-8")
            result=build_index.build(ROOT,SHA,Path(self.temp.name)/("srcset"+str(len(sources))),FIXED_TIME,SHA,None,monitor)["monitoring"]
            self.assertEqual(result["status"],"UNAVAILABLE"); self.assertEqual(result["reason"],"INVALID_SOURCE_SET")

    def test_lane_registry_hostile_free_text_and_account_like_id_are_redacted(self):
        registry=Path(self.temp.name)/"hostile-audit.json"
        records=[{"lane_id":"account-463666728","state":"RUNNING","classification":"ACTIVE_CURRENT","attention_required":False,"objective":"ALERT account 463666728 at D:\\Meta 5 raw prose","direct_consumer":"secret alert body"}]
        registry.write_text(json.dumps({"result":"AUDIT","records":records}),encoding="utf-8")
        index=build_index.build(ROOT,SHA,Path(self.temp.name)/"hostile-out",FIXED_TIME,SHA,registry)
        blob=json.dumps(index["queue"]); self.assertNotIn("463666728",blob); self.assertNotIn("secret alert body",blob); self.assertNotIn("raw prose",blob); self.assertNotIn(r"D:\Meta 5",blob)
        dynamic=[x for x in index["queue"] if x.get("source_kind")=="LANE_REGISTRY_NONCANONICAL"][0]
        self.assertRegex(dynamic["id"],r"^REDACTED_LANE_[0-9a-f]{8}$"); self.assertEqual(dynamic["summary"],"Noncanonical Lane Registry status: ACTIVE_CURRENT.")

    def test_expected_sha_mismatch_and_missing_source_fail_closed(self):
        with self.assertRaisesRegex(build_index.BuildError, "expected SHA mismatch"):
            build_index.build(ROOT, SHA, self.out, FIXED_TIME, "0" * 40, None)
        with self.assertRaises(build_index.BuildError):
            build_index.text_source(ROOT, SHA, "docs/factory/NOT_PRESENT.md")


if __name__ == "__main__":
    unittest.main(verbosity=2)
