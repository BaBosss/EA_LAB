from __future__ import annotations

import hashlib
import pathlib
import re
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT))

from _triage.factory_vnext.architecture import (
    make_component,
    make_master_mold,
    make_position_group,
    make_strategy_family,
    make_strategy_variant,
    variant_context,
)
from _triage.factory_vnext.contracts import make_home_contract, make_parameter_set, make_run_manifest, make_window_contract
from _triage.factory_vnext.derived_metrics import derive_metric_bundle
from _triage.factory_vnext.grade_confidence import build_grade_evidence
from _triage.factory_vnext.report import ReportError, build_report, validate_report_record
from _triage.factory_vnext.telemetry import make_event


class FactoryVNextReportTests(unittest.TestCase):
    def setUp(self) -> None:
        master = make_master_mold("MOLD1", "1", ["CAP_ENTRY", "CAP_RECOVERY", "CAP_HEDGE", "CAP_FILTER"])
        family = make_strategy_family(master, "B11", "Boss11", ["CAP_ENTRY", "CAP_RECOVERY", "CAP_HEDGE"], "11")
        groups = [
            make_position_group("PG_MAIN", "MAIN"),
            make_position_group("PG_REVERSAL", "REVERSAL"),
            make_position_group("PG_HEDGE", "HEDGE", "PG_MAIN"),
        ]
        components = [
            make_component("CMP_MAIN", "ENTRY", "PG_MAIN", capabilities=["CAP_ENTRY"]),
            make_component("CMP_REV", "REVERSAL", "PG_REVERSAL", capabilities=["CAP_ENTRY"]),
            make_component("CMP_REC_REV", "RECOVERY", "PG_REVERSAL", capabilities=["CAP_RECOVERY"], recovery_scope_position_group_id="PG_REVERSAL"),
            make_component("CMP_HEDGE", "HEDGE", "PG_HEDGE", capabilities=["CAP_HEDGE"], parent_position_group_id="PG_MAIN"),
        ]
        self.variant = make_strategy_variant(family, "B11-V01", "1.0", groups, components)
        self.context = variant_context(master, family, self.variant)
        self.home = make_home_contract("B11-V01", "1.0", "BTCUSD", "H4", self.context)
        self.window = make_window_contract("DISCOVERY", "2026-01-01", "2026-02-01", "H4", bars=100)
        self.params = make_parameter_set({"AtrPeriod": 14, "Mult": 2.5}, "PROFILE-STF")
        self.run = make_run_manifest(
            source_commit="a" * 40,
            home=self.home,
            window=self.window,
            profile_id="PROFILE-STF",
            parameter_set=self.params,
            physical_symbol="BTCUSDm",
            broker_data="fixture",
            tester_model="fixture-model",
            runtime_seconds=1.0,
            bars=100,
        )

    def _trade_event(self, **overrides):
        kwargs = dict(
            run_id=self.run["RunID"],
            variant=self.variant,
            event_family="TRADE_EVENTS",
            evidence_label="MEASURED",
            scope="COMPONENT",
            component_id="CMP_MAIN",
            position_group_id="PG_MAIN",
            intent_id="INTENT-ENTRY-1",
            sequence=1,
            payload={"mfe": 12.5, "mae": -3.0, "holding_seconds": 120.0, "giveback": 1.25, "exit_reason": "TP"},
        )
        kwargs.update(overrides)
        return make_event(**kwargs)

    def _identity(self, variant_id: str | None = None):
        return {
            "Strategy": self.variant["VariantID"],
            "HomeContractID": self.home["HomeContractID"],
            "LogicalSymbol": self.home["LogicalSymbol"],
            "PhysicalSymbol": self.run["PhysicalSymbol"],
            "ExecutionTF": self.home["ExecutionTF"],
            "ProfileID": self.run["ProfileID"],
            "BrokerData": self.run["BrokerDataEnvironment"],
            "WindowContractID": self.window["WindowContractID"],
            "ParameterSetID": self.params["ParameterSetID"],
            "RunID": self.run["RunID"],
            "VariantID": variant_id or self.variant["VariantID"],
        }

    def _report(self, *, outside: bool = False):
        e1 = self._trade_event(sequence=1)
        bundle = derive_metric_bundle([e1])
        grade = build_grade_evidence(bundle, home_status="OUTSIDE_VALIDATED_CONTRACT" if outside else "INSIDE_VALIDATED_CONTRACT")
        return build_report(self._identity(), bundle, grade)

    def test_report_is_deterministic_and_id_binds_hash(self):
        r1 = self._report()
        r2 = self._report()
        self.assertEqual(r1["ReportID"], r2["ReportID"])
        self.assertEqual(r1["html_sha256"], r2["html_sha256"])
        self.assertEqual(hashlib.sha256(r1["html"].encode("utf-8")).hexdigest(), r1["html_sha256"])
        validate_report_record(r1)

    def test_identity_mismatch_refused(self):
        e1 = self._trade_event(sequence=1)
        bundle = derive_metric_bundle([e1])
        grade = build_grade_evidence(bundle, home_status="INSIDE_VALIDATED_CONTRACT")
        bad = self._identity()
        bad["RunID"] = "RUN-OTHER"
        with self.assertRaisesRegex(ReportError, "RunID mismatch"):
            build_report(bad, bundle, grade)

    def test_missing_identity_refused(self):
        e1 = self._trade_event(sequence=1)
        bundle = derive_metric_bundle([e1])
        grade = build_grade_evidence(bundle, home_status="INSIDE_VALIDATED_CONTRACT")
        bad = self._identity()
        del bad["BrokerData"]
        with self.assertRaisesRegex(ReportError, "BrokerData is required"):
            build_report(bad, bundle, grade)

    def test_exact_five_pages_and_repeated_identity(self):
        report = self._report()
        self.assertEqual(report["page_ids"], ["overview", "trade-diagnostic", "optimization", "risk-recovery-hedge", "context-regime-broker"])
        self.assertEqual(report["html"].count('class="page"'), 5)
        for field in ("Strategy", "HomeContractID", "LogicalSymbol", "PhysicalSymbol", "ExecutionTF", "ProfileID", "BrokerData", "WindowContractID", "ParameterSetID", "RunID", "VariantID"):
            self.assertGreaterEqual(report["html"].count(field), 5 if field != "VariantID" else 5)

    def test_html_escaping_and_no_external_assets(self):
        e1 = self._trade_event(sequence=1)
        bundle = derive_metric_bundle([e1])
        grade = build_grade_evidence(bundle, home_status="INSIDE_VALIDATED_CONTRACT")
        identity = self._identity()
        identity["Strategy"] = '<script>alert("x")</script>'
        report = build_report(identity, bundle, grade)
        self.assertNotIn("<script", report["html"].lower())
        self.assertNotIn("http://", report["html"].lower())
        self.assertNotIn("https://", report["html"].lower())
        self.assertNotIn("cdn", report["html"].lower())

    def test_metric_value_status_and_actions_visible(self):
        report = self._report()
        self.assertIn("Status:", report["html"])
        self.assertIn("WHY", report["html"])
        self.assertIn("ACTION", report["html"])
        self.assertIn("evidence:", report["html"])
        self.assertIn("metric-card", report["html"])

    def test_empty_page_visible_and_outside_contract_neutral(self):
        report = self._report(outside=True)
        self.assertIn("OUTSIDE_VALIDATED_CONTRACT", report["html"])
        self.assertIn("does not inherit PASS or Grade", report["html"])
        self.assertIn("UNAVAILABLE / UNTESTED", report["html"])
        self.assertIn("Risk / Recovery / Hedge", report["html"])

    def test_report_id_changes_with_metric_and_grade_content(self):
        e1 = self._trade_event(sequence=1)
        b1 = derive_metric_bundle([e1])
        g1 = build_grade_evidence(b1, home_status="INSIDE_VALIDATED_CONTRACT")
        r1 = build_report(self._identity(), b1, g1)

        e2 = self._trade_event(sequence=1, payload={"mfe": 13.5, "mae": -3.0, "holding_seconds": 120.0, "giveback": 1.25, "exit_reason": "TP"})
        b2 = derive_metric_bundle([e2])
        g2 = build_grade_evidence(b2, home_status="INSIDE_VALIDATED_CONTRACT")
        r2 = build_report(self._identity(), b2, g2)
        self.assertNotEqual(r1["ReportID"], r2["ReportID"])

    def test_validate_record_rejects_hash_tamper(self):
        report = self._report()
        tampered = dict(report)
        tampered["html"] = report["html"] + "<!--x-->"
        with self.assertRaisesRegex(ReportError, "html_sha256 does not match html"):
            validate_report_record(tampered)


if __name__ == "__main__":
    unittest.main(verbosity=2)
