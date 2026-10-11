# EA_LAB Autonomous Orchestrator V1 — T3-B Signed Proof Source Security

**SOURCE-ONLY candidate. NOT a runtime/installed producer/activation approval.** One existing Main CT. Baseline `e4107a1c144709f8cdc0a062179734da5739cdf3`. This contract does not launch jobs, install a Scheduled Task, open a gateway, sign production receipts, create private keys or attach to MT5.

## Component 1: source-only Ed25519 proof verifier

`tools/lnwjud/job_control_runtime_v1/orchestrator_signed_proof_verifier.cjs` exports `createSignedProofVerifier({anchors,maxAgeMs=120000})` and `messageForProof(proof,key_id)`. The verifier uses only Node built-in `crypto.createPublicKey`, `createHash` and `verify`. No filesystem/network/process/Registry calls. Its only output is a boolean verification decision. Five exact types: `git`, `registry`, `leases`, `jobs`, `tasks`.

Every source type requires an independent **pre-approved trust anchor**, with exact fields `producer_id, key_id, public_key_pem, valid_from_utc, valid_until_utc, revoked=false`; a key must be a public PEM block of Ed25519 type (private PEM and RSA keys rejected). Trust-anchor authenticity is an **EXTERNAL HARD STOP**: this source does not discover/approve anchors, keys, issuer identities, roles or their revocation. The signed proof uses the unchanged exact `EA_LAB_TRUSTED_SNAPSHOT_PROOF_V1` 8-field envelope. Attestation string `ed25519:<key_id>:<base64url 64-byte signature>`; signature is computed over `EA_LAB_ORCHESTRATOR_SIGNED_PROOF_V1\n` plus a fixed JSON tuple of schema, source type, producer ID, source HEAD, source TREE, SHA256 of raw bytes, captured UTC, key ID, and newline. The function accepts no optional fields or caller-provided authenticated flag.

Verification enforces fixed schema, source-specific producer identity, exact lower-case 40-char Git hashes and SHA256, Ed25519 signature against pinned public key, exact bounded UTC calendar with Z suffix, age <= 120 seconds by default, and key validity/explicit revocation. Invalid, unsigned, stale, future, wrong-family, key-substituted, source/type-substituted or tampered input returns literal `false`. Keys are generated transiently in unit tests only, never saved as a real issuer credential.

**LIMITATION:** signature correctness establishes that bytes were signed by the associated private key; it does not establish that a real-world producer operated within an approved Registry/owner/lease. A malicious trusted signer can still sign misleading observations. Without a **durable CAS replay ledger**, even a valid two-minute signature can be replayed; explicit negative fixture documents this current limitation. A live production ingress must add owner-authenticated monotonic sequence, durable anchored replay protection, expiry/lease issuer and compromise recovery before any dispatch authority.

## Component 2: previously accepted T3-A boundary hardening

`orchestrator_trusted_snapshot_adapter.cjs` is modified only to close two LOW findings from previous exact-head review: pass a defensive copy of `Buffer` to injected verifier, re-check SHA after verifier, and reject a proof captured more than **120 seconds** from the authoritative Git snapshot `captured_utc`. Original per-proof 15-minute freshness and exact Git HEAD/TREE, Registry, lease and process checks remain. On mutation/skew, output must be `UNKNOWN` rather than `READY`; no new process side-effect.

## Proof and tests

TDD uses exact original test/negative fixtures, first RED and final GREEN with full raw logs/EXIT/status preserved. New signed proof source test suite has 37 tests, including five Ed25519 authentic positives, tampered hash/signature/proof/source/key negatives, revoked/expired/invalid keys and signature replay limitation; two additional red-first fixtures reproduce the mutable Buffer and temporal skew fail-open behaviors in the accepted T3-A adapter.

Required pre-integration regression: new 37, previous T3-A 40, prior Orchestrator Reconciler 41, existing JobControl + production adapter/fault suites, and Python Harness 12, all on frozen exact HEAD/TREE. One independent fresh exact-head read-only scrutiny checks changed adapter/new crypto/negative tests/doc. Only the original Main CT may perform normal fast-forward integration after review and postcondition, never bypass Git hooks or conflate acceptance axes.

## T3 runtime hard stops and owner-specific activation sheet

`SOURCE_ACCEPTED` does **not** imply `RUNTIME_ACCEPTED`. Do not install Task Scheduler, system service, production JobControl, autonomous gateway, Hermes cron, daemon, Monitor publisher, actual signing private key, nonzero external provider spend, MT5/optimizer, Factory/Real Submit, DEMO/LIVE or trading. The owner must separately authorize an **exact** installed consumer/launcher/principal, executable+configuration SHA256, publisher authority, signing key custody/cert rotation, per-source trust anchor, durable resource lease, replay ledger, process PID/creation/heartbeat and postcondition, crash and rollback rehearsal, watchdog, provider/model/auth/quota/cost ceiling, timeline and stop conditions. This source phase supplies none of those missing identities by assumption.

### T3-C controlled smoke (prospective only)

Only after separate exact admission, exercise one synthetic read-only READY, one forged negative and one lease-contention negative, persist acceptance receipts, verify no paid calls, and restore exact installed preimage SHA from a dry-run rollback fixture. A production-installed process must be identity-proven by real process observer and current source binding. No unattended 24/7 claim until runtime, restart and Monitor acceptance actually pass.

## Governance and handoff

Use the single Main CT, Registry path+WIP admission, original budgets and accepted `AGENTS.md`/R3/R4.2 contracts. Preserve the active W2 and B17 incumbents. Keep failed RED receipts and two LOW findings visible. No separate strategy/risk governance or parallel CT. This doc is SOURCE CONTRACT only and does not supersede owner hard stops.
