import json, os, pathlib, subprocess, sys, tempfile, unittest
from types import SimpleNamespace
from unittest import mock
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parent))
from model import Model, Refused, SOURCE_ADAPTER_IMPORT_ALLOWLIST, WORK_BUCKETS, _DashboardParser, clean, safe_bytes, digest, number, age_state, utcnow, stamp, projection_view, work_presentation
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
        self.assertIsNotNone(stamp('2026-09-24T00:00:00.1234567Z'))
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
        paths=list(pathlib.Path(model.c['registry']).glob('*.json'))
        self.assertEqual(len(paths),1)
        path=paths[0]
        record=json.loads(path.read_text(encoding='utf-8'))
        record.update(changes)
        path.write_text(json.dumps(record),encoding='utf-8')
    def _write_terminal_result(self,model,state):
        path=pathlib.Path(model.c['jobs'])/'job-one'/'result.json'
        path.write_text(json.dumps({'job_id':'job-one','state':state}),encoding='utf-8')
    def test_running_registry_without_durable_job_is_stale_not_chat_liveness(self):
        with tempfile.TemporaryDirectory() as td:
            work=self._make_work_roots(td,with_job=False).work(); rows=work['rows']
        self.assertEqual(len(rows),1); row=rows[0]
        self.assertEqual(row['display_state'],'STALE_REGISTRY')
        self.assertEqual(row['process_health'],'NO_DURABLE_JOB')
        self.assertIsNone(row['runner_alive']); self.assertEqual(row['progress'],'UNKNOWN')
        self.assertFalse(row['actual_live']); self.assertEqual(work['counts']['actual_live_jobs'],0)
    def test_pid_fields_alone_never_establish_liveness(self):
        with tempfile.TemporaryDirectory() as td:
            model=self._make_work_roots(td,with_job=True)
            work=model.work(); rows=work['rows']
        self.assertEqual(len(rows),1); row=rows[0]
        self.assertEqual(row['process_health'],'UNAVAILABLE')
        self.assertEqual(row['display_state'],'LIVENESS_UNAVAILABLE')
        self.assertNotEqual(row['display_state'],'ACTIVE_PROCESS')
        self.assertIsNone(row['runner_alive']); self.assertEqual(row['progress'],'UNKNOWN')
        self.assertIsNone(work['counts']['actual_live_jobs'])
        self.assertIsNone(work['counts']['by_bucket']['ACTUAL LIVE JOBS'])
        self.assertEqual(work['process_proven_count'],0)
        self.assertFalse(work['process_probe_complete'])
    def test_thirteenth_unknown_process_probe_makes_live_counts_unknown(self):
        with tempfile.TemporaryDirectory() as td:
            model=self._make_work_roots(td,lane='ct-test-lane-00',with_job=True)
            registry=pathlib.Path(model.c['registry']); leases=pathlib.Path(model.c['leases']); jobs=pathlib.Path(model.c['jobs'])
            for index in range(1,13):
                lane=f'ct-test-lane-{index:02d}'; job_id=f'job-{index:02d}'
                record={'lane_id':lane,'state':'RUNNING','updated_at':utcnow(),'owner_chat':'fixture',
                        'worker':'fixture','blocker_class':'','head_sha':'a'*40,'reviewed_head':None,
                        'reviewer':None,'dependencies':[]}
                (registry/(lane+'.json')).write_text(json.dumps(record),encoding='utf-8')
                (leases/(lane+'.json')).write_text(json.dumps({'lane_id':lane,'job_id':job_id}),encoding='utf-8')
                job=jobs/job_id; job.mkdir()
                (job/'state.json').write_text(json.dumps({'job_id':job_id,'state':'RUNNING'}),encoding='utf-8')
            def observation(lane_id,job_id):
                unknown=lane_id.endswith('-12')
                return {'health':'UNKNOWN' if unknown else 'ACTIVE','observed_state':'UNKNOWN' if unknown else 'RUNNING',
                        'durable_state':'RUNNING','runner_alive':not unknown,
                        'child_alive':False,'postcondition_alive':False,'heartbeat_age_sec':5.0,
                        'retry_decision':'REFUSE_RETRY','checked_utc':utcnow(),
                        'status_source':'ACCEPTED_CHAT_STALL_LANE_STATUS'}
            with mock.patch.object(model,'lane_status',side_effect=observation) as probe:
                work=model.work()
        self.assertEqual(probe.call_count,13)
        self.assertEqual(work['process_probed_count'],13)
        self.assertEqual(work['process_proven_count'],12)
        self.assertEqual(work['process_eligible_count'],13)
        self.assertFalse(work['process_probe_complete'])
        self.assertIsNone(work['counts']['actual_live_jobs'])
        self.assertIsNone(work['counts']['by_bucket']['ACTUAL LIVE JOBS'])
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
    def test_work_locator_fixture_covers_every_bucket_and_unknown_truth(self):
        base={'state':'UNKNOWN','blocker':'','freshness':'CURRENT','process_health':'UNKNOWN','process_state':'UNKNOWN',
              'runner_alive':None,'child_alive':None,'postcondition_alive':None,'process_freshness':'UNKNOWN',
              'source_class':'LANE_REGISTRY','track':'UNKNOWN','ea_family':'UNKNOWN','acceptance':'UNKNOWN',
              'canonical_relation':'UNKNOWN'}
        fixtures={
            'CURRENT ACTIONABLE':base|{'state':'RUNNING'},
            'READY':base|{'state':'READY'},
            'WAITING / BLOCKED':base|{'state':'WAITING','blocker':'DEPENDENCY'},
            'OWNER DECISION NEEDED':base|{'state':'BLOCKED','blocker':'E_OWNER_DECISION_REQUIRED'},
            'PARKED':base|{'state':'PARKED'},
            'HISTORICAL UNRESOLVED / UNKNOWN':base|{'state':'RUNNING','freshness':'STALE'},
            'ACTUAL LIVE JOBS':base|{'state':'RUNNING','process_health':'ACTIVE','process_state':'RUNNING',
                                      'runner_alive':True,'process_freshness':'CURRENT'},
            'RECENTLY DONE':base|{'state':'DONE'},
        }
        self.assertEqual(tuple(fixtures),WORK_BUCKETS)
        for expected,row in fixtures.items():
            with self.subTest(bucket=expected):
                got=work_presentation(row)
                self.assertEqual(got['bucket'],expected)
                self.assertIsInstance(got['next'],str); self.assertTrue(got['next'])
        unknown=work_presentation(base)
        self.assertEqual(unknown['bucket'],'HISTORICAL UNRESOLVED / UNKNOWN')
        self.assertEqual(base['track'],'UNKNOWN'); self.assertEqual(base['ea_family'],'UNKNOWN')
        self.assertEqual(base['acceptance'],'UNKNOWN'); self.assertEqual(base['canonical_relation'],'UNKNOWN')
    def test_canonical_taskboard_row_keeps_plan_status_separate_from_acceptance(self):
        model=Model({'repo':'.','registry':'.','leases':'.','jobs':'.'}); model.sha='a'*40
        docs={'taskboards/active/P01.md':'## ORDER-LOCATOR-1 — [system] locator slice — `READY`\n'}
        rows=model._taskboard_rows(docs)
        self.assertEqual(len(rows),1); row=rows[0]
        self.assertEqual(row['id'],'ORDER-LOCATOR-1')
        self.assertEqual(row['plan_status'],'READY')
        self.assertEqual(row['bucket'],'READY')
        self.assertEqual(row['track'],'SYSTEM')
        self.assertEqual(row['acceptance'],'UNKNOWN')
        self.assertEqual(row['ownership_state'],'UNKNOWN')
        self.assertEqual(row['execution_state'],'UNKNOWN')
        self.assertEqual(row['canonical_relation'],'EXACT_CANONICAL_SOURCE')
    def test_current_taskboard_headings_are_explicit_and_ambiguity_safe(self):
        model=Model({'repo':'.','registry':'.','leases':'.','jobs':'.'}); model.sha='a'*40
        docs={'taskboards/active/P01.md':'\n'.join((
            '## ORDER-1461 — [tooling/integrity] stale detector — `OPEN — item 1 DONE; item 2 still owed`',
            '## ORDER-731 — [factory/S2a] attested blob pin — `DONE (item 1); item 2 still OPEN`',
            '## ORDER-MT5-REPORT-PARSER-HARDENING-R4-20260920 — [tooling/reporting] repair — `DONE_REVIEWED / CANONICAL / SCRUTINY_PASS_HIGH / SOURCE_ACCEPTED`',
            '## ORDER-PROSE-OPEN — OPEN questions are preserved in this completed title — `DONE`',
            '## ORDER-EXPLICIT-CONFLICT — conflicting declaration — `DONE / BLOCKED`',
            '## ORDER-OPEN-ONLY — legacy open declaration — `OPEN`',
        ))}
        rows={row['id']:row for row in model._taskboard_rows(docs)}
        self.assertEqual(rows['ORDER-1461']['plan_status'],'UNKNOWN')
        self.assertEqual(rows['ORDER-731']['plan_status'],'UNKNOWN')
        self.assertEqual(rows['ORDER-MT5-REPORT-PARSER-HARDENING-R4-20260920']['plan_status'],'DONE')
        self.assertEqual(rows['ORDER-PROSE-OPEN']['plan_status'],'DONE')
        self.assertEqual(rows['ORDER-EXPLICIT-CONFLICT']['plan_status'],'UNKNOWN')
        self.assertEqual(rows['ORDER-OPEN-ONLY']['plan_status'],'READY')
    def test_accepted_exact_lane_job_active_observation_is_actual_live(self):
        with tempfile.TemporaryDirectory() as td:
            model=self._make_work_roots(td,with_job=True)
            live={'health':'ACTIVE','observed_state':'RUNNING','durable_state':'RUNNING','runner_alive':True,
                  'child_alive':False,'postcondition_alive':False,'heartbeat_age_sec':5.0,
                  'retry_decision':'REFUSE_RETRY','checked_utc':utcnow(),'status_source':'ACCEPTED_CHAT_STALL_LANE_STATUS'}
            with mock.patch.object(model,'lane_status',return_value=live):
                work=model.work(); row=work['rows'][0]
        self.assertTrue(row['actual_live'])
        self.assertEqual(row['bucket'],'ACTUAL LIVE JOBS')
        self.assertEqual(work['counts']['actual_live_jobs'],1)
    def test_historical_unknown_rows_searchable_but_excluded_from_active_counts(self):
        with tempfile.TemporaryDirectory() as td:
            model=self._make_work_roots(td,lane='historical-family-alias',with_job=False)
            self._update_work_record(model,state='RUNNING',updated_at='2000-01-01T00:00:00Z',
                                     objective='historic objective',direct_consumer='future consumer')
            work=model.work(); row=work['rows'][0]
        self.assertEqual(row['bucket'],'HISTORICAL UNRESOLVED / UNKNOWN')
        self.assertIn('historical-family-alias',row['search_text'])
        self.assertIn('future consumer',row['search_text'])
        self.assertEqual(work['counts']['active_workers'],0)
        self.assertEqual(work['counts']['actual_live_jobs'],0)
    def test_fresh_normal_registry_lane_is_discoverable_without_special_case(self):
        lane='ct-fb-ai-trading-thread-intake-ro-20260929'
        with tempfile.TemporaryDirectory() as td:
            model=self._make_work_roots(td,lane=lane,with_job=False)
            path=pathlib.Path(model.c['registry'])/(lane+'.json')
            record=json.loads(path.read_text(encoding='utf-8'))
            record.update(state='WAITING',objective='Facebook AI trading thread planning intake',
                          direct_consumer='Main CT planning stream',blocker_class='MAIN_CT_PLANNING_INTAKE_REQUIRED')
            path.write_text(json.dumps(record),encoding='utf-8')
            row=model.work()['rows'][0]
        self.assertEqual(row['id'],lane)
        self.assertIn(lane,row['search_text'])
        self.assertIn('Facebook AI trading thread planning intake',row['search_text'])
        self.assertNotIn(lane,pathlib.Path(__file__).with_name('model.py').read_text(encoding='utf-8'))
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

class WorkAcceptanceTests(unittest.TestCase):
    def fixture(self, td):
        model=OwnerWebAppUnitTests()._make_work_roots(td,with_job=False)
        model.sha='a'*40
        model._canonical_work_documents=lambda: {}
        root=pathlib.Path(td)/'acceptance'; root.mkdir()
        contract={'task':'fixture exact bytes'}
        contract_hash=digest(json.dumps(contract).encode())
        receipt={'schema_version':'EA_LAB_SCRUTINY_RESULT_V1','verdict':'SCRUTINY_PASS','confidence':'HIGH',
                 'decision':'ALLOW_INTEGRATION','findings':[],'reviewed_head':'a'*40}
        original={'schema':'mainct_lane_b_stale_proof_scrutiny/1','verdict':'SCRUTINY_PASS','confidence':'HIGH',
                  'integration_disposition':'ALLOW_INTEGRATION','reviewed_head':'a'*40,'contract_sha256':contract_hash,
                  'review_metadata':{'author_lane':'ct-test-lane'},'material_unresolved_findings':[],
                  'findings':[{'severity':'HIGH','status':'CLOSED_IN_THIS_OWNER_APPROVED_ROUND'}],
                  'historical_failures_preserved':{'old':'SCRUTINY_FAIL'}}
        entry={'lane_id':'ct-test-lane','reviewed_head':'a'*40,'task_contract_sha256':contract_hash,
               'task_contract_file':'contract.json','raw_review_file':'original.json','raw_review_sha256':'0'*64,
               'normalized_review_file':'normalized.json','normalized_review_sha256':'0'*64,'material_unresolved_findings':0}
        binding={'schema_version':'EA_LAB_DOT_ACCEPTANCE_BINDING_V1','authority':'DOT_DERIVED_REVIEW_PROJECTION',
                 'owner':'EA_LAB-MAIN-CT-20260930','observed_at_utc':utcnow(),'entries':[entry]}
        config={'manifest':str(root/'manifest.json'),'sha256':'0'*64,
                'expected':[{'lane_id':'ct-test-lane','reviewed_head':'a'*40,'task_contract_sha256':contract_hash}]}
        model.c['work_acceptance']=config
        def sync():
            for name,obj in (('contract.json',contract),('original.json',original),('normalized.json',receipt)):
                (root/name).write_bytes(json.dumps(obj).encode())
            entry['raw_review_sha256']=digest((root/'original.json').read_bytes())
            entry['normalized_review_sha256']=digest((root/'normalized.json').read_bytes())
            (root/'manifest.json').write_bytes(json.dumps(binding).encode())
            config['sha256']=digest((root/'manifest.json').read_bytes())
        sync()
        return SimpleNamespace(model=model,root=root,contract=contract,receipt=receipt,original=original,
                               entry=entry,binding=binding,config=config,sync=sync)

    def unknown(self,f,reason):
        work=f.model.work();row=work['rows'][0]
        self.assertEqual(row['acceptance'],'UNKNOWN')
        self.assertEqual(row['acceptance_reason'],reason)
        self.assertNotIn('acceptance_proof',row)
        self.assertEqual(row['integration_state'],'UNKNOWN')
        self.assertEqual(row['deployment_state'],'UNKNOWN')
        self.assertIn(reason,row['evidence_basis'])
        return work

    def test_exact_acceptance_preserves_raw_history_and_never_proves_runtime(self):
        with tempfile.TemporaryDirectory() as td:
            f=self.fixture(td); raw=(f.root/'original.json').read_bytes()
            before={p.name:p.read_bytes() for p in f.root.iterdir()}
            work=f.model.work();row=work['rows'][0]
            self.assertEqual(row['acceptance'],'SCRUTINY_PASS / HIGH / ALLOW_INTEGRATION (review only)')
            self.assertEqual(row['acceptance_proof']['raw_review_sha256'],digest(raw))
            self.assertFalse(row['actual_live']);self.assertEqual(row['job_state'],'NOT_OBSERVED')
            self.assertEqual(row['integration_state'],'UNKNOWN');self.assertEqual(row['deployment_state'],'UNKNOWN')
            self.assertEqual(row['canonical_relation'],'EXACT_CANONICAL_HEAD')
            self.assertEqual(work['sources']['acceptance']['availability'],'AVAILABLE')
            self.assertEqual(before,{p.name:p.read_bytes() for p in f.root.iterdir()})
            self.assertEqual(f.original['historical_failures_preserved']['old'],'SCRUTINY_FAIL')

    def test_default_absence_remains_unknown(self):
        with tempfile.TemporaryDirectory() as td:
            f=self.fixture(td);del f.model.c['work_acceptance']
            row=f.model.work()['rows'][0]
            self.assertEqual(row['acceptance'],'UNKNOWN');self.assertEqual(row['acceptance_reason'],'ACCEPTANCE_NOT_PROVIDED')

    def test_wrong_row_head_does_not_transfer_review(self):
        with tempfile.TemporaryDirectory() as td:
            f=self.fixture(td);OwnerWebAppUnitTests()._update_work_record(f.model,head_sha='b'*40)
            self.unknown(f,'ACCEPTANCE_ROW_HEAD_MISMATCH')

    def test_lane_and_contract_expected_mismatches(self):
        for key,value in (('lane_id','ct-other'),('reviewed_head','b'*40),('task_contract_sha256','b'*64)):
            with self.subTest(key=key),tempfile.TemporaryDirectory() as td:
                f=self.fixture(td);f.entry[key]=value;f.sync();self.unknown(f,'ACCEPTANCE_EXPECTED_MISMATCH')

    def test_each_pinned_input_hash_is_required(self):
        for name in ('manifest.json','contract.json','original.json','normalized.json'):
            with self.subTest(name=name),tempfile.TemporaryDirectory() as td:
                f=self.fixture(td);(f.root/name).write_bytes((f.root/name).read_bytes()+b' ')
                self.unknown(f,'ACCEPTANCE_MANIFEST_HASH' if name=='manifest.json' else 'ACCEPTANCE_SOURCE_HASH')

    def test_missing_source_is_explicit_unknown(self):
        for name in ('manifest.json','contract.json','original.json','normalized.json'):
            with self.subTest(name=name),tempfile.TemporaryDirectory() as td:
                f=self.fixture(td);(f.root/name).unlink();self.unknown(f,'ACCEPTANCE_SOURCE_UNAVAILABLE_OR_INVALID')

    def test_duplicate_and_conflicting_bindings_fail_entire_population(self):
        for conflict in (False,True):
            with self.subTest(conflict=conflict),tempfile.TemporaryDirectory() as td:
                f=self.fixture(td);other=dict(f.entry)
                if conflict: other['reviewed_head']='b'*40
                f.binding['entries'].append(other);f.sync();self.unknown(f,'ACCEPTANCE_DUPLICATE_OR_CONFLICTING_LANE')
        with tempfile.TemporaryDirectory() as td:
            f=self.fixture(td);f.config['expected'].append(dict(f.config['expected'][0]));self.unknown(f,'ACCEPTANCE_DUPLICATE_EXPECTED_LANE')

    def test_binding_age_is_distinct_from_historical_review_validity(self):
        for when in ((dt.datetime.now(dt.timezone.utc)-dt.timedelta(hours=25)).isoformat(),
                     (dt.datetime.now(dt.timezone.utc)+dt.timedelta(hours=1)).isoformat(),'2026-10-02T05:00:00','BAD'):
            with self.subTest(when=when),tempfile.TemporaryDirectory() as td:
                f=self.fixture(td);f.binding['observed_at_utc']=when;f.sync();self.unknown(f,'ACCEPTANCE_BINDING_STALE_OR_UNQUALIFIED')

    def test_review_strict_schema_and_criteria(self):
        cases=[({'schema_version':'mainct_lane_b_stale_proof_scrutiny/1'},'ACCEPTANCE_REVIEW_SCHEMA'),
               ({'extra':'forged'},'ACCEPTANCE_REVIEW_SCHEMA'),({'findings':['OPEN HIGH']},'ACCEPTANCE_REVIEW_FINDINGS'),
               ({'findings':False},'ACCEPTANCE_REVIEW_FINDINGS'),({'verdict':'PASS'},'ACCEPTANCE_REVIEW_CRITERIA'),
               ({'confidence':'MEDIUM'},'ACCEPTANCE_REVIEW_CRITERIA'),({'decision':'DEPLOY'},'ACCEPTANCE_REVIEW_CRITERIA'),
               ({'reviewed_head':'b'*40},'ACCEPTANCE_REVIEW_CRITERIA')]
        for changes,reason in cases:
            with self.subTest(changes=changes),tempfile.TemporaryDirectory() as td:
                f=self.fixture(td);f.receipt.update(changes);f.sync();self.unknown(f,reason)

    def test_raw_derived_fidelity_and_material_findings(self):
        cases=[({'schema':'UNSUPPORTED'},'ACCEPTANCE_RAW_SCHEMA'),({'reviewed_head':'b'*40},'ACCEPTANCE_RAW_IDENTITY'),
               ({'contract_sha256':'b'*64},'ACCEPTANCE_RAW_IDENTITY'),({'review_metadata':{'author_lane':'ct-other'}},'ACCEPTANCE_RAW_IDENTITY'),
               ({'verdict':'SCRUTINY_FAIL'},'ACCEPTANCE_DERIVATION_MISMATCH'),
               ({'material_unresolved_findings':[{'severity':'HIGH'}]},'ACCEPTANCE_RAW_MATERIAL_FINDING'),
               ({'findings':[{'severity':'HIGH','status':'OPEN'}]},'ACCEPTANCE_RAW_MATERIAL_FINDING')]
        for changes,reason in cases:
            with self.subTest(changes=changes),tempfile.TemporaryDirectory() as td:
                f=self.fixture(td);f.original.update(changes);f.sync();self.unknown(f,reason)
        with tempfile.TemporaryDirectory() as td:
            f=self.fixture(td);f.entry['material_unresolved_findings']=False;f.sync();self.unknown(f,'ACCEPTANCE_MATERIAL_FINDING')

    def test_duplicate_json_keys_and_nonfinite_values_refused(self):
        for tail,reason in ((',"owner":"EA_LAB-MAIN-CT-20260930"','ACCEPTANCE_DUPLICATE_JSON_KEY'),
                            (',"forged":NaN','ACCEPTANCE_NONFINITE_JSON')):
            with self.subTest(reason=reason),tempfile.TemporaryDirectory() as td:
                f=self.fixture(td);raw=(f.root/'manifest.json').read_text();raw=raw[:-1]+tail+'}'
                (f.root/'manifest.json').write_text(raw);f.config['sha256']=digest((f.root/'manifest.json').read_bytes());self.unknown(f,reason)

    def test_unsafe_paths_and_unpinned_config_refused(self):
        for filename in ('../outside.json','C:/outside.json','original.json/child','original.json:stream'):
            with self.subTest(filename=filename),tempfile.TemporaryDirectory() as td:
                f=self.fixture(td);f.entry['raw_review_file']=filename;f.sync();self.unknown(f,'ACCEPTANCE_SOURCE_PATH')
        with tempfile.TemporaryDirectory() as td:
            f=self.fixture(td);f.config['sha256']='BAD';self.unknown(f,'ACCEPTANCE_MANIFEST_PIN')
        with tempfile.TemporaryDirectory() as td:
            f=self.fixture(td);f.config['manifest']='manifest.json';self.unknown(f,'ACCEPTANCE_MANIFEST_PATH')

    def test_hardlink_alias_refused(self):
        with tempfile.TemporaryDirectory() as td:
            f=self.fixture(td);os.link(f.root/'original.json',f.root/'alias.json');self.unknown(f,'ACCEPTANCE_HARDLINK_REFUSED')

    def test_empty_missing_population_and_untrusted_authority_refused(self):
        for changes,reason in (({'entries':[]},'ACCEPTANCE_BINDING_POPULATION'),
                               ({'entries':[{}]*33},'ACCEPTANCE_BINDING_POPULATION'),
                               ({'owner':'another-owner'},'ACCEPTANCE_BINDING_AUTHORITY'),
                               ({'authority':'REVIEWER'},'ACCEPTANCE_BINDING_AUTHORITY')):
            with self.subTest(changes=changes),tempfile.TemporaryDirectory() as td:
                f=self.fixture(td);f.binding.update(changes);f.sync();self.unknown(f,reason)
        with tempfile.TemporaryDirectory() as td:
            f=self.fixture(td);f.config['expected'].append({'lane_id':'ct-extra','reviewed_head':'a'*40,'task_contract_sha256':'b'*64})
            self.unknown(f,'ACCEPTANCE_BINDING_POPULATION_MISMATCH')

    def test_total_reader_budget_fails_closed_without_partial_acceptance(self):
        with tempfile.TemporaryDirectory() as td:
            f=self.fixture(td)
            for i in range(2,23):
                lane='ct-extra-'+str(i);entry=dict(f.entry);entry['lane_id']=lane
                objects={'task_contract':f.contract,'raw_review':{**f.original,'review_metadata':{'author_lane':lane}},'normalized_review':f.receipt}
                for kind,obj in objects.items():
                    name=kind+str(i)+'.json';raw=json.dumps(obj).encode();(f.root/name).write_bytes(raw)
                    entry[kind+'_file']=name;entry[kind+'_sha256']=digest(raw)
                f.binding['entries'].append(entry)
                f.config['expected'].append({k:entry[k] for k in ('lane_id','reviewed_head','task_contract_sha256')})
            f.sync();self.unknown(f,'ACCEPTANCE_READ_BUDGET')

    def test_done_frozen_success_and_plan_row_never_infer_acceptance(self):
        for state in ('DONE','FROZEN','RUNNING'):
            with self.subTest(state=state),tempfile.TemporaryDirectory() as td:
                f=self.fixture(td);OwnerWebAppUnitTests()._update_work_record(f.model,state=state,reviewed_head='a'*40)
                del f.model.c['work_acceptance'];row=f.model.work()['rows'][0]
                self.assertEqual(row['acceptance'],'UNKNOWN');self.assertEqual(row['integration_state'],'UNKNOWN')
        with tempfile.TemporaryDirectory() as td:
            f=self.fixture(td);f.model._canonical_work_documents=lambda: {'taskboards/active/P01.md':'## ORDER-X `ACCEPTED`'}
            rows=f.model.work()['rows'];plan=next(r for r in rows if r['source_class']=='CANONICAL_TASKBOARD')
            self.assertEqual(plan['acceptance'],'UNKNOWN');self.assertEqual(plan['acceptance_reason'],'ACCEPTANCE_NOT_BOUND')

    def test_duplicate_registry_identity_does_not_receive_acceptance(self):
        with tempfile.TemporaryDirectory() as td:
            f=self.fixture(td);root=pathlib.Path(f.model.c['registry'])
            (root/'duplicate.json').write_bytes((root/'ct-test-lane.json').read_bytes())
            rows=self.unknown(f,'ACCEPTANCE_DUPLICATE_ROW_IDENTITY')['rows']
            self.assertEqual(len(rows),2)
            self.assertTrue(all(r['acceptance']=='UNKNOWN' and r['acceptance_reason']=='ACCEPTANCE_DUPLICATE_ROW_IDENTITY' for r in rows))

    def test_conflicting_registry_reviewed_head_is_unknown(self):
        with tempfile.TemporaryDirectory() as td:
            f=self.fixture(td);OwnerWebAppUnitTests()._update_work_record(f.model,reviewed_head='b'*40)
            self.unknown(f,'ACCEPTANCE_ROW_REVIEW_MISMATCH')

    def test_conflicting_malformed_same_lane_cannot_disappear_from_uniqueness(self):
        for changes in ({'state':[]},{'dependencies':None},{'owner_chat':{}},{'state':{}}, {'lane_id':'CT-TEST-LANE','dependencies':None}):
            with self.subTest(changes=changes),tempfile.TemporaryDirectory() as td:
                f=self.fixture(td);root=pathlib.Path(f.model.c['registry'])
                bad=json.loads((root/'ct-test-lane.json').read_bytes());bad.update(head_sha='b'*40);bad.update(changes)
                (root/'conflicting.json').write_bytes(json.dumps(bad).encode())
                self.unknown(f,'ACCEPTANCE_DUPLICATE_ROW_IDENTITY')

    def test_unattributable_registry_input_makes_identity_population_unknown(self):
        values=['{', '[]', 'null', '{}', '{"lane_id":null}', '{"lane_id":"../escape"}', '{"lane_id":".."}',
                '{"lane_id":"ct-other","lane_id":"ct-test-lane"}',
                '{"lane_id":"ct-other","nested":{"k":1,"k":2}}',
                '{"lane_id":"ct-other","forged":NaN}']
        for raw in values:
            with self.subTest(raw=raw),tempfile.TemporaryDirectory() as td:
                f=self.fixture(td);(pathlib.Path(f.model.c['registry'])/'unattributable.json').write_bytes(raw.encode())
                work=self.unknown(f,'ACCEPTANCE_REGISTRY_POPULATION_UNKNOWN')
                self.assertEqual(work['sources']['acceptance']['availability'],'UNKNOWN')
                self.assertEqual(work['sources']['acceptance']['reason'],'ACCEPTANCE_REGISTRY_POPULATION_UNKNOWN')

    def test_safe_other_rejected_lane_is_tainted_without_inventing_target_conflict(self):
        with tempfile.TemporaryDirectory() as td:
            f=self.fixture(td);(pathlib.Path(f.model.c['registry'])/'other.json').write_bytes(json.dumps({'lane_id':'ct-other','state':[]}).encode())
            row=f.model.work()['rows'][0]
            self.assertEqual(row['acceptance'],'SCRUTINY_PASS / HIGH / ALLOW_INTEGRATION (review only)')
            self.assertEqual(row['integration_state'],'UNKNOWN')

    def test_same_byte_identity_capture_precedes_presentation_without_reread(self):
        with tempfile.TemporaryDirectory() as td:
            f=self.fixture(td);root=pathlib.Path(f.model.c['registry']);source=root/'ct-test-lane.json'
            before=source.read_bytes();registry_reads=[]
            import model as module
            original=module.safe_bytes
            def observe(path,base,*args):
                if pathlib.Path(path).parent==root: registry_reads.append(pathlib.Path(path).name)
                return original(path,base,*args)
            with mock.patch.object(module,'safe_bytes',side_effect=observe):row=f.model.work()['rows'][0]
            self.assertEqual(registry_reads,['ct-test-lane.json'])
            self.assertEqual(source.read_bytes(),before)
            self.assertEqual(row['acceptance_reason'],'EXACT_DOT_BINDING_VERIFIED')

    def test_unreadable_registry_record_is_unknown_population(self):
        with tempfile.TemporaryDirectory() as td:
            f=self.fixture(td);root=pathlib.Path(f.model.c['registry']);bad=root/'unreadable.json';bad.write_bytes(b'{}')
            import model as module
            original=module.safe_bytes
            def observe(path,base,*args):
                if pathlib.Path(path)==bad:raise OSError('fixture unreadable record')
                return original(path,base,*args)
            with mock.patch.object(module,'safe_bytes',side_effect=observe):self.unknown(f,'ACCEPTANCE_REGISTRY_POPULATION_UNKNOWN')

    def test_row_failure_does_not_change_locator_or_execution(self):
        with tempfile.TemporaryDirectory() as td:
            f=self.fixture(td);before=f.model.work()['rows'][0]
            f.receipt['verdict']='SCRUTINY_FAIL';f.sync();after=f.model.work()['rows'][0]
            for key in ('work_id','lane_id','state','owner','head','blocker','next','bucket','actual_live','search_text','source_locator','canonical_relation','process_health'):
                self.assertEqual(before[key],after[key],key)
            self.assertEqual(after['acceptance'],'UNKNOWN')

class OwnerLightPhase0Tests(unittest.TestCase):
    def test_explicit_tracks_and_unknown_navigation(self):
        from model import OWNER_TRACKS,OWNER_GROUPS,owner_projection
        self.assertEqual(len(OWNER_TRACKS),5);self.assertEqual(len(OWNER_GROUPS),7)
        for track in OWNER_TRACKS:
            row=owner_projection({'track':track,'bucket':'READY','source_locator':'fixture.json'})
            self.assertEqual(row['owner_track'],track);self.assertEqual(row['track_qualification'],'EXPLICIT_SOURCE_TRACK')
            self.assertEqual(row['owner_group'],'READY');self.assertIn('fixture.json',row['track_basis'])
        for value in ('RESEARCH','CORE',None,[],{'track':'SYSTEM'},'<img>', 'system'):
            row=owner_projection({'track':value,'objective':'SYSTEM EA TESTING','state':'RUNNING'})
            self.assertEqual(row['owner_track'],'SYSTEM');self.assertEqual(row['track_qualification'],'UNKNOWN')
            self.assertEqual(row['checkpoint_state'],'UNKNOWN');self.assertEqual(row['decision_state'],'UNKNOWN')
        for declared,expected in [('EA BUILD','EA BUILD / IMPLEMENTATION'),('EA PLANNING','EA RESEARCH / PLANNING'),('EA RESEARCH','EA RESEARCH / PLANNING')]:
            self.assertEqual(owner_projection({'track':declared})['owner_track'],expected)

    def test_owner_groups_preserve_reservation_and_history(self):
        from model import owner_projection
        for bucket,group in [('ACTUAL LIVE JOBS','RUNNING'),('WAITING / BLOCKED','WAITING/BLOCKED'),('PARKED','PARKED'),('READY','READY'),('RECENTLY DONE','RECENTLY DONE'),('OWNER DECISION NEEDED','OWNER DECISION NEEDED'),('CURRENT ACTIONABLE','CURRENT ACTIONABLE')]:
            row={'bucket':bucket,'state':'RUNNING','track':'EA TESTING'};before=dict(row)
            self.assertEqual(owner_projection(row)['owner_group'],group);self.assertEqual(row,before)
        self.assertTrue(owner_projection({'bucket':'HISTORICAL UNRESOLVED / UNKNOWN'})['historical'])
        self.assertEqual(owner_projection({'state':'RUNNING'})['owner_group'],'CURRENT ACTIONABLE')

    def test_acceptance_cli_disabled_and_requires_both_pins(self):
        args=parser().parse_args([]);self.assertNotIn('work_acceptance',config_from_args(args))
        for extra in (['--work-acceptance-config','D:/absent.json'],['--work-acceptance-config-sha256','a'*64],['--work-acceptance-config','relative.json','--work-acceptance-config-sha256','a'*64]):
            with self.assertRaises(Refused): config_from_args(parser().parse_args(extra))

    def test_pinned_read_only_acceptance_cli_and_identity(self):
        with tempfile.TemporaryDirectory() as td:
            path=pathlib.Path(td)/'config.json'
            value={'manifest':str(pathlib.Path(td)/'manifest.json'),'sha256':'a'*64,'expected':[]}
            raw=json.dumps(value).encode();path.write_bytes(raw)
            args=parser().parse_args(['--work-acceptance-config',str(path),'--work-acceptance-config-sha256',digest(raw)])
            config=config_from_args(args);self.assertEqual(config['work_acceptance'],value)
            self.assertEqual(path.read_bytes(),raw);identity(config)
            changed=dict(config);changed['work_acceptance']={**value,'sha256':'b'*64}
            self.assertNotEqual(identity(config)['sources_sha256'],identity(changed)['sources_sha256'])
            args.work_acceptance_config_sha256='b'*64
            with self.assertRaises(Refused):config_from_args(args)
            for raw in (b'{"manifest":"x","manifest":"y","sha256":"a","expected":[]}',b'{"manifest":"x","sha256":NaN,"expected":[]}',b'[]',b'{',b'{"manifest":"x","sha256":"a","expected":[],"extra":1}'):
                path.write_bytes(raw);args.work_acceptance_config_sha256=digest(raw)
                with self.assertRaises(Refused):config_from_args(args)

class PassiveCheckpointTests(unittest.TestCase):
    def fixture(self,td):
        root=pathlib.Path(td);module=root/'module.py';module.write_bytes(b'# SYNTHETIC fixture only')
        contract=root/'contract.json';contract.write_bytes(b'{}');result=root/'result.json';result.write_bytes(b'{}')
        pin=lambda path:{'path':str(path),'sha256':digest(path.read_bytes())}
        value={'job_identity':'DOT-RO16-F0-MECHANICS-20261002','owner':'DOT','task':'F0 fixture',
               'stage':'F0_COMPLETE_PHASE0_GATE','source_status':'ISOLATED','fixture_status':'PASS_32_CASES_286_ASSERTIONS',
               'review':{'status':'NOT_RUN'},'integration':{'status':'PROPOSAL_ONLY_NOT_ADMITTED'},
               'native_runtime_status':'NOT_RUN_NOT_QUALIFIED','result':{'status':'PASS','fixture_cases':32,'assertions':286,'failed':0,'test_result':pin(result)},
               'contract':pin(contract),'exact_source':{'module':pin(module)},'updated_at':'2026-10-02T08:24:54Z',
               'consumer_mode':'PASSIVE_FILE_READ_ONLY_NO_STATE_WRITER','objective':'H011 H047 H048 H086 fixture','blocker':'Review not run','oneNEXT':'DOT bounded review only'}
        index=root/'index.json';checkpoint=root/'checkpoint.json'
        index.write_text(json.dumps({**value,'schema':'dot_f0_queue_ready_evidence/1'}));checkpoint.write_text(json.dumps({**value,'schema':'dot_f0_continuity_checkpoint/1'}))
        config={'index':str(index),'index_sha256':digest(index.read_bytes()),'checkpoint':str(checkpoint),'checkpoint_sha256':digest(checkpoint.read_bytes())}
        return Model({'repo':str(root),'work_checkpoint':config}),index,checkpoint

    def test_passive_checkpoint_fixture_only_not_overall_acceptance(self):
        with tempfile.TemporaryDirectory() as td:
            model,index,checkpoint=self.fixture(td);before=(index.read_bytes(),checkpoint.read_bytes())
            row=model.work_checkpoint()[0];self.assertFalse(row['actual_live']);self.assertEqual(row['acceptance'],'UNKNOWN')
            self.assertEqual(row['freshness'],'UNKNOWN');self.assertEqual(row['passive_review_state'],'NOT_RUN')
            self.assertEqual(row['native_state'],'NOT_RUN_NOT_QUALIFIED');self.assertEqual(row['passive_integration_state'],'PROPOSAL_ONLY_NOT_ADMITTED')
            self.assertEqual(before,(index.read_bytes(),checkpoint.read_bytes()));self.assertEqual(Model({'repo':td}).work_checkpoint(),[])

    def test_passive_checkpoint_hash_crossbinding_and_source_guards(self):
        with tempfile.TemporaryDirectory() as td:
            model,index,checkpoint=self.fixture(td);raw=index.read_bytes()
            index.write_bytes(raw+b' ');self.assertEqual(model.work_checkpoint(),[])
            index.write_bytes(raw);checkpoint.write_text('{}');self.assertEqual(model.work_checkpoint(),[])
        for field,value in [('review',{'status':'PASS'}),('integration',{'status':'INTEGRATED'}),('native_runtime_status','LIVE'),('owner','somebody'),('job_identity','different'),('consumer_mode','STATE_WRITER')]:
            with tempfile.TemporaryDirectory() as td:
                model,index,checkpoint=self.fixture(td)
                for path in (index,checkpoint):
                    obj=json.loads(path.read_bytes());obj[field]=value;path.write_text(json.dumps(obj))
                config=model.c['work_checkpoint'];config['index_sha256']=digest(index.read_bytes());config['checkpoint_sha256']=digest(checkpoint.read_bytes())
                self.assertEqual(model.work_checkpoint(),[],field)
        with tempfile.TemporaryDirectory() as td:
            model,index,checkpoint=self.fixture(td);(pathlib.Path(td)/'module.py').write_bytes(b'changed')
            self.assertEqual(model.work_checkpoint(),[])

    def test_passive_checkpoint_cli_explicit_pinned_disabled(self):
        self.assertNotIn('work_checkpoint',config_from_args(parser().parse_args([])))
        with tempfile.TemporaryDirectory() as td:
            model,index,checkpoint=self.fixture(td);path=pathlib.Path(td)/'caller.json';raw=json.dumps(model.c['work_checkpoint']).encode();path.write_bytes(raw)
            args=parser().parse_args(['--work-checkpoint-config',str(path),'--work-checkpoint-config-sha256',digest(raw)])
            config=config_from_args(args);self.assertEqual(config['work_checkpoint'],model.c['work_checkpoint']);identity(config)
            args.work_checkpoint_config_sha256='b'*64
            with self.assertRaises(Refused):config_from_args(args)
            args.work_checkpoint_config_sha256=None
            with self.assertRaises(Refused):config_from_args(args)

class PassiveCheckpointV2Tests(unittest.TestCase):
    fixture=PassiveCheckpointTests.fixture
    def v2(self,td):
        model,old,unused=self.fixture(td);previous=json.loads(old.read_bytes());root=pathlib.Path(td)
        value={'task_id':previous['job_identity'],'lane_id':None,'owner':'DOT','objective':'F0 fixture','exact_source_head':{'isolated_module':previous['exact_source']['module']},
               'contract_identity':[],'current_stage':'TERMINAL_F0_FIXTURE_VALIDATION_COMPLETE_PHASE0_HOLD','last_completed_stage':'fixture-only completion',
               'current_durable_job_identity':{'logical_job_id':previous['job_identity']},'process_identity_when_proven':{'historical_OS_identity':'UNKNOWN_NOT_INDEPENDENTLY_CAPTURED'},
               'result_evidence_identity':{},'blocker':'Review not run','repair_budget':{},'review_state':{'status':'NOT_RUN_BY_THIS_SCOPE'},
               'direct_consumer':'DOT','one_NEXT':'DOT review gate','owner_decision_required':False,'updated_at':previous['updated_at'],
               'logical_slot_task_job_mapping':{'LaneRegistry_lane_id':None,'LongJobRunner_job_id':None},'source_status':previous['source_status'],
               'fixture_status':previous['fixture_status'],'integration_state':{'status':'PROPOSAL_ONLY_NOT_ADMITTED'},'native_runtime_status':'NOT_RUN_NOT_QUALIFIED',
               'queue_state':{'value':'DONE','scope':'LOCAL_F0_SYNCHRONOUS_FIXTURE_OBJECTIVE_ONLY','does_not_imply':'review accepted, integrated, deployed, native execution, active liveness or Phase0 PASS'}}
        checkpoint=root/'v2_checkpoint.json';checkpoint.write_text(json.dumps({**value,'schema':'dot_f0_current_linkage_checkpoint/2'}))
        index=root/'v2_index.json';index.write_text(json.dumps({**value,'schema':'dot_f0_passive_queue_linkage/2','current_checkpoint':{'path':str(checkpoint),'sha256':digest(checkpoint.read_bytes())},'previous_queue':{'path':str(old),'sha256':digest(old.read_bytes())}}))
        model.c['work_checkpoint']={'index':str(index),'index_sha256':digest(index.read_bytes()),'checkpoint':str(checkpoint),'checkpoint_sha256':digest(checkpoint.read_bytes())}
        return model,index,checkpoint

    def test_v2_local_done_separate_from_acceptance_and_liveness(self):
        with tempfile.TemporaryDirectory() as td:
            model,index,checkpoint=self.v2(td);rows=model.work_checkpoint();self.assertEqual(len(rows),1,model.errors);row=rows[0]
            self.assertEqual(row['bucket'],'RECENTLY DONE');self.assertEqual(row['state'],'DONE');self.assertIn('LOCAL_F0',row['raw_state'])
            self.assertEqual(row['acceptance'],'UNKNOWN');self.assertFalse(row['actual_live']);self.assertEqual(row['historical_os_identity'],'UNKNOWN_NOT_INDEPENDENTLY_CAPTURED')
            self.assertEqual(row['registry_binding'],'UNKNOWN_NOT_ESTABLISHED');self.assertEqual(row['passive_review_state'],'NOT_RUN_BY_THIS_SCOPE')

    def test_v2_wrong_scope_lane_process_review_or_previous_input_refused(self):
        for key,value in [('lane_id','invented-lane'),('queue_state',{'value':'DONE','scope':'ALL_READY'}),('review_state',{'status':'PASS'}),('process_identity_when_proven',{'historical_OS_identity':'PROVEN'}),('logical_slot_task_job_mapping',{'LaneRegistry_lane_id':'invented','LongJobRunner_job_id':None})]:
            with tempfile.TemporaryDirectory() as td:
                model,index,checkpoint=self.v2(td)
                for path in (index,checkpoint):
                    obj=json.loads(path.read_bytes());obj[key]=value;path.write_text(json.dumps(obj))
                obj=json.loads(index.read_bytes());obj['current_checkpoint']['sha256']=digest(checkpoint.read_bytes());index.write_text(json.dumps(obj))
                config=model.c['work_checkpoint'];config['index_sha256']=digest(index.read_bytes());config['checkpoint_sha256']=digest(checkpoint.read_bytes())
                self.assertEqual(model.work_checkpoint(),[],key)
        with tempfile.TemporaryDirectory() as td:
            model,index,checkpoint=self.v2(td);(pathlib.Path(td)/'index.json').write_bytes(b'{}');self.assertEqual(model.work_checkpoint(),[])

if __name__=="__main__":
    if '--browser-fixtures' in sys.argv: print(json.dumps(browser_fixtures(),ensure_ascii=True))
    else: unittest.main()
