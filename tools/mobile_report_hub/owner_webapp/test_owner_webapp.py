import json, os, pathlib, sys, tempfile, unittest
from types import SimpleNamespace
from unittest import mock
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parent))
from model import Model, Refused, _DashboardParser, clean, safe_bytes, digest, number, age_state, utcnow, stamp, projection_view
from server import Application, Handler, render, serialize, reusable, identity
import datetime as dt
import shutil

HERE=pathlib.Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent))
from build_index import safe_projection, unavailable_safe_projection, _SAFE_SENSOR_STATES, _SAFE_DD_BANDS, _SAFE_FINDING_SEVERITIES

def model_fixture(root, mode='available'):
    """Real file readers and Model.snapshot; only Git blob I/O uses fixture bytes.

    No production registry, lane probe, MT5, hosting or runtime inputs are used.
    """
    config={k:str(root/k) for k in ('repo','monitor','snapshots','registry','leases','jobs','knowledge','runtime')}
    for p in config.values(): pathlib.Path(p).mkdir(parents=True,exist_ok=True)
    config['assets']=str(HERE); config['lane_status']=str(root/'absent.ps1')
    if mode=='work_missing': pathlib.Path(config['registry']).rmdir()
    if mode=='work_invalid': (root/'registry/bad.json').write_text('{',encoding='utf-8')
    if mode.startswith('aging'):
        (root/'registry/ct-aging.json').write_text(json.dumps({
            'lane_id':'ct-aging','state':'RUNNING','updated_at':'2026-09-24T00:00:00Z',
            'worker':'fixture','owner_chat':'fixture','dependencies':[]}),encoding='utf-8')
    when={'stale':'2026-09-20T00:00:00Z','future':'2026-09-25T00:00:00Z',
          'unqualified':'2026-09-24T00:00:00','malformed_time':'2026-02-30T00:00:00Z'}.get(mode,'2026-09-24T00:00:00Z')
    raw={'entity':'SafeProjection','build_id':'a'*16,'generated_at':when,'accounts':[],
         'findings':[{'public_id':'FP-'+'a'*10,'severity':'WARN','state':'OPEN'}]}
    source=root/'projection.json'; source.write_text(json.dumps(raw),encoding='utf-8')
    projection=safe_projection(source,'2026-09-24T00:00:00Z')
    if mode=='missing': projection=unavailable_safe_projection()
    if mode=='invalid': projection=unavailable_safe_projection('INVALID_INPUT')
    if mode=='empty': projection['findings']=[]
    index={'schema_version':1,'project':{'canonical_sha':'a'*40},'eas':[], 'safe_projection':projection,
           'monitoring':{'status':'CURRENT','generated_at_utc':when,'sources':[]}}
    (root/'monitor/report_index.json').write_text(json.dumps(index),encoding='utf-8')
    header='row_type,login,server_time,balance,equity,currency,margin\n'
    if mode!='missing':
        for day,value in ((22,'100'),(23,'BAD' if mode in ('invalid','malformed_account','gaps') else '101'),(24,'102')):
            if mode=='malformed_account' and day!=23: continue
            (root/f'snapshots/EA_LAB_snapshot_123456789_{20260900+day}.csv').write_text(header+f'ACCOUNT,123456789,2026.09.{day} 00:00:00,{value},{value},USD,\n',encoding='utf-8')
    if mode=='conflict':
        (root/'snapshots/EA_LAB_snapshot_123456789.csv').write_text(header+'ACCOUNT,123456789,2026.09.24 00:00:00,999,999,USD,\n',encoding='utf-8')
    blobs={'PROJECT_STATE.md':b'Global state: `DEGRADED_MONITORING`',
           'portfolio/ACCOUNTS.csv':b'account,currency,environment\n123456789,USD,DEMO\n',
           'portfolio/DEPLOYMENTS.csv':b'account,magic,ea_name,status\n',
           'ea_projects/(Boss)_NewsGuard/GUARDCONFIG_2026-07-17.md':b''}
    def git(_self,*args):
        if args[0]=='rev-parse': return b'a'*40
        if args[0]=='ls-tree': return b''
        if args[0]=='show': return blobs[args[1].split(':',1)[1]]
        raise AssertionError(args)
    with mock.patch.object(Model,'git',git):
        app=Application(config)
        first=app.snapshot(); cached=app.snapshot()
        page=render(config,cached).decode('utf-8')
    return {'snapshot':json.loads(serialize(cached)), 'html':page,'health':app.health(), 'config':config,'first':first}

def browser_fixtures():
    result={}
    for mode in ('available','empty','missing','invalid','stale','future','unqualified','malformed_time','malformed_account','gaps','conflict','work_missing','work_invalid','aging','aging_offline'):
        with tempfile.TemporaryDirectory() as td:
            fixture=model_fixture(pathlib.Path(td),mode)
            result[mode]={k:fixture[k] for k in ('snapshot','html','health')}
    return result

class ConvergenceTests(unittest.TestCase):
    def test_strict_z_offsets_and_calendar(self):
        self.assertEqual(stamp('2026-09-24T07:00:00+07:00'),stamp('2026-09-24T00:00:00Z'))
        for value in (None,[],{},True,'','2026-09-24','2026-09-24T00:00:00','2026-02-30T00:00:00Z','2026-09-24T24:00:00Z','2026-09-24T00:00:00+07:99','2026-09-24T00:00:00+24:00','2026-09-24X00:00:00Z'):
            with self.subTest(value=value): self.assertIsNone(stamp(value)); self.assertEqual(age_state(value),'UNKNOWN')
    def test_future_is_never_current(self):
        self.assertEqual(age_state((dt.datetime.now(dt.timezone.utc)+dt.timedelta(seconds=20)).isoformat()),'FUTURE')
    def test_producer_enum_contract(self):
        with tempfile.TemporaryDirectory() as td:
            p=pathlib.Path(td)/'projection.json'
            for sensor in _SAFE_SENSOR_STATES:
                for band in _SAFE_DD_BANDS:
                    for severity in _SAFE_FINDING_SEVERITIES:
                        raw={'entity':'SafeProjection','build_id':'a'*16,'generated_at':'2026-09-24T00:00:00Z',
                             'accounts':[{'account_masked':'***789','sensor_state':sensor,'dd_pct_band':band}],
                             'findings':[{'public_id':'FP-'+'a'*10,'severity':severity,'state':'OPEN'}]}
                        p.write_text(json.dumps(raw),encoding='utf-8')
                        produced=safe_projection(p)
                        self.assertEqual(produced['status'],'AVAILABLE')
                        self.assertEqual(projection_view(produced)['accounts'],raw['accounts'])
                        self.assertEqual(projection_view(produced)['findings'],raw['findings'])
    def test_projection_missing_invalid_and_forged(self):
        for value,expected in ((None,'MISSING'),({},'INVALID'),([], 'INVALID'),(unavailable_safe_projection(),'MISSING'),(unavailable_safe_projection('bad'),'INVALID')):
            self.assertEqual(projection_view(value)['status'],expected)
        value=unavailable_safe_projection(); value.update(status='AVAILABLE',findings=[{'public_id':'fake'}])
        self.assertEqual(projection_view(value)['status'],'INVALID')
    def test_projection_malformed_enum_types_are_invalid(self):
        base={'status':'AVAILABLE','entity':'SafeProjection','source_kind':'SAFE_PROJECTION_DERIVED',
              'authority':'READ_ONLY_NO_RUNTIME_AUTHORITY','build_id':'a'*16,'generated_at':'2026-09-24T00:00:00Z',
              'accounts':[{'account_masked':'***789','sensor_state':[],'dd_pct_band':'OK'}],'findings':[]}
        self.assertEqual(projection_view(base)['status'],'INVALID')
        base['accounts']=[];base['findings']=[{'public_id':'FP-'+'a'*10,'severity':{},'state':'OPEN'}]
        self.assertEqual(projection_view(base)['status'],'INVALID')
    def test_malformed_only_and_missing_accounts(self):
        for mode,status in (('malformed_account','INVALID'),('missing','MISSING')):
            with tempfile.TemporaryDirectory() as td:
                accounts=model_fixture(pathlib.Path(td),mode)['snapshot']['accounts']
                self.assertEqual(accounts['status'],status); self.assertEqual(accounts['rows'],[])
                if status=='INVALID': self.assertEqual(len(accounts['gaps']),1)
    def test_gaps_and_conflicts_never_substitute_previous_balance(self):
        for mode in ('gaps','conflict'):
            with tempfile.TemporaryDirectory() as td:
                accounts=model_fixture(pathlib.Path(td),mode)['snapshot']['accounts']
                self.assertEqual(accounts['status'],'INVALID')
                self.assertIsNone(accounts['rows'][0]['latest']['balance'])
    def test_model_serialization_truth_order_and_cache_separation(self):
        with tempfile.TemporaryDirectory() as td:
            f=model_fixture(pathlib.Path(td),'stale')
            self.assertTrue(f['snapshot']['transport']['cache_hit'])
            self.assertFalse(f['first']['transport']['cache_hit'])
            self.assertEqual(f['snapshot']['monitoring']['generated_at_utc'],'2026-09-20T00:00:00Z')
            self.assertLess(f['html'].index('root.EALabTruth=api'),f['html'].index('const truth=window.EALabTruth'))
            self.assertNotIn('123456789',f['html'])
    def test_serialization_escape_and_nonfinite_rejection(self):
        self.assertNotIn(b'</script>',serialize({'x':'</script>\u2028'}))
        with self.assertRaises(ValueError): serialize({'x':float('nan')})
    def test_health_identity_rejects_legacy_version_and_wrong_source(self):
        with tempfile.TemporaryDirectory() as td:
            f=model_fixture(pathlib.Path(td)); expected=f['health']['identity']
            self.assertTrue(reusable(f['health'],expected))
            self.assertFalse(reusable({'app':f['health']['app'],'status':'OK','read_only':True},expected))
            config={**f['config'],'monitor':str(pathlib.Path(td)/'other')}
            self.assertFalse(reusable(f['health'],identity(config)))
            self.assertEqual(set(expected['files']),{'model.py','server.py','truth.js','owner_webapp.js','owner_webapp.html','owner_webapp.css'})
    def test_health_route_serializes_actual_startup_identity(self):
        app=Application({'assets':str(HERE)})
        handler=Handler.__new__(Handler); handler.app=app; handler.path='/health'; handler._send=mock.Mock()
        handler.do_GET()
        got=json.loads(handler._send.call_args.args[0])
        self.assertTrue(reusable(got,app.startup_identity))
        self.assertEqual(got['started_at'],app.started_at)
    def test_changed_loaded_source_is_refused(self):
        with mock.patch('server.SERVER_SOURCE_SHA256','0'*64):
            with self.assertRaisesRegex(Refused,'LOADED_SOURCE_CHANGED'): Application({'assets':str(HERE)})
    def test_startup_asset_change_refused_not_relabelled(self):
        with tempfile.TemporaryDirectory() as td:
            root=pathlib.Path(td); assets=root/'assets'; assets.mkdir()
            for name in ('owner_webapp.html','owner_webapp.css','owner_webapp.js','truth.js'): shutil.copyfile(HERE/name,assets/name)
            config={'assets':str(assets)}; app=Application(config); before=app.startup_identity
            (assets/'truth.js').write_text('// changed',encoding='utf-8')
            self.assertEqual(before,app.startup_identity)
            with self.assertRaisesRegex(Refused,'STARTUP_IDENTITY_CHANGED'): app.health()
            self.assertFalse(reusable({'app':'EA_LAB_OWNER_WEBAPP_CONVERGENCE_V1','status':'OK','read_only':True,'identity':before},identity(config)))
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
    def _lane_payload(self, **overrides):
        base={
            'lane_id':'ct-lane-one','job_id':'job-one','health':'ACTIVE','observed_state':'RUNNING',
            'durable_state':'RUNNING','runner_alive':True,'child_alive':True,'postcondition_alive':False,
            'heartbeat_age_sec':5.0,'retry_decision':'REFUSE_RETRY','checked_utc':'2026-09-21T16:00:00+00:00'
        }
        base.update(overrides); return base
    def _lane_model(self, script):
        return Model({'repo':'.','lane_status':str(script)})
    def _mock_status(self, payload, returncode=0):
        raw=json.dumps(payload).encode('utf-8')
        return mock.patch('model.subprocess.run',return_value=SimpleNamespace(returncode=returncode,stdout=raw,stderr=b''))
    def test_lane_status_active_runner_child(self):
        with tempfile.TemporaryDirectory() as td:
            script=pathlib.Path(td)/'lane_status.ps1'; script.write_text('# test',encoding='utf-8')
            with self._mock_status(self._lane_payload()):
                got=self._lane_model(script).lane_status('ct-lane-one','job-one')
        self.assertEqual(got['health'],'ACTIVE'); self.assertTrue(got['runner_alive']); self.assertTrue(got['child_alive'])
        self.assertEqual(got['heartbeat_age_sec'],5.0)
    def test_lane_status_terminal_complete(self):
        with tempfile.TemporaryDirectory() as td:
            script=pathlib.Path(td)/'lane_status.ps1'; script.write_text('# test',encoding='utf-8')
            payload=self._lane_payload(health='COMPLETE',observed_state='COMPLETE',durable_state='COMPLETE',
                                       runner_alive=False,child_alive=False,heartbeat_age_sec=20.0)
            with self._mock_status(payload):
                got=self._lane_model(script).lane_status('ct-lane-one','job-one')
        self.assertEqual(got['health'],'COMPLETE'); self.assertFalse(got['runner_alive'])
    def test_lane_status_stale_heartbeat(self):
        with tempfile.TemporaryDirectory() as td:
            script=pathlib.Path(td)/'lane_status.ps1'; script.write_text('# test',encoding='utf-8')
            payload=self._lane_payload(health='STALLED',heartbeat_age_sec=901.0)
            with self._mock_status(payload):
                got=self._lane_model(script).lane_status('ct-lane-one','job-one')
        self.assertEqual(got['health'],'STALLED'); self.assertEqual(got['heartbeat_age_sec'],901.0)
    def test_lane_status_mismatched_lane_or_job_refuses(self):
        with tempfile.TemporaryDirectory() as td:
            script=pathlib.Path(td)/'lane_status.ps1'; script.write_text('# test',encoding='utf-8')
            for payload in (self._lane_payload(lane_id='ct-other'),self._lane_payload(job_id='job-other')):
                with self._mock_status(payload):
                    with self.assertRaisesRegex(Refused,'LANE_STATUS_IDENTITY'):
                        self._lane_model(script).lane_status('ct-lane-one','job-one')
    def test_lane_status_missing_or_invalid_output_refuses(self):
        with tempfile.TemporaryDirectory() as td:
            missing=pathlib.Path(td)/'missing.ps1'
            with self.assertRaisesRegex(Refused,'LANE_STATUS_UNAVAILABLE'):
                self._lane_model(missing).lane_status('ct-lane-one','job-one')
            script=pathlib.Path(td)/'lane_status.ps1'; script.write_text('# test',encoding='utf-8')
            with mock.patch('model.subprocess.run',return_value=SimpleNamespace(returncode=0,stdout=b'{}',stderr=b'')):
                with self.assertRaisesRegex(Refused,'LANE_STATUS_SCHEMA'):
                    self._lane_model(script).lane_status('ct-lane-one','job-one')
            bad=self._lane_payload(runner_alive=123)
            with self._mock_status(bad):
                with self.assertRaisesRegex(Refused,'LANE_STATUS_PROCESS_TYPES'):
                    self._lane_model(script).lane_status('ct-lane-one','job-one')
    def test_lane_status_active_without_verified_process_refuses(self):
        with tempfile.TemporaryDirectory() as td:
            script=pathlib.Path(td)/'lane_status.ps1'; script.write_text('# test',encoding='utf-8')
            payload=self._lane_payload(runner_alive=False,child_alive=False,postcondition_alive=False)
            with self._mock_status(payload):
                with self.assertRaisesRegex(Refused,'LANE_STATUS_ACTIVE_WITHOUT_PROCESS'):
                    self._lane_model(script).lane_status('ct-lane-one','job-one')
    def _make_work_roots(self,td,lane='ct-test-lane',with_job=True):
        base=pathlib.Path(td); registry=base/'registry'; leases=base/'leases'; jobs=base/'jobs'
        registry.mkdir(); leases.mkdir(); jobs.mkdir()
        record={'lane_id':lane,'state':'RUNNING','updated_at':utcnow(),'owner_chat':'ChatGPT window says PID 999 is running',
                'worker':'chat-ui-text-only','blocker_class':'','head_sha':'a'*40,'reviewed_head':None,'reviewer':None,'dependencies':[]}
        (registry/(lane+'.json')).write_text(json.dumps(record),encoding='utf-8')
        if with_job:
            (leases/(lane+'.json')).write_text(json.dumps({'lane_id':lane,'job_id':'job-one'}),encoding='utf-8')
            job=jobs/'job-one'; job.mkdir()
            (job/'state.json').write_text(json.dumps({'job_id':'job-one','state':'RUNNING','runner_pid':os.getpid(),'child_pid':os.getpid()}),encoding='utf-8')
        cfg={'repo':'.','registry':str(registry),'leases':str(leases),'jobs':str(jobs),'lane_status':str(base/'missing_lane_status.ps1')}
        return Model(cfg)
    def test_running_registry_without_durable_job_is_stale_not_chat_liveness(self):
        with tempfile.TemporaryDirectory() as td:
            rows=self._make_work_roots(td,with_job=False).work()['rows']
        self.assertEqual(len(rows),1); row=rows[0]
        self.assertEqual(row['display_state'],'STALE_REGISTRY')
        self.assertEqual(row['process_health'],'NO_DURABLE_JOB')
        self.assertIsNone(row['runner_alive']); self.assertEqual(row['progress'],'UNKNOWN')
    def test_pid_fields_alone_never_establish_liveness(self):
        with tempfile.TemporaryDirectory() as td:
            model=self._make_work_roots(td,with_job=True)
            rows=model.work()['rows']
        self.assertEqual(len(rows),1); row=rows[0]
        self.assertEqual(row['process_health'],'UNAVAILABLE')
        self.assertEqual(row['display_state'],'LIVENESS_UNAVAILABLE')
        self.assertNotEqual(row['display_state'],'ACTIVE_PROCESS')
        self.assertIsNone(row['runner_alive']); self.assertEqual(row['progress'],'UNKNOWN')
    def test_work_maps_only_accepted_lane_status_health(self):
        mapping={'ACTIVE':'ACTIVE_PROCESS','STALLED':'STALLED','RECOVERY_REQUIRED':'RECOVERY_REQUIRED','COMPLETE':'TERMINAL_RECONCILE'}
        with tempfile.TemporaryDirectory() as td:
            model=self._make_work_roots(td,with_job=True)
            for health,expected in mapping.items():
                observed='LOST_PROCESS' if health=='RECOVERY_REQUIRED' else 'COMPLETE' if health=='COMPLETE' else 'RUNNING'
                live={'health':health,'observed_state':observed,'durable_state':observed,'runner_alive':health in ('ACTIVE','STALLED'),
                      'child_alive':health in ('ACTIVE','STALLED'),'postcondition_alive':False,'heartbeat_age_sec':901.0 if health=='STALLED' else 5.0,
                      'retry_decision':'REFUSE_RETRY','checked_utc':'2026-09-21T16:00:00+00:00','status_source':'ACCEPTED_CHAT_STALL_LANE_STATUS'}
                with mock.patch.object(model,'lane_status',return_value=live):
                    row=model.work()['rows'][0]
                self.assertEqual(row['display_state'],expected,health)
                self.assertEqual(row['process_health'],health,health)
                self.assertEqual(row['progress'],'UNKNOWN',health)
    def test_work_refuses_internal_lease_lane_identity_mismatch(self):
        with tempfile.TemporaryDirectory() as td:
            model=self._make_work_roots(td,with_job=True)
            lease=pathlib.Path(model.c['leases'])/'ct-test-lane.json'
            lease.write_text(json.dumps({'lane_id':'ct-other-lane','job_id':'job-one'}),encoding='utf-8')
            out=model.work()
        self.assertEqual(out['rows'],[])
        self.assertIn({'source':'lane_observation','reason':'LEASE_LANE_IDENTITY'},model.errors)
    def test_work_refuses_state_and_result_job_identity_mismatch(self):
        for which in ('state','result'):
            with self.subTest(which=which), tempfile.TemporaryDirectory() as td:
                model=self._make_work_roots(td,with_job=True)
                job=pathlib.Path(model.c['jobs'])/'job-one'
                if which=='state':
                    (job/'state.json').write_text(json.dumps({'job_id':'job-other','state':'RUNNING'}),encoding='utf-8')
                    expected='JOB_STATE_IDENTITY'
                else:
                    (job/'result.json').write_text(json.dumps({'job_id':'job-other','state':'COMPLETE'}),encoding='utf-8')
                    expected='JOB_RESULT_IDENTITY'
                out=model.work()
                self.assertEqual(out['rows'],[])
                self.assertIn({'source':'lane_observation','reason':expected},model.errors)
if __name__=="__main__":
    if '--browser-fixtures' in sys.argv: print(json.dumps(browser_fixtures(),ensure_ascii=True))
    else: unittest.main()
