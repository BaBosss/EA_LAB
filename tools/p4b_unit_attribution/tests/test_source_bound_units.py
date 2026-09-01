import csv
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import build_source_bound_units as m


def row(deal_id, position_id, entry, time_server, *, volume="0.01", deal_type="0",
        order_id=None, commission="0", swap="0", profit="0"):
    return {
        "schema_version": m.SOURCE_SCHEMA,
        "symbol": "XAUUSD", "period": "16388", "period_name": "PERIOD_H4",
        "magic": "990001", "account_margin_mode": "2",
        "deal_id": str(deal_id), "position_id": str(position_id),
        "order_id": str(order_id if order_id is not None else deal_id + 100),
        "deal_entry": str(entry), "deal_type": str(deal_type),
        "deal_time_server": time_server, "deal_time_msc": str(1700000000000 + deal_id),
        "volume": volume, "price": "2000.0", "commission": commission,
        "swap": swap, "profit": profit,
    }


def write_source(path, rows):
    with path.open("w", newline="", encoding="ascii") as f:
        w = csv.DictWriter(f, fieldnames=m.REQUIRED_HEADER, lineterminator="\n")
        w.writeheader(); w.writerows(rows)


class SourceBoundUnitTests(unittest.TestCase):
    def test_exact_position_link_builds_one_realized_unit(self):
        rows = [
            row(1, 77, m.ENTRY_IN, "2023.06.12 12:00:00", commission="-0.01"),
            row(2, 77, m.ENTRY_OUT, "2023.06.13 14:00:00", deal_type="1", commission="-0.01", swap="-0.02", profit="1.25"),
        ]
        units, meta = m.build_units(m.read_source(self._source(rows)), "H3-C03-MAIN")
        self.assertEqual(meta["realized_unit_count"], 1)
        self.assertEqual(meta["source_in_count"], 1)
        self.assertEqual(meta["source_out_count"], 1)
        self.assertEqual(units[0]["source_position_id"], "77")
        self.assertEqual(units[0]["source_open_deal_id"], "1")
        self.assertEqual(units[0]["source_deal_id"], "2")
        self.assertEqual(units[0]["entry_utc"], "2023-06-12T09:00:00Z")
        self.assertEqual(units[0]["source_net_realized"], "1.21")

    def test_zero_position_id_refuses(self):
        with self.assertRaises(m.UnitSourceError):
            m.read_source(self._source([row(1, 0, m.ENTRY_IN, "2023.01.02 12:00:00")]))

    def test_duplicate_deal_id_refuses(self):
        with self.assertRaises(m.UnitSourceError):
            m.read_source(self._source([
                row(1, 77, m.ENTRY_IN, "2023.01.02 12:00:00"),
                row(1, 77, m.ENTRY_OUT, "2023.01.03 12:00:00"),
            ]))

    def test_multi_entry_position_refuses(self):
        parsed = m.read_source(self._source([
            row(1, 77, m.ENTRY_IN, "2023.01.02 12:00:00", volume="0.01"),
            row(2, 77, m.ENTRY_IN, "2023.01.02 13:00:00", volume="0.01"),
            row(3, 77, m.ENTRY_OUT, "2023.01.03 12:00:00", volume="0.01"),
        ]))
        with self.assertRaises(m.UnitSourceError):
            m.build_units(parsed, "H3-C03-MAIN")

    def test_inout_reversal_refuses(self):
        parsed = m.read_source(self._source([
            row(1, 77, m.ENTRY_IN, "2023.01.02 12:00:00"),
            row(2, 77, m.ENTRY_INOUT, "2023.01.03 12:00:00"),
        ]))
        with self.assertRaises(m.UnitSourceError):
            m.build_units(parsed, "H3-C03-MAIN")

    def test_volume_mismatch_refuses(self):
        parsed = m.read_source(self._source([
            row(1, 77, m.ENTRY_IN, "2023.01.02 12:00:00", volume="0.02"),
            row(2, 77, m.ENTRY_OUT, "2023.01.03 12:00:00", volume="0.01"),
        ]))
        with self.assertRaises(m.UnitSourceError):
            m.build_units(parsed, "H3-C03-MAIN")

    def test_open_position_is_counted_but_not_realized(self):
        parsed = m.read_source(self._source([row(1, 77, m.ENTRY_IN, "2023.01.02 12:00:00")]))
        units, meta = m.build_units(parsed, "H3-C03-MAIN")
        self.assertEqual(units, [])
        self.assertEqual(meta["open_position_count"], 1)

    def test_dst_transition_is_unknown_not_guessed(self):
        parsed = m.read_source(self._source([
            row(1, 77, m.ENTRY_IN, "2023.03.12 12:00:00"),
            row(2, 77, m.ENTRY_OUT, "2023.03.13 12:00:00"),
        ]))
        units, meta = m.build_units(parsed, "H3-C03-MAIN")
        self.assertEqual(units[0]["time_status"], "UNKNOWN_TIMEZONE")
        self.assertEqual(units[0]["entry_utc"], "")
        self.assertEqual(meta["unknown_time_unit_count"], 1)

    def test_mixed_run_identity_refuses(self):
        rows = [
            row(1, 77, m.ENTRY_IN, "2023.01.02 12:00:00"),
            row(2, 77, m.ENTRY_OUT, "2023.01.03 12:00:00"),
        ]
        rows[1]["symbol"] = "EURUSD"
        with self.assertRaises(m.UnitSourceError):
            m.read_source(self._source(rows))

    def _source(self, rows):
        f = tempfile.NamedTemporaryFile(suffix=".csv", delete=False)
        f.close()
        p = Path(f.name)
        self.addCleanup(lambda: p.unlink(missing_ok=True))
        write_source(p, rows)
        return p


if __name__ == "__main__":
    unittest.main()
