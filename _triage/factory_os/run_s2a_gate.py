"""
run_s2a_gate.py - ORDER-600 (S2a): every S2a check, in ONE interpreter.

WHY AN AGGREGATOR AND NOT FIVE ENTRIES IN THE .ps1
  `run_contract_binding_tests.ps1` spawns one python process per script, and on this machine a bare
  interpreter start is ~0.9s. Five separate entries would have cost ~4.4s of a fast tier already
  measured at 15.4s against a 15.0s ADVISORY budget -- a 30% overrun to run about 1.7s of actual work.
  Folding them into one process is the same budget decision, with numbers, that put the snapshot
  validator suite inside that .ps1 rather than beside it.

WHAT IT RUNS, in the order a reader should care about
  1. gen_s2a_migration.py --check       D1 still matches its generator (no hand-edit drift)
  2. gen_s2a_migration_doc.py --check   D2 still matches D1 (no stale prose about changed rows)
  3. check_s2a_migration.py             the nine MACHINE criteria of ORDER-600 against the real D1
  4. check_s2a_migration.py --self-test 18 assertions that the checker refuses the null migration
                                        and the two rev-5 owner forms' own abuse
  5. run_s2a_migration_tests.py         24 mutations of the REAL D1, each must redden by name, with
                                        the unmutated file as a green control

  (3) alone is not enough and (4) alone is not enough: (3) is a green run whose checker might be
  incapable of failing, and (4) only proves the checker refuses a synthetic artifact built to be
  refused. (5) is the one that shows it still bites against the file actually produced.

USAGE  tools\\python312\\python.exe _triage/factory_os/run_s2a_gate.py
EXIT   0 = all five green · 1 = any failed (including D1 absent, which is exit 2 downstream)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import check_s2a_migration as chk          # noqa: E402
import check_s2a_attestation as sign            # noqa: E402
import gen_s2a_migration as gen_d1          # noqa: E402
import gen_s2a_migration_doc as gen_d2      # noqa: E402
import run_s2a_migration_tests as muts      # noqa: E402
import run_s2a_attestation_tests as sign_tests  # noqa: E402

STEPS = (
    ('D1 matches its generator', lambda: gen_d1.main(['--check'])),
    ('D2 matches D1', lambda: gen_d2.main(['--check'])),
    ('the nine machine criteria', lambda: chk.main([])),
    ('the checker refuses the null migration', lambda: chk.self_test()),
    # ORDER-602 A: the sign-off log is a separate artifact so the owner never edits a guard to say
    # yes. An empty log is valid -- this step asserts the log is WELL-FORMED, never that it is signed.
    ('the attestation log is valid', lambda: sign.main([])),
    ('recording a decision needs no guard edit', lambda: sign_tests.main()),
    # count DERIVED, not typed: this label read "24 mutations" while the suite already held 27, one
    # commit after I complained about exactly that class of drift in D2's own prose.
    ('%d mutations of the real D1, + the loader and drift-guard parts' % len(muts.CASES),
     lambda: muts.main()),
)


ATTESTATION_STEP = 'the attestation log is valid'


def attestation_exemption():
    """ORDER-610: the ONE case where a red attestation step is expected rather than wrong.

    The owner's approval pins MASTER_BACKLOG.md at the pre-transfer blob. Executing the transfer
    they approved changes that blob, so A6 fires on the change it authorized -- and it cannot be
    repaired here: check_s2a_attestation.py is inside its own bundle, so editing it voids every
    attestation it holds, and writing the owner's acknowledgement would be manufacturing the
    owner's words (blind audit 8 BLOCKER 1).

    The judgement is NOT re-derived here. It is delegated to check_coverage_transfer.py
    --explain-attestation, which exits 0 only when the attestation's sole complaint is that one
    pin AND the transfer independently verifies. One implementation, one set of fixtures: a
    downgrade rule written twice is a downgrade rule that will disagree with itself.
    """
    import subprocess
    p = subprocess.run(
        [sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                      'check_coverage_transfer.py'), '--explain-attestation'],
        capture_output=True)
    return p.returncode == 0, p.stdout.decode('utf-8', 'replace')


def main():
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    os.chdir(root)
    failed = []
    advisories = []
    for label, fn in STEPS:
        # each step chdir's to root itself; none of them is allowed to leave the cwd elsewhere
        rc = fn()
        os.chdir(root)
        if rc != 0 and label == ATTESTATION_STEP:
            exempt, detail = attestation_exemption()
            os.chdir(root)
            if exempt:
                print('\n---- [ADVISORY] %s (exit %s) -- EXPECTED, owner decision owed\n%s'
                      % (label, rc, detail))
                advisories.append(label)
                continue
        print('\n---- [%s] %s (exit %s)\n' % ('OK ' if rc == 0 else 'FAIL', label, rc))
        if rc != 0:
            failed.append(label)
    if advisories:
        print('=== %d ADVISORY step(s): %s -- see _triage/USER_TASKS_2026-07-31.md ==='
              % (len(advisories), ' · '.join(advisories)))
    if failed:
        print('=== S2a GATE FAILED: %s ===' % ' · '.join(failed))
        return 1
    # Do NOT say "all N green" when one of them was an advisory: a summary line that overstates by
    # one step is how a reader learns to skim past the detail that mattered.
    print('=== S2a GATE: %d of %d steps green%s ==='
          % (len(STEPS) - len(advisories), len(STEPS),
             ', %d ADVISORY (owner decision owed)' % len(advisories) if advisories else ''))
    return 0


if __name__ == '__main__':
    sys.exit(main())
