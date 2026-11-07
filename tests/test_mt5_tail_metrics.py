"""Tests for scripts/mt5_tail_metrics.py (reporting-only tail metrics)."""
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import mt5_tail_metrics as tm  # noqa: E402

FIXTURE = ROOT / "ea_template/regression_reports/build6090/TPLBASE6090_Boss_15_ST03.htm"


class Helpers(unittest.TestCase):
    def test_cvar_takes_worst_tail_mean(self):
        vals = list(range(-10, 30))  # n=40 -> k=2 -> worst two: -10, -9
        cvar, var = tm._cvar(vals)
        self.assertEqual(cvar, -9.5)
        self.assertEqual(var, -9)

    def test_cvar_minimum_one_value(self):
        self.assertEqual(tm._cvar([5.0, -3.0, 1.0]), (-3.0, -3.0))

    def test_months_inclusive_span(self):
        from datetime import datetime
        self.assertEqual(tm._months(datetime(2023, 11, 5), datetime(2024, 2, 1)),
                         ["2023-11", "2023-12", "2024-01", "2024-02"])


@unittest.skipUnless(FIXTURE.exists(), "regression report fixture missing")
class OnRealReport(unittest.TestCase):
    def test_reconciles_and_counts(self):
        m = tm.compute(FIXTURE)
        self.assertAlmostEqual(sum(x["pl"] for x in m["monthly"]), m["net_profit"], delta=1.0)
        self.assertEqual(m["closed_deals"], int(m["total_trades"]))
        self.assertEqual(m["months"], 6)  # 2024.01.01 -> 2024.07.01, end exclusive
        self.assertTrue(m["low_n_months"])
        self.assertLessEqual(m["trade_cvar95"], m["trade_var95"])
        self.assertLessEqual(m["trade_worst"], m["trade_cvar95"])

    def test_reconciliation_guard_fires(self):
        orig = tm.extract_deals
        try:
            tm.extract_deals = lambda p: [dict(d, pl=d["pl"] + 5.0) for d in orig(p)]
            with self.assertRaises(tm.TailMetricsError):
                tm.compute(FIXTURE)
        finally:
            tm.extract_deals = orig


if __name__ == "__main__":
    unittest.main()
