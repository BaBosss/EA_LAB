from __future__ import annotations

import csv
import json
import tempfile
import unittest
from collections import Counter
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest import mock

from tools.news_macro_lab import macrogate_native as native
from tools.news_macro_lab import macro_placebo as p


REPO = Path(__file__).resolve().parents[3]
PREREG = REPO / "tools/news_macro_lab/macrogate_ab_prereg_v1_20260925.json"


class Fixture:
    fields = (
        "valid_from_utc", "valid_to_utc", "macro_state", "macro_as_of_utc",
        "macro_source_date", "macro_ri", "macro_confidence", "macro_coverage",
        "macro_missing_inputs", "macro_partial", "macro_flags",
    )

    def __init__(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.timeline = self.root / "timeline.csv"
        self.manifest = self.root / "manifest.json"
        self.rows = []
        states = ("NEUTRAL", "RISK_OFF", "STRESS", "RISK_ON")
        current = datetime(2020, 1, 1, tzinfo=timezone.utc)
        end = datetime(2026, 1, 1, tzinfo=timezone.utc)
        index = 0
        while current < end:
            following = current + timedelta(days=1)
            state = states[index % len(states)]
            self.rows.append({
                "valid_from_utc": current.strftime("%Y-%m-%dT%H:%M:%SZ"),
                "valid_to_utc": following.strftime("%Y-%m-%dT%H:%M:%SZ"),
                "macro_state": state,
                "macro_as_of_utc": current.strftime("%Y-%m-%dT%H:%M:%SZ"),
                "macro_source_date": (current.date() - timedelta(days=1)).isoformat(),
                "macro_ri": f"{(index % 19 - 9) / 10:.3f}",
                "macro_confidence": ("HIGH", "MED", "LOW")[index % 3],
                "macro_coverage": "8/8",
                "macro_missing_inputs": "",
                "macro_partial": "false",
                "macro_flags": f"FLAG_{index % 5}",
            })
            current = following
            index += 1
        self.write()

    def write(self):
        with self.timeline.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=self.fields, lineterminator="\n")
            writer.writeheader()
            writer.writerows(self.rows)
        timeline_sha = p.sha256_file(self.timeline)
        data = {
            "schema_version": "ea_lab_macrogate_causal_replay_extract/1",
            "classification": "CAUSAL_MACRO_REPLAY_RESEARCH_ONLY",
            "timeline_sha256": timeline_sha,
            "macro_interval_count": len(self.rows),
            "first_timestamp": self.rows[0]["valid_from_utc"],
            "last_timestamp": self.rows[-1]["valid_to_utc"],
            "can_execute": False,
            "performance": "NOT_RUN",
            "probability": None,
        }
        self.manifest.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        self.timeline_sha = timeline_sha
        self.manifest_sha = p.sha256_file(self.manifest)

    def build(self):
        with (
            mock.patch.object(p, "EXPECTED_CAUSAL_TIMELINE_SHA", self.timeline_sha),
            mock.patch.object(p, "EXPECTED_CAUSAL_MANIFEST_SHA", self.manifest_sha),
            mock.patch.object(native, "EXPECTED_CAUSAL_TIMELINE_SHA", self.timeline_sha),
            mock.patch.object(native, "EXPECTED_CAUSAL_MANIFEST_SHA", self.manifest_sha),
        ):
            return p.build_placebo_package(self.timeline, self.manifest, PREREG, REPO)

    def close(self):
        self.tmp.cleanup()


class MacroPlaceboTests(unittest.TestCase):
    def setUp(self):
        self.fx = Fixture()

    def tearDown(self):
        self.fx.close()

    def test_exact_seed_mapping_is_deterministic_unique_and_nonidentity(self):
        expected = {
            2026092501: 38,
            2026092502: -23,
            2026092503: -8,
            2026092504: -32,
            2026092505: 36,
        }
        first = p.select_seed_shifts(p.FROZEN_SEEDS, p.CANDIDATE_SHIFTS, (156, 157))
        second = p.select_seed_shifts(p.FROZEN_SEEDS, p.CANDIDATE_SHIFTS, (156, 157))
        self.assertEqual(first, expected)
        self.assertEqual(second, expected)
        self.assertEqual(len(set(first.values())), 5)
        self.assertTrue(all(shift % size for shift in first.values() for size in (156, 157)))

    def test_both_windows_have_full_bijective_weekday_preserving_coverage(self):
        package = self.fx.build()
        for window in ("MAIN", "BWD"):
            self.assertEqual(package["windows"][window]["source_row_count"], 1096)
            for cell in package["cells"]:
                if cell["window"] != window:
                    continue
                rows = cell["provenance_rows"]
                self.assertEqual(len(rows), 1096)
                self.assertEqual(len({row["target_index"] for row in rows}), 1096)
                self.assertEqual(len({row["donor_index"] for row in rows}), 1096)
                self.assertEqual(sum(row["weekday_mismatch"] for row in rows), 0)
                self.assertEqual(sum(row["cross_window"] for row in rows), 0)
                self.assertEqual(sum(row["holdout_contact"] for row in rows), 0)

    def test_marginal_donor_state_counts_are_preserved_for_every_cell(self):
        package = self.fx.build()
        for cell in package["cells"]:
            source_counts = package["windows"][cell["window"]]["source_state_counts"]
            donor_counts = Counter(row["donor_macro_state"] for row in cell["provenance_rows"])
            self.assertEqual(dict(sorted(donor_counts.items())), source_counts)
            self.assertTrue(cell["marginal_donor_state_counts_preserved"])

    def test_seams_and_nonclaims_are_explicit(self):
        package = self.fx.build()
        for cell in package["cells"]:
            self.assertGreater(cell["wrap_seam_target_count"], 0)
            self.assertFalse(cell["uniform_calendar_shift_claimed"])
            self.assertFalse(cell["exact_run_length_preservation_at_seams_claimed"])
            self.assertTrue(all(item["displacement_weeks_counts"] for item in cell["weekday_strata"]))

    def test_native_times_are_strict_and_transition_targets_are_unknown(self):
        package = self.fx.build()
        main = next(c for c in package["cells"] if c["window"] == "MAIN" and c["seed"] == 2026092501)
        times = [datetime.strptime(row["datetime"], "%Y.%m.%d %H:%M") for row in main["native_rows"]]
        self.assertEqual(times, sorted(set(times)))
        transition = next(
            row for row in main["provenance_rows"]
            if row["target_valid_from_utc"] == "2024-11-03T00:00:00Z"
        )
        self.assertEqual(transition["target_native_datetime"], "2024.11.03 00:00")
        self.assertEqual(transition["target_native_state"], "UNKNOWN")
        self.assertEqual(transition["target_representation"], "TRANSITION_UNKNOWN_BOUNDARY_MARKER")
        resume = next(row for row in main["native_rows"] if row["source_utc"] == "2024-11-04T00:00:00Z")
        self.assertEqual(resume["datetime"], "2024.11.04 02:00")

    def test_provenance_preserves_donor_identity_values_and_synthetic_boundary(self):
        package = self.fx.build()
        row = package["cells"][0]["provenance_rows"][0]
        self.assertEqual(row["classification"], "SYNTHETIC_PLACEBO_ONLY")
        self.assertFalse(row["causal_state_qualified"])
        self.assertEqual(row["donor_availability_semantics"], "PROVENANCE_ONLY_NOT_CAUSAL_TRUTH")
        self.assertIn("donor_valid_from_utc", row)
        self.assertIn("donor_macro_as_of_utc", row)
        self.assertIn("donor_macro_ri", row)
        self.assertIn("donor_macro_flags", row)
        self.assertNotEqual(row["target_valid_from_utc"], row["donor_valid_from_utc"])

    def test_authority_fields_remain_pre_outcome(self):
        package = self.fx.build()
        self.assertFalse(package["can_execute"])
        self.assertEqual(package["performance"], "NOT_RUN")
        self.assertFalse(package["holdout_used"])
        self.assertIsNone(package["probability"])
        self.assertFalse(package["selection_performed"])
        self.assertTrue(package["all_seeds_retained"])

    def test_malformed_duplicate_gap_and_overlap_inputs_fail_closed(self):
        mutations = {
            "MALFORMED": lambda rows: rows[0].__setitem__("macro_state", "BROKEN"),
            "DUPLICATE": lambda rows: rows.insert(1, dict(rows[0])),
            "GAP": lambda rows: rows[1].__setitem__("valid_from_utc", "2020-01-02T00:01:00Z"),
            "OVERLAP": lambda rows: rows[1].__setitem__("valid_from_utc", "2020-01-01T23:59:00Z"),
        }
        for label, mutate in mutations.items():
            with self.subTest(label=label):
                original = [dict(row) for row in self.fx.rows]
                mutate(self.fx.rows)
                self.fx.write()
                with self.assertRaises((p.Refused, native.Refused)):
                    self.fx.build()
                self.fx.rows = original
                self.fx.write()

    def test_source_and_exporter_drift_fail_closed(self):
        self.fx.timeline.write_text(
            self.fx.timeline.read_text(encoding="utf-8") + "\n", encoding="utf-8"
        )
        with self.assertRaisesRegex((p.Refused, native.Refused), "CAUSAL_TIMELINE_HASH_MISMATCH"):
            self.fx.build()
        self.fx.write()
        with mock.patch.object(p, "EXPECTED_NATIVE_EXPORTER_SHA", "0" * 64):
            with self.assertRaisesRegex(p.Refused, "NATIVE_EXPORTER_HASH_MISMATCH"):
                self.fx.build()

    def test_machine_prereg_drift_fails_closed(self):
        bad = self.fx.root / "bad-prereg.json"
        data = json.loads(PREREG.read_text(encoding="utf-8"))
        data["placebo"]["seed_shift_weeks"]["2026092501"] = 37
        bad.write_text(json.dumps(data) + "\n", encoding="utf-8")
        with (
            mock.patch.object(p, "EXPECTED_CAUSAL_TIMELINE_SHA", self.fx.timeline_sha),
            mock.patch.object(p, "EXPECTED_CAUSAL_MANIFEST_SHA", self.fx.manifest_sha),
            mock.patch.object(native, "EXPECTED_CAUSAL_TIMELINE_SHA", self.fx.timeline_sha),
            mock.patch.object(native, "EXPECTED_CAUSAL_MANIFEST_SHA", self.fx.manifest_sha),
        ):
            with self.assertRaisesRegex(p.Refused, "PREREG_HASH_MISMATCH"):
                p.build_placebo_package(self.fx.timeline, self.fx.manifest, bad, REPO)

    def test_artifacts_are_byte_deterministic_and_source_bound(self):
        package = self.fx.build()
        first = p.write_artifacts(package, self.fx.root / "first", REPO, PREREG)
        second = p.write_artifacts(package, self.fx.root / "second", REPO, PREREG)
        self.assertEqual(first["files"], second["files"])
        self.assertEqual(first["manifest_sha256"], second["manifest_sha256"])
        self.assertEqual(len(first["files"]), 21)
        manifest = json.loads(Path(first["manifest"]).read_text(encoding="utf-8"))
        self.assertEqual(manifest["source_timeline_sha256"], self.fx.timeline_sha)
        self.assertEqual(manifest["native_exporter_sha256"], p.EXPECTED_NATIVE_EXPORTER_SHA)
        self.assertEqual(len(manifest["cells"]), 10)
        self.assertTrue(all(cell["native_csv_sha256"] for cell in manifest["cells"]))
        self.assertTrue(all(cell["provenance_csv_sha256"] for cell in manifest["cells"]))


if __name__ == "__main__":
    unittest.main()
