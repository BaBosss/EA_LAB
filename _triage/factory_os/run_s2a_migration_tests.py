"""
run_s2a_migration_tests.py - prove check_s2a_migration.py can REDDEN against the real D1.

WHY THIS EXISTS SEPARATELY FROM --self-test
  `--self-test` proves the checker refuses audit 5's *null migration* - a synthetic artifact built to
  be refused. It says nothing about whether the checker still bites against the file that was actually
  produced. Those are different claims, and this slice has already been burned by the difference twice
  in two days: `check_schema_structure.py` was CRASHING for four commits while in no suite, and three
  audit-6 fixes shipped with no fixture in the very commit whose message said a check that lives in
  shell history is not a check.

  So: every mutation below is applied to the REAL `s2a_migration.jsonl` / reconciliation on disk, and
  each must redden the criterion it targets BY NAME. A green D1 plus a checker that cannot fail on D1
  is not evidence of anything.

USAGE  tools\\python312\\python.exe _triage/factory_os/run_s2a_migration_tests.py
EXIT   0 = every mutation was caught and the control stayed green · 1 = otherwise
"""
import io
import json
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_s2a_migration as chk  # noqa: E402


def load_real():
    rows = [json.loads(l) for l in io.open(chk.MIGRATION_PATH, encoding='utf-8') if l.strip()]
    cov = json.load(io.open(chk.COVERAGE_PATH, encoding='utf-8'))
    return rows, cov


def run_all(rows, cov):
    """Run every criterion over an in-memory migration + a temp coverage file."""
    problems = []
    tracked = chk.tracked_paths() or set()
    chk.c1_entity_set(rows, problems)
    chk.c2_no_approved(rows, problems)
    chk.c3_owner_vocabulary(rows, problems, tracked)
    chk.c4_owner_ref_recomputed(rows, problems)
    chk.c5_refs_distinct(rows, problems)
    chk.c6_one_signoff_per_owner(rows, problems)
    chk.c7_coverage_edge(rows, problems)
    chk.c9_reversal_fields(rows, problems)
    saved = chk.COVERAGE_PATH
    fd, tmp = tempfile.mkstemp(suffix='.json')
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as fh:
            json.dump(cov, fh)
        chk.COVERAGE_PATH = tmp
        chk.c8_coverage_reconciled(problems)
    finally:
        chk.COVERAGE_PATH = saved
        try:
            os.unlink(tmp)
        except OSError:
            pass
    return '\n'.join(problems)


def find(rows, entity):
    for r in rows:
        if r['entity'] == entity:
            return r
    raise SystemExit('fixture drift: no row for %s' % entity)


# --------------------------------------------------------------------------- mutations
def m_bad_hash(rows, cov):
    r = find(rows, 'CoverageCell')
    d = r['owner_ref']['raw_sha256']
    r['owner_ref']['raw_sha256'] = ('0' if d[0] != '0' else '1') + d[1:]


def m_bad_blob(rows, cov):
    find(rows, 'CoverageCell')['owner_ref']['blob_oid'] = 'b' * 40


def m_unresolvable_path(rows, cov):
    # distinct from m_bad_blob: there the blob is comparable and MISMATCHES, here the path@commit
    # cannot be resolved at all. Two different branches of C4, and the first version of this suite
    # asserted the wrong one -- the mutation was caught, by the other branch, so a lazier expectation
    # ('C4' anywhere in the output) would have hidden that the unresolvable branch was never exercised.
    find(rows, 'CoverageCell')['owner_ref']['path'] = 'no/such/file/at/head.md'


def m_drop_coverage_edge(rows, cov):
    find(rows, 'CoverageCell')['proposed_owner'] = 'factory/hypotheses.jsonl'


def m_all_keep(rows, cov):
    for r in rows:
        r['disposition'] = 'KEEP'
        r.setdefault('keep_reason', 'x')


def m_approved(rows, cov):
    find(rows, 'CoverageCell')['signoff_state'] = 'APPROVED'


def m_two_signers(rows, cov):
    # ControlRoomSnapshotV5 and SystemFinding share portfolio/control_room_snapshot.json
    find(rows, 'SystemFinding')['signoff_owner'] = 'somebody else'


def m_drop_same_blob_reason(rows, cov):
    find(rows, 'SystemFinding').pop('same_blob_reason', None)
    find(rows, 'ControlRoomSnapshotV5').pop('same_blob_reason', None)


def m_schema_as_owner(rows, cov):
    find(rows, 'CoverageCell')['current_owner'] = '_triage/factory_os/schemas.json'


def m_owner_absent_at_head(rows, cov):
    # MEASURED 2026-07-31 (ORDER-630): this used to point at `factory/hypotheses.jsonl` on the
    # premise that the file does not exist. S5 created it, and the mutation went GREEN -- it was
    # asserting "C3 refuses an absent current_owner" using a path that had quietly become present.
    # A mutation whose premise expires stops discriminating without stopping running, which is the
    # same shape as a guard that keeps reporting after it stops being true.
    #
    # The path below is chosen to be UNCREATABLE rather than merely absent: it names a directory
    # the migration table does not propose, so no later slice can make it exist as a side effect.
    # C3's criterion is "a current_owner that does not exist is refused" -- which path exercises it
    # was always incidental, and tying it to a file the design plans to CREATE was the mistake.
    #
    # This file is NOT inside the attestation bundle (check_s2a_attestation.BUNDLE names
    # s2a_migration.jsonl, s2a_coverage_reconciliation.json, S2A_OWNERSHIP_MIGRATION.md,
    # gen_s2a_migration.py, check_s2a_migration.py and check_s2a_attestation.py), so repairing it
    # costs no signature. Checked before editing rather than assumed.
    find(rows, 'Hypothesis')['current_owner'] = '_triage/factory_os/no_such_owner_file.jsonl'


def m_undeclared_proposed(rows, cov):
    find(rows, 'Hypothesis')['proposed_owner'] = 'factory/hypothesees.jsonl'   # typo


def m_revert_the_commit(rows, cov):
    find(rows, 'CoverageCell')['reverse_steps'] = 'revert the commit'


def m_empty_retention(rows, cov):
    find(rows, 'CoverageCell')['retention_window'] = '   '


def m_drop_entity(rows, cov):
    rows.remove(find(rows, 'MetricRef'))


def m_embedded_wrong_parent(rows, cov):
    r = find(rows, 'MetricRef')
    r['current_owner'] = 'EMBEDDED:Hypothesis'
    r['proposed_owner'] = 'EMBEDDED:Hypothesis'


def m_embedded_star_one_parent(rows, cov):
    find(rows, 'OwnerRef')['embedded_in'] = ['CoverageCell']


def m_embedded_transfers(rows, cov):
    find(rows, 'MetricRef')['disposition'] = 'TRANSFER'


def m_unowned_no_evidence(rows, cov):
    find(rows, 'TestUniverse').pop('unowned_evidence', None)


def m_unowned_evidence_silent(rows, cov):
    find(rows, 'TestUniverse')['unowned_evidence'] = 'CLAUDE.md'


def m_state_swapped(rows, cov):
    """ORDER-602 B: the four owner states are not interchangeable.

    Before the taxonomy, all four were `UNOWNED` and shared one disposition rule, which is what made
    the escape wide enough for audit 7's attack. Swapping a row onto another state must now fail even
    though both states are legal values.
    """
    find(rows, 'TestUniverse')['current_owner'] = 'TRANSIENT'


def m_state_wrong_disposition(rows, cov):
    """NO_CURRENT_OWNER exists to ACQUIRE an owner, so it may not sit at KEEP."""
    r = find(rows, 'TestUniverse')
    r['disposition'] = 'KEEP'
    r['keep_reason'] = 'leave it'


def m_undeclared_entity_claims_unowned(rows, cov):
    """Codex audit 7's primitive, isolated: an entity helps itself to the UNOWNED exemption.

    This is the single-field form of the combined attack. It matters on its own because the closed
    UNOWNABLE list is now the only thing standing between one legitimate exemption and 27 of them.
    """
    r = find(rows, 'Hypothesis')
    r['current_owner'] = 'NO_CURRENT_OWNER'
    r['unowned_evidence'] = '_triage/EA_LAB_FACTORY_OS_DESIGN.md'
    r['owner_ref'] = None
    r['owner_ref_absent_reason'] = 'none'


def m_unowned_keep_canonical(rows, cov):
    r = find(rows, 'TestUniverse')
    r['disposition'] = 'KEEP'
    r['keep_reason'] = 'x'
    r['proposed_owner'] = 'NO_CURRENT_OWNER'


def m_decline_pin_with_a_reason(rows, cov):
    # /scrutinize: the one-line bypass of the order's strongest criterion. A row whose current_owner
    # is a real file at HEAD sets owner_ref to null and supplies any sentence. Before the fix this was
    # SILENT, so audit 5's null migration could have passed C4 by declining every pin instead of
    # faking every hash.
    r = find(rows, 'CoverageCell')
    r['owner_ref'] = None
    r['owner_ref_absent_reason'] = 'I would rather not'


def m_exempt_row_without_a_reason(rows, cov):
    # the other side of the same rule: EMBEDDED/UNOWNED rows ARE exempt, but must still say why.
    find(rows, 'TestUniverse').pop('owner_ref_absent_reason', None)


def m_refused_without_a_reason(rows, cov):
    r = find(rows, 'CoverageCell')
    r['signoff_state'] = 'REFUSED'
    r.pop('refused_reason', None)


def m_codex7_combined_attack(rows, cov):
    """Codex audit 7 BLOCKER 1, reproduced verbatim: the coordinated semantic bypass.

    Every mutation above this one is LOCAL -- it breaks a single field and expects a single criterion to
    fire. This one coordinates C2, C3, C4, C7, C8 and C9 at once, and the checker passed it with exit 0
    and all nine [OK]. That is the finding: 27 local mutations green does not imply the acceptance holds,
    and the 'UNOWNED is guarded' claim was true only in the weakest sense -- the guard opened a file.
    `schemas.json` DEFINES all 27 entities, so it contains every entity name, so it satisfied a substring
    test as 'evidence' that each of them is unowned.
    """
    for r in rows:
        # ORDER-602 B retired the single `UNOWNED` value, so the attack is re-aimed at the STRONGEST
        # surviving state. Left on the retired literal it would still go red -- but for the trivial
        # reason that the value no longer exists, which would quietly stop testing the escape it was
        # written for. A regression test that passes for the wrong reason is worse than none.
        r['current_owner'] = 'NO_CURRENT_OWNER'
        r['proposed_owner'] = 'NO_CURRENT_OWNER'
        r['disposition'] = 'KEEP'
        r['canonical_or_derived'] = 'derived'
        r['owner_ref'] = None
        r['owner_ref_absent_reason'] = 'none'
        r['unowned_evidence'] = '_triage/factory_os/schemas.json'
        r['keep_reason'] = 'leave everything where it is'
        r['signoff_state'] = 'REFUSED'
        r['refused_reason'] = 'no'
        r['signoff_owner'] = 'nobody'
        for k in ('breaks_if_moved', 'breaks_if_not_moved', 'reverse_steps', 'evidence_lost',
                  'retention_window'):
            r[k] = 'x'
        r.pop('same_blob_reason', None)
        r.pop('embedded_in', None)
    real = {r['entity']: r for r in load_real()[0]}
    cc = find(rows, 'CoverageCell')                       # keep the required edge...
    cc['current_owner'] = 'MASTER_BACKLOG.md'
    cc['proposed_owner'] = 'factory/coverage.jsonl'
    cc['owner_ref'] = real['CoverageCell']['owner_ref']
    cc.pop('unowned_evidence', None)
    orf = find(rows, 'OwnerRef')                          # ...one decoy transfer defeats all-KEEP
    orf['disposition'] = 'TRANSFER'
    orf['proposed_owner'] = 'factory/universe.jsonl'
    sec2 = chk.parse_section2()                           # ...and pad the mapping with junk
    mapping = [{'source_row': r['source_row'], 'cells': list(r['live_cells'])} for r in sec2]
    mapping[0]['cells'] += ['junk'] * 32
    cov['mapping'] = mapping
    cov['source_rows_consumed'] = len(mapping)
    cov['cells_emitted'] = sum(len(m['cells']) for m in mapping)


def m_cov_wrong_rowcount(rows, cov):
    cov['source_rows_consumed'] = 8


def m_cov_cells_too_small(rows, cov):
    cov['cells_emitted'] = 7
    cov['mapping'] = [{'source_row': m['source_row'], 'cells': m['cells'][:1]}
                      for m in cov['mapping']][:7]


def m_cov_drops_a_live_cell(rows, cov):
    for m in cov['mapping']:
        if m['source_row'] == 'ST_EA03 MACD':
            m['cells'] = [c for c in m['cells']
                          if not (isinstance(c, dict) and c.get('cell') == 'USDCAD H1')]
    cov['cells_emitted'] = sum(len(m['cells']) for m in cov['mapping'])


def m_cov_fabricated_live_cell(rows, cov):
    """/scrutinize ORDER-602 H6: claiming LIVE used to skip traceability entirely.

    The token check only applied to non-LIVE cells, and the LIVE-subset check proves the REAL live
    cells are present -- never that everything claiming LIVE is real. So a fabricated label wearing
    `status: LIVE` passed. Same shape as audit 7's blocker: one path closed, its twin left open.
    """
    for m in cov['mapping']:
        for c in m['cells']:
            if isinstance(c, dict) and c.get('status') == 'UNVERIFIED_IMPORT':
                c['status'] = 'LIVE'
                c['cell'] = 'TOTALLY MADE UP'
                return


def m_cov_unverified_without_coords(rows, cov):
    for m in cov['mapping']:
        for c in m['cells']:
            if isinstance(c, dict) and c.get('status') == 'UNVERIFIED_IMPORT':
                c.pop('source_coordinates', None)
                return


CASES = [
    ('C4  a single flipped sha256 digit',      m_bad_hash,                 'raw_sha256 MISMATCH'),
    ('C4  a plausible constant blob_oid',      m_bad_blob,                 'blob_oid MISMATCH'),
    ('C4  an owner_ref path absent at HEAD',   m_unresolvable_path,        'does not resolve'),
    ('C7  the Coverage edge removed',          m_drop_coverage_edge,       'Coverage edge row is ABSENT'),
    ('C7  every row flipped to KEEP',          m_all_keep,                 'null migration'),
    ('C2  one row signed APPROVED',            m_approved,                 'APPROVED'),
    ('C6  two signers for one owner file',     m_two_signers,              'different signers'),
    ('C5  same blob, reason removed',          m_drop_same_blob_reason,    'same_blob_reason'),
    ('C3  schemas.json as current_owner',      m_schema_as_owner,          'does not own it'),
    ('C3  current_owner absent at HEAD',       m_owner_absent_at_head,     'does not exist at HEAD'),
    ('C3  proposed_owner typo, undeclared',    m_undeclared_proposed,      'PLANNED_PATHS'),
    ('C9  reverse_steps = revert the commit',  m_revert_the_commit,        'not being executable steps'),
    ('C9  an emptied retention_window',        m_empty_retention,          'empty retention_window'),
    ('C1  one entity row deleted',             m_drop_entity,              'no migration row'),
    ('C3  EMBEDDED names a false parent',      m_embedded_wrong_parent,    'does not reference'),
    ('C3  EMBEDDED:* down to one parent',      m_embedded_star_one_parent, 'at least 2'),
    ('C3  an EMBEDDED row set to TRANSFER',    m_embedded_transfers,       'owns no'),
    ('C3  UNOWNED with its citation removed',  m_unowned_no_evidence,      'declared evidence is'),
    ('C3  UNOWNED citing the wrong file',      m_unowned_evidence_silent,  'declared evidence is'),
    ('C3  an undeclared entity claims UNOWNED', m_undeclared_entity_claims_unowned,
                                                                           'not declared UNOWNABLE'),
    ('602B a row swapped onto another state',  m_state_swapped,            'its declared state is'),
    ('602B NO_CURRENT_OWNER sitting at KEEP',  m_state_wrong_disposition,  'that state allows only'),
    ('C3  an acquiring state as its own dest',  m_unowned_keep_canonical,   'proposes nothing'),
    ('AUDIT7 the combined semantic attack',    m_codex7_combined_attack,   'not declared UNOWNABLE'),
    ('C4  a real owner declines its pin',      m_decline_pin_with_a_reason, 'no reason string buys'),
    ('C4  an exempt row states no reason',     m_exempt_row_without_a_reason, 'states no owner_ref_absent'),
    ('C2  REFUSED with no refused_reason',     m_refused_without_a_reason,  'does not close the question'),
    ('C8  source_rows_consumed inflated',      m_cov_wrong_rowcount,       'every source row must be'),
    ('C8  cells_emitted below the LIVE count', m_cov_cells_too_small,      'cannot be smaller'),
    ('C8  a LIVE cell dropped from mapping',   m_cov_drops_a_live_cell,    'omits its LIVE cell'),
    ('C8  a fabricated cell relabelled LIVE',  m_cov_fabricated_live_cell, 'cannot mark itself LIVE'),
    ('C8  UNVERIFIED_IMPORT with no coords',   m_cov_unverified_without_coords, 'no source_coordinates'),
]


def main():
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    os.chdir(root)
    if not os.path.exists(chk.MIGRATION_PATH):
        print('[ABORT] %s does not exist; this suite tests the REAL D1, not a fixture.'
              % chk.MIGRATION_PATH)
        return 2

    print('=== CONTROL: the real D1 must be GREEN, or every mutation below proves nothing ===')
    rows, cov = load_real()
    control = run_all(rows, cov)
    if control:
        print('  [BAD] the unmutated D1 is already red:')
        for line in control.split('\n')[:6]:
            print('     -> %s' % line)
        return 1
    print('  [OK ] %d rows, all nine criteria silent\n' % len(rows))

    print('=== %d MUTATIONS, each must redden its own criterion by name ===' % len(CASES))
    bad = 0
    for label, mutate, expect in CASES:
        rows, cov = load_real()          # fresh copy per case: no mutation may leak into the next
        mutate(rows, cov)
        blob = run_all(rows, cov)
        ok = expect in blob
        print('  [%s] %-40s expect=RED got=%s' % ('OK ' if ok else 'BAD', label,
                                                  'RED ' if blob else 'GREEN'))
        if not ok:
            bad += 1
            print('        -> wanted %r; got: %s' % (expect, (blob.split('\n')[0] if blob
                                                              else 'NOTHING AT ALL')))
    if bad:
        print('\n=== %d MUTATION(S) NOT CAUGHT ===' % bad)
        return 1

    bad += advisory_part()
    bad += structural_part()
    bad += drift_guard_part()
    if bad:
        return 1
    print('\n=== ALL %d MUTATIONS CAUGHT, CONTROLS GREEN; ADVISORY, LOADER AND DRIFT GUARD ALL '
          'PROVEN BOTH WAYS ===' % len(CASES))
    return 0


def advisory_part():
    """PART 4: the pin-vintage advisory must speak up, and must stay quiet when there is no news.

    It is an ADVISORY, so it cannot be covered by the mutation loop (which asserts failures). But an
    advisory nobody tests is worse than a missing one: it reads as "checked and clean" on every run
    while being incapable of saying anything.
    """
    print('\n=== PART 4: the pin-vintage advisory, both directions ===')
    rows, _ = load_real()
    bad = 0

    # CONTROL, built to be state-INDEPENDENT. The first version asserted "the real D1 produces no
    # notes", which failed the moment a commit touched AGENT_TASKBOARD.md -- a file two rows pin and
    # that changes on every order update. That is the SAME HEAD-tracking false alarm fixed in
    # gen_s2a_migration.py, reintroduced one layer up in the test: a legitimate, expected repo state
    # was being treated as a defect. A pinned owner going stale is exactly what the advisory exists
    # to REPORT, so it must never be what the suite FAILS on.
    # So the control is synthesised: a row pinned at the blob HEAD actually has right now must draw
    # no note, whatever else is true of the repo.
    probe_path = 'MASTER_BACKLOG.md'
    live_blob = os.popen('git rev-parse HEAD:%s' % probe_path).read().strip()
    current_row = [{'entity': 'SyntheticCurrentRow',
                    'owner_ref': {'path': probe_path, 'commit_oid': 'HEAD',
                                  'blob_oid': live_blob, 'raw_sha256': 'x' * 64}}]
    quiet = chk.pin_vintage_notes(current_row)
    print('  [%s] CONTROL a row pinned at HEAD\'s actual blob for %s -> no note'
          % ('OK ' if not quiet else 'BAD', probe_path))
    if quiet:
        print('        -> unexpectedly said: %s' % quiet[:2])
        bad += 1
    # ...and report, without judging, whatever the real file currently says. This is INFORMATION, not
    # an assertion: a stale pin here is a legitimate state.
    live_notes = chk.pin_vintage_notes(rows)
    print('  [--- ] FYI the real D1 currently draws %d advisory note(s)%s'
          % (len(live_notes), (': ' + '; '.join(n['text'].split(' -- ')[0] for n in live_notes))
             if live_notes else ''))

    # A stale-but-valid pin: point a row at an OLDER blob of the same file that still resolves.
    # Found the DETERMINISTIC way -- walk the file's own revisions and take the first blob that
    # differs from what is pinned now. The first version of this case guessed `HEAD~3` and SKIPPED,
    # because MASTER_BACKLOG.md happened not to change in that range; a case that silently does not
    # run is the thing this whole suite exists to prevent, so it is built not to depend on luck.
    stale = [json.loads(json.dumps(r)) for r in rows]
    older = blob = None
    for row in stale:
        ref = row.get('owner_ref')
        if not ref:
            continue
        path = ref['path']
        revs = os.popen('git rev-list -n 40 HEAD -- "%s"' % path).read().split()
        for rev in revs:
            cand = os.popen('git rev-parse %s:"%s" 2>NUL' % (rev, path)).read().strip()
            if cand and len(cand) == 40 and cand != ref['blob_oid']:
                older, blob, victim = rev, cand, row
                break
        if older:
            break
    if older:
        victim['owner_ref']['commit_oid'] = older
        victim['owner_ref']['blob_oid'] = blob
        notes = chk.pin_vintage_notes(stale)
        ok = any(n['kind'] == 'STALE' for n in notes)
        print('  [%s] %s pinned at an older revision of %s -> reported'
              % ('OK ' if ok else 'BAD', victim['entity'], victim['owner_ref']['path']))
        if not ok:
            print('        -> said: %s' % (notes[:1] or ['NOTHING AT ALL']))
            bad += 1
    else:
        # Never report a pass that was not earned.
        print('  [BAD] could not construct a stale pin from any of the 14 pinned rows -- this case '
              'did not run, which is not the same as passing')
        bad += 1

    # a pin at a path that does not exist at HEAD
    gone = [json.loads(json.dumps(r)) for r in rows]
    find(gone, 'CoverageCell')['owner_ref']['path'] = 'deleted/owner.md'
    notes = chk.pin_vintage_notes(gone)
    ok = any(n['kind'] == 'MISSING' for n in notes)
    print('  [%s] a pin whose path is gone at HEAD -> reported' % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> said: %s' % (notes[:1] or ['NOTHING AT ALL']))
        bad += 1
    if bad:
        print('\n=== ADVISORY PART FAILED ===')
    return bad


def structural_part():
    """PART 3: the checks inside load_rows(), which PART 1 cannot reach.

    /scrutinize 2026-07-30 found these were enforced in production and tested by nothing. PART 1
    drives the nine criteria directly against in-memory rows, so it never executes the loader -- and
    the loader is where required-field, disposition and KEEP-reason validation lives. That is the same
    shape as this slice's two worst finds: check_schema_structure.py crashing for four commits while
    in no suite, and three audit-6 fixes shipping with no fixture. A rule nothing exercises is a rule
    that can rot silently.
    """
    print('\n=== PART 3: the loader\'s structural checks, which PART 1 never reaches ===')
    original = io.open(chk.MIGRATION_PATH, encoding='utf-8').read()
    rows = [json.loads(l) for l in original.split('\n') if l.strip()]

    def write_and_load(mutate, raw=None):
        saved = chk.MIGRATION_PATH
        fd, tmp = tempfile.mkstemp(suffix='.jsonl')
        try:
            if raw is not None:
                text = raw
            else:
                rs = [json.loads(json.dumps(r)) for r in rows]
                mutate(rs)
                text = ''.join(json.dumps(r, sort_keys=True) + '\n' for r in rs)
            with os.fdopen(fd, 'w', encoding='utf-8', newline='\n') as fh:
                fh.write(text)
            chk.MIGRATION_PATH = tmp
            _, problems = chk.load_rows()
            return '\n'.join(problems)
        finally:
            chk.MIGRATION_PATH = saved
            try:
                os.unlink(tmp)
            except OSError:
                pass

    def drop_field(rs):
        for r in rs:
            if r['entity'] == 'CoverageCell':
                del r['retention_window']

    def bad_disposition(rs):
        for r in rs:
            if r['entity'] == 'CoverageCell':
                r['disposition'] = 'MOVE'

    def keep_no_reason(rs):
        for r in rs:
            if r['entity'] == 'IdeaRef':
                r['disposition'] = 'KEEP'
                r.pop('keep_reason', None)

    cases = [
        ('a required field deleted', drop_field, None, 'is missing field(s)'),
        ('an invented disposition', bad_disposition, None, 'not one of'),
        ('KEEP with its reason removed', keep_no_reason, None, 'no keep_reason'),
        ('a line that is not valid JSON', None, '{"entity": broken\n', 'not valid JSON'),
        ('an entirely empty file', None, '', 'is empty'),
    ]
    bad = 0
    for label, mutate, raw, expect in cases:
        blob = write_and_load(mutate, raw)
        ok = expect in blob
        print('  [%s] %-34s expect=RED got=%s' % ('OK ' if ok else 'BAD', label,
                                                  'RED ' if blob else 'GREEN'))
        if not ok:
            bad += 1
            print('        -> wanted %r; got: %s'
                  % (expect, (blob.split('\n')[0] if blob else 'NOTHING AT ALL')))
    # CONTROL: the real file must load with no structural complaint at all.
    _, clean = chk.load_rows()
    print('  [%s] CONTROL the real D1 loads with no structural problem'
          % ('OK ' if not clean else 'BAD'))
    if clean:
        print('        -> %s' % clean[:2])
        bad += 1
    if io.open(chk.MIGRATION_PATH, encoding='utf-8').read() != original:
        print('  [BAD] this part modified the real D1')
        bad += 1
    if bad:
        print('\n=== STRUCTURAL PART FAILED ===')
    return bad


def drift_guard_part():
    """PART 2: the D1-vs-generator drift guard must be able to FAIL, and must not fail on an old pin.

    This part exists because of a defect I shipped and caught one commit later. `--check` used to
    regenerate against HEAD, so it reported STALE on every commit after the one that produced D1 --
    HEAD had moved, so every `commit_oid` differed. The fix was to honour the recorded pins. But
    loosening a guard is exactly how a guard becomes inert, so both directions are asserted here:

      NEGATIVE  a real change to a judgement field must still be reported STALE
      CONTROL   D1 pinned at an EARLIER commit than HEAD must stay OK -- which is the very case that
                used to fail, and which is true right now, since D1 is pinned one commit back
    """
    import gen_s2a_migration as gen
    print('\n=== PART 2: the drift guard, both directions ===')
    bad = 0
    head = os.popen('git rev-parse --short HEAD').read().strip()
    pinned = set()
    for line in io.open(chk.MIGRATION_PATH, encoding='utf-8'):
        if line.strip():
            o = json.loads(line)
            if o.get('owner_ref'):
                pinned.add(o['owner_ref']['commit_oid'][:8])

    rc = gen.main(['--check'])
    ok = rc == 0
    print('  [%s] CONTROL D1 pinned at %s while HEAD is %s -> still OK (a pin is a historical '
          'claim, not a HEAD tracker)' % ('OK ' if ok else 'BAD', ','.join(sorted(pinned)), head))
    if not ok:
        bad += 1

    # NEGATIVE: alter a judgement field on disk and require STALE.
    saved = chk.MIGRATION_PATH
    original = io.open(saved, encoding='utf-8').read()
    fd, tmp = tempfile.mkstemp(suffix='.jsonl')
    try:
        rows = [json.loads(l) for l in original.split('\n') if l.strip()]
        find(rows, 'CoverageCell')['breaks_if_moved'] = 'dashboard may break'   # audit 5's phrasing
        with os.fdopen(fd, 'w', encoding='utf-8', newline='\n') as fh:
            for r in rows:
                fh.write(json.dumps(r, ensure_ascii=True, sort_keys=True) + '\n')
        chk.MIGRATION_PATH = tmp
        rc = gen.main(['--check'])
        ok = rc != 0
        print('  [%s] NEGATIVE a judgement field rewritten -> reported STALE'
              % ('OK ' if ok else 'BAD'))
        if not ok:
            bad += 1
    finally:
        chk.MIGRATION_PATH = saved
        try:
            os.unlink(tmp)
        except OSError:
            pass
    # ORDER-731 review M4, both directions. build_rows must REFUSE an owner pinning two DISTINCT
    # paths (the sorted-first tie-break would decide enforcement by ASCII), and must keep
    # accepting the same-path duplication that legitimately exists (Hypothesis + WorkReceipt).
    dup = None
    for spec in gen.ROWS:
        if spec.get('entity') == 'CoverageCell':
            dup = dict(spec)
            break
    if dup is None:
        print('  [BAD] M4 probe could not find the CoverageCell spec in gen.ROWS')
        bad += 1
    else:
        dup['entity'] = 'M4Probe'
        dup.pop('ref_path', None)          # defaults to the owner => a SECOND distinct path
        dup.pop('ref_path_reason', None)
        saved_rows = gen.ROWS
        try:
            gen.ROWS = saved_rows + [dup]
            try:
                gen.build_rows()
                fired = False
            except SystemExit as exc:
                fired = 'M4' in str(exc) and 'MASTER_BACKLOG.md' in str(exc)
        finally:
            gen.ROWS = saved_rows
        print('  [%s] M4 NEGATIVE: an owner pinning two DISTINCT paths is REFUSED by build_rows'
              % ('OK ' if fired else 'BAD'))
        if not fired:
            bad += 1
        try:
            gen.build_rows()
            ok = True
        except SystemExit:
            ok = False
        print('  [%s] M4 CONTROL: the real table (same-path duplication only) still builds'
              % ('OK ' if ok else 'BAD'))
        if not ok:
            bad += 1
    # the real file must be byte-identical to how this part found it
    if io.open(saved, encoding='utf-8').read() != original:
        print('  [BAD] this suite modified the real D1 -- it must only ever read it')
        bad += 1
    if bad:
        print('\n=== DRIFT GUARD PART FAILED ===')
    return bad


if __name__ == '__main__':
    sys.exit(main())
