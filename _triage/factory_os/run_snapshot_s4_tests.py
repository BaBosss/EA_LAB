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

import evidence as evd                 # noqa: E402
import snapshot_build as sb            # noqa: E402

NO_DERIVE = None  # bound in main() to sb.RECONCILIATION_NOT_DERIVED; see the C2c block
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


def real_scaffold(root, sources, recon=None, stale_bar=30):
    """A scaffold valid against the REAL repo root, whose canonical mandatory-source registry is
    pinned (F2). Fixtures that pass root=None -- because they want reconcile() to read the real
    boards -- must satisfy that registry, so the names go in here rather than being repeated at
    every call site."""
    inp = scaffold(root, sources, recon=recon, stale_bar=stale_bar)
    inp['meta']['mandatory_sources'] = sorted(
        set(inp['meta']['mandatory_sources']) | set(sb.MANDATORY_SOURCE_PATHS))
    return inp


def row(name, path, mandatory=True, **claims):
    r = {'name': name, 'path': path, 'mandatory': mandatory,
         'read_ok': None, 'sha256': None, 'mtime': None, 'age_hours': None, 'fresh': None}
    r.update(claims)
    return r


def main():
    global NO_DERIVE
    NO_DERIVE = sb.RECONCILIATION_NOT_DERIVED
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
                                schema_validator=gate, reconciler=NO_DERIVE)
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
                    root=root, schema_validator=gate, reconciler=NO_DERIVE),
                "claims True but the file at 'nope.txt' is False")
        refuses('C4 NEG a builder claiming a sha256 the file does not have is REFUSED',
                lambda: sb.build_document(
                    scaffold(root, [row('srcA', 'srcA.txt', sha256='0' * 64)]),
                    root=root, schema_validator=gate, reconciler=NO_DERIVE),
                'sha256 claims')
        refuses('C4 NEG a builder claiming an mtime the file does not have is REFUSED',
                lambda: sb.build_document(
                    scaffold(root, [row('srcA', 'srcA.txt', mtime='2099-01-01T00:00:00')]),
                    root=root, schema_validator=gate, reconciler=NO_DERIVE),
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
                    root=root, schema_validator=gate, reconciler=NO_DERIVE),
                'fresh claims True')
        stale_doc = sb.build_document(
            scaffold(root, [row('srcOld', 'srcOld.txt')], stale_bar=30),
            root=root, schema_validator=gate, reconciler=NO_DERIVE)
        check('C4 SPECIFICITY the same row with NO claim derives fresh=false and says STALE',
              stale_doc['meta']['sources'][0]['fresh'] is False
              and ('MANDATORY_SOURCE_STALE', 'srcOld')
              in [(x['code'], x['detail']) for x in stale_doc['verdict']['reasons']],
              json.dumps(stale_doc['verdict']))
        refuses('C4 NEG a source row with NO path is REFUSED, not skipped',
                lambda: sb.build_document(
                    scaffold(root, [{'name': 'srcA', 'mandatory': True}]),
                    root=root, schema_validator=gate, reconciler=NO_DERIVE),
                'no usable `path`')
        refuses('C4 NEG an ABSOLUTE source path is REFUSED',
                lambda: sb.build_document(
                    scaffold(root, [row('srcA', os.path.join(root, 'srcA.txt'))]),
                    root=root, schema_validator=gate, reconciler=NO_DERIVE),
                'is absolute')
        refuses('C4 NEG a source path escaping the repo root is REFUSED',
                lambda: sb.build_document(
                    scaffold(root, [row('srcA', os.path.join('..', 'srcA.txt'))]),
                    root=root, schema_validator=gate, reconciler=NO_DERIVE),
                'is outside the repository root')

        # SPECIFICITY, per memory `gate-specificity-not-just-sensitivity`: a deriver that refused
        # EVERY claim would pass all seven negatives above and be useless. A claim that MATCHES
        # the disk must be accepted.
        ok_doc = sb.build_document(
            scaffold(root, [row('srcA', 'srcA.txt', read_ok=True, sha256=real_sha)]),
            root=root, schema_validator=gate, reconciler=NO_DERIVE)
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
                               root=root, schema_validator=gate, reconciler=NO_DERIVE)
        check('C2 seeded 10 discovered / 10 categorized / sums matching => clear',
              d2['verdict']['reconciliation_clear'] is True,
              json.dumps(d2['verdict']))

        dropped = copy.deepcopy(seeded)
        dropped['categorized'] = 9
        dropped['categories']['completed'] = 4
        d3 = sb.build_document(scaffold(root, [row('srcA', 'srcA.txt')], recon=dropped),
                               root=root, schema_validator=gate, reconciler=NO_DERIVE)
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
                               root=root, schema_validator=gate, reconciler=NO_DERIVE)
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
        # Archive headers preserve historical phrases such as "was `OPEN`" after the current
        # `REVIEWED(...)` status. The archive parser must keep the first known status, while the
        # active-board parser retains its conservative non-terminal precedence rule.
        history_header = ('## ORDER-521 -- `EA_BREAKOUT_XAU` -- '
                          '`REVIEWED(Claude/Opus 2026-07-28)` -- was `OPEN`')
        check('C2b archive status uses the current first status, not historical was-OPEN text',
              sb._order_rows(history_header, archive=True)[0][1] == 'REVIEWED',
              repr(sb._order_rows(history_header, archive=True)))
        check('C2b active status still prefers an explicit non-terminal mention',
              sb._order_rows(history_header, archive=False)[0][1] == 'OPEN',
              repr(sb._order_rows(history_header, archive=False)))
        # ROUND-2 FINDING, fixtured. reconcile() read 2 of the 5 taskboard-shaped files in the
        # repo root; the other 3 were invisible to `discovered`. They carry ZERO order headers
        # today (measured), so the count was not wrong -- it was UNGUARDED, and two of the three
        # say in their own headers that claim/status rules match the main board, so an order
        # landing in one is a normal thing to do. The list is a declaration now and the FILESYSTEM
        # decides whether it is complete, which is run_guard_shape_lint's L0 pattern.
        boards = tempfile.mkdtemp(prefix='s4boards_')
        try:
            for rel in sb.TASKBOARDS:
                with io.open(os.path.join(boards, rel), 'w', encoding='utf-8') as fh:
                    fh.write('## ORDER-001 -- x `OPEN`\n')
            os.makedirs(os.path.join(boards, 'factory'))
            with io.open(os.path.join(boards, 'factory', 'coverage.jsonl'), 'w') as fh:
                fh.write('')
            base = sb.reconcile(root=boards)
            check('C2d CONTROL a root with only the declared boards reconciles',
                  base['discovered'] == 2, json.dumps(base))
            with io.open(os.path.join(boards, 'SIDE_TASKBOARD.md'), 'w', encoding='utf-8') as fh:
                fh.write('## ORDER-999 -- work nobody counted `OPEN`\n')
            refuses('C2d NEG an UNDECLARED taskboard carrying orders is REFUSED, not skipped',
                    lambda: sb.reconcile(root=boards),
                    'is in neither TASKBOARDS nor TASKBOARDS_NOT_READ')
            os.remove(os.path.join(boards, 'SIDE_TASKBOARD.md'))
            # ...and a board declared NOT READ *because it is empty* that has acquired orders.
            declared = sorted(sb.TASKBOARDS_NOT_READ)[0]
            with io.open(os.path.join(boards, declared), 'w', encoding='utf-8') as fh:
                fh.write('## ORDER-998 -- work on an excluded board `OPEN`\n')
            refuses('C2d NEG a NOT-READ board whose emptiness premise expired is REFUSED',
                    lambda: sb.reconcile(root=boards),
                    'is declared NOT READ on the grounds that it holds no orders')
            # SPECIFICITY: the same board, EMPTY, must NOT be refused -- otherwise the exclusion
            # list would be useless and the check would just be "any extra file is fatal".
            with io.open(os.path.join(boards, declared), 'w', encoding='utf-8') as fh:
                fh.write('# a declared, empty, excluded board\n')
            again = sb.reconcile(root=boards)
            check('C2d SPECIFICITY a declared NOT-READ board with no orders is fine',
                  again['discovered'] == 2, json.dumps(again))
        finally:
            shutil.rmtree(boards, ignore_errors=True)

        empty = tempfile.mkdtemp(prefix='s4empty_')
        try:
            refuses('C2b NEG a MISSING taskboard is refused, never counted as zero orders',
                    lambda: sb.reconcile(root=empty),
                    'is not present, and an absent board is not the same fact')
        finally:
            shutil.rmtree(empty, ignore_errors=True)

        print("\n--- C2c: the reconciliation counts are DERIVED, not claimed (round-1 finding) ---")
        # FOUND BY PROBING, not by reading: before this, a builder input declaring `discovered: 0`
        # and every other count 0 was ACCEPTED and produced reconciliation_clear=true, while the
        # real boards reconcile to discovered=312 / unclassified=30 / duplicates=6. The source rows
        # were authenticated and the arithmetic was not, and the arithmetic is the half that says
        # the work is finished.
        refuses('C2c NEG an all-zero reconciliation claim is REFUSED against the real boards',
                lambda: sb.build_document(real_scaffold(root, [row('srcA', 'srcA.txt')]),
                                          root=None, schema_validator=gate,
                                          reconciler=sb.reconcile),
                'does not match what the boards actually reconcile to')
        # SPECIFICITY: a deriver that refused every claim would pass the negative and be useless.
        truth = sb.reconcile()
        agreeing = sb.build_document(real_scaffold(root, [row('srcA', 'srcA.txt')], recon=truth),
                                     root=None, schema_validator=gate, reconciler=sb.reconcile)
        check('C2c SPECIFICITY a claim that AGREES with the boards is accepted',
              agreeing['meta']['reconciliation'] == truth)
        # An input that CLAIMS NOTHING gets the derived counts filled in -- which is what the
        # PowerShell writer now does, so it cannot claim at all.
        no_claim = real_scaffold(root, [row('srcA', 'srcA.txt')])
        del no_claim['meta']['reconciliation']
        filled = sb.build_document(no_claim, root=None, schema_validator=gate,
                                   reconciler=sb.reconcile)
        check('C2c an input that claims NOTHING is filled from the boards',
              filled['meta']['reconciliation'] == truth)
        # The sentinel must be a DECISION, not a default -- the schema gate's own rule.
        try:
            sb.build_document(scaffold(root, [row('srcA', 'srcA.txt')]), root=root,
                              schema_validator=gate)
            check('C2c NEG omitting `reconciler` raises rather than defaulting', False,
                  'it was accepted')
        except TypeError as exc:
            check('C2c NEG omitting `reconciler` raises rather than defaulting',
                  'no default' in str(exc), str(exc)[:120])
        try:
            sb.build_document(scaffold(root, [row('srcA', 'srcA.txt')]), root=root,
                              schema_validator=gate, reconciler=lambda **k: {})
            check('C2c NEG an arbitrary callable is refused, like the schema gate', False,
                  'a lambda was accepted')
        except TypeError:
            check('C2c NEG an arbitrary callable is refused, like the schema gate', True)

        print("\n--- FABLE REVIEW (round 5) ---")
        # F2: S6 pinned name->path and left the builder choosing WHICH NAMES COUNT.
        # Driven against the REAL repo root, because that is the only tree the canonical set
        # describes -- and because scoping it there was the repair's own second defect.
        shrunk = scaffold(root, [row('live_dashboard', 'portfolio/LIVE_DASHBOARD.html')])
        shrunk['meta']['mandatory_sources'] = ['live_dashboard']
        refuses('AUDIT F2 a builder input that omits a canonical mandatory source is REFUSED '
                '(probed: shrinking the registry to one name BUILT CLEAN, deleting two of three '
                'fleet sensors with no reason code)',
                lambda: sb.build_document(shrunk, root=None, schema_validator=gate,
                                          reconciler=NO_DERIVE),
                'meta.mandatory_sources omits')
        check('AUDIT F2 SPECIFICITY the constraint does NOT fire for a different root -- the '
              'canonical names describe THIS repo, and the first version of this repair broke '
              'every synthetic fixture in the suite',
              sb.build_document(scaffold(root, [row('srcA', 'srcA.txt')]), root=root,
                                schema_validator=gate, reconciler=NO_DERIVE)['entity']
              == 'ControlRoomSnapshotV5')
        full = scaffold(root, [row('live_dashboard', 'portfolio/LIVE_DASHBOARD.html')])
        full['meta']['mandatory_sources'] = sorted(sb.MANDATORY_SOURCE_PATHS)
        ok_doc = sb.build_document(full, root=None, schema_validator=gate, reconciler=NO_DERIVE)
        check('AUDIT F2 SPECIFICITY a registry that CONTAINS them all still builds, and the '
              'missing ones are reported as MISSING rather than vanishing',
              sorted(set(x['detail'] for x in ok_doc['verdict']['reasons']
                         if x['code'] == 'MANDATORY_SOURCE_MISSING'))
              == sorted(set(sb.MANDATORY_SOURCE_PATHS) - {'live_dashboard'}),
              json.dumps(ok_doc['verdict']['reasons']))

        # F3: git_head was the last typed field, and it is hashed into build_id.
        lie = scaffold(root, [row('live_dashboard', 'portfolio/LIVE_DASHBOARD.html')])
        lie['meta']['mandatory_sources'] = sorted(sb.MANDATORY_SOURCE_PATHS)
        lie['meta']['git_head'] = 'deadbeef'
        refuses('AUDIT F3 a fabricated git_head is REFUSED (probed: accepted, persisted, and '
                'hashed into build_id, so "rebuilt" and "changed" became indistinguishable)',
                lambda: sb.build_document(lie, root=None, schema_validator=gate,
                                          reconciler=NO_DERIVE),
                'meta.git_head claims')
        nogit = tempfile.mkdtemp(prefix='s4nogit_')
        try:
            claim = scaffold(nogit, [row('srcA', 'srcA.txt')])
            claim['meta']['mandatory_sources'] = ['srcA']
            claim['meta']['git_head'] = 'abc1234'
            refuses('AUDIT F3 a git_head claim that CANNOT be checked is refused, not trusted',
                    lambda: sb.build_document(claim, root=nogit, schema_validator=gate,
                                              reconciler=NO_DERIVE),
                    'cannot be checked')
            silent = scaffold(nogit, [row('srcA', 'srcA.txt')])
            silent['meta']['mandatory_sources'] = ['srcA']
            built = sb.build_document(silent, root=nogit, schema_validator=gate,
                                      reconciler=NO_DERIVE)
            check('AUDIT F3 SPECIFICITY an input that CLAIMS no git_head is fine outside a repo',
                  built['meta'].get('git_head') in (None, ''), repr(built['meta'].get('git_head')))
        finally:
            shutil.rmtree(nogit, ignore_errors=True)

        print("\n--- BLIND AUDIT ROUND 4 ---")
        import inspect as _i
        rs = _i.getsource(sb._resolve)
        se = _i.getsource(sb._stat_evidence)
        bf = _i.getsource(sb.build_file)
        # S1: precedence, not position. A title that MENTIONS a status must not beat the status.
        check('AUDIT S1 a title mentioning DONE does not beat a status of OPEN '
              '(probed: it did -- a title could hide actionable work)',
              sb._order_rows('## ORDER-X -- title mentions `DONE` -- `OPEN`'
                             + chr(10))[0][1] == 'OPEN')
        check('AUDIT S1 and the round-3 case still holds -- inline code loses to the real status',
              sb._order_rows('## ORDER-546 -- [EXP] `(EXP)_x` -- `REVIEWED(C)`'
                             + chr(10))[0][1] == 'REVIEWED')
        check('AUDIT S1 the two ranks are DERIVED from STATUS_CATEGORY, not a second vocabulary',
              sb.NON_TERMINAL_VERBS | sb.TERMINAL_VERBS == set(sb.STATUS_CATEGORY))
        # S2: temp names must be invocation-unique.
        check('AUDIT S2 the output temp name carries pid + a random suffix '
              '(probed: two concurrent builds collided -- JSONDecodeError, FileNotFoundError, '
              'and a sharing violation)',
              'os.getpid()' in bf and 'uuid.uuid4()' in bf)
        # S3: an in-place rewrite during the read must be DETECTED.
        #
        # ORDER-670, T5: `_stat_evidence` no longer stats the file itself -- it reads through
        # `evidence.observe()`, which OWNS the one-handle/two-fstat mechanism this case names (T5
        # collapsed a second implementation of the same rule rather than accepting one). So the
        # source-string check moves to `observe`'s source, and gains a companion: `_stat_evidence`
        # must actually CALL it rather than merely importing the module, or the collapse is a
        # rename with the vulnerability still reachable underneath.
        oe = _i.getsource(evd.observe)
        check('AUDIT S3 the file is fstat-ed BEFORE and AFTER the read and a change is REFUSED '
              '(probed: one handle stopped path replacement, not in-place mutation)',
              'before = os.fstat' in oe and 'after = os.fstat' in oe
              and 'st_mtime_ns' in oe)
        check('AUDIT S3/T5 `_stat_evidence` reaches that mechanism THROUGH observe(), rather than '
              're-deriving it (probed: a second implementation is a second place to fix the bug)',
              'evd.observe(' in se and 'os.fstat(fh.fileno())' not in se)

        # BEHAVIOURAL, not just textual: drive the actual race rather than trust the source
        # match. Neither this suite nor evidence.py's own had ever exercised observe()'s refusal
        # against a real mid-read mutation before this migration -- GUARD_SHAPES shape 3 ("have I
        # seen this red, for this reason?") applied to the fixture that is supposed to prove S3.
        # `os.fstat` is patched to answer differently on its second call, which is the exact
        # shape a file rewritten between `fh.read()` and the second fstat produces; it is scoped
        # to snapshot_build's own os reference and restored in `finally` no matter what.
        s3 = tempfile.mkdtemp(prefix='s4race_')
        try:
            fp = os.path.join(s3, 'f.txt')
            with io.open(fp, 'wb') as fh:
                fh.write(b'ORIGINAL')
            _real_fstat = sb.os.fstat
            _calls = [0]

            def _flaky_fstat(fd):
                _calls[0] += 1
                st = _real_fstat(fd)
                if _calls[0] == 2:
                    st = os.stat_result((st.st_mode, st.st_ino, st.st_dev, st.st_nlink,
                                         st.st_uid, st.st_gid, st.st_size + 1,
                                         st.st_atime_ns // 10**9, st.st_mtime_ns // 10**9 + 1,
                                         st.st_ctime_ns // 10**9))
                return st
            sb.os.fstat = _flaky_fstat
            try:
                ev = sb._stat_evidence(fp, datetime.datetime.now())
                raised = False
            except sv.SnapshotRefusal as exc:
                raised, msg = True, str(exc)
            finally:
                sb.os.fstat = _real_fstat
            check('AUDIT S3 BEHAVIOURAL a real mid-read fstat mismatch REFUSES through '
                  '_stat_evidence (not merely matched in source text)',
                  raised and 'modified while it was being read' in msg,
                  msg if raised else json.dumps(ev))

            # ITS PAIR, and the reason it exists: the first form of the observe() migration
            # collapsed observe's TWO failure modes into one handler, so a file that merely
            # could not be OPENED took the mid-read-mutation branch -- a hard build refusal,
            # with a message naming the wrong cause, where this function had always returned
            # read_ok=False for the registry join to report as MANDATORY_SOURCE_UNREADABLE.
            # ToolFailure is not an OSError, so the outer `except (IOError, OSError)` silently
            # stopped covering it. Without this case the regression is invisible: nothing else
            # in the suite drives an unreadable-but-present source.
            _real_open = evd.io.open

            def _deny(path, *a, **k):
                raise PermissionError(13, 'Permission denied', path)
            evd.io.open = _deny
            try:
                ev2 = sb._stat_evidence(fp, datetime.datetime.now())
                refused2 = False
            except sv.SnapshotRefusal as exc:
                refused2, ev2 = True, str(exc)
            finally:
                evd.io.open = _real_open
            check('AUDIT S3 SPECIFICITY an UNREADABLE (not mutated) source is still read_ok=False, '
                  'not a build refusal blaming a mid-read mutation',
                  (not refused2) and ev2.get('read_ok') is False and ev2.get('sha256') is None,
                  ev2 if refused2 else json.dumps(ev2))
        finally:
            shutil.rmtree(s3, ignore_errors=True)
        # S4: containment must be referential.
        check('AUDIT S4 containment uses realpath, so a junction out of the tree is caught '
              '(probed: a lexical prefix check accepted root/escape -> outside)',
              'os.path.realpath' in rs and 'os.path.abspath' not in rs)
        # S6: a logical name must be bound to a canonical physical path.
        bad_bind = scaffold(root, [row('deployments_inventory', 'srcA.txt')])
        refuses('AUDIT S6 a mandatory logical name pointed at the wrong file is REFUSED '
                '(probed: deployments_inventory -> an unrelated fresh file gave '
                'reconciliation_clear=true with no reasons)',
                lambda: sb.build_document(bad_bind, root=root, schema_validator=gate,
                                          reconciler=NO_DERIVE),
                'the canonical path for that logical name')
        check('AUDIT S6 SPECIFICITY an unlisted logical name is still unconstrained, so the '
              'binding is a declaration and not a whitelist of every source',
              'srcA' not in sb.MANDATORY_SOURCE_PATHS)
        # S8: freshness must not be decided after lossy rounding.
        prec = tempfile.mkdtemp(prefix='s4prec_')
        try:
            fp = os.path.join(prec, 'f.txt')
            with io.open(fp, 'w') as fh:
                fh.write('x')
            n0 = datetime.datetime.now()
            os.utime(fp, ((n0 - datetime.timedelta(hours=1.04)).timestamp(),) * 2)
            age = sb._stat_evidence(fp, n0)['age_hours']
            check('AUDIT S8 a real age of 1.04h survives storage and stays OVER a 1.0h bar '
                  '(probed: it was stored as 1.0 and compared FRESH)',
                  age > 1.0, 'stored %r' % age)
        finally:
            shutil.rmtree(prec, ignore_errors=True)

        print("\n--- BLIND AUDIT ROUND 3 ---")
        # P0: the hash and the mtime must describe the SAME open file.
        #
        # ORDER-670, T5: same collapse as S3 above -- the one-handle guarantee is `observe()`'s to
        # keep, and `_stat_evidence` is checked for calling it rather than re-deriving the fstat
        # pair itself.
        import inspect
        src = inspect.getsource(sb._stat_evidence)
        check('AUDIT P0 evidence comes from ONE open handle via evidence.observe(), not a second '
              'stat of the path (probed: hash of OLD bytes carried the mtime of NEW)',
              'evd.observe(' in src and 'os.path.getmtime(abs_path)' not in src
              and 'os.fstat(fh.fileno())' not in src)
        one = tempfile.mkdtemp(prefix='s4fs_')
        try:
            fp = os.path.join(one, 'f.txt')
            with io.open(fp, 'w') as fh:
                fh.write('CONTENT')
            ev = sb._stat_evidence(fp, datetime.datetime.now())
            check('AUDIT P0 SPECIFICITY and a normal file still derives a matching hash and mtime',
                  ev['read_ok'] is True
                  and ev['sha256'] == hashlib.sha256(b'CONTENT').hexdigest()
                  and ev['mtime'] is not None, json.dumps(ev))
        finally:
            shutil.rmtree(one, ignore_errors=True)

        # P1: a `_comment` on a REAL coverage row must not erase it. One rule, imported.
        er = tempfile.mkdtemp(prefix='s4er_')
        try:
            os.makedirs(os.path.join(er, 'factory'))
            for rel in sb.TASKBOARDS:
                with io.open(os.path.join(er, rel), 'w', encoding='utf-8') as fh:
                    fh.write('## ORDER-001 -- x `OPEN`' + chr(10))
            cov = os.path.join(er, 'factory', 'coverage.jsonl')
            with io.open(cov, 'w', encoding='utf-8') as fh:
                fh.write('{"cells": [{"cell": "EURUSD H1", "status": "UNVERIFIED_IMPORT"}]}' + chr(10))
            base = sb.reconcile(root=er)['coverage']
            check('AUDIT P1 CONTROL a plain coverage row counts', base['cells_in_universe'] == 1,
                  json.dumps(base))
            with io.open(cov, 'w', encoding='utf-8') as fh:
                fh.write('{"_comment": "x", "cells": [{"cell": "EURUSD H1", '
                         '"status": "UNVERIFIED_IMPORT"}]}' + chr(10))
            refuses('AUDIT P1 a `_comment` on a REAL coverage row is REFUSED as ambiguous, not '
                    'silently erased (probed: 1 cell became a 0/0/0 universe)',
                    lambda: sb.reconcile(root=er), 'ambiguous whether this is a row or a note')
            check('AUDIT P1 and the rule has ONE home -- reconcile calls registry.classify_record',
                  'reg.classify_record' in inspect.getsource(sb.reconcile))
        finally:
            shutil.rmtree(er, ignore_errors=True)

        # P2: freshness drives the verdict, so it belongs in build_id.
        f1 = {'meta': {'git_head': 'h', 'mandatory_sources': ['s'],
                       'sources': [{'name': 's', 'path': 'p', 'sha256': 'd', 'read_ok': True,
                                    'mtime': 't1', 'fresh': True}],
                       'reconciliation': {'x': 1}}}
        f2 = json.loads(json.dumps(f1))
        f2['meta']['sources'][0].update({'fresh': False, 'mtime': 't2'})
        check('AUDIT P2 build_id CHANGES between a fresh and a stale source (probed: same id '
              'while one verdict was clear and the other MANDATORY_SOURCE_STALE)',
              sb.compute_build_id(f1) != sb.compute_build_id(f2))
        check('AUDIT P2 and age_hours is deliberately NOT hashed, so the id stays stable across '
              'rebuilds of unchanged evidence',
              'age_hours' not in inspect.getsource(sb.compute_build_id).split('h.update')[-1])

        # P2: inline code in a title must not be read as the status.
        parsed = sb._order_rows('## ORDER-546 -- [EXP] `(EXP)_x` foo -- `REVIEWED(Claude)`' + chr(10))
        check('AUDIT P2 a title containing inline code resolves to the STATUS span, not the first '
              'uppercase span (probed: 11 live rows classified from a non-status span)',
              parsed[0][1] == 'REVIEWED', str(parsed))
        parsed2 = sb._order_rows('## ORDER-999 -- x `BUILT+CLOSED(x)`' + chr(10))
        check('AUDIT P2 SPECIFICITY a header with NO known status verb still falls back and lands '
              'in unclassified, rather than being dropped',
              parsed2[0][1] == 'BUILT' and sb.STATUS_CATEGORY.get(parsed2[0][1]) is None,
              str(parsed2))

        print("\n--- BLIND AUDIT ROUND 2 ---")
        # P2-6: build_id called itself "a digest over WHAT WAS READ" and did not hash the
        # reconciliation, so discovered=312 and discovered=0 produced the SAME id at the same head.
        a = {'meta': {'git_head': 'abc', 'mandatory_sources': ['s'],
                      'sources': [{'name': 's', 'path': 'p', 'sha256': 'd', 'read_ok': True}],
                      'reconciliation': {'discovered': 312}}}
        b = json.loads(json.dumps(a))
        b['meta']['reconciliation'] = {'discovered': 0}
        check('AUDIT P2-6 build_id CHANGES when the reconciliation changes (probed: it did not)',
              sb.compute_build_id(a) != sb.compute_build_id(b),
              '%s == %s' % (sb.compute_build_id(a), sb.compute_build_id(b)))
        c = json.loads(json.dumps(a))
        check('AUDIT P2-6 SPECIFICITY and it is STABLE for identical evidence, so it still tells '
              '"rebuilt" from "changed"', sb.compute_build_id(a) == sb.compute_build_id(c))

        # P1-8: a coverage store that parses but has the wrong SHAPE was reported as an empty
        # universe -- "readable but not understood" published as "there is nothing there".
        badcov = tempfile.mkdtemp(prefix='s4cov_')
        try:
            os.makedirs(os.path.join(badcov, 'factory'))
            for rel in sb.TASKBOARDS:
                with io.open(os.path.join(badcov, rel), 'w', encoding='utf-8') as fh:
                    fh.write('## ORDER-001 -- x `OPEN`' + chr(10))
            with io.open(os.path.join(badcov, 'factory', 'coverage.jsonl'), 'w',
                         encoding='utf-8') as fh:
                fh.write('{"_comment": "c"}' + chr(10) + '{"bogus": 1}' + chr(10))
            refuses('AUDIT P1-8 a coverage row with no `cells` is REFUSED, not counted as zero',
                    lambda: sb.reconcile(root=badcov), 'has no `cells` key')
            # SPECIFICITY: a real metadata line is still fine, and a real cell still counts.
            with io.open(os.path.join(badcov, 'factory', 'coverage.jsonl'), 'w',
                         encoding='utf-8') as fh:
                fh.write('{"_comment": "c"}' + chr(10)
                         + '{"cells": [{"cell": "EURUSD H1", "status": "LIVE"}]}' + chr(10))
            r = sb.reconcile(root=badcov)
            check('AUDIT P1-8 SPECIFICITY metadata is still skipped and a real cell still counts',
                  r['coverage']['cells_in_universe'] == 1 and r['coverage']['tested'] == 1,
                  json.dumps(r['coverage']))

            # ORDER-1250: the store now holds NATIVE CoverageCell rows too, and a native row IS
            # one cell rather than a container of them. Counted, not refused -- but the refusal
            # above had to be NARROWED to allow that, so these three cases exist to prove the
            # narrowing did not open it: a native row counts into its part, a native row whose
            # state is in no part is still REFUSED, and an unclassifiable row still is too.
            native = ('{"entity": "CoverageCell", "cell_id": "c1", '
                      '"hypothesis_revision": "B14-H01-r1", "logical_symbol": "XAUUSD", '
                      '"tf": "H1", "universe_version": "u", "state": "%s", "metrics": [], '
                      '"trial_count": 0}')
            with io.open(os.path.join(badcov, 'factory', 'coverage.jsonl'), 'w',
                         encoding='utf-8') as fh:
                fh.write('{"_comment": "c"}' + chr(10)
                         + '{"cells": [{"cell": "EURUSD H1", "status": "LIVE"}]}' + chr(10)
                         + (native % 'BASELINE_RUN') + chr(10)
                         + (native % 'NOT_APPLICABLE') + chr(10))
            r = sb.reconcile(root=badcov)
            check('ORDER-1250 a native CoverageCell counts as ONE cell, in the part its state names',
                  r['coverage']['cells_in_universe'] == 3 and r['coverage']['tested'] == 2
                  and r['coverage']['not_applicable'] == 1, json.dumps(r['coverage']))

            with io.open(os.path.join(badcov, 'factory', 'coverage.jsonl'), 'w',
                         encoding='utf-8') as fh:
                fh.write((native % 'SOMETHING_NEW') + chr(10))
            refuses('ORDER-1250 ATTACK a native cell in NO coverage part is REFUSED, not counted '
                    'into the universe and out of every part',
                    lambda: sb.reconcile(root=badcov), 'in no coverage part')

            with io.open(os.path.join(badcov, 'factory', 'coverage.jsonl'), 'w',
                         encoding='utf-8') as fh:
                fh.write('{"bogus": 1}' + chr(10))
            refuses('ORDER-1250 SPECIFICITY the original refusal still fires on a row that is '
                    'NEITHER shape', lambda: sb.reconcile(root=badcov), 'has no `cells` key')
        finally:
            shutil.rmtree(badcov, ignore_errors=True)

        # P2-10: the bucket named cancelled_by_user asserted an actor the board does not state.
        rows = sb._order_rows('## ORDER-1 -- x `CANCELLED(agent qwen 2026-07-01)`' + chr(10))
        check('AUDIT P2-10 a CANCELLED(agent ...) row does NOT land in cancelled_by_user',
              sb.STATUS_CATEGORY.get(rows[0][1]) is None, str(rows))
        check('AUDIT P2-10 and no verb at all maps into that bucket, so it cannot be filled by a '
              'guess', 'cancelled_by_user' not in set(sb.STATUS_CATEGORY.values()))

        print('\n--- C5: atomic build -> validate -> replace ---')
        out = os.path.join(root, 'snap.json')
        sb.build_file(_write(root, 'good.json', scaffold(root, [row('srcA', 'srcA.txt')])),
                      out, root=root, schema_validator=gate, reconciler=NO_DERIVE)
        before = io.open(out, 'rb').read()
        check('C5 a good build writes the canonical file', len(before) > 0)

        bad_in = _write(root, 'bad.json', scaffold(root, [row('srcA', 'gone.txt', read_ok=True)]))
        try:
            sb.build_file(bad_in, out, root=root, schema_validator=gate, reconciler=NO_DERIVE)
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
                    root=root, schema_validator=gate, reconciler=NO_DERIVE),
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
