"""Canonical validator checks for mixed current epochs and deal/snapshot reconciliation."""

import datetime as _dt
import hashlib
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from runtime_identity import (  # noqa: E402
    BUILD_RECEIPT_SCHEMA,
    IDENTITY_SCHEMA,
    validate_epoch_evidence,
    validate_identity_batch,
    validate_identity_set,
)


def identity(receipt, epoch, first=None):
    return {
        'schema': IDENTITY_SCHEMA,
        'account_login': '100000001', 'magic': '900001',
        'ea_logical_identity': 'EA_X_TEST', 'build_receipt': receipt,
        'config_fingerprint': 'c' * 64, 'config_fingerprint_version': 'cfgfp-v1',
        'symbol': 'EURUSDm', 'timeframe': 'PERIOD_H1',
        'attach_epoch': epoch, 'first_trade_epoch': first,
        'evidence_timestamp': _dt.datetime.now(_dt.timezone.utc).isoformat().replace('+00:00', 'Z'),
        'evidence_source': 'EA_RUNTIME_COMMON_FILE',
    }


def main():
    receipt = 'br-' + 'a' * 32
    artifact = b'epoch fixture artifact'
    artifact_hash = hashlib.sha256(artifact).hexdigest()
    source_hash = 'd' * 64
    expected = {
        '100000001|900001': {
            'account_login': '100000001', 'magic': '900001', 'ea_logical_identity': 'EA_X_TEST',
            'build_receipt': receipt, 'config_fingerprint': 'c' * 64,
            'config_fingerprint_version': 'cfgfp-v1', 'symbol': 'EURUSDm', 'timeframe': 'PERIOD_H1',
            'attach_epoch': 'epoch-2', 'source_sha256': source_hash, 'artifact_sha256': artifact_hash,
        }
    }
    registry = {receipt: {
        'schema': BUILD_RECEIPT_SCHEMA, 'build_receipt': receipt, 'ea_logical_identity': 'EA_X_TEST',
        'artifact_path': 'fixture/epoch.ex5', 'artifact_sha256': artifact_hash,
        'source_path': 'fixture/not-deployed.mq5', 'source_sha256': source_hash,
    }}
    artifacts = {'fixture/epoch.ex5': artifact}
    checks = []
    mixed = validate_identity_batch(
        [identity(receipt, 'epoch-1'), identity(receipt, 'epoch-2')],
        expected['100000001|900001'], registry, artifacts)
    checks.append(('J current evidence unit with mixed epochs -> FAIL', mixed['state'] != 'PASS' and
                   any(r['code'] == 'MIXED_ATTACH_EPOCHS' for r in mixed['reasons'])))
    old_deal = validate_epoch_evidence('epoch-2', {
        'attach_epoch': 'epoch-1', 'ticket': '7001', 'deal_timestamp': '2026.08.11 10:00:00'
    }, 'deal')
    checks.append(('J old deal evidence cannot satisfy new epoch', old_deal['state'] == 'FAIL'))
    current_snapshot = validate_epoch_evidence('epoch-2', {'attach_epoch': 'epoch-2', 'balance': '100'}, 'snapshot')
    checks.append(('current AccountSnapshot epoch reconciles', current_snapshot['state'] == 'PASS'))
    malformed = validate_identity_set(
        [identity(receipt, 'epoch-2')],
        {'100000001|900001': {'account_login': '100000001', 'magic': '900001'}},
        registry, artifacts)
    checks.append(('malformed expected mapping cannot become green', malformed['state'] != 'PASS'))
    for label, ok in checks:
        print('[PASS] ' + label if ok else '[FAIL] ' + label)
    print('PASS %d/%d' % (sum(1 for _, ok in checks if ok), len(checks)))
    return 0 if all(ok for _, ok in checks) else 1


if __name__ == '__main__':
    sys.exit(main())
