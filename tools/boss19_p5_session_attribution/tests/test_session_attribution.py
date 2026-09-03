from __future__ import annotations

import importlib.util
import unittest
from datetime import datetime
from decimal import Decimal
from pathlib import Path

MODULE = Path(__file__).resolve().parents[1] / "build_session_attribution.py"
spec = importlib.util.spec_from_file_location("p5session", MODULE)
mod = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(mod)


def row(window: str, year: int, month: int, home: str, net: str, session: str) -> dict:
    symbol, tf = home.split("|")
    return {
        "window": window, "year": str(year), "entry_month": f"{year:04d}-{month:02d}",
        "home": home, "symbol": symbol, "tf": tf, "session_state": session,
        "net": Decimal(net), "exit_dt": datetime(year, month, 15), "source_deal_id": str(year * 100 + month),
    }


class SessionAttributionTests(unittest.TestCase):
    def test_exact_boundaries(self) -> None:
        cases = {
            "2024-01-01T00:00:00Z": "ASIA", "2024-01-01T06:59:59Z": "ASIA",
            "2024-01-01T07:00:00Z": "LONDON", "2024-01-01T11:59:59Z": "LONDON",
            "2024-01-01T12:00:00Z": "LONDON_NY_OVERLAP", "2024-01-01T15:59:59Z": "LONDON_NY_OVERLAP",
            "2024-01-01T16:00:00Z": "NEW_YORK_ONLY", "2024-01-01T20:59:59Z": "NEW_YORK_ONLY",
            "2024-01-01T21:00:00Z": "OUTSIDE_DEFINED_SESSION", "2024-01-01T23:59:59Z": "OUTSIDE_DEFINED_SESSION",
        }
        for ts, expected in cases.items():
            self.assertEqual(mod.classify_session(ts), expected)

    def test_distributed_positive_context_is_candidate(self) -> None:
        rows = []
        for window, years in (("MAIN", (2023, 2024, 2025)), ("BWD", (2020, 2021, 2022))):
            for i, year in enumerate(years):
                rows.append(row(window, year, 1 + i, "XAUUSD|H1", "10", "ASIA"))
                rows.append(row(window, year, 4 + i, "EURUSD|H4", "10", "ASIA"))
        _, summary = mod.loo_rows(rows, "2026-09-03T13:00:00Z")
        self.assertEqual(summary["ASIA"]["direction"], "POSITIVE")
        self.assertTrue(summary["ASIA"]["context_candidate"])

    def test_single_year_dependence_fails_candidate(self) -> None:
        rows = []
        for window, years in (("MAIN", (2023, 2024, 2025)), ("BWD", (2020, 2021, 2022))):
            for i, year in enumerate(years):
                value = "100" if i == 0 else "-20"
                rows.append(row(window, year, 1 + i, "XAUUSD|H1", value, "LONDON"))
                rows.append(row(window, year, 4 + i, "EURUSD|H4", value, "LONDON"))
        _, summary = mod.loo_rows(rows, "2026-09-03T13:00:00Z")
        self.assertEqual(summary["LONDON"]["direction"], "POSITIVE")
        self.assertFalse(summary["LONDON"]["context_candidate"])

    def test_outside_is_never_named_candidate(self) -> None:
        summary = {s: {"direction": "MIXED_OR_ZERO", "context_candidate": False} for s in mod.NAMED_SESSIONS}
        decision, candidates = mod.decide(summary)
        self.assertEqual(decision, "P5_SESSION_CONTEXT_FALSIFIED_STOP_EXPANSION_PARK")
        self.assertEqual(candidates, [])


if __name__ == "__main__":
    unittest.main()
