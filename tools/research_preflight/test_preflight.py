"""Synthetic offline fixtures. No EA results, lane claims, or MT5 processes."""
import copy
import hashlib
import json
import statistics
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import preflight as p

SOURCE = b'fixture source only'
REF = '1' * 40


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


class Fixture:
    def __init__(self, root, source=SOURCE, ref=REF, source_path='fixture.mq5'):
        self.root, self.source, self.ref = root, source, ref
        self.contract = dict(schema=p.SCHEMA, contract_id='SYNTHETIC-NOT-A-RUN', source_sha=ref,
                             source_path=source_path, hypothesis='FIXTURE', revision='r1', parent='FIXTURE-PARENT',
                             holdout=dict(from_date='2026.01.01', to_date='2026.12.31'), cells=[])
        self.observation = dict(schema='research-preflight-observation/1', contract_sha256='', cells={})
        for window, start, end in [('MAIN','2023.01.01','2025.12.31'), ('BWD','2020.01.01','2022.12.31')]:
            expected = dict(symbol='XAUUSD', tf='H1', leverage='1:100', model='1', from_date=start,
                            to_date=end, optimization='0', forward='0', deposit='10000', currency='USD',
                            expert='EALabTpl/Fixture', installation=r'D:\Meta 5',
                            installation_lineage='SYNTHETIC-LINEAGE', account_identity='SYNTHETIC-ACCOUNT',
                            lane='MT5-lane1', report_name='FIXTURE_'+window,
                            tester_report_path=rf'D:\Meta 5\FIXTURE_{window}.htm',
                            launch_ini_path=rf'D:\FIXTURE\{window}\tester.ini')
            cell = dict(cell_id=window, pair_id='PAIR', window=window, expected=expected,
                        parameters={'InpSignal':'92', 'InpLots':'0.01'}, effective_config={'signal':92,'lots':0.01},
                        inputs={}, outputs={k:f'{window}/{k}.{ext}' for k,ext in
                          [('report','htm'),('log','log'),('year_split','json'),('metrics','json'),('truncation','json')]},
                        native_graph_required=True, graph_paths=[f'{window}/graph.png'], end_condition='FULL_WINDOW')
            self.contract['cells'].append(cell)
            tester = '\n'.join(f'{key}={expected[field]}' for field,key in p.INI_KEYS.items())
            ini = '[Tester]\n' + tester + '\n[TesterInputs]\nInpSignal=92\nInpLots=0.01\n'
            inp = cell['inputs']
            inp['ini'] = self.write(f'{window}/tester.ini', ini.encode())
            inp['set'] = self.write(f'{window}/full.set', b'InpSignal=92\nInpLots=0.01\n')
            inp['ex5'] = self.write(f'{window}/fixture.ex5', b'SYNTHETIC-NONEXECUTABLE')
            inp['build_receipt'] = self.write_json(f'{window}/build.json', dict(schema='build_receipt/1',
                  build_receipt='SYNTHETIC', artifact_sha256=inp['ex5']['sha256'], source_sha256=sha(source)))
            inp['source_manifest'] = self.write_json(f'{window}/source.json', dict(source_sha=ref,
                            source_path=source_path, files={source_path:sha(source)}))
            inp['identity'] = self.write_json(f'{window}/identity.json', dict(source_sha=ref, source_path=source_path,
                            identity=expected, lane_state='RUNNING', runtime_legal=True,
                            requested_config=cell['parameters'], effective_config=cell['effective_config']))
            report = ('<html>Expert:\nFixture\nSymbol:\nXAUUSD\nCurrency:\nUSD\nPeriod:\n'
                      f'H1 ({start} - {end})\nInitial Deposit:\n10000\nLeverage:\n1:100\n'
                      '<img src="graph.png"></html>').encode('utf-16-le')
            post = self.observation['cells'][window] = {}
            post['report'] = self.write(cell['outputs']['report'], report)
            # Signature fixture only: no claim to be an MT5-generated equity curve.
            post['graphs'] = [self.write(f'{window}/graph.png', b'\x89PNG\r\n\x1a\n' + b'FIXTURE')]
            post['log'] = self.write(cell['outputs']['log'], b'SYNTHETIC END\n')
            post['year_split'] = self.write_json(cell['outputs']['year_split'], {'fixture':True})
            post['metrics'] = self.write_json(cell['outputs']['metrics'], p.report_parser.parse_report(str(root / post['report']['path'])))
            post['truncation'] = self.write_json(cell['outputs']['truncation'], dict(schema_version=2,
                                      check_status='CHECK_PASS', checker_exit_code=0, truncated=False))

    def write(self, name, raw):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(raw)
        return {'path':name, 'sha256':sha(raw)}

    def write_json(self, name, value):
        return self.write(name, json.dumps(value, sort_keys=True).encode())

    def change(self, binding, old, new):
        path = self.root / binding['path']
        binding.update(self.write(binding['path'], path.read_bytes().replace(old,new)))

    def change_json(self, binding, mutate):
        value = p.load_json((self.root / binding['path']).read_bytes())
        mutate(value)
        binding.update(self.write_json(binding['path'], value))

    def inspect(self, mode='post-run', actual_head=None, source_reader=True):
        return p.inspect(self.contract, self.root, actual_head or self.ref, mode, self.observation,
                         (lambda ref,path:self.source) if source_reader else None)

    def envelopes(self):
        contract = self.write_json('contract.json', self.contract)
        self.observation['contract_sha256'] = contract['sha256']
        observation = self.write_json('observation.json', self.observation)
        return contract, observation


class PreflightTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='research-preflight-')
        self.addCleanup(self.tmp.cleanup)
        self.f = Fixture(Path(self.tmp.name))
        self.c = self.f.contract['cells'][0]
        self.post = self.f.observation['cells']['MAIN']

    def refusal(self, code, mode='post-run', **kwargs):
        result = self.f.inspect(mode, **kwargs)
        self.assertEqual('REFUSE', result['status'], result)
        self.assertIn(code, {x['code'] for x in result['issues']}, result)
        self.assertFalse(result['authority_granted'])

    def test_positive_pre_and_post(self):
        for mode in ['pre-run','post-run']:
            result = self.f.inspect(mode)
            self.assertEqual('PASS', result['status'], result)
            self.assertEqual('UNKNOWN', result['live_lane_eligibility'])
            self.assertFalse(result['authority_granted'])
            self.assertTrue(Path(result['cells'][0]['ini_resolved_path']).is_absolute())

    def test_missing_ini_path(self):
        del self.c['inputs']['ini']['path']
        self.refusal('INI_BINDING_MISSING', 'pre-run')

    def test_ini_hash_mismatch(self):
        (self.f.root / self.c['inputs']['ini']['path']).write_bytes(b'changed')
        self.refusal('INI_HASH_MISMATCH', 'pre-run')

    def test_wrong_install(self):
        self.f.change_json(self.c['inputs']['identity'], lambda x:x['identity'].update(installation=r'D:\Meta 5b'))
        self.refusal('OBSERVED_IDENTITY_MISMATCH', 'pre-run')

    def test_holdout_overlap(self):
        self.c['expected']['to_date'] = '2026.01.01'
        self.refusal('HOLDOUT_OVERLAP', 'pre-run')

    def test_moved_head(self):
        self.refusal('SOURCE_HEAD_MOVED', 'pre-run', actual_head='2'*40)

    def test_set_hash_mismatch(self):
        self.c['inputs']['set']['sha256'] = '0'*64
        self.refusal('SET_HASH_MISMATCH', 'pre-run')

    def test_missing_graph(self):
        (self.f.root / self.post['graphs'][0]['path']).unlink()
        self.refusal('MISSING_GRAPH')

    def test_unsafe_graph(self):
        self.f.change(self.post['report'], 'graph.png'.encode('utf-16-le'), '../outside.png'.encode('utf-16-le'))
        self.refusal('UNSAFE_GRAPH')

    def test_graph_base_refused(self):
        self.f.change(self.post['report'], '<html>'.encode('utf-16-le'), '<html><base href="elsewhere/">'.encode('utf-16-le'))
        self.refusal('UNSAFE_GRAPH')

    def test_graph_hash_mismatch(self):
        (self.f.root / self.post['graphs'][0]['path']).write_bytes(b'\x89PNG\r\n\x1a\nOTHER')
        self.refusal('GRAPH_HASH_MISMATCH')

    def test_missing_report(self):
        (self.f.root / self.post['report']['path']).unlink()
        self.refusal('REPORT_MISSING')

    def test_truncated(self):
        self.f.change_json(self.post['truncation'], lambda x:x.update(truncated=True))
        self.refusal('TRUNCATED_RUN')

    def test_cross_install_pair(self):
        self.f.contract['cells'][1]['expected']['installation'] = r'D:\Meta 5b'
        self.refusal('CROSS_INSTALL_PAIR', 'pre-run')

    def test_duplicate_cell(self):
        self.f.contract['cells'].append(copy.deepcopy(self.c))
        self.refusal('DUPLICATE_CELL_IDENTITY', 'pre-run')

    def test_unknown_parameter(self):
        self.f.change(self.c['inputs']['ini'], b'InpLots=0.01', b'InpLots=0.01\nNotInContract=1')
        self.refusal('UNKNOWN_PARAMETER', 'pre-run')

    def test_missing_parameter(self):
        self.f.change(self.c['inputs']['set'], b'InpLots=0.01\n', b'')
        self.refusal('PARAMETER_SURFACE_MISSING', 'pre-run')

    def test_effective_mismatch(self):
        self.f.change_json(self.c['inputs']['identity'], lambda x:x['effective_config'].update(lots=99))
        self.refusal('EFFECTIVE_CONFIG_MISMATCH', 'pre-run')

    def test_source_bytes_mismatch(self):
        self.f.source = b'wrong source'
        self.refusal('SOURCE_GRAPH_HASH_MISMATCH', 'pre-run')

    def test_build_ex5_mismatch(self):
        self.f.change_json(self.c['inputs']['build_receipt'], lambda x:x.update(artifact_sha256='0'*64))
        self.refusal('BUILD_EX5_MISMATCH', 'pre-run')

    def test_unknown_source_reader(self):
        result = self.f.inspect('pre-run', source_reader=False)
        self.assertEqual('UNKNOWN', result['status'])

    def test_unknown_runtime(self):
        self.f.change_json(self.c['inputs']['identity'], lambda x:x.update(runtime_legal=None))
        self.assertEqual('UNKNOWN', self.f.inspect('pre-run')['status'])

    def test_unknown_truncation(self):
        self.f.change_json(self.post['truncation'], lambda x:x.update(check_status='CHECK_FAILED', truncated=None))
        self.assertEqual('UNKNOWN', self.f.inspect()['status'])

    def test_unknown_optional_graph(self):
        self.c['native_graph_required'] = False
        (self.f.root / self.post['graphs'][0]['path']).unlink()
        self.assertEqual('UNKNOWN', self.f.inspect()['status'])

    def test_output_collision(self):
        self.c['outputs']['log'] = self.c['outputs']['report']
        self.refusal('DUPLICATE_OUTPUT_IDENTITY', 'pre-run')

    def test_path_escape(self):
        self.c['inputs']['ini']['path'] = '../outside.ini'
        self.refusal('UNSAFE_PATH', 'pre-run')

    def test_bad_metrics(self):
        self.f.change_json(self.post['metrics'], lambda x:x.update(symbol='GBPUSD'))
        self.refusal('METRICS_REPORT_MISMATCH')

    def test_bad_metrics_profit(self):
        self.f.change_json(self.post['metrics'], lambda x:x.update(net_profit=99999))
        self.refusal('METRICS_REPORT_MISMATCH')

    def test_external_set_override(self):
        self.f.change(self.c['inputs']['ini'], b'[Tester]\n', b'[Tester]\nExpertParameters=unbound.set\n')
        self.refusal('INI_EXTERNAL_PARAMETERS_UNSUPPORTED', 'pre-run')

    def test_default_section(self):
        self.f.change(self.c['inputs']['ini'], b'[Tester]\n', b'[DEFAULT]\nModel=4\n[Tester]\n')
        self.refusal('INI_UNSUPPORTED_SECTIONS', 'pre-run')

    def test_report_identity_mismatch(self):
        self.f.change(self.post['report'], 'XAUUSD'.encode('utf-16-le'), 'GBPUSD'.encode('utf-16-le'))
        self.refusal('REPORT_SYMBOL_MISMATCH')

    def test_m4_wrong_lane(self):
        self.c['expected'].update(model='4', installation=r'D:\Meta 5c', lane='MT5-lane3')
        self.refusal('MODEL4_LANE_ILLEGAL', 'pre-run')

    def test_nonfinite_and_duplicate_json(self):
        for raw in [b'{"x":NaN}', b'{"x":1,"x":2}']:
            with self.assertRaises(p.Invalid):
                p.load_json(raw)

    def test_invalid_envelope(self):
        contract, _ = self.f.envelopes()
        with self.assertRaises(p.Invalid):
            p.pinned(self.f.root / contract['path'], '0'*64)

    def test_cli_readonly_and_envelope_mismatch(self):
        # Use actual Git blob/HEAD but synthetic evidence; never checks out or edits Git.
        ref = p.head(p.REPO)
        source_path = 'scripts/parse_mt5_report.py'
        source = subprocess.check_output(['git','-C',str(p.REPO),'show',ref+':'+source_path])
        fixture = Fixture(self.f.root, source, ref, source_path)
        contract, observation = fixture.envelopes()
        before = {str(x):sha(x.read_bytes()) for x in self.f.root.rglob('*') if x.is_file()}
        cmd = [sys.executable,str(Path(p.__file__)), 'post-run','--contract',str(self.f.root/contract['path']),
               '--contract-sha256',contract['sha256'],'--source-repo',str(p.REPO),'--artifact-root',str(self.f.root),
               '--observations',str(self.f.root/observation['path']),'--observations-sha256',observation['sha256']]
        result = subprocess.run(cmd, capture_output=True, text=True)
        self.assertEqual(0,result.returncode,result.stdout+result.stderr)
        self.assertEqual('PASS',json.loads(result.stdout)['status'])
        cmd[cmd.index('--contract-sha256')+1]='0'*64
        result = subprocess.run(cmd,capture_output=True,text=True)
        self.assertEqual(2,result.returncode,result.stdout+result.stderr)
        self.assertEqual('INPUT_ENVELOPE_HASH_MISMATCH',json.loads(result.stdout)['issues'][0]['code'])
        after = {str(x):sha(x.read_bytes()) for x in self.f.root.rglob('*') if x.is_file()}
        self.assertEqual(before,after)


def mismatch_test(field, old, new):
    def test(self):
        self.f.change(self.c['inputs']['ini'], old.encode(), new.encode())
        self.refusal('INI_'+field.upper()+'_MISMATCH','pre-run')
    return test


for field,old,new in [('symbol','Symbol=XAUUSD','Symbol=GBPUSD'), ('tf','Period=H1','Period=M15'),
                      ('leverage','Leverage=1:100','Leverage=1:500'), ('model','Model=1','Model=4'),
                      ('optimization','Optimization=0','Optimization=1')]:
    setattr(PreflightTests,'test_wrong_'+field,mismatch_test(field,old,new))


def benchmark():
    with tempfile.TemporaryDirectory(prefix='research-preflight-benchmark-') as temp:
        fixture = Fixture(Path(temp))
        values = {}
        for mode in ['pre-run','post-run']:
            samples=[]
            for _ in range(100):
                start=time.perf_counter()
                result=fixture.inspect(mode)
                if result['status']!='PASS':
                    raise RuntimeError(result)
                samples.append((time.perf_counter()-start)*1000)
            values[mode]={'iterations':len(samples),'median_ms':round(statistics.median(samples),3),
                          'p95_ms':round(sorted(samples)[94],3),'max_ms':round(max(samples),3)}
        ref = p.head(p.REPO)
        source_path = 'scripts/parse_mt5_report.py'
        source = subprocess.check_output(['git','-C',str(p.REPO),'show',ref+':'+source_path])
        fixture = Fixture(Path(temp), source, ref, source_path)
        contract, observation = fixture.envelopes()
        for mode in ['pre-run','post-run']:
            cmd = [sys.executable,str(Path(p.__file__)),mode,'--contract',str(Path(temp)/contract['path']),
                   '--contract-sha256',contract['sha256'],'--source-repo',str(p.REPO),'--artifact-root',temp]
            if mode=='post-run':
                cmd += ['--observations',str(Path(temp)/observation['path']),'--observations-sha256',observation['sha256']]
            samples=[]
            for _ in range(5):
                start=time.perf_counter()
                result=subprocess.run(cmd,capture_output=True,text=True)
                if result.returncode!=0:
                    raise RuntimeError(result.stdout+result.stderr)
                samples.append((time.perf_counter()-start)*1000)
            values[mode+'-cli']={'iterations':5,'median_ms':round(statistics.median(samples),3),
                                'max_ms':round(max(samples),3)}
        print(json.dumps({'schema':'research-preflight-benchmark/1','synthetic_cells':2,
                          'git_reader':'core: fixture-memory; cli: actual Git, one declared source file per cell',
                          'results':values},indent=2))


if __name__=='__main__':
    if '--benchmark' in sys.argv:
        benchmark()
    else:
        unittest.main(verbosity=2)
