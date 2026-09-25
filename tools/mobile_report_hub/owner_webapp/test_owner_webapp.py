import json, os, pathlib, subprocess, sys, tempfile, unittest
from types import SimpleNamespace
from unittest import mock
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parent))
from model import Model, Refused, SOURCE_ADAPTER_IMPORT_ALLOWLIST, _DashboardParser, clean, safe_bytes, digest, number, age_state, utcnow, stamp, projection_view
from server import Application, Handler, config_from_args, parser, render, serialize, reusable, identity
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

def adapter_payload(sha):
    section=lambda availability,reasons,data,errors=[]:{'implementation':'IMPLEMENTED_READER','availability':availability,
        'reasons':reasons,'data':data,'provenance':[],'errors':errors}
    finding={'owner':'ledger','code':'ACCOUNT_METADATA_MISSING_OR_AMBIGUOUS','source_id':None,
             'finding_id':'finding-'+'d'*64,'next_action':'INSPECT_DECLARED_SOURCE_EVIDENCE'}
    return {'schema_version':'ea_observation_adapters/1','canonical_ref':sha,'read_at_utc':'2026-09-24T13:35:13Z',
        'authority':'READ_ONLY_SOURCE_OBSERVATIONS','integration':{
            'consumer':'tools.mobile_report_hub.owner_webapp.model.Model.snapshot','ui_wired':False,
            'activated':False,'real_data_qualified':False},
        'sections':{
            'accounts':section('PARTIAL',['BROKER_SERVER_NOT_EXPORTED','BROKER_TIME_UNQUALIFIED'],{
                'accounts':[{'account_key':'account-'+'a'*64,'currency':'USD','availability':'PARTIAL',
                             'currency_binding_conflict':False,'qualified_series':None,'samples':[{},{}]},
                            {'account_key':'account-'+'b'*64,'currency':'EUR','availability':'PARTIAL',
                             'currency_binding_conflict':True,'qualified_series':None,'samples':[{}]}],
                'cross_currency_total':None,'broker_qualified_series_available':False}),
            'ledger':section('PARTIAL',['FEE_CYCLE_IDS_NOT_EXPORTED','BROKER_TIME_UNQUALIFIED'],{
                'accounts':[{'account_key':'account-'+'a'*64,'availability':'PARTIAL',
                             'reason':'COST_CYCLE_CLOCK_AND_RUNTIME_GAPS','deal_count':7,'quarantined':[],
                             'components':[{'stream_id':'stream-'+'c'*64,'deal_count':7,
                                            'gross_realized_profit_component':'999.00','fee_availability':'NOT_EXPORTED',
                                            'all_costs_complete':False,'window_latest':'2026-09-24T12:30:00',
                                            'clock_basis':'BROKER_TIME_UNQUALIFIED'}]},
                            {'account_key':'account-'+'b'*64,'availability':'UNAVAILABLE','reason':'LEDGER_MISSING',
                             'deal_count':None,'quarantined':[],'components':[]}],
                'raw_rows_read':9,'unit':'DEAL_EVENTS_NOT_TRADE_CYCLES','account_totals_across_currencies':None}),
            'deployments':section('PARTIAL',['DESCRIPTIVE_ONLY'],{
                'deployments':[{'deployment_id':'deployment-'+'e'*64,'expected_identity_present':True,
                                'comparison':'DIFFERENCES_OR_GAPS'},
                               {'deployment_id':'deployment-'+'f'*64,'expected_identity_present':False,
                                'comparison':'FIELDS_MATCH_ONLY'}],
                'authority':'DESCRIPTIVE_ONLY','first_trade_or_judge_claim':None,
                'producer':{'generated_at':'2026-09-24T13:35:13Z','canonical_binding':'DIFFERENT_REPO_HEAD',
                            'producer_identity_state':'FAIL','producer_head':'1'*40}}),
            'guards':section('PARTIAL',['NO_QUALIFIED_EFFECTIVE_EVENT_SOURCE'],{
                'contexts':[{'kind':'NEWS_CALENDAR','availability':'PARTIAL','observed_at':None,
                             'reason':'CONTEXT_NOT_EFFECTIVE_EVIDENCE'},
                            {'kind':'MRIS','availability':'PARTIAL','observed_at':'2026-09-24T13:35:09Z',
                             'reason':'CONTEXT_NOT_EFFECTIVE_EVIDENCE'}],
                'effective':None,'reason':'CALENDAR_MRIS_AND_CONFIG_CANNOT_PROVE_EA_APPLICATION'}),
            'access_provenance':section('UNAVAILABLE',['NO_ACCESS_QUALIFICATION_EVIDENCE'],{}),
        },'provenance':[],'errors':[finding],'budget_usage':{'files':4,'bytes':1234,'rows':9}}

class SourceAdapterIntegrationTests(unittest.TestCase):
    def model(self, adapter_root=None):
        repo=HERE.parents[2]
        config={'repo':str(repo),'snapshots':'S:/snapshots','runtime':'R:/runtime'}
        if adapter_root is not None: config['adapter_root']=str(adapter_root)
        model=Model(config)
        model.sha=model.git('rev-parse','HEAD').decode().strip()
        return model

    def adapter_bundle(self, root):
        repo=HERE.parents[2]
        for relative in SOURCE_ADAPTER_IMPORT_ALLOWLIST:
            destination=root.joinpath(*pathlib.PurePosixPath(relative).parts)
            destination.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(repo.joinpath(*pathlib.PurePosixPath(relative).parts),destination)
        return root

    def test_adapter_root_cli_fallback_explicit_and_identity_binding(self):
        fallback=config_from_args(parser().parse_args(['--repo','R:/canonical']))
        explicit=config_from_args(parser().parse_args(['--repo','R:/canonical','--adapter-root','A:/bundle']))
        self.assertEqual(fallback['adapter_root'],'R:/canonical')
        self.assertEqual(explicit['adapter_root'],'A:/bundle')
        first=identity({**explicit,'assets':str(HERE)})
        second=identity({**explicit,'assets':str(HERE),'adapter_root':'B:/other-bundle'})
        self.assertNotEqual(first['sources_sha256'],second['sources_sha256'])

    def test_distinct_accepted_adapter_bundle_executes_against_git_repo(self):
        with tempfile.TemporaryDirectory() as td:
            bundle=self.adapter_bundle(pathlib.Path(td)/'bundle')
            model=self.model(bundle)
            self.assertNotEqual(model.repo.absolute(),bundle.absolute())
            before=model._verified_adapter_files()
            raw=model._run_source_adapter()
            self.assertEqual(before,model._verified_adapter_files())
            observation=json.loads(raw)
            self.assertEqual(observation['schema_version'],'ea_observation_adapters/1')
            self.assertEqual(observation['canonical_ref'],model.sha)

    def test_exact_git_bound_local_imports_allow_accepted_invocation(self):
        model=self.model(); payload=adapter_payload(model.sha)
        with mock.patch.object(model,'_run_source_adapter',return_value=json.dumps(payload).encode()):
            got=model.source_observations()
        self.assertEqual(got['status'],'AVAILABLE')
        self.assertEqual(got['canonical_ref'],model.sha)

    def test_pre_read_hash_mismatch_is_optional_unavailable(self):
        model=self.model()
        with mock.patch.object(model,'_verified_adapter_files',side_effect=Refused('SOURCE_ADAPTER_BYTE_MISMATCH')):
            got=model.source_observations()
        self.assertEqual(got['status'],'UNAVAILABLE')
        self.assertEqual(got['overall'],'UNAVAILABLE')

    def test_missing_or_mismatched_adapter_bundle_is_optional_unavailable(self):
        for defect in ('missing','mismatch'):
            with self.subTest(defect=defect), tempfile.TemporaryDirectory() as td:
                bundle=self.adapter_bundle(pathlib.Path(td)/'bundle')
                target=bundle.joinpath(*pathlib.PurePosixPath(SOURCE_ADAPTER_IMPORT_ALLOWLIST[0]).parts)
                if defect=='missing': target.unlink()
                else: target.write_bytes(target.read_bytes()+b'\n# drift\n')
                got=self.model(bundle).source_observations()
                self.assertEqual(got['status'],'UNAVAILABLE')
                self.assertEqual(got['overall'],'UNAVAILABLE')

    def test_post_read_mutation_discards_result(self):
        model=self.model(); payload=adapter_payload(model.sha); before={'x':'1'}
        with mock.patch.object(model,'_verified_adapter_files',side_effect=[before,{'x':'2'}]), \
             mock.patch.object(model,'_run_source_adapter',return_value=json.dumps(payload).encode()):
            got=model.source_observations()
        self.assertEqual(got['status'],'UNAVAILABLE')

    def test_subprocess_contract_and_failure_modes(self):
        model=self.model(); good=json.dumps(adapter_payload(model.sha)).encode()
        completed=lambda code=0,out=good: SimpleNamespace(returncode=code,stdout=out,stderr=b'')
        with mock.patch('model.subprocess.run',return_value=completed()) as run:
            self.assertEqual(model._run_source_adapter(),good)
            command=run.call_args.args[0]
            self.assertEqual(command[0],sys.executable); self.assertIn('-I',command); self.assertIn('-B',command)
            self.assertIn('-X',command); x_index=command.index('-X')
            self.assertRegex(command[x_index+1],r'^pycache_prefix=.*\\.ea_lab_monitor_pycache_[0-9a-f]{32}$')
            self.assertFalse(pathlib.Path(command[x_index+1].split('=',1)[1]).exists())
            self.assertNotIn('shell',run.call_args.kwargs)
            self.assertEqual(command[-6:],[str(model.adapter_root),str(model.repo),model.sha,model.c['snapshots'],model.c['snapshots'],model.c['runtime']])
            launcher_arg=command[command.index('-c')+1]
            self.assertIn('sys.path.insert(0,import_root)',launcher_arg)
            self.assertIn('BuildRequest(repo=pathlib.Path(repo)',launcher_arg)
        for result,code in ((completed(2,b''),'SOURCE_ADAPTER_PROCESS_FAILED'),
                            (completed(0,b'{'),'SOURCE_ADAPTER_JSON_INVALID'),
                            (completed(0,b'x'*4_000_001),'SOURCE_ADAPTER_OUTPUT_TOO_LARGE')):
            with self.subTest(code=code), mock.patch('model.subprocess.run',return_value=result):
                if code=='SOURCE_ADAPTER_JSON_INVALID':
                    raw=model._run_source_adapter()
                    with self.assertRaisesRegex(Refused,code): model._project_source_observations(raw)
                else:
                    with self.assertRaisesRegex(Refused,code): model._run_source_adapter()
        with mock.patch('model.subprocess.run',side_effect=subprocess.TimeoutExpired(['python'],40)):
            with self.assertRaisesRegex(Refused,'SOURCE_ADAPTER_TIMEOUT'): model._run_source_adapter()

    def test_wrong_schema_ref_authority_and_integration_are_unavailable(self):
        model=self.model()
        cases=(('schema_version','wrong'),('canonical_ref','0'*40),('authority','WRITE_AUTHORITY'))
        for key,value in cases:
            payload=adapter_payload(model.sha); payload[key]=value
            with self.subTest(key=key), mock.patch.object(model,'_verified_adapter_files',return_value={'x':'1'}), \
                 mock.patch.object(model,'_run_source_adapter',return_value=json.dumps(payload).encode()):
                self.assertEqual(model.source_observations()['status'],'UNAVAILABLE')
        payload=adapter_payload(model.sha); payload['integration']['activated']=True
        with mock.patch.object(model,'_verified_adapter_files',return_value={'x':'1'}), \
             mock.patch.object(model,'_run_source_adapter',return_value=json.dumps(payload).encode()):
            self.assertEqual(model.source_observations()['status'],'UNAVAILABLE')

    def test_partial_projection_preserves_gaps_identity_guards_and_no_money(self):
        model=self.model(); got=model._project_source_observations(json.dumps(adapter_payload(model.sha)).encode())
        self.assertEqual(got['overall'],'PARTIAL')
        self.assertEqual(got['sections']['ledger']['account_count'],2)
        self.assertEqual(got['sections']['ledger']['accounts_with_ledger'],1)
        self.assertEqual(got['sections']['ledger']['missing_ledger_count'],1)
        self.assertEqual(got['sections']['ledger']['deal_events'],7)
        self.assertEqual(got['sections']['ledger']['deal_event_unit'],'DEAL_EVENTS_NOT_TRADE_CYCLES')
        self.assertFalse(got['sections']['ledger']['all_costs_complete'])
        self.assertEqual(got['sections']['deployments']['producer_identity_state'],'FAIL')
        self.assertEqual(got['sections']['deployments']['canonical_binding'],'DIFFERENT_REPO_HEAD')
        self.assertIsNone(got['sections']['guards']['effective'])
        self.assertEqual(got['sections']['guards']['effective_state'],'UNKNOWN')
        serialized=json.dumps(got)
        self.assertNotIn('gross_realized_profit_component',serialized)
        self.assertNotIn('999.00',serialized)
        self.assertNotIn('account-',serialized)
        self.assertEqual(got['finding_count'],1)

    def test_legitimate_unavailable_section_remains_section_unavailable(self):
        model=self.model(); payload=adapter_payload(model.sha)
        payload['sections']['ledger'].update(availability='UNAVAILABLE',reasons=['SOURCE_MISSING'],data={})
        got=model._project_source_observations(json.dumps(payload).encode())
        self.assertEqual(got['status'],'AVAILABLE')
        self.assertEqual(got['sections']['ledger']['availability'],'UNAVAILABLE')
        self.assertIsNone(got['sections']['ledger']['deal_events'])
        self.assertIsNone(got['sections']['ledger']['missing_ledger_count'])

    def test_invalid_diagnostic_code_is_rejected_not_rendered(self):
        model=self.model(); payload=adapter_payload(model.sha); payload['errors'][0]['code']='<img onerror=alert(1)>'
        with self.assertRaisesRegex(Refused,'SOURCE_ADAPTER_FINDING_SCHEMA'):
            model._project_source_observations(json.dumps(payload).encode())

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
            self.assertEqual(f['snapshot']['source_observations']['status'],'UNAVAILABLE')
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
    def _update_work_record(self,model,**changes):
        path=pathlib.Path(model.c['registry'])/'ct-test-lane.json'
        record=json.loads(path.read_text(encoding='utf-8'))
        record.update(changes)
        path.write_text(json.dumps(record),encoding='utf-8')
    def _write_terminal_result(self,model,state):
        path=pathlib.Path(model.c['jobs'])/'job-one'/'result.json'
        path.write_text(json.dumps({'job_id':'job-one','state':state}),encoding='utf-8')
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
    def test_terminal_result_never_erases_explicit_work_gate(self):
        cases=(
            ('COMPLETE','WAITING_GPT_SCRUTINY_EXACT_HEAD','WAITING_REVIEW'),
            ('FAILED','SERIALIZED_STATE_CONVERGENCE','WAITING_STATE_SYNC'),
            ('TIMED_OUT','REPAIR_1_1_EXHAUSTED','REPAIR_LIMIT'),
            ('CANCELLED','E_OWNER_DECISION_REQUIRED','OWNER_OR_SOURCE_GATE'),
        )
        for terminal,blocker,expected in cases:
            with self.subTest(terminal=terminal,blocker=blocker), tempfile.TemporaryDirectory() as td:
                model=self._make_work_roots(td)
                self._update_work_record(model,state='BLOCKED',blocker_class=blocker)
                self._write_terminal_result(model,terminal)
                row=model.work()['rows'][0]
                self.assertEqual(row['display_state'],expected)
                self.assertEqual(row['category'],expected)
                self.assertEqual(row['job_state'],terminal)
                self.assertTrue(row['unresolved'])
                self.assertEqual(row['acceptance'],'UNKNOWN')
                self.assertEqual(row['canonical'],'NOT_ASSESSED')
                self.assertEqual(row['consumption'],'UNKNOWN')
    def test_done_historical_blocker_is_history_not_unresolved(self):
        with tempfile.TemporaryDirectory() as td:
            model=self._make_work_roots(td,with_job=False)
            self._update_work_record(model,state='DONE',blocker_class='HISTORICAL_REVIEW_FAILURE')
            row=model.work()['rows'][0]
        self.assertEqual(row['state'],'DONE')
        self.assertFalse(row['unresolved'])
        self.assertEqual(row['display_state'],'OWNER_OR_SOURCE_GATE')
        self.assertEqual(row['acceptance'],'UNKNOWN')
    def test_done_without_gate_records_scope_closure_not_pass(self):
        with tempfile.TemporaryDirectory() as td:
            model=self._make_work_roots(td,with_job=False)
            self._update_work_record(model,state='DONE',blocker_class='',reviewed_head='a'*40,reviewer='reviewer')
            row=model.work()['rows'][0]
        self.assertEqual(row['display_state'],'RECORDED_SCOPE_CLOSURE')
        self.assertFalse(row['unresolved'])
        self.assertEqual(row['acceptance'],'UNKNOWN')
        self.assertEqual(row['canonical'],'NOT_ASSESSED')
    def test_superseded_by_is_claim_only_and_never_pass(self):
        with tempfile.TemporaryDirectory() as td:
            model=self._make_work_roots(td,with_job=False)
            self._update_work_record(model,state='DONE',blocker_class='',superseded_by='ct-successor')
            row=model.work()['rows'][0]
        self.assertEqual(row['superseded_by_claim'],'ct-successor')
        self.assertEqual(row['acceptance'],'UNKNOWN')
        self.assertEqual(row['canonical'],'NOT_ASSESSED')
        self.assertFalse(row['unresolved'])
if __name__=="__main__":
    if '--browser-fixtures' in sys.argv: print(json.dumps(browser_fixtures(),ensure_ascii=True))
    else: unittest.main()
