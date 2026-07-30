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

CASES = (
    ('a PLANNED constraint relabelled WIRED', 'Hypothesis',
     {'x-enforcement-status': 'WIRED'}),
    ('a BUILT row whose enforcer does not exist', 'SnapshotVerdict',
     {'x-enforcer': '_triage/factory_os/does_not_exist.py'}),
    ('a WIRED row whose enforcer nothing invokes', 'MagicAllocation',
     {'x-enforcer': '_triage/factory_os/snapshot_validator.py'}),
    ('an invented status value', 'WorkReceipt',
     {'x-enforcement-status': 'TOTALLY_FINE'}),
    ('a PLANNED row quietly naming a real enforcer', 'CoverageCell',
     {'x-enforcer': 'scripts/check_state.ps1'}),
)


def run_checker():
    p = subprocess.run(['tools\\python312\\python.exe', CHECKER], capture_output=True, text=True)
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
        for label, entity, patch in CASES:
            doc = json.loads(original)
            doc['$defs'][entity].update(patch)
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
