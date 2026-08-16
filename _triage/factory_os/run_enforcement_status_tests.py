"""
run_enforcement_status_tests.py - prove the PLANNED/BUILT/WIRED labels are CHECKED, not decorative.

WHY THIS EXISTS
  `x-enforced-by` used to assert that a named validator enforced a constraint. Codex audit 7 MAJOR 7
  measured that SEVEN of the ten names had no implementation at all, so the field was false governance
  state: it read as "enforced" for constraints nothing enforced. Splitting it into
  PLANNED / BUILT / WIRED only helps if the labels are verified against the repo -- an unchecked label
  is the same false claim with more syllables. `check_schema_structure.py` verifies them; this proves
  that verification can FAIL.

  The WIRED case earned this suite twice. The first implementation searched the tier files whole, so a
  claim pointing at `snapshot_validator.py` passed -- that name appears in run_fast_cages.ps1's
  `$SUITE_GUARDS` map as an INPUT that triggers the tier, not as something the tier runs. The second
  cut the map out and still passed, because the same filename reappears in a later declaration block.
  Only whitelisting the arrays that are actually executed made it decidable. Being named in a
  dependency list is not being invoked, and two attempts got that wrong.

  ORDER-1283: the mutation cage uses an injected temporary schema document. The tracked
  `_triage/factory_os/schemas.json` is never opened for writing, so concurrent commit hooks
  cannot restore one another's mutation or leave a false-green receipt behind.

USAGE  tools\\python312\\python.exe _triage/factory_os/run_enforcement_status_tests.py
"""
import io
import json
import os
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_design_contracts as gen  # noqa: E402

CHECKER = '_triage/factory_os/check_schema_structure.py'

def _patch(entity, **fields):
    def mutate(doc):
        body = doc['$defs'][entity]
        unchanged = [key for key, value in fields.items() if body.get(key) == value]
        if unchanged:
            raise AssertionError('mutation anchor already has requested value for %s: %s'
                                 % (entity, unchanged))
        body.update(fields)
        return len(fields)
    return mutate


def _drop(entity, *keys):
    def mutate(doc):
        body = doc['$defs'][entity]
        missing = [key for key in keys if key not in body]
        if missing:
            raise AssertionError('mutation anchor missing for %s: %s' % (entity, missing))
        for k in keys:
            body.pop(k)
        return len(keys)
    return mutate


def _rename(entity, new):
    def mutate(doc):
        if entity not in doc['$defs']:
            raise AssertionError('mutation anchor missing for %s' % entity)
        if new in doc['$defs']:
            raise AssertionError('mutation target already exists: %s' % new)
        doc['$defs'][new] = doc['$defs'].pop(entity)
        return 1
    return mutate


def _add_entity(name):
    def mutate(doc):
        if name in doc['$defs']:
            raise AssertionError('mutation target already exists: %s' % name)
        doc['$defs'][name] = {'type': 'object', 'description': 'a contract nobody classified'}
        return 1
    return mutate


# (label, the name a [FAIL] line must NAME, mutation)
CASES = (
    ('a PLANNED constraint relabelled WIRED', 'Hypothesis',
     _patch('Hypothesis', **{'x-enforcement-status': 'WIRED'})),
    ('a BUILT row whose enforcer does not exist', 'SnapshotVerdict',
     _patch('SnapshotVerdict', **{'x-enforcer': '_triage/factory_os/does_not_exist.py'})),
    ('a WIRED row whose enforcer nothing invokes', 'MagicAllocation',
     _patch('MagicAllocation', **{'x-enforcer': '_triage/factory_os/snapshot_validator.py'})),
    ('an invented status value', 'WorkReceipt',
     _patch('WorkReceipt', **{'x-enforcement-status': 'TOTALLY_FINE'})),
    ('a PLANNED row quietly naming a real enforcer', 'CoverageCell',
     _patch('CoverageCell', **{'x-enforcer': 'scripts/check_state.ps1'})),

    # ---- ORDER-1264 #1. FOUR of the five cases below were GREEN against the pre-fix checker
    # (measured 2026-08-03 by running each mutation against `git show HEAD:` of the checker,
    # not assumed), because an entity carrying no `x-enforced-by` was `continue`d past rather
    # than failed and nothing held an inventory of which entities must carry one. The first two
    # are the audit's own words -- "a constraint and its enforcement metadata can be deleted
    # TOGETHER and the lint still prints STRUCTURE OK".
    #
    # ORDER-1280 closes the old undeclared list. The second inventory direction is
    # now pinned by an explicit scope exemption gaining a declaration: a justified
    # exemption must not become an unverified enforcement claim by accident.
    ('ORDER-1264: x-enforced-by DELETED from a declared entity', 'SafeProjection',
     _drop('SafeProjection', 'x-enforced-by')),
    ('ORDER-1264: constraint AND metadata deleted together', 'ReconciliationEvidence',
     _drop('ReconciliationEvidence', 'x-enforced-by', 'x-enforcement-status', 'x-enforcer')),
    ('ORDER-1280: a scope exemption quietly GAINS a declaration', 'EvidenceRef',
     _patch('EvidenceRef', **{'x-enforced-by': 'somebody_validator: trust me'})),
    ('ORDER-1264: a new entity classified by nobody', 'TotallyNewContract',
     _add_entity('TotallyNewContract')),
    # Both inventory directions at once: the new name is unclassified AND the old one is a stale
    # entry. A rename is used rather than a deletion deliberately -- deleting a ROUTED entity
    # crashes the branch-resolution check at line 77 with a KeyError before the inventory
    # assertion is ever reached, so a delete-case would be green for the wrong reason. Measured,
    # not assumed. `ModuleUse` is a helper, so renaming it reaches the assertion cleanly.
    ('ORDER-1264: a renamed entity leaves a stale inventory entry', 'ModuleUse',
     _rename('ModuleUse', 'ModuleUseRenamed')),
)


def run_checker(schema_override=None):
    # ORDER-670: mode pinned to WORKTREE explicitly. This suite injects mutations from a
    # temporary copy of schemas.json and asserts the checker refuses them -- it is testing the
    # checker's RULES against synthetic bytes (category C), not judging a commit. Under a
    # pre-commit hook the inherited env says `index`, and an index-mode checker cannot see a
    # worktree mutation: every case here would report GREEN-for-the-wrong-reason and the
    # suite would call that BAD. The mode must therefore be deterministic, not inherited.
    env = dict(os.environ)
    env['EA_LAB_EVIDENCE'] = 'worktree'
    if schema_override:
        env['EA_LAB_ENFORCEMENT_SCHEMA_OVERRIDE'] = schema_override
    else:
        env.pop('EA_LAB_ENFORCEMENT_SCHEMA_OVERRIDE', None)
    p = subprocess.run(['tools\\python312\\python.exe', CHECKER], capture_output=True,
                       text=True, env=env)
    return p.returncode, p.stdout


def main():
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    os.chdir(root)
    schema_path = os.path.abspath(gen.SCHEMA_PATH)
    original_bytes = io.open(schema_path, 'rb').read()
    original = original_bytes.decode('utf-8')
    bad = 0

    rc, out = run_checker()
    print('=== CONTROL: the real schema must be GREEN, or every case below proves nothing ===')
    print('  [%s] check_schema_structure.py exits 0 (%s)'
          % ('OK ' if rc == 0 else 'BAD',
             next((l.strip() for l in out.splitlines() if 'PLANNED=' in l), '?')))
    if rc != 0:
        return 1

    print('\n=== %d mutations, each must be refused BY NAME ===' % len(CASES))
    with tempfile.TemporaryDirectory(prefix='enforcementmut_') as tmp:
        mutant_path = os.path.join(tmp, 'schemas.json')
        for label, entity, mutate in CASES:
            doc = json.loads(original)
            changed = mutate(doc)
            if not changed:
                raise AssertionError('mutation for %s changed no fields' % entity)
            io.open(mutant_path, 'w', encoding='utf-8', newline='\n').write(
                json.dumps(doc, indent=2, ensure_ascii=False) + '\n')
            # Test-only interruption seam. A harness may terminate this process after the
            # mutation is materialised; the tracked schema must still be byte-identical.
            pause_marker = os.environ.get('EA_LAB_ENFORCEMENT_PAUSE_MARKER')
            if pause_marker:
                io.open(pause_marker, 'w', encoding='ascii').write('mutation materialized\n')
                while os.path.exists(pause_marker):
                    time.sleep(0.05)
            rc, out = run_checker(mutant_path)
            hit = [l for l in out.splitlines() if '[FAIL]' in l and entity in l]
            ok = rc != 0 and hit
            print('  [%s] %-46s expect=RED got=%s' % ('OK ' if ok else 'BAD', label,
                                                      'RED ' if rc != 0 else 'GREEN'))
            if not ok:
                bad += 1
                print('        -> %s' % (hit[0].strip()[:100] if hit
                                         else 'NOTHING NAMED %s FAILED' % entity))
    if io.open(schema_path, 'rb').read() != original_bytes:
        print('  [BAD] this suite changed tracked schemas.json')
        bad += 1
    else:
        print('  [OK ] tracked schemas.json was never written (mutations stayed in a temp copy)')
    rc, _ = run_checker()
    print('\n  [%s] CONTROL schema restored and green again (exit %d)'
          % ('OK ' if rc == 0 else 'BAD', rc))
    if rc != 0:
        bad += 1

    if bad:
        print('\n=== %d CASE(S) DID NOT BEHAVE AS DECLARED ===' % bad)
        return 1
    print('\n=== ENFORCEMENT LABELS ARE CHECKED, AND THE CHECK CAN FAIL ===')
    return 0


if __name__ == '__main__':
    sys.exit(main())
