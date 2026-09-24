import argparse
import csv
import hashlib
import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path
from unittest.mock import patch

TOOL = Path(__file__).resolve().parents[1] / 'post_broad_diagnostic_pack.py'
SPEC = importlib.util.spec_from_file_location('post_broad_diagnostic_pack', TOOL)
MOD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MOD)


def write_csv(path, fields, rows):
    with path.open('w', encoding='utf-8', newline='') as fh:
        writer=csv.DictWriter(fh,fieldnames=fields,lineterminator='\n')
        writer.writeheader(); writer.writerows(rows)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class PackTests(unittest.TestCase):
    def test_owner_additional_2_delimiters_at_diagnostic_exception_boundary(self):
        roots = ("<EVIDENCE_ROOT>/", "/home/", "Z:/Users/",
                 "//private-server/private-share/")
        tails = ("O'Brien/alice/private-root/file.json",
                 'D"Angelo/tenant/hidden-tree/file.json',
                 "segment\nalice/private-root/file.json",
                 "segment\r\nline\ntenant/hidden-tree/file.json",
                 "segment -> alice/private-root/file.json")
        for root in roots:
            for tail in tails:
                for separator in ("/", "\\"):
                    raw = (root + tail).replace("/", separator)
                    for wrapper in ("{}", "cannot read '{}'", 'cannot read "{}"'):
                        message = wrapper.format(raw)
                        for exc in (MOD.Refusal(message), OSError(5, message), OSError(5, "denied", raw)):
                            with self.subTest(raw=raw, wrapper=wrapper, kind=type(exc).__name__):
                                out, err = StringIO(), StringIO()
                                with patch.object(MOD, 'parser') as parser, patch.object(MOD, 'build', side_effect=exc):
                                    parser.return_value.parse_args.return_value = argparse.Namespace()
                                    with redirect_stdout(out), redirect_stderr(err):
                                        self.assertEqual(2, MOD.main())
                                self.assertEqual('', out.getvalue())
                                for secret in ('brien', 'angelo', 'alice', 'tenant', 'private-root',
                                               'hidden-tree', 'file.json', 'private-server', 'private-share'):
                                    self.assertNotIn(secret, err.getvalue().casefold())
                                self.assertEqual(err.getvalue(), MOD.portable_error(MOD.Refusal(err.getvalue())))

    def test_owner_additional_2_comparisons_at_diagnostic_exception_boundary(self):
        for operator in ('<', '>', '<=', '>='):
            message = f'expected {operator} 5 for reports/result.json'
            for exc in (MOD.Refusal(message), OSError(5, message)):
                with self.subTest(message=message, kind=type(exc).__name__):
                    out, err = StringIO(), StringIO()
                    with patch.object(MOD, 'parser') as parser, patch.object(MOD, 'build', side_effect=exc):
                        parser.return_value.parse_args.return_value = argparse.Namespace()
                        with redirect_stdout(out), redirect_stderr(err):
                            self.assertEqual(2, MOD.main())
                    self.assertEqual('', out.getvalue())
                    self.assertEqual('REFUSED: ' + message + '\n', err.getvalue())

    def test_owner_additional_3_malformed_placeholder_at_cli_boundary(self):
        tail = "subject'quoted/restricted-tree/file.json"
        windows_tail = tail.replace("/", "\\")
        cases = (
            "< EVIDENCE_ROOT " + tail,
            "cannot read '/srv/" + tail + "'",
            'cannot read "Q:/Users/' + tail + '"',
            'cannot read "\\\\node\\share\\' + windows_tail + '"',
            "< EVIDENCE_ROOT\nsubject/restricted-tree/file.json",
            "< EVIDENCE_ROOT <ANYTHING>/subject/restricted-tree/file.json",
            "< EVIDENCE_ROOT <EVIDENCE_ROOT>/subject/restricted-tree/file.json",
        )
        for message in cases:
            for exc in (MOD.Refusal(message), OSError(5, message)):
                with self.subTest(message=message, kind=type(exc).__name__):
                    out, err = StringIO(), StringIO()
                    with patch.object(MOD, 'parser') as parser, patch.object(MOD, 'build', side_effect=exc):
                        parser.return_value.parse_args.return_value = argparse.Namespace()
                        with redirect_stdout(out), redirect_stderr(err):
                            self.assertEqual(2, MOD.main())
                    self.assertEqual('', out.getvalue())
                    rendered = err.getvalue()
                    self.assertNotIn('restricted-tree', rendered.casefold())
                    self.assertNotIn('subject', rendered.casefold())
                    self.assertEqual(rendered, MOD.portable_error(MOD.Refusal(rendered)))
        for message in ('expected < 5 for reports/result.json',
                        'expected > 5 for reports/result.json'):
            for exc in (MOD.Refusal(message), OSError(5, message)):
                out, err = StringIO(), StringIO()
                with patch.object(MOD, 'parser') as parser, patch.object(MOD, 'build', side_effect=exc):
                    parser.return_value.parse_args.return_value = argparse.Namespace()
                    with redirect_stdout(out), redirect_stderr(err):
                        self.assertEqual(2, MOD.main())
                self.assertEqual('REFUSED: ' + message + '\n', err.getvalue())

    def test_owner_repair_cli_private_tails_and_ordinary_angles(self):
        paths = ["<EVIDENCE_ROOT>/Users/alice/private-root/file.json",
                 r"<EVIDENCE_ROOT>\Users\alice\private-root\file.json",
                 "/home/alice/private-root/file.json", r"\Users\alice\private-root\file.json",
                 r"Z:\Users\alice\private-root\file.json",
                 r"\\server-alice\share-secret\private-root\file.json"]
        for raw in paths:
            for exc in (MOD.Refusal("cannot read '" + raw + "'"), OSError(5, "denied", raw)):
                with self.subTest(raw=raw, exception=type(exc).__name__):
                    out, err = StringIO(), StringIO()
                    with patch.object(MOD, 'parser') as parser, patch.object(MOD, 'build', side_effect=exc):
                        parser.return_value.parse_args.return_value = argparse.Namespace()
                        with redirect_stdout(out), redirect_stderr(err):
                            self.assertEqual(2, MOD.main())
                    for secret in ('alice', 'private-root', 'server-alice', 'share-secret'):
                        self.assertNotIn(secret, err.getvalue().casefold())
                    self.assertEqual('', out.getvalue())
                    self.assertEqual(err.getvalue(), MOD.portable_error(MOD.Refusal(err.getvalue())))
        for message in ('expected < 5', 'value > threshold', 'a < b and c > d'):
            self.assertEqual(message, MOD.portable_error(MOD.Refusal(message)))

    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix='post broad pack ')
        self.root=Path(self.tmp.name)
    def tearDown(self):
        self.tmp.cleanup()

    def test_placeholder_refusals_are_closed_at_cli_boundary(self):
        paths = [
            "<ANYTHING>/Users/alice/private-root/file.json",
            "<EVIDENCE_ROOT>//Users/alice/private-root/file.json",
            "<EVIDENCE_ROOT>/<EVIDENCE_ROOT>/alice/private-root",
            r"<EVIDENCE_ROOT>/C:\Users\alice\private-root\file.json",
            r"<EVIDENCE_ROOT>/\\server-alice\private-root\file.json",
            r"<EVIDENCE_ROOT>/\\.\pipe\private-root",
            "<<EVIDENCE_ROOT>>/alice/private-root",
        ]
        for index, raw in enumerate(paths):
            for exc in (MOD.Refusal("cannot read '" + raw + "'"), OSError(5, "denied", raw)):
                with self.subTest(case=index, exception=type(exc).__name__):
                    out, err = StringIO(), StringIO()
                    with patch.object(MOD, 'parser') as parser, patch.object(MOD, 'build', side_effect=exc):
                        parser.return_value.parse_args.return_value = argparse.Namespace()
                        with redirect_stdout(out), redirect_stderr(err):
                            rc = MOD.main()
                    self.assertEqual(2, rc)
                    self.assertEqual('', out.getvalue())
                    self.assertIn('<UNSAFE_PATH_', err.getvalue())
                    self.assertNotIn('alice', err.getvalue().casefold())
                    self.assertNotIn('private-root', err.getvalue().casefold())
                    self.assertEqual(err.getvalue(), MOD.portable_error(MOD.Refusal(err.getvalue())))

    def make_fixture(self):
        unit_fields=['h3_run_id','symbol','period_name','source_position_id','source_deal_id','entry_utc','exit_utc','source_net_realized']
        detail_fields=['h3_run_id','window','year','symbol','tf','source_position_id','source_deal_id','entry_utc','exit_utc','source_net_realized','macro_state','local_state','vol_state']
        raw=[
            ('H3-C01-BWD','BWD','2020','XAUUSD','M15','1','11','2020-01-02T00:00:00Z','2020-01-03T00:00:00Z','10','NEUTRAL','RANGE','LOW'),
            ('H3-C01-BWD','BWD','2021','XAUUSD','M15','2','12','2021-02-02T00:00:00Z','2021-02-03T00:00:00Z','-5','NEUTRAL','RANGE','LOW'),
            ('H3-C01-MAIN','MAIN','2023','XAUUSD','M15','3','13','2023-01-02T00:00:00Z','2023-01-03T00:00:00Z','-8','NEUTRAL','TREND_DOWN','HIGH'),
            ('H3-C01-MAIN','MAIN','2024','XAUUSD','M15','4','14','2024-03-02T00:00:00Z','2024-03-03T00:00:00Z','1','NEUTRAL','TREND_UP','NORMAL'),
            ('H3-C02-MAIN','MAIN','2023','EURUSD','H1','5','15','2023-04-02T00:00:00Z','2023-04-03T00:00:00Z','3','STRESS','RANGE','NORMAL'),
            ('H3-C02-MAIN','MAIN','2024','EURUSD','H1','6','16','2024-04-02T00:00:00Z','2024-04-03T00:00:00Z','4','STRESS','RANGE','NORMAL'),
        ]
        units=[]; detail=[]
        for run,window,year,symbol,tf,pos,deal,entry,exit_,net,macro,local,vol in raw:
            units.append({'h3_run_id':run,'symbol':symbol,'period_name':'PERIOD_'+tf,'source_position_id':pos,
                          'source_deal_id':deal,'entry_utc':entry,'exit_utc':exit_,'source_net_realized':net})
            detail.append({'h3_run_id':run,'window':window,'year':year,'symbol':symbol,'tf':tf,
                           'source_position_id':pos,'source_deal_id':deal,'entry_utc':entry,'exit_utc':exit_,
                           'source_net_realized':net,'macro_state':macro,'local_state':local,'vol_state':vol})
        units_path=self.root/'units.csv'; detail_path=self.root/'detail.csv'
        write_csv(units_path,unit_fields,units); write_csv(detail_path,detail_fields,detail)
        cells=[
            {'cell_id':'H3-C01-BWD','index':1,'window':'BWD','symbol':'XAUUSD','tf':'M15','realized_unit_count':2,'report_trades':2},
            {'cell_id':'H3-C01-MAIN','index':2,'window':'MAIN','symbol':'XAUUSD','tf':'M15','realized_unit_count':2,'report_trades':2},
            {'cell_id':'H3-C02-BWD','index':3,'window':'BWD','symbol':'EURUSD','tf':'H1','realized_unit_count':0,'report_trades':0},
            {'cell_id':'H3-C02-MAIN','index':4,'window':'MAIN','symbol':'EURUSD','tf':'H1','realized_unit_count':2,'report_trades':2},
        ]
        source_pkg={'aggregate_units_sha256':sha(units_path),'holdout':'UNSPENT','cell_count':len(cells),'cells':cells}
        regime_pkg={'aggregate_units_sha256':sha(units_path),'holdout':'UNSPENT','output_sha256':{'regime_attribution_detail.csv':sha(detail_path)}}
        source_path=self.root/'source_package.json'; regime_path=self.root/'regime_package.json'
        source_path.write_text(json.dumps(source_pkg),encoding='utf-8'); regime_path.write_text(json.dumps(regime_pkg),encoding='utf-8')
        return units_path,source_path,detail_path,regime_path
    def args(self,out_name='out with spaces'):
        units,source,detail,regime=self.make_fixture()
        return argparse.Namespace(units=str(units),source_package=str(source),regime_detail=str(detail),
                                  regime_package=str(regime),out_dir=str(self.root/out_name),direct_consumer='fixture consumer')

    def test_outputs_no_entry_reversals_and_integrity(self):
        args=self.args()
        inputs={Path(value):Path(value).read_bytes() for value in
                (args.units,args.source_package,args.regime_detail,args.regime_package)}
        result=MOD.build(args)
        self.assertEqual(result['status'],'PASS')
        self.assertEqual(MOD.portable_path(Path(args.out_dir),repo_root=MOD.REPO_ROOT),result['output_dir'])
        self.assertNotRegex(result['output_dir'],r'(?i)^[a-z]:[/\\]')
        self.assertNotRegex(json.dumps(result),r'(?i)C:\\\\Users\\\\|D:\\\\EA_LAB_CONTROL\\\\')
        self.assertEqual(inputs,{path:path.read_bytes() for path in inputs})
        out=Path(args.out_dir)
        with (out/'participation_no_entry.csv').open(encoding='utf-8',newline='') as fh:
            rows=list(csv.DictReader(fh))
        no_entry=[r for r in rows if r['cell_id']=='H3-C02-BWD'][0]
        self.assertEqual(no_entry['participation_status'],'NO_ENTRY')
        with (out/'counterexamples_sign_reversals.csv').open(encoding='utf-8',newline='') as fh:
            kinds={r['counterexample_type'] for r in csv.DictReader(fh)}
        self.assertIn('REGIME_YEAR_SIGN_REVERSAL',kinds)
        self.assertIn('SYMBOL_TF_WINDOW_SIGN_REVERSAL',kinds)
        recon=json.loads((out/'reconciliation.json').read_text(encoding='utf-8'))
        self.assertTrue(recon['exact_key_set_match']); self.assertEqual(recon['status'],'PASS')
        MOD.validate_manifest(out/'report_package_manifest.json')
    def test_identical_inputs_are_byte_deterministic(self):
        args=self.args('out one'); MOD.build(args)
        first={p.name:p.read_bytes() for p in Path(args.out_dir).iterdir() if p.is_file()}
        args.out_dir=str(self.root/'out two'); MOD.build(args)
        second={p.name:p.read_bytes() for p in Path(args.out_dir).iterdir() if p.is_file()}
        self.assertEqual(first,second)

    def test_refuses_detail_key_loss_with_updated_detail_receipt(self):
        args=self.args(); detail=Path(args.regime_detail)
        with detail.open(encoding='utf-8',newline='') as fh:
            rows=list(csv.DictReader(fh))
        fields=list(rows[0])
        write_csv(detail,fields,rows[:-1])
        regime=Path(args.regime_package); data=json.loads(regime.read_text())
        data['output_sha256']['regime_attribution_detail.csv']=sha(detail)
        regime.write_text(json.dumps(data),encoding='utf-8')
        with self.assertRaisesRegex(MOD.Refusal,'key mismatch'):
            MOD.build(args)
    def test_refuses_per_key_net_change_with_updated_detail_receipt(self):
        args=self.args(); detail=Path(args.regime_detail)
        with detail.open(encoding='utf-8',newline='') as fh:
            rows=list(csv.DictReader(fh))
        fields=list(rows[0])
        rows[0]['source_net_realized']='999'; write_csv(detail,fields,rows)
        regime=Path(args.regime_package); data=json.loads(regime.read_text())
        data['output_sha256']['regime_attribution_detail.csv']=sha(detail)
        regime.write_text(json.dumps(data),encoding='utf-8')
        with self.assertRaisesRegex(MOD.Refusal,'net mismatch'):
            MOD.build(args)

    def test_refuses_package_count_change(self):
        args=self.args(); source=Path(args.source_package); data=json.loads(source.read_text())
        data['cells'][0]['realized_unit_count']=3
        source.write_text(json.dumps(data),encoding='utf-8')
        with self.assertRaisesRegex(MOD.Refusal,'cell count mismatch'):
            MOD.build(args)


    def test_refuses_non_unspent_holdout_metadata(self):
        args=self.args(); regime=Path(args.regime_package); data=json.loads(regime.read_text())
        data['holdout']='SPENT'; regime.write_text(json.dumps(data),encoding='utf-8')
        with self.assertRaisesRegex(MOD.Refusal,'HOLDOUT must be UNSPENT'):
            MOD.build(args)

    def test_refuses_holdout_detail_row_even_when_receipt_is_updated(self):
        args=self.args(); detail=Path(args.regime_detail)
        with detail.open(encoding='utf-8',newline='') as fh:
            rows=list(csv.DictReader(fh))
        fields=list(rows[0]); rows[0]['window']='HOLDOUT'; write_csv(detail,fields,rows)
        regime=Path(args.regime_package); data=json.loads(regime.read_text())
        data['output_sha256']['regime_attribution_detail.csv']=sha(detail)
        regime.write_text(json.dumps(data),encoding='utf-8')
        with self.assertRaisesRegex(MOD.Refusal,'HOLDOUT rows are not allowed'):
            MOD.build(args)


if __name__ == '__main__':
    unittest.main()
