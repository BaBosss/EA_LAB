import unittest

from scout import read_json, scout, shortlist, CATALOG_PATH


class ScoutTests(unittest.TestCase):
    def test_catalog_is_pinned_and_nonempty(self):
        catalog = read_json(CATALOG_PATH)
        self.assertEqual(catalog["upstream_sha"], "a5bcbc6a192386e7c625976082715dabed9bfb26")
        self.assertEqual(catalog["entry_count"], 118)
        self.assertEqual(len(catalog["entries"]), 118)
        self.assertEqual(catalog["license"], "CC0-1.0")

    def test_duplicate_capability_uses_existing(self):
        result = scout("MT5 backtest execution")
        self.assertEqual(result["decision"], "USE_EXISTING")
        self.assertEqual(result["existing"]["status"], "COVERED")
        self.assertEqual(result["shortlist"], [])

    def test_one_generic_token_does_not_mask_distinct_capability(self):
        result = scout("cross-sectional portfolio ranking backtest")
        self.assertEqual(result["decision"], "SCOUT")
        self.assertIsNone(result["existing"])
        self.assertFalse(result["automatic_install"])

    def test_exact_single_word_alias_still_uses_existing(self):
        result = scout("backtesting")
        self.assertEqual(result["decision"], "USE_EXISTING")
        self.assertEqual(result["existing"]["capability"], "backtest execution")
    def test_broker_execution_fails_closed(self):
        result = scout("broker execution MCP order placement")
        self.assertEqual(result["decision"], "BLOCKED_BY_DESIGN")
        self.assertEqual(result["shortlist"], [])
        self.assertFalse(result["automatic_install"])

    def test_scout_never_installs(self):
        result = scout("agent evaluation benchmark")
        self.assertEqual(result["decision"], "SCOUT")
        self.assertFalse(result["automatic_install"])
        self.assertTrue(result["shortlist"])
        self.assertTrue(all(x["install_state"] == "NOT_INSTALLED" for x in result["shortlist"]))
        self.assertTrue(all(x["candidate_review"]["downstream_license"] == "UNVERIFIED_MUST_VERIFY" for x in result["shortlist"]))

    def test_trades_live_wording_is_execution_exposed(self):
        catalog = read_json(CATALOG_PATH)
        candidates = shortlist("cross-sectional portfolio ranking backtest", catalog["entries"], limit=10)
        ai_trader = [x for x in candidates if x["name"] == "HKUDS/AI-Trader"]
        self.assertEqual(len(ai_trader), 1)
        self.assertEqual(ai_trader[0]["authority_class"], "EXECUTION_EXPOSED")
        self.assertEqual(ai_trader[0]["decision"], "PARK_BLOCKED_BY_DESIGN")
    def test_dangerous_catalog_items_are_parked(self):
        catalog = read_json(CATALOG_PATH)
        candidates = shortlist("alpaca live trading", catalog["entries"], limit=10)
        alpaca = [x for x in candidates if x["name"] == "alpacahq/alpaca-mcp-server"]
        self.assertEqual(len(alpaca), 1)
        self.assertEqual(alpaca[0]["authority_class"], "EXECUTION_EXPOSED")
        self.assertEqual(alpaca[0]["decision"], "PARK_BLOCKED_BY_DESIGN")


if __name__ == "__main__":
    unittest.main(verbosity=2)
