import argparse
import csv
import hashlib
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

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
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix='post broad pack ')
        self.root=Path(self.tmp.name)
    def tearDown(self):
        self.tmp.cleanup()

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
        args=self.args(); result=MOD.build(args)
        self.assertEqual(result['status'],'PASS')
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
