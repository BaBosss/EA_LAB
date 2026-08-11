"""Failure-first acceptance tests for the runtime identity contract."""

import hashlib
import os
import sys
import datetime as _dt

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from runtime_identity import (  # noqa: E402
    IDENTITY_SCHEMA,
    BUILD_RECEIPT_SCHEMA,
    validate_identity,
    validate_identity_batch,
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


def base_identity(receipt, config='c' * 64, **overrides):
    value = {
        'schema': IDENTITY_SCHEMA,
        'account_login': '100000001',
        'magic': '900001',
        'ea_logical_identity': 'EA_X_TEST',
        'build_receipt': receipt,
        'config_fingerprint': config,
        'config_fingerprint_version': 'cfgfp-v1',
        'symbol': 'EURUSDm',
        'timeframe': 'PERIOD_H1',
        'attach_epoch': 'epoch-1',
        'first_trade_epoch': None,
        'evidence_timestamp': _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat().replace('+00:00', 'Z'),
        'evidence_source': 'EA_RUNTIME_COMMON_FILE',
    }
    value.update(overrides)
    return value


def main():
    receipt = 'br-' + ('a' * 32)
    artifact_bytes = b'compiled artifact for runtime identity tests\n'
    artifact_hash = hashlib.sha256(artifact_bytes).hexdigest()
    artifacts = {
        receipt: {
            'schema': BUILD_RECEIPT_SCHEMA,
            'build_receipt': receipt,
            'ea_logical_identity': 'EA_X_TEST',
            'artifact_path': 'fixture/EA_X_TEST.ex5',
            'artifact_sha256': artifact_hash,
            'config_fingerprint': 'c' * 64,
            'config_fingerprint_version': 'cfgfp-v1',
            'source_path': 'fixture/EA_X_TEST.mq5',
            'source_sha256': 'd' * 64,
        }
    }
    expected = {
        'account_login': '100000001',
        'magic': '900001',
        'ea_logical_identity': 'EA_X_TEST',
        'build_receipt': receipt,
        'config_fingerprint': 'c' * 64,
        'config_fingerprint_version': 'cfgfp-v1',
        'symbol': 'EURUSDm',
        'timeframe': 'PERIOD_H1',
        'source_sha256': 'd' * 64,
        'artifact_sha256': artifact_hash,
    }

    def result(observed, exp=expected, registry=artifacts, bytes_by_path=None):
        return validate_identity(
            observed,
            exp,
            registry,
            {'fixture/EA_X_TEST.ex5': artifact_bytes} if bytes_by_path is None else bytes_by_path,
        )

    good = result(base_identity(receipt), bytes_by_path={'fixture/EA_X_TEST.ex5': artifact_bytes})
    check('valid fully bound identity -> PASS', good['state'] == 'PASS', str(good))

    for label, field, value in [
        ('account mismatch -> fail-visible', 'account_login', '100000002'),
        ('magic mismatch -> fail-visible', 'magic', '900002'),
        ('EA logical identity mismatch -> fail-visible', 'ea_logical_identity', 'EA_Y_TEST'),
        ('build receipt mismatch -> fail-visible', 'build_receipt', 'br-' + ('b' * 32)),
        ('config fingerprint mismatch -> fail-visible', 'config_fingerprint', 'd' * 64),
        ('config fingerprint schema/version unknown -> fail-visible', 'config_fingerprint_version', 'cfgfp-v9'),
        ('symbol mismatch -> fail-visible', 'symbol', 'GBPUSDm'),
        ('timeframe mismatch -> fail-visible', 'timeframe', 'PERIOD_H4'),
    ]:
        bad = base_identity(receipt, **{field: value})
        check(label, result(bad)['state'] != 'PASS', str(result(bad)))

    wrong_artifact = dict(artifacts)
    wrong_artifact[receipt] = dict(artifacts[receipt], artifact_sha256='e' * 64)
    bad_artifact = validate_identity(
        base_identity(receipt), expected, wrong_artifact,
        {'fixture/EA_X_TEST.ex5': artifact_bytes})
    check('expected artifact/build receipt mismatch -> fail-visible', bad_artifact['state'] != 'PASS', str(bad_artifact))

    unknown_version = base_identity(receipt, config_fingerprint_version='cfgfp-v9')
    check('unknown config version cannot be healthy', result(unknown_version)['state'] != 'PASS')

    wrong_build = base_identity('br-' + ('b' * 32))
    check('same semantic config fingerprint with wrong build -> not healthy', result(wrong_build)['state'] != 'PASS')
    wrong_config = base_identity(receipt, config='d' * 64)
    check('same build with wrong config -> not healthy', result(wrong_config)['state'] != 'PASS')

    pre = base_identity(receipt, attach_epoch='epoch-1', first_trade_epoch=None)
    post = base_identity(receipt, attach_epoch='epoch-1', first_trade_epoch='epoch-1')
    wrong_first = base_identity(receipt, attach_epoch='epoch-1', first_trade_epoch='epoch-2')
    check('pre-attach historical trade does not create first-trade epoch', result(pre)['state'] == 'PASS')
    check('first trade is bound to its attach epoch', result(post)['state'] == 'PASS')
    check('first-trade epoch mismatch -> fail-visible', result(wrong_first)['state'] != 'PASS')
    mixed = validate_identity_batch(
        [pre, base_identity(receipt, attach_epoch='epoch-2')],
        expected,
        artifacts,
        {'fixture/EA_X_TEST.ex5': artifact_bytes},
    )
    check('pre-repin and post-repin evidence cannot mix', mixed['state'] != 'PASS', str(mixed))

    missing = validate_identity({}, expected, artifacts)
    check('missing identity cannot become green', missing['state'] != 'PASS', str(missing))
    check('legacy evidence remains explicit non-green', missing['state'] == 'LEGACY_UNVERIFIED', str(missing))

    if FAIL:
        print('FAIL %d/%d' % (PASS, PASS + FAIL))
        return 1
    print('PASS %d/%d' % (PASS, PASS))
    return 0


if __name__ == '__main__':
    sys.exit(main())
