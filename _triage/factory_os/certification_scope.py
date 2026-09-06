"""Structured RuntimeIdentity certification/mechanism scope classification.

docs/architecture/RUNTIME_IDENTITY_COVERAGE_CONTRACT_20260905.md: two scope dimensions were
previously hidden inside the single x58 forward-observed denominator. This module reads the
dedicated structured scope owner (portfolio/CERTIFICATION_SCOPE.csv) and reports them side by
side without ever parsing DEPLOYMENTS.csv.notes at runtime -- that transcription happens once,
reviewed, via scripts/research/seed_certification_scope.py.

This module deliberately never infers a row's scope from trade history, filenames, account-level
prose, or dashboard presence: it can only read what scripts/lib/certification_scope.ps1 (or a
future writer) put in the structured CSV, and any deployment key absent from that CSV is reported
UNKNOWN, never silently excluded.
"""

from __future__ import annotations

import csv
import json
import re
import sys


MECHANISM_VALUES = frozenset((
    'NATIVE_RUNTIME_IDENTITY',
    'NO_NATIVE_RUNTIME_IDENTITY_MT4',
    'UNKNOWN',
))
CERTIFICATION_VALUES = frozenset((
    'LAB_CERTIFIED',
    'USER_OWNED_UNCERTIFIED',
    'UNKNOWN',
))
REQUIRED_COLUMNS = (
    'account', 'magic', 'identity_mechanism_capability', 'identity_certification_scope',
    'evidence_ref', 'status',
)
_KEY = re.compile(r'^[1-9][0-9]*$')


def _reason(code, detail):
    return {'code': code, 'detail': detail}


def parse_certification_scope_rows(rows):
    """rows: iterable of dict (csv.DictReader shape). Returns (by_key, errors).

    A row that fails any check is reported in `errors` and excluded from `by_key` -- it is never
    silently coerced into a passing shape. Fail-closed: a caller that gets any errors must not
    treat the returned by_key as a complete or trustworthy scope map.
    """
    by_key = {}
    errors = []
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            errors.append(_reason('CERTIFICATION_SCOPE_ROW_MALFORMED', 'row=%d is not an object' % index))
            continue
        missing = [c for c in REQUIRED_COLUMNS if c not in row]
        if missing:
            errors.append(_reason('CERTIFICATION_SCOPE_ROW_INCOMPLETE',
                                   'row=%d missing=%s' % (index, ','.join(missing))))
            continue
        account = (row['account'] or '').strip()
        magic = (row['magic'] or '').strip()
        if not _KEY.fullmatch(account) or not _KEY.fullmatch(magic):
            errors.append(_reason('CERTIFICATION_SCOPE_KEY_INVALID',
                                   'row=%d account=%r magic=%r' % (index, row['account'], row['magic'])))
            continue
        mechanism = (row['identity_mechanism_capability'] or '').strip()
        certification = (row['identity_certification_scope'] or '').strip()
        if mechanism not in MECHANISM_VALUES:
            errors.append(_reason('CERTIFICATION_SCOPE_MECHANISM_INVALID',
                                   'row=%d value=%r' % (index, mechanism)))
            continue
        if certification not in CERTIFICATION_VALUES:
            errors.append(_reason('CERTIFICATION_SCOPE_CERTIFICATION_INVALID',
                                   'row=%d value=%r' % (index, certification)))
            continue
        evidence_ref = (row['evidence_ref'] or '').strip()
        if not evidence_ref:
            errors.append(_reason('CERTIFICATION_SCOPE_EVIDENCE_REF_MISSING',
                                   'row=%d key=%s|%s' % (index, account, magic)))
            continue
        key = '%s|%s' % (account, magic)
        if key in by_key:
            errors.append(_reason('CERTIFICATION_SCOPE_DUPLICATE_KEY', key))
            continue
        by_key[key] = {
            'account': account,
            'magic': magic,
            'identity_mechanism_capability': mechanism,
            'identity_certification_scope': certification,
            'evidence_ref': evidence_ref,
            'status': (row['status'] or '').strip(),
        }
    return by_key, errors


def classify_forward_scope(expected_keys, scope_by_key):
    """Compare the canonical forward-observed, non-REMOVED deployment universe (the SAME scope
    RuntimeIdentity coverage already uses -- see scripts/lib/runtime_identity.ps1's
    Get-RuntimeIdentityExpectedScope) against the structured CERTIFICATION_SCOPE.csv map.

    A deployment key with no CERTIFICATION_SCOPE.csv row counts toward `scope_unknown` and
    `missing_scope_fact`; it is never silently excluded from scope_total_forward_observed.
    A CERTIFICATION_SCOPE.csv row outside the expected universe is `orphaned_scope_rows`, never
    merged in as if it were still forward-observed.

    Dimensions are reported side by side, not as a strict partition: a row with a known
    mechanism but an unknown certification (or vice versa) counts in both its known-dimension
    bucket and `scope_unknown`, matching the contract's "publish side by side" instruction rather
    than inventing a mutually-exclusive category that would hide the partial-knowledge case.

    Fail-closed on UNKNOWN: `state` can only be 'PASS' when every expected key has a
    CERTIFICATION_SCOPE.csv row AND that row leaves no dimension UNKNOWN. Structural completeness
    (no missing_scope_fact, no orphaned_scope_rows) is necessary but not sufficient -- a fully
    reconciled scope where every row still carries an unresolved UNKNOWN fact is 'GAP', never
    'PASS'. This module does not resolve UNKNOWN facts itself; it only refuses to launder them
    into a passing state.
    """
    expected = [k for k in expected_keys if k]
    expected_set = set(expected)
    missing = sorted(k for k in expected_set if k not in scope_by_key)
    orphaned = sorted(k for k in scope_by_key if k not in expected_set)

    native = set()
    mechanism_unavailable = set()
    lab_certified = set()
    user_owned_uncertified = set()
    unknown = set()
    for key in expected_set:
        row = scope_by_key.get(key)
        if row is None:
            unknown.add(key)
            continue
        mechanism = row['identity_mechanism_capability']
        certification = row['identity_certification_scope']
        if mechanism == 'NATIVE_RUNTIME_IDENTITY':
            native.add(key)
        elif mechanism == 'NO_NATIVE_RUNTIME_IDENTITY_MT4':
            mechanism_unavailable.add(key)
        if certification == 'LAB_CERTIFIED':
            lab_certified.add(key)
        elif certification == 'USER_OWNED_UNCERTIFIED':
            user_owned_uncertified.add(key)
        if mechanism == 'UNKNOWN' or certification == 'UNKNOWN':
            unknown.add(key)

    if not expected:
        state = 'UNKNOWN'
    elif missing or orphaned or unknown:
        state = 'GAP'
    else:
        state = 'PASS'

    reason = ''
    if state == 'GAP':
        if not expected:
            reason = 'no forward-observed deployment row is in scope'
        else:
            parts = []
            if missing:
                parts.append('%d expected key(s) have no CERTIFICATION_SCOPE.csv row' % len(missing))
            if orphaned:
                parts.append('%d CERTIFICATION_SCOPE.csv row(s) are outside the current '
                              'forward-observed scope' % len(orphaned))
            if unknown:
                parts.append('%d expected key(s) have an unresolved UNKNOWN mechanism or '
                              'certification scope fact' % len(unknown))
            reason = ', '.join(parts)
    elif state == 'UNKNOWN':
        reason = 'no forward-observed deployment row is in scope'

    return {
        'state': state,
        'scope_total_forward_observed': len(expected_set),
        'scope_native_identity_capable': len(native),
        'scope_mechanism_unavailable': len(mechanism_unavailable),
        'scope_lab_certified': len(lab_certified),
        'scope_user_owned_uncertified': len(user_owned_uncertified),
        'scope_unknown': len(unknown),
        'missing_scope_fact': missing,
        'orphaned_scope_rows': orphaned,
        'reason': reason,
    }


def _read_csv_rows(path):
    with open(path, 'r', encoding='utf-8-sig', newline='') as handle:
        return list(csv.DictReader(handle))


def main(argv):
    if len(argv) != 4 or argv[1] != 'classify':
        print('usage: certification_scope.py classify <CERTIFICATION_SCOPE.csv> <expected_scope.json>')
        return 2
    rows = _read_csv_rows(argv[2])
    with open(argv[3], 'r', encoding='utf-8-sig') as handle:
        expected = json.load(handle)
    by_key, errors = parse_certification_scope_rows(rows)
    result = classify_forward_scope(expected, by_key)
    if errors:
        result = dict(result, state='FAIL', parse_errors=errors)
    print(json.dumps(result, sort_keys=True))
    return 0 if result['state'] == 'PASS' else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv))
