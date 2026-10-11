# EA_LAB — T3-C-P3 In-process Verified Signed SQLite, Source-only

**Authority:** ONE existing Main CT; accepted parent HEAD 30600b20969978ff398027b69cfebd2dfac5f4fc. Owner permits read-only qualification and additional Paid API ceiling USD 0. No authorization for production install, task/service/cron, MT5/Factory/Real Submit, DEMO/LIVE/trading or risk changes.

## Source trust boundary

The new orchestrator_inprocess_signed_sqlite.cjs composes the already accepted T3-C-P2 createSignedClaimIngress validator with native Node.js SQLite WAL+FULL **inside the same OS process**, not the former test-only unauthenticated Python subprocess. The only exported factory returns frozen methods verifyAndRecord and historyCount. Internal database writer/ledger callback is private and not separately exported. A caller using this module's advertised public interface cannot skip Ed25519 verification to persist a claim.

The P2 validator checks a complete signed tuple: source HEAD/TREE, resource, owner, lease, sequence, idempotency, issuer/key, UTC window, and raw evidence SHA256. The module copies the public-key anchor into a closure to prevent late external mutation. All green results are READ_ONLY advisory with can_execute=false and can_submit=false. Any ambiguous SQLite failure becomes UNKNOWN, never an execution permission.

SQLite stores history-wide unique proof digests and idempotency keys, and a per-resource owner/lease/monotonic sequence. All writes are guarded by BEGIN IMMEDIATE; journal_mode=WAL and synchronous=FULL are verified on actual local Windows SQLite. Commit is followed by full state/history readback. Tests execute two independent Windows OS child PIDs competing for one resource, an abruptly exited child after COMMIT, restart replay, malformed/unsigned child input, corrupt DB, wrong issuer, forged owner, extra fields, forbidden execute, stale sequence, foreign lease and source drift.

**Boundaries:** The Ed25519 private key and public trust-anchor identity are EPHEMERAL FIXTURE ONLY. There is no production issuer/credential custody or authentic signed producer. The injected clock is not a trusted time oracle; OS path checks are not symlink-race-proof ACL or production storage identity; WAL+FULL process-crash testing does not prove hardware power-loss durability. No paid AI, network, installed runtime, broker, scheduler, Monitor or JobControl dispatch code is present. This is NOT a production authenticated principal or always-on Orchestrator.

## Evidence gates and acceptance

Preserve actual BaBoss RED before source implementation and all negative/intermediate evidence. Run P3 positive/adversarial test set, all nine prior impacted Node suites, P1 Python Windows SQLite regression, Harness, native Git hooked commit and independent exact-head scrutiny. Only Main CT integrates accepted source after fresh origin/master vs independent ls-remote, Registry gate and allowlist; a test-only smoke is NOT a runtime installation.

Source paths: tools/lnwjud/job_control_runtime_v1/orchestrator_inprocess_signed_sqlite.cjs, tools/lnwjud/job_control_runtime_v1/test_orchestrator_inprocess_signed_sqlite.cjs, and this doc. Existing T3-C-P2/P1/JobControl/EA code is unchanged.

## Still blocked, and ONE NEXT

Retain previously written T3_EXACT_INSTALLATION_MANIFEST_UNAPPROVED_20261011.json as INCOMPLETE_UNAPPROVED_NOT_INSTALLED. Real producer signer/issuer/private-key custody, authenticated principal, IPC/DB ACL, exclusive production lease, task name+principal+launcher hash, actual PID/heartbeat/terminal postcondition and reversible installed preimage/rollback are NOT proved. Monitor remains DEGRADED / DIFFERENT_REPO_HEAD. No real external runtime or trading may start.

**ONE NEXT:** Freeze true signer issuer/key custody, one authorized read-only producer and consumer principal, protected durable ledger, actual process identity/heartbeat, real rollback and Monitor acceptance; then request separate exact installation approval. Never promote source acceptance into runtime authority.
