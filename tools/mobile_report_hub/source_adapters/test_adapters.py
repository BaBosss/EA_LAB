"""Production-reader and CLI fixtures. No runtime, network or source mutations."""
from __future__ import annotations
import contextlib
import copy
import csv
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import patch

from . import BuildRequest, build_observations
from .__main__ import main
from .coverage import deployment_coverage, guard_observations, read_control
from .builder import PARSER_CONTRACTS
from .readers import (DEAL_FIELDS, MT4_ORDER_FIELDS, SNAP_FIELDS, Metadata,
                      read_ledgers, read_mt4_orders, read_snapshots)
from .safe import Limits, Refused, Sources, checked_path, decimal, digest, opaque, utc_time

REPO = Path(__file__).resolve().parents[3]
RUN = REPO / "build/ea_observation_adapters_v1/continuation-20260924"
BASE = "1df924b1ac7e112148dd8a70773c8c63b0b9a893"
START_BASE = "3d6941ab0f0edbacffbb60022cd84113d6a288b6"
LOGIN = "731245689"
TICKET = "918273645"
NOW = "2026-09-24T06:30:00Z"
BROKER_COORDINATE = str(int((datetime(2026, 9, 20, 9) - datetime(1970, 1, 1)).total_seconds()))


def csv_bytes(fields, rows):
    stream = io.StringIO(newline="")
    writer = csv.DictWriter(stream, fieldnames=sorted(fields), lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
    return stream.getvalue().encode()


def deal(**changes):
    value = dict(ticket=TICKET, time="2026.09.20 09:00:00", symbol="EURUSD", magic="41", type="0", entry="1",
                 volume="0.10", price="1.12000", profit="0.10", swap="-0.01", commission="-0.02", comment="private fixture")
    return value | changes


def mt4_order(**changes):
    value = dict(ticket=TICKET, open_time="2026.09.20 08:00:00", close_time="2026.09.20 09:00:00",
                 symbol="EURUSD", magic="0", type="0", lots="0.10", open_price="1.12000",
                 close_price="1.12100", profit="10.00", swap="-0.01", commission="-0.02",
                 comment="private fixture")
    return value | changes


def snapshot(when="2026.09.20 09:00:00", **changes):
    value = dict.fromkeys(SNAP_FIELDS, "")
    value.update(row_type="ACCOUNT", login=LOGIN, server_time=when, currency="USD", equity="0.00", balance="0.00",
                 margin="0.00", free_margin="0.00", margin_level_pct="0.0", stopout_mode="PERCENT", stopout_level="50.0")
    return value | changes


def magic_row(**changes):
    value = dict.fromkeys(SNAP_FIELDS, "")
    value.update(row_type="MAGIC", login=LOGIN, server_time="2026.09.20 09:00:00", magic="41", symbols="EURUSD",
                 float_pl="0.00", open_lots="0.00", open_positions="0", oldest_open_hours="0.0", pending_orders="0")
    return value | changes


def metadata():
    return Metadata([dict(account=LOGIN, platform="MT5", currency="USD")],
                    [dict(account=LOGIN, magic="41", symbol="EURUSD", status="ACTIVE")],
                    [dict(account=LOGIN, magic="41", symbol="EURUSD", attach_epoch="epoch-2", ea_logical_identity="fixture",
                          build_receipt="br-" + "a" * 32, config_fingerprint="b" * 64, config_fingerprint_version="cfgfp-v1",
                          timeframe="H1", source_sha256="c" * 64, artifact_sha256="d" * 64)], ["source-" + "e" * 64])


class Fixture(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=RUN, prefix="fixture-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.meta = metadata()
        self.sources = Sources()

    def ledger(self, rows, date="20260920", fields=None):
        path = self.root / f"EA_LAB_deals_{LOGIN}_{date}.csv"
        path.write_bytes(csv_bytes(fields or DEAL_FIELDS, rows))
        return path

    def snap(self, rows, date="20260920"):
        path = self.root / f"EA_LAB_snapshot_{LOGIN}_{date}.csv"
        path.write_bytes(csv_bytes(SNAP_FIELDS, rows))
        return path

    def ledgers(self):
        return read_ledgers(self.sources, self.root, self.meta)["accounts"][0]

    def snapshots(self):
        return read_snapshots(self.sources, self.root, self.meta)["accounts"][0]

    def mt4_file(self, rows, date="20260920", fields=None, login=LOGIN):
        path = self.root / f"EA_LAB_mt4_orders_{login}_{date}.csv"
        path.write_bytes(csv_bytes(fields or MT4_ORDER_FIELDS, rows))
        return path

    def mt4_orders(self):
        return read_mt4_orders(self.sources, self.root, self.meta)

    def control(self, **changes):
        data = {"entity": "ControlRoomSnapshotV5", "meta": {"schema": "ControlRoomSnapshot", "version": 5,
                 "git_head": BASE, "generated_at": NOW}, "runtime_identity_summary": {"state": "FAIL", "records": 0}}
        data.update(changes)
        (self.root / "portfolio").mkdir(exist_ok=True)
        (self.root / "portfolio/control_room_snapshot.json").write_text(json.dumps(data), encoding="utf-8")
        return data


class LedgerTests(Fixture):
    def test_two_currencies_never_sum(self):
        self.ledger([deal()])
        self.meta.accounts["731245680"].append(dict(account="731245680", platform="MT5", currency="USC"))
        (self.root / "EA_LAB_deals_731245680_20260920.csv").write_bytes(csv_bytes(DEAL_FIELDS, [deal()]))
        result = read_ledgers(self.sources, self.root, self.meta)
        self.assertEqual({r["currency"] for r in result["accounts"]}, {"USD", "USC"})
        self.assertIsNone(result["account_totals_across_currencies"])

    def test_duplicate_header_and_malformed_row_refused(self):
        path = self.ledger([])
        for raw in (b"ticket,ticket\n1,1\n", b"ticket,time\n1\n", b""):
            path.write_bytes(raw)
            self.assertIsNone(self.ledgers()["deal_count"])

    def test_missing_is_not_zero(self):
        result = self.ledgers()
        self.assertIsNone(result["deal_count"])
        self.assertEqual(result["reason"], "LEDGER_MISSING")

    def test_valid_empty_is_zero_observed_deals_only(self):
        self.ledger([])
        self.assertEqual(self.ledgers()["deal_count"], 0)

    def test_decimal_components_include_entry_costs(self):
        self.ledger([deal(), deal(ticket="2", entry="0", profit="0.00", swap="0.00", commission="-0.03")])
        component = self.ledgers()["components"][0]
        self.assertEqual(component["reported_components_subtotal"], "0.04")
        self.assertEqual(component["deal_count"], 2)
        self.assertFalse(component["all_costs_complete"])
        self.assertIsNone(component["fee"])
        self.assertEqual(component["cycle_identifiers"], "NOT_EXPORTED")

    def test_repeat_full_history_and_optional_time_extension(self):
        self.ledger([deal()])
        self.ledger([deal(time_unix=BROKER_COORDINATE)], "20260921", DEAL_FIELDS | {"time_unix"})
        result = self.ledgers()
        self.assertEqual(result["deal_count"], 1)
        self.assertEqual(result["quarantined"], [])
        self.assertEqual(len(result["components"][0]["source_refs"]), 2)

    def test_numeric_normalization_is_dedup_safe(self):
        self.ledger([deal()])
        self.ledger([deal(profit="00.100", volume="0.1000")], "20260921")
        self.assertEqual(self.ledgers()["deal_count"], 1)

    def test_conflicting_ticket_is_quarantined_not_first_or_newest(self):
        self.ledger([deal()])
        self.ledger([deal(profit="999.00")], "20260921")
        result = self.ledgers()
        self.assertEqual(result["deal_count"], 0)
        self.assertEqual(result["components"], [])
        self.assertEqual(result["quarantined"][0]["reasons"], ["SHARED_FIELD_CONFLICT"])

    def test_known_epoch_conflict_quarantines(self):
        fields = DEAL_FIELDS | {"time_unix"}
        self.ledger([deal(time_unix=BROKER_COORDINATE)], fields=fields)
        self.ledger([deal(time_unix="11")], "20260921", fields)
        self.assertIn("BROKER_TIME_FIELDS_CONFLICT", self.ledgers()["quarantined"][0]["reasons"])

    def test_invalid_duplicate_poison_survives_valid_copy(self):
        self.ledger([deal(profit="NaN")])
        self.ledger([deal()], "20260921")
        self.assertEqual(self.ledgers()["deal_count"], 0)

    def test_all_nontrade_enum_rows_excluded(self):
        self.ledger([deal(ticket=str(i), type=str(i), symbol="", profit="1000") for i in range(2, 18)])
        result = self.ledgers()
        self.assertEqual(result["deal_count"], 0)
        self.assertEqual(result["non_trading_deals_excluded"], 16)

    def test_enum_validation_is_strict(self):
        for changes in ({"entry": "OUT"}, {"entry": "4"}, {"type": "18"}, {"type": "BUY"}, {"type": "True"}):
            with self.subTest(changes=changes):
                self.ledger([deal(**changes)])
                self.assertEqual(self.ledgers()["deal_count"], 0)

    def test_reversal_and_partial_closes_remain_events(self):
        self.ledger([deal(ticket=str(i + 1), entry=str(i), volume="0.01") for i in range(4)])
        self.assertEqual(self.ledgers()["deal_count"], 4)

    def test_unknown_new_fee_schema_refused(self):
        self.ledger([deal(fee="1.00")], fields=DEAL_FIELDS | {"fee"})
        self.assertIsNone(self.ledgers()["deal_count"])

    def test_unkeyed_bad_ticket_withholds_account_totals(self):
        self.ledger([deal(), deal(ticket="../../private")])
        result = self.ledgers()
        self.assertIsNone(result["deal_count"])
        self.assertIsNone(result["components"][0]["reported_components_subtotal"])

    def test_header_only_invalid_and_true_zero_distinct(self):
        self.ledger([deal(profit="0", swap="0", commission="0")])
        self.assertEqual(self.ledgers()["components"][0]["reported_components_subtotal"], "0")
        self.ledger([deal(profit="")])
        self.assertEqual(self.ledgers()["components"], [])

    def test_currency_and_account_conflicts(self):
        self.ledger([deal()])
        self.meta.accounts[LOGIN].append(dict(account=LOGIN, platform="MT5", currency="USC"))
        self.assertEqual(read_ledgers(self.sources, self.root, self.meta)["accounts"], [])
        self.assertTrue(self.sources.errors)

    def test_exact_mapping_not_runtime_attestation(self):
        self.ledger([deal()])
        item = self.ledgers()["components"][0]
        self.assertEqual(item["mapping_status"], "DECLARED_EXACT")
        self.assertFalse(item["attribution_eligible"])
        self.assertIsNotNone(item["expected_identity_pin"])

    def test_ambiguous_and_multi_symbol_mapping(self):
        self.ledger([deal()])
        self.meta.deployments.append(dict(account=LOGIN, magic="41", symbol="USDJPY", status="ACTIVE"))
        self.assertEqual(self.ledgers()["components"][0]["mapping_status"], "AMBIGUOUS")

    def test_large_decimals_accumulate_exactly(self):
        self.ledger([deal(ticket="1", profit="99999999999999999999.1234567890", swap="0", commission="0"),
                     deal(ticket="2", profit="0.0000000001", swap="0", commission="0")])
        self.assertEqual(self.ledgers()["components"][0]["reported_components_subtotal"], "99999999999999999999.1234567891")


class MT4OrderTests(Fixture):
    def setUp(self):
        super().setUp()
        self.meta.accounts[LOGIN][0]["platform"] = "MT4"

    def test_exact_producer_hash_pin_and_valid_closed_order(self):
        path = "tools/DealsExporter/OrdersExporterMT4.mq4"
        raw, _ = Sources().git_blob(REPO, START_BASE, path)
        self.assertEqual(PARSER_CONTRACTS[path], "4caee0ebe8440cb13c28c79354904d1cd992163f2864936b22ae68ca1e678593")
        self.assertEqual(digest(raw), PARSER_CONTRACTS[path])
        self.mt4_file([mt4_order()])
        result = self.mt4_orders()
        account = result["accounts"][0]
        self.assertEqual(account["closed_trade_orders"], 1)
        self.assertEqual(account["excluded_non_market_orders"], 0)
        self.assertEqual(account["clock_basis"], "BROKER_TIME_UNQUALIFIED")
        self.assertEqual(result["unit"], "MT4_CLOSED_ORDER_RECORDS_NOT_MT5_DEALS")
        self.assertIsNone(result["account_totals_across_currencies"])

    def test_non_market_excluded_and_identical_daily_history_deduped(self):
        self.mt4_file([mt4_order(), mt4_order(ticket="2", type="6", symbol=""),
                       mt4_order(ticket="3", type="-1", symbol="", magic="-7")])
        self.mt4_file([mt4_order(profit="010.000"), mt4_order(ticket="2", type="6", symbol=""),
                       mt4_order(ticket="3", type="-1", symbol="", magic="-7")], "20260921")
        account = self.mt4_orders()["accounts"][0]
        self.assertEqual(account["closed_trade_orders"], 1)
        self.assertEqual(account["excluded_non_market_orders"], 2)
        self.assertEqual(account["file_count"], 2)
        self.assertEqual(account["quarantined_count"], 0)

    def test_conflicting_repeated_ticket_is_quarantined(self):
        self.mt4_file([mt4_order()])
        self.mt4_file([mt4_order(close_price="9.99999")], "20260921")
        account = self.mt4_orders()["accounts"][0]
        self.assertEqual(account["closed_trade_orders"], 0)
        self.assertEqual(account["quarantined_count"], 1)
        self.assertEqual(account["quarantined"][0]["reasons"], ["SHARED_FIELD_CONFLICT"])
        self.assertNotIn(TICKET, json.dumps(account))

    def test_market_order_lots_must_be_positive(self):
        cases = (("0", "0"), ("1", "-0.10"))
        for order_type, lots in cases:
            with self.subTest(order_type=order_type, lots=lots):
                self.mt4_file([mt4_order(type=order_type, lots=lots)])
                self.sources = Sources()
                account = self.mt4_orders()["accounts"][0]
                self.assertEqual(account["closed_trade_orders"], 0)
                self.assertEqual(account["quarantined"][0]["reasons"],
                                 ["MT4_MARKET_LOTS_NOT_POSITIVE"])

    def test_market_order_open_price_must_be_positive(self):
        cases = (("0", "0"), ("1", "-1.12000"))
        for order_type, open_price in cases:
            with self.subTest(order_type=order_type, open_price=open_price):
                self.mt4_file([mt4_order(type=order_type, open_price=open_price)])
                self.sources = Sources()
                account = self.mt4_orders()["accounts"][0]
                self.assertEqual(account["closed_trade_orders"], 0)
                self.assertEqual(account["quarantined"][0]["reasons"],
                                 ["MT4_MARKET_OPEN_PRICE_NOT_POSITIVE"])

    def test_market_order_close_price_must_be_positive(self):
        cases = (("0", "0"), ("1", "-1.12100"))
        for order_type, close_price in cases:
            with self.subTest(order_type=order_type, close_price=close_price):
                self.mt4_file([mt4_order(type=order_type, close_price=close_price)])
                self.sources = Sources()
                account = self.mt4_orders()["accounts"][0]
                self.assertEqual(account["closed_trade_orders"], 0)
                self.assertEqual(account["quarantined"][0]["reasons"],
                                 ["MT4_MARKET_CLOSE_PRICE_NOT_POSITIVE"])

    def test_market_order_open_time_cannot_follow_close_time(self):
        self.mt4_file([mt4_order(open_time="2026.09.20 09:00:01")])
        account = self.mt4_orders()["accounts"][0]
        self.assertEqual(account["closed_trade_orders"], 0)
        self.assertEqual(account["quarantined"][0]["reasons"],
                         ["MT4_MARKET_TIME_ORDER_INVALID"])

    def test_market_order_equal_open_and_close_time_is_accepted(self):
        self.mt4_file([mt4_order(open_time="2026.09.20 09:00:00")])
        account = self.mt4_orders()["accounts"][0]
        self.assertEqual(account["closed_trade_orders"], 1)
        self.assertEqual(account["quarantined"], [])

    def test_impossible_duplicate_poison_is_order_independent(self):
        orders = (
            (mt4_order(), mt4_order(lots="0")),
            (mt4_order(lots="0"), mt4_order()),
        )
        for first, second in orders:
            with self.subTest(first_lots=first["lots"]):
                first_path = self.mt4_file([first])
                second_path = self.mt4_file([second], "20260921")
                self.sources = Sources()
                account = self.mt4_orders()["accounts"][0]
                self.assertEqual(account["closed_trade_orders"], 0)
                self.assertEqual(account["quarantined"][0]["reasons"],
                                 ["MT4_MARKET_LOTS_NOT_POSITIVE"])
                first_path.unlink()
                second_path.unlink()

    def test_non_market_domain_impossibilities_remain_excluded(self):
        self.mt4_file([mt4_order(type="6", lots="0", open_price="-1.12000",
                                 close_price="0", open_time="2026.09.20 10:00:00")])
        account = self.mt4_orders()["accounts"][0]
        self.assertEqual(account["closed_trade_orders"], 0)
        self.assertEqual(account["excluded_non_market_orders"], 1)
        self.assertEqual(account["quarantined"], [])

    def test_valid_header_only_observes_zero_not_lifetime_proof(self):
        self.mt4_file([])
        account = self.mt4_orders()["accounts"][0]
        self.assertEqual(account["availability"], "PARTIAL")
        self.assertEqual(account["closed_trade_orders"], 0)
        self.assertEqual(account["excluded_non_market_orders"], 0)
        self.assertEqual(account["history_completeness"], "EXPORT_WINDOW_NOT_LIFETIME_PROOF")
        self.assertIsNone(account["window_first_close"])

    def test_malformed_filename_or_date_withholds_current_account(self):
        for suffix in ("20260931", "bad-date", "2026093", "00000000"):
            with self.subTest(suffix=suffix):
                path = self.root / f"EA_LAB_mt4_orders_{LOGIN}_{suffix}.csv"
                path.write_bytes(csv_bytes(MT4_ORDER_FIELDS, [mt4_order()]))
                self.sources = Sources()
                account = self.mt4_orders()["accounts"][0]
                self.assertEqual(account["availability"], "UNAVAILABLE")
                self.assertIsNone(account["closed_trade_orders"])
                self.assertIn("SOURCE_FILENAME_INVALID", {e["code"] for e in self.sources.errors})
                path.unlink()

    def test_metadata_missing_ambiguous_and_non_mt4_fail_closed(self):
        self.mt4_file([mt4_order()])
        cases = (
            Metadata([], [], [], []),
            Metadata([dict(account=LOGIN, platform="MT4"), dict(account=LOGIN, platform="MT4")], [], [], []),
            Metadata([dict(account=LOGIN, platform="MT5")], [], [], []),
        )
        expected = ("ACCOUNT_METADATA_MISSING_OR_AMBIGUOUS", "ACCOUNT_METADATA_MISSING_OR_AMBIGUOUS",
                    "ACCOUNT_PLATFORM_NOT_MT4")
        for meta, code in zip(cases, expected):
            with self.subTest(code=code):
                sources = Sources()
                result = read_mt4_orders(sources, self.root, meta)
                self.assertEqual(result["accounts"], [])
                self.assertIn(code, {e["code"] for e in sources.errors})

    def test_unknown_missing_and_duplicate_columns_withhold(self):
        cases = (
            csv_bytes(MT4_ORDER_FIELDS | {"fee"}, [mt4_order(fee="1")]),
            csv_bytes(MT4_ORDER_FIELDS - {"comment"}, [{k: v for k, v in mt4_order().items() if k != "comment"}]),
            b"ticket,ticket\n1,1\n",
        )
        for raw in cases:
            with self.subTest(size=len(raw)):
                self.mt4_file([]).write_bytes(raw)
                self.sources = Sources()
                account = self.mt4_orders()["accounts"][0]
                self.assertEqual(account["availability"], "UNAVAILABLE")
                self.assertIsNone(account["closed_trade_orders"])
                self.assertIn("CSV_SCHEMA_INVALID", {e["code"] for e in self.sources.errors})

    def test_malformed_row_fields_are_quarantined_or_withhold_when_unkeyed(self):
        cases = (
            ("ticket", "0", True), ("magic", "1.0", False), ("type", "1.0", False),
            ("open_time", "2026-09-20T08:00:00", False), ("close_time", "", False),
            ("lots", "NaN", False), ("open_price", "Infinity", False),
            ("close_price", "1e2", False), ("profit", "", False),
            ("swap", "--1", False), ("commission", "1,000", False),
            ("symbol", "../EURUSD", False),
        )
        for field, value, unkeyed in cases:
            with self.subTest(field=field):
                self.mt4_file([mt4_order(**{field: value})])
                self.sources = Sources()
                account = self.mt4_orders()["accounts"][0]
                if unkeyed:
                    self.assertEqual(account["availability"], "UNAVAILABLE")
                    self.assertIsNone(account["closed_trade_orders"])
                else:
                    self.assertEqual(account["availability"], "PARTIAL")
                    self.assertEqual(account["closed_trade_orders"], 0)
                    self.assertEqual(account["quarantined_count"], 1)

    def test_newer_malformed_file_withholds_instead_of_falling_back(self):
        self.mt4_file([mt4_order()])
        fields = MT4_ORDER_FIELDS - {"close_time"}
        row = {k: v for k, v in mt4_order(ticket="2").items() if k in fields}
        self.mt4_file([row], "20260921", fields)
        account = self.mt4_orders()["accounts"][0]
        self.assertEqual(account["availability"], "UNAVAILABLE")
        self.assertIsNone(account["closed_trade_orders"])
        self.assertEqual(account["file_count"], 2)

    def test_output_has_no_money_aggregates_or_private_source_values(self):
        self.mt4_file([mt4_order(comment="private C:\\secret")])
        result = self.mt4_orders()
        payload = json.dumps(result)
        for secret in (LOGIN, TICKET, "private C:\\secret", str(self.root)):
            self.assertNotIn(secret, payload)
        def keys(value):
            if isinstance(value, dict):
                return set(value) | set().union(*(keys(v) for v in value.values()))
            if isinstance(value, list):
                return set().union(*(keys(v) for v in value)) if value else set()
            return set()
        self.assertTrue({"profit", "swap", "commission", "lots", "portfolio_money"}.isdisjoint(keys(result)))

    def test_builder_exposes_separate_partial_section_with_fixed_reasons(self):
        self.mt4_file([mt4_order()])
        with patch("tools.mobile_report_hub.source_adapters.builder.Metadata", return_value=self.meta):
            result = build_observations(BuildRequest(REPO, START_BASE, self.root, self.root, self.root, NOW)).to_dict()
        section = result["sections"]["mt4_orders"]
        self.assertEqual(section["availability"], "PARTIAL")
        self.assertEqual(section["data"]["accounts"][0]["closed_trade_orders"], 1)
        self.assertEqual(set(section["reasons"]), {
            "BROKER_TIME_UNQUALIFIED", "EXPORT_WINDOW_NOT_LIFETIME_PROOF",
            "MT4_CLOSED_ORDER_HISTORY_DISTINCT_FROM_MT5_DEALS"})
        self.assertFalse(result["integration"]["real_data_qualified"])
        self.assertIn("ledger", result["sections"])


class SnapshotTests(Fixture):
    def test_mt4_shared_snapshot_schema_without_inventing_deal_history(self):
        self.meta.accounts[LOGIN][0]["platform"] = "MT4"
        self.snap([snapshot(), magic_row()])
        account = self.snapshots()
        self.assertEqual(account["platform"], "MT4")
        self.assertEqual(account["latest"]["fields"]["equity"]["value"], "0.00")
        self.assertIsNone(self.ledgers()["deal_count"])
        self.ledger([deal()])
        self.assertIsNone(self.ledgers()["deal_count"])

    def test_wrong_row_layout_is_not_silently_ignored(self):
        self.snap([snapshot(magic="41")])
        self.assertIsNone(self.snapshots()["latest"])

    def test_broker_future_does_not_invent_utc_freshness(self):
        self.snap([snapshot("2099.09.21 09:00:00")])
        result = self.snapshots()
        self.assertEqual(result["freshness"], "UNKNOWN")
        self.assertEqual(result["clock_basis"], "BROKER_TIME_UNQUALIFIED")

    def test_missing_and_zero_are_distinct(self):
        self.snap([snapshot(equity="", balance="0")])
        fields = self.snapshots()["latest"]["fields"]
        self.assertIsNone(fields["equity"]["value"])
        self.assertEqual(fields["balance"]["value"], "0")

    def test_newest_incomplete_never_backfills(self):
        self.snap([snapshot(equity="100")])
        self.snap([snapshot("2026.09.21 09:00:00", equity="")], "20260921")
        result = self.snapshots()
        self.assertIsNone(result["latest"]["fields"]["equity"]["value"])
        self.assertEqual(result["latest_observed"], "2026-09-21T09:00:00")

    def test_sort_by_source_clock_and_explicit_gap(self):
        self.snap([snapshot("2026.09.21 09:00:00")])
        self.snap([snapshot("2026.09.20 09:00:00")], "20260921")
        result = self.snapshots()
        self.assertEqual(result["intervals"][0]["observed_elapsed_seconds"], 86400)
        self.assertEqual(result["freshness"], "UNKNOWN")
        self.assertIsNone(result["qualified_series"])
        self.assertIsNone(result["calculations"])

    def test_identical_same_time_merges_provenance(self):
        self.snap([snapshot()])
        self.snap([snapshot()], "20260921")
        result = self.snapshots()
        self.assertEqual(len(result["samples"]), 1)
        self.assertEqual(len(result["latest"]["source_refs"]), 2)

    def test_conflicting_same_time_nulls_all_values(self):
        self.snap([snapshot()])
        self.snap([snapshot(equity="1")], "20260921")
        result = self.snapshots()
        self.assertTrue(result["latest"]["conflict"])
        self.assertIsNone(result["latest"]["fields"]["equity"]["value"])
        self.assertIsNone(result["latest"]["floating"])

    def test_invalid_newest_time_does_not_fall_back(self):
        self.snap([snapshot()])
        self.snap([snapshot("bad")], "20260921")
        self.assertIsNone(self.snapshots()["latest"])

    def test_nonfinite_values_have_per_field_availability(self):
        for raw in ("NaN", "Infinity", "-Infinity", "True", "1e20", "1,000"):
            with self.subTest(raw=raw):
                self.snap([snapshot(equity=raw)])
                value = self.snapshots()["latest"]["fields"]["equity"]
                self.assertEqual(value, {"value": None, "availability": "INVALID"})

    def test_currency_conflict_is_not_merged(self):
        self.snap([snapshot(currency="USC")])
        self.assertIsNone(self.snapshots()["latest"])
        self.assertEqual(self.sources.errors[0]["code"], "ACCOUNT_CURRENCY_CONFLICT")

    def test_snapshot_currency_conflict_withholds_ledger_components(self):
        self.snap([snapshot(currency="USC")])
        self.ledger([deal()])
        self.snapshots()
        result = self.ledgers()
        self.assertIsNone(result["deal_count"])
        self.assertIsNone(result["components"][0]["reported_components_subtotal"])

    def test_snapshot_login_must_match_filename(self):
        self.snap([snapshot(login="12")])
        self.assertIsNone(self.snapshots()["latest"])

    def test_current_floating_and_missing_magic_distinct(self):
        self.snap([snapshot(), magic_row()])
        latest = self.snapshots()["latest"]
        self.assertEqual(latest["floating"][0]["fields"]["float_pl"]["value"], "0.00")
        self.snap([snapshot()])
        self.assertEqual(self.snapshots()["latest"]["floating"], [])

    def test_multi_symbol_floating_cannot_attribute(self):
        self.snap([snapshot(), magic_row(symbols="EURUSD;USDJPY")])
        self.assertEqual(self.snapshots()["latest"]["floating"][0]["mapping"]["mapping_status"], "MULTI_SYMBOL_OR_MISSING")

    def test_next_explicit_read_observes_new_file(self):
        self.snap([snapshot()])
        self.assertEqual(len(self.snapshots()["samples"]), 1)
        self.snap([snapshot("2026.09.21 09:00:00")], "20260921")
        self.assertEqual(len(self.snapshots()["samples"]), 2)


class CoverageTests(Fixture):
    def test_matching_existing_identity_is_only_descriptive(self):
        record = {**self.meta.identities[0], "account_login": LOGIN, "schema": "runtime_identity/1",
                  "first_trade_epoch": None, "evidence_timestamp": NOW, "validation_state": "PASS"}
        self.control(runtime_identity=[record], runtime_identity_summary={"state": "PASS", "records": 1})
        result = deployment_coverage(self.meta, read_control(self.sources, self.root, BASE, NOW), NOW)
        self.assertEqual(result["deployments"][0]["comparison"], "FIELDS_MATCH_ONLY")
        self.assertFalse(result["deployments"][0]["attribution_eligible"])
        self.assertIsNone(result["first_trade_or_judge_claim"])

    def test_existing_producer_failure_survives(self):
        self.control()
        control = read_control(self.sources, self.root, BASE, NOW)
        result = deployment_coverage(self.meta, control, NOW)
        self.assertEqual(result["deployments"][0]["runtime_identity"], "FAIL")
        self.assertFalse(result["deployments"][0]["attribution_eligible"])

    def test_stale_source_age_is_reported_without_invented_ttl(self):
        doc = self.control()
        doc["meta"]["generated_at"] = "2020-01-01T00:00:00Z"
        self.control(**doc)
        result = read_control(self.sources, self.root, BASE, NOW)
        self.assertGreater(result["observed_age_seconds"], 0)
        self.assertEqual(result["freshness"], "UNQUALIFIED_NO_ADAPTER_TTL")

    def test_future_source_does_not_qualify(self):
        doc = self.control()
        doc["meta"]["generated_at"] = "2027-01-01T00:00:00Z"
        self.control(**doc)
        control = read_control(self.sources, self.root, BASE, NOW)
        self.assertEqual(control["temporal_relation"], "FUTURE")
        self.assertIn("PRODUCER_TIMESTAMP_FUTURE", deployment_coverage(self.meta, control, NOW)["deployments"][0]["reasons"])

    def test_malformed_timezone_offsets_refused(self):
        for stamp in ("2026-09-24T06:30:00+24:00", "2026-09-24T06:30:00+00:99", "2026-09-24T06:30:00", "2026-02-30T00:00:00Z"):
            with self.subTest(stamp=stamp), self.assertRaises(Refused):
                utc_time(stamp)

    def test_runtime_identity_field_mismatches_remain_visible(self):
        expected = self.meta.identities[0]
        record = {**expected, "account_login": LOGIN, "schema": "runtime_identity/1", "first_trade_epoch": None,
                  "evidence_timestamp": NOW, "validation_state": "PASS"}
        for field in ("config_fingerprint", "attach_epoch", "symbol", "build_receipt"):
            with self.subTest(field=field):
                changed = record | {field: "mismatch"}
                self.control(runtime_identity=[changed], runtime_identity_summary={"state": "PASS", "records": 1})
                result = deployment_coverage(self.meta, read_control(Sources(), self.root, BASE, NOW), NOW)
                self.assertIn(field.upper() + "_MISMATCH", result["deployments"][0]["reasons"])

    def test_wrong_magic_is_missing_not_matched(self):
        self.control(runtime_identity=[{"account_login": LOGIN, "magic": "42"}], runtime_identity_summary={"state": "PASS", "records": 1})
        result = deployment_coverage(self.meta, read_control(self.sources, self.root, BASE, NOW), NOW)
        self.assertIn("OBSERVED_IDENTITY_MISSING_OR_AMBIGUOUS", result["deployments"][0]["reasons"])

    def test_stale_identity_uses_existing_owner_policy(self):
        record = {**self.meta.identities[0], "account_login": LOGIN, "schema": "runtime_identity/1",
                  "first_trade_epoch": None, "evidence_timestamp": "2020-01-01T00:00:00Z", "validation_state": "PASS"}
        self.control(runtime_identity=[record], runtime_identity_summary={"state": "PASS", "records": 1})
        control = read_control(self.sources, self.root, BASE, NOW)
        result = deployment_coverage(self.meta, control, NOW)
        self.assertIn("IDENTITY_TIMESTAMP_STALE_EXISTING_POLICY", result["deployments"][0]["reasons"])

    def test_config_calendar_mris_and_arbitrary_false_cannot_be_effective(self):
        (self.root / "portfolio/mris").mkdir(parents=True)
        (self.root / "portfolio/news_week.csv").write_bytes(csv_bytes(set("BkkTime Currency Title TimeRaw Forecast Previous".split()), []))
        (self.root / "portfolio/mris/regime_state.json").write_text(json.dumps({"generated_utc": NOW, "effective": False}), encoding="utf-8")
        cov = deployment_coverage(self.meta, None, NOW)
        with patch.object(Sources, "git_blob", return_value=(b"configured true", "source-fixture")):
            result = guard_observations(self.sources, self.root, REPO, BASE, NOW, cov)
        self.assertIsNone(result["effective"])
        self.assertIsNone(result["deployments"][0]["MacroGate"]["effective"])
        self.assertEqual(result["deployments"][0]["availability"], "UNAVAILABLE")

    def test_duplicate_json_fields_and_nonfinite_refused(self):
        self.control()
        path = self.root / "portfolio/control_room_snapshot.json"
        for raw in ('{"x":1,"x":2}', '{"x":NaN}'):
            path.write_text(raw, encoding="utf-8")
            with self.assertRaises(Refused):
                read_control(self.sources, self.root, BASE, NOW)


class SafetyTests(Fixture):
    def test_unc_device_and_alternate_stream_refused_before_io(self):
        for raw in (r"\\server\share\private", r"\\.\pipe\private", str(self.root / "data.csv:secret"), str(self.root / "NUL")):
            with self.subTest(index=len(raw)), self.assertRaises(Refused):
                checked_path(Path(raw), Path(raw))

    def test_sources_unchanged_and_hashed(self):
        path = self.ledger([deal(comment="C:\\private\\secret " + LOGIN)])
        before = path.read_bytes()
        result = self.ledgers()
        self.assertEqual(before, path.read_bytes())
        self.assertEqual(self.sources.provenance[0]["sha256"], digest(before))
        text = json.dumps(result)
        for secret in (LOGIN, TICKET, "C:\\private", "private fixture", str(self.root)):
            self.assertNotIn(secret, text)

    def test_file_byte_budget(self):
        self.ledger([deal()])
        self.sources = Sources(Limits(file_bytes=10))
        self.assertIsNone(self.ledgers()["deal_count"])
        self.assertEqual(self.sources.errors[0]["code"], "SOURCE_BUDGET_EXCEEDED")

    def test_total_byte_budget(self):
        path = self.ledger([deal()])
        self.ledger([deal()], "20260921")
        self.sources = Sources(Limits(total_bytes=len(path.read_bytes()) + 1))
        self.assertIsNone(self.ledgers()["deal_count"])

    def test_file_count_and_row_budgets(self):
        self.ledger([deal(), deal(ticket="2")])
        self.sources = Sources(Limits(rows=1))
        self.assertIsNone(self.ledgers()["deal_count"])
        self.ledger([deal()], "20260921")
        with self.assertRaises(Refused):
            read_ledgers(Sources(Limits(files=1)), self.root, self.meta)

    def test_directory_budget_no_recursive_scan(self):
        (self.root / "unrelated").mkdir()
        (self.root / "other").mkdir()
        with self.assertRaisesRegex(Refused, "DIRECTORY_BUDGET"):
            Sources(Limits(directory_entries=1)).discover(self.root, "EA_LAB_")

    def test_traversal_and_sibling_root(self):
        for path in (self.root / ".." / "outside", self.root.parent / (self.root.name + "-sibling")):
            with self.assertRaises(Refused):
                checked_path(path, self.root)

    def test_hardlink_refused(self):
        path = self.ledger([deal()])
        target = self.root / "linked.csv"
        os.link(path, target)
        with self.assertRaisesRegex(Refused, "HARDLINK"):
            self.sources.read(self.root, target.name, "FIXTURE")

    def test_symlink_refused(self):
        path = self.ledger([deal()])
        link = self.root / "linked.csv"
        try:
            link.symlink_to(path)
        except OSError:
            self.skipTest("Windows symlink privilege unavailable; reparse gate separately exercised")
        with self.assertRaisesRegex(Refused, "LINK_OR_REPARSE"):
            self.sources.read(self.root, link.name, "FIXTURE")

    def test_reparse_attribute_gate(self):
        path = self.ledger([deal()])
        original = Path.lstat
        def fake_lstat(p):
            value = original(p)
            if p == path:
                class Reparse:
                    st_mode = value.st_mode
                    st_file_attributes = 0x400
                return Reparse()
            return value
        with patch.object(Path, "lstat", fake_lstat), self.assertRaisesRegex(Refused, "LINK_OR_REPARSE"):
            self.sources.read(self.root, path.name, "FIXTURE")

    @unittest.skipUnless(os.name == "nt", "Windows junction fixture")
    def test_real_windows_junction_refused(self):
        target = self.root / "target"
        target.mkdir()
        (target / "sentinel").write_bytes(b"unchanged")
        junction = self.root / "junction"
        # Only fixture-owned paths are interpolated; PowerShell single-quote escaping.
        quote = lambda p: "'" + str(p).replace("'", "''") + "'"
        command = "$ErrorActionPreference='Stop'; New-Item -ItemType Junction -Path " + quote(junction) + " -Target " + quote(target) + " | Out-Null"
        result = subprocess.run(["powershell", "-NoProfile", "-Command", command], capture_output=True, timeout=15)
        self.assertEqual(result.returncode, 0, "JUNCTION_FIXTURE_CREATION_FAILED")
        try:
            with self.assertRaisesRegex(Refused, "LINK_OR_REPARSE"):
                self.sources.read(junction, "sentinel", "FIXTURE")
            self.assertEqual((target / "sentinel").read_bytes(), b"unchanged")
        finally:
            os.rmdir(junction)

    def test_unstable_read_refused(self):
        path = self.ledger([deal()])
        original = Path.open
        calls = 0
        def unstable(p, *args, **kwargs):
            nonlocal calls
            if p == path:
                calls += 1
                if calls == 2:
                    with original(p, "wb") as f:
                        f.write(b"changed")
            return original(p, *args, **kwargs)
        with patch.object(Path, "open", unstable), self.assertRaisesRegex(Refused, "SOURCE_CHANGED"):
            self.sources.read(self.root, path.name, "FIXTURE")

    def test_decimal_bool_and_nonfinite(self):
        for value in (True, False, None, float("nan"), "NaN", "Infinity", "-Infinity", "1e999999"):
            with self.subTest(value=str(value)), self.assertRaises(Refused):
                decimal(value)

    def test_budgets_cannot_be_widened_or_boolean(self):
        for options in ({"files": True}, {"rows": 1_000_001}, {"file_bytes": 0}):
            with self.assertRaises(Refused):
                Limits(**options)


class BuilderCliTests(Fixture):
    def test_changed_exporter_contract_fails_closed(self):
        with patch.object(Sources, "git_blob", return_value=(b"changed producer", "source-fixture")):
            with self.assertRaisesRegex(Refused, "PARSER_CONTRACT_SOURCE_CHANGED"):
                build_observations(BuildRequest(REPO, BASE, self.root, self.root, self.root, NOW))

    def args(self, *extra):
        return ["--repo", str(REPO), "--ref", BASE, "--ledgers", str(self.root), "--snapshots", str(self.root),
                "--runtime", str(self.root), "--as-of", NOW, *extra]

    def canonical_fixture(self):
        source = Sources()
        raw, _ = source.git_blob(REPO, BASE, "portfolio/ACCOUNTS.csv")
        row = next(r for r in source.csv(raw) if r["platform"] == "MT5")
        login = row["account"]
        (self.root / f"EA_LAB_deals_{login}_20260920.csv").write_bytes(csv_bytes(DEAL_FIELDS, [deal()]))
        (self.root / f"EA_LAB_snapshot_{login}_20260920.csv").write_bytes(csv_bytes(SNAP_FIELDS, [snapshot(login=login, currency=row["currency"])]))
        return login

    def test_callable_build_uses_canonical_metadata_and_real_readers(self):
        login = self.canonical_fixture()
        result = build_observations(BuildRequest(REPO, BASE, self.root, self.root, self.root, NOW)).to_dict()
        account = next(a for a in result["sections"]["ledger"]["data"]["accounts"] if a["account_key"] == opaque("account", login))
        self.assertEqual(account["deal_count"], 1)
        self.assertFalse(result["integration"]["ui_wired"])
        self.assertNotIn(login, json.dumps(result))

    def test_actual_cli_subprocess_populated_fixture(self):
        login = self.canonical_fixture()
        script = "import sys,runpy;sys.path.insert(0,sys.argv.pop(1));runpy.run_module('tools.mobile_report_hub.source_adapters',run_name='__main__')"
        proc = subprocess.run([sys.executable, "-B", "-c", script, str(REPO.resolve()), *self.args()], capture_output=True, text=True, timeout=30)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        result = json.loads(proc.stdout)
        self.assertEqual(result["schema_version"], "ea_observation_adapters/1")
        self.assertNotIn(login, proc.stdout)
        self.assertNotIn(TICKET, proc.stdout)
        self.assertNotIn(str(self.root), proc.stdout + proc.stderr)

    def test_cli_output_only_new_scoped_file_and_no_overwrite(self):
        output = self.root / "observations.json"
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(main(self.args("--output", str(output))), 0)
            before = output.read_bytes()
            self.assertEqual(main(self.args("--output", str(output))), 2)
        self.assertEqual(before, output.read_bytes())

    def test_output_traversal_private_errors_sanitized(self):
        for output in (self.root.parent / ".." / "old.json", self.root / "private.csv"):
            error = io.StringIO()
            with contextlib.redirect_stderr(error), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(main(self.args("--output", str(output))), 2)
            self.assertNotIn(str(output), error.getvalue())

    def test_invalid_cli_args_do_not_echo_values(self):
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            self.assertEqual(main(["--secret=" + LOGIN]), 2)
        self.assertNotIn(LOGIN, err.getvalue())

    def test_errors_are_repeatable_observations_no_notifications(self):
        first = build_observations(BuildRequest(REPO, BASE, self.root, self.root, self.root, NOW)).to_dict()
        second = build_observations(BuildRequest(REPO, BASE, self.root, self.root, self.root, NOW)).to_dict()
        self.assertEqual(first, second)
        self.assertEqual(first["sections"]["access_provenance"]["data"]["notifications"], "NONE")


class Repair1Tests(Fixture):
    def build(self):
        with patch("tools.mobile_report_hub.source_adapters.builder.Metadata", return_value=self.meta):
            return build_observations(BuildRequest(REPO, BASE, self.root, self.root, self.root, NOW)).to_dict()

    def account(self, result, section):
        return next(a for a in result["sections"][section]["data"]["accounts"]
                    if a["account_key"] == opaque("account", LOGIN))

    def unaffected_account(self):
        other = "731245680"
        self.meta.accounts[other].append(dict(account=other, platform="MT5", currency="USD"))
        (self.root / f"EA_LAB_deals_{other}_20260920.csv").write_bytes(csv_bytes(DEAL_FIELDS, [deal()]))
        (self.root / f"EA_LAB_snapshot_{other}_20260920.csv").write_bytes(csv_bytes(SNAP_FIELDS, [snapshot(login=other)]))
        return other

    def assert_withheld(self, result, reason):
        account = self.account(result, "ledger")
        self.assertIsNone(account["deal_count"])
        self.assertEqual(account["availability"], "UNAVAILABLE")
        self.assertEqual(account["reason"], reason)
        self.assertEqual(len(account["components"]), 1)
        for field in ("deal_count", "gross_realized_profit_component", "swap", "commission",
                      "reported_components_subtotal"):
            self.assertIsNone(account["components"][0][field])
        payload = json.dumps(result)
        self.assertTrue(all(secret not in payload for secret in (LOGIN, TICKET, str(self.root))))
        other = opaque("account", "731245680")
        unaffected = next(a for a in result["sections"]["ledger"]["data"]["accounts"] if a["account_key"] == other)
        self.assertEqual(unaffected["deal_count"], 1)
        self.assertEqual(unaffected["components"][0]["reported_components_subtotal"], "0.07")
        unaffected = next(a for a in result["sections"]["accounts"]["data"]["accounts"] if a["account_key"] == other)
        self.assertIsNotNone(unaffected["latest"])

    def malformed_filename(self, kind):
        self.snap([snapshot(equity="12.00")])
        self.ledger([deal()])
        # Both discovery orders must withhold; malformed suffixes never become input.
        for suffix in ("20260931", "00000000", "bad-date", "2026093"):
            with self.subTest(suffix=suffix):
                self.meta = metadata()
                self.unaffected_account()
                path = self.root / f"EA_LAB_{kind}_{LOGIN}_{suffix}.csv"
                path.write_bytes(b"must not be parsed")
                try:
                    result = self.build()
                    self.assertIn("SOURCE_FILENAME_INVALID", {e["code"] for e in result["errors"]})
                    if kind == "snapshot":
                        account = self.account(result, "accounts")
                        self.assertTrue(account["latest"] is None, "MALFORMED_FILENAME_RETAINED_OLDER_LATEST")
                        self.assertEqual(account["latest_reason"], "INVALID_SOURCE_MAY_HIDE_LATEST")
                    self.assert_withheld(result, "INVALID_EXPORT_WITHHELD")
                finally:
                    path.unlink()

    def test_oa001_snapshot_malformed_date_withholds_old_latest_and_totals(self):
        self.malformed_filename("snapshot")

    def test_oa001_ledger_malformed_date_withholds_old_totals(self):
        self.malformed_filename("deals")

    def snapshot_conflict(self, wrong_login):
        self.unaffected_account()
        self.snap([snapshot(equity="12.00")])
        self.snap([snapshot("2026.09.21 09:00:00", login=wrong_login)], "20260921")
        self.ledger([deal()])
        result = self.build()
        self.assertIn("SNAPSHOT_ACCOUNT_OR_TIME_CONFLICT", {e["code"] for e in result["errors"]})
        self.assertTrue(self.account(result, "accounts")["latest"] is None)
        self.assert_withheld(result, "SNAPSHOT_ACCOUNT_BINDING_CONFLICT")

    def test_oa002_snapshot_login_mismatch_withholds_ledger(self):
        self.snapshot_conflict("731245680")

    def test_oa002_snapshot_missing_login_withholds_ledger(self):
        self.snapshot_conflict("")

    def malformed_state(self, state):
        self.snap([snapshot()])
        self.ledger([deal()])
        self.control()
        before = self.build()
        self.control(runtime_identity_summary={"state": state, "records": 0})
        result = self.build()
        self.assertEqual(result["sections"]["accounts"], before["sections"]["accounts"])
        self.assertEqual(result["sections"]["ledger"], before["sections"]["ledger"])
        deployment = result["sections"]["deployments"]
        self.assertEqual([e["code"] for e in deployment["errors"]], ["CONTROL_ROOM_IDENTITY_STATE_INVALID"])
        self.assertIsNone(deployment["data"]["producer"])
        self.assertEqual(deployment["data"]["deployments"][0]["runtime_identity"], "UNAVAILABLE")
        self.assertIsNone(result["sections"]["guards"]["data"]["effective"])
        self.assertFalse(result["integration"]["real_data_qualified"])
        self.assertTrue(all(secret not in json.dumps(result) for secret in (LOGIN, TICKET, str(self.root))))

    def test_oa003_list_state_returns_typed_payload(self):
        self.malformed_state([])

    def test_oa003_object_state_returns_typed_payload(self):
        self.malformed_state({"private": LOGIN})


if __name__ == "__main__":
    unittest.main()
