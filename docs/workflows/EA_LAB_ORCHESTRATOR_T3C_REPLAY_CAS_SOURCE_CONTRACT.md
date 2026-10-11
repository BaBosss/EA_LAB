# EA_LAB — Orchestrator V1 T3-C Replay/CAS Lease Guard (SOURCE ONLY)

**Status: DRAFT_UNREVIEWED until exact HEAD acceptance. Not installed; not approved for autonomous runtime, scheduling, MT5, Factory or LIVE.** One Main CT, based on canonical `20eac360849f32bfbceaba9f6a9a99e8b809aaf6`.

## Scope and limits

`createReplayLeaseGuard({store, verifier, clock, source_head, source_tree}).record(claim)` is an **inert, synchronous evidence-recording advisory**. It has NO filesystem/process/network/crypto-signing/Registry-writing/Scheduled Task/JobControl dispatch imports or capabilities. Its *only* mutation occurs through externally injected `store.compareAndSwap`; for production use the store MUST already be separately qualified as **durable, atomic, exclusive and authenticated to one preapproved owner**. **An in-memory mock CAS is NOT durable CAS evidence.** The injected `verifier.verifyClaim` is not an identity proof by itself; it MUST be bound externally to the accepted T3-B Ed25519 signed proof, including issuer authorization and exact claim body. There is no production signer private key or trust anchor selection in this milestone.

Exact claim `EA_LAB_T3C_REPLAY_CAS_CLAIM_V1` contains: `schema, source_head, source_tree, lane_id, task_id, resource, owner, lease_id, lease_until_utc, sequence, idempotency_key, signed_proof_sha256, can_execute=false, can_submit=false`. No extraneous keys or alternate time offsets. Exact source SHA/TREE and UTC time bound are mandatory. A lease must expire after the current time and no later than 5 minutes. Signed verifier must return literal boolean `true`.

Store API: `read(resource) -> {version,record}`, `compareAndSwap({key,expected_version,next_record}) -> {applied,version}`. After CAS success it MUST read again and match **both** returned version and the full record, or return `UNKNOWN`. An injected store is not qualified by its function names or a self-reported `durable` flag: independent persisted WAL/fsync, crash, replay and cross-process atomicity remain external T3-C requirements. A CAS loser returns `WAITING_RESOURCE`. Malformed record or ambiguous IO error returns `UNKNOWN` without blind retry.

The gate rejects duplicate `idempotency_key`, re-used signed proof digest, non-monotonic sequence, foreign unexpired owner/lease, invalid expiry, unknown canonical source and source-tree drift. Even if recording succeeds, return **`RECORDED_READ_ONLY`**, never `READY_TO_EXECUTE` or any permission to issue a job; output always has `can_execute=false`, `can_submit=false` and `scope=EVIDENCE_RECORD_ONLY`. An accepted proof for one resource is not authorization for trading or another resource.

## Deterministic tests

A new `test_orchestrator_replay_lease_guard.cjs` uses injected in-memory mock CAS to exercise 37 cases: positive CAS/readback, same evidence replay, signed proof refusal, expiry/foreign owner, stale sequence, concurrent version contention, simulated IO errors, corrupted readback and hard stop to avoid trading/submit. One **actual RED** must be recorded before implementation; preserve all intermediate failures, run the final green and impacted prior Orchestrator/T3-A/T3-B/JobControl/adapter/Harness regressions on the exact frozen candidate. Independent exact-head reviewer (not the author) must scrutinize source/test/docs, including whether returned readback is logically sufficient and where real store trust is missing. Main CT only integrates accepted source.

## T3-C real activation still missing

No installed producer principal/key custody, authenticated trust-anchor issuance, persisted replay ledger or WAL/fsync, cross-process CAS/lease issuer, actual process PID+creation+heartbeat, terminal postcondition, installed launcher/task/executable+config SHA, rollback before-image/restoration proof, provider/quota/cost cap, rate limit, Monitor health or **exact Owner task-level activation decision** is demonstrated here. Keep original incumbent Monitor, lnwjud, W2 and B17 lanes undisturbed; never run a second gateway/cron/runner. Synthetic tests do not qualify shutdown/restart or concurrency across separate OS processes.

**ONE NEXT:** Existing Main CT must qualify a real trusted producer + durable atomic store against actual filesystem/registry ownership, test two competing separate OS processes and crash/restart on an isolated acceptance environment, freeze *exact* installation/rollback/leased resource identity, then authorize one controlled read-only runtime smoke; until then `T3C_RUNTIME=BLOCKED`.
