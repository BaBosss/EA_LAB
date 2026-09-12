"""In-memory accounting fixtures; no source-evidence writes or MT5 execution."""

import copy
import importlib.util
import unittest
from datetime import datetime
from decimal import Decimal as D
from pathlib import Path

SPEC = importlib.util.spec_from_file_location("swapcredit", Path(__file__).with_name("analyze_swap_credit.py"))
a = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(a)


def deal(profit="10.00", swap="0.00", commission="0.00", direction="out"):
    return {"profit": D(profit), "swap": D(swap), "commission": D(commission), "direction": direction}


def fixture():
    return [["Deals"], a.HEADER.copy(),
            ["2023.01.02 01:00:00", "2", "USDJPY", "buy", "in", "0.01", "130.000", "2",
             "0.00", "0.00", "0.00", "10000.00", "16_KangarooGrid L0"],
            ["2023.01.02 02:00:00", "3", "USDJPY", "sell", "out", "0.01", "131.000", "3",
             "-1.00", "2.00", "10.00", "10011.00", ""],
            ["", "-1.00", "2.00", "10.00", "10011.00", ""], [""]]


def parse(rows):
    return a.parse_ledger(rows, datetime(2023, 1, 1), datetime(2025, 12, 31, 23, 59, 59), D("10000"))


def cells(adjusted="1.00", credit="1.00"):
    return [{"cell": tag, "status": "PASS", "totals": {
        "adjusted_net": adjusted, "positive_swap_credit_total": credit}} for tag in a.PINS]


class AccountingTests(unittest.TestCase):
    def test_positive_credit_removal_only(self):
        result = a.attribution([deal(swap="5.00"), deal(swap="-2.00")])
        self.assertEqual(result["native_net"], "23.00")
        self.assertEqual(result["adjusted_net"], "18.00")
        self.assertEqual(result["positive_swap_credit_total"], "5.00")
        self.assertEqual(result["adjustment_amount"], "-5.00")
        self.assertEqual(result["signed_total_swap"], "3.00")

    def test_negative_swap_retained(self):
        result = a.attribution([deal(swap="-2.50")])
        self.assertEqual(result["negative_swap_debit_total"], "-2.50")
        self.assertEqual(result["native_net"], result["adjusted_net"])
        self.assertEqual(result["adjusted_net"], "7.50")

    def test_commission_retained_including_entry_cashflow(self):
        result = a.attribution([deal("0.00", commission="-0.50", direction="in"),
                                deal(swap="3.00", commission="-1.00")])
        self.assertEqual(result["commission"], "-1.50")
        self.assertEqual(result["adjusted_net"], "8.50")

    def test_no_credit_inert_case(self):
        result = a.attribution([deal(), deal(swap="-1.00")])
        self.assertEqual(result["native_net"], result["adjusted_net"])
        self.assertEqual(result["adjustment_sign"], "ZERO")
        self.assertEqual(a.classify(cells(credit="0.00"))["classification"],
                         "NO_CREDIT_DEPENDENCE_IN_RECORDED_LEDGER")

    def test_decimal_cents_exact(self):
        self.assertEqual(a.attribution([deal("0.10") for _ in range(3)])["native_net"], "0.30")

    def test_hash_mismatch_refusal(self):
        with self.assertRaisesRegex(a.BlockedEvidence, "hash mismatch"):
            a.checked_bytes(b"altered", a.digest(b"original"), "fixture")
        self.assertEqual(a.checked_bytes(b"original", a.digest(b"original"), "fixture"), b"original")

    def test_native_net_reconciliation_refusal(self):
        totals = a.attribution([deal()])
        a.reconcile(totals, "10", 10.0, "10.00")
        for values in (("9.99", "10", "10"), ("10", "9.99", "10"), ("10", "10", "9.99")):
            with self.subTest(values=values), self.assertRaisesRegex(a.BlockedEvidence, "native-net"):
                a.reconcile(totals, *values)

    def test_falsifier_each_cell_and_zero_boundary(self):
        for index in range(4):
            for value in ("0.00", "-0.01"):
                rows = cells()
                rows[index]["totals"]["adjusted_net"] = value
                result = a.classify(rows)
                self.assertTrue(result["claim_falsified"])
                self.assertEqual(result["nonpositive_cells"], [rows[index]["cell"]])

    def test_positive_nets_not_falsified(self):
        self.assertEqual(a.classify(cells())["classification"],
                         "CREDIT_INDEPENDENT_POSITIVE_NET_NOT_FALSIFIED_ON_RECORDED_LEDGER")

    def test_no_selection_of_reports(self):
        for rows in (cells()[:3], [cells()[0]] * 4):
            with self.assertRaises(a.BlockedEvidence):
                a.classify(rows)

    def test_blocked_cell_cannot_be_strategy_failure(self):
        rows = cells()
        rows[0]["status"] = "BLOCKED_EVIDENCE"
        with self.assertRaises(a.BlockedEvidence):
            a.classify(rows)

    def test_deterministic_output_without_mutation(self):
        rows = fixture()
        before = copy.deepcopy(rows)
        first = a.serialize(a.attribution(parse(rows)[0]))
        self.assertEqual(first, a.serialize(a.attribution(parse(rows)[0])))
        self.assertEqual(rows, before)


class LedgerTests(unittest.TestCase):
    def test_valid_ledger_reconciles_totals_and_episodes(self):
        deals, episodes = parse(fixture())
        self.assertEqual(len(episodes), 1)
        self.assertEqual(a.attribution(deals)["adjusted_net"], "9.00")
        self.assertEqual([d["deal"] for d in episodes[0]], [2, 3])

    def test_exact_opening_deposit_balance_row_is_allowed(self):
        rows = fixture()
        rows.insert(2, ["2023.01.01 00:00:00", "1", "", "balance", "", "", "", "",
                        "0.00", "0.00", "10000.00", "10000.00", ""])
        deals, episodes = parse(rows)
        self.assertEqual([d["deal"] for d in deals], [2, 3])
        self.assertEqual(len(episodes), 1)

    def test_second_or_malformed_balance_row_refuses(self):
        exact = ["2023.01.01 00:00:00", "1", "", "balance", "", "", "", "",
                 "0.00", "0.00", "10000.00", "10000.00", ""]
        rows = fixture()
        rows.insert(2, exact)
        rows.insert(3, exact.copy())
        with self.assertRaisesRegex(a.BlockedEvidence, "unsupported"):
            parse(rows)

    def test_unsupported_row_refusal(self):
        for kind in ("balance", "credit", "commission", "correction", "dividend"):
            rows = fixture()
            rows[2][3] = kind
            with self.subTest(kind=kind), self.assertRaisesRegex(a.BlockedEvidence, "unsupported"):
                parse(rows)

    def test_nontrading_row_cannot_hide_in_short_row(self):
        rows = fixture()
        rows.insert(3, ["balance", "100.00"])
        with self.assertRaisesRegex(a.BlockedEvidence, "malformed"):
            parse(rows)

    def test_balance_reconciliation_refusal(self):
        rows = fixture()
        rows[3][11] = "10010.99"
        with self.assertRaisesRegex(a.BlockedEvidence, "balance reconciliation"):
            parse(rows)

    def test_footer_reconciliation_refusal(self):
        rows = fixture()
        rows[-2][2] = "1.99"
        with self.assertRaisesRegex(a.BlockedEvidence, "totals reconciliation"):
            parse(rows)

    def test_missing_footer_refusal(self):
        with self.assertRaisesRegex(a.BlockedEvidence, "incomplete"):
            parse(fixture()[:-2])

    def test_incomplete_position_refusal(self):
        rows = fixture()
        rows[3][5] = "0.005"
        with self.assertRaisesRegex(a.BlockedEvidence, "incomplete"):
            parse(rows)

    def test_extra_volume_refusal(self):
        rows = fixture()
        rows[3][5] = "0.02"
        with self.assertRaisesRegex(a.BlockedEvidence, "exceeds"):
            parse(rows)

    def test_duplicate_id_refusal(self):
        rows = fixture()
        rows[3][1] = "2"
        with self.assertRaisesRegex(a.BlockedEvidence, "duplicate"):
            parse(rows)

    def test_changed_header_refusal(self):
        rows = fixture()
        rows[1][9] = "Fee"
        with self.assertRaisesRegex(a.BlockedEvidence, "header"):
            parse(rows)

    def test_data_after_footer_refusal(self):
        rows = fixture()
        rows.append(rows[2])
        with self.assertRaisesRegex(a.BlockedEvidence, "after Deals totals"):
            parse(rows)

    def test_entry_swap_refusal(self):
        rows = fixture()
        rows[2][9] = "1.00"
        with self.assertRaisesRegex(a.BlockedEvidence, "entry-side swap"):
            parse(rows)

    def test_nonfinite_numeric_refusal(self):
        for value in ("NaN", "Infinity", "1e3", "", "1.001"):
            rows = fixture()
            rows[3][9] = value
            with self.subTest(value=value), self.assertRaises(a.BlockedEvidence):
                parse(rows)


if __name__ == "__main__":
    unittest.main(verbosity=2)
