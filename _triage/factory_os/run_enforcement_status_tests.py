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

🔴 DO NOT PUT THIS SUITE ON THE COMMIT PATH UNTIL IT STOPS WRITING TO schemas.json (ORDER-1283)
  This suite tests the checker by MUTATING the live, tracked `_triage/factory_os/schemas.json`
  and restoring it in a `finally`. On a hand-run wrapper that is untidy. In the pre-commit tier
  of a repo where two lanes commit concurrently it is a DATA-LOSS PATH, and that was OBSERVED,
  not theorised: ORDER-1264 added it to run_schema_cages.ps1, and within twenty minutes a hand
  run and another lane's hook collided on the file -- one died with OSError 22, the other's
  `finally` restored ITS idea of "the original", and `WorkReceipt.x-enforcement-status` was left
  sitting in the working tree as "TOTALLY_FINE". Whichever process reads the file while the
  other holds a mutation restores THE MUTATION.

  It goes back in the tier when the checker is drivable with an INJECTED document instead of
  only as a subprocess over a fixed path. Adding it back before then re-opens the same hole.

USAGE  tools\\python312\\python.exe _triage/factory_os/run_enforcement_status_tests.py
"""
import io
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_design_contracts as gen  # noqa: E402

CHECKER = '_triage/factory_os/check_schema_structure.py'

def _patch(entity, **fields):
    def mutate(doc):
        doc['$defs'][entity].update(fields)
    return mutate


def _drop(entity, *keys):
    def mutate(doc):
        for k in keys:
            doc['$defs'][entity].pop(k, None)
    return mutate


def _rename(entity, new):
    def mutate(doc):
        doc['$defs'][new] = doc['$defs'].pop(entity)
    return mutate


def _add_entity(name):
    def mutate(doc):
        doc['$defs'][name] = {'type': 'object', 'description': 'a contract nobody classified'}
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
    # The exception is stated rather than left to read as a fifth catch: the ExecutionKey case
    # was ALREADY red at HEAD, because once `x-enforced-by` appeared the old loop stopped
    # skipping the entity and demanded a valid `x-enforcement-status`, which it had none. What
    # ORDER-1264 changed for it is only WHICH check fires and what the message tells you to do
    # (move it to _ENFORCEMENT_DECLARED). It is kept because it pins the inventory's second
    # direction, not because it is evidence of the repair.
    ('ORDER-1264: x-enforced-by DELETED from a declared entity', 'SafeProjection',
     _drop('SafeProjection', 'x-enforced-by')),
    ('ORDER-1264: constraint AND metadata deleted together', 'ReconciliationEvidence',
     _drop('ReconciliationEvidence', 'x-enforced-by', 'x-enforcement-status', 'x-enforcer')),
    ('ORDER-1264: an undeclared entity quietly GAINS a declaration', 'ExecutionKey',
     _patch('ExecutionKey', **{'x-enforced-by': 'somebody_validator: trust me'})),
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


def run_checker():
    # ORDER-670: mode pinned to WORKTREE explicitly. This suite writes mutations into the
    # worktree copy of schemas.json and asserts the checker refuses them -- it is testing the
    # checker's RULES against synthetic bytes (category C), not judging a commit. Under a
    # pre-commit hook the inherited env says `index`, and an index-mode checker cannot see a
    # worktree mutation: every case here would report GREEN-for-the-wrong-reason and the
    # suite would call that BAD. The mode must therefore be deterministic, not inherited.
    env = dict(os.environ)
    env['EA_LAB_EVIDENCE'] = 'worktree'
    p = subprocess.run(['tools\\python312\\python.exe', CHECKER], capture_output=True,
                       text=True, env=env)
    return p.returncode, p.stdout


def main():
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    os.chdir(root)
    original = io.open(gen.SCHEMA_PATH, encoding='utf-8').read()
    bad = 0

    rc, out = run_checker()
    print('=== CONTROL: the real schema must be GREEN, or every case below proves nothing ===')
    print('  [%s] check_schema_structure.py exits 0 (%s)'
          % ('OK ' if rc == 0 else 'BAD',
             next((l.strip() for l in out.splitlines() if 'PLANNED=' in l), '?')))
    if rc != 0:
        return 1

    print('\n=== %d mutations, each must be refused BY NAME ===' % len(CASES))
    try:
        for label, entity, mutate in CASES:
            doc = json.loads(original)
            mutate(doc)
            io.open(gen.SCHEMA_PATH, 'w', encoding='utf-8', newline='\n').write(
                json.dumps(doc, indent=2, ensure_ascii=False) + '\n')
            rc, out = run_checker()
            hit = [l for l in out.splitlines() if '[FAIL]' in l and entity in l]
            ok = rc != 0 and hit
            print('  [%s] %-46s expect=RED got=%s' % ('OK ' if ok else 'BAD', label,
                                                      'RED ' if rc != 0 else 'GREEN'))
            if not ok:
                bad += 1
                print('        -> %s' % (hit[0].strip()[:100] if hit
                                         else 'NOTHING NAMED %s FAILED' % entity))
    finally:
        io.open(gen.SCHEMA_PATH, 'w', encoding='utf-8', newline='\n').write(original)

    if io.open(gen.SCHEMA_PATH, encoding='utf-8').read() != original:
        print('  [BAD] this suite did not restore schemas.json')
        bad += 1
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
