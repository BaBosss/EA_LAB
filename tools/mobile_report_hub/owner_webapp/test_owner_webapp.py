import json, pathlib, sys, tempfile, unittest
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parent))
from model import Refused, _DashboardParser, clean, safe_bytes, digest, number, age_state
class OwnerWebAppUnitTests(unittest.TestCase):
    def test_clean_redacts_local_paths_and_private_numbers(self):
        out=clean(r"see D:\secret\thing.txt account 1234567890")
        self.assertNotIn("D:\\secret",out)
        self.assertNotIn("1234567890",out)
        self.assertIn("[local path]",out)
        self.assertIn("[private ID]",out)
    def test_number_fail_closed(self):
        self.assertIsNone(number(float("nan")))
        self.assertIsNone(number(True))
        self.assertEqual(number("12.5"),12.5)
    def test_safe_bytes_root_and_limit(self):
        with tempfile.TemporaryDirectory() as td:
            root=pathlib.Path(td); inside=root/"a.txt"; inside.write_text("abc",encoding="utf-8")
            outside=root.parent/(root.name+"_outside.txt"); outside.write_text("x",encoding="utf-8")
            try:
                self.assertEqual(safe_bytes(inside,root),b"abc")
                with self.assertRaises(Refused): safe_bytes(outside,root)
                with self.assertRaises(Refused): safe_bytes(inside,root,limit=2)
            finally: outside.unlink(missing_ok=True)
    def test_digest_stable(self):
        self.assertEqual(digest(b"abc"),"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    def test_dashboard_parser_preserves_performance_table(self):
        html='<div class="card acct-card"><div class="acct-head"><b>123456789</b> · Demo · window: from 2026-01-01 · net 12.5 · 2 trades</div><table><tr><th>EA</th><th>Trades</th><th>Net P&amp;L</th><th>PF</th></tr><tr class="st-green"><td>EA-A</td><td>2</td><td>12.5</td><td>1.4</td></tr></table></div>'
        p=_DashboardParser(); p.feed(html)
        self.assertEqual(len(p.cards),1)
        self.assertIn('123456789',p.cards[0]['head'])
        self.assertEqual([c['text'] for c in p.cards[0]['rows'][0]['cells']],['EA','Trades','Net P&L','PF'])
        self.assertEqual(p.cards[0]['rows'][1]['class'],'st-green')
if __name__=="__main__": unittest.main()
