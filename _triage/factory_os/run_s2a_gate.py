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
import gen_s2a_migration as gen_d1          # noqa: E402
import gen_s2a_migration_doc as gen_d2      # noqa: E402
import run_s2a_migration_tests as muts      # noqa: E402

STEPS = (
    ('D1 matches its generator', lambda: gen_d1.main(['--check'])),
    ('D2 matches D1', lambda: gen_d2.main(['--check'])),
    ('the nine machine criteria', lambda: chk.main([])),
    ('the checker refuses the null migration', lambda: chk.self_test()),
    ('24 mutations of the real D1 are caught', lambda: muts.main()),
)


def main():
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    os.chdir(root)
    failed = []
    for label, fn in STEPS:
        # each step chdir's to root itself; none of them is allowed to leave the cwd elsewhere
        rc = fn()
        os.chdir(root)
        print('\n---- [%s] %s (exit %s)\n' % ('OK ' if rc == 0 else 'FAIL', label, rc))
        if rc != 0:
            failed.append(label)
    if failed:
        print('=== S2a GATE FAILED: %s ===' % ' · '.join(failed))
        return 1
    print('=== S2a GATE: all %d steps green ===' % len(STEPS))
    return 0


if __name__ == '__main__':
    sys.exit(main())
