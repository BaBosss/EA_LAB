import unittest

from broker import Broker, tool_definitions
from preflight import canonical, strict_json
from test_gate_contract import Fixture, call


class BrokerTests(unittest.TestCase):
    def setUp(self):
        self.fixture = Fixture()
        self.broker = Broker(self.fixture.snapshot(), self.fixture.contract['bounds'])

    def invoke(self, name, **args):
        return strict_json(self.broker.dispatch(canonical(call(name, **args))))

    def test_exact_six_tools(self):
        self.assertEqual({t['name'] for t in tool_definitions()}, {'get_manifest','get_head','read_source','read_evidence','read_git_object','get_hash'})
        self.assertTrue(self.invoke('get_manifest')['ok'])
        self.assertTrue(self.invoke('get_head')['ok'])
        self.assertTrue(self.invoke('get_hash', entry_id='e_01')['ok'])

    def test_unknown_tool_matrix_reaches_dispatcher(self):
        for name in ('open','listdir','url','shell','python','eval','exec','plugin','process','registry',
                     'mt5','runtime','computer_use','browser','write_source','write_evidence','__getattribute__'):
            with self.subTest(name=name):
                self.assertFalse(self.invoke(name)['ok'])

    def test_unknown_id_and_argument_matrix(self):
        for entry in ('missing','../a.py','D:/EA_LAB/a.py','https://example.invalid','e_01'):
            with self.subTest(entry=entry):
                self.assertFalse(self.invoke('read_source',source_id=entry,offset=0,length=1)['ok'])
        self.assertFalse(self.invoke('get_head', path='private')['ok'])
        self.assertFalse(self.invoke('get_hash', entry_id='missing')['ok'])

    def test_bounds_matrix(self):
        for offset, length in ((-1,1),(0,0),(0,-1),(0,65537),(999,1),(0,True),(False,1),(0,'1'),(0,10**100)):
            with self.subTest(offset=offset,length=length):
                self.assertFalse(self.invoke('read_source',source_id='s_01',offset=offset,length=length)['ok'])

    def test_coverage_union_requires_all_bytes(self):
        size = self.fixture.contract['evidence_entries'][0]['size']
        for _ in range(2): self.invoke('read_evidence',evidence_id='e_01',offset=0,length=1)
        self.assertFalse(self.broker.covers(['e_01']))
        self.invoke('read_evidence',evidence_id='e_01',offset=2,length=size-2)
        self.assertFalse(self.broker.covers(['e_01']))
        self.invoke('read_evidence',evidence_id='e_01',offset=1,length=1)
        self.assertTrue(self.broker.covers(['e_01']))

    def test_aggregate_caps(self):
        fixture = self.fixture
        broker = Broker(fixture.snapshot(), dict(fixture.contract['bounds'], max_response_bytes=1))
        self.assertFalse(strict_json(broker.dispatch(canonical(call('read_evidence',evidence_id='e_01',offset=0,length=1))))['ok'])
        self.assertEqual(broker.successful_evidence_reads, 0)
        self.assertFalse(broker.covers(['e_01']))
        broker = Broker(fixture.snapshot(), dict(fixture.contract['bounds'], max_tool_calls=1))
        broker.dispatch(canonical(call('get_head')))
        self.assertFalse(strict_json(broker.dispatch(canonical(call('get_head'))))['ok'])

    def test_malformed_envelope(self):
        for raw in (b'null',b'[]',b'{}',b'{"name":"get_head","name":"shell","arguments":{}}'):
            self.assertFalse(strict_json(self.broker.dispatch(raw))['ok'])
