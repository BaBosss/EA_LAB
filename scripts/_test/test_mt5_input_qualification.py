"""Prospective D-001 offline input contract; no tester execution or evidence rewrite."""
import html
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
import parse_mt5_report as parser


def report_html(overrides=None):
    """Synthetic complete settings/results schema, explicitly not measured data."""
    fields = {
        'Expert:': 'Fixture', 'Symbol:': 'XAUUSD', 'Company:': 'Fixture Broker',
        'Period:': 'H1 (2023.01.01 - 2025.12.31)', 'Currency:': 'USD',
        'Leverage:': '1:100', 'Initial Deposit:': '10 000.00',
        'History Quality:': '100% real ticks', 'Bars:': '100', 'Ticks:': '1000',
        'Symbols:': '1', 'Total Net Profit:': '0.00', 'Gross Profit:': '0.00',
        'Gross Loss:': '0.00', 'Profit Factor:': '0.00', 'Total Trades:': '0',
        'Total Deals:': '0', 'Balance Drawdown Absolute:': '0.00',
        'Equity Drawdown Absolute:': '0.00',
        'Balance Drawdown Maximal:': '0.00 (0.00%)',
        'Equity Drawdown Maximal:': '0.00 (0.00%)',
        'Balance Drawdown Relative:': '0.00% (0.00)',
        'Equity Drawdown Relative:': '0.00% (0.00)',
    }
    fields.update(overrides or {})
    rows = ''.join('<tr><td>' + html.escape(k) + '</td><td><b>' + html.escape(str(v)) +
                   '</b></td></tr>' for k, v in fields.items() if v is not None)
    return ('<html><head><title>Strategy Tester Report Build 6090</title></head>'
            '<body><table>' + rows + '</table></body></html>')


class InputQualificationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / 'input.htm'

    def tearDown(self):
        self.temp.cleanup()

    def write(self, text, encoding='utf-16-le'):
        self.path.write_bytes(text.encode(encoding))
        return self.path

    def refuse(self, text):
        with self.assertRaises(parser.ReportQualificationError):
            parser.parse_report(self.write(text))
        run = subprocess.run([sys.executable, '-B', str(ROOT / 'scripts/parse_mt5_report.py'),
                              str(self.path), '--json'], capture_output=True, text=True)
        self.assertEqual(run.returncode, 1)
        result = json.loads(run.stdout)
        self.assertEqual(result['status'], 'PARSE_ERROR')
        self.assertNotIn('net_profit', result)
        self.assertNotIn('ea_name', result)

    def test_wrong_files_api_and_cli(self):
        for text in ['', '# Strategy Tester Report\nExpert: Fixture',
                     'Expert: Fixture\nSymbol: XAUUSD\nTotal Net Profit: 0',
                     '<html><body><h1>hello</h1></body></html>',
                     '<html><head><title>Strategy Tester Report</title></head><body></body></html>',
                     '<!--' + report_html() + '-->',
                     report_html().replace('Strategy Tester Report Build 6090', 'Optimization Results'),
                     report_html().replace('Build 6090', '') + '<!-- Build 6090 -->',
                     report_html().replace('Expert:', 'Report:')]:
            with self.subTest(text=text[:75]):
                self.refuse(text)

    def test_truncation_and_wrong_structure(self):
        good = report_html()
        cases = [good[:n] for n in (1, 40, len(good)//2, len(good)-1, len(good)-14)]
        cases += [good + '<!-- unfinished', good.replace('</td>', '', 1), good.replace('</tr>', '', 1),
                  good.replace('<tr>', '<div>', 1), good + good,
                  good.replace('Expert:</td><td>', 'Expert:</td></tr><tr><td>'),
                  good.replace('<body>', '<body><script>'),
                  good.replace('</table>', '</table><table><tr><td>Expert:</td><td>Other</td></tr></table>'),
                  good.replace('<table>', '<table><table>'),
                  good.replace('</table>', '<tr><td>Symbol:</td><td>EURUSD</td></tr></table>'),
                  good.replace('<td>Expert:</td>', '<!-- <td>Expert:</td> -->')]
        for text in cases:
            with self.subTest(text=text[:60], length=len(text)):
                self.refuse(text)

    def test_report_tables_in_unsupported_containers_are_refused(self):
        good = report_html()
        for container in ('textarea', 'select', 'option', 'datalist', 'button',
                          'template', 'iframe', 'object', 'noscript'):
            with self.subTest(container=container):
                self.refuse(good.replace('<table>', f'<{container}><table>')
                                .replace('</table>', f'</table></{container}>'))

    def test_build_identity_is_bound_and_unambiguous(self):
        missing = report_html({'Expert:': 'Fixture Build 6090'}).replace(
            'Strategy Tester Report Build 6090', 'Strategy Tester Report')
        conflicting = report_html().replace(
            '<table>', '<table><tr><td>Fixture Broker (Build 6091)</td></tr>')
        self.refuse(missing)
        self.refuse(conflicting)

        equivalent = report_html().replace(
            '<table>', '<table><tr><td>Fixture Broker (Build 6090)</td></tr>')
        self.assertEqual(parser.parse_report(self.write(equivalent))['report_build'], 6090)

    def test_required_fields_cannot_default_or_cross_cells(self):
        required = ['Expert:', 'Symbol:', 'Company:', 'Currency:', 'Leverage:', 'Period:',
                    'Initial Deposit:', 'Bars:', 'Ticks:', 'Symbols:', 'Total Net Profit:',
                    'Gross Profit:', 'Gross Loss:', 'Profit Factor:', 'Total Trades:', 'Total Deals:',
                    'Balance Drawdown Absolute:', 'Equity Drawdown Absolute:',
                    'Balance Drawdown Maximal:', 'Equity Drawdown Maximal:']
        for field in required:
            for value in ('', None):
                with self.subTest(field=field, value=value):
                    self.refuse(report_html({field: value}))

    def test_malformed_values(self):
        for field, value in [('Period:', 'H1 (2023.02.30 - 2025.12.31)'),
                             ('Period:', 'H1 (2025.01.01 - 2023.01.01)'),
                             ('Period:', 'garbage'), ('Total Trades:', '1.5'),
                             ('Ticks:', '-1'), ('Initial Deposit:', '12 34.56'),
                             ('Gross Profit:', '1,2,3'), ('Profit Factor:', 'NaN'),
                             ('Profit Factor:', '9'*400),
                             ('Equity Drawdown Maximal:', 'broken'),
                             ('Average profit trade:', ''), ('AHPR:', '1.0 (bad)'),
                             ('Short Trades (won %):', '1.5 (40%)'),
                             ('Maximum consecutive wins ($):', '3 (bad)'),
                             ('Equity Drawdown Relative:', '1% trailing')]:
            with self.subTest(field=field, value=value):
                self.refuse(report_html({field: value}))

    def test_valid_encodings_zero_trades_grouping_and_inline_labels(self):
        for encoding in ('utf-8', 'utf-8-sig', 'utf-16', 'utf-16-le', 'utf-16-be'):
            raw = report_html({'Gross Profit:': '12,345.67', 'Gross Loss:': '-12 345.67'})
            if encoding == 'utf-16-be':
                self.path.write_bytes(b'\xfe\xff' + raw.encode(encoding))
            else:
                self.write(raw, encoding)
            result = parser.parse_report(self.path)
            self.assertEqual(result['total_trades'], 0)
            self.assertEqual(result['gross_profit'], 12345.67)
            self.assertEqual(result['gross_loss'], -12345.67)
        result = parser.parse_report(self.write(report_html().replace('Expert:', '<b>Expert:</b>')))
        self.assertEqual(result['ea_name'], 'Fixture')

    def test_optional_aliases_and_grouped_numbers_preserved(self):
        result = parser.parse_report(self.write(report_html({
            'Avg profit trade:': '12.34', 'Avg loss trade:': '-5.67',
            'Short Trades (won %):': '1,000 (50.00%)',
            'Maximum consecutive wins ($):': '3 (1 234.56)',
            'AHPR:': '1.0000 (0.00%)'})))
        self.assertEqual(result['avg_profit_trade'], 12.34)
        self.assertEqual(result['avg_loss_trade'], -5.67)
        self.assertEqual(result['short_trades'], 1000)
        self.assertEqual(result['max_consecutive_wins'], 3)
        self.assertEqual(result['ahpr'], 1)
        self.refuse(report_html({'Average profit trade:': '', 'Avg profit trade:': '99.00'}))

    def test_invalid_encoding_refused(self):
        for raw in (b'\xff\xfeA', b'\xffinvalid', report_html().encode() + b'\x00'):
            self.path.write_bytes(raw)
            with self.assertRaises(parser.ReportQualificationError):
                parser.parse_report(self.path)

    def test_d001_2_raw_start_token_matrix(self):
        good = report_html()
        for tag in ('table', 'tr', 'td'):
            for suffix in (' / >', ' /\t>', ' /\n>', ' //>',
                           ' width>', ' width />', ' width=>', ' width= >', ' width==1>',
                           ' width=1=2>', ' width="1" width="2">',
                           ' width="1" WIDTH="2">', ' width="1"x="2">',
                           ' width="unfinished>', " width='unfinished>",
                           ' width=<bad>>', ' width="<bad>">',
                           ' <bad>', ' /x>', '/', '>', '/>'):
                # A bare > is the valid control; every other mutation refuses.
                if suffix == '>':
                    continue
                with self.subTest(tag=tag, suffix=suffix):
                    self.refuse(good.replace('<'+tag+'>', '<'+tag+suffix, 1))

    def test_d001_2_raw_closing_and_incomplete_tokens(self):
        good = report_html()
        for tag in ('table', 'tr', 'td', 'body', 'html'):
            for suffix in (' x>', ' x="1">', '/>', ' / >', '<>', '=x>', ''):
                with self.subTest(tag=tag, suffix=suffix):
                    self.refuse(good.replace('</'+tag+'>', '</'+tag+suffix, 1))
        for token in ('<', '</', '<table', '<table x="', '</table', '<!--', '<!'):
            with self.subTest(trailing=token):
                self.refuse(good + token)
        # Tolerant end-of-input recovery must not eat an unfinished raw token.
        for token in ('<', '</', '<table / >', '<img src=>'):
            with self.subTest(in_body=token):
                self.refuse(good.replace('</body>', token+'</body>'))

    def test_d001_2_valid_tokens_and_opaque_content(self):
        good = report_html()
        cases = [good.replace('<table>', '<TaBlE width="100%" border=1 cellpadding=0>')
                     .replace('</table>', '</TABLE >'),
                 good.replace('<table>', "<table data-note='a > b &lt; c / >' title=report>"),
                 good.replace('<td>', '<td\n align = "right" >'),
                 good.replace('<head>', '<head><meta charset="utf-8"><link rel="x" href="x"/>'),
                 good.replace('<body>', '<body><br><br/><hr /><img src="a.png">'),
                 good.replace('<body>', '<body><input disabled><input checked="checked"/>'),
                 good.replace('<body>', '<body><!-- <table / ><script><td x=> -->'),
                 good.replace('</head>', '<style>p::before { content: "<table / >"; } '
                              'x < y; </stylex> <!-- </head> --> </style></head>'),
                 good.replace('<body><table>', '<body><div><table>')
                     .replace('</table>', '</table></div>'),
                 '<!DOCTYPE HTML>'+good,
                 good.replace('<body>', '<body>&lt;table / &gt;')]
        expected = parser.parse_report(self.write(good))
        for index, text in enumerate(cases):
            with self.subTest(case=index):
                self.assertEqual(parser.parse_report(self.write(text)), expected)

    def test_style_data_cannot_supply_report_identity_or_fields(self):
        good = report_html()
        missing_expert = good.replace('<td>Expert:</td>',
                                      '<td><style>Expert:</style></td>')
        missing_build = good.replace('Strategy Tester Report Build 6090',
                                     'Strategy Tester Report').replace(
            '<table>', '<table><tr><td><style>Build 6090</style></td></tr>')
        title_from_style = good.replace('Strategy Tester Report Build 6090',
                                        'Strategy Tester Report<style> Build 6090</style>')
        style_only_value = good.replace('<td><b>Fixture</b></td>',
                                        '<td><style>Fixture</style></td>', 1)
        for name, report in (('expert label', missing_expert),
                             ('preamble build', missing_build),
                             ('title build', title_from_style),
                             ('required value', style_only_value)):
            with self.subTest(source=name):
                self.refuse(report)

    def test_style_beside_real_cell_text_is_ignored(self):
        good = report_html()
        expected = parser.parse_report(self.write(good))
        cases = (
            good.replace('<td>Expert:</td>',
                         '<td>Expert:<style>Build 6090</style></td>'),
            good.replace('<td><b>Fixture</b></td>',
                         '<td><b>Fixture</b><style>Other Expert:</style></td>', 1),
            good.replace('</head>', '<style>Build 6091; Expert:; '
                         'content: "<table / >"; x < y;</style></head>'),
        )
        for index, report in enumerate(cases):
            with self.subTest(case=index):
                self.assertEqual(parser.parse_report(self.write(report)), expected)

    def test_style_raw_tokens_remain_opaque(self):
        good = report_html()
        styled = good.replace('</head>', '<style>content: "<table / >"; '
                              'x < y; </stylex> <!-- </head> --> </style></head>')
        self.assertEqual(parser.parse_report(self.write(styled)),
                         parser.parse_report(self.write(good)))

    def test_d001_4_decimal_conflicts(self):
        scalar_aliases = (
            ('Average profit trade:', 'Avg profit trade:'),
            ('Average loss trade:', 'Avg loss trade:'),
            ('Average consecutive wins:', 'Avg consecutive wins:'),
            ('Average consecutive losses:', 'Avg consecutive losses:'))
        pairs = [('9007199254740992', '9007199254740993'),
                 ('1.00000000000000000000000000001', '1.00000000000000000000000000002'),
                 ('0.'+'0'*60+'1', '0.'+'0'*60+'2'), ('1', '2')]
        for labels in scalar_aliases:
            for left, right in pairs:
                with self.subTest(labels=labels, left=left, right=right):
                    self.refuse(report_html(dict(zip(labels, (left, right)))))
        for labels in (('Maximum consecutive wins ($):', 'Max consecutive wins:'),
                       ('Maximum consecutive losses ($):', 'Max consecutive losses:')):
            for left, right in pairs:
                for values in ((left+' (1)', right+' (1)'),
                               ('1 ('+left+')', '1 ('+right+')')):
                    with self.subTest(labels=labels, values=values):
                        self.refuse(report_html(dict(zip(labels, values))))

    def test_d001_4_decimal_equivalence(self):
        pairs = [('1', '1.0'), ('1.00', '1.000'), ('-0', '0'),
                 ('1,234,567.00', '1 234 567'),
                 ('9007199254740993', '9 007 199 254 740 993.00'),
                 ('1.00000000000000000000000000001', '1.000000000000000000000000000010')]
        for left, right in pairs:
            with self.subTest(left=left, right=right):
                parsed = parser.parse_report(self.write(report_html({
                    'Average profit trade:': left, 'Avg profit trade:': right,
                    'Maximum consecutive wins ($):': '3 ('+left+')',
                    'Max consecutive wins:': '3.0 ('+right+')'})))
                self.assertEqual(parsed['avg_profit_trade'], parser.pn(left))
                self.assertEqual(parsed['max_consecutive_wins'], 3)

    def test_d001_4_malformed_aliases_refuse_entire_input(self):
        for invalid in ('', '1e0', 'NaN', 'Infinity', '1,23', '1  000', '1.0junk', '--1'):
            for reverse in (False, True):
                values = (invalid, '1') if reverse else ('1', invalid)
                with self.subTest(invalid=invalid, reverse=reverse):
                    self.refuse(report_html(dict(zip(
                        ('Average profit trade:', 'Avg profit trade:'), values))))
                    self.refuse(report_html(dict(zip(
                        ('Maximum consecutive wins ($):', 'Max consecutive wins:'),
                        ('3 ('+v+')' for v in values)))))

    def test_d001_1_d001_3_retained_controls(self):
        good = report_html()
        for tag in parser._ReportHTML.NON_REPORT_CONTAINERS | {'span', 'p'}:
            with self.subTest(container=tag):
                self.refuse(good.replace('<table>', '<'+tag+'><table>')
                            .replace('</table>', '</table></'+tag+'>'))
        for title in ('Other Strategy Tester Report Build 6090',
                      'Strategy Tester Report Build 6090 extra', 'Strategy Tester Report'):
            with self.subTest(title=title):
                self.refuse(good.replace('Strategy Tester Report Build 6090', title))
        for borrowed in ('<p>Build 6090</p>', '<!-- Build 6090 -->',
                         '<div title="Build 6090"></div>'):
            self.refuse(good.replace(' Build 6090', '').replace('<body>', '<body>'+borrowed))
        preamble = good.replace(' Build 6090', '').replace(
            '<table>', '<table><tr><td>Broker Build 6090</td></tr>')
        self.assertEqual(parser.parse_report(self.write(preamble))['report_build'], 6090)
        self.assertEqual(parser._ReportHTML().qualified_fields(good)['expert:'], 'Fixture')

    def test_qualified_template_reports_equal_base_outputs(self):
        # Immutable baseline source is only an oracle for these qualified reports.
        source = subprocess.check_output(['git', '-C', str(ROOT), 'show',
            '5e84dd3e7c662e80e631d7f9e72903d0ba2420c6:scripts/parse_mt5_report.py'])
        baseline = {}
        exec(compile(source, 'base_parser', 'exec'), baseline)
        paths = sorted((ROOT / 'ea_template/regression_reports/build6090').glob('*.htm'))
        self.assertEqual(len(paths), 8)
        for path in paths:
            with self.subTest(report=path.name):
                self.assertEqual(parser.parse_report(path), baseline['parse_report'](path))


if __name__ == '__main__':
    unittest.main(verbosity=2)
