"""Focused ORDER-1281 tests for the governed schema/commit-path OwnerRef sweep.

The production registry files are read, never edited.  Negative cases mutate deep copies of one
live row and pass those copies to the same enumerator the schema fixture path uses.
"""
import copy
import hashlib
import io
import json
import os
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)

import evidence  # noqa: E402
import registry  # noqa: E402
import run_schema_fixtures as fixtures  # noqa: E402

# Cardinality is an engagement assertion, not a schema limit. The accepted B11/12/13/15/16
# H01 registrations established 1172 refs; B16-H05 and B16-H08 each add one preregistration
# ref plus 161 ParameterBinding definition refs; B18-H01 adds one preregistration ref plus`n# 147 ParameterBinding definition refs, for 1644 governed live OwnerRefs.
EXPECTED_LIVE_OWNERREFS = 1644


def fail(message):
    raise AssertionError(message)


def expect(condition, message):
    if not condition:
        fail(message)


def first_live_ref(source):
    stores = registry.load_all(source=source)
    records = []
    for rel in sorted(stores):
        _meta, rows = stores[rel]
        records.extend(('%s:%d' % (rel, line), row) for line, row in rows)
    count, problems = fixtures.check_live_owner_refs(records, source)
    expect(count == EXPECTED_LIVE_OWNERREFS,
           'live OwnerRef count changed: got %d, want %d' % (count, EXPECTED_LIVE_OWNERREFS))
    expect(not problems, 'a live OwnerRef failed before adversarial mutation: %s' % problems)
    for where, row in records:
        refs = list(fixtures._owner_refs(row, where))
        if refs:
            return where, row, refs[0][1], stores
    fail('no live OwnerRef fixture was found')


def main():
    source = evidence.EvidenceSource.for_run(root=ROOT)
    where, row, ref, stores = first_live_ref(source)
    production_bytes = {}
    for rel in sorted(stores):
        production_bytes[rel] = hashlib.sha256(source.read_committed_bytes(rel)).hexdigest()

    count, problems = fixtures.check_live_owner_refs([(where, row)], source)
    expect(count == 1 and not problems, 'valid pinned OwnerRef was not accepted: %s' % problems)
    print('PASS valid pinned OwnerRef')

    bad_hash = copy.deepcopy(row)
    list(fixtures._owner_refs(bad_hash, where))[0][1]['raw_sha256'] = '0' * 64
    _count, problems = fixtures.check_live_owner_refs([(where, bad_hash)], source)
    expect(any('R3' in problem for problem in problems),
           'bad raw_sha256 was not refused: %s' % problems)
    print('PASS bad hash refused')

    unreachable = copy.deepcopy(row)
    list(fixtures._owner_refs(unreachable, where))[0][1]['path'] = 'ORDER-1281/no-such-file'
    _count, problems = fixtures.check_live_owner_refs([(where, unreachable)], source)
    expect(any('R1' in problem for problem in problems),
           'unreachable OwnerRef path was not refused: %s' % problems)
    print('PASS unreachable path refused')

    malformed = copy.deepcopy(row)
    list(fixtures._owner_refs(malformed, where))[0][1]['commit_oid'] = 'not-a-commit'
    _count, problems = fixtures.check_live_owner_refs([(where, malformed)], source)
    expect(problems and 'commit_oid' in problems[0],
           'malformed OwnerRef was not refused: %s' % problems)
    print('PASS malformed OwnerRef refused')

    # Exercise the governed enumerator with a temporary fixture copy, not only an in-memory
    # mutation. The production registry bytes remain outside this directory and are checked below.
    temp_root = tempfile.mkdtemp(prefix='order1281-ownerref-')
    try:
        temp_store = os.path.join(temp_root, 'factory', 'parameter_bindings.jsonl')
        os.makedirs(os.path.dirname(temp_store))
        synthetic_bad_pin = copy.deepcopy(row)
        list(fixtures._owner_refs(synthetic_bad_pin, where))[0][1]['blob_oid'] = '0' * 40
        with io.open(temp_store, 'w', encoding='utf-8', newline='\n') as fh:
            fh.write(json.dumps({'_comment': 'ORDER-1281 temporary fixture'}) + '\n')
            fh.write(json.dumps(synthetic_bad_pin) + '\n')
        _meta, fixture_rows = registry.read_store('factory/parameter_bindings.jsonl',
                                                   root=temp_root)
        fixture_records = [('temporary fixture:%d' % line, record)
                           for line, record in fixture_rows]
        _count, problems = fixtures.check_live_owner_refs(fixture_records, source)
        expect(any('R2' in problem for problem in problems),
               'synthetic bad pin was not refused: %s' % problems)
    finally:
        shutil.rmtree(temp_root, ignore_errors=True)
    print('PASS synthetic bad pin in temporary fixture refused')

    for rel, before in production_bytes.items():
        after = hashlib.sha256(source.read_committed_bytes(rel)).hexdigest()
        expect(after == before, 'negative test changed production registry bytes: %s' % rel)
    print('PASS production registry bytes unchanged during negative tests')

    schema = json.loads(source.read_committed('_triage/factory_os/schemas.json'))
    owner = schema['$defs']['OwnerRef']
    expect(owner.get('x-enforcement-status') == 'WIRED',
           'OwnerRef schema is not WIRED: %r' % owner.get('x-enforcement-status'))
    expect(owner.get('x-enforcer') == '_triage/factory_os/run_schema_fixtures.py',
           'OwnerRef points at the wrong enforcer: %r' % owner.get('x-enforcer'))
    print('PASS canonical schema/commit path is wired')
    print('ORDER-1281 PASS: %d live OwnerRefs, positive and four adversarial refusals'
          % EXPECTED_LIVE_OWNERREFS)
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as exc:  # noqa: BLE001 - focused cage reports a deterministic failure
        print('FAIL ORDER-1281: %s: %s' % (type(exc).__name__, exc))
        sys.exit(1)
