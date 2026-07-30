"""
check_s2a_migration.py - ORDER-600 (S2a) deliverable D3: the checker.

WHY THIS EXISTS, AND WHY IT IS WRITTEN BEFORE THE DATA
  ORDER-600's own words: "A criterion with no line in this file is not acceptance; it is a wish."
  Codex audit 5 closed rev 1 of that order by constructing, for every criterion, the cheapest
  output that met the letter and defeated the purpose -- 27 rows named from `$defs`, a constant in
  every hash field, and no migration proposed at all. So this file is built FIRST, against no data,
  which means the data cannot be shaped to whatever the checker happened to accept. It refuses an
  empty file, and it refuses the null migration.

WHAT IT ASSERTS  (the nine MACHINE criteria of ORDER-600 rev 4, one function each)
  C1  entity set == the generated __STORAGE__ row set, by SET EQUALITY, read from the generator
  C2  zero rows with signoff_state == APPROVED
  C3  owner vocabulary: current_owner exists at HEAD; proposed_owner exists or is in PLANNED_PATHS
  C4  owner_ref is RECOMPUTED from git, not shaped: blob_oid and raw_sha256 both verified
  C5  owner_ref values distinct across rows unless same_blob_reason is given
  C6  exactly one sign-off row per distinct current_owner, each with a named signer
  C7  the Coverage edge row is present and explicit
  C8  coverage counting is RECONCILED: source_rows_consumed vs cells_emitted, mapped, not equated
  C9  reverse_steps / evidence_lost / retention_window non-empty on every row

TWO SPEC DECISIONS THIS FILE MAKES, both recorded rather than assumed
  1. The coverage reconciliation (C8) lives in a SEPARATE file, not as a row in the jsonl. It cannot
     be a row: C1 demands the entity set equal the __STORAGE__ set exactly, so a `__META__` entity
     would fail C1. Path: factory_os/s2a_coverage_reconciliation.json.
  2. `EMBEDDED:<Parent>` and a null `owner_ref` are legal only under the rev-4 amendment, and only
     with a stated reason. C4 still recomputes every ref that IS claimed.

NOT IN THE PRE-COMMIT TIER, AND MUST NOT BE UNTIL D1 EXISTS
  It exits 2 while `factory_os/s2a_migration.jsonl` is absent, which is correct behaviour and would
  make the fast tier permanently red. Wire it in the same commit that lands D1 -- and note the tier
  has zero headroom (median 14.8s of a 15.0s advisory budget), so it belongs in the existing
  `run_contract_binding_tests.ps1` python wrapper rather than as a new PowerShell suite. `--self-test`
  needs no data and can be run at any time; that is the mode that proves this file is not a wish.

USAGE  python _triage/factory_os/check_s2a_migration.py [--self-test]
EXIT   0 = every criterion holds · 1 = at least one does not · 2 = the inputs are missing
"""
import hashlib
import io
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_design_contracts as gen  # noqa: E402  -- C1 reads the entity set from the generator

MIGRATION_PATH = 'factory_os/s2a_migration.jsonl'
COVERAGE_PATH = 'factory_os/s2a_coverage_reconciliation.json'

REQUIRED_FIELDS = ('entity', 'current_owner', 'proposed_owner', 'disposition',
                   'canonical_or_derived', 'owner_ref', 'breaks_if_moved', 'breaks_if_not_moved',
                   'signoff_owner', 'signoff_state', 'reverse_steps', 'evidence_lost',
                   'retention_window')

DISPOSITIONS = ('TRANSFER', 'KEEP', 'RETIRE')
SIGNOFF_STATES = ('PROPOSED', 'REFUSED')          # APPROVED is the owner's act, not this order's

# ORDER-600 rev 4: a proposed_owner may name a file that does not exist yet -- 11 of the 27
# entities are in that position and the order forbids creating them -- but it must be a DECLARED
# future path, so a typo is still caught. Adding a line here is a reviewable act.
PLANNED_PATHS = (
    'factory/hypotheses.jsonl',
    'factory/parameter_bindings.jsonl',
    'factory/universe.jsonl',
    'factory/instrument_profiles.jsonl',
    'factory/coverage.jsonl',
    'factory/magic_allocations.jsonl',
    'factory/runs/',                  # per-run file, one per run_id
    'factory/candidates/',            # per-candidate file
    'ops/findings.jsonl',
    'ops/receipts/',
    'build/safe_projection.json',
)

COVERAGE_CURRENT_OWNER = 'MASTER_BACKLOG.md'
COVERAGE_PROPOSED_OWNER = 'factory/coverage.jsonl'


def fail(problems, msg):
    problems.append(msg)


def _git(*args):
    p = subprocess.run(('git',) + args, capture_output=True, text=True)
    return p.returncode, p.stdout.strip(), p.stderr.strip()


def tracked_paths():
    rc, out, _ = _git('ls-files')
    if rc != 0:
        return None
    return set(out.split('\n'))


def storage_entities():
    """C1's source of truth: the entities the generated __STORAGE__ block actually lists.

    Read from the schema through the generator rather than hardcoded. ORDER-600 says "do not
    hardcode 24" -- and the number is 27 today, which is exactly why hardcoding it would have
    silently drifted.
    """
    with io.open(gen.SCHEMA_PATH, encoding='utf-8') as fh:
        schema = json.load(fh)
    return set(k for k, v in schema['$defs'].items() if isinstance(v, dict))


# ---------------------------------------------------------------------------- criteria

def c1_entity_set(rows, problems):
    expected = storage_entities()
    got = [r.get('entity') for r in rows]
    dupes = sorted({e for e in got if got.count(e) > 1})
    if dupes:
        fail(problems, 'C1 duplicate entity rows: %s' % dupes)
    missing = sorted(expected - set(got))
    extra = sorted(set(got) - expected)
    if missing:
        fail(problems, 'C1 %d entity/entities in the schema have no migration row: %s'
             % (len(missing), missing))
    if extra:
        fail(problems, 'C1 row(s) for entities the schema does not define: %s' % extra)


def c2_no_approved(rows, problems):
    bad = [r.get('entity') for r in rows if r.get('signoff_state') == 'APPROVED']
    if bad:
        fail(problems, 'C2 %d row(s) write signoff_state=APPROVED, which is the owner\'s act in '
                       'their own commit, not this order\'s: %s' % (len(bad), bad))
    for r in rows:
        if r.get('signoff_state') not in SIGNOFF_STATES:
            fail(problems, 'C2 %s has signoff_state=%r, not one of %s'
                 % (r.get('entity'), r.get('signoff_state'), list(SIGNOFF_STATES)))


def c3_owner_vocabulary(rows, problems, tracked):
    for r in rows:
        e = r.get('entity')
        cur = r.get('current_owner') or ''
        prop = r.get('proposed_owner') or ''
        if cur.startswith('EMBEDDED:'):
            if r.get('disposition') != 'KEEP':
                fail(problems, 'C3 %s is EMBEDDED but disposition=%r; an embedded fact owns no '
                               'file to transfer' % (e, r.get('disposition')))
        elif cur not in tracked:
            fail(problems, 'C3 %s current_owner=%r does not exist at HEAD. current_owner is a '
                           'claim about TODAY.' % (e, cur))
        elif cur.endswith('schemas.json'):
            fail(problems, 'C3 %s names schemas.json as current_owner; the schema DESCRIBES the '
                           'fact, it does not own it' % e)
        if prop.startswith('EMBEDDED:'):
            continue
        if prop not in tracked and not any(prop.startswith(p) for p in PLANNED_PATHS):
            fail(problems, 'C3 %s proposed_owner=%r neither exists at HEAD nor appears in '
                           'PLANNED_PATHS -- declare it there if it is intended' % (e, prop))


def c4_owner_ref_recomputed(rows, problems):
    """The criterion the rev-1 order failed: a plausible constant must not pass."""
    for r in rows:
        e, ref = r.get('entity'), r.get('owner_ref')
        if ref is None:
            cur = r.get('current_owner') or ''
            if not (cur.startswith('EMBEDDED:') or r.get('owner_ref_absent_reason')):
                fail(problems, 'C4 %s declines an owner_ref without owner_ref_absent_reason' % e)
            continue
        for k in ('path', 'commit_oid', 'blob_oid', 'raw_sha256'):
            if not ref.get(k):
                fail(problems, 'C4 %s owner_ref is missing %s' % (e, k))
        if any(not ref.get(k) for k in ('path', 'commit_oid', 'blob_oid', 'raw_sha256')):
            continue
        spec = '%s:%s' % (ref['commit_oid'], ref['path'])
        rc, blob_oid, err = _git('rev-parse', spec)
        if rc != 0:
            fail(problems, 'C4 %s owner_ref does not resolve (%s): %s' % (e, spec, err[:70]))
            continue
        if blob_oid != ref['blob_oid']:
            fail(problems, 'C4 %s blob_oid MISMATCH for %s: stated %s, git says %s'
                 % (e, spec, ref['blob_oid'][:12], blob_oid[:12]))
        rc, _, _ = _git('cat-file', '-e', blob_oid)
        p = subprocess.run(['git', 'cat-file', 'blob', blob_oid], capture_output=True)
        if p.returncode != 0:
            fail(problems, 'C4 %s blob %s cannot be read' % (e, blob_oid[:12]))
            continue
        digest = hashlib.sha256(p.stdout).hexdigest()
        if digest != ref['raw_sha256']:
            fail(problems, 'C4 %s raw_sha256 MISMATCH for %s: stated %s, recomputed %s'
                 % (e, spec, ref['raw_sha256'][:12], digest[:12]))


def c5_refs_distinct(rows, problems):
    seen = {}
    for r in rows:
        ref = r.get('owner_ref')
        if not ref or not ref.get('blob_oid'):
            continue
        key = ref['blob_oid']
        if key in seen and not r.get('same_blob_reason'):
            fail(problems, 'C5 %s and %s pin the same blob with no same_blob_reason'
                 % (seen[key], r.get('entity')))
        seen.setdefault(key, r.get('entity'))


def c6_one_signoff_per_owner(rows, problems):
    by_owner = {}
    for r in rows:
        cur = r.get('current_owner') or ''
        if cur.startswith('EMBEDDED:'):
            continue
        by_owner.setdefault(cur, []).append(r)
    for owner, group in sorted(by_owner.items()):
        signers = sorted({(r.get('signoff_owner') or '').strip() for r in group})
        if '' in signers:
            fail(problems, 'C6 %s has row(s) with an empty signoff_owner: %s'
                 % (owner, [r.get('entity') for r in group if not (r.get('signoff_owner') or '').strip()]))
            signers = [s for s in signers if s]
        if len(signers) > 1:
            fail(problems, 'C6 %s has %d different signers across its rows (%s) -- exactly one '
                           'sign-off per distinct current_owner' % (owner, len(signers), signers))


def c7_coverage_edge(rows, problems):
    # The null-migration guard runs FIRST and outside any early return. Found by --self-test:
    # it used to sit after the `if not edge: return` below, so on the null migration -- the exact
    # artifact it was written for, which has no Coverage edge -- it never executed. The guard that
    # matters most was unreachable in the only case that matters most.
    if rows and all(r.get('disposition') == 'KEEP' for r in rows):
        fail(problems, 'C7 EVERY row is KEEP. That is the null migration audit 5 constructed; a '
                       'proposal that proposes nothing is not a proposal.')

    edge = [r for r in rows
            if (r.get('current_owner') or '').startswith(COVERAGE_CURRENT_OWNER)
            and r.get('proposed_owner') == COVERAGE_PROPOSED_OWNER]
    if not edge:
        fail(problems, 'C7 the Coverage edge row is ABSENT: no row moves %s (section 2) to %s. '
                       'Its absence fails the order -- rev 1 could omit the entire point.'
             % (COVERAGE_CURRENT_OWNER, COVERAGE_PROPOSED_OWNER))
        return
    for r in edge:
        if r.get('disposition') not in ('TRANSFER', 'KEEP'):
            fail(problems, 'C7 the Coverage edge row has disposition=%r, expected TRANSFER or KEEP'
                 % r.get('disposition'))
        if not (r.get('signoff_owner') or '').strip():
            fail(problems, 'C7 the Coverage edge row has no named signoff_owner')


def c8_coverage_reconciled(problems):
    if not os.path.exists(COVERAGE_PATH):
        fail(problems, 'C8 %s is missing: the two coverage numbers must be REPORTED with a '
                       'mapping, not asserted equal' % COVERAGE_PATH)
        return
    with io.open(COVERAGE_PATH, encoding='utf-8') as fh:
        cov = json.load(fh)
    for k in ('source_rows_consumed', 'cells_emitted', 'mapping'):
        if k not in cov:
            fail(problems, 'C8 %s has no %r' % (COVERAGE_PATH, k))
    if any(k not in cov for k in ('source_rows_consumed', 'cells_emitted', 'mapping')):
        return
    if cov['source_rows_consumed'] == cov['cells_emitted']:
        fail(problems, 'C8 source_rows_consumed == cells_emitted == %d. MEASURED 2026-07-30: '
                       'section 2 has 7 EA rows while the LIVE column alone holds 8 cells, because '
                       'ST_EA03 carries GBPUSD H1 AND USDCAD H1. Equal numbers mean the rows were '
                       'counted, not normalised.' % cov['source_rows_consumed'])
    mapped = sum(len(m.get('cells', [])) for m in cov['mapping'])
    if mapped != cov['cells_emitted']:
        fail(problems, 'C8 the mapping accounts for %d cells but cells_emitted is %d'
             % (mapped, cov['cells_emitted']))
    if len(cov['mapping']) != cov['source_rows_consumed']:
        fail(problems, 'C8 the mapping covers %d source rows but source_rows_consumed is %d -- '
                       'every source row must be consumed exactly once'
             % (len(cov['mapping']), cov['source_rows_consumed']))
    for m in cov['mapping']:
        for cell in m.get('cells', []):
            if cell.get('status') == 'UNVERIFIED_IMPORT' and not cell.get('source_coordinates'):
                fail(problems, 'C8 an UNVERIFIED_IMPORT cell carries no source_coordinates')


def c9_reversal_fields(rows, problems):
    for r in rows:
        for k in ('reverse_steps', 'evidence_lost', 'retention_window'):
            v = r.get(k)
            if not v or (isinstance(v, str) and not v.strip()):
                fail(problems, 'C9 %s has an empty %s' % (r.get('entity'), k))
        steps = r.get('reverse_steps')
        if isinstance(steps, str) and steps.strip().lower() in ('revert the commit', 'revert'):
            fail(problems, 'C9 %s reverse_steps is %r -- the order calls that out by name as not '
                           'being executable steps' % (r.get('entity'), steps))


def load_rows():
    if not os.path.exists(MIGRATION_PATH):
        return None, ['%s does not exist yet. This checker is deliberately written BEFORE the '
                      'data (ORDER-600 D3), so this is the expected state until D1 is produced.'
                      % MIGRATION_PATH]
    rows, problems = [], []
    with io.open(MIGRATION_PATH, encoding='utf-8') as fh:
        for n, line in enumerate(fh, 1):
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except ValueError as exc:
                problems.append('%s:%d is not valid JSON: %s' % (MIGRATION_PATH, n, exc))
                continue
            missing = [f for f in REQUIRED_FIELDS if f not in obj]
            if missing:
                problems.append('%s:%d (%s) is missing field(s): %s'
                                % (MIGRATION_PATH, n, obj.get('entity', '?'), missing))
            if obj.get('disposition') not in DISPOSITIONS:
                problems.append('%s:%d has disposition=%r, not one of %s'
                                % (MIGRATION_PATH, n, obj.get('disposition'), list(DISPOSITIONS)))
            if obj.get('disposition') == 'KEEP' and not (obj.get('keep_reason') or '').strip():
                problems.append('%s:%d is KEEP with no keep_reason -- KEEP is a visible choice '
                                'with a name on it, not a default' % (MIGRATION_PATH, n))
            rows.append(obj)
    if not rows and not problems:
        problems.append('%s is empty. An empty migration satisfies nothing.' % MIGRATION_PATH)
    return rows, problems


def self_test():
    """Rebuild audit 5's gaming artifact and assert this checker refuses it.

    A checker written before the data, and never run against data, is a wish with a shebang. So the
    null migration audit 5 constructed to close rev 1 is reconstructed here -- every entity named
    from $defs, schemas.json as the owner, a plausible constant in every hash field, every
    disposition KEEP, and no Coverage edge -- and each criterion that should fire is asserted BY
    NAME. A generic "it produced problems" would pass even if the wrong nine things broke.
    """
    print('=== self-test: does this checker refuse audit 5\'s null migration? ===')
    entities = sorted(storage_entities())
    null_migration = [{
        'entity': e,
        'current_owner': '_triage/factory_os/schemas.json',      # describes the fact, owns nothing
        'proposed_owner': '_triage/factory_os/schemas.json',
        'disposition': 'KEEP',                                    # ...for all 27
        'canonical_or_derived': 'canonical',
        'owner_ref': {'path': '_triage/factory_os/schemas.json',
                      'commit_oid': 'a' * 40, 'blob_oid': 'b' * 40, 'raw_sha256': 'c' * 64},
        'breaks_if_moved': 'dashboard may break',
        'breaks_if_not_moved': 'drift',
        'signoff_owner': '',
        'signoff_state': 'APPROVED',
        'reverse_steps': 'revert the commit',
        'evidence_lost': 'n/a',
        'retention_window': '30d',
    } for e in entities]

    problems = []
    tracked = tracked_paths() or set()
    c1_entity_set(null_migration, problems)
    c2_no_approved(null_migration, problems)
    c3_owner_vocabulary(null_migration, problems, tracked)
    c4_owner_ref_recomputed(null_migration, problems)
    c5_refs_distinct(null_migration, problems)
    c6_one_signoff_per_owner(null_migration, problems)
    c7_coverage_edge(null_migration, problems)
    c9_reversal_fields(null_migration, problems)

    blob = '\n'.join(problems)
    expected = [
        ('C2 APPROVED refused', 'C2 ' in blob and 'APPROVED' in blob),
        ('C3 schemas.json refused as owner', 'does not own it' in blob),
        ('C4 constant hash refused', 'C4 ' in blob and ('MISMATCH' in blob or 'does not resolve' in blob)),
        ('C5 identical blobs refused', 'same_blob_reason' in blob),
        ('C6 empty signer refused', 'empty signoff_owner' in blob),
        ('C7 missing Coverage edge refused', 'Coverage edge row is ABSENT' in blob),
        ('C7 all-KEEP refused', 'null migration' in blob),
        ('C9 "revert the commit" refused', 'not being executable steps' in blob),
    ]
    bad = 0
    for label, ok in expected:
        print('  [%s] %s' % ('OK ' if ok else 'BAD', label))
        if not ok:
            bad += 1
    # C1 must NOT fire: the null migration names every entity correctly. That is the whole point --
    # counting entity names was rev 1's only real check, and it passed.
    c1_fired = 'C1 ' in blob
    print('  [%s] C1 stays SILENT on the null migration (it names every entity, which is exactly '
          'why counting names was never enough)' % ('OK ' if not c1_fired else 'BAD'))
    if c1_fired:
        bad += 1
    print('\n  %d criteria checked, %d did not behave as declared' % (len(expected) + 1, bad))
    return 1 if bad else 0


def main(argv):
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    os.chdir(root)
    if '--self-test' in argv:
        return self_test()

    print('=== ORDER-600 (S2a) acceptance: the nine MACHINE criteria ===')
    print('migration: %s' % MIGRATION_PATH)
    print('coverage : %s\n' % COVERAGE_PATH)

    tracked = tracked_paths()
    if tracked is None:
        print('[ABORT] git ls-files failed, so no path claim could be checked. That is a tool')
        print('        failure, not a clean run -- exiting 2 rather than reporting success.')
        return 2

    rows, problems = load_rows()
    if rows is None:
        for p in problems:
            print('[PENDING] %s' % p)
        print('\n=== D1 NOT PRESENT - nothing asserted. This is exit 2, not exit 0: "no data" and')
        print('    "data that passes" must never share an exit code. ===')
        return 2

    print('  %d row(s) loaded, %d structural problem(s)\n' % (len(rows), len(problems)))
    for name, fn in (('C1 entity set == __STORAGE__ set', lambda: c1_entity_set(rows, problems)),
                     ('C2 no APPROVED signoff', lambda: c2_no_approved(rows, problems)),
                     ('C3 owner vocabulary / existence', lambda: c3_owner_vocabulary(rows, problems, tracked)),
                     ('C4 owner_ref recomputed from git', lambda: c4_owner_ref_recomputed(rows, problems)),
                     ('C5 owner_refs distinct', lambda: c5_refs_distinct(rows, problems)),
                     ('C6 one signer per current_owner', lambda: c6_one_signoff_per_owner(rows, problems)),
                     ('C7 Coverage edge present, not all-KEEP', lambda: c7_coverage_edge(rows, problems)),
                     ('C8 coverage counting reconciled', lambda: c8_coverage_reconciled(problems)),
                     ('C9 reversal fields non-empty', lambda: c9_reversal_fields(rows, problems))):
        before = len(problems)
        fn()
        added = len(problems) - before
        print('  [%s] %-42s %s' % ('OK ' if added == 0 else 'BAD', name,
                                   '' if added == 0 else '%d problem(s)' % added))

    if problems:
        print('')
        for p in problems:
            print('  -> %s' % p)
        print('\n=== %d PROBLEM(S) - ORDER-600 is not satisfied ===' % len(problems))
        return 1
    print('\n=== ALL NINE MACHINE CRITERIA HOLD ===')
    print('    NOTE: the HUMAN-REVIEW checklist in ORDER-600 is NOT checked here and cannot be.')
    print('    A green run means the table is well-formed and its hashes are real, not that the')
    print('    breakage analysis is any good.')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
