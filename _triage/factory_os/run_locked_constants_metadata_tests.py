"""Deterministic cage for the semantic LockedConstants metadata boundary."""

import io
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)

import gen_locked_constants as GEN  # noqa: E402
import preset  # noqa: E402
import wrapper_owners  # noqa: E402


def main():
    inputs_path = os.path.join(ROOT, 'ea_template', 'core', 'Inputs.mqh')
    inputs = io.open(inputs_path, encoding='utf-8-sig').read()
    def read(rel):
        return io.open(os.path.join(ROOT, rel.replace('/', os.sep)), encoding='utf-8-sig').read()

    loaded = wrapper_owners.load_from_read(
        read, root_listing=sorted('ea_template/' + name
                                  for name in os.listdir(os.path.join(ROOT, 'ea_template'))
                                  if name.endswith('.mq5')))
    generated = GEN.emit(read, inputs, loaded.by_tag)
    committed = io.open(os.path.join(ROOT, GEN.OUT_REL.replace('/', os.sep)), encoding='utf-8-sig').read()
    checks = [
        ('committed LockedConstants equals canonical generator', generated == committed),
        ('LAB_BUILD_RECEIPT excluded from semantic preimage', 'const:LAB_BUILD_RECEIPT=' not in generated),
        ('CFG_FP_VERSION excluded from semantic preimage', 'const:CFG_FP_VERSION=' not in generated),
        ('ordinary locked constant remains represented', 'const:HEDGE_TAG=' in generated),
    ]

    fixture = {
        'ea_template/Boss_11_Fix.mq5': '#define LAB_ENTRY_11\n#include "core/FixCore.mqh"\n',
        'ea_template/core/FixCore.mqh': (
            '#define LAB_ENTRY_11\n'
            '#define LAB_BUILD_RECEIPT "br-fixture" // @CFG_METADATA\n'
            '#define CFG_FP_VERSION "cfgfp-v1" // @CFG_METADATA\n'
            '#define ORDINARY 7\n'),
    }
    fixture_out = GEN.emit(lambda rel: fixture[rel], '#ifndef LAB_ENTRY_11\n',
                           {'LAB_ENTRY_11': 'ea_template/Boss_11_Fix.mq5'})
    checks.extend([
        ('fixture metadata marker excludes build receipt', 'const:LAB_BUILD_RECEIPT=' not in fixture_out),
        ('fixture metadata marker excludes fingerprint version', 'const:CFG_FP_VERSION=' not in fixture_out),
        ('fixture ordinary constant remains represented', 'const:ORDINARY=' in fixture_out),
    ])
    def scan_fixture(defines):
        return GEN.scan(lambda rel: '#define LAB_ENTRY_11\n' + defines,
                        'LAB_ENTRY_11', 'fixture.mq5')

    boolean_defines = ('#define ENABLED true\n#define DISABLED false\n'
                       '#define DERIVED ((ENABLED + true) * 3 - DISABLED - false)\n'
                       '#define NEGATIVE (-true + false)\n'
                       '#define RATE 1.5\n#define PROMOTED (RATE * true + false)\n'
                       '#define QUOTED "true"\n')
    consts = {c.name: c for c in scan_fixture(boolean_defines)}
    for name, expected in [('ENABLED', '1'), ('DISABLED', '0'),
                           ('DERIVED', '6'), ('NEGATIVE', '-1')]:
        c = consts[name]
        checks.append((name + ' canonical long',
                       (c.kind, c.text, c.number) == (GEN.KIND_LONG, expected, int(expected))))
    checks.extend([
        ('boolean reference preserves double promotion',
         (consts['PROMOTED'].kind, consts['PROMOTED'].text, consts['PROMOTED'].number)
         == (GEN.KIND_DOUBLE, preset.canonical_double(1.5), 1.5)),
        ('quoted true stays a string', consts['QUOTED'].kind == GEN.KIND_STRING
         and consts['QUOTED'].text == 'true'),
        ('boolean emitter reads macro through long canonicalizer',
         consts['ENABLED'].canon_call() == 'CFG_CanonLong((long)ENABLED)'),
        ('boolean constants remain in Python fingerprint mapping',
         GEN.constants_for(lambda rel: '#define LAB_ENTRY_11\n' + boolean_defines,
                           'LAB_ENTRY_11', 'fixture.mq5')['DISABLED'] == '0'),
        ('numeric equivalent redefinition accepted',
         len(scan_fixture('#define FLAG true\n#define FLAG 1\n')) == 1),
    ])
    for label, defines, diagnostic in [
        ('unknown identifier', '#define X arbitrary_name\n', 'not an already-defined'),
        ('boolean prefix identifier', '#define X true_value\n', 'not an already-defined'),
        ('uppercase identifier', '#define X TRUE\n', 'not an already-defined'),
        ('Python True', '#define X True\n', 'not a number'),
        ('Python False', '#define X False\n', 'not a number'),
        ('nested unknown', '#define X (true + unknown)\n', 'not an already-defined'),
        ('forward reference', '#define X LATER\n#define LATER true\n', 'not an already-defined'),
        ('string arithmetic', '#define S "true"\n#define X (S + true)\n', 'string constant'),
        ('call syntax', '#define X true()\n', 'cannot reduce'),
        ('boolean operator', '#define X (true and false)\n', 'cannot reduce'),
        ('MQL logical syntax', '#define X (true && false)\n', 'cannot reduce'),
        ('conflicting redefinition', '#define X true\n#define X false\n', 'defined twice'),
        ('division by false', '#define X (true / false)\n', 'divides by zero'),
        ('if directive', '#if true\n#define X 1\n#endif\n', 'does not model'),
        ('elif directive', '#ifdef LAB_ENTRY_11\n#elif true\n#endif\n', 'does not model'),
    ]:
        try:
            scan_fixture(defines)
        except preset.PresetRefusal as exc:
            checks.append((label + ' refused', diagnostic in str(exc)))
        else:
            checks.append((label + ' refused', False))

    for label, ok in checks:
        print('[PASS] ' + label if ok else '[FAIL] ' + label)
    print('PASS %d/%d' % (sum(1 for _, ok in checks if ok), len(checks)))
    return 0 if all(ok for _, ok in checks) else 1


if __name__ == '__main__':
    sys.exit(main())
