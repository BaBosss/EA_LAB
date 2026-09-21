import json, os, pathlib, sys, tempfile, unittest
from types import SimpleNamespace
from unittest import mock
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parent))
from model import Model, Refused, _DashboardParser, clean, safe_bytes, digest, number, age_state, utcnow
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
            (leases/(lane+'.json')).write_text(json.dumps({'job_id':'job-one'}),encoding='utf-8')
            job=jobs/'job-one'; job.mkdir()
            (job/'state.json').write_text(json.dumps({'state':'RUNNING','runner_pid':os.getpid(),'child_pid':os.getpid()}),encoding='utf-8')
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
if __name__=="__main__": unittest.main()
