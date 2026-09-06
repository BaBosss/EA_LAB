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
    # The canonical table now lists physical CSV columns only. Reintroducing role
    # is the same forbidden global-ownership regression; an absent row is the
    # correct baseline, not a reason to leave this mutation probe unexercised.
    rows.append({'column': 'role', 'scope': 'global',
                 'meaning': 'TUNABLE / LOCKED for this parameter'})


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


def mut_workreceipt_anticopy_removed(s):
    """audit-4 Q2.3 - the ownership rule that used to be invisible to this harness.

    `if` carried only `required`, so the renderer produced an empty `when` and dropped the
    whole clause. Codex deleted this rule and the generated design did not move.
    """
    d = s['$defs']['WorkReceipt']
    keep = [c for c in d['allOf']
            if not (isinstance(c.get('if'), dict)
                    and 'required' in c['if'] and 'properties' not in c['if']
                    and isinstance(c.get('then'), dict) and 'not' in c['then'])]
    assert len(keep) < len(d['allOf']), 'no bare-required/not clause found to remove'
    d['allOf'] = keep


def mut_lease_requirements_dropped(s):
    """audit-4 Q3 - nullable nested objects were not walked, so these vanished silently."""
    lease = s['$defs']['RunAttempt']['properties']['lease']
    assert lease.get('required'), 'lease has no required list to drop'
    lease.pop('required')


def mut_nesting_past_the_cap(s):
    """audit-5 Q3(c) - nothing committed ever crossed MAX_NEST_DEPTH.

    So a future edit could put the cap branch back to `return []` and all cases would stay
    green while nested contracts silently vanished again -- the exact defect audit 4 found.
    This case makes the cap's behaviour observable.
    """
    leaf = {'type': 'object', 'properties': {'leaf': {'type': 'string'}}}
    for _ in range(gen.MAX_NEST_DEPTH + 1):
        leaf = {'type': 'object', 'properties': {'child': leaf}}
    s['$defs']['Hypothesis']['properties']['depth_probe'] = leaf


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
     'TUNABLE / LOCKED for this parameter', True),
    ('#11 flat `lane` / `best_pf_main` on CoverageCell', mut_coverage_gets_flat_lane,
     '`lane`', True),
    ('#12 parity list shrinks below its stated set', mut_parity_list_shrinks,
     '2c', True),
    ('#15 SafeProjection carries the raw finding id', mut_safe_projection_leaks,
     'finding_id', True),
    ('#20 typed registry given a CSV owner', mut_owner_becomes_csv,
     'factory/hypotheses.csv', True),
    ('A4  WorkReceipt anti-copy rule deleted', mut_workreceipt_anticopy_removed,
     'REFUSED', True),
    ('A4  nullable `lease` loses its required set', mut_lease_requirements_dropped,
     'lease_id', True),
    ('A5  nesting past MAX_NEST_DEPTH', mut_nesting_past_the_cap, None, True),
    ('CONTROL no schema change at all', mut_noop, None, False),
    ('CONTROL rationale-only edit (def description)', mut_rationale_only, None, False),
]


def main():
    os.chdir(ROOT)
    with io.open(gen.SCHEMA_PATH, encoding='utf-8') as fh:
        base = json.load(fh)
    # The generated blocks moved out of the design into CONTRACTS.md. The regressions this
    # harness reproduces are schema->rendered-contract regressions, so it follows the blocks;
    # the design is now read separately, and only to check it still links every contract.
    with io.open(gen.CONTRACTS_PATH, encoding='utf-8', newline='') as fh:
        # Normalised for the same reason the generator normalises: this repo's working tree is
        # CRLF and the generator emits LF, so a file straight from `git checkout` would make
        # the precondition below ABORT -- every case unrun, on a clean checkout, in a
        # pre-commit hook. A cage that is red for everyone is a cage that gets removed.
        contracts = fh.read().replace('\r\n', '\n')
    with io.open(gen.DESIGN_PATH, encoding='utf-8', newline='') as fh:
        design = fh.read().replace('\r\n', '\n')

    print('=== does the binding catch the seven regressions it was built for? ===')
    print('contracts: {0}'.format(gen.CONTRACTS_PATH))
    print('design:    {0} (link check only)'.format(gen.DESIGN_PATH))
    print('schema:    {0}\n'.format(gen.SCHEMA_PATH))

    # Precondition. If the committed file is already stale the whole run is meaningless -
    # every case would show a diff and every case would "pass" for the wrong reason.
    clean, _ = gen.rewrite(contracts, base)
    if clean != contracts:
        print('[ABORT] committed CONTRACTS.md does not match the current schema. Regenerate first;')
        print('        until then this harness cannot tell a caught defect from a stale file.')
        return 1
    print('  [OK ] precondition: committed CONTRACTS.md matches the unmutated schema\n')

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
            after, _ = gen.rewrite(contracts, mutated)
            err = None
        except (KeyError, gen.DepthExceeded) as exc:
            # DepthExceeded is caught beside KeyError (audit-5 Q3c): raising is the point, but
            # an uncaught traceback is a crash, and "the harness crashed" must be reported as a
            # named RED result rather than left to look like a broken test run.
            after, err = None, exc.args[0]

        if err is not None:
            got_red = True
            witness_ok = True
        else:
            got_red = after != contracts
            witness_ok = True
            if witness is not None:
                # The diff must be about the defect, not about some unrelated churn.
                witness_ok = (witness in after) != (witness in contracts) or \
                             after.count(witness) != contracts.count(witness)

        ok = (got_red == expect_red) and (witness_ok or not expect_red)
        if not ok:
            failures += 1
        print('  [{0}] {1:<48} expect={2:<5} got={3:<5} {4}'.format(
            'OK ' if ok else 'FAIL', label,
            'RED' if expect_red else 'GREEN', 'RED' if got_red else 'GREEN',
            '' if witness_ok else '(diff did not touch `%s`)' % witness))

    # Document-level cases. These call the REAL coverage validator, not a restatement of it.
    # The previous version of the deleted-block case asserted `'ExecutionKey' not in keys`
    # after deleting the ExecutionKey block, which is true by arithmetic and tested nothing
    # (audit-4 P1). A control that cannot fail reports coverage that was never checked.
    def coverage_problems(text):
        keys = [m.group('key') for m in gen.BLOCK_RE.finditer(text)]
        return gen.validate_coverage(text, base, keys)

    STRAY_ANCHOR = '## Why this file exists, separately from the design'
    assert STRAY_ANCHOR in contracts, 'the stray-marker fixture anchors on text that is gone'
    doc_cases = [
        ('CONTROL unmodified contracts file', contracts, False),
        ('DOC  a whole block deleted',
         contracts.replace(gen.BEGIN.format(key='ExecutionKey'), '<!-- gone -->'), True),
        ('DOC  a stray unpaired BEGIN marker',
         contracts.replace(STRAY_ANCHOR,
                           gen.BEGIN.format(key='CoverageCell') + '\n\n' + STRAY_ANCHOR),
         True),
        ('DOC  the same block written twice',
         contracts + '\n' + gen.BEGIN.format(key='OwnerRef') + '\n\n'
         + gen.END.format(key='OwnerRef') + '\n',
         True),
    ]
    # Line endings. The generator and this harness both had to learn that CRLF is not a
    # contract change -- --check went red on a clean checkout with an empty diff, and this
    # harness ABORTED, so every case went unrun inside a pre-commit hook. Fixed in df4ccec6
    # and, until now, protected by nothing but review (audit-5 Q3b).
    # splitlines(keepends=True) rather than split('\n'): splitting on the separator and
    # re-joining appends a newline the original never had, and a fixture that changes the
    # content it claims to re-encode reports RED for its own defect. Which it did, once.
    mixed = ''.join(
        (line[:-1] + '\r\n' if (i % 2 and line.endswith('\n')) else line)
        for i, line in enumerate(contracts.splitlines(keepends=True)))
    for label, text in (('EOL  CRLF throughout', contracts.replace('\n', '\r\n')),
                        ('EOL  alternating CRLF/LF', mixed)):
        regenerated, _ = gen.rewrite(text.replace('\r\n', '\n'), base)
        ok = regenerated == contracts
        if not ok:
            failures += 1
        print('  [{0}] {1:<48} expect=GREEN got={2:<5}'.format(
            'OK ' if ok else 'FAIL', label, 'GREEN' if ok else 'RED'))

    for label, text, expect_red in doc_cases:
        problems = coverage_problems(text)
        got_red = bool(problems)
        ok = got_red == expect_red
        if not ok:
            failures += 1
        print('  [{0}] {1:<48} expect={2:<5} got={3:<5} {4}'.format(
            'OK ' if ok else 'FAIL', label,
            'RED' if expect_red else 'GREEN', 'RED' if got_red else 'GREEN',
            problems[0][:60] + '...' if problems else ''))

    # LINK cases. Moving the blocks out of the design cost one property that used to hold by
    # construction: while the tables lived in the design, "the design states this contract" was
    # not something anyone had to check. Now it is validate_links' job, and a new obligation
    # nobody has watched fail is not an obligation. All four negatives below are one edit from
    # the committed design.
    keys_now = [m.group('key') for m in gen.BLOCK_RE.finditer(contracts)]
    a_key = 'CoverageCell'
    good_link = '[`{0}`](factory_os/CONTRACTS.md#{1})'.format(a_key, gen.anchor_of(a_key))
    assert good_link in design, 'the link fixtures anchor on a link that is not in the design'
    link_cases = [
        ('LINK CONTROL unmodified design', design, False),
        ('LINK a contract the design stops linking',
         design.replace(good_link, '`{0}`'.format(a_key)), True),
        ('LINK name and destination disagree',
         design.replace(good_link,
                        '[`{0}`](factory_os/CONTRACTS.md#owneref)'.format(a_key)), True),
        ('LINK a dangling reference to no contract',
         design + '\n[`NotAContract`](factory_os/CONTRACTS.md#notacontract)\n', True),
        # Codex audit 6 (MAJOR 5), reproduced: all 30 links inside ONE html comment returned CLEAN
        # with zero visible prose, because the check regex-scanned raw bytes. A link a reader cannot
        # see satisfies a regex, not a reference.
        ('LINK every link hidden in one html comment',
         '<!--\n' + '\n'.join(m.group(0) for m in gen.LINK_RE.finditer(design)) + '\n-->\n', True),
        ('LINK every link hidden in a fenced code block',
         '```\n' + '\n'.join(m.group(0) for m in gen.LINK_RE.finditer(design)) + '\n```\n', True),
        # ...and the control that keeps the two above honest: the SAME links, visible, must pass.
        # Without it, a validate_links that rejected everything would look like a working fix.
        ('LINK CONTROL the same links, visible',
         '\n\n'.join(m.group(0) for m in gen.LINK_RE.finditer(design)), False),
    ]
    for label, text, expect_red in link_cases:
        problems = gen.validate_links(text, keys_now)
        got_red = bool(problems)
        ok = got_red == expect_red
        if not ok:
            failures += 1
        print('  [{0}] {1:<48} expect={2:<5} got={3:<5} {4}'.format(
            'OK ' if ok else 'FAIL', label,
            'RED' if expect_red else 'GREEN', 'RED' if got_red else 'GREEN',
            problems[0][:60] + '...' if problems else ''))

    print('')
    if failures:
        print('=== {0} CASE(S) DID NOT BEHAVE AS DECLARED ==='.format(failures))
        return 1
    print('=== ALL {0} CASES BEHAVED AS DECLARED - 7/7 regressions caught, controls stayed green ==='
          .format(len(CASES) + len(doc_cases) + len(link_cases) + 2))
    return 0


if __name__ == '__main__':
    sys.exit(main())
