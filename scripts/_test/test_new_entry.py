"""Unit tests for scripts/new_entry.py. Run: tools\\python312\\python.exe -I scripts\\_test\\test_new_entry.py

Most tests run the REAL text edits against the committed core files in memory (nothing is written), then
ask the neutrality proof's own `active()` whether any existing build would see a difference."""
import json
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(REPO, 'scripts'))
import new_entry as N  # noqa: E402

GOOD_INPUTS = ('input group "=== E098 Test ==="\n'
               'input int    _98_Period = 14;   // Period\n'
               'input double _98_Mult   = 2.0;  // Multiplier\n'
               'input bool   _98_UseX   = true; // Use X\n')


def manifest(**over):
    m = {'build': 98, 'name': 'Probe', 'title': 'Probe entry', 'entry_source': 'e.mqh', 'inputs_source': 'i.mqh',
         'init_call': 'Probe_Init()', 'deinit_call': 'Probe_Deinit();', 'own_ontick': None,
         'stack': {'mode': 'STACK_SINGLE', 'confirm': 'CONF_DISTANCE', 'note': 'single order'},
         'magic': 999801, 'preset_overlay': {'_98_Period': 20}}
    m.update(over)
    return m


def write_manifest(d, m, entry='EntrySignal Entry_Evaluate(){ }\nbool Probe_Init(){return true;}\nvoid Probe_Deinit(){}\n'):
    for n, t in (('e.mqh', entry), ('i.mqh', GOOD_INPUTS)):
        with open(os.path.join(d, n), 'w') as f:
            f.write(t)
    p = os.path.join(d, 'm.json')
    with open(p, 'w') as f:
        json.dump(m, f)
    return p


class ActiveTests(unittest.TestCase):
    def test_ifdef_ifndef_else_and_define(self):
        t = '#ifdef A\nx\n#else\ny\n#endif\n#ifndef A\nz\n#define B\n#endif\n#ifdef B\nw\n#endif\n// c\n\n'
        self.assertEqual(N.active(t, 'A'), ['x'])
        self.assertEqual(N.active(t, None), ['y', 'z', '#define B', 'w'])

    def test_unbalanced_refused(self):
        with self.assertRaises(N.Refuse):
            N.active('#ifdef A\nx\n', 'A')

    def test_trailing_comment_is_kept(self):
        self.assertEqual(N.active('input int a = 1; // label\n', None), ['input int a = 1; // label'])


class ProofSpecificity(unittest.TestCase):
    def test_proof_can_fail(self):
        for name, ok in N.selftest(REPO):
            self.assertTrue(ok, name)


class ManifestTests(unittest.TestCase):
    def test_ok(self):
        with tempfile.TemporaryDirectory() as d:
            mf = N.load_manifest(write_manifest(d, manifest()))
            self.assertEqual(mf['init_call'], 'Probe_Init();')
            self.assertEqual(mf['entry_file'], 'Entry_Probe.mqh')
            self.assertEqual(mf['preset_overlay'], {'_98_Period': '20'})

    def test_refusals(self):
        bad = [dict(build=5), dict(name='bad name'), dict(title='a "q" b'), dict(init_call='a;b();'),
               dict(own_ontick='x y'), dict(stack={'mode': 'single', 'confirm': 'CONF_DISTANCE'}),
               dict(magic=5), dict(preset_overlay={'a': [1]}), dict(entry_file='Foo.mqh')]
        for over in bad:
            with tempfile.TemporaryDirectory() as d:
                with self.assertRaises(N.Refuse, msg=str(over)):
                    N.load_manifest(write_manifest(d, manifest(**over)))

    def test_missing_source_refused(self):
        with tempfile.TemporaryDirectory() as d:
            p = write_manifest(d, manifest())
            os.remove(os.path.join(d, 'e.mqh'))
            with self.assertRaises(N.Refuse):
                N.load_manifest(p)


class HookInjectionTests(unittest.TestCase):
    """Codex review 2026-11-06 P1: a multi-line init_call smuggled preprocessor lines into LabCore.mqh."""

    CODEX_PAYLOAD = 'Probe_Init(\n#else\n#ifdef BOSS_LAB_INPUTS_MQH\n#include "entries/Leak.mqh"\n#endif\n#endif\n#ifdef LAB_ENTRY_98\n);'

    def load(self, **over):
        with tempfile.TemporaryDirectory() as d:
            return N.load_manifest(write_manifest(d, manifest(**over)))

    def test_multiline_and_directive_calls_refused(self):
        for bad in (self.CODEX_PAYLOAD, 'Probe_Init();\n#endif', 'Probe_Init(); // x', 'a(b);c();', 'Probe_Init(\n);'):
            with self.assertRaises(N.Refuse, msg=repr(bad)):
                self.load(init_call=bad)
            with self.assertRaises(N.Refuse, msg=repr(bad)):
                self.load(deinit_call=bad)

    def test_trailing_newline_values_refused(self):
        for over in (dict(name='Probe\n'), dict(entry_file='Entry_Probe.mqh\n'), dict(own_ontick='Probe_Tick\n'),
                     dict(stack={'mode': 'STACK_SINGLE\n', 'confirm': 'CONF_DISTANCE'})):
            with self.assertRaises(N.Refuse, msg=repr(over)):
                self.load(**over)

    def test_extra_file_names_checked(self):
        with tempfile.TemporaryDirectory() as d:
            p = write_manifest(d, manifest(extra_files=['bad name.mqh']))
            open(os.path.join(d, 'bad name.mqh'), 'w').close()
            with self.assertRaises(N.Refuse):
                N.load_manifest(p)

    def test_directive_audit(self):
        ok = '+++ b/x\n+#ifdef LAB_ENTRY_98\n+  #include "entries/Entry_Probe.mqh"\n+#endif\n+#ifndef LAB_CONST__98_X\n+#define LAB_CONSTVAL_X 1\n+input int a = 1;\n'
        self.assertEqual(N.directive_violations(ok), [])
        for bad in ('+#else', '+#ifdef BOSS_LAB_INPUTS_MQH', '+#include "entries/Leak.mqh"', '+#if 1', '+#undef LAB_ENTRY_14',
                    '+#ifdef LAB_ENTRY_14 && X', '+#define EVIL 1'):
            self.assertEqual(N.directive_violations(bad + '\n'), [bad[1:]], bad)

    def test_destination_collision_refused(self):
        with tempfile.TemporaryDirectory() as d:
            a = os.path.join(d, 'x', 'Entry_Probe.mqh')
            b = os.path.join(d, 'x', '..', 'x', 'Entry_Probe.mqh')
            with self.assertRaises(N.Refuse):
                N.check_destinations([a, b], d)
            N.check_destinations([a, os.path.join(d, 'y.mqh')], d)


class InputsBlockTests(unittest.TestCase):
    def test_parse_and_render(self):
        items = N.parse_entry_inputs(GOOD_INPUTS, 98)
        txt = N.render_entry_inputs(items, 98, 'Probe', 'ab' * 32)
        self.assertIn('#ifndef LAB_CONST__98_Period\ninput int _98_Period = 14; // [P19800] Period\n#endif\n', txt)
        self.assertIn('#ifdef LAB_CONST__98_Mult\nconst double _98_Mult = LAB_CONSTVAL__98_Mult;\n#endif\n', txt)
        self.assertIn('[P19802] Use X', txt)
        self.assertTrue(txt.rstrip().endswith('#endif'))

    def test_refusals(self):
        for text in ('input int _97_X = 1; // wrong prefix\n', 'input int _98_X = 1;\ninput int _98_X = 2;\n',
                     '#ifdef FOO\ninput int _98_X = 1;\n#endif\n', 'int stray = 1;\n', 'input group "g"\n'):
            with self.assertRaises(N.Refuse, msg=text):
                N.parse_entry_inputs(text, 98)

    def test_existing_pid_tag_is_replaced(self):
        items = N.parse_entry_inputs('input int _98_X = 1; // [P12345] label\n', 98)
        self.assertEqual(items[0][4], 'label')


class HookTests(unittest.TestCase):
    ANCHOR = 'A\n#endif\n'

    def test_first_after_anchor_then_after_last_marker(self):
        t = 'pre\n' + self.ANCHOR + 'post\n'
        t = N.insert_hook(t, 'init', 40, 'one\n', self.ANCHOR)
        t = N.insert_hook(t, 'init', 41, 'two\n', self.ANCHOR)
        self.assertEqual(t, 'pre\nA\n#endif\none\n// new_entry.py: end init build 40\ntwo\n// new_entry.py: end init build 41\npost\n')

    def test_duplicate_and_bad_anchor_refused(self):
        t = N.insert_hook('x\n' + self.ANCHOR, 'init', 40, 'one\n', self.ANCHOR)
        with self.assertRaises(N.Refuse):
            N.insert_hook(t, 'init', 40, 'one\n', self.ANCHOR)
        with self.assertRaises(N.Refuse):
            N.insert_hook('nothing here\n', 'init', 40, 'one\n', self.ANCHOR)
        with self.assertRaises(N.Refuse):
            N.insert_hook(self.ANCHOR * 2, 'init', 40, 'one\n', self.ANCHOR)


class RealCoreEditsAreNeutral(unittest.TestCase):
    """The edits applied in memory to the committed core must not change any existing build."""

    @classmethod
    def setUpClass(cls):
        cls.inputs = N.git(REPO, 'show', 'HEAD:ea_template/core/Inputs.mqh').replace('\r\n', '\n')
        cls.labcore = N.git(REPO, 'show', 'HEAD:ea_template/core/LabCore.mqh').replace('\r\n', '\n')
        cls.tags = N.existing_tags(cls.inputs)

    def mf(self, **over):
        with tempfile.TemporaryDirectory() as d:
            return N.load_manifest(write_manifest(d, manifest(**over)))

    def edit(self, **over):
        mf = self.mf(**over)
        items = N.parse_entry_inputs(GOOD_INPUTS, mf['build'])
        return mf, N.edit_inputs(self.inputs, mf, items, 'cd' * 32), N.edit_labcore(self.labcore, mf)

    def test_existing_builds_see_identical_active_source(self):
        _, ni, nl = self.edit(own_ontick='Probe_OnTick')
        for tag in self.tags + [None]:
            self.assertEqual(N.active(self.inputs, tag), N.active(ni, tag), 'Inputs.mqh %s' % tag)
            self.assertEqual(N.active(self.labcore, tag), N.active(nl, tag), 'LabCore.mqh %s' % tag)

    def test_new_build_sees_its_blocks(self):
        _, ni, nl = self.edit(own_ontick='Probe_OnTick')
        ai, al = N.active(ni, 'LAB_ENTRY_98'), N.active(nl, 'LAB_ENTRY_98')
        self.assertTrue(any('input int _98_Period = 14;' in l for l in ai))
        self.assertTrue(any('StackMode    = STACK_SINGLE' in l for l in ai))
        self.assertIn('   #include "entries/Entry_Probe.mqh"', al)
        self.assertIn('   Probe_Init();', al)
        self.assertIn('   Probe_Deinit();', al)
        self.assertIn('   if(Probe_OnTick()) return;', al)

    def test_two_builds_chain(self):
        mf1, ni, nl = self.edit()
        items2 = N.parse_entry_inputs(GOOD_INPUTS.replace('_98_', '_97_'), 97)
        mf2 = self.mf(build=97, name='Probe2')
        ni2 = N.edit_inputs(ni, mf2, items2, 'ef' * 32)
        nl2 = N.edit_labcore(nl, mf2)
        for tag in self.tags + [None, 'LAB_ENTRY_98']:
            a = N.active(ni, tag)
            self.assertEqual(a, N.active(ni2, tag), tag)
        self.assertEqual(N.active(nl, 'LAB_ENTRY_98'), N.active(nl2, 'LAB_ENTRY_98'))
        self.assertIn('   Probe_Init();', N.active(nl2, 'LAB_ENTRY_97'))

    def test_second_apply_of_same_build_refused(self):
        mf, ni, nl = self.edit()
        with self.assertRaises(N.Refuse):
            N.edit_inputs(ni, mf, N.parse_entry_inputs(GOOD_INPUTS, 98), 'x')
        with self.assertRaises(N.Refuse):
            N.edit_labcore(nl, mf)

    def test_existing_build_number_refused(self):
        with self.assertRaises(N.Refuse):
            N.edit_inputs(self.inputs, self.mf(build=29), N.parse_entry_inputs(GOOD_INPUTS.replace('_98_', '_29_'), 29), 'x')

    def test_registry_rows_carry_the_declared_pid_and_default(self):
        mf, ni, _ = self.edit()
        rows = N.registry_rows(N.parse_entry_inputs(GOOD_INPUTS, 98), mf, ni)
        self.assertEqual([r[0] for r in rows], ['_98_Period', '_98_Mult', '_98_UseX'])
        self.assertEqual([r[12] for r in rows], ['19800', '19801', '19802'])
        self.assertTrue(rows[0][6].startswith('14 - Inputs.mqh:'))
        self.assertEqual(len(rows[0]), 17)


class MiscTests(unittest.TestCase):
    def test_wrapper_owner_sorted_and_unique(self):
        t = 'build_tag,wrapper_rel\nLAB_ENTRY_11,a\nLAB_ENTRY_29,b\n'
        out = N.add_wrapper_owner(t, 12, 'c')
        self.assertEqual(out, 'build_tag,wrapper_rel\nLAB_ENTRY_11,a\nLAB_ENTRY_12,c\nLAB_ENTRY_29,b\n')
        with self.assertRaises(N.Refuse):
            N.add_wrapper_owner(out, 12, 'c')

    def test_ascii_refused(self):
        with self.assertRaises(N.Refuse):
            N.need_ascii('x', 'café')

    def test_snapshot_restores_changed_and_removes_created(self):
        with tempfile.TemporaryDirectory() as d:
            a, b = os.path.join(d, 'a'), os.path.join(d, 'b')
            with open(a, 'w') as f:
                f.write('old')
            s = N.Snapshot()
            s.keep(a)
            s.keep(b)
            with open(a, 'w') as f:
                f.write('new')
            with open(b, 'w') as f:
                f.write('created')
            s.restore()
            with open(a) as f:
                self.assertEqual(f.read(), 'old')
            self.assertFalse(os.path.exists(b))

    def test_snapshot_restores_read_only_files_and_continues_after_an_error(self):
        import stat
        with tempfile.TemporaryDirectory() as d:
            ro, created, ok = (os.path.join(d, n) for n in ('ro', 'created', 'ok'))
            for p in (ro, ok):
                with open(p, 'w') as f:
                    f.write('old')
            os.chmod(ro, stat.S_IREAD)
            s = N.Snapshot()
            for p in (ro, created, ok):
                s.keep(p)
            os.chmod(ro, stat.S_IWRITE)
            for p in (ro, created, ok):
                with open(p, 'w') as f:
                    f.write('new')
            os.chmod(ro, stat.S_IREAD)
            s.restore()
            with open(ro) as f:
                self.assertEqual(f.read(), 'old')
            with open(ok) as f:
                self.assertEqual(f.read(), 'old')
            self.assertFalse(os.path.exists(created))
            self.assertFalse(os.stat(ro).st_mode & stat.S_IWRITE)    # its read-only attribute is back
            # an unrestorable path (parent directory removed) must not stop the others
            s2 = N.Snapshot()
            gone = os.path.join(d, 'sub', 'f')
            os.makedirs(os.path.dirname(gone))
            with open(gone, 'w') as f:
                f.write('x')
            s2.keep(gone)
            s2.keep(ok)
            os.remove(gone)
            os.rmdir(os.path.dirname(gone))
            with open(ok, 'w') as f:
                f.write('new')
            with self.assertRaises(N.Refuse):
                s2.restore()
            with open(ok) as f:
                self.assertEqual(f.read(), 'old')

    def test_wrapper_text(self):
        with tempfile.TemporaryDirectory() as d:
            mf = N.load_manifest(write_manifest(d, manifest()))
        w = N.render_wrapper(mf, 'a' * 64, 'b' * 64)
        self.assertIn('#define LAB_ENTRY_98\n#define LAB_ENTRY_TAG "98_Probe"\n#include "core/LabCore.mqh"\n', w)
        self.assertNotIn('{', w)   # a wrapper has no statements


if __name__ == '__main__':
    unittest.main(verbosity=2)
