# -*- coding: utf-8 -*-
"""run_snapshot_s4_tests.py -- ORDER-612 (slice S4) acceptance, C2 / C4 / C5 / C7.

C1 (the real snapshot validates) is asserted by run_schema_fixtures.py, where the line it flips
already lived. C3 and C6 are the READER half and are asserted by
scripts/_test/run_snapshot_s4_tests.ps1, because the readers are PowerShell.

EVERY CRITERION HERE HAS A NEGATIVE, and each negative asserts on the SPECIFIC refusal text or
reason code -- never merely that "something was rejected". A negative that only proves rejection
can be credited to a rule it never reached, which is how this repo's fixtures have passed before
while asserting nothing (see docs/GUARD_SHAPES.md, shape 3).

USAGE  tools\\python312\\python.exe _triage/factory_os/run_snapshot_s4_tests.py
"""
import copy
import datetime
import hashlib
import io
import json
import os
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import snapshot_build as sb            # noqa: E402
import snapshot_validator as sv        # noqa: E402

PASS = []
FAIL = []


def check(name, ok, detail=''):
    (PASS if ok else FAIL).append(name)
    print('  [%s] %s%s' % ('OK ' if ok else 'BAD', name, ('  -> ' + detail) if detail and not ok else ''))


def refuses(name, fn, must_contain):
    """Assert fn() raises SnapshotRefusal whose message CONTAINS must_contain."""
    try:
        fn()
    except sv.SnapshotRefusal as exc:
        if must_contain in str(exc):
            check(name, True)
        else:
            check(name, False, 'refused, but for a different reason: %s' % str(exc)[:160])
        return
    check(name, False, 'it was ACCEPTED')


def scaffold(root, sources, recon=None, stale_bar=30):
    return {
        'entity': 'SnapshotBuilderInput',
        'meta': {
            'schema': 'ControlRoomSnapshot',
            'version': 5,
            'generated_at': '2026-07-31T00:00:00',
            'stale_bar_hours': stale_bar,
            'mandatory_sources': [s['name'] for s in sources if s.get('mandatory')] or ['srcA'],
            'sources': sources,
            'reconciliation': recon or {
                'discovered': 0, 'categorized': 0,
                'categories': dict((k, 0) for k in sv.CATEGORY_KEYS),
                'duplicates': 0, 'conflicts': 0, 'unclassified': 0,
                'coverage': {'cells_in_universe': 0, 'tested': 0, 'untested': 0,
                             'not_applicable': 0},
            },
        },
        'system_health': [], 'floating_risk': [], 'deployments': {},
        'unknown_magics': [], 'attestation': [], 'judge_readiness': [],
        'judge_cohorts': [], 'summary': {},
    }


def row(name, path, mandatory=True, **claims):
    r = {'name': name, 'path': path, 'mandatory': mandatory,
         'read_ok': None, 'sha256': None, 'mtime': None, 'age_hours': None, 'fresh': None}
    r.update(claims)
    return r


def main():
    root = tempfile.mkdtemp(prefix='s4_')
    try:
        with io.open(os.path.join(root, 'srcA.txt'), 'w') as fh:
            fh.write('A')
        real_sha = hashlib.sha256(b'A').hexdigest()

        # NO_SCHEMA_CHECK everywhere below: the ajv gate is exercised by run_schema_fixtures.py
        # (89 cases) and costs a node subprocess per call. What is under test here is the
        # DERIVATION and the ATOMICITY, both of which are pure Python.
        gate = sv.NO_SCHEMA_CHECK

        print('\n--- C4: authenticity is DERIVED from the file on disk, never claimed ---')
        doc = sb.build_document(scaffold(root, [row('srcA', 'srcA.txt')]), root=root,
                                schema_validator=gate)
        r0 = doc['meta']['sources'][0]
        check('a row with no claims gets read_ok/sha256/mtime derived from the real file',
              r0['read_ok'] is True and r0['sha256'] == real_sha and r0['mtime'] is not None,
              json.dumps(r0))
        check('and `fresh` is derived, not carried', isinstance(r0['fresh'], bool))

        # THE NEGATIVE THE ORDER NAMES, VERBATIM: "a builder input asserting read_ok: true for a
        # file that does not exist => RED". This is Codex audit 6's surviving attack.
        refuses('C4 NEG a builder claiming read_ok=true for a file that does not exist is REFUSED',
                lambda: sb.build_document(
                    scaffold(root, [row('srcA', 'nope.txt', read_ok=True)]),
                    root=root, schema_validator=gate),
                "claims True but the file at 'nope.txt' is False")
        refuses('C4 NEG a builder claiming a sha256 the file does not have is REFUSED',
                lambda: sb.build_document(
                    scaffold(root, [row('srcA', 'srcA.txt', sha256='0' * 64)]),
                    root=root, schema_validator=gate),
                'sha256 claims')
        refuses('C4 NEG a builder claiming an mtime the file does not have is REFUSED',
                lambda: sb.build_document(
                    scaffold(root, [row('srcA', 'srcA.txt', mtime='2099-01-01T00:00:00')]),
                    root=root, schema_validator=gate),
                'mtime claims')
        # srcOld exists because the first version of this negative used `stale_bar=0` on a
        # just-created file -- and age 0.0 <= bar 0 is GENUINELY FRESH, so `fresh: true` was not a
        # lie and the case could not discriminate. It was OBSERVED passing-as-accepted before this
        # was fixed. A negative that cannot tell its two sides apart is not a negative
        # (memory: discriminating-test-must-be-able-to-discriminate).
        old_path = os.path.join(root, 'srcOld.txt')
        with io.open(old_path, 'w') as fh:
            fh.write('old')
        old_ts = (datetime.datetime.now() - datetime.timedelta(hours=100)).timestamp()
        os.utime(old_path, (old_ts, old_ts))
        derived_age = sb._stat_evidence(old_path, datetime.datetime.now())['age_hours']
        check('the stale fixture really is over the 30h bar (measured, not assumed)',
              derived_age > 30, 'age_hours=%r' % derived_age)
        refuses('C4 NEG a builder claiming fresh=true on an over-the-bar row is REFUSED',
                lambda: sb.build_document(
                    scaffold(root, [row('srcOld', 'srcOld.txt', fresh=True)], stale_bar=30),
                    root=root, schema_validator=gate),
                'fresh claims True')
        stale_doc = sb.build_document(
            scaffold(root, [row('srcOld', 'srcOld.txt')], stale_bar=30),
            root=root, schema_validator=gate)
        check('C4 SPECIFICITY the same row with NO claim derives fresh=false and says STALE',
              stale_doc['meta']['sources'][0]['fresh'] is False
              and ('MANDATORY_SOURCE_STALE', 'srcOld')
              in [(x['code'], x['detail']) for x in stale_doc['verdict']['reasons']],
              json.dumps(stale_doc['verdict']))
        refuses('C4 NEG a source row with NO path is REFUSED, not skipped',
                lambda: sb.build_document(
                    scaffold(root, [{'name': 'srcA', 'mandatory': True}]),
                    root=root, schema_validator=gate),
                'no usable `path`')
        refuses('C4 NEG an ABSOLUTE source path is REFUSED',
                lambda: sb.build_document(
                    scaffold(root, [row('srcA', os.path.join(root, 'srcA.txt'))]),
                    root=root, schema_validator=gate),
                'is absolute')
        refuses('C4 NEG a source path escaping the repo root is REFUSED',
                lambda: sb.build_document(
                    scaffold(root, [row('srcA', os.path.join('..', 'srcA.txt'))]),
                    root=root, schema_validator=gate),
                'escapes the repository root')

        # SPECIFICITY, per memory `gate-specificity-not-just-sensitivity`: a deriver that refused
        # EVERY claim would pass all seven negatives above and be useless. A claim that MATCHES
        # the disk must be accepted.
        ok_doc = sb.build_document(
            scaffold(root, [row('srcA', 'srcA.txt', read_ok=True, sha256=real_sha)]),
            root=root, schema_validator=gate)
        check('C4 SPECIFICITY a claim that AGREES with the disk is accepted, not refused',
              ok_doc['meta']['sources'][0]['sha256'] == real_sha)

        print('\n--- C7: version is 5, and 4 is refused ---')
        check('the built document is entity=ControlRoomSnapshotV5',
              doc['entity'] == 'ControlRoomSnapshotV5')
        check('meta.version is 5', doc['meta']['version'] == 5)
        # The version floor is a SCHEMA rule (`minimum: 5`), so the negative has to go through
        # ajv -- asserting it here without the gate would be a criterion that cannot fail.
        v4 = copy.deepcopy(doc)
        v4['meta']['version'] = 4
        refuses('C7 NEG version 4 is refused BY THE SCHEMA (4 is taken by the old writer)',
                lambda: sv.verify_snapshot(v4, sv.ajv_schema_validator),
                "minimum at '/meta/version'")

        print('\n--- C2: N discovered => exactly N categorized, or an explicit reason ---')
        seeded = {'discovered': 10, 'categorized': 10,
                  'categories': {'actionable': 0, 'running': 2, 'waiting': 3,
                                 'review_audit': 0, 'completed': 5, 'cancelled_by_user': 0},
                  'duplicates': 0, 'conflicts': 0, 'unclassified': 0,
                  'coverage': {'cells_in_universe': 4, 'tested': 1, 'untested': 2,
                               'not_applicable': 1}}
        d2 = sb.build_document(scaffold(root, [row('srcA', 'srcA.txt')], recon=seeded),
                               root=root, schema_validator=gate)
        check('C2 seeded 10 discovered / 10 categorized / sums matching => clear',
              d2['verdict']['reconciliation_clear'] is True,
              json.dumps(d2['verdict']))

        dropped = copy.deepcopy(seeded)
        dropped['categorized'] = 9
        dropped['categories']['completed'] = 4
        d3 = sb.build_document(scaffold(root, [row('srcA', 'srcA.txt')], recon=dropped),
                               root=root, schema_validator=gate)
        codes = [(x['code'], x['detail']) for x in d3['verdict']['reasons']]
        check('C2 NEG drop one categorized => NOT clear, naming BOTH numbers',
              d3['verdict']['reconciliation_clear'] is False
              and ('DISCOVERED_CATEGORIZED_MISMATCH', 'discovered=10 categorized=9') in codes,
              json.dumps(codes))

        unclass = copy.deepcopy(seeded)
        unclass['categorized'] = 9
        unclass['categories']['completed'] = 4
        unclass['unclassified'] = 1
        d4 = sb.build_document(scaffold(root, [row('srcA', 'srcA.txt')], recon=unclass),
                               root=root, schema_validator=gate)
        codes4 = [(x['code'], x['detail']) for x in d4['verdict']['reasons']]
        check('C2 the "or an explicit UNKNOWN" half: an unclassified item is NAMED, not absorbed',
              ('UNCLASSIFIED_PRESENT', 'unclassified=1') in codes4, json.dumps(codes4))

        print('\n--- C2b: the reconciliation producer reads real boards and refuses silence ---')
        rec = sb.reconcile()
        check('reconcile() over the real repo returns discovered > 0', rec['discovered'] > 0,
              json.dumps(rec))
        check('and categorized + unclassified == discovered (nothing is lost between them)',
              rec['categorized'] + rec['unclassified'] == rec['discovered'],
              '%d + %d != %d' % (rec['categorized'], rec['unclassified'], rec['discovered']))
        check('and the six category buckets sum to categorized',
              sum(rec['categories'].values()) == rec['categorized'])
        empty = tempfile.mkdtemp(prefix='s4empty_')
        try:
            refuses('C2b NEG a MISSING taskboard is refused, never counted as zero orders',
                    lambda: sb.reconcile(root=empty),
                    'is not present, and an absent board is not the same fact')
        finally:
            shutil.rmtree(empty, ignore_errors=True)

        print('\n--- C5: atomic build -> validate -> replace ---')
        out = os.path.join(root, 'snap.json')
        sb.build_file(_write(root, 'good.json', scaffold(root, [row('srcA', 'srcA.txt')])),
                      out, root=root, schema_validator=gate)
        before = io.open(out, 'rb').read()
        check('C5 a good build writes the canonical file', len(before) > 0)

        bad_in = _write(root, 'bad.json', scaffold(root, [row('srcA', 'gone.txt', read_ok=True)]))
        try:
            sb.build_file(bad_in, out, root=root, schema_validator=gate)
            check('C5 NEG a failing build must raise', False, 'it returned normally')
        except sv.SnapshotRefusal:
            check('C5 NEG a failing build raises', True)
        after = io.open(out, 'rb').read()
        check('C5 NEG and the previous file is BYTE-UNCHANGED (sha compared, not mtime)',
              hashlib.sha256(before).hexdigest() == hashlib.sha256(after).hexdigest())
        check('C5 NEG and no temp file is left behind',
              not any(f.startswith('.snap.json') for f in os.listdir(root)),
              str([f for f in os.listdir(root) if f.startswith('.')]))

        print('\n--- the supplied-answer scan still holds at the new entry point ---')
        refuses('a builder input carrying a nested `reconciliation_clear` is REFUSED',
                lambda: sb.build_document(
                    _poison(scaffold(root, [row('srcA', 'srcA.txt')])),
                    root=root, schema_validator=gate),
                'is present in a builder input')

        print('\n=== %d passed, %d failed ===' % (len(PASS), len(FAIL)))
        for f in FAIL:
            print('   FAILED: %s' % f)
        return 1 if FAIL else 0
    finally:
        shutil.rmtree(root, ignore_errors=True)


def _poison(inp):
    inp['meta']['reconciliation']['reconciliation_clear'] = True
    return inp


def _write(root, name, obj):
    path = os.path.join(root, name)
    with io.open(path, 'w', encoding='utf-8') as fh:
        json.dump(obj, fh)
    return path


if __name__ == '__main__':
    sys.exit(main())
