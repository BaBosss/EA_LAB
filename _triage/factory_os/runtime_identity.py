"""Canonical runtime identity and compiled-artifact receipt validation.

This module deliberately keeps configuration identity separate from runtime identity.
The existing config fingerprint is consumed as an opaque semantic value; this module
does not add account, symbol, timeframe, or epoch data to its preimage.
"""

from __future__ import annotations

import datetime as _dt
import hashlib
import json
import re
import os
import sys


IDENTITY_SCHEMA = 'runtime_identity/1'
BUILD_RECEIPT_SCHEMA = 'build_receipt/1'
CONFIG_FINGERPRINT_VERSION = 'cfgfp-v1'
RUNTIME_IDENTITY_MAX_AGE_HOURS = 30
RUNTIME_IDENTITY_FUTURE_TOLERANCE_MINUTES = 5
EXPECTED_ERRORS_KEY = '__errors__'
FORWARD_AWAITING = 'AWAITING_FIRST_TRADE'
FORWARD_VERIFIED = 'VERIFIED'
FORWARD_INVALID_IDENTITY = 'INVALID_RUNTIME_IDENTITY'
FORWARD_STALE_DEALS = 'STALE_DEAL_EVIDENCE'
FORWARD_MALFORMED_DEALS = 'MALFORMED_DEAL_EVIDENCE'
DEAL_ENTRY_IN = '0'

REQUIRED_FIELDS = (
    'account_login',
    'magic',
    'ea_logical_identity',
    'build_receipt',
    'config_fingerprint',
    'config_fingerprint_version',
    'symbol',
    'timeframe',
    'attach_epoch',
    'first_trade_epoch',
    'evidence_timestamp',
)

_HEX64 = re.compile(r'^[0-9a-f]{64}$')
_RECEIPT = re.compile(r'^br-[0-9a-f]{32}$')
_EPOCH = re.compile(r'^epoch-[1-9][0-9]*$')
_UNSET = object()


def _reason(code, detail):
    return {'code': code, 'detail': detail}


def _result(state, reasons, identity=None):
    return {
        'state': state,
        'reasons': reasons,
        'identity': identity,
    }


def validate_epoch_evidence(current_epoch, evidence, label='epoch evidence'):
    """Reconcile deal/snapshot sidecar evidence to the active Runtime Identity epoch.

    Exporters that carry epoch provenance use `attach_epoch`; the aliases are accepted for the
    transport envelopes used by the deal and AccountSnapshot collectors. Missing provenance is a
    failure, never an inferred match from file age, ticket, or filename.
    """
    if not isinstance(evidence, dict):
        return _result('FAIL', [_reason('EPOCH_EVIDENCE_MISSING', label)])
    observed_epoch = evidence.get('attach_epoch')
    if observed_epoch is None:
        observed_epoch = evidence.get('evidence_epoch', evidence.get('epoch'))
    if not _EPOCH.fullmatch(_as_text(observed_epoch)):
        return _result('FAIL', [_reason('EPOCH_EVIDENCE_MISSING', label)])
    if observed_epoch != current_epoch:
        return _result('FAIL', [_reason('EPOCH_EVIDENCE_MISMATCH',
                                         'expected=%s observed=%s' % (current_epoch, observed_epoch))])
    return _result('PASS', [], evidence)


def _positive_integer(value):
    """Accept the integer values emitted by MQL5 and their CSV string form."""
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value if value > 0 else None
    if isinstance(value, str) and re.fullmatch(r'[1-9][0-9]*', value.strip()):
        return int(value.strip())
    return None


def derive_first_trade(identity, deals, deals_fresh=True, supplied_first_trade_epoch=_UNSET):
    """Derive the first qualifying entry from one validated runtime identity and deal feed.

    The deal feed is deliberately a list of canonical collected rows.  `time_unix` is required;
    the display `time` column is never used for the authority comparison.  Account context is
    attached by the collector from the account-scoped filename, so a row cannot qualify without
    an explicit account match.
    """
    if not isinstance(identity, dict):
        return _result(FORWARD_INVALID_IDENTITY,
                       [_reason('IDENTITY_MISSING', 'runtime identity is not an object')])

    account = _as_text(identity.get('account_login'))
    magic = _as_text(identity.get('magic'))
    symbol = _as_text(identity.get('symbol'))
    epoch = _as_text(identity.get('attach_epoch'))
    attach_time = _positive_integer(identity.get('attach_time_unix'))
    identity_reasons = []
    if not account.isdigit() or not account:
        identity_reasons.append(_reason('ACCOUNT_LOGIN_INVALID', str(identity.get('account_login'))))
    if not magic.isdigit() or not magic:
        identity_reasons.append(_reason('MAGIC_INVALID', str(identity.get('magic'))))
    if not symbol:
        identity_reasons.append(_reason('SYMBOL_MISSING', 'symbol'))
    if not _EPOCH.fullmatch(epoch):
        identity_reasons.append(_reason('ATTACH_EPOCH_INVALID', str(identity.get('attach_epoch'))))
    if attach_time is None:
        identity_reasons.append(_reason('ATTACH_TIME_UNIX_MISSING', 'forward-test authority requires attach_time_unix'))
    if identity_reasons:
        return _result(FORWARD_INVALID_IDENTITY, identity_reasons, identity)

    if not deals_fresh:
        return _result(FORWARD_STALE_DEALS,
                       [_reason('DEAL_EVIDENCE_STALE', 'fresh canonical deal evidence is required')],
                       identity)
    if not isinstance(deals, list):
        return _result(FORWARD_MALFORMED_DEALS,
                       [_reason('DEAL_EVIDENCE_MALFORMED', 'deal evidence is not an array')], identity)

    candidates = []
    for index, row in enumerate(deals):
        if not isinstance(row, dict):
            return _result(FORWARD_MALFORMED_DEALS,
                           [_reason('DEAL_EVIDENCE_MALFORMED', 'row=%d is not an object' % index)], identity)
        missing = [field for field in ('account_login', 'ticket', 'time_unix', 'symbol', 'magic', 'entry')
                   if field not in row]
        if missing:
            return _result(FORWARD_MALFORMED_DEALS,
                           [_reason('DEAL_EVIDENCE_INCOMPLETE', 'row=%d missing=%s' %
                                    (index, ','.join(missing)))], identity)
        row_account = _as_text(row.get('account_login'))
        ticket = _positive_integer(row.get('ticket'))
        deal_time = _positive_integer(row.get('time_unix'))
        row_magic = _as_text(row.get('magic'))
        row_symbol = _as_text(row.get('symbol'))
        entry = _as_text(row.get('entry'))
        if (not row_account.isdigit() or not row_account or ticket is None or deal_time is None or
                not row_magic.isdigit() or not row_magic or not row_symbol or entry == ''):
            return _result(FORWARD_MALFORMED_DEALS,
                           [_reason('DEAL_EVIDENCE_MALFORMED', 'row=%d has invalid canonical fields' % index)],
                           identity)
        if (row_account == account and row_magic == magic and row_symbol == symbol and
                entry == DEAL_ENTRY_IN and deal_time >= attach_time):
            candidates.append((deal_time, ticket, row))

    supplied = identity.get('first_trade_epoch') if supplied_first_trade_epoch is _UNSET else supplied_first_trade_epoch
    if not candidates:
        if supplied is not None:
            return _result(FORWARD_INVALID_IDENTITY,
                           [_reason('FIRST_TRADE_EVIDENCE_MISSING',
                                    'first_trade_epoch=%s but no qualifying deal exists' % supplied)], identity)
        return {
            'state': FORWARD_AWAITING,
            'reasons': [],
            'identity': identity,
            'first_trade_epoch': None,
            'qualifying_deal': None,
            'attach_time_unix': attach_time,
            'attach_epoch': epoch,
        }

    deal_time, ticket, row = min(candidates, key=lambda item: (item[0], item[1]))
    if supplied is not None and supplied != epoch:
        return _result(FORWARD_INVALID_IDENTITY,
                       [_reason('FIRST_TRADE_EPOCH_MISMATCH',
                                'expected=%s observed=%s' % (epoch, supplied))], identity)
    return {
        'state': FORWARD_VERIFIED,
        'reasons': [],
        'identity': identity,
        'first_trade_epoch': epoch,
        'qualifying_deal': {
            'ticket': str(ticket),
            'time_unix': deal_time,
            'symbol': row['symbol'],
            'magic': str(row['magic']),
            'entry': str(row['entry']),
        },
        'attach_time_unix': attach_time,
        'attach_epoch': epoch,
    }


def _as_text(value):
    return value if isinstance(value, str) else ''


def _identity_key(identity):
    if not isinstance(identity, dict):
        return None
    return '%s|%s' % (identity.get('account_login'), identity.get('magic'))


def _parse_timestamp(value):
    if not isinstance(value, str) or not value:
        return None
    text = value.strip()
    # MQL5 TimeToString uses dots in the date portion; JSON test/deployment evidence commonly
    # uses ISO hyphens. Both are the same producer timestamp, and neither is rewritten by the
    # collector.
    text = re.sub(r'^(\d{4})\.(\d{2})\.(\d{2})\s+', r'\1-\2-\3T', text)
    try:
        return _dt.datetime.fromisoformat(text.replace('Z', '+00:00'))
    except ValueError:
        return None


def _freshness_reasons(value):
    parsed = _parse_timestamp(value)
    if parsed is None:
        return [_reason('EVIDENCE_TIMESTAMP_INVALID', str(value))]
    if parsed.tzinfo is None:
        now = _dt.datetime.now()
    else:
        now = _dt.datetime.now(_dt.timezone.utc)
        parsed = parsed.astimezone(_dt.timezone.utc)
    age = (now - parsed).total_seconds() / 3600.0
    reasons = []
    if age > RUNTIME_IDENTITY_MAX_AGE_HOURS:
        reasons.append(_reason('EVIDENCE_TIMESTAMP_STALE',
                               'age_hours=%.1f max_hours=%d' % (age, RUNTIME_IDENTITY_MAX_AGE_HOURS)))
    if age < -(RUNTIME_IDENTITY_FUTURE_TOLERANCE_MINUTES / 60.0):
        reasons.append(_reason('EVIDENCE_TIMESTAMP_FUTURE',
                               'age_hours=%.1f tolerance_minutes=%d' %
                               (age, RUNTIME_IDENTITY_FUTURE_TOLERANCE_MINUTES)))
    return reasons


def _shape_reasons(observed):
    reasons = []
    if not isinstance(observed, dict):
        return [_reason('IDENTITY_MISSING', 'runtime identity is not an object')]
    missing = [field for field in REQUIRED_FIELDS if field not in observed]
    if missing:
        reasons.append(_reason('IDENTITY_INCOMPLETE', ','.join(missing)))
        return reasons
    if observed.get('schema') != IDENTITY_SCHEMA:
        reasons.append(_reason('IDENTITY_SCHEMA_UNKNOWN', str(observed.get('schema'))))
    if not _as_text(observed.get('account_login')).isdigit():
        reasons.append(_reason('ACCOUNT_LOGIN_INVALID', str(observed.get('account_login'))))
    if not _as_text(observed.get('magic')).isdigit():
        reasons.append(_reason('MAGIC_INVALID', str(observed.get('magic'))))
    if not _as_text(observed.get('ea_logical_identity')):
        reasons.append(_reason('EA_IDENTITY_MISSING', 'ea_logical_identity'))
    if not _RECEIPT.fullmatch(_as_text(observed.get('build_receipt'))):
        reasons.append(_reason('BUILD_RECEIPT_INVALID', str(observed.get('build_receipt'))))
    if not _HEX64.fullmatch(_as_text(observed.get('config_fingerprint'))):
        reasons.append(_reason('CONFIG_FINGERPRINT_INVALID', 'config_fingerprint'))
    if observed.get('config_fingerprint_version') != CONFIG_FINGERPRINT_VERSION:
        reasons.append(_reason('CONFIG_FINGERPRINT_VERSION_UNKNOWN',
                               str(observed.get('config_fingerprint_version'))))
    for field in ('symbol', 'timeframe'):
        if not _as_text(observed.get(field)):
            reasons.append(_reason(field.upper() + '_MISSING', field))
    if not _EPOCH.fullmatch(_as_text(observed.get('attach_epoch'))):
        reasons.append(_reason('ATTACH_EPOCH_INVALID', str(observed.get('attach_epoch'))))
    if 'attach_time_unix' in observed and _positive_integer(observed.get('attach_time_unix')) is None:
        reasons.append(_reason('ATTACH_TIME_UNIX_INVALID', str(observed.get('attach_time_unix'))))
    first = observed.get('first_trade_epoch')
    if first is not None and first != observed.get('attach_epoch'):
        reasons.append(_reason('FIRST_TRADE_EPOCH_MISMATCH', str(first)))
    reasons.extend(_freshness_reasons(observed.get('evidence_timestamp')))
    if observed.get('evidence_source') != 'EA_RUNTIME_COMMON_FILE':
        reasons.append(_reason('EVIDENCE_SOURCE_UNKNOWN', str(observed.get('evidence_source'))))
    return reasons


def _expected_reasons(observed, expected):
    reasons = []
    if not isinstance(expected, dict):
        return [_reason('EXPECTED_IDENTITY_MISSING', 'no expected identity record')]
    for field in ('account_login', 'magic', 'ea_logical_identity', 'build_receipt',
                  'config_fingerprint', 'config_fingerprint_version', 'symbol', 'timeframe',
                  'attach_epoch'):
        if field in expected and observed.get(field) != expected.get(field):
            reasons.append(_reason(field.upper() + '_MISMATCH',
                                   'expected=%s observed=%s' % (expected.get(field), observed.get(field))))
    if 'attach_time_unix' in expected and observed.get('attach_time_unix') != expected.get('attach_time_unix'):
        reasons.append(_reason('ATTACH_TIME_UNIX_MISMATCH',
                               'expected=%s observed=%s' %
                               (expected.get('attach_time_unix'), observed.get('attach_time_unix'))))
    for field in ('source_sha256', 'artifact_sha256'):
        value = expected.get(field)
        if not _HEX64.fullmatch(_as_text(value)):
            reasons.append(_reason('EXPECTED_%s_UNBOUND' % field.upper(), field))
    return reasons


def _artifact_reasons(observed, expected, registry, artifact_bytes_by_path):
    reasons = []
    if not isinstance(registry, dict):
        return [_reason('BUILD_RECEIPT_UNVERIFIABLE', 'no build receipt registry')]
    receipt = observed.get('build_receipt')
    record = registry.get(receipt)
    if not isinstance(record, dict):
        return [_reason('BUILD_RECEIPT_UNKNOWN', receipt)]
    if record.get('schema') != BUILD_RECEIPT_SCHEMA:
        reasons.append(_reason('BUILD_RECEIPT_SCHEMA_UNKNOWN', str(record.get('schema'))))
    if record.get('build_receipt') != receipt:
        reasons.append(_reason('BUILD_RECEIPT_RECORD_MISMATCH', receipt))
    if record.get('ea_logical_identity') != observed.get('ea_logical_identity'):
        reasons.append(_reason('BUILD_EA_MISMATCH',
                               'expected=%s observed=%s' % (record.get('ea_logical_identity'), observed.get('ea_logical_identity'))))
    if 'config_fingerprint' in record and record.get('config_fingerprint') != observed.get('config_fingerprint'):
        reasons.append(_reason('BUILD_CONFIG_MISMATCH', receipt))
    if ('config_fingerprint_version' in record and
            record.get('config_fingerprint_version') != observed.get('config_fingerprint_version')):
        reasons.append(_reason('BUILD_CONFIG_VERSION_MISMATCH', receipt))
    artifact_path = record.get('artifact_path')
    artifact_hash = record.get('artifact_sha256')
    if not isinstance(artifact_path, str) or not _HEX64.fullmatch(_as_text(artifact_hash)):
        reasons.append(_reason('ARTIFACT_RECORD_INVALID', receipt))
    elif artifact_bytes_by_path is not None:
        if artifact_path not in artifact_bytes_by_path:
            reasons.append(_reason('ARTIFACT_UNVERIFIABLE', artifact_path))
        else:
            actual = hashlib.sha256(artifact_bytes_by_path[artifact_path]).hexdigest()
            if actual != artifact_hash:
                reasons.append(_reason('ARTIFACT_SHA256_MISMATCH', artifact_path))
    source_path = record.get('source_path')
    source_hash = record.get('source_sha256')
    if not isinstance(source_path, str) or not source_path or not _HEX64.fullmatch(_as_text(source_hash)):
        reasons.append(_reason('SOURCE_PROVENANCE_INVALID', receipt))
    else:
        expected_source = expected.get('source_sha256') if isinstance(expected, dict) else None
        if source_hash != expected_source:
            reasons.append(_reason('SOURCE_SHA256_MISMATCH', receipt))
        if os.path.isfile(source_path):
            with open(source_path, 'rb') as source:
                actual_source = hashlib.sha256(source.read()).hexdigest()
            if actual_source != source_hash:
                reasons.append(_reason('SOURCE_FILE_SHA256_MISMATCH', source_path))
        # A deployment is allowed to carry the trusted receipt without shipping source. The
        # absence is not converted into a fake filesystem success: the registry hash remains the
        # authoritative build-time source proof and must already be pinned above.
    expected_artifact = expected.get('artifact_sha256') if isinstance(expected, dict) else None
    if _HEX64.fullmatch(_as_text(expected_artifact)) and artifact_hash != expected_artifact:
        reasons.append(_reason('ARTIFACT_SHA256_MISMATCH', receipt))
    return reasons


def validate_identity(observed, expected, build_receipts, artifact_bytes_by_path=None):
    """Validate one runtime record against expected deployment and build evidence."""
    shape = _shape_reasons(observed)
    if shape:
        state = 'LEGACY_UNVERIFIED' if any(r['code'] in ('IDENTITY_MISSING', 'IDENTITY_INCOMPLETE') for r in shape) else 'FAIL'
        return _result(state, shape, observed if isinstance(observed, dict) else None)
    reasons = []
    reasons.extend(_expected_reasons(observed, expected))
    reasons.extend(_artifact_reasons(observed, expected, build_receipts, artifact_bytes_by_path))
    return _result('PASS' if not reasons else 'FAIL', reasons, observed)


def validate_identity_batch(records, expected, build_receipts, artifact_bytes_by_path=None):
    """Validate a collection and reject silent mixing of attach/repin epochs."""
    if not records:
        return _result('LEGACY_UNVERIFIED', [_reason('RUNTIME_IDENTITY_MISSING', 'no runtime identity records')])
    reasons = []
    states = []
    for record in records:
        result = validate_identity(record, expected, build_receipts, artifact_bytes_by_path)
        states.append(result['state'])
        reasons.extend(result['reasons'])
    groups = {}
    for record in records:
        if isinstance(record, dict):
            groups.setdefault(_identity_key(record), set()).add(record.get('attach_epoch'))
    for key, epochs in groups.items():
        if len(epochs) > 1:
            reasons.append(_reason('MIXED_ATTACH_EPOCHS', '%s' % (sorted(epochs),)))
    if reasons:
        state = 'LEGACY_UNVERIFIED' if any(s == 'LEGACY_UNVERIFIED' for s in states) else 'FAIL'
        return _result(state, reasons, records)
    return _result('PASS', [], records)


def _expected_for_record(expected, record):
    if isinstance(expected, dict) and 'account_login' in expected:
        return expected
    if not isinstance(expected, dict) or not isinstance(record, dict):
        return None
    return expected.get('%s|%s' % (record.get('account_login'), record.get('magic')))


def validate_identity_set(records, expected_by_key, build_receipts, artifact_bytes_by_path=None):
    """Validate the current fleet without collapsing historical attach epochs into it.

    The expected mapping owns the active account|magic universe and active attach epoch. Records
    from older epochs are returned separately as historical evidence; they never satisfy current
    coverage and never get merged into the current result.
    """
    if not records:
        if isinstance(expected_by_key, dict) and expected_by_key.get(EXPECTED_ERRORS_KEY):
            return _result('FAIL', [_reason('EXPECTED_MAPPING_INVALID', error)
                                    for error in expected_by_key[EXPECTED_ERRORS_KEY]], [])
        return _result('LEGACY_UNVERIFIED', [_reason('RUNTIME_IDENTITY_MISSING', 'no runtime identity records')], [])
    expected_map = expected_by_key if isinstance(expected_by_key, dict) else {}
    if 'account_login' in expected_map and 'magic' in expected_map:
        expected_map = {'%s|%s' % (expected_map.get('account_login'), expected_map.get('magic')): expected_map}
    mapping_errors = expected_map.get(EXPECTED_ERRORS_KEY, [])
    expected_entries = dict((key, value) for key, value in expected_map.items()
                            if key != EXPECTED_ERRORS_KEY)
    annotated = []
    historical = []
    reasons = []
    states = []
    by_key = {}
    for record in records:
        by_key.setdefault(_identity_key(record), []).append(record)

    if mapping_errors:
        reasons.extend(_reason('EXPECTED_MAPPING_INVALID', error) for error in mapping_errors)

    for key, expected in expected_entries.items():
        if not isinstance(expected, dict):
            reasons.append(_reason('EXPECTED_MAPPING_INVALID', str(key)))
            continue
        if not _EPOCH.fullmatch(_as_text(expected.get('attach_epoch'))):
            reasons.append(_reason('EXPECTED_ATTACH_EPOCH_INVALID', str(key)))
        current = [record for record in by_key.get(key, [])
                   if isinstance(record, dict) and record.get('attach_epoch') == expected.get('attach_epoch')]
        if not current:
            code = 'CURRENT_EPOCH_EVIDENCE_MISSING' if by_key.get(key) else 'EXPECTED_IDENTITY_MISSING'
            reasons.append(_reason(code, str(key)))
        if len(current) > 1:
            reasons.append(_reason('DUPLICATE_CURRENT_IDENTITY', str(key)))
        for record in current:
            result = validate_identity(record, expected, build_receipts, artifact_bytes_by_path)
            item = dict(record)
            item['validation_state'] = result['state']
            item['validation_reasons'] = result['reasons']
            annotated.append(item)
            states.append(result['state'])
            reasons.extend(result['reasons'])

    expected_keys = set(expected_entries)
    for record in records:
        key = _identity_key(record)
        expected = expected_entries.get(key)
        if key in expected_keys and isinstance(expected, dict) and record.get('attach_epoch') != expected.get('attach_epoch'):
            item = dict(record) if isinstance(record, dict) else {}
            item['validation_state'] = 'HISTORICAL'
            item['validation_reasons'] = [_reason('PRIOR_ATTACH_EPOCH',
                                                  'expected=%s observed=%s' %
                                                  (expected.get('attach_epoch'), record.get('attach_epoch')))]
            historical.append(item)
            continue
        if key not in expected_keys:
            item = dict(record) if isinstance(record, dict) else {}
            item['validation_state'] = 'FAIL'
            item['validation_reasons'] = [_reason('UNEXPECTED_IDENTITY', str(key))]
            annotated.append(item)
            states.append('FAIL')
            reasons.extend(item['validation_reasons'])

    # A current result is a single expected epoch per binding. When callers provide a raw batch
    # rather than a deployment partition, retain the existing mixed-epoch guard as a hard fail.
    current_records = [record for record in records if isinstance(record, dict)
                       and _identity_key(record) in expected_keys and any(
                           isinstance(expected_entries.get(_identity_key(record)), dict) and
                           record.get('attach_epoch') == expected_entries[_identity_key(record)].get('attach_epoch')
                           for _ in [0])]
    groups = {}
    for record in current_records:
        groups.setdefault(_identity_key(record), set()).add(record.get('attach_epoch'))
    for key, epochs in groups.items():
        if len(epochs) > 1:
            reasons.append(_reason('MIXED_ATTACH_EPOCHS', '%s' % (sorted(epochs),)))
            for item in annotated:
                if _identity_key(item) == key:
                    item['validation_state'] = 'FAIL'
                    item['validation_reasons'].append(_reason('MIXED_ATTACH_EPOCHS', '%s' % (sorted(epochs),)))

    if reasons:
        state = 'LEGACY_UNVERIFIED' if any(s == 'LEGACY_UNVERIFIED' for s in states) else 'FAIL'
        return dict(_result(state, reasons, annotated), historical=historical)
    if not expected_entries:
        return dict(_result('FAIL', [_reason('EXPECTED_MAPPING_EMPTY', 'no active expected deployments')], annotated),
                    historical=historical)
    return dict(_result('PASS', [], annotated), historical=historical)


def load_build_receipts(path):
    """Load the append-only JSONL receipt registry and reject duplicate receipts."""
    records = {}
    with open(path, 'r', encoding='utf-8') as handle:
        for lineno, line in enumerate(handle, 1):
            line = line.strip()
            if not line:
                continue
            record = json.loads(line)
            receipt = record.get('build_receipt')
            if receipt in records:
                raise ValueError('duplicate build_receipt at line %d: %s' % (lineno, receipt))
            records[receipt] = record
    return records


def _read_json(path, fallback):
    if not path or not os.path.isfile(path):
        return fallback
    with open(path, 'r', encoding='utf-8-sig') as handle:
        value = json.load(handle)
    return fallback if value is None else value


def main(argv):
    if argv[1:2] == ['derive-first-trade']:
        if len(argv) not in (4, 5):
            print('usage: runtime_identity.py derive-first-trade <identity.json> <deals.json> [--stale]')
            return 2
        identity = _read_json(argv[2], {})
        deals = _read_json(argv[3], [])
        result = derive_first_trade(identity, deals, deals_fresh=(len(argv) == 4))
        print(json.dumps(result, sort_keys=True))
        return 0 if result['state'] in (FORWARD_AWAITING, FORWARD_VERIFIED) else 1
    if len(argv) != 5 or argv[1] != 'verify-batch':
        print('usage: runtime_identity.py verify-batch <records.json> <expected.json> <build_receipts.jsonl>')
        return 2
    records = _read_json(argv[2], [])
    expected = _read_json(argv[3], {})
    registry = load_build_receipts(argv[4]) if os.path.isfile(argv[4]) else {}
    artifact_bytes = {}
    for record in registry.values():
        artifact_path = record.get('artifact_path') if isinstance(record, dict) else None
        if isinstance(artifact_path, str) and os.path.isfile(artifact_path):
            with open(artifact_path, 'rb') as artifact:
                artifact_bytes[artifact_path] = artifact.read()
    result = validate_identity_set(records, expected, registry, artifact_bytes)
    print(json.dumps(result, sort_keys=True))
    return 0 if result['state'] == 'PASS' else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv))
