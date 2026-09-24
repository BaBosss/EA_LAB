"""B21 deterministic source/contract fixtures. No MQL runtime or trading.

Range/config truth tables evaluate extracted pure predicates; lifecycle and
kill coverage are source call-chain checks, not broker execution evidence.
"""
import copy
import csv
import io
import json
from pathlib import Path
import re
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate as g
import template_engine as te


def read(rel):
    return (g.ROOT / rel).read_bytes()


def active(data, b21=True):
    """Only conditional selection; includes are validated separately."""
    defined = {'LAB_ENTRY_21'} if b21 else {'LAB_ENTRY_11'}
    stack, enabled, out = [], True, []
    for line in data.decode('utf-8-sig').splitlines():
        parts = line.strip().split()
        if not parts:
            continue
        op = parts[0]
        if op in ('#ifdef', '#ifndef'):
            condition = parts[1] in defined
            if op == '#ifndef':
                condition = not condition
            stack.append((enabled, condition))
            enabled = enabled and condition
        elif op == '#else':
            parent, condition = stack[-1]
            enabled = parent and not condition
        elif op == '#endif':
            enabled = stack.pop()[0]
        elif op == '#define' and enabled:
            defined.add(parts[1])
        elif enabled:
            out.append(line)
    g.require(not stack, 'unbalanced test preprocessing')
    return '\n'.join(out).encode()


def body(data, name):
    a, b = te.function_span(data, name)
    return g.code(data[a:b])


def norm(text):
    return g.code(text.encode())


def require_snippet(text, snippet):
    g.require(norm(snippet) in text, 'missing safety clause: ' + snippet)


def pre_tick_contract(entry):
    guard = body(active(entry), 'DF03_B21PreTick')
    require_snippet(guard, 'RuntimeIdentity_Update();')
    require_snippet(guard, 'if(RiskControl_CheckDD()) return false;')
    require_snippet(guard, 'if(RiskControl_IsHalted()) return false;')
    require_snippet(guard, 'return true;')


def timer_tick_contract(engine):
    timer = body(engine, 'DF03_SourceOnTimer')
    seam = norm('if(DF03_B21PreTick()) DF03_SourceOnTick();')
    g.require(timer.count(seam) == 1, 'nested timer tick guard drift')
    g.require(timer.count('DF03_SourceOnTick (') == 1,
              'nested native tick delegate count')
    # A refused simulated tick skips only that native tick. Source-owned trade
    # dispatch and the remaining timer cadence/cleanup body must still follow.
    tail = norm('''
        if(ON_TRADE_REALTIME == 1) { DF03_SourceOnTrade(); }
        static datetime t0 = 0;
        datetime t = 0;
        bool ok = false;
        if(FXD_ONTIMER_TAKEN)
    ''')
    g.require(timer.index(seam) < timer.index(tail),
              'native timer trade/cleanup tail drift')


def safety_contract(execution, entry, core, risk):
    ex, en, co = active(execution), active(entry), active(core)
    ownership = body(ex, 'Exec_IdentityIsMine')
    require_snippet(ownership, 'if(symbol != _Symbol) return false;')
    require_snippet(ownership, 'return magic > (long)_21_DF03_MagicStart && magic <= (long)_21_DF03_MagicStart + 5;')
    for name, clause in (
        ('Exec_PosIsMine', 'return Exec_IdentityIsMine(PositionGetString(POSITION_SYMBOL), (long)PositionGetInteger(POSITION_MAGIC));'),
        ('Exec_OrdIsMine', 'return Exec_IdentityIsMine(OrderGetString(ORDER_SYMBOL), (long)OrderGetInteger(ORDER_MAGIC));'),
        ('Exec_CountAll', 'return Exec_CountDir(0);'),
        ('Exec_CountDir', 'if(!Exec_PosIsMine(i)) continue;'),
        ('Exec_CountDir', 'if(direction == 0) n++;'),
        ('Exec_CountPending', 'if(Exec_OrdIsMine(i)) n++;'),
        ('Exec_CloseAll', 'if(!Exec_PosIsMine(i)) continue;'),
        ('Exec_CloseAll', 'g_trade.PositionClose(tk)'),
        ('Exec_CloseAll', 'Exec_CancelAllPending();'),
        ('Exec_CloseAll', 'return (Exec_CountAll() == 0 && Exec_CountPending() == 0);'),
        ('Exec_CancelAllPending', 'if(!Exec_OrdIsMine(i)) continue;'),
        ('Exec_CancelAllPending', 'g_trade.OrderDelete(tk)'),
    ):
        require_snippet(body(ex, name), clause)
    require_snippet(body(risk, 'RiskControl_KillReconcile'), 'if(Exec_CloseAll())')
    require_snippet(body(risk, 'RiskControl_CheckDD'), 'RiskControl_KillReconcile();')
    require_snippet(body(en, 'DF03_B21ConfigValid'),
                    'if(DryRun || _0_Magic != (long)_21_DF03_MagicStart || _MG_SelfGate)')
    hook = body(en, 'DF03_B21NewOrder')
    for clause in (
        'if(!g_df03_ready || !Exec_IdentityIsMine(symbol, magic)) return false;',
        'if(type != 0 && type != 1) return false;',
        'if(Exec_NewsBlocked() || Exec_MacroBlocked() || !Exec_SpreadOK()) return false;',
        'if(!RiskControl_AllowNewOrder()) return false;',
        'if(Exec_CountAll() == 0 && Exec_CountPending() == 0 && !RiskControl_AcctGateOK()) return false;',
        'if(!MathIsValidNumber(lot) || lot <= 0.0) return false;',
        'if(!MathIsValidNumber(minv) || !MathIsValidNumber(maxv) || !MathIsValidNumber(step) || minv <= 0.0 || maxv < minv || step <= 0.0) return false;',
        'lot = Exec_NormalizeLot(RiskControl_ClampLot(lot * Exec_MacroLotMult()));',
        'return Basket_HeatCheckPass(symbol, lot);',
    ):
        require_snippet(hook, clause)
    pre_tick_contract(entry)
    init, tick, deinit = (body(co, n) for n in ('OnInit', 'OnTick', 'OnDeinit'))
    require_snippet(init, 'if(!DF03_B21ConfigValid()) return INIT_FAILED;')
    require_snippet(init, 'if(!RiskControl_Init()) return INIT_FAILED;')
    require_snippet(tick, 'RuntimeIdentity_Update(); if(!g_df03_ready) return; if(RiskControl_CheckDD()) return; if(RiskControl_IsHalted()) return; DF03_AdapterTick(); return;')
    g.require(tick.count('DF03_AdapterTick (') == 1,
              'terminal native tick delegate count')
    for text, call in ((init, 'DF03_AdapterInit'), (tick, 'DF03_AdapterTick'), (deinit, 'DF03_AdapterDeinit')):
        g.require(text.count(call + ' (') == 1, 'native lifecycle delegate count')
    for text in (init, tick, deinit):
        g.require(not re.search(r'\b(?:Stack_\w+|Recovery_\w+|Hedge_\w+|Exit_\w+|ExitManager_\w+|Indi_\w+|Regime_\w+|Entry_\w+|MG_\w+|Basket_\w+|Lab_PrintEffectiveConfig|Lab_OpenOrder|IsNewBar) \(', text),
                  'shared engine or bar gate active in B21 lifecycle')
    g.require('HIDDEN_INACTIVE' in init, 'inactive controls not disclosed')


class B21Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.parent = g.PARENT.read_bytes()
        cls.raw = read('ea_template/compat/df03/DF03_Generated.mqh')
        cls.engine, cls.manifest = te.build(cls.parent)
        cls.execution = read('ea_template/core/Execution.mqh')
        cls.entry = read('ea_template/core/entries/Entry_GridFibo.mqh')
        cls.core = read('ea_template/core/LabCore.mqh')
        cls.risk = read('ea_template/core/RiskControl.mqh')

    def test_pinned_bytes_and_reconstruction(self):
        self.assertEqual(g.sha(self.parent), g.PARENT_SHA256)
        self.assertEqual(g.sha(self.raw), '564099a9e48abffcfbeceb43b3558f9212ece603309eaf15e6947834aa957115')
        self.assertEqual(te.restore(self.engine, self.manifest), self.parent)

    def test_deterministic_outputs(self):
        self.assertEqual(read('ea_template/compat/df03/DF03_TemplateEngine.mqh'), self.engine)
        self.assertEqual(json.loads(read('ea_template/compat/df03/template_manifest.json')), self.manifest)

    def test_warning_compat_exact_24_and_accepted_engine_preserved(self):
        sites = self.manifest.get('warning_conversions', [])
        self.assertEqual(len(sites), 24)
        self.assertEqual([s['line'] for s in sites],
                         [1838,1873,1908,1943,1978,2013,2048,2083,2488,2523,
                          4570,7031,7032,7033,7034,7035,7070,7071,7072,7073,
                          7074,11083,11627,13756])
        restored = self.engine
        for s in reversed(sites):
            self.assertEqual(s['new'], '(' + s['cast'] + ')(' + s['old'] + ')')
            at = s['engine_offset']
            new = s['new'].encode()
            self.assertEqual(restored[at:at+len(new)], new)
            restored = restored[:at] + s['old'].encode() + restored[at+len(new):]
        self.assertEqual(g.sha(restored),
                         '9d8c00497b822022ec8e0af0a5e9d2ae5e3f64603c87f19ab4cd1a32b12a17af')

    def test_conversion_fixture_is_source_bound_and_no_trade(self):
        fixture = read('ea_template/tests/DF03_ConversionCompat_Test.mq5')
        self.assertIn(te.fixture_region(self.raw), fixture)
        self.assertNotRegex(g.code(fixture),
                            r'\b(?:OrderSend|OrderSendAsync|CTrade|OrderSelect|PositionSelect|Sleep)\b')
        self.assertNotIn(b'#include', fixture)
        self.assertIn(b'DF03_IMPLICIT_ORACLE', fixture)

    def test_conversion_fixture_static_members_defined_once_in_both_arms(self):
        members = ('B1', 'B2', 'B3', 'B4', 'B5', 'S1', 'S2', 'S3', 'S4', 'S5')
        for member in members:
            self.assertIn(('static int ' + member + ';').encode(), self.raw)
        self.assertIn(b'static ENUM_TIMEFRAMES Timeframe;', self.raw)
        expected = [('int', 'v::' + member, '0') for member in members]
        expected.append(('ENUM_TIMEFRAMES', 'c::Timeframe', 'PERIOD_CURRENT'))

        def assert_definitions(data):
            definitions = re.findall(
                r'(?m)^\s*(int|long|double|ENUM_TIMEFRAMES)\s+'
                r'((?:v|c)::\w+)\s*(?:=\s*([^;]+))?;',
                data.decode())
            self.assertCountEqual(definitions, expected)

        generated = te.fixture_bytes(self.raw)
        self.assertEqual(read('ea_template/tests/DF03_ConversionCompat_Test.mq5'), generated)
        for prefix in (b'', b'#define DF03_IMPLICIT_ORACLE\n'):
            with self.subTest(arm='implicit' if prefix else 'explicit'):
                selected = active(prefix + generated)
                assert_definitions(selected)
                # Missing, duplicate and widened definitions must each fail.
                for typename, member, value in expected:
                    definition = f'{typename} {member} = {value};'.encode()
                    for bad in (selected.replace(definition, b'', 1),
                                selected + b'\n' + definition,
                                selected.replace(definition, definition.replace(
                                    typename.encode(), b'long', 1), 1)):
                        with self.assertRaises(AssertionError):
                            assert_definitions(bad)

    def test_conversion_missing_duplicate_context_drift_refused(self):
        for site in te.warning_sites(self.raw):
            start = site['raw_offset']
            for changed in (self.raw[:start] + self.raw[start+len(site['old']):],
                            self.raw + (site['lhs']+' = '+site['old']+';').encode(),
                            self.raw.replace(b'static int B1;', b'static long B1;', 1)):
                with self.subTest(line=site['line']), self.assertRaises(ValueError):
                    te.warning_sites(changed)

    def test_conversion_manifest_tamper_refused(self):
        for key in ('old', 'new', 'raw_offset', 'engine_offset', 'cast', 'line'):
            changed = copy.deepcopy(self.manifest)
            changed['warning_conversions'][0][key] = 'tampered'
            with self.subTest(key=key), self.assertRaises(ValueError):
                te.verify(self.parent, self.engine, changed)

    def test_differential_log_refuses_missing_duplicate_or_boundary_difference(self):
        keys = te.fixture_keys()
        rows = ['DF03_ROW|' + key + '|0' for key in sorted(keys)]
        def log(arm, data):
            return '\n'.join(['DF03_ARM|' + arm, 'DF03_RUNTIME|6090'] + data +
                             ['DF03_DONE|' + str(len(data))])
        oracle = log('IMPLICIT_TEST_CONTROL', rows)
        explicit = log('EXPLICIT', rows)
        self.assertEqual(te.compare_fixture_logs(oracle, explicit)['rows'], len(keys))
        self.assertEqual(te.compare_fixture_logs('tester DF03_ConversionCompat_Test started\n' + oracle,
                                                explicit)['rows'], len(keys))
        for bad in (log('EXPLICIT', rows[:-1]), log('EXPLICIT', rows + rows[:1]),
                    explicit.replace(rows[0], rows[0] + 'DIFFERENCE'),
                    explicit.replace('6090', '6182'), explicit + '\nDF03_DONE|1',
                    explicit.replace('EXPLICIT', 'IMPLICIT_TEST_CONTROL')):
            with self.assertRaises(ValueError):
                te.compare_fixture_logs(oracle, bad)

    def test_wrong_parent_refuses(self):
        with self.assertRaisesRegex(ValueError, 'SHA256'):
            te.build(self.parent + b' ')

    def test_engine_tamper_refuses(self):
        with self.assertRaises(ValueError):
            te.restore(self.engine.replace(b'df03_safe_lots', b'bad_safe_lots', 1), self.manifest)

    def test_mapping_manifest_tamper_refuses(self):
        manifest = copy.deepcopy(self.manifest)
        manifest['mappings'][0]['target'] = '_21_DF03_Lot2'
        with self.assertRaisesRegex(ValueError, 'dependency drift'):
            te.verify(self.parent, self.engine, manifest)

    def test_input_types_defaults_pids_and_no_raw_inputs(self):
        inputs = read('ea_template/core/Inputs.mqh').decode()
        registry = read('docs/PARAM_REGISTRY.csv').decode('utf-8-sig')
        rows = list(csv.DictReader(io.StringIO('\n'.join(line for line in registry.splitlines() if line and not line.startswith('>')))))
        self.assertEqual(len(self.manifest['mappings']), 14)
        self.assertEqual(len(re.findall(r'^input \w+ _21_DF03_', inputs, re.M)), 14)
        self.assertNotIn('input ', g.code(self.engine))
        for n, m in enumerate(self.manifest['mappings']):
            self.assertEqual(m['pid'], 12100+n)
            self.assertRegex(inputs, rf'input {m["type"]} {m["target"]} = {re.escape(m["default"])}; // \[P{m["pid"]}\]')
            self.assertEqual(sum(row['parameter_pid'] == str(m['pid']) for row in rows), 1)
            self.assertEqual(next(row['name'] for row in rows if row['parameter_pid'] == str(m['pid'])), m['target'])

    def test_magic_all_global_reads_mapped(self):
        tokens = g.tokens(self.engine)
        for i, token in enumerate(tokens):
            if token[0] == b'MagicStart':
                self.assertIn(tokens[i-1][0], (b'int', b'::'))
        self.assertEqual(g.code(self.engine).count('_21_DF03_MagicStart'), 5)

    def test_one_guard_immediately_before_native_send(self):
        text = body(self.engine, 'OrderCreate')
        self.assertEqual(g.code(self.engine).count('DF03_B21NewOrder ('), 1)
        require_snippet(text, 'double df03_safe_lots = lots; if(!DF03_B21NewOrder(symbol, magic, type, df03_safe_lots)) return -1; ticket = EEFD::OrderSend(symbol, type, df03_safe_lots,')
        self.assertEqual(text.count('double df03_safe_lots = lots ;'), 1)

    def test_nested_timer_tick_is_guarded_without_suppressing_timer_tail(self):
        pre_tick_contract(self.entry)
        timer_tick_contract(self.engine)

    def test_source_changes_limited_to_declared_integration_seams(self):
        # Reverse only integration patches: proves every unpatched native byte,
        # including MODIFY/CLOSE sends and graph/event bodies, is unchanged.
        data = self.engine
        for p in reversed(self.manifest['patches']):
            at, new = p['offset'], p['new'].encode()
            data = data[:at] + p['old'].encode() + data[at+len(new):]
        self.assertEqual(data, self.raw)
        self.assertEqual(len(self.manifest['patches']), 35 + 24)
        conversions = {(s['old'], s['new']) for s in self.manifest['warning_conversions']}
        for p in self.manifest['patches']:
            self.assertTrue(p['old'].startswith('input ') or p['new'].startswith('_21_DF03_') or
                            p['new'] == te.HOOK.decode() or
                            p['new'] == te.TIMER_TICK_HOOK.decode() or
                            (p['old'], p['new']) == ('lots', 'df03_safe_lots') or
                            (p['old'], p['new']) in conversions)

    def test_seam_accepts_lf_crlf_and_mixed_trivia(self):
        for raw in (self.raw.replace(b'\r\n', b'\n'),
                    self.raw.replace(b'\r\n', b'\n').replace(b'\n', b'\r\n'),
                    self.raw.replace(b'EEFD::OrderSend(', b'EEFD /*gap*/ :: OrderSend (')):
            with self.subTest(newlines=g.sha(raw)):
                self.assertEqual(len(te.send_patches(raw)), 2)

    def test_duplicate_seam_refuses(self):
        with self.assertRaisesRegex(ValueError, 'ambiguous'):
            te.send_patches(self.raw + b'\nvoid extra(){' + te.SEND + b'}')

    def test_missing_seam_refuses(self):
        with self.assertRaisesRegex(ValueError, 'missing'):
            te.send_patches(self.raw.replace(b'ticket = EEFD::OrderSend(', b'ticket = OtherSend('))

    def test_close_send_substitution_refuses(self):
        with self.assertRaises(ValueError):
            te.send_patches(self.raw.replace(b'EEFD::OrderSend(', b'EEFD::OrderClose('))

    def test_argument_drift_refuses(self):
        a, b = te.function_span(self.raw, 'OrderCreate')
        changed = self.raw[:a] + self.raw[a:b].replace(b'\n\t\t\tlots,', b'\n\t\t\tother_lots,') + self.raw[b:]
        with self.assertRaisesRegex(ValueError, 'argument drift'):
            te.send_patches(changed)

    def test_duplicate_ordercreate_refuses(self):
        with self.assertRaisesRegex(ValueError, 'ambiguous/missing function'):
            te.send_patches(self.raw + b'\nint OrderCreate(){return 0;}')

    def test_buy_sell_forwarding_drift_refuses(self):
        a, b = te.function_span(self.raw, 'SellNow')
        with self.assertRaisesRegex(ValueError, 'forwarding drift'):
            te.send_patches(self.raw[:a] + self.raw[a:b].replace(b'OP_SELL', b'OP_BUY') + self.raw[b:])

    def test_timer_tick_seam_missing_refuses(self):
        changed = self.raw.replace(b'DF03_SourceOnTick();', b'DF03_SourceOtherTick();', 1)
        with self.assertRaisesRegex(ValueError, 'timer tick seam'):
            te.timer_tick_patches(changed)

    def test_timer_tick_seam_duplicate_refuses(self):
        a, b = te.function_span(self.raw, 'DF03_SourceOnTimer')
        changed = self.raw[:b-1] + b'\nDF03_SourceOnTick();\n' + self.raw[b-1:]
        with self.assertRaisesRegex(ValueError, 'timer tick seam'):
            te.timer_tick_patches(changed)

    def test_timer_tick_seam_context_drift_refuses(self):
        changed = self.raw.replace(
            b'if (FXD_CHART_IS_OFFLINE && EEFD::RefreshRates()) {',
            b'if (FXD_CHART_IS_OFFLINE) {', 1)
        with self.assertRaisesRegex(ValueError, 'timer tick seam'):
            te.timer_tick_patches(changed)

    def test_safety_call_chain(self):
        safety_contract(self.execution, self.entry, self.core, self.risk)

    def test_ownership_range_truth_table_and_kill_selection(self):
        text = body(active(self.execution), 'Exec_IdentityIsMine')
        expr = re.search(r'return (magic .+?) ;', text)[1]
        expr = expr.replace('( long )', '').replace('& &', 'and')
        # Static chain validation binds BOTH close/delete iteration and final
        # flat reconciliation to this exact predicate, for every native group.
        safety_contract(self.execution, self.entry, self.core, self.risk)
        def owns(symbol, magic, base):
            return symbol == 'OWN' and eval(expr, {'__builtins__': {}},
                                            dict(magic=magic, _21_DF03_MagicStart=base))
        for base in (4023, 0, 2147483640):
            basket = [('OWN', base+n) for n in range(-1, 8)] + [('FOREIGN', base+1)]
            selected = [magic for symbol, magic in basket if owns(symbol, magic, base)]
            self.assertEqual(selected, list(range(base+1, base+6)))

    def test_init_refusal_truth_table(self):
        text = body(active(self.entry), 'DF03_B21ConfigValid')
        expr = re.search(r'if \( (.+?) \) \{', text)[1].replace('( long )', '').replace('| |', 'or')
        for dry, mismatch, selfgate in ((False,False,False), (True,False,False), (False,True,False), (False,False,True), (True,True,True)):
            result = eval(expr, {'__builtins__': {}}, dict(DryRun=dry, _0_Magic=4023+int(mismatch), _21_DF03_MagicStart=4023, _MG_SelfGate=selfgate))
            self.assertEqual(result, dry or mismatch or selfgate)

    def test_wrapper_forwards_events_once(self):
        wrapper = read('ea_template/Boss_21_GridFibo.mq5')
        for event, adapter, args in (('OnTrade','Trade',''), ('OnTimer','Timer',''), ('OnChartEvent','ChartEvent','id, lparam, dparam, sparam')):
            self.assertEqual(body(wrapper, event), norm('{ if(g_df03_ready) DF03_Adapter' + adapter + '('+args+'); }'))
        for adapter, source, args in (('Init','OnInit',''), ('Tick','OnTick',''), ('Trade','OnTrade',''), ('Timer','OnTimer',''), ('ChartEvent','OnChartEvent','id, lparam, dparam, sparam'), ('Deinit','OnDeinit','reason')):
            self.assertEqual(body(self.entry, 'DF03_Adapter'+adapter), norm('{ DF03_Source'+source+'('+args+'); }'))

    def test_other_build_ownership_unchanged(self):
        self.assertEqual(body(active(self.execution, False), 'Exec_IdentityIsMine'),
                         norm('{ if(symbol != _Symbol) return false; return magic == _0_Magic; }'))

    def test_raw_probe_still_uses_control(self):
        self.assertIn(b'../../compat/df03/DF03_Generated.mqh', active(self.entry, False))
        self.assertNotIn(b'DF03_TemplateEngine.mqh', active(self.entry, False))

    def test_global_attach_guards_precede_native_init(self):
        text = body(active(self.core), 'OnInit')
        for clause in ('_0_Magic == 990001', 'StringLen(Persist_Key("exit_closeall")) > 63'):
            self.assertLess(text.index(norm(clause)), text.index('DF03_AdapterInit ('))


def negative_contract_test(field, before, after):
    def test(self):
        data = {key: getattr(self, key) for key in ('execution', 'entry', 'core', 'risk')}
        self.assertIn(before.encode(), data[field])
        data[field] = data[field].replace(before.encode(), after.encode(), 1)
        with self.assertRaises(ValueError):
            safety_contract(**data)
    return test


for name, field, before, after in (
    ('range_lower', 'execution', 'magic > (long)_21_DF03_MagicStart', 'magic >= (long)_21_DF03_MagicStart'),
    ('range_upper', 'execution', '_21_DF03_MagicStart + 5', '_21_DF03_MagicStart + 6'),
    ('foreign_symbol', 'execution', 'if(symbol != _Symbol) return false;', ''),
    ('kill_close', 'execution', 'if(!g_trade.PositionClose(tk))', 'if(false)'),
    ('kill_pending', 'execution', 'Exec_CancelAllPending();', ''),
    ('flat_proof', 'execution', 'return (Exec_CountAll() == 0 && Exec_CountPending() == 0);', 'return true;'),
    ('dryrun', 'entry', 'DryRun || ', ''),
    ('magic_init', 'entry', '_0_Magic != (long)_21_DF03_MagicStart || ', ''),
    ('selfgate', 'entry', ' || _MG_SelfGate)', ')'),
    ('risk_gate', 'entry', 'if(!RiskControl_AllowNewOrder()) return false;', ''),
    ('flat_account_gate', 'entry', 'Exec_CountAll() == 0 && Exec_CountPending() == 0 && ', ''),
    ('heat', 'entry', 'return Basket_HeatCheckPass(symbol, lot);', 'return true;'),
    ('spread', 'entry', ' || !Exec_SpreadOK()', ''),
    ('macro', 'entry', 'Exec_MacroBlocked() || ', ''),
    ('news', 'entry', 'Exec_NewsBlocked() || ', ''),
    ('lot_step', 'entry', ' || step <= 0.0', ''),
    ('risk_clamp', 'entry', 'RiskControl_ClampLot(lot * Exec_MacroLotMult())', 'lot'),
    ('timer_identity_update', 'entry', 'RuntimeIdentity_Update();', ''),
    ('timer_current_dd', 'entry', 'if(RiskControl_CheckDD()) return false;', ''),
    ('timer_halt_refusal', 'entry', 'if(RiskControl_IsHalted()) return false;', ''),
    ('hardkill_order', 'core', 'if(RiskControl_CheckDD()) return;\n   if(RiskControl_IsHalted()) return;\n   DF03_AdapterTick();', 'DF03_AdapterTick();'),
    ('shared_stack', 'core', 'DF03_AdapterTick();', 'DF03_AdapterTick(); Stack_Init();'),
    ('shared_recovery', 'core', 'DF03_AdapterTick();', 'DF03_AdapterTick(); Recovery_Init();'),
    ('shared_hedge', 'core', 'DF03_AdapterTick();', 'DF03_AdapterTick(); Hedge_Init();'),
    ('shared_exit', 'core', 'DF03_AdapterTick();', 'DF03_AdapterTick(); Exit_Init();'),
    ('bar_gate', 'core', 'DF03_AdapterTick();', 'if(IsNewBar()) DF03_AdapterTick();'),
):
    # Normalize only test fixture line endings, never source files.
    if name == 'hardkill_order':
        before = before.replace('\n', '\r\n') if b'\r\n' in read('ea_template/core/LabCore.mqh') else before
    setattr(B21Tests, 'test_refuse_' + name, negative_contract_test(field, before, after))


if __name__ == '__main__':
    unittest.main(verbosity=2)
