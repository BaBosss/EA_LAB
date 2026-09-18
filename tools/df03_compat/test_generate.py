"""Author deterministic checks, not independent QA or runtime parity evidence."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate as g


class CompatibilityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.parent = g.PARENT.read_bytes()
        cls.generated, cls.manifest = g.build(cls.parent)
        cls.records = cls.manifest['changes']

    def test_determinism_and_checked_in_dependency(self):
        generated, manifest = g.build(self.parent)
        self.assertEqual((generated, manifest), (self.generated, self.manifest))
        self.assertEqual((g.DEST / 'DF03_Generated.mqh').read_bytes(), generated)
        self.assertEqual(json.loads((g.DEST / 'manifest.json').read_bytes()), manifest)

    def test_wrong_hash_refuses_before_output(self):
        with tempfile.TemporaryDirectory(prefix='df03-negative-') as td:
            parent = Path(td) / 'wrong.mq5'
            parent.write_bytes(self.parent + b' ')
            out = Path(td) / 'must-not-exist'
            proc = subprocess.run([sys.executable, '-B', str(Path(g.__file__)),
                                   '--parent', str(parent), '--out', str(out)], capture_output=True)
            self.assertNotEqual(proc.returncode, 0)
            self.assertFalse(out.exists())
            out.mkdir()
            sentinel = out / 'DF03_Generated.mqh'
            sentinel.write_bytes(b'preserve previous output')
            proc = subprocess.run([sys.executable, '-B', str(Path(g.__file__)),
                                   '--parent', str(parent), '--out', str(out)], capture_output=True)
            self.assertNotEqual(proc.returncode, 0)
            self.assertEqual(sentinel.read_bytes(), b'preserve previous output')
            self.assertEqual(len(list(out.iterdir())), 1)

    def test_comments_strings_and_builtin_lexing(self):
        source = (b'// Bars OnTick\r\n/* Digits Point */\n'
                  b'string x="Bars \\" OnTrade"; string y="Point";\n'
                  b'int Bars=::Bars /*gap*/ (_Symbol,PERIOD_CURRENT);\n'
                  b'::Bars=Bars("x",0); int Digits=_Digits; double Point=_Point;\n'
                  b'void OnTick(){ OnTrade(); }')
        expected = (b'// Bars OnTick\r\n/* Digits Point */\n'
                    b'string x="Bars \\" OnTrade"; string y="Point";\n'
                    b'int DF03_CompatBars=::Bars /*gap*/ (_Symbol,PERIOD_CURRENT);\n'
                    b'::DF03_CompatBars=Bars("x",0); int DF03_CompatDigits=_Digits; double DF03_CompatPoint=_Point;\n'
                    b'void DF03_SourceOnTick(){ DF03_SourceOnTrade(); }')
        transformed, records = g.transform(source)
        self.assertEqual(transformed, expected)
        self.assertEqual(g.inverse(transformed, records), source)

    def test_inverse_exact_parent_bytes(self):
        self.assertEqual(len(self.parent), 535962)
        self.assertEqual(g.inverse(self.generated, self.records), self.parent)
        self.assertEqual(g.sha(self.parent), g.PARENT_SHA256)

    def test_map_tampering_fails(self):
        for field, value in [('parent_offset', 0), ('generated_offset', 0),
                             ('old', 'Unknown'), ('new', 'Other')]:
            records = copy.deepcopy(self.records)
            records[0][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                g.verify(self.parent, self.generated, records)

    def test_builtin_calls_exact(self):
        def calls(data):
            ts = g.tokens(data)
            return [ts[i:i+8] for i, t in enumerate(ts[:-1])
                    if t[0] == b'Bars' and ts[i+1][0] == b'(']
        before, after = calls(self.parent), calls(self.generated)
        self.assertEqual(len(before), 2)
        self.assertEqual([[t[0] for t in c] for c in before], [[t[0] for t in c] for c in after])

    def test_inputs_all_defaults_exact(self):
        expected = [('double', 'Lot1', '0.05'), ('double', 'Lot2', '0.1'),
                    ('double', 'Lot3', '0.15'), ('double', 'Lot4', '0.2'),
                    ('double', 'Lot5', '0.3'), ('double', 'Pull_Back', '20.0'),
                    ('double', 'Nearby_PIP', '20.0'), ('double', 'Close_All_Percent', '2.0'),
                    ('ENUM_TIMEFRAMES', 'Timeframe', 'PERIOD_D1'),
                    ('double', 'Hedging_mode_1_on_0_off', '1.0'),
                    ('double', 'TP_pip', '40.0'), ('double', 'SL_pip', '20.0'),
                    ('int', 'MagicStart', '4023'), ('string', 'inp430_Lo_ModeCandleFindBy', '"id"')]
        self.assertEqual(self.manifest['causal']['inputs'],
                         [f'input {t} {n} = {v} ;' for t, n, v in expected])

    def test_graph_exact_order_and_event_roots(self):
        graph = self.manifest['causal']
        self.assertEqual([b['id'] for b in graph['blocks']], list(range(126)))
        # Outbound declaration order is NOT callback execution order in Block8.
        self.assertEqual(graph['blocks'][8]['outbound_array'], [0,1,10,2,3,4,5,6,7,9])
        self.assertEqual([e['target'] for e in graph['blocks'][8]['ordered_callback_edges']],
                         [0,1,2,3,4,5,6,7,9,10])
        self.assertEqual(graph['event_roots']['OnInit'], [8])
        self.assertEqual(len(graph['event_roots']['__OnTick__']), 15)
        self.assertEqual(graph['event_roots']['OnTrade'], [11,12])
        self.assertEqual(graph, g.causal_manifest(g.inverse(self.generated, self.records)))

    def test_hedge_native_semantics(self):
        graph = self.manifest['causal']
        self.assertEqual(graph['hedge_gate_blocks'], list(range(116,126)))
        self.assertEqual(graph['swapped_stop_assignments'], 10)
        self.assertEqual(graph['swapped_target_assignments'], 10)
        self.assertGreater(graph['period_d1_tokens'], 0)
        self.assertGreater(graph['current_timeframe_calls'], 0)
        self.assertEqual(graph['enum_to_candle_find_assignments'], 1)

    def test_lifecycle_and_repaired_parent(self):
        repaired, records = g.transform(self.parent, lifecycle=False)
        self.assertEqual(g.verify(self.parent, repaired, records, lifecycle=False), self.manifest['causal'])
        self.assertEqual(len(records), 15)
        graph = self.manifest['causal']['lifecycle']
        self.assertEqual(graph['OnInit']['signature'], 'void OnInit ( )')
        self.assertEqual(graph['OnTick']['ordered_native_calls'], ['__OnTick__'])
        self.assertEqual(graph['__OnTick__']['ordered_native_calls'], ['OnTrade'])
        self.assertEqual(graph['OnTimer']['ordered_native_calls'], ['OnTick', 'OnTrade'])

    def test_probe_refuses_initialization_and_adapter_forwarding(self):
        probe = g.code((g.ROOT / 'ea_template/tests/GridFibo_AdapterCompile.mq5').read_bytes())
        self.assertIn('int OnInit ( ) { return INIT_FAILED ; }', probe)
        self.assertIn('void OnTick ( ) { }', probe)
        self.assertIn('void OnDeinit ( const int reason ) { }', probe)
        self.assertEqual(probe.count('DF03_CompileCheckOnly ('), 1)
        adapter = g.code((g.ROOT / 'ea_template/core/entries/Entry_GridFibo.mqh').read_bytes())
        for name in ('Init', 'Tick', 'Trade', 'Timer'):
            self.assertIn(f'void DF03_Adapter{name} ( ) {{ DF03_SourceOn{name} ( ) ; }}', adapter)
        self.assertIn('DF03_SourceOnChartEvent ( id , lparam , dparam , sparam ) ;', adapter)
        self.assertIn('DF03_SourceOnDeinit ( reason ) ;', adapter)
        self.assertIn('# ifndef EA_LAB_ENTRY_GRIDFIBO_MQH', adapter)


# Every mutant passes through the SAME authoritative check used by generation.
# Each anchor must match the real emitted dependency; no skipped/imaginary mutant.
MUTANTS = {
    'input_default': (b'input double Lot1 = 0.05;', b'input double Lot1 = 0.06;'),
    'block_id': (b'__block_number = 0;', b'__block_number = 1;'),
    'block_type': (b'class Block8: public MDL_Pass', b'class Block8: public MDL_Condition'),
    'callback_edge': (b'_blocks_[0].run(8);', b'_blocks_[1].run(8);'),
    'callback_order': (b'_blocks_[0].run(8);\r\n\t\t\t_blocks_[1].run(8);',
                       b'_blocks_[1].run(8);\r\n\t\t\t_blocks_[0].run(8);'),
    'outbound_array': (b'{0,1,10,2,3,4,5,6,7,9}', b'{1,0,10,2,3,4,5,6,7,9}'),
    'tick_root': (b'{14,16,24,26,34,36,44,46,71,76,83,84,88,90,92}', b'{14,16}'),
    'trade_root': (b'blocks_to_run[] = {11,12}', b'blocks_to_run[] = {12,11}'),
    'init_root': (b'blocks_to_run[] = {8}', b'blocks_to_run[] = {9}'),
    'hedge_gate': (b'Lo.Value = c::Hedging_mode_1_on_0_off;', b'Lo.Value = 1.0;'),
    'hedge_operand': (b'Value = (double)1.0;', b'Value = (double)0.0;'),
    'd1': (b'input ENUM_TIMEFRAMES Timeframe = PERIOD_D1;', b'input ENUM_TIMEFRAMES Timeframe = PERIOD_H1;'),
    'current_tf': (b'ObjPrice1.Period = CurrentTimeframe();', b'ObjPrice1.Period = PERIOD_D1;'),
    'swapped_sl': (b'StopLossPips = (double)c::TP_pip;', b'StopLossPips = (double)c::SL_pip;'),
    'swapped_tp': (b'TakeProfitPips = (double)c::SL_pip;', b'TakeProfitPips = (double)c::TP_pip;'),
    'enum_string': (b'ObjPrice1.ModeCandleFindBy = c::Timeframe;', b'ObjPrice1.ModeCandleFindBy = "id";'),
    'builtin': (b'::Bars(::_Symbol, PERIOD_CURRENT)', b'::DF03_CompatBars(::_Symbol, PERIOD_CURRENT)'),
    'renamed_token': (b'DF03_CompatBars', b'DF03_CompatBarz'),
    'lifecycle_call': (b'if (ENABLE_EVENT_TRADE) {DF03_SourceOnTrade();}', b'if (ENABLE_EVENT_TRADE) {}'),
    'comment': (b'// Point Format Rules', b'// Point format rules'),
    'string': (b'"OnInit() handler has returned a nonzero value"', b'"changed message"'),
    'newline': (b'\r\n', b'\n'),
}


def mutant_test(old, new):
    def test(self):
        self.assertTrue(old in self.generated, f'missing real-source mutant anchor: {old!r}')
        mutant = self.generated.replace(old, new, 1)
        with self.assertRaises(ValueError):
            g.verify(self.parent, mutant, self.records)
    return test


for name, (old, new) in MUTANTS.items():
    setattr(CompatibilityTests, 'test_reject_mutant_' + name, mutant_test(old, new))


if __name__ == '__main__':
    unittest.main(verbosity=2)
