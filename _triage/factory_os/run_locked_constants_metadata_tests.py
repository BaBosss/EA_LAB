"""Deterministic cage for the semantic LockedConstants metadata boundary."""

import io
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)

import gen_locked_constants as GEN  # noqa: E402
import preset  # noqa: E402


def main():
    inputs_path = os.path.join(ROOT, 'ea_template', 'core', 'Inputs.mqh')
    inputs = io.open(inputs_path, encoding='utf-8-sig').read()
    wrappers = sorted(os.path.join('ea_template', name).replace(os.sep, '/')
                      for name in os.listdir(os.path.join(ROOT, 'ea_template'))
                      if name.startswith('Boss_') and name.endswith('.mq5'))

    def read(rel):
        return io.open(os.path.join(ROOT, rel.replace('/', os.sep)), encoding='utf-8-sig').read()

    generated = GEN.emit(read, inputs, wrappers)
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
    fixture_out = GEN.emit(lambda rel: fixture[rel], '#ifndef LAB_ENTRY_11\n', ['ea_template/Boss_11_Fix.mq5'])
    checks.extend([
        ('fixture metadata marker excludes build receipt', 'const:LAB_BUILD_RECEIPT=' not in fixture_out),
        ('fixture metadata marker excludes fingerprint version', 'const:CFG_FP_VERSION=' not in fixture_out),
        ('fixture ordinary constant remains represented', 'const:ORDINARY=' in fixture_out),
    ])
    for label, ok in checks:
        print('[PASS] ' + label if ok else '[FAIL] ' + label)
    print('PASS %d/%d' % (sum(1 for _, ok in checks if ok), len(checks)))
    return 0 if all(ok for _, ok in checks) else 1


if __name__ == '__main__':
    sys.exit(main())
