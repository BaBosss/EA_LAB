"""Failure-first ORDER-602 authority-separation tests.

These tests exercise the semantic seam independently of the append-only ledger corpus.  An
attestation may be a perfectly valid record while remaining non-authoritative; only a resolved,
action-bound OwnerRef may cross the owner-authorization boundary.
"""
import copy
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)

import check_coverage_transfer as coverage  # noqa: E402
import check_s2a_attestation as att       # noqa: E402


AUTH_REF = {
    'entity': 'OwnerRef',
    'owner_type': 'taskboard_order',
    'path': 'AGENT_TASKBOARD.md',
    'commit_oid': '804c2551e640efd03238ee6776cd2db94edc35ed',
    'blob_oid': '456b8b8ca397d00cf31e16d1dbcd38f3180b0ed5',
    'raw_sha256': 'b589ed1c79f6f5ffc14ad5a49d774c0faf5508f27d1f5d0372b235769e3cff38',
    'anchor': 'unblocks',
}


def row(**overrides):
    value = {
        'bundle_sha256': att.bundle_digest(),
        'current_owner': 'MASTER_BACKLOG.md',
        'decision': 'APPROVED',
        'signer': 'arbitrary display text',
        'decided_at': '2026-08-11T00:00',
        'reason': 'informational attestation',
    }
    value.update(overrides)
    return value


def expect(label, condition, detail=''):
    if not condition:
        raise AssertionError('%s: %s' % (label, detail))
    print('[OK ] %s' % label)


def main():
    os.chdir(ROOT)

    # A: arbitrary signer text + APPROVED is never an owner authorization.
    status = att.authorization_status(row(), require=True, action='coverage_transfer')
    expect('A arbitrary signer + no ref cannot authorize owner-reserved action',
           status['authorization_state'] == 'NON_AUTHORITATIVE' and status['problems'], status)

    # B: the same row remains a valid informational attestation.
    status = att.authorization_status(row(), require=False, action='coverage_transfer')
    expect('B informational APPROVED attestation remains valid without auth',
           not status['problems'] and status['authorization_state'] == 'NON_AUTHORITATIVE' and
           status['signer_role'] == 'display_only', status)

    # C: owner-authorization consumers fail closed when the reference is absent.
    expect('C auth-sensitive consumer fails closed on absent ref',
           any(p.startswith('AUTH-ABSENT') for p in
               att.authorization_status(row(), require=True,
                                       action='coverage_transfer')['problems']))

    # D: a pre-existing, resolved taskboard owner record is accepted.
    status = att.authorization_status(row(authorization_ref=copy.deepcopy(AUTH_REF)),
                                      require=True, action='coverage_transfer')
    expect('D resolved authorization_ref passes',
           status['authorization_state'] == 'AUTHORIZED_BY_RESOLVED_REF' and
           not status['problems'], status)

    # E: a historical row without proof is explicit legacy/non-authoritative state.
    status = att.authorization_status(row(decided_at='2026-07-31T02:10'), require=False,
                                      action='coverage_transfer')
    expect('E historical no-ref row is legacy non-authoritative',
           status['legacy'] is True and status['authorization_state'] == 'NON_AUTHORITATIVE',
           status)

    # F: OwnerRef R1-R4 remain the resolver's authority; a forged blob/hash is refused.
    forged = copy.deepcopy(AUTH_REF)
    forged['raw_sha256'] = '0' * 64
    status = att.authorization_status(row(authorization_ref=forged), require=True,
                                      action='coverage_transfer')
    expect('F forged authorization_ref is refused by the existing resolver',
           status['authorization_state'] == 'INVALID_AUTHORIZATION_REF' and
           any('R3' in p for p in status['problems']), status)

    # G: ordinary engineering attestations do not acquire an unnecessary owner-signature gate.
    status = att.authorization_status(row(current_owner='AGENT_TASKBOARD.md',
                                           reason='engineering review'), require=False,
                                      action='engineering_review')
    expect('G ordinary engineering workflow remains informational',
           not status['problems'] and status['authorization_state'] == 'NON_AUTHORITATIVE',
           status)

    # The consumer must invoke the auth-required interface, not the informational checker.
    calls = []
    saved = coverage.subprocess.run

    class Result:
        returncode = 1
        stdout = b'AUTH-ABSENT\n'

    def fake_run(cmd, **kwargs):
        calls.append(cmd)
        return Result()

    coverage.subprocess.run = fake_run
    try:
        problems = []
        coverage.a8_attestation_still_valid(problems)
    finally:
        coverage.subprocess.run = saved
    expect('A8 invokes the authorization-required attestation consumer',
           any('--require-authorization' in cmd for cmd in calls), calls)
    expect('A8 reports owner authorization failure deterministically',
           any('owner authorization' in p.lower() and 'AUTH-ABSENT' in p for p in problems),
           problems)

    print('AUTHORIZATION TESTS: PASS')
    return 0


if __name__ == '__main__':
    sys.exit(main())
