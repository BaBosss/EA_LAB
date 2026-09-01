import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import audit_h3_unit_suitability as m


def mini_report(position=False, basket=False):
    pos = '<td><b>Position</b></td>' if position else ''
    basket_text = ' basket_id=B1' if basket else ''
    html = f'''<html><body><table>
<tr><th><b>Orders</b></th></tr>
<tr><td><b>Open Time</b></td><td><b>Order</b></td><td><b>Symbol</b></td><td><b>Type</b></td><td><b>Volume</b></td><td><b>Price</b></td><td><b>S / L</b></td><td><b>T / P</b></td><td><b>Time</b></td><td><b>State</b></td><td><b>Comment</b></td></tr>
<tr><td>2023.01.01 00:00:00</td><td>2</td><td>XAUUSD</td><td>buy stop</td><td>0.01 / 0.01</td><td>1800</td><td></td><td></td><td>2023.01.01 01:00:00</td><td>filled</td><td>B19 L1{basket_text}</td></tr>
</table><table>
<tr><th><b>Deals</b></th></tr>
'''
    html += f'''<tr><td><b>Time</b></td><td><b>Deal</b></td><td><b>Symbol</b></td><td><b>Type</b></td><td><b>Direction</b></td><td><b>Volume</b></td><td><b>Price</b></td><td><b>Order</b></td><td><b>Commission</b></td><td><b>Swap</b></td><td><b>Profit</b></td><td><b>Balance</b></td><td><b>Comment</b></td>{pos}</tr>
<tr><td>2023.01.01 01:00:00</td><td>2</td><td>XAUUSD</td><td>buy</td><td>in</td><td>0.01</td><td>1800</td><td>2</td><td>0</td><td>0</td><td>0</td><td>10000</td><td>B19 L1{basket_text}</td></tr>
<tr><td>2023.01.02 01:00:00</td><td>3</td><td>XAUUSD</td><td>sell</td><td>out</td><td>0.01</td><td>1820</td><td>3</td><td>0</td><td>0</td><td>20</td><td>10020</td><td></td></tr>
</table></body></html>'''
    return html.encode('utf-16')


class SuitabilityTests(unittest.TestCase):
    def test_standard_report_schema_has_no_position_identity(self):
        tables = m.parse_report_tables(mini_report())
        oh, _ = m.split_table(tables['Orders'], m.EXPECTED_ORDER_HEADER)
        dh, _ = m.split_table(tables['Deals'], m.EXPECTED_DEAL_HEADER)
        self.assertEqual(oh, m.EXPECTED_ORDER_HEADER)
        self.assertEqual(dh, m.EXPECTED_DEAL_HEADER)
        self.assertFalse(any('position' in x.lower() for x in dh))

    def test_open_and_close_order_ids_are_not_a_link(self):
        tables = m.parse_report_tables(mini_report())
        _, deals = m.split_table(tables['Deals'], m.EXPECTED_DEAL_HEADER)
        ins = {r[7] for r in deals if r[4] == 'in'}
        outs = {r[7] for r in deals if r[4] == 'out'}
        self.assertEqual(ins & outs, set())
    def test_out_deal_has_close_fields_not_entry_timestamp_field(self):
        tables = m.parse_report_tables(mini_report())
        dh, deals = m.split_table(tables['Deals'], m.EXPECTED_DEAL_HEADER)
        out = [r for r in deals if r[4] == 'out'][0]
        self.assertEqual(out[0], '2023.01.02 01:00:00')
        self.assertEqual(out[10], '20')
        self.assertNotIn('Open Time', dh)
        self.assertNotIn('Entry Time', dh)

    def test_contract_forbids_inferred_linkage_methods(self):
        self.assertEqual(
            m.FORBIDDEN_INFERENCES,
            ['FIFO', 'TEMPORAL_PROXIMITY', 'VOLUME_MATCH', 'ORDER_SEQUENCE', 'P_AND_L_MATCH'],
        )

    def test_frozen_identity_constants(self):
        self.assertEqual(len(m.EXPECTED_H3_SHA), 64)
        self.assertEqual(len(m.EXPECTED_TIMELINE_SHA), 64)
        self.assertEqual(m.BLOCKED, 'BLOCKED(EVIDENCE_UNSUITABLE_FOR_UNIT_ATTRIBUTION)')


if __name__ == '__main__':
    unittest.main()
