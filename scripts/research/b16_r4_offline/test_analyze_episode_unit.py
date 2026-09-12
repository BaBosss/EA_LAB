"""Focused offline fixtures; no source, runtime, or repository writes."""
import copy
import hashlib
import importlib.util
import sys
import unittest
from decimal import Decimal as D, localcontext
from pathlib import Path
from unittest.mock import patch

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import analyze_episode_unit as a


def fixture(events=None):
    # Two entries, partial first close, another entry, then a multi-entry exit.
    # Flat only after exit 6; exit 8 completes a separate episode.
    events = events or [
        ("in", "0.02", "0", "0", "0"),
        ("in", "0.01", "0", "0", "0"),
        ("out", "0.01", "10", "0.25", "-0.10"),
        ("in", "0.01", "0", "0", "0"),
        ("out", "0.03", "-4", "-0.50", "-0.20"),
        ("in", "0.01", "0", "0", "0"),
        ("out", "0.01", "2", "0.15", "-0.05"),
    ]
    amounts = [(D(c), D(s), D(p)) for _, _, p, s, c in events]
    values = [sum(v, D(0)) for v in amounts]
    net = sum(values, D(0))
    exits = [value for event, value in zip(events, values) if event[0] == "out"]
    rows = [["Symbol:", "USDJPY"], ["Initial Deposit:", "10000.00"],
            ["Total Net Profit:", str(net)], ["Total Trades:", str(len(exits))],
            ["Total Deals:", str(len(events))],
            ["Gross Profit:", str(sum((v for v in exits if v > 0), D(0)))],
            ["Gross Loss:", str(sum((v for v in exits if v < 0), D(0)))],
            ["Deals"], list(a.HEADER),
            ["2023.01.01 00:00:00", "1", "", "balance", "", "", "", "", "0", "0", "10000", "10000", ""]]
    balance = D(10000)
    for i, (event, value) in enumerate(zip(events, values), 2):
        direction, volume, profit, swap, commission = event
        balance += value
        rows.append([f"2023.01.02 00:00:{i:02d}", str(i), "USDJPY",
                     "buy" if direction == "in" else "sell", direction,
                     volume, "130.123", str(i), commission, swap, profit, str(balance), ""])
    totals = [sum((v[i] for v in amounts), D(0)) for i in range(3)]
    rows.extend([["", *map(str, totals), str(balance), ""], [""]])
    return rows


def html_bytes(rows):
    return ("<html><table>" + "".join("<tr>" + "".join(f"<td>{v}</td>" for v in row) + "</tr>"
                                     for row in rows) + "</table></html>").encode("utf-16")


class SamplerTests(unittest.TestCase):
    def test_known_sha256_vector_and_determinism(self):
        digest = "2b71d8b6eae1882fa2708b82359aa97cf244096f6d9c4ad5a8fcec4bd0d04d39"
        self.assertEqual(hashlib.sha256(b"20260912|M1_MAIN|TICKET|0|0").hexdigest(), digest)
        self.assertEqual(int(digest[:16], 16), 3130521496135501871)
        self.assertEqual(a.sample_index("M1_MAIN", "TICKET", 0, 0, 275), 271)
        self.assertEqual([a.sample_index("M1_MAIN", "TICKET", 0, 0, 7) for _ in range(5)], [4] * 5)

    def test_exact_unsigned_big_endian_modulo(self):
        with patch.object(a.hashlib, "sha256") as sha:
            sha.return_value.digest.return_value = bytes.fromhex("fedcba9876543210") + b"\x00" * 24
            self.assertEqual(a.sample_index("M4_BWD", "EPISODE", 4999, 2, 3), 0)
            sha.assert_called_once_with(b"20260912|M4_BWD|EPISODE|4999|2")
        self.assertEqual(a.sample_index("M1_MAIN", "TICKET", 0, 0, 1), 0)

    def test_ticket_and_episode_units_draw_counts_and_known_sums(self):
        tickets = list(map(D, ["1.01", "2.02", "3.03", "4.04"]))
        episodes = [D("3.03"), D("7.07")]
        # Frozen indices: ticket [3,3,3,1], [2,3,3,1], [3,1,0,3].
        self.assertEqual([a.resampled_sum(tickets, "M1_MAIN", "TICKET", r) for r in range(3)],
                         list(map(D, ["14.14", "13.13", "11.11"])))
        self.assertEqual([a.resampled_sum(episodes, "M1_MAIN", "EPISODE", r) for r in range(3)],
                         [D("10.10")] * 3)

    def test_5000_replications_each_arm(self):
        for arm in ("TICKET", "EPISODE"):
            with patch.object(a, "resampled_sum", wraps=a.resampled_sum) as sample:
                result = a.bootstrap([D("0.10"), D("0.20")], "M1_MAIN", arm)
                self.assertEqual(sample.call_count, 5000)
                self.assertEqual(sample.call_args_list[0].args[-1], 0)
                self.assertEqual(sample.call_args_list[-1].args[-1], 4999)
                self.assertEqual(result["replications"], 5000)
                self.assertEqual(result["draws_per_replication"], 2)

    def test_ticket_episode_resampling_difference_fixture(self):
        # Each intact episode nets zero. Shuffled constituent tickets vary.
        ticket = a.bootstrap([D("10"), D("-10"), D("20"), D("-20")], "M1_MAIN", "TICKET")
        episode = a.bootstrap([D("0"), D("0")], "M1_MAIN", "EPISODE")
        self.assertGreater(ticket["width"], 0)
        self.assertEqual(episode["width"], 0)
        self.assertEqual(episode["median"], 0)

    def test_sampler_invalid_arguments_refused(self):
        for args in [("BAD", "TICKET", 0, 0, 1), ("M1_MAIN", "bad", 0, 0, 1),
                     ("M1_MAIN", "TICKET", -1, 0, 1), ("M1_MAIN", "TICKET", 5000, 0, 1),
                     ("M1_MAIN", "TICKET", 0, 0, 0), ("M1_MAIN", "TICKET", 0, 1, 1)]:
            with self.subTest(args=args), self.assertRaises(a.EvidenceError):
                a.sample_index(*args)


class QuantileTests(unittest.TestCase):
    def test_boundaries_and_frozen_interpolation(self):
        sums = [D(i) / 100 for i in range(5000)]
        for p, expected in [("0", "0"), ("1", "49.99"), ("0.025", "1.24975"),
                            ("0.5", "24.995"), ("0.975", "48.74025")]:
            self.assertEqual(a.quantile(sums, D(p)), D(expected))

    def test_negative_tied_quantiles(self):
        sums = [D("-2.21")] * 2500 + [D("1.10")] * 2500
        self.assertEqual(a.quantile(sums, D("0.5")), D("-0.555"))
        self.assertEqual(a.quantile(sums, D("0.025")), D("-2.21"))
        self.assertEqual(a.quantile(sums, D("0.975")), D("1.10"))

    def test_invalid_count_probability_refused(self):
        for sums, probability in [([D(0)] * 4999, D("0.5")), ([D(0)] * 5000, D("1.01")),
                                  ([D(0)] * 5000, 0.5)]:
            with self.assertRaises(a.EvidenceError):
                a.quantile(sums, probability)


class LedgerTests(unittest.TestCase):
    def test_partial_close_multi_exit_exact_reconstruction(self):
        result = a.reconstruct(fixture())
        self.assertEqual((result["N"], result["K"]), (3, 2))
        self.assertEqual(result["tickets"], list(map(D, ["10.15", "-4.70", "2.10"])))
        self.assertEqual(result["episode_units"], [D("5.45"), D("2.10")])
        self.assertEqual(result["observed_total"], D("7.55"))
        self.assertEqual(result["episode_size_distribution"], {1: 1, 2: 1})
        self.assertEqual([e["deal_ids"] for e in result["episodes"]], [[2, 3, 4, 5, 6], [7, 8]])

    def test_html_parser_and_exact_decimal_context(self):
        data = html_bytes(fixture())
        with localcontext() as context:
            context.prec = 5
            result = a.parse_report(data)
        self.assertEqual(result["observed_total"], D("7.55"))
        self.assertEqual(a.decimal_value("10 000.01"), D("10000.01"))

    def test_open_final_refused(self):
        rows = fixture([("in", "0.02", "0", "0", "0"), ("out", "0.01", "1", "0", "0")])
        with self.assertRaisesRegex(a.EvidenceError, "ends non-flat"):
            a.reconstruct(rows)

    def test_close_while_flat_and_overclose_refused(self):
        for events, message in [([("out", "0.01", "0", "0", "0")], "while flat"),
                                ([("in", "0.01", "0", "0", "0"),
                                  ("out", "0.02", "0", "0", "0")], "exceeds")]:
            with self.assertRaisesRegex(a.EvidenceError, message):
                a.reconstruct(fixture(events))

    def test_nontrading_malformed_direction_symbol_refusals(self):
        for column, replacement in [(3, "credit"), (4, "in/out"), (2, "EURUSD"), (5, "0")]:
            rows = fixture()
            rows[10][column] = replacement
            with self.subTest(column=column), self.assertRaises(a.EvidenceError):
                a.reconstruct(rows)
        rows = fixture()
        rows.insert(-2, ["unexpected"])
        with self.assertRaisesRegex(a.EvidenceError, "unsupported ledger row"):
            a.reconstruct(rows)

    def test_extra_deposit_refused(self):
        rows = fixture()
        extra = rows[9].copy()
        extra[0], extra[1] = "2023.02.01 00:00:00", "9"
        rows.insert(-2, extra)
        with self.assertRaisesRegex(a.EvidenceError, "non-trading balance"):
            a.reconstruct(rows)

    def test_entry_costs_even_canceling_refused(self):
        rows = fixture()
        rows[10][8:11] = ["-1", "1", "0"]
        with self.assertRaisesRegex(a.EvidenceError, "entry cashflow"):
            a.reconstruct(rows)

    def test_incomplete_footer_and_table_refused(self):
        rows = fixture()
        with self.assertRaisesRegex(a.EvidenceError, "missing totals footer"):
            a.reconstruct(rows[:-2])
        rows.append(["unrecognized tail"])
        with self.assertRaisesRegex(a.EvidenceError, "after totals footer"):
            a.reconstruct(rows)
        with self.assertRaisesRegex(a.EvidenceError, "incomplete HTML"):
            a.parse_report("<table><tr><td>incomplete".encode("utf-16"))

    def test_duplicate_or_unordered_deals_refused(self):
        for mutation in ("duplicate", "order"):
            rows = fixture()
            if mutation == "duplicate":
                rows[11][1] = rows[10][1]
            else:
                rows[11], rows[10] = rows[10], rows[11]
            with self.assertRaises(a.EvidenceError):
                a.reconstruct(rows)

    def test_reconciliation_refusals(self):
        # Native net/count/gross, running balance and footer components all fail closed.
        for row_index, column in [(2, 1), (3, 1), (4, 1), (5, 1), (6, 1), (12, 11), (-2, 2)]:
            rows = fixture()
            rows[row_index][column] = str(D(rows[row_index][column]) + D("0.01"))
            with self.subTest(row=row_index), self.assertRaisesRegex(a.EvidenceError, "reconciliation mismatch"):
                a.reconstruct(rows)

    def test_invalid_decimal_and_ambiguous_header_refused(self):
        for value in ("NaN", "Infinity", "1e3", "1,000", "0.000000001"):
            with self.assertRaises(a.EvidenceError):
                a.decimal_value(value)
        for extra in (["Total Net Profit:", "7.55"], ["Deals"]):
            rows = fixture()
            rows.insert(0, extra)
            with self.assertRaises(a.EvidenceError):
                a.reconstruct(rows)

    def test_reference_agreement_fixture_and_four_reports(self):
        spec = importlib.util.spec_from_file_location("accepted_h02", a.ROOT / a.REFERENCE)
        ref = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(ref)
        all_rows = [fixture()]
        for cell, expected in a.REPORT_HASHES.items():
            p = a.ROOT / a.SOURCE_DIR / "runtime" / cell / "report.htm"
            self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(), expected)
            all_rows.append(ref.parse_html(p))
        for rows in all_rows:
            ledger = a.reconstruct(rows)
            reference = ref.reconstruct_cycles(ref.parse_deals(rows))
            self.assertEqual([e["deal_ids"] for e in ledger["episodes"]], [e["deal_ids"] for e in reference])
            self.assertEqual([len(e["tickets"]) for e in ledger["episodes"]],
                             [e["closed_ticket_count"] for e in reference])
            self.assertEqual(ledger["episode_units"], [D(str(e["pnl"])) for e in reference])


class OutputTests(unittest.TestCase):
    def test_falsifier_requires_every_model_and_window_strictly_wider(self):
        cells = {cell: {"status": "PASS", "TICKET": {"width": D(1)}, "EPISODE": {"width": D(2)}}
                 for cell in a.REPORT_HASHES}
        self.assertEqual(a.classify(cells), a.SUPPORTED)
        for cell in cells:
            for width in (D(1), D("0.5")):
                changed = copy.deepcopy(cells)
                changed[cell]["EPISODE"]["width"] = width
                self.assertEqual(a.classify(changed), a.MIXED)
        cells["M4_BWD"]["status"] = a.BLOCKED
        self.assertEqual(a.classify(cells), a.BLOCKED)
        self.assertEqual(a.classify({}), a.BLOCKED)

    def test_hash_mismatch_every_source_refuses_before_inference(self):
        real_read = Path.read_bytes
        for cell in a.REPORT_HASHES:
            target = a.ROOT / a.SOURCE_DIR / "runtime" / cell / "report.htm"
            def read(path):
                data = real_read(path)
                return data + b"bad" if path == target else data
            with patch.object(Path, "read_bytes", read), patch.object(a, "bootstrap") as sample:
                result = a.analyze()
            self.assertEqual(result["classification"], a.BLOCKED)
            self.assertIn("source hash mismatch", result["cells"][cell]["blocker"])
            self.assertTrue(all("sha256" in c["source"] for c in result["cells"].values()))
            sample.assert_not_called()

    def test_missing_support_evidence_refuses_before_inference(self):
        real_read = Path.read_bytes
        def read(path):
            if path == a.ROOT / a.PREREG:
                raise FileNotFoundError("fixture missing prereg")
            return real_read(path)
        with patch.object(Path, "read_bytes", read), patch.object(a, "bootstrap") as sample:
            self.assertEqual(a.analyze()["status"], a.BLOCKED)
            sample.assert_not_called()

    def test_invalid_ledger_blocks_all_inference(self):
        with patch.object(a, "parse_report", side_effect=a.EvidenceError("native net mismatch")), \
                patch.object(a, "bootstrap") as sample:
            result = a.analyze()
        self.assertEqual(result["classification"], a.BLOCKED)
        self.assertEqual(len(result["blockers"]), 4)
        sample.assert_not_called()

    def test_deterministic_repeat_output(self):
        first = {arm: a.bootstrap([D("-1.01"), D("2.02")], "M4_BWD", arm)
                 for arm in ("TICKET", "EPISODE")}
        second = {arm: a.bootstrap([D("-1.01"), D("2.02")], "M4_BWD", arm)
                  for arm in ("TICKET", "EPISODE")}
        self.assertEqual(a.encode(first), a.encode(second))
        self.assertIn('"q025": "', a.encode(first))
        self.assertTrue(a.encode(first).endswith("\n"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
