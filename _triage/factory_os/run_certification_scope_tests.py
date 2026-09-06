"""Focused acceptance tests for the RuntimeIdentity certification/mechanism scope classifier
(docs/architecture/RUNTIME_IDENTITY_COVERAGE_CONTRACT_20260905.md).

PART 1 of the certification-scope acceptance suite (scripts/_test/run_certification_scope_tests.ps1
runs this file first, then its own PowerShell-bridge and Get-MonitorCoverage layers). This file
exercises _triage/factory_os/certification_scope.py directly: parse_certification_scope_rows'
shape/enum/key-uniqueness validation and classify_forward_scope's reconciliation, with the required
negative fixtures and the fail-closed-on-UNKNOWN contract as first-class assertions.
"""

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from certification_scope import (  # noqa: E402
    classify_forward_scope,
    parse_certification_scope_rows,
)


PASS = 0
FAIL = 0


def check(name, condition, detail=''):
    global PASS, FAIL
    if condition:
        PASS += 1
        print('[PASS] ' + name)
    else:
        FAIL += 1
        print('[FAIL] ' + name + ((' :: ' + detail) if detail else ''))


def row(account='141049900', magic='7777', mechanism='UNKNOWN', certification='UNKNOWN',
        evidence_ref='no explicit fact', status='TRANSCRIBED'):
    return {
        'account': account,
        'magic': magic,
        'identity_mechanism_capability': mechanism,
        'identity_certification_scope': certification,
        'evidence_ref': evidence_ref,
        'status': status,
    }


def error_codes(errors):
    return {e['code'] for e in errors}


def main():
    # ---- parse_certification_scope_rows: happy path ----
    by_key, errors = parse_certification_scope_rows([row()])
    check('single valid row parses with no errors', errors == [], str(errors))
    check('parsed row is keyed account|magic', '141049900|7777' in by_key, str(by_key))

    # ---- negative: malformed row shape ----
    by_key, errors = parse_certification_scope_rows(['not-a-dict'])
    check('non-dict row -> CERTIFICATION_SCOPE_ROW_MALFORMED, excluded from by_key',
          'CERTIFICATION_SCOPE_ROW_MALFORMED' in error_codes(errors) and by_key == {}, str(errors))

    # ---- negative: missing required column ----
    incomplete = row()
    del incomplete['evidence_ref']
    by_key, errors = parse_certification_scope_rows([incomplete])
    check('row missing a required column -> CERTIFICATION_SCOPE_ROW_INCOMPLETE, excluded',
          'CERTIFICATION_SCOPE_ROW_INCOMPLETE' in error_codes(errors) and by_key == {}, str(errors))

    # ---- negative: non-canonical account/magic key ----
    for bad_account, bad_magic, label in [
        ('0', '7777', 'account=0 (not positive)'),
        ('01', '7777', 'account with leading zero'),
        ('abc', '7777', 'non-numeric account'),
        ('141049900', '', 'blank magic'),
    ]:
        by_key, errors = parse_certification_scope_rows([row(account=bad_account, magic=bad_magic)])
        check('invalid key (%s) -> CERTIFICATION_SCOPE_KEY_INVALID, excluded' % label,
              'CERTIFICATION_SCOPE_KEY_INVALID' in error_codes(errors) and by_key == {}, str(errors))

    # ---- negative: invalid mechanism/certification enum values ----
    by_key, errors = parse_certification_scope_rows([row(mechanism='NOT_A_REAL_VALUE')])
    check('invalid mechanism enum -> CERTIFICATION_SCOPE_MECHANISM_INVALID, excluded',
          'CERTIFICATION_SCOPE_MECHANISM_INVALID' in error_codes(errors) and by_key == {}, str(errors))

    by_key, errors = parse_certification_scope_rows([row(certification='NOT_A_REAL_VALUE')])
    check('invalid certification enum -> CERTIFICATION_SCOPE_CERTIFICATION_INVALID, excluded',
          'CERTIFICATION_SCOPE_CERTIFICATION_INVALID' in error_codes(errors) and by_key == {}, str(errors))

    # ---- negative: blank evidence_ref (a value must justify a non-UNKNOWN fact) ----
    by_key, errors = parse_certification_scope_rows([row(evidence_ref='   ')])
    check('blank evidence_ref -> CERTIFICATION_SCOPE_EVIDENCE_REF_MISSING, excluded',
          'CERTIFICATION_SCOPE_EVIDENCE_REF_MISSING' in error_codes(errors) and by_key == {}, str(errors))

    # ---- negative: duplicate account|magic key ----
    by_key, errors = parse_certification_scope_rows([row(), row()])
    check('duplicate account|magic key -> CERTIFICATION_SCOPE_DUPLICATE_KEY, second copy excluded',
          'CERTIFICATION_SCOPE_DUPLICATE_KEY' in error_codes(errors) and len(by_key) == 1, str(errors))

    # ---- classify_forward_scope: fail-closed on UNKNOWN is the central contract ----
    both_unknown, _ = parse_certification_scope_rows([row()])
    result = classify_forward_scope(['141049900|7777'], both_unknown)
    check('every dimension UNKNOWN, no missing/orphan -> GAP, never PASS (fail-closed)',
          result['state'] == 'GAP' and result['scope_unknown'] == 1, str(result))

    mt4_only, _ = parse_certification_scope_rows(
        [row(mechanism='NO_NATIVE_RUNTIME_IDENTITY_MT4', certification='UNKNOWN')])
    result = classify_forward_scope(['141049900|7777'], mt4_only)
    check('known mechanism but UNKNOWN certification -> still GAP (structural completeness is not enough)',
          result['state'] == 'GAP' and result['scope_mechanism_unavailable'] == 1 and result['scope_unknown'] == 1,
          str(result))

    uncert_only, _ = parse_certification_scope_rows(
        [row(mechanism='UNKNOWN', certification='USER_OWNED_UNCERTIFIED')])
    result = classify_forward_scope(['141049900|7777'], uncert_only)
    check('known certification but UNKNOWN mechanism -> still GAP',
          result['state'] == 'GAP' and result['scope_user_owned_uncertified'] == 1 and result['scope_unknown'] == 1,
          str(result))

    fully_known, _ = parse_certification_scope_rows(
        [row(mechanism='NATIVE_RUNTIME_IDENTITY', certification='LAB_CERTIFIED')])
    result = classify_forward_scope(['141049900|7777'], fully_known)
    check('both dimensions known, no missing/orphan -> PASS is reachable when facts are actually resolved',
          result['state'] == 'PASS' and result['scope_unknown'] == 0, str(result))

    # ---- classify_forward_scope: missing / orphaned reconciliation, never silently dropped ----
    result = classify_forward_scope(['999999999|1'], {})
    check('expected key with no scope row -> GAP, missing_scope_fact contains it, still counted in total',
          result['state'] == 'GAP' and result['missing_scope_fact'] == ['999999999|1']
          and result['scope_total_forward_observed'] == 1, str(result))

    orphan_map, _ = parse_certification_scope_rows([row(account='222222222', magic='2')])
    result = classify_forward_scope(['141049900|7777'], dict(both_unknown, **orphan_map))
    check('scope row outside expected universe -> orphaned_scope_rows, not merged into scope_total',
          result['state'] == 'GAP' and result['orphaned_scope_rows'] == ['222222222|2']
          and result['scope_total_forward_observed'] == 1, str(result))

    # ---- classify_forward_scope: empty expected universe -> UNKNOWN, not PASS/GAP ----
    result = classify_forward_scope([], {})
    check('empty expected scope -> UNKNOWN (no forward-observed row to reconcile against)',
          result['state'] == 'UNKNOWN', str(result))

    # ---- classify_forward_scope: blank/falsy keys in expected list are dropped, not counted ----
    result = classify_forward_scope(['', None, '141049900|7777'], fully_known)
    check('blank/None entries in expected scope are ignored, not phantom-missing',
          result['scope_total_forward_observed'] == 1 and result['state'] == 'PASS', str(result))

    # ---- main() CLI: end-to-end classify, including the FAIL-on-parse-error override ----
    with tempfile.TemporaryDirectory() as tmp:
        csv_path = Path(tmp) / 'scope.csv'
        csv_path.write_text(
            'account,magic,identity_mechanism_capability,identity_certification_scope,evidence_ref,status\n'
            '141049900,7777,NO_NATIVE_RUNTIME_IDENTITY_MT4,UNKNOWN,DEPLOYMENTS.csv platform=MT4,TRANSCRIBED\n',
            encoding='utf-8',
        )
        expected_path = Path(tmp) / 'expected.json'
        expected_path.write_text(json.dumps(['141049900|7777']), encoding='utf-8')
        proc = subprocess.run(
            [sys.executable, str(Path(__file__).with_name('certification_scope.py')),
             'classify', str(csv_path), str(expected_path)],
            capture_output=True, text=True,
        )
        out = json.loads(proc.stdout.strip())
        check('CLI classify: exit code non-zero when state is not PASS (GAP here, fail-closed)',
              proc.returncode == 1, 'rc=%d out=%s' % (proc.returncode, proc.stdout))
        check('CLI classify: GAP because certification is still UNKNOWN even though structurally complete',
              out['state'] == 'GAP' and out['scope_unknown'] == 1, str(out))

        bad_csv_path = Path(tmp) / 'bad.csv'
        bad_csv_path.write_text(
            'account,magic,identity_mechanism_capability,identity_certification_scope,evidence_ref,status\n'
            '141049900,7777,NOT_A_REAL_VALUE,UNKNOWN,bad row,TRANSCRIBED\n',
            encoding='utf-8',
        )
        proc = subprocess.run(
            [sys.executable, str(Path(__file__).with_name('certification_scope.py')),
             'classify', str(bad_csv_path), str(expected_path)],
            capture_output=True, text=True,
        )
        out = json.loads(proc.stdout.strip())
        check('CLI classify: invalid enum row -> state forced to FAIL with parse_errors, exit 1',
              proc.returncode == 1 and out['state'] == 'FAIL' and len(out.get('parse_errors', [])) > 0,
              'rc=%d out=%s' % (proc.returncode, proc.stdout))

        proc = subprocess.run(
            [sys.executable, str(Path(__file__).with_name('certification_scope.py')), 'classify'],
            capture_output=True, text=True,
        )
        check('CLI with wrong argument count -> usage error, exit 2',
              proc.returncode == 2, 'rc=%d out=%s err=%s' % (proc.returncode, proc.stdout, proc.stderr))

    if FAIL:
        print('FAIL %d/%d' % (PASS, PASS + FAIL))
        return 1
    print('PASS %d/%d' % (PASS, PASS))
    return 0


if __name__ == '__main__':
    sys.exit(main())
