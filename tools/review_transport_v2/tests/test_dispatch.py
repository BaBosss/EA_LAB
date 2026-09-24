from unittest import mock
import unittest

from model_client import FakeModelClient, ModelClient
from preflight import Refusal, canonical
from test_gate_contract import Fixture, call, envelope


class DispatchTests(unittest.TestCase):
    def test_rtv2_003_citations_require_full_content_reads(self):
        for mode in ('unread', 'metadata', 'partial', 'denied'):
            with self.subTest(mode=mode):
                fixture = Fixture()
                fixture.contract['required_coverage'] = ['e_01']
                fixture.freeze()
                calls = [call('read_evidence', evidence_id='e_01', offset=0,
                              length=fixture.contract['evidence_entries'][0]['size'])]
                if mode == 'metadata': calls += [call('get_hash', entry_id='s_01')]
                if mode == 'partial': calls += [call('read_source', source_id='s_01', offset=0, length=1)]
                if mode == 'denied': calls += [call('read_evidence', evidence_id='s_01', offset=0, length=1)]
                result = fixture.result(); result['citations'].append('s_01')
                receipt = fixture.launch(FakeModelClient([envelope(calls),
                    envelope(result=result, request_id='fake-2')]))
                self.assertIsNone(receipt['substantive_verdict'])
                self.assertIn('Refusal: RESULT_CITATION_COVERAGE', receipt['limitations'])

    def test_rtv2_003_fully_read_optional_citation_allowed(self):
        fixture = Fixture()
        fixture.contract['required_coverage'] = ['e_01']; fixture.freeze()
        from preflight import strict_json
        responses = [strict_json(raw) for raw in fixture.client().responses]
        responses[-1]['result']['citations'].append('s_01')
        receipt = fixture.launch(FakeModelClient(responses))
        self.assertEqual(receipt['disposition'], 'DETERMINISTIC_TEST_ONLY', receipt['limitations'])

    def test_no_real_adapter_no_implicit_credentials(self):
        fixture = Fixture()
        receipt = fixture.launch(ModelClient())
        self.assertEqual(receipt['model_dispatch_count'], 0)
        self.assertIsNone(receipt['substantive_verdict'])
        self.assertIn('Refusal: QUALIFIED_API_ADAPTER_UNAVAILABLE', receipt['limitations'])

    def test_explicit_endpoint_required(self):
        fixture = Fixture(); client = fixture.client()
        fixture.contract['endpoint_identity'] = 'https://unapproved.invalid'; fixture.freeze()
        self.assertEqual(fixture.launch(client)['model_dispatch_count'], 0)

    def test_model_response_failure_matrix(self):
        for mode in ('model','result-head','result-bundle','unknown-field','invalid-json','unknown-citation','no-citation'):
            with self.subTest(mode=mode):
                fixture = Fixture(); client = fixture.client()
                from preflight import strict_json
                responses = [strict_json(x) for x in client.responses]
                if mode == 'model': responses[0]['model'] = 'wrong'
                elif mode == 'result-head': responses[1]['result']['reviewed_head'] = '0'*40
                elif mode == 'result-bundle': responses[1]['result']['bundle_manifest_sha256'] = '0'*64
                elif mode == 'unknown-field': responses[1]['result']['extra'] = 'bad'
                elif mode == 'unknown-citation': responses[1]['result']['citations'] = ['outside']
                elif mode == 'no-citation': responses[1]['result']['citations'] = []
                else: responses[0] = b'{'
                receipt = fixture.launch(FakeModelClient(responses))
                self.assertGreater(receipt['model_dispatch_count'], 0)
                self.assertIsNone(receipt['substantive_verdict'])
                self.assertEqual(receipt['disposition'], 'ENVIRONMENT')

    def test_manifest_and_hash_only_do_not_count_as_evidence(self):
        fixture = Fixture()
        client = FakeModelClient([envelope([call('get_manifest'),call('get_hash',entry_id='e_01')]),
                                  envelope(result=fixture.result(),request_id='fake-2')])
        receipt = fixture.launch(client)
        self.assertEqual(receipt['successful_evidence_reads'], 0)
        self.assertIsNone(receipt['substantive_verdict'])

    def test_partial_read_blocks_verdict(self):
        fixture = Fixture()
        client = FakeModelClient([envelope([call('read_evidence',evidence_id='e_01',offset=0,length=1)]),
                                  envelope(result=fixture.result(),request_id='fake-2')])
        receipt = fixture.launch(client)
        self.assertEqual(receipt['successful_evidence_reads'], 1)
        self.assertIsNone(receipt['substantive_verdict'])

    def test_zero_evidence_package_blocks_verdict(self):
        fixture = Fixture()
        # New empty evidence directory avoids deleting earlier fixture artifacts.
        empty = fixture.root/'empty-evidence'; empty.mkdir()
        from preflight import identity
        fixture.contract.update(evidence_root=str(empty),evidence_root_identity=identity(empty),evidence_entries=[])
        fixture.contract['required_coverage'].remove('e_01'); fixture.freeze()
        receipt = fixture.launch()
        self.assertIsNone(receipt['substantive_verdict'])

    def test_postconditions_run_on_provider_failure(self):
        fixture = Fixture(); client = fixture.client()
        with mock.patch.object(FakeModelClient, 'exchange', side_effect=RuntimeError('provider down')):
            receipt = fixture.launch(client)
        self.assertEqual(receipt['model_dispatch_count'], 1)
        self.assertEqual(receipt['observed_head_post'], fixture.contract['requested_head'])
        self.assertIn('source',receipt['unchanged_checks'])
        self.assertIsNone(receipt['substantive_verdict'])

    def test_model_receives_bytes_not_broker_or_host_capabilities(self):
        fixture = Fixture(); client = fixture.client(); receipt = fixture.launch(client)
        self.assertEqual(receipt['disposition'],'DETERMINISTIC_TEST_ONLY',receipt['limitations'])
        self.assertTrue(all(type(x) is bytes for x in client.requests))
        first = client.requests[0]
        self.assertNotIn(str(fixture.repo).encode(), first)
        self.assertNotIn(str(fixture.control).encode(), first)

    def test_round_budget_and_call_budget(self):
        for mode in ('round','calls'):
            fixture = Fixture()
            if mode == 'round':
                fixture.contract['bounds']['max_model_rounds']=1
                responses=[envelope([call('get_head')])]
            else:
                fixture.contract['bounds']['max_tool_calls']=1
                responses=[envelope([call('get_head')]),envelope([call('get_head')],request_id='fake-2')]
            fixture.freeze(); receipt=fixture.launch(FakeModelClient(responses))
            self.assertIsNone(receipt['substantive_verdict'])

    def test_failed_postcondition_revokes_completed_result(self):
        fixture = Fixture(); client = fixture.client(); snapshot = fixture.snapshot()
        with mock.patch('launch.export', side_effect=[snapshot, snapshot, Refusal('POST_TEST_MUTATION')]):
            receipt = fixture.launch(client)
        self.assertEqual(receipt['model_dispatch_count'], 2)
        self.assertIsNone(receipt['substantive_verdict'])
        self.assertIsNone(receipt['protected_state_after'])
        self.assertIn('POSTCONDITION: POST_TEST_MUTATION', receipt['limitations'])
