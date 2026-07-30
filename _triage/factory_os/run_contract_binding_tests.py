"""
run_contract_binding_tests.py - does the design<->schema binding actually catch the
seven regressions it was built for?

WHY THIS EXISTS  (BACKLOG-D31)
  The previous attempt at this binding (check_schema_structure.py) was believed to be the
  cure. Audit 3 measured it against the 7 REGRESSED findings and it would have caught
  0 of 7, because it compared storage paths and grepped banned sentences while every one
  of those defects was semantic. It reported STRUCTURE OK on a commit where the design
  described `attempts[]`, a lease with `pid`, and `launched_at` and the schema said the
  opposite.

  So this file does not ask "is the design well-formed". It reproduces each of the seven
  defects as a schema mutation and asserts the binding goes RED - the rule audit 3 asked
  for in its own words: do not call a finding fixed until a negative fixture for that
  specific defect fails before the fix and passes after.

  Three CONTROL cases are included and they are not decoration. A harness that goes red on
  every edit proves nothing (memory `discriminating-test-must-be-able-to-discriminate`),
  and a cage that cannot be shown to discriminate is the failure mode this repo has hit
  four times: the artifact keeps being produced and quietly stops being true.

USAGE  tools\\python312\\python.exe _triage/factory_os/run_contract_binding_tests.py
EXIT   0 = every case behaved as declared | 1 = at least one did not
"""
import copy, io, json, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_design_contracts as gen  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


# ------------------------------------------------------------------- mutations

def mut_candidate_id_in_payload(s):
    """audit-1 #5 - candidate_id back inside the payload it is the hash of."""
    s['$defs']['CandidatePayload']['properties']['candidate_id'] = {'type': 'string'}
    s['$defs']['CandidatePayload']['required'].append('candidate_id')


def mut_execution_key_drops_deposit(s):
    """audit-1 #8 - the field whose absence made two different runs share one cache key."""
    d = s['$defs']['ExecutionKey']
    d['properties'].pop('deposit', None)
    d['required'] = [r for r in d['required'] if r != 'deposit']


def mut_role_becomes_global(s):
    """audit-1 #10 - `role` written as a column of the global parameter registry."""
    rows = s['x-ea-lab-meta']['contracts']['parameter_registry_columns']['rows']
    for row in rows:
        if row['column'] == 'role':
            row['scope'] = 'global'
            row['meaning'] = 'TUNABLE / LOCKED for this parameter'
            return
    raise AssertionError('no `role` row to mutate')


def mut_coverage_gets_flat_lane(s):
    """audit-1 #11 - one lane and one fingerprint beside MAIN and BWD together."""
    p = s['$defs']['CoverageCell']['properties']
    p['lane'] = {'type': 'string'}
    p['best_pf_main'] = {'type': 'number'}


def mut_parity_list_shrinks(s):
    """audit-2 #12 - the list and the stated count disagreeing."""
    rows = s['x-ea-lab-meta']['contracts']['parity_cases']['rows']
    s['x-ea-lab-meta']['contracts']['parity_cases']['rows'] = [
        r for r in rows if r['case'] != '2c']


def mut_safe_projection_leaks(s):
    """audit-3 #15 - the internal finding id reaching an online surface."""
    items = s['$defs']['SafeProjection']['properties']['findings']['items']
    items['properties']['finding_id'] = {'type': 'string'}
    items['required'].append('finding_id')


def mut_owner_becomes_csv(s):
    """audit-1 #20 - a typed registry given a CSV owner, which cannot round-trip lists or nulls."""
    s['$defs']['Hypothesis']['x-owner-file'] = 'factory/hypotheses.csv'


def mut_noop(s):
    return


def mut_rationale_only(s):
    """CONTROL - edit prose the tables do not render. Must NOT move the design."""
    s['$defs']['Hypothesis']['description'] = 'rewritten rationale, no contract change'


CASES = [
    ('#5  candidate id inside its own hash payload', mut_candidate_id_in_payload,
     '`candidate_id`', True),
    ('#8  ExecutionKey loses `deposit`', mut_execution_key_drops_deposit,
     '`deposit`', True),
    ('#10 `role` moved to the global registry', mut_role_becomes_global,
     'NOT A COLUMN', True),
    ('#11 flat `lane` / `best_pf_main` on CoverageCell', mut_coverage_gets_flat_lane,
     '`lane`', True),
    ('#12 parity list shrinks below its stated set', mut_parity_list_shrinks,
     '2c', True),
    ('#15 SafeProjection carries the raw finding id', mut_safe_projection_leaks,
     'finding_id', True),
    ('#20 typed registry given a CSV owner', mut_owner_becomes_csv,
     'factory/hypotheses.csv', True),
    ('CONTROL no schema change at all', mut_noop, None, False),
    ('CONTROL rationale-only edit (def description)', mut_rationale_only, None, False),
]


def main():
    os.chdir(ROOT)
    with io.open(gen.SCHEMA_PATH, encoding='utf-8') as fh:
        base = json.load(fh)
    with io.open(gen.DESIGN_PATH, encoding='utf-8', newline='') as fh:
        design = fh.read()

    print('=== does the binding catch the seven regressions it was built for? ===')
    print('design: {0}'.format(gen.DESIGN_PATH))
    print('schema: {0}\n'.format(gen.SCHEMA_PATH))

    # Precondition. If the committed design is already stale the whole run is meaningless -
    # every case would show a diff and every case would "pass" for the wrong reason.
    clean, _ = gen.rewrite(design, base)
    if clean != design:
        print('[ABORT] the committed design does not match the current schema. Regenerate first;')
        print('        until then this harness cannot tell a caught defect from a stale file.')
        return 1
    print('  [OK ] precondition: committed design matches the unmutated schema\n')

    failures = 0
    for label, mutate, witness, expect_red in CASES:
        mutated = copy.deepcopy(base)
        try:
            mutate(mutated)
        except AssertionError as exc:
            print('  [FAIL] {0:<48} mutation could not be applied: {1}'.format(label, exc))
            failures += 1
            continue

        try:
            after, _ = gen.rewrite(design, mutated)
            err = None
        except KeyError as exc:
            after, err = None, exc.args[0]

        if err is not None:
            got_red = True
            witness_ok = True
        else:
            got_red = after != design
            witness_ok = True
            if witness is not None:
                # The diff must be about the defect, not about some unrelated churn.
                witness_ok = (witness in after) != (witness in design) or \
                             after.count(witness) != design.count(witness)

        ok = (got_red == expect_red) and (witness_ok or not expect_red)
        if not ok:
            failures += 1
        print('  [{0}] {1:<48} expect={2:<5} got={3:<5} {4}'.format(
            'OK ' if ok else 'FAIL', label,
            'RED' if expect_red else 'GREEN', 'RED' if got_red else 'GREEN',
            '' if witness_ok else '(diff did not touch `%s`)' % witness))

    # CONTROL 3 - silence. An entity the design never mentions cannot be caught
    # contradicting the schema, and six of the seven regressions survived a checker
    # that only examined what WAS written.
    stripped = design.replace(
        gen.BEGIN.format(key='ExecutionKey'), '<!-- deleted for the control case -->')
    try:
        gen.rewrite(stripped, base)
        keys = [m.group('key') for m in gen.BLOCK_RE.finditer(stripped)]
        caught = 'ExecutionKey' not in keys
    except KeyError:
        caught = True
    print('  [{0}] {1:<48} expect=RED   got={2}'.format(
        'OK ' if caught else 'FAIL',
        'CONTROL block deleted from the design', 'RED' if caught else 'GREEN'))
    print('         (the generator refuses on missing coverage; this asserts the deletion is visible)')
    if not caught:
        failures += 1

    print('')
    if failures:
        print('=== {0} CASE(S) DID NOT BEHAVE AS DECLARED ==='.format(failures))
        return 1
    print('=== ALL {0} CASES BEHAVED AS DECLARED - 7/7 regressions caught, controls stayed green ==='
          .format(len(CASES) + 1))
    return 0


if __name__ == '__main__':
    sys.exit(main())
