# T3 P4 — Test-only producer contract (source only)

**Status:** fixture contract implemented; production producer remains NOT QUALIFIED. This file and its paired test add no installed process, producer, scheduler, IPC, key store, or runtime authority.

## Purpose and boundary

The accepted P3 API verifies a signed claim and the evidence bytes in one process before an isolated SQLite write. P3 deliberately does not implement producer key custody or a real signed-observation producer. This P4 candidate adds an executable fixture contract in `tools/lnwjud/job_control_runtime_v1/test_orchestrator_test_only_producer_contract.cjs` so future producer work has a concrete shape and negative cases.

The test helper creates a fresh Ed25519 key pair in process memory for each test context. Its private key remains inside the fixture closure and is never serialized, written to disk, installed, or used outside the test process. The exported fixture surface exposes only a public anchor and an `observe()` function. All fixture anchors use the existing `T3C_P2_ISOLATED_SIGNED_CLAIM` role. These keys and claims are synthetic test data; they are not production trust.

Each signed envelope binds the P2 envelope schema, signer and key IDs, capture time, and the exact P1 claim tuple: source HEAD/TREE, resource, owner, lease ID and expiry, sequence, idempotency key, evidence SHA256, and `can_execute=false` / `can_submit=false`. The verifier receives the envelope and evidence through the existing P3 `verifyAndRecord()` API. The test clock is injected and fixed to the fixture window; this does not qualify a wall clock or lease issuer.

## Negative cases

The 10 tests cover:

1. A complete ephemeral signed claim is accepted as `VERIFIED_AND_RECORDED_READ_ONLY`; execute/submit stay false.
2. Post-sign owner mutation is rejected with no history write.
3. Replacing the evidence bytes fails the signed digest check.
4. A validly signed claim for a different source HEAD is rejected.
5. An expired lease is rejected before persistence.
6. Exact proof replay after reopening the P3 API is rejected; one history row remains.
7. Sequence regression and a foreign active owner/lease cannot replace the current fixture claim.
8. A revoked trust anchor is unqualified.
9. A production-like or otherwise wrong signer role is unqualified.
10. An extra envelope field fails closed before persistence.

The new test was RED before the fixture implementation. RED source SHA256: `45a0c5e8c61462550b2e28e8f543dcc77ce3901f5b32d64b0209f0ef470f71bf`; command `node --test tools/lnwjud/job_control_runtime_v1/test_orchestrator_test_only_producer_contract.cjs`; exit 1; raw output SHA256 `c47766a29d53e59c1efc2f8f5c51f303b042a0625e69fbe10c59ade4ffa0d005`.

GREEN source SHA256: `3fd011bf57ce51d8320e32ff3bc2c1cfcaa8e93c0fda3bf558ae945fc0ae1cdc`; Node `v24.19.0`, `C:\Program Files\nodejs\node.exe`; command as above; 10 tests, 10 passed, 0 failed; exit 0; raw output SHA256 `6c0a07c8c4ea3bd3b6675a8ddc19483f2d7706465c6b23e04906791c9b0d7892`. Exact RED/GREEN raw logs and receipts are in the sibling evidence directory.

## Qualification not established

This fixture does not prove a real producer identity, principal, executable/source lineage, authority, or actual signed observation receipt. No approved issuer, production public-key anchor, private-key custodian, rotation/revocation process, authenticated producer IPC, production OS principal, ACL-protected database, exclusive production lease issuer/resource/CAS receipt, installed consumer/config, PID/heartbeat/terminal receipt, Monitor acceptance, or rollback receipt was found in the observations for this task. The test uses an OS temporary directory and an injected clock. It does not test hardware power loss or establish a production filesystem ACL.

The prior P3 independent review findings remain visible and unfixed: post-COMMIT readback mismatch can return UNKNOWN after a row may have committed; path checks remain vulnerable to a filesystem TOCTOU window without kernel-level controls; `historyCount()` uses `BEGIN IMMEDIATE` and may create schema/hold a write lock. The separate P1 isolated SQLite regression passed 25/25 and includes two-process contention with exactly one winner, crash-before-COMMIT rollback (child exit 17, zero committed rows after restart, then a later claim accepted), crash-after-COMMIT retention (child exit 19, one row after restart, replay blocked), restart/readback, WAL+FULL verification, symlink-root rejection, and corrupt-storage failure. That suite exercises the earlier P1 `SQLiteReplayLedger`, so it does not establish a distinct pre-COMMIT crash result for the P3 in-process writer. Hardware power-loss durability remains NOT PROVEN. Production ACL/access-denial behavior remains NOT PROVEN because no qualified production principal or installed service exists for that test.

All outcomes are source/test evidence only. No install or activation is allowed; no claim here authorizes execution, submission, trading, MT5, Factory, DEMO, or LIVE use.
