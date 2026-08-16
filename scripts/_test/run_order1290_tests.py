# -*- coding: utf-8 -*-
"""ORDER-1290 surface evidence tests.

The fixture is deliberately offline: the bytes stand in for the committed .set
and Inputs.mqh that a Control Tower reader would fetch.  No terminal or runner
is invoked, and every negative changes one binding or one completeness fact.
"""
import copy
import hashlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
FACTORY = os.path.join(ROOT, '_triage', 'factory_os')
if FACTORY not in sys.path:
    sys.path.insert(0, FACTORY)

import surface_evidence as surface


PASS = 0
FAIL = 0


def check(name, condition, detail=''):
    global PASS, FAIL
    if condition:
        PASS += 1
        print('[PASS] ' + name)
    else:
        FAIL += 1
        print('[FAIL] ' + name + (': ' + detail if detail else ''))


def fixture():
    input_bytes = (b'#ifndef LAB_ENTRY_TEST\n'
                   b'#define LAB_ENTRY_TEST\n'
                   b'#endif\n'
                   b'input int Alpha = 1;\n'
                   b'input int Beta = 2;\n')
    set_bytes = (b'; build=LAB_ENTRY_TEST surface=2 effective_config_hash=' + b'c' * 64 +
                 b' (surface+constants)\nAlpha=1\nBeta=2\n')
    key = {
        'expert': 'SyntheticEA', 'symbol': 'XAUUSD', 'tf': 'H1',
        'from_date': '2099.01.01', 'to_date': '2099.01.02', 'model': 1,
        'deposit': 10000, 'currency': 'USD', 'account_unit': 'USD',
        'leverage': 100, 'terminal_build': 5000,
        'set_hash': hashlib.sha256(set_bytes).hexdigest(),
        'ex5_hash': 'b' * 64, 'effective_config_hash': 'c' * 64,
        'data_fingerprint': 'v1:' + 'd' * 64, 'lane': 'D:/Meta 5',
    }
    return input_bytes, set_bytes, key


def main():
    input_bytes, set_bytes, key = fixture()
    run_id = 'RUN-20990101-1290'
    path = 'fixtures/effective_surface.set'
    source_path = 'fixtures/Inputs.mqh'
    record = surface.make_surface_state(
        run_id, key, path, set_bytes, source_path, input_bytes, 'LAB_ENTRY_TEST')

    check('valid FULL surface evidence is accepted',
          surface.validate_surface_state(record, run_id, key, set_bytes, input_bytes) == [])
    check('record carries run/config linkage and both source hashes',
          record['run_id'] == run_id and record['execution_key_digest']
          and record['set_sha256'] == key['set_hash']
          and record['effective_config_hash'] == key['effective_config_hash'])

    # A missing assignment is not allowed to masquerade as FULL, even if the
    # stale record keeps the old count and hashes are updated to the new bytes.
    missing = set_bytes.replace(b'Beta=2\n', b'')
    missing_record = copy.deepcopy(record)
    missing_record['set_sha256'] = hashlib.sha256(missing).hexdigest()
    check('missing assignment makes evidence non-green',
          surface.validate_surface_state(missing_record, run_id, key, missing, input_bytes))

    # The sharp cache-remainder attack: preserve FULL/complete and the declared
    # count while deleting one assignment. The recomputed surface state must catch it.
    stale = copy.deepcopy(record)
    stale['assignments'] = 2
    stale['complete'] = True
    check('stale cache remainder pretending FULL is detected',
          surface.validate_surface_state(stale, run_id, key, missing, input_bytes))

    wrong_run = copy.deepcopy(record)
    wrong_run['run_id'] = 'RUN-20990101-999'
    check('surface from the wrong run is refused',
          surface.validate_surface_state(wrong_run, run_id, key, set_bytes, input_bytes))

    tampered_hash = copy.deepcopy(record)
    tampered_hash['input_source_sha256'] = 'e' * 64
    check('tampered input hash is refused',
          surface.validate_surface_state(tampered_hash, run_id, key, set_bytes, input_bytes))

    tampered_count = copy.deepcopy(record)
    tampered_count['declared'] = 1
    check('tampered surface count is refused',
          surface.validate_surface_state(tampered_count, run_id, key, set_bytes, input_bytes))

    incomplete = surface.make_surface_state(
        run_id, key, path, b'Alpha=1\n', source_path, input_bytes, 'LAB_ENTRY_TEST')
    check('an undeclared/partial writer result cannot be accepted as complete evidence',
          not incomplete['complete'] and surface.validate_surface_state(
              incomplete, run_id, key, b'Alpha=1\n', input_bytes))

    print('RESULT: %d passed, %d failed' % (PASS, FAIL))
    return 0 if FAIL == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
