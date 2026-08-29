import hashlib
import pathlib
import tempfile
import unittest
import sys

ROOT = pathlib.Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT))

from _triage.factory_os import setfile
from _triage.factory_vnext.boss_family_first_green import (
    BossFamilyFirstGreenError, SPECS, _assert_locked_values, build_boss_first_green, write_boss_first_green,
)
from _triage.factory_vnext.variant_generator import validate_variant_build_package

EXPECTED_PROJECTION = {11:29, 12:26, 13:35, 15:29, 16:21}
EXPECTED_MISSING = {11:0, 12:0, 13:0, 15:0, 16:1}

class Boss1116FirstGreenTests(unittest.TestCase):
    def test_real_fixed_config_packages(self):
        for boss in (11,12,13,15,16):
            with self.subTest(boss=boss):
                build=build_boss_first_green(str(ROOT),boss)
                self.assertEqual(build['all_binding_count'],SPECS[boss]['bindings'])
                self.assertEqual(build['projection_binding_count'],EXPECTED_PROJECTION[boss])
                self.assertEqual(build['physical_baseline_key_count'],SPECS[boss]['physical'])
                self.assertEqual(len(build['projected_not_in_baseline']),EXPECTED_MISSING[boss])
                projection=build['variant_build_package']['ParameterProjection']
                self.assertEqual({r['role'] for r in projection},{'LOCKED'})
                self.assertEqual({r['projection'] for r in projection},{'SNAPSHOT_ONLY'})
                self.assertFalse(build['mt5_set_compat_manifest']['refusal_rows'])
                validate_variant_build_package(build['variant_build_package'])

    def test_proposed_sets_preserve_baseline_and_disable_optimizer(self):
        for boss in (11,12,13,15,16):
            with self.subTest(boss=boss):
                build=build_boss_first_green(str(ROOT),boss)
                baseline=(ROOT/SPECS[boss]['baseline']).read_text(encoding='utf-8-sig')
                before=setfile.parse_set(baseline)[0]; after=setfile.parse_set(build['proposed_set'])[0]
                self.assertEqual([x.name for x in after[:len(before)]],[x.name for x in before])
                self.assertEqual([x.value for x in after[:len(before)]],[x.value for x in before])
                for line in after:
                    if line.optimize_tail is not None:
                        self.assertTrue(line.optimize_tail.endswith('N'))
        b16=build_boss_first_green(str(ROOT),16)
        self.assertEqual([(r['parameter'],r['locked_value']) for r in b16['projected_not_in_baseline']],[('_16_BaseLotMode','0')])
        self.assertTrue(b16['proposed_set'].rstrip().endswith('_16_BaseLotMode=0'))

    def test_locked_value_drift_refuses(self):
        build=build_boss_first_green(str(ROOT),11)
        bindings=[r for r in __import__('json').loads('[]')]  # keep test mutation local below
        from _triage.factory_vnext.boss_family_first_green import _h01_bindings, _jsonl
        bindings=_h01_bindings(_jsonl(ROOT/'factory/parameter_bindings.jsonl'),11)
        baseline=(ROOT/SPECS[11]['baseline']).read_text(encoding='utf-8-sig')
        locked=next(r for r in bindings if r['role']=='LOCKED' and r['parameter'] in baseline)
        line=next(x for x in setfile.parse_set(baseline)[0] if x.name==locked['parameter'])
        mutated=baseline.replace(line.raw, line.name+'=999999',1)
        with self.assertRaisesRegex(BossFamilyFirstGreenError,'frozen LOCKED values differ'):
            _assert_locked_values(ROOT,mutated,bindings,11)

    def test_writes_byte_identical_artifacts(self):
        for boss in (11,12,13,15,16):
            with self.subTest(boss=boss), tempfile.TemporaryDirectory() as a, tempfile.TemporaryDirectory() as b:
                write_boss_first_green(str(ROOT),boss,a); write_boss_first_green(str(ROOT),boss,b)
                one={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in pathlib.Path(a).iterdir()}
                two={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in pathlib.Path(b).iterdir()}
                self.assertEqual(one,two)

if __name__=='__main__': unittest.main(verbosity=2, testRunner=unittest.TextTestRunner(stream=sys.stdout, verbosity=2))
