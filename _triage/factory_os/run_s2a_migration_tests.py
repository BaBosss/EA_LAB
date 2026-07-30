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
    find(rows, 'Hypothesis')['current_owner'] = 'factory/hypotheses.jsonl'


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


def m_unowned_keep_canonical(rows, cov):
    r = find(rows, 'TestUniverse')
    r['disposition'] = 'KEEP'
    r['keep_reason'] = 'x'
    r['proposed_owner'] = chk.UNOWNED


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
    ('C3  UNOWNED with its citation removed',  m_unowned_no_evidence,      'needs a citation'),
    ('C3  UNOWNED citing a silent file',       m_unowned_evidence_silent,  'never mentions'),
    ('C3  UNOWNED+KEEP on a canonical fact',   m_unowned_keep_canonical,   'must not be signable'),
    ('C8  source_rows_consumed inflated',      m_cov_wrong_rowcount,       'every source row must be'),
    ('C8  cells_emitted below the LIVE count', m_cov_cells_too_small,      'cannot be smaller'),
    ('C8  a LIVE cell dropped from mapping',   m_cov_drops_a_live_cell,    'omits its LIVE cell'),
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

    bad += drift_guard_part()
    if bad:
        return 1
    print('\n=== ALL %d MUTATIONS CAUGHT, CONTROL STAYED GREEN, DRIFT GUARD PROVEN BOTH WAYS ==='
          % len(CASES))
    return 0


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
    # the real file must be byte-identical to how this part found it
    if io.open(saved, encoding='utf-8').read() != original:
        print('  [BAD] this suite modified the real D1 -- it must only ever read it')
        bad += 1
    if bad:
        print('\n=== DRIFT GUARD PART FAILED ===')
    return bad


if __name__ == '__main__':
    sys.exit(main())
