# -*- coding: utf-8 -*-
"""ORDER-1500 targeted tests for the run-journal validator.

The suite uses in-memory committed-byte sources for synthetic cases and the real
committed manifests for the preservation/read-through cases.  It deliberately
does not write to the repository or mutate the three historical manifests.
"""
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
FACTORY_ROOT = os.path.join(REPO_ROOT, '_triage', 'factory_os')
if FACTORY_ROOT not in sys.path:
    sys.path.insert(0, FACTORY_ROOT)

import evidence
import run_journal_validator as validator


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


class MemorySource(object):
    def __init__(self, files, fail_on=None):
        self.files = dict(files)
        self.fail_on = fail_on
        self.patterns = []

    def list_committed(self, pattern):
        self.patterns.append(pattern)
        if self.fail_on == ('list', pattern):
            raise evidence.ToolFailure('synthetic list failure')
        prefix = pattern[:-7] if pattern.endswith('*.jsonl') else pattern
        return sorted(p for p in self.files if p.startswith(prefix) and p.endswith('.jsonl'))

    def read_committed_bytes(self, rel):
        if self.fail_on == ('read', rel):
            raise evidence.ToolFailure('synthetic read failure')
        if rel not in self.files:
            raise evidence.ToolFailure('synthetic missing file')
        return self.files[rel]


def row(run_id='RUN-20990101-001', attempt=1, transition='QUEUED'):
    return {
        'entity': 'RunTransition',
        'run_id': run_id,
        'cell_id': 'SYNTHETIC',
        'attempt': attempt,
        'transition': transition,
        'at': '2099-01-01T00:00:00Z',
        'execution_key': current_key(),
    }


def current_key():
    return {
        'expert': 'SyntheticEA', 'symbol': 'XAUUSD', 'tf': 'H1',
        'from_date': '2099.01.01', 'to_date': '2099.01.02', 'model': 1,
        'deposit': 10000, 'currency': 'USD', 'account_unit': 'USD',
        'leverage': 100, 'terminal_build': 5000,
        'set_hash': 'a' * 64, 'ex5_hash': 'b' * 64,
        'effective_config_hash': 'c' * 64,
        'data_fingerprint': 'v1:' + ('d' * 64), 'lane': 'D:/Meta 5',
    }


def encoded(*records):
    return ('\n'.join(json.dumps(r, separators=(',', ':')) for r in records) + '\n').encode('utf-8')


def report_has_state(report, state):
    return any(r['state'] == state for r in report.rows)


def main():
    schema = os.path.join(FACTORY_ROOT, 'schemas.json')

    # A: a valid current row is accepted by the normal RunTransition contract.
    valid_source = MemorySource({
        'factory/runs/RUN-20990101-001.jsonl': encoded(row()),
    })
    valid_report = validator.validate_run_journals(valid_source, schema)
    check('A valid current RunTransition row -> VALID',
          valid_report.ok and report_has_state(valid_report, validator.VALID))

    # B/F: malformed current rows, including a fourth row, fail normally.
    invalid_source = MemorySource({
        'factory/runs/RUN-20990101-002.jsonl': encoded(row('RUN-20990101-002', attempt=0)),
        'factory/runs/RUN-20260802-005.jsonl': encoded(row('RUN-20260802-005', attempt=0)),
    })
    invalid_report = validator.validate_run_journals(invalid_source, schema)
    check('B malformed current/new row -> INVALID',
          not invalid_report.ok and len(invalid_report.invalid_rows) == 2)
    check('F fourth malformed row -> INVALID',
          any(r['file'] == 'factory/runs/RUN-20260802-005.jsonl'
              and r['state'] == validator.INVALID for r in invalid_report.rows))

    # G: a near-match path and ID cannot enter the exception set.
    near_source = MemorySource({
        'factory/runs/RUN-20260802-001x.jsonl': encoded(
            row('RUN-20260802-001x', attempt=0)),
    })
    near_report = validator.validate_run_journals(near_source, schema)
    check('G near-match ID/path -> INVALID',
          not near_report.ok and near_report.invalid_rows[0]['state'] == validator.INVALID)

    # J/K: AJV's historical anyOf is deliberately broad so it can read old rows;
    # the journal validator must not let that compatibility branch become a new
    # writer contract.  A path preimage and an old ini_hash are both refused.
    legacy_key = {
        k: v for k, v in current_key().items()
        if k not in ('account_unit', 'terminal_build')
    }
    legacy_key['ini_hash'] = 'e' * 64
    legacy_key['data_fingerprint'] = 'D:/Meta 5|XAUUSD|H1|2099.01.01|2099.01.02|M1'
    bad_legacy = row('RUN-20990101-006')
    bad_legacy['execution_key'] = legacy_key
    bad_legacy_report = validator.validate_run_journals(
        MemorySource({'factory/runs/RUN-20990101-006.jsonl': encoded(bad_legacy)}), schema)
    check('J new legacy ini_hash/preimage row -> INVALID',
          not bad_legacy_report.ok and bad_legacy_report.invalid_rows)

    bad_fingerprint = row('RUN-20990101-007')
    bad_fingerprint['execution_key']['data_fingerprint'] = 'D:/Meta 5|XAUUSD|H1|preimage'
    bad_fingerprint_report = validator.validate_run_journals(
        MemorySource({'factory/runs/RUN-20990101-007.jsonl': encoded(bad_fingerprint)}), schema)
    check('K current key with fingerprint preimage -> INVALID',
          not bad_fingerprint_report.ok and bad_fingerprint_report.invalid_rows)

    missing_surface_source = MemorySource({
        'factory/runs/RUN-20990101-008.jsonl': encoded(
            row('RUN-20990101-008'),
            row('RUN-20990101-008', transition='COMPLETED')),
    })
    missing_surface_report = validator.validate_run_journals(missing_surface_source, schema)
    check('L completed current row without surface evidence -> INVALID',
          not missing_surface_report.ok and any(
              'durable set_surface_state' in r.get('detail', '')
              for r in missing_surface_report.invalid_rows))

    # C/D/E and byte preservation: read the real committed manifests without writing them.
    legacy_paths = [
        'factory/runs/RUN-20260802-001.jsonl',
        'factory/runs/RUN-20260802-002.jsonl',
        'factory/runs/RUN-20260802-004.jsonl',
    ]
    legacy_source = evidence.EvidenceSource('index', root=REPO_ROOT)
    before = {}
    for path in legacy_paths:
        before[path] = legacy_source.read_committed_bytes(path)
    legacy_report = validator.validate_run_journals(legacy_source, schema)
    after = {p: legacy_source.read_committed_bytes(p) for p in legacy_paths}
    check('C/D/E exact three manifests -> LEGACY_EXCEPTION',
          legacy_report.ok and set(legacy_report.legacy_files) == set(legacy_paths)
          and not legacy_report.invalid_rows)
    check('exception IDs are exactly the approved closed set',
          validator.LEGACY_EXCEPTION_IDS == frozenset({
              'RUN-20260802-001', 'RUN-20260802-002', 'RUN-20260802-004'}))
    check('historical manifests remain byte-identical', before == after)
    caller_source = MemorySource(before)
    validator.validate_run_journals(caller_source, schema)
    check('validator caller enumerates factory/runs/*.jsonl',
          'factory/runs/*.jsonl' in caller_source.patterns)

    # H: changing the bytes of an exception path disables the exception; it is not a bypass.
    mutated = dict(before)
    mutated[legacy_paths[0]] += b'{not-json}\n'
    mutated_report = validator.validate_run_journals(MemorySource(mutated), schema)
    check('H changed historical bytes do not receive a general bypass',
          not mutated_report.ok and any(r['file'] == legacy_paths[0]
                                        and r['state'] == validator.INVALID
                                        for r in mutated_report.rows))

    # Removing one literal exception makes its still-invalid historical rows fail normally.
    reduced_report = validator._validate_run_journals(
        MemorySource(before), schema,
        legacy_ids=validator.LEGACY_EXCEPTION_IDS - frozenset({'RUN-20260802-002'}))
    check('literal exception removal makes the corresponding row fail',
          not reduced_report.ok and any(r['file'] == legacy_paths[1]
                                        and r['state'] == validator.INVALID
                                        for r in reduced_report.rows))

    # I: unreadable journal infrastructure is an error, never a valid result.
    broken = MemorySource({'factory/runs/RUN-20990101-003.jsonl': b''},
                          fail_on=('read', 'factory/runs/RUN-20990101-003.jsonl'))
    try:
        validator.validate_run_journals(broken, schema)
    except validator.JournalInfrastructureError:
        infra_ok = True
    else:
        infra_ok = False
    check('I unreadable journal infrastructure -> ERROR', infra_ok)

    # Metadata/caller contract.
    with io.open(schema, encoding='utf-8') as fh:
        schema_doc = json.load(fh)
    run_transition = schema_doc['$defs']['RunTransition']
    check('RunTransition enforcement status is WIRED',
          run_transition.get('x-enforcement-status') == 'WIRED')
    check('exact exception files are byte-pinned',
          set(validator.LEGACY_MANIFEST_SHA256) == set(legacy_paths))

    print('RESULT: %d passed, %d failed' % (PASS, FAIL))
    return 0 if FAIL == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
